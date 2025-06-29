use crate::math::{Vec3, Vec4, Mat4f};
use crate::gfx::{Gfx, Camera};
use super::{Voxel, gpu_worldgen::CompressedChunk, palette_compression::VoxelDecompressor};
use super::mesh_generator::{MeshGenerator, BinaryGreedyMeshGenerator};
use std::sync::Arc;
use std::collections::HashMap;

const MAX_LOD_LEVELS: usize = 5;
const VERTEX_POOL_SIZE: usize = 1024 * 1024; // 1M vertices per pool
const INDEX_POOL_SIZE: usize = 4 * 1024 * 1024; // 4M indices per pool

#[derive(Clone)]
pub struct ViewParams {
    pub view_matrix: Mat4f,
    pub projection_matrix: Mat4f,
    pub frustum_planes: [Vec4<f32>; 6],
    pub camera_position: Vec3<f32>,
    pub lod_distances: [f32; MAX_LOD_LEVELS],
}

impl ViewParams {
    pub fn from_camera_data(
        view_matrix: Mat4f,
        projection_matrix: Mat4f,
        camera_position: Vec3<f32>,
        lod_distances: [f32; MAX_LOD_LEVELS],
    ) -> Self {
        // Calculate frustum planes from view-projection matrix
        let vp = projection_matrix * view_matrix;
        let frustum_planes = Self::extract_frustum_planes(&vp);
        
        Self {
            view_matrix,
            projection_matrix,
            frustum_planes,
            camera_position,
            lod_distances,
        }
    }
    
    fn extract_frustum_planes(vp: &Mat4f) -> [Vec4<f32>; 6] {
        // Extract frustum planes from view-projection matrix
        // Format: ax + by + cz + d = 0
        let data = vp.to_array();
        let mut m = [0.0f32; 16];
        let mut idx = 0;
        for col in 0..4 {
            for row in 0..4 {
                m[idx] = data[col][row];
                idx += 1;
            }
        }
        
        [
            // Left plane
            Vec4::new([m[3] + m[0], m[7] + m[4], m[11] + m[8], m[15] + m[12]]),
            // Right plane
            Vec4::new([m[3] - m[0], m[7] - m[4], m[11] - m[8], m[15] - m[12]]),
            // Bottom plane
            Vec4::new([m[3] + m[1], m[7] + m[5], m[11] + m[9], m[15] + m[13]]),
            // Top plane
            Vec4::new([m[3] - m[1], m[7] - m[5], m[11] - m[9], m[15] - m[13]]),
            // Near plane
            Vec4::new([m[3] + m[2], m[7] + m[6], m[11] + m[10], m[15] + m[14]]),
            // Far plane
            Vec4::new([m[3] - m[2], m[7] - m[6], m[11] - m[10], m[15] - m[14]]),
        ]
    }
}

// Vertex format for voxel rendering with greedy meshing support
// Using repr(C, align(4)) to ensure consistent layout across FFI boundary
#[repr(C, align(4))]
#[derive(Clone, Copy, Debug)]
pub struct VoxelVertex {
    pub position: [f32; 3],     // Bottom-left corner of the face (in voxel coordinates) - 12 bytes
    pub size: [f32; 2],         // Width and height of the face (in voxels) - 8 bytes  
    pub normal_dir: u32,        // Face direction: 0=+X, 1=-X, 2=+Y, 3=-Y, 4=+Z, 5=-Z - 4 bytes
    pub color: [f32; 4],        // Face color - 16 bytes
    // Total: 40 bytes
}

// Instance data for batched rendering
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct ChunkInstanceData {
    pub transform: [[f32; 4]; 4],
    pub chunk_id: u32,
    pub lod_level: u32,
    pub palette_offset: u32,
    pub padding: u32,
}

// Vertex pool for efficient memory management
pub struct VertexPool {
    vertices: Vec<VoxelVertex>,
    free_ranges: Vec<(usize, usize)>, // (start, count)
    allocated_ranges: HashMap<u64, (usize, usize)>, // chunk_id -> (start, count)
}

