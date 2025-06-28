use major::{
    math::{Vec3, Mat4f},
    universe::{
        GpuWorldGenerator, VoxelWorkspace, WorldBounds, GenerationParams,
        PaletteCompressionSystem, CompressedVoxelData,
        VoxelPhysicsGenerator, PhysicsLodLevel,
        VertexPoolBatchRenderer, ViewParams,
        sdf::{Sdf, SdfOps, Sphere, Box3, Plane},
        brush::{BrushLayer, LayeredBrush, Condition, BlendMode},
        Voxel, World,
    },
    gfx::{Gfx, Camera},
    physx::Physx,
};
use std::sync::{Arc, RwLock};
use std::collections::HashMap;

// Complete voxel world system for Synthesis
pub struct VoxelWorld {
    // Core systems
    gpu_generator: GpuWorldGenerator,
    compression_system: PaletteCompressionSystem,
    physics_generator: VoxelPhysicsGenerator,
    renderer: VertexPoolBatchRenderer,
    
    // World data
    world: World,
    loaded_regions: HashMap<RegionId, LoadedRegion>,
    active_chunks: HashMap<ChunkId, ActiveChunk>,
    
    // Configuration
    config: WorldConfig,
    
    // Context references
    vulkan: Arc<dyn Gfx>,
    physics: Arc<RwLock<dyn Physx>>,
}

#[derive(Clone, Copy, Debug, Hash, Eq, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct RegionId(i32, i32, i32);

#[derive(Clone, Copy, Debug, Hash, Eq, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct ChunkId(i32, i32, i32);

pub struct LoadedRegion {
    pub id: RegionId,
    pub chunks: Vec<ChunkId>,
    pub generation_params: GenerationParams,
}

pub struct ActiveChunk {
    pub id: ChunkId,
    pub compressed_data: CompressedVoxelData,
    pub physics_colliders: Vec<u64>, // Physics body IDs
    pub render_data: ChunkRenderData,
    pub last_modified: u64, // timestamp in seconds
}

pub struct ChunkRenderData {
    pub vertex_count: u32,
    pub lod_distances: [f32; 5],
}

#[derive(Clone, serde::Serialize, serde::Deserialize)]
pub struct WorldConfig {
    pub chunk_size: u32,
    pub region_size: u32, // in chunks
    pub view_distance: f32,
    pub physics_distance: f32,
    pub voxel_size: f32,
    pub enable_compression: bool,
    pub enable_physics: bool,
    pub enable_lod: bool,
}

impl Default for WorldConfig {
    fn default() -> Self {
        Self {
            chunk_size: 64,
            region_size: 8,
            view_distance: 512.0,
            physics_distance: 256.0,
            voxel_size: 1.0,
            enable_compression: true,
            enable_physics: true,
            enable_lod: true,
        }
    }
}

impl VoxelWorld {
    pub fn new(
        vulkan: Arc<dyn Gfx>,
        physics: Arc<RwLock<dyn Physx>>,
        config: WorldConfig,
    ) -> Self {
        Self {
            gpu_generator: GpuWorldGenerator::new(vulkan.clone()),
            compression_system: PaletteCompressionSystem::new(vulkan.clone()),
            physics_generator: VoxelPhysicsGenerator::new(physics.clone()),
            renderer: VertexPoolBatchRenderer::new(vulkan.clone()),
            world: World::default(),
            loaded_regions: HashMap::new(),
            active_chunks: HashMap::new(),
            config,
            vulkan,
            physics,
        }
    }
    
    pub fn voxel_size(&self) -> f32 {
        self.config.voxel_size
    }
    
    pub fn chunks_modified_since(&self, timestamp: &std::time::Instant) -> bool {
        let timestamp_secs = timestamp.elapsed().as_secs();
        let current_time = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        for chunk in self.active_chunks.values() {
            if chunk.last_modified > current_time - timestamp_secs {
                return true;
            }
        }
        false
    }
    
