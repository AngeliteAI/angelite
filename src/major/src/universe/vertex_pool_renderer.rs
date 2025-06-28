use crate::math::{Vec3, Vec4, Mat4f};
use crate::gfx::{Gfx, Camera};
use super::{Voxel, gpu_worldgen::CompressedChunk, palette_compression::VoxelDecompressor};
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

// Main vertex pool batch renderer
pub struct VertexPoolBatchRenderer {
    gfx: Arc<dyn Gfx>,
    vertex_pools: [VertexPool; MAX_LOD_LEVELS],
    index_pools: [IndexPool; MAX_LOD_LEVELS],
    instance_manager: InstanceDataManager,
    culling_system: GpuCullingSystem,
    chunk_meshes: HashMap<u64, ChunkMeshData>,
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
    pub fn new(gfx: Arc<dyn Gfx>) -> Self {
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
            gfx,
        }
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
        lod_meshes[0] = Some(self.generate_greedy_mesh(&decompressed, chunk_size)?);
        
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
        let mut vertices = Vec::new();
        let mut indices = Vec::new();
        
        // Count non-empty voxels for debugging
        let non_empty = voxels.iter().filter(|v| v.0 != 0).count();
        println!("Greedy meshing {} non-empty voxels in {}x{}x{} chunk", non_empty, size, size, size);
        
        // Process each axis and direction for greedy meshing
        // For Z-axis faces (top/bottom)
        self.greedy_mesh_axis(voxels, size, 2, &mut vertices, &mut indices)?;
        // For Y-axis faces (front/back)
        self.greedy_mesh_axis(voxels, size, 1, &mut vertices, &mut indices)?;
        // For X-axis faces (left/right)
        self.greedy_mesh_axis(voxels, size, 0, &mut vertices, &mut indices)?;
        