impl VertexPool {
    pub fn new(capacity: usize) -> Self {
        Self {
            vertices: Vec::with_capacity(capacity),
            free_ranges: vec![(0, capacity)],
            allocated_ranges: HashMap::new(),
        }
    }
    
    pub fn allocate(&mut self, chunk_id: u64, vertex_count: usize) -> Option<usize> {
        // Find suitable free range
        for (idx, &(start, count)) in self.free_ranges.iter().enumerate() {
            if count >= vertex_count {
                // Remove this range
                self.free_ranges.remove(idx);
                
                // Add remaining range if any
                if count > vertex_count {
                    self.free_ranges.push((start + vertex_count, count - vertex_count));
                }
                
                // Track allocation
                self.allocated_ranges.insert(chunk_id, (start, vertex_count));
                
                return Some(start);
            }
        }
        
        None
    }
    
    pub fn deallocate(&mut self, chunk_id: u64) {
        if let Some((start, count)) = self.allocated_ranges.remove(&chunk_id) {
            // Merge with adjacent free ranges
            self.free_ranges.push((start, count));
            self.coalesce_free_ranges();
        }
    }
    
    fn coalesce_free_ranges(&mut self) {
        self.free_ranges.sort_by_key(|&(start, _)| start);
        
        let mut coalesced = Vec::new();
        let mut current_start = 0;
        let mut current_end = 0;
        
        for &(start, count) in &self.free_ranges {
            if start <= current_end {
                // Merge
                current_end = current_end.max(start + count);
            } else {
                // New range
                if current_end > current_start {
                    coalesced.push((current_start, current_end - current_start));
                }
                current_start = start;
                current_end = start + count;
            }
        }
        
        if current_end > current_start {
            coalesced.push((current_start, current_end - current_start));
        }
        
        self.free_ranges = coalesced;
    }
}

// Index pool for efficient memory management
pub struct IndexPool {
    indices: Vec<u32>,
    free_ranges: Vec<(usize, usize)>,
    allocated_ranges: HashMap<u64, (usize, usize)>,
}

impl IndexPool {
    pub fn new(capacity: usize) -> Self {
        Self {
            indices: Vec::with_capacity(capacity),
            free_ranges: vec![(0, capacity)],
            allocated_ranges: HashMap::new(),
        }
    }
    
    pub fn allocate(&mut self, chunk_id: u64, count: usize) -> Option<usize> {
        // Find a free range that fits
        for (i, &(start, end)) in self.free_ranges.iter().enumerate() {
            if end - start >= count {
                // Allocate from this range
                let allocated_start = start;
                let allocated_end = start + count;
                
                // Update free ranges
                if allocated_end < end {
                    self.free_ranges[i] = (allocated_end, end);
                } else {
                    self.free_ranges.remove(i);
                }
                
                // Track allocation
                self.allocated_ranges.insert(chunk_id, (allocated_start, allocated_end));
                
                return Some(allocated_start);
            }
        }
        None
    }
    
    pub fn deallocate(&mut self, chunk_id: u64) {
        if let Some((start, end)) = self.allocated_ranges.remove(&chunk_id) {
            // Add back to free ranges
            self.free_ranges.push((start, end));
            // TODO: Merge adjacent free ranges
        }
    }
}

// Batch builder for optimal draw call generation
pub struct BatchBuilder {
    batches: Vec<DrawBatch>,
    current_batch: Option<DrawBatch>,
    max_vertices_per_batch: usize,
    max_instances_per_batch: usize,
}

#[derive(Clone)]
pub struct DrawBatch {
    pub vertex_offset: u32,
    pub index_offset: u32,
    pub index_count: u32,
    pub instance_count: u32,
    pub instances: Vec<ChunkInstanceData>,
    pub material_id: u32,
}