    // Main update loop
    pub async fn update(&mut self, camera_pos: Vec3<f32>, delta_time: f32) -> Result<(), String> {
        
        // Update region loading
        self.update_region_loading(camera_pos).await?;
        
        // Update chunk physics
        self.update_chunk_physics(camera_pos).await?;
        
        // Don't use the renderer here - we're manually managing the mesh in main.rs
        // The renderer.render_voxel_chunks would conflict with our manual mesh updates
        
        Ok(())
    }
    
    
    // Get individual chunk meshes for rendering  
    pub fn get_chunks_for_rendering(&self) -> Option<Vec<((i32, i32, i32), Vec<major::universe::VoxelVertex>)>> {
        use major::universe::vertex_pool_renderer::VoxelVertex;
        
        if self.active_chunks.is_empty() {
            return None;
        }
        
        let mut chunk_meshes = Vec::new();
        
        for (chunk_id, chunk) in self.active_chunks.iter() {
            // Generate greedy mesh using the renderer
            let decompressed = self.decompress_chunk(&chunk.compressed_data);
            
            // Count non-air voxels for debugging
            let non_air_count = decompressed.iter().filter(|v| v.0 != 0).count();
            if non_air_count > 0 {
                println!("Chunk {:?} has {} non-air voxels", chunk_id, non_air_count);
            }
            
            let greedy_result = self.renderer.generate_greedy_mesh(
                &decompressed,
                self.config.chunk_size as usize
            );
            
            if let Ok((vertices, _indices)) = greedy_result {
                println!("Generated {} vertices for chunk {:?}", vertices.len(), chunk_id);
                
                if !vertices.is_empty() {
                    chunk_meshes.push(((chunk_id.0, chunk_id.1, chunk_id.2), vertices));
                }
            }
        }
        
        if chunk_meshes.is_empty() {
            None
        } else {
            Some(chunk_meshes)
        }
    }
    
    // Get a greedy mesh representation for rendering
    pub fn get_greedy_mesh(&self) -> Option<(Vec<major::math::Vec3f>, Vec<u32>, Vec<major::gfx::Color>, Vec<[f32; 2]>)> {
        use major::universe::vertex_pool_renderer::VoxelVertex;
        
        if self.active_chunks.is_empty() {
            return None;
        }
        
        let mut all_vertices = Vec::new();
        let mut all_normals = Vec::new();
        let mut all_colors = Vec::new();
        let mut all_sizes = Vec::new();
        
        // Use the renderer's greedy meshing for all chunks
        for (chunk_id, chunk) in self.active_chunks.iter() {
            // Generate greedy mesh using the renderer
            let decompressed = self.decompress_chunk(&chunk.compressed_data);
            
            // Count non-air voxels for debugging
            let non_air_count = decompressed.iter().filter(|v| v.0 != 0).count();
            if non_air_count > 0 {
                println!("Chunk {:?} has {} non-air voxels", chunk_id, non_air_count);
            }
            
            let greedy_result = self.renderer.generate_greedy_mesh(
                &decompressed,
                self.config.chunk_size as usize
            );
            
            if let Ok((vertices, _indices)) = greedy_result {
                let world_offset = self.chunk_id_to_world_pos(*chunk_id);
                
                println!("Chunk {:?} generated {} vertices at offset {:?}", chunk_id, vertices.len(), world_offset);
                
                for vertex in vertices {
                    // Convert from VoxelVertex to our format
                    all_vertices.push(major::math::Vec3f::xyz(
                        world_offset.x() + vertex.position[0],
                        world_offset.y() + vertex.position[1],
                        world_offset.z() + vertex.position[2]
                    ));
                    
                    all_normals.push(vertex.normal_dir);
                    
                    all_colors.push(major::gfx::Color::new(
                        vertex.color[0],
                        vertex.color[1],
                        vertex.color[2],
                        vertex.color[3]
                    ));
                    
                    all_sizes.push(vertex.size);
                }
            }
        }
        
        if all_vertices.is_empty() {
            None
        } else {
            println!("Total vertices generated: {}", all_vertices.len());
            
            // Debug: Print first few vertices
            for i in 0..5.min(all_vertices.len()) {
                println!("Vertex {}: pos={:?}, normal={}, color={:?}, size={:?}", 
                    i, 
                    all_vertices[i].0, 
                    all_normals[i],
                    all_colors[i],
                    all_sizes[i]
                );
            }
            
            Some((all_vertices, all_normals, all_colors, all_sizes))
        }
    }
    