        println!("Greedy mesh generated {} vertices and {} indices", vertices.len(), indices.len());
        Ok((vertices, indices))
    }
    
    fn greedy_mesh_axis(
        &self,
        voxels: &[Voxel],
        size: usize,
        axis: usize,
        vertices: &mut Vec<VoxelVertex>,
        indices: &mut Vec<u32>,
    ) -> Result<(), String> {
        let mut mask = vec![None; size * size];
        
        // u, v are the axes perpendicular to the face normal
        let u = (axis + 1) % 3;
        let v = (axis + 2) % 3;
        
        // Process both directions (positive and negative)
        for direction in [true, false] {
            let mut total_faces_this_dir = 0;
            // Iterate through slices along the axis
            for slice_pos in 0..size {
                // Clear mask
                mask.fill(None);
                let mut faces_in_slice = 0;
                
                // Build mask for this slice
                for v_pos in 0..size {
                    for u_pos in 0..size {
                        let mut pos = [0; 3];
                        pos[axis] = slice_pos;
                        pos[u] = u_pos;
                        pos[v] = v_pos;
                        
                        let idx = pos[2] * size * size + pos[1] * size + pos[0];
                        let current_voxel = voxels[idx];
                        
                        // Check if face is visible
                        let neighbor_idx = if direction {
                            // Positive direction
                            if slice_pos < size - 1 {
                                let mut neighbor_pos = pos;
                                neighbor_pos[axis] += 1;
                                Some(neighbor_pos[2] * size * size + neighbor_pos[1] * size + neighbor_pos[0])
                            } else {
                                None
                            }
                        } else {
                            // Negative direction
                            if slice_pos > 0 {
                                let mut neighbor_pos = pos;
                                neighbor_pos[axis] -= 1;
                                Some(neighbor_pos[2] * size * size + neighbor_pos[1] * size + neighbor_pos[0])
                            } else {
                                None
                            }
                        };
                        
                        let neighbor_voxel = neighbor_idx
                            .and_then(|idx| voxels.get(idx))
                            .copied()
                            .unwrap_or(Voxel(0));
                        
                        // Add face to mask if current is solid and neighbor is air
                        if current_voxel.0 != 0 && neighbor_voxel.0 == 0 {
                            mask[v_pos * size + u_pos] = Some(current_voxel);
                        }
                    }
                }
                
                // Generate merged quads from mask
                let mut processed = vec![false; size * size];
                
                for start_v in 0..size {
                    for start_u in 0..size {
                        let mask_idx = start_v * size + start_u;
                        
                        if processed[mask_idx] || mask[mask_idx].is_none() {
                            continue;
                        }
                        
                        let voxel_type = mask[mask_idx].unwrap();
                        
                        // Find width (along u axis)
                        let mut width = 1;
                        while start_u + width < size {
                            let idx = start_v * size + start_u + width;
                            if idx >= mask.len() || mask[idx] != Some(voxel_type) || processed[idx] {
                                break;
                            }
                            width += 1;
                        }
                        
                        // Find height (along v axis)
                        let mut height = 1;
                        'height_loop: while start_v + height < size {
                            // Check if entire row matches
                            let mut row_matches = true;
                            for u_offset in 0..width {
                                let idx = (start_v + height) * size + start_u + u_offset;
                                if idx >= mask.len() || mask[idx] != Some(voxel_type) || processed[idx] {
                                    row_matches = false;
                                    break;
                                }
                            }
                            if !row_matches {
                                break 'height_loop;
                            }
                            height += 1;
                        }
                        
                        // Safety check - width and height should never be 0
                        debug_assert!(width >= 1, "Width should never be less than 1");
                        debug_assert!(height >= 1, "Height should never be less than 1");
                        
                        // Mark area as processed
                        for v_offset in 0..height {
                            for u_offset in 0..width {
                                processed[(start_v + v_offset) * size + start_u + u_offset] = true;
                            }
                        }
                        
                        // Create face
                        // For negative faces, position is at the slice position
                        // For positive faces, position is at slice position + 1
                        let mut face_pos = [0.0; 3];
                        face_pos[axis] = if direction {
                            (slice_pos + 1) as f32
                        } else {
                            slice_pos as f32
                        };
                        face_pos[u] = start_u as f32;
                        face_pos[v] = start_v as f32;
                        
                        let face_size = [width as f32, height as f32];
                        
                        
                        let normal_dir = match (axis, direction) {
                            (0, true) => 0,  // +X
                            (0, false) => 1, // -X
                            (1, true) => 2,  // +Y
                            (1, false) => 3, // -Y
                            (2, true) => 4,  // +Z
                            (2, false) => 5, // -Z
                            _ => unreachable!(),
                        };
                        
                        // Map voxel type to color
                        let color = match voxel_type.0 {
                            1 => [0.5, 0.5, 0.5, 1.0], // Stone - gray
                            2 => [0.4, 0.3, 0.2, 1.0], // Dirt - brown
                            3 => [0.2, 0.7, 0.3, 1.0], // Grass - green
                            _ => [1.0, 0.0, 1.0, 1.0], // Unknown - magenta
                        };
                        
                        // Add vertex (geometry shader will expand to quad)
                        let vertex = VoxelVertex {
                            position: face_pos,
                            size: face_size,
                            normal_dir,
                            color,
                        };
                        
                        vertices.push(vertex);
                        
                        // Since we're using points with geometry shader, each face is one index
                        indices.push(vertices.len() as u32 - 1);
                        faces_in_slice += 1;
                    }
                }
                if faces_in_slice > 0 {
                    total_faces_this_dir += faces_in_slice;
                }
            }
            if total_faces_this_dir > 0 {
                println!("Axis {} direction {}: generated {} faces", axis, direction, total_faces_this_dir);
            }
        }
        
        Ok(())
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
    gfx: Arc<dyn Gfx>,
}

impl GpuCullingSystem {
    pub fn new(gfx: Arc<dyn Gfx>) -> Self {
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