impl BatchBuilder {
    pub fn new(max_vertices: usize, max_instances: usize) -> Self {
        Self {
            batches: Vec::new(),
            current_batch: None,
            max_vertices_per_batch: max_vertices,
            max_instances_per_batch: max_instances,
        }
    }
    
    pub fn add_chunk(
        &mut self,
        vertex_offset: u32,
        index_offset: u32,
        index_count: u32,
        instance_data: ChunkInstanceData,
        material_id: u32,
    ) {
        let needs_new_batch = match &self.current_batch {
            None => true,
            Some(batch) => {
                batch.material_id != material_id ||
                batch.instances.len() >= self.max_instances_per_batch
            }
        };
        
        if needs_new_batch {
            if let Some(batch) = self.current_batch.take() {
                self.batches.push(batch);
            }
            
            self.current_batch = Some(DrawBatch {
                vertex_offset,
                index_offset,
                index_count,
                instance_count: 0,
                instances: Vec::new(),
                material_id,
            });
        }
        
        if let Some(batch) = &mut self.current_batch {
            batch.instances.push(instance_data);
            batch.instance_count += 1;
        }
    }
    
    pub fn finish(mut self) -> Vec<DrawBatch> {
        if let Some(batch) = self.current_batch.take() {
            self.batches.push(batch);
        }
        self.batches
    }
}

// Helper struct for greedy meshing
struct GreedyQuad {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
}

// Main vertex pool batch renderer
pub struct VertexPoolBatchRenderer {
    gfx: Arc<dyn Gfx + Send + Sync>,
    vertex_pools: [VertexPool; MAX_LOD_LEVELS],
    index_pools: [IndexPool; MAX_LOD_LEVELS],
    instance_manager: InstanceDataManager,
    culling_system: GpuCullingSystem,
    chunk_meshes: HashMap<u64, ChunkMeshData>,
    mesh_generator: Box<dyn MeshGenerator>,
}

#[derive(Clone)]
pub struct ChunkMeshData {
    pub lod_meshes: [Option<LodMeshData>; MAX_LOD_LEVELS],
    pub bounds: ChunkBounds,
}

#[derive(Clone)]
pub struct LodMeshData {
    pub vertex_offset: usize,
    pub vertex_count: usize,
    pub index_offset: usize,
    pub index_count: usize,
}

#[derive(Clone)]
pub struct ChunkBounds {
    pub min: Vec3<f32>,
    pub max: Vec3<f32>,
}