    // Generate a new region
    pub async fn generate_region(&mut self, region_id: RegionId) -> Result<(), String> {
        println!("Generating region {:?}", region_id);
        
        // Create generation parameters for this region
        let params = self.create_generation_params(region_id);
        
        // Calculate region bounds
        let region_bounds = self.calculate_region_bounds(region_id);
        
        // Generate with GPU
        let workspace = self.gpu_generator
            .generate_world_region(region_bounds, params.clone())
            .await?;
        
        // Extract and compress chunks
        let compressed_chunks = self.extract_and_compress_chunks(&workspace, region_id).await?;
        
        // Create region data
        let mut region = LoadedRegion {
            id: region_id,
            chunks: Vec::new(),
            generation_params: params,
        };
        
        // Process each chunk
        for (chunk_id, compressed_data) in &compressed_chunks {
            // Generate physics if enabled
            let physics_colliders = if self.config.enable_physics {
                self.generate_chunk_physics(&workspace, *chunk_id).await?
            } else {
                vec![]
            };
            
            // Create render data
            let render_data = ChunkRenderData {
                vertex_count: compressed_data.dimensions.0 * 
                             compressed_data.dimensions.1 * 
                             compressed_data.dimensions.2,
                lod_distances: [64.0, 128.0, 256.0, 512.0, 1024.0],
            };
            
            // Add to active chunks
            self.active_chunks.insert(*chunk_id, ActiveChunk {
                id: *chunk_id,
                compressed_data: compressed_data.clone(),
                physics_colliders,
                render_data,
                last_modified: std::time::SystemTime::now()
                    .duration_since(std::time::UNIX_EPOCH)
                    .unwrap()
                    .as_secs(),
            });
            
            region.chunks.push(*chunk_id);
        }
        
        self.loaded_regions.insert(region_id, region);
        
        // Don't add chunks to renderer since we're using manual mesh management
        println!("Generated {} chunks for region {:?}", compressed_chunks.len(), region_id);
        
        Ok(())
    }
    
    // Modify voxels in the world
    pub async fn modify_voxels(
        &mut self,
        modifications: Vec<VoxelModification>,
    ) -> Result<(), String> {
        // Group modifications by chunk
        let mut chunks_to_update: HashMap<ChunkId, Vec<VoxelModification>> = HashMap::new();
        
        for modification in modifications {
            let chunk_id = self.world_pos_to_chunk_id(modification.position);
            chunks_to_update.entry(chunk_id)
                .or_insert_with(Vec::new)
                .push(modification);
        }
        
        // Update each chunk
        for (chunk_id, mods) in chunks_to_update {
            // Extract data to avoid borrow checker issues
            let chunk_data = if let Some(chunk) = self.active_chunks.get(&chunk_id) {
                Some((chunk.compressed_data.clone(), chunk.compressed_data.dimensions))
            } else {
                None
            };
            
            if let Some((compressed_data, dimensions)) = chunk_data {
                // Decompress chunk
                let mut voxels = self.decompress_chunk(&compressed_data);
                
                // Apply modifications
                for modification in mods {
                    let local_pos = self.world_to_chunk_local(modification.position);
                    let idx = self.local_pos_to_index(local_pos);
                    if idx < voxels.len() {
                        voxels[idx] = modification.new_voxel;
                    }
                }
                
                // Recompress
                let compressed = self.compression_system
                    .compress_workspace(&voxels, dimensions)
                    .await?;
                
                // Update physics
                if self.config.enable_physics {
                    self.update_chunk_physics_bodies(chunk_id, &compressed).await?;
                }
                
                // Don't update renderer - manual mesh management in main.rs
                
                // Update chunk
                if let Some(chunk) = self.active_chunks.get_mut(&chunk_id) {
                    chunk.compressed_data = compressed;
                    chunk.last_modified = std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .unwrap()
                        .as_secs();
                }
            }
        }
        
        Ok(())
    }
    
    // Raycast through voxel world
    pub fn raycast(
        &self,
        origin: Vec3<f32>,
        direction: Vec3<f32>,
        max_distance: f32,
    ) -> Option<VoxelRaycastHit> {
        // Use DDA algorithm for voxel traversal
        let mut current = origin;
        let step = direction.normalize() * self.config.voxel_size * 0.1;
        let mut distance = 0.0;
        
        while distance < max_distance {
            let chunk_id = self.world_pos_to_chunk_id(current);
            
            if let Some(chunk) = self.active_chunks.get(&chunk_id) {
                let local_pos = self.world_to_chunk_local(current);
                let idx = self.local_pos_to_index(local_pos);
                
                // Check if we hit a solid voxel
                let decompressed = self.decompress_chunk(&chunk.compressed_data);
                if idx < decompressed.len() && decompressed[idx].0 != 0 {
                    return Some(VoxelRaycastHit {
                        position: current,
                        normal: self.calculate_hit_normal(current, direction),
                        voxel: decompressed[idx],
                        chunk_id,
                        distance,
                    });
                }
            }
            
            current = current + step;
            distance += step.length();
        }
        
        None
    }
    
    // Helper methods
    fn create_generation_params(&self, region_id: RegionId) -> GenerationParams {
        println!("Creating generation params for region {:?}", region_id);
        
        // Create terrain SDF (Z is up)
        let terrain_base = Plane {
            normal: Vec3::new([0.0, 0.0, 1.0]),
            distance: 0.0,
        };
        
        // Add some interesting features
        let mountain = Sphere {
            center: Vec3::new([
                region_id.0 as f32 * 512.0 + 256.0,
                region_id.1 as f32 * 512.0 + 256.0,
                -50.0,  // Below the terrain plane
            ]),
            radius: 200.0,
        };
        
        let terrain_sdf = terrain_base.union(mountain);
        
        // Create brush layers
        let stone_layer = BrushLayer {
            condition: Condition::depth(2.0, 100.0),  // Deep below surface
            voxel: Voxel(1), // Stone
            blend_weight: 1.0,
            priority: 0,
        };
        
        let dirt_layer = BrushLayer {
            condition: Condition::depth(0.5, 2.0),  // Near surface
            voxel: Voxel(2), // Dirt
            blend_weight: 1.0,
            priority: 1,
        };
        
        let grass_layer = BrushLayer {
            condition: Condition::depth(-0.5, 0.5),  // At surface
            voxel: Voxel(3), // Grass
            blend_weight: 1.0,
            priority: 2,
        };
        
        let brush = LayeredBrush {
            layers: vec![stone_layer, dirt_layer, grass_layer],
            blend_mode: BlendMode::Replace,
            global_weight: 1.0,
        };
        
        GenerationParams {
            sdf_resolution: Vec3::new([128, 64, 128]),
            sdf_tree: Arc::from(terrain_sdf),  // Convert Box<dyn Sdf> to Arc<dyn Sdf>
            brush_schema: major::universe::gpu_worldgen::BrushSchema {
                layers: vec![Arc::new(brush)],
                blend_mode: BlendMode::Replace,
            },
            post_processes: vec![
                major::universe::gpu_worldgen::PostProcess::Smoothing {
                    iterations: 2,
                    strength: 0.5,
                },
            ],
            lod_levels: vec![
                major::universe::gpu_worldgen::LodLevel {
                    distance: 64.0,
                    simplification: 1.0,
                },
                major::universe::gpu_worldgen::LodLevel {
                    distance: 256.0,
                    simplification: 0.5,
                },
            ],
        }
    }
    