impl VertexPoolBatchRenderer {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>) -> Self {
        Self::new_with_generator(gfx, Box::new(BinaryGreedyMeshGenerator::new()))
    }
    
    pub fn new_with_generator(gfx: Arc<dyn Gfx + Send + Sync>, mesh_generator: Box<dyn MeshGenerator>) -> Self {
        Self {
            vertex_pools: [
                VertexPool::new(VERTEX_POOL_SIZE),
                VertexPool::new(VERTEX_POOL_SIZE),
                VertexPool::new(VERTEX_POOL_SIZE),
                VertexPool::new(VERTEX_POOL_SIZE),
                VertexPool::new(VERTEX_POOL_SIZE),
            ],
            index_pools: [
                IndexPool::new(INDEX_POOL_SIZE),
                IndexPool::new(INDEX_POOL_SIZE),
                IndexPool::new(INDEX_POOL_SIZE),
                IndexPool::new(INDEX_POOL_SIZE),
                IndexPool::new(INDEX_POOL_SIZE),
            ],
            instance_manager: InstanceDataManager::new(),
            culling_system: GpuCullingSystem::new(gfx.clone()),
            chunk_meshes: HashMap::new(),
            mesh_generator,
            gfx,
        }
    }
    
    /// Set a new mesh generator
    pub fn set_mesh_generator(&mut self, mesh_generator: Box<dyn MeshGenerator>) {
        println!("Switching mesh generator to: {}", mesh_generator.name());
        self.mesh_generator = mesh_generator;
        // Clear existing meshes to force regeneration with new generator
        self.chunk_meshes.clear();
    }
    
    pub async fn add_chunks(
        &mut self,
        chunks: Vec<CompressedChunk>,
    ) -> Result<(), String> {
        for chunk in chunks {
            self.add_chunk(chunk).await?;
        }
        Ok(())
    }
    
    async fn add_chunk(&mut self, chunk: CompressedChunk) -> Result<(), String> {
        let chunk_id = self.chunk_id_from_position(Vec3::new([
            chunk.position.x() as i32,
            chunk.position.y() as i32,
            chunk.position.z() as i32,
        ]));
        
        println!("Adding chunk at position {:?}", chunk.position);
        
        // Generate LOD meshes
        let lod_meshes = self.generate_lod_meshes(&chunk).await?;
        
        // Allocate in vertex/index pools
        let mut mesh_data = ChunkMeshData {
            lod_meshes: [None, None, None, None, None],
            bounds: self.calculate_chunk_bounds(&chunk),
        };
        
        for (lod_level, lod_mesh) in lod_meshes.iter().enumerate() {
            if let Some((vertices, indices)) = lod_mesh {
                // Allocate vertex space
                if let Some(vertex_offset) = self.vertex_pools[lod_level].allocate(chunk_id, vertices.len()) {
                    // Copy vertices
                    let vertex_pool = &mut self.vertex_pools[lod_level];
                    for (i, vertex) in vertices.iter().enumerate() {
                        if vertex_offset + i < vertex_pool.vertices.len() {
                            vertex_pool.vertices[vertex_offset + i] = *vertex;
                        } else {
                            vertex_pool.vertices.push(*vertex);
                        }
                    }
                    
                    // Allocate index space
                    if let Some(index_offset) = self.index_pools[lod_level].allocate(chunk_id, indices.len()) {
                        // Copy indices
                        let index_pool = &mut self.index_pools[lod_level];
                        for (i, index) in indices.iter().enumerate() {
                            if index_offset + i < index_pool.indices.len() {
                                index_pool.indices[index_offset + i] = *index + vertex_offset as u32;
                            } else {
                                index_pool.indices.push(*index + vertex_offset as u32);
                            }
                        }
                        
                        mesh_data.lod_meshes[lod_level] = Some(LodMeshData {
                            vertex_offset,
                            vertex_count: vertices.len(),
                            index_offset,
                            index_count: indices.len(),
                        });
                    }
                }
            }
        }
        
        self.chunk_meshes.insert(chunk_id, mesh_data);
        
        Ok(())
    }
    
    pub async fn render_voxel_chunks(
        &mut self,
        chunks: &[VoxelChunk],
        view_params: &ViewParams,
    ) -> Result<(), String> {
        // Phase 1: Frustum culling and LOD selection
        let visible_chunks = self.culling_system.cull_chunks(chunks, view_params).await?;
        
        // Phase 2: Build batches
        let mut batch_builder = BatchBuilder::new(100000, 1000);
        
        for &(chunk_idx, lod_level) in &visible_chunks {
            let chunk = &chunks[chunk_idx];
            let chunk_id = self.chunk_id_from_position(Vec3::new([
            chunk.position.x() as i32,
            chunk.position.y() as i32,
            chunk.position.z() as i32,
        ]));
            
            if let Some(mesh_data) = self.chunk_meshes.get(&chunk_id) {
                if let Some(lod_mesh) = &mesh_data.lod_meshes[lod_level as usize] {
                    let instance_data = ChunkInstanceData {
                        transform: chunk.transform.to_array(),
                        chunk_id: chunk_id as u32,
                        lod_level,
                        palette_offset: 0, // TODO: Calculate from palette system
                        padding: 0,
                    };
                    
                    batch_builder.add_chunk(
                        lod_mesh.vertex_offset as u32,
                        lod_mesh.index_offset as u32,
                        lod_mesh.index_count as u32,
                        instance_data,
                        0, // Material ID
                    );
                }
            }
        }
        
        let batches = batch_builder.finish();
        
        // Phase 3: Update instance buffer
        self.instance_manager.update_instances(&batches).await?;
        
        // Phase 4: Generate indirect draw commands
        let draw_commands = self.generate_indirect_commands(&batches);
        
        // Phase 5: Submit to Vulkan
        self.submit_draw_commands(draw_commands).await?;
        
        Ok(())
    }
    
    async fn generate_lod_meshes(
        &self,
        chunk: &CompressedChunk,
    ) -> Result<Vec<Option<(Vec<VoxelVertex>, Vec<u32>)>>, String> {
        let mut lod_meshes = vec![None; MAX_LOD_LEVELS];
        
        // Decompress chunk
        // Determine chunk size - when bits_per_index is 0, it means all voxels are the same type
        let chunk_size = 64; // Standard chunk size - we'll get this from metadata later
        
        let voxel_count = chunk_size * chunk_size * chunk_size;
        let compressed_data = super::palette_compression::CompressedVoxelData {
            palette: chunk.palette.clone(),
            bitpacked_data: super::palette_compression::BitpackedData {
                data: chunk.indices.data.clone(),
                bits_per_index: chunk.indices.bits_per_index, // 0 is valid - means single palette entry
                voxel_count,
            },
            dimensions: (chunk_size as u32, chunk_size as u32, chunk_size as u32),
            compression_ratio: 0.0, // Not needed for decompression
        };
        let decompressed = VoxelDecompressor::decompress_chunk(&compressed_data);
        
        // Generate LOD 0 (full resolution)
        lod_meshes[0] = Some(self.mesh_generator.generate_mesh(&decompressed, chunk_size)?);
        
        // Generate other LODs
        for lod in 1..MAX_LOD_LEVELS {
            let simplification = 1 << lod;
            lod_meshes[lod] = Some(self.generate_lod_mesh(&decompressed, chunk_size, simplification)?);
        }
        
        Ok(lod_meshes)
    }
    
    pub fn generate_greedy_mesh(
        &self,
        voxels: &[Voxel],
        size: usize,
    ) -> Result<(Vec<VoxelVertex>, Vec<u32>), String> {
        // Use the configured mesh generator
        self.mesh_generator.generate_mesh(voxels, size)
    }
    
    // Legacy method for backwards compatibility - delegates to mesh generator
    fn generate_greedy_mesh_legacy(
        &self,
        voxels: &[Voxel],
        size: usize,
    ) -> Result<(Vec<VoxelVertex>, Vec<u32>), String> {
        if voxels.is_empty() || size == 0 || size > 64 {
            return Ok((vec![], vec![]));
        }
        
        // Count non-air voxels
        let non_air_count = voxels.iter().filter(|v| v.0 != 0).count();
        println!("Starting binary greedy mesh for {} voxels ({} non-air)", voxels.len(), non_air_count);
        
        let mut vertices = Vec::new();
        let mut indices = Vec::new();
        
        // Build binary columns for each axis
        let mut axis_cols = vec![vec![vec![0u64; size]; size]; 3];
        
        // Fill binary columns with correct indexing
        for z in 0..size {
            for y in 0..size {
                for x in 0..size {
                    // Standard voxel indexing: idx = x + y * size + z * size * size
                    let idx = x + y * size + z * size * size;
                    if idx < voxels.len() && voxels[idx].0 != 0 {
                        // For each axis, we store bits representing position along that axis
                        // X axis (0): YZ planes, bit position represents X coordinate
                        axis_cols[0][z][y] |= 1u64 << x;
                        // Y axis (1): XZ planes, bit position represents Y coordinate  
                        axis_cols[1][z][x] |= 1u64 << y;
                        // Z axis (2): XY planes, bit position represents Z coordinate
                        axis_cols[2][y][x] |= 1u64 << z;
                    }
                }
            }
        }
        
        // Simple test: check if we have a full plane of voxels at any Z level
        for z in 0..size {
            let mut all_solid = true;
            for y in 0..size {
                for x in 0..size {
                    let idx = x + y * size + z * size * size;
                    if idx >= voxels.len() || voxels[idx].0 == 0 {
                        all_solid = false;
                        break;
                    }
                }
                if !all_solid { break; }
            }
            if all_solid {
                println!("Z level {} is completely solid - should merge to 1 face!", z);
            }
        }
        
        // Process each axis
        for axis in 0..3 {
            self.greedy_mesh_binary_axis(
                voxels, size, axis, &axis_cols[axis],
                &mut vertices, &mut indices
            )?;
        }
        
        println!("Binary greedy mesh generated {} vertices and {} indices", vertices.len(), indices.len());
        Ok((vertices, indices))
    }
    
    fn greedy_mesh_binary_axis(
        &self,
        voxels: &[Voxel],
        size: usize,
        axis: usize,
        axis_cols: &Vec<Vec<u64>>,
        vertices: &mut Vec<VoxelVertex>,
        indices: &mut Vec<u32>,
    ) -> Result<(), String> {
        let u = (axis + 1) % 3;
        let v = (axis + 2) % 3;
        
        // For each face direction (negative and positive)
        for forward in [false, true] {
            // Create face masks by detecting solid->air transitions
            let mut face_masks = vec![vec![0u64; size]; size];
            
            for b in 0..size {
                for a in 0..size {
                    let col = axis_cols[a][b];
                    
                    if forward {
                        // Positive direction: current is solid AND next is air
                        // Shift left to check the next position
                        face_masks[a][b] = col & !(col << 1);
                        // Also add faces at the boundary (last solid voxel)
                        if size < 64 {
                            face_masks[a][b] |= col & (1u64 << (size - 1));
                        }
                    } else {
                        // Negative direction: current is solid AND previous is air
                        // Shift right to check the previous position
                        face_masks[a][b] = col & !(col >> 1);
                        // Also add faces at the boundary (first solid voxel)
                        face_masks[a][b] |= col & 1u64;
                    }
                }
            }
            
            // Group faces by voxel type
            let mut type_masks: HashMap<u16, Vec<Vec<u64>>> = HashMap::new();
            
            for b in 0..size {
                for a in 0..size {
                    let mut col = face_masks[a][b];
                    
                    while col != 0 {
                        let bit_pos = col.trailing_zeros() as usize;
                        col &= col - 1; // Clear lowest bit
                        
                        // Get voxel position
                        let mut pos = [0; 3];
                        pos[axis] = bit_pos;
                        pos[u] = a;
                        pos[v] = b;
                        
                        let voxel_idx = pos[0] + pos[1] * size + pos[2] * size * size;
                        if voxel_idx >= voxels.len() {
                            continue;
                        }
                        
                        let voxel_type = voxels[voxel_idx].0;
                        
                        // Get or create mask for this voxel type
                        let type_mask = type_masks.entry(voxel_type as u16).or_insert_with(|| {
                            vec![vec![0u64; size]; size]
                        });
                        
                        // Set bit in the appropriate mask
                        type_mask[a][b] |= 1u64 << bit_pos;
                    }
                }
            }
            
            // Process each voxel type separately
            for (voxel_type, type_mask) in type_masks {
                // Process each layer along the axis
                for layer in 0..size {
                    let mut plane = vec![0u32; size];
                    
                    // Build binary plane for this layer
                    for b in 0..size {
                        for a in 0..size {
                            if (type_mask[a][b] >> layer) & 1 == 1 {
                                plane[a] |= 1u32 << b;
                            }
                        }
                    }
                    
                    // Skip empty planes
                    if plane.iter().all(|&row| row == 0) {
                        continue;
                    }
                    
                    // Greedy mesh this binary plane
                    let quads = self.greedy_mesh_binary_plane(&mut plane, size);
                    
                    // Debug output for large quads
                    if quads.len() > 0 {
                        let total_area: u32 = quads.iter().map(|q| q.w * q.h).sum();
                        let avg_area = total_area as f32 / quads.len() as f32;
                        if avg_area < 2.0 {
                            println!("WARNING: Axis {} dir {} layer {} type {}: {} quads, avg area {:.1} (too many strips!)", 
                                axis, forward, layer, voxel_type, quads.len(), avg_area);
                        }
                    }
                    
                    // Convert quads to vertices
                    for quad in quads {
                        let mut position = [0.0; 3];
                        position[axis] = if forward {
                            (layer + 1) as f32
                        } else {
                            layer as f32
                        };
                        position[u] = quad.x as f32;
                        position[v] = quad.y as f32;
                        
                        let face_size = [quad.w as f32, quad.h as f32];
                        // Normal direction mapping:
                        // axis 0 (X): forward = +X (0), backward = -X (1)
                        // axis 1 (Y): forward = +Y (2), backward = -Y (3)
                        // axis 2 (Z): forward = +Z (4), backward = -Z (5)
                        let normal_dir = match (axis, forward) {
                            (0, true) => 0,   // +X
                            (0, false) => 1,  // -X
                            (1, true) => 2,   // +Y
                            (1, false) => 3,  // -Y
                            (2, true) => 4,   // +Z
                            (2, false) => 5,  // -Z
                            _ => unreachable!(),
                        };
                        
                        let color = match voxel_type as usize {
                            1 => [0.5, 0.5, 0.5, 1.0], // Stone
                            2 => [0.4, 0.3, 0.2, 1.0], // Dirt
                            3 => [0.2, 0.7, 0.3, 1.0], // Grass
                            _ => [1.0, 0.0, 1.0, 1.0], // Unknown
                        };
                        
                        vertices.push(VoxelVertex {
                            position,
                            size: face_size,
                            normal_dir: normal_dir as u32,
                            color,
                        });
                        
                        indices.push(vertices.len() as u32 - 1);
                    }
                }
            }
        }
        
        Ok(())
    }
    
    
    fn greedy_mesh_binary_plane(&self, plane: &mut [u32], size: usize) -> Vec<GreedyQuad> {
        let mut quads = Vec::new();
        
        // Debug: print the plane
        let mut solid_count = 0;
        for row in 0..size {
            solid_count += plane[row].count_ones();
        }
        if solid_count > 0 {
            println!("Binary plane has {} solid cells in {}x{} grid", solid_count, size, size);
        }
        
        for row in 0..size {
            let mut y = 0;
            
            while y < size as u32 {
                // Skip zeros to find start of solid run
                y += (plane[row] >> y).trailing_zeros();
                if y >= size as u32 {
                    break;
                }
                
                // Find height of solid run
                let h = (plane[row] >> y).trailing_ones();
                
                // Create mask for this height at this y position
                let h_mask = if h >= 32 { !0u32 } else { (1u32 << h) - 1 };
                let mask = h_mask << y;
                
                // Try to expand horizontally
                let mut w = 1;
                while row + w < size {
                    // Check if next row has the same pattern
                    let next_row_bits = (plane[row + w] >> y) & h_mask;
                    if next_row_bits != h_mask {
                        break;
                    }
                    w += 1;
                }
                
                // Clear the bits we've merged in ALL rows (including the first one)
                for r in 0..w {
                    plane[row + r] &= !mask;
                }
                
                if w > 1 || h > 1 {
                    println!("Created quad at ({}, {}) size {}x{}", row, y, w, h);
                }
                
                quads.push(GreedyQuad {
                    x: row as u32,
                    y,
                    w: w as u32,
                    h,
                });
                
                y += h;
            }
        }
        
        quads
    }
    
    fn generate_lod_mesh(
        &self,
        voxels: &[Voxel],
        size: usize,
        simplification: usize,
    ) -> Result<(Vec<VoxelVertex>, Vec<u32>), String> {
        // Generate simplified mesh for LOD
        Ok((vec![], vec![]))
    }
    
    fn chunk_id_from_position(&self, position: Vec3<i32>) -> u64 {
        // Generate unique ID from chunk position
        let x = position.x() as u64 & 0xFFFFF;
        let y = position.y() as u64 & 0xFFFFF;
        let z = position.z() as u64 & 0xFFFFF;
        (x << 40) | (y << 20) | z
    }
    
    fn calculate_chunk_bounds(&self, chunk: &CompressedChunk) -> ChunkBounds {
        let pos = Vec3::new([
            chunk.position.x() as f32,
            chunk.position.y() as f32,
            chunk.position.z() as f32,
        ]) * 64.0; // Chunk size
        
        ChunkBounds {
            min: pos,
            max: pos + Vec3::one() * 64.0,
        }
    }
    
    fn generate_indirect_commands(&self, batches: &[DrawBatch]) -> Vec<IndirectDrawCommand> {
        batches.iter().map(|batch| {
            IndirectDrawCommand {
                index_count: batch.index_count,
                instance_count: batch.instance_count,
                first_index: batch.index_offset,
                vertex_offset: batch.vertex_offset as i32,
                first_instance: 0,
            }
        }).collect()
    }
    
    async fn submit_draw_commands(
        &mut self,
        commands: Vec<IndirectDrawCommand>,
    ) -> Result<(), String> {
        // Submit to Vulkan renderer
        Ok(())
    }
}