    fn calculate_region_bounds(&self, region_id: RegionId) -> WorldBounds {
        let region_size_voxels = self.config.region_size * self.config.chunk_size;
        let min = Vec3::new([
            region_id.0 as f32 * region_size_voxels as f32 * self.config.voxel_size,
            region_id.1 as f32 * region_size_voxels as f32 * self.config.voxel_size,
            region_id.2 as f32 * region_size_voxels as f32 * self.config.voxel_size,
        ]);
        let max = min + Vec3::one() * region_size_voxels as f32 * self.config.voxel_size;
        
        println!("Region {:?} bounds: min=[{:.1}, {:.1}, {:.1}], max=[{:.1}, {:.1}, {:.1}]", 
            region_id, min.x(), min.y(), min.z(), max.x(), max.y(), max.z());
        
        WorldBounds {
            min,
            max,
            voxel_size: self.config.voxel_size,
        }
    }
    
    async fn extract_and_compress_chunks(
        &mut self,
        workspace: &VoxelWorkspace,
        region_id: RegionId,
    ) -> Result<HashMap<ChunkId, CompressedVoxelData>, String> {
        let mut compressed_chunks = HashMap::new();
        let all_chunks = workspace.extract_all_chunks();
        
        println!("Extracting {} chunks from workspace for region {:?}", all_chunks.len(), region_id);
        
        // Calculate region offset in chunks
        let region_chunk_offset = Vec3::new([
            region_id.0 * self.config.region_size as i32,
            region_id.1 * self.config.region_size as i32,
            region_id.2 * self.config.region_size as i32,
        ]);
        
        for chunk in all_chunks {
            // Convert from region-relative to world chunk coordinates
            let chunk_id = ChunkId(
                region_chunk_offset.x() + chunk.position.x(),
                region_chunk_offset.y() + chunk.position.y(),
                region_chunk_offset.z() + chunk.position.z(),
            );
            
            // Convert to compressed voxel data format
            let compressed = CompressedVoxelData {
                palette: chunk.palette,
                bitpacked_data: major::universe::palette_compression::BitpackedData {
                    data: chunk.indices.data,
                    bits_per_index: chunk.indices.bits_per_index,
                    voxel_count: (self.config.chunk_size * self.config.chunk_size * self.config.chunk_size) as usize,
                },
                dimensions: (self.config.chunk_size, self.config.chunk_size, self.config.chunk_size),
                compression_ratio: 0.0, // Will be calculated
            };
            
            compressed_chunks.insert(chunk_id, compressed);
        }
        
        Ok(compressed_chunks)
    }
    
    async fn generate_chunk_physics(
        &mut self,
        workspace: &VoxelWorkspace,
        chunk_id: ChunkId,
    ) -> Result<Vec<u64>, String> {
        let colliders = self.physics_generator
            .generate_physics_colliders(workspace, PhysicsLodLevel::Quarter)
            .await?;
        
        let mut body_ids = Vec::new();
        let mut physics = self.physics.write().unwrap();
        
        for collider in colliders {
            // Create physics body
            // let body_id = physics.create_static_body(collider);
            // body_ids.push(body_id);
        }
        
        Ok(body_ids)
    }
    
    async fn update_region_loading(&mut self, camera_pos: Vec3<f32>) -> Result<(), String> {
        // Generate a single region that contains the terrain plane at Z=0
        // Since our chunk size is 32 and region size is 4, each region is 128 voxels
        // We want a region that spans from below to above Z=0
        let region_id = RegionId(0, 0, 0);
        
        if !self.loaded_regions.contains_key(&region_id) {
            println!("Generating initial region at origin");
            self.generate_region(region_id).await?;
        }
        
        // Also generate neighboring regions for a 3x3 grid at Z=0
        for x in -1..=1 {
            for y in -1..=1 {
                let region_id = RegionId(x, y, 0);
                if !self.loaded_regions.contains_key(&region_id) {
                    self.generate_region(region_id).await?;
                }
            }
        }
        
        Ok(())
    }
    
    async fn update_chunk_physics(&mut self, camera_pos: Vec3<f32>) -> Result<(), String> {
        // Update physics for nearby chunks
        let chunk_ids: Vec<_> = self.active_chunks.keys().cloned().collect();
        for chunk_id in chunk_ids {
            let chunk_center = self.chunk_id_to_world_pos(chunk_id) + 
                              Vec3::one() * self.config.chunk_size as f32 * 0.5 * self.config.voxel_size;
            let distance = (chunk_center - camera_pos).length();
            
            if distance < self.config.physics_distance {
                // Enable physics
                if let Some(chunk) = self.active_chunks.get(&chunk_id) {
                    if chunk.physics_colliders.is_empty() {
                        // Generate physics colliders
                        // TODO: Implement
                    }
                }
            } else {
                // Disable physics
                if let Some(chunk) = self.active_chunks.get_mut(&chunk_id) {
                    if !chunk.physics_colliders.is_empty() {
                        // Remove physics colliders
                        let mut physics = self.physics.write().unwrap();
                        for &body_id in &chunk.physics_colliders {
                            // physics.remove_body(body_id);
                        }
                        chunk.physics_colliders.clear();
                    }
                }
            }
        }
        
        Ok(())
    }
    
    async fn update_chunk_physics_bodies(
        &mut self,
        chunk_id: ChunkId,
        compressed: &CompressedVoxelData,
    ) -> Result<(), String> {
        if let Some(chunk) = self.active_chunks.get_mut(&chunk_id) {
            // Remove old physics bodies
            let mut physics = self.physics.write().unwrap();
            for &body_id in &chunk.physics_colliders {
                // physics.remove_body(body_id);
            }
            chunk.physics_colliders.clear();
            
            // Generate new physics bodies
            // TODO: Implement based on compressed data
        }
        
        Ok(())
    }
    
    fn decompress_chunk(&self, compressed: &CompressedVoxelData) -> Vec<Voxel> {
        major::universe::palette_compression::VoxelDecompressor::decompress_chunk(compressed)
    }
    
    fn compressed_to_render_chunk(&self, compressed: &CompressedVoxelData, chunk_id: ChunkId) -> major::universe::gpu_worldgen::CompressedChunk {
        major::universe::gpu_worldgen::CompressedChunk {
            position: Vec3::new([chunk_id.0, chunk_id.1, chunk_id.2]),
            palette: compressed.palette.clone(),
            indices: major::universe::gpu_worldgen::BitpackedData {
                data: compressed.bitpacked_data.data.clone(),
                bits_per_index: compressed.bitpacked_data.bits_per_index,
            },
            metadata: major::universe::gpu_worldgen::ChunkMetadata {
                has_surface: true,
                lod_levels: vec![],
            },
        }
    }
    
    fn chunk_to_render_data(&self, chunk: &ActiveChunk) -> major::universe::vertex_pool_renderer::VoxelChunk {
        // Pass chunk indices as position for the renderer to look up mesh data
        let chunk_indices = Vec3::new([chunk.id.0 as f32, chunk.id.1 as f32, chunk.id.2 as f32]);
        let world_pos = self.chunk_id_to_world_pos(chunk.id);
        major::universe::vertex_pool_renderer::VoxelChunk {
            position: chunk_indices,  // Use chunk indices for mesh lookup
            transform: Mat4f::from_translation(world_pos),  // Use world position for transform
        }
    }
    