// GPU culling system
pub struct GpuCullingSystem {
    gfx: Arc<dyn Gfx + Send + Sync>,
}

impl GpuCullingSystem {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>) -> Self {
        Self { gfx }
    }
    
    pub async fn cull_chunks(
        &self,
        chunks: &[VoxelChunk],
        view_params: &ViewParams,
    ) -> Result<Vec<(usize, u32)>, String> {
        // Perform GPU-based frustum and occlusion culling
        // Returns (chunk_index, lod_level)
        
        let mut visible = Vec::new();
        
        for (idx, chunk) in chunks.iter().enumerate() {
            // Simple CPU frustum culling for now
            if self.is_in_frustum(chunk, view_params) {
                let lod = self.calculate_lod(chunk, view_params);
                visible.push((idx, lod));
            }
        }
        
        Ok(visible)
    }
    
    fn is_in_frustum(&self, chunk: &VoxelChunk, view_params: &ViewParams) -> bool {
        // Frustum culling
        true
    }
    
    fn calculate_lod(&self, chunk: &VoxelChunk, view_params: &ViewParams) -> u32 {
        // Extract position from transform matrix (last column)
        let transform_data = chunk.transform.to_array();
        let world_pos = Vec3::new([
            transform_data[3][0],
            transform_data[3][1],
            transform_data[3][2],
        ]);
        let distance = (world_pos - view_params.camera_position).length();
        
        for (lod, &max_dist) in view_params.lod_distances.iter().enumerate() {
            if distance < max_dist {
                return lod as u32;
            }
        }
        
        (MAX_LOD_LEVELS - 1) as u32
    }
}

// Instance data manager
pub struct InstanceDataManager {
    instance_buffer: Vec<ChunkInstanceData>,
}

impl InstanceDataManager {
    pub fn new() -> Self {
        Self {
            instance_buffer: Vec::new(),
        }
    }
    
    pub async fn update_instances(&mut self, batches: &[DrawBatch]) -> Result<(), String> {
        self.instance_buffer.clear();
        
        for batch in batches {
            self.instance_buffer.extend_from_slice(&batch.instances);
        }
        
        Ok(())
    }
}

// Structures for rendering
#[repr(C)]
pub struct IndirectDrawCommand {
    pub index_count: u32,
    pub instance_count: u32,
    pub first_index: u32,
    pub vertex_offset: i32,
    pub first_instance: u32,
}

pub struct VoxelChunk {
    pub position: Vec3<f32>,
    pub transform: Mat4f,
}