    fn is_chunk_visible(&self, chunk: &ActiveChunk, view_params: &ViewParams) -> bool {
        let chunk_center = self.chunk_id_to_world_pos(chunk.id) + 
                          Vec3::one() * self.config.chunk_size as f32 * 0.5 * self.config.voxel_size;
        let distance = (chunk_center - view_params.camera_position).length();
        distance < self.config.view_distance
    }
    
    fn unload_region(&mut self, region_id: RegionId) {
        if let Some(region) = self.loaded_regions.remove(&region_id) {
            // Remove all chunks in this region
            for chunk_id in region.chunks {
                if let Some(chunk) = self.active_chunks.remove(&chunk_id) {
                    // Clean up physics
                    if !chunk.physics_colliders.is_empty() {
                        let mut physics = self.physics.write().unwrap();
                        for &body_id in &chunk.physics_colliders {
                            // physics.remove_body(body_id);
                        }
                    }
                }
            }
        }
    }
    
    fn world_pos_to_region_id(&self, pos: Vec3<f32>) -> RegionId {
        let region_size = self.config.region_size * self.config.chunk_size;
        RegionId(
            (pos.x() / (region_size as f32 * self.config.voxel_size)).floor() as i32,
            (pos.y() / (region_size as f32 * self.config.voxel_size)).floor() as i32,
            (pos.z() / (region_size as f32 * self.config.voxel_size)).floor() as i32,
        )
    }
    
    fn world_pos_to_chunk_id(&self, pos: Vec3<f32>) -> ChunkId {
        ChunkId(
            (pos.x() / (self.config.chunk_size as f32 * self.config.voxel_size)).floor() as i32,
            (pos.y() / (self.config.chunk_size as f32 * self.config.voxel_size)).floor() as i32,
            (pos.z() / (self.config.chunk_size as f32 * self.config.voxel_size)).floor() as i32,
        )
    }
    
    fn chunk_id_to_world_pos(&self, chunk_id: ChunkId) -> Vec3<f32> {
        Vec3::new([
            chunk_id.0 as f32 * self.config.chunk_size as f32 * self.config.voxel_size,
            chunk_id.1 as f32 * self.config.chunk_size as f32 * self.config.voxel_size,
            chunk_id.2 as f32 * self.config.chunk_size as f32 * self.config.voxel_size,
        ])
    }
    
    fn world_to_chunk_local(&self, world_pos: Vec3<f32>) -> Vec3<u32> {
        let chunk_origin = self.chunk_id_to_world_pos(self.world_pos_to_chunk_id(world_pos));
        let local = (world_pos - chunk_origin) / self.config.voxel_size;
        Vec3::new([
            local.x().floor() as u32,
            local.y().floor() as u32,
            local.z().floor() as u32,
        ])
    }
    
    fn local_pos_to_index(&self, local: Vec3<u32>) -> usize {
        (local.z() * self.config.chunk_size * self.config.chunk_size +
         local.y() * self.config.chunk_size +
         local.x()) as usize
    }
    
    fn calculate_hit_normal(&self, hit_pos: Vec3<f32>, ray_dir: Vec3<f32>) -> Vec3<f32> {
        // Simple normal calculation based on which face was hit
        let voxel_center = Vec3::new([
            (hit_pos.x() / self.config.voxel_size).floor() + 0.5,
            (hit_pos.y() / self.config.voxel_size).floor() + 0.5,
            (hit_pos.z() / self.config.voxel_size).floor() + 0.5,
        ]) * self.config.voxel_size;
        
        let diff = hit_pos - voxel_center;
        let abs_diff = diff.abs();
        
        if abs_diff.x() > abs_diff.y() && abs_diff.x() > abs_diff.z() {
            Vec3::new([diff.x().signum(), 0.0, 0.0])
        } else if abs_diff.y() > abs_diff.z() {
            Vec3::new([0.0, diff.y().signum(), 0.0])
        } else {
            Vec3::new([0.0, 0.0, diff.z().signum()])
        }
    }
}

// Save/Load system
impl VoxelWorld {
    pub async fn save_world(&self, path: &str) -> Result<(), String> {
        use std::fs::File;
        use std::io::Write;
        
        // Create save data structure
        let save_data = WorldSaveData {
            version: 1,
            config: self.config.clone(),
            regions: self.loaded_regions.keys().cloned().collect(),
            chunks: self.active_chunks.iter()
                .map(|(id, chunk)| ChunkSaveData {
                    id: *id,
                    compressed_data: chunk.compressed_data.clone(),
                    last_modified: chunk.last_modified,
                })
                .collect(),
        };
        
        // Serialize with bincode
        let encoded = bincode::serialize(&save_data)
            .map_err(|e| format!("Failed to serialize world: {}", e))?;
        
        // Write to file
        let mut file = File::create(path)
            .map_err(|e| format!("Failed to create save file: {}", e))?;
        file.write_all(&encoded)
            .map_err(|e| format!("Failed to write save data: {}", e))?;
        
        println!("Saved world to {}", path);
        Ok(())
    }
    
    pub async fn load_world(&mut self, path: &str) -> Result<(), String> {
        use std::fs::File;
        use std::io::Read;
        
        // Read file
        let mut file = File::open(path)
            .map_err(|e| format!("Failed to open save file: {}", e))?;
        let mut encoded = Vec::new();
        file.read_to_end(&mut encoded)
            .map_err(|e| format!("Failed to read save data: {}", e))?;
        
        // Deserialize
        let save_data: WorldSaveData = bincode::deserialize(&encoded)
            .map_err(|e| format!("Failed to deserialize world: {}", e))?;
        
        // Clear current world
        self.loaded_regions.clear();
        self.active_chunks.clear();
        
        // Load configuration
        self.config = save_data.config;
        
        // Load chunks
        for chunk_data in save_data.chunks {
            // Generate render data
            let render_data = ChunkRenderData {
                vertex_count: chunk_data.compressed_data.dimensions.0 *
                             chunk_data.compressed_data.dimensions.1 *
                             chunk_data.compressed_data.dimensions.2,
                lod_distances: [64.0, 128.0, 256.0, 512.0, 1024.0],
            };
            
            self.active_chunks.insert(chunk_data.id, ActiveChunk {
                id: chunk_data.id,
                compressed_data: chunk_data.compressed_data,
                physics_colliders: vec![], // Will be regenerated
                render_data,
                last_modified: chunk_data.last_modified,
            });
        }
        
        // Mark regions as loaded
        for region_id in save_data.regions {
            self.loaded_regions.insert(region_id, LoadedRegion {
                id: region_id,
                chunks: vec![], // Will be rebuilt
                generation_params: self.create_generation_params(region_id),
            });
        }
        
        // Rebuild renderer data
        let chunks: Vec<_> = self.active_chunks.iter()
            .map(|(chunk_id, chunk)| self.compressed_to_render_chunk(&chunk.compressed_data, *chunk_id))
            .collect();
        self.renderer.add_chunks(chunks).await?;
        
        println!("Loaded world from {}", path);
        Ok(())
    }
}

// Supporting structures
pub struct VoxelModification {
    pub position: Vec3<f32>,
    pub new_voxel: Voxel,
}

pub struct VoxelRaycastHit {
    pub position: Vec3<f32>,
    pub normal: Vec3<f32>,
    pub voxel: Voxel,
    pub chunk_id: ChunkId,
    pub distance: f32,
}

#[derive(serde::Serialize, serde::Deserialize)]
struct WorldSaveData {
    version: u32,
    config: WorldConfig,
    regions: Vec<RegionId>,
    chunks: Vec<ChunkSaveData>,
}

#[derive(serde::Serialize, serde::Deserialize)]
struct ChunkSaveData {
    id: ChunkId,
    compressed_data: CompressedVoxelData,
    last_modified: u64, // timestamp in seconds
}