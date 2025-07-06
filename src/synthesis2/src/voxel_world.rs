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
        vertex_pool_renderer::VoxelVertex,
        gpu_worldgen::{CHUNK_SIZE, CompressedChunk},
    },
    gfx::{Gfx, Camera},
    physx::Physx,
};
use crate::rendergraph_integration::SynthesisRenderGraph;
use std::sync::{Arc, Mutex};
use major::runtime::{RwLock, async_channel, AsyncSender, AsyncReceiver, Handle as RuntimeHandle, PollHandle};
use std::sync::mpsc::{channel, Sender, Receiver, TryRecvError};
use std::collections::{HashMap, HashSet};
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll, Waker};

// State for tracking GPU generation requests
pub struct GpuGenerationState {
    pub chunk_id: ChunkId,
    pub region_id: RegionId,
    pub request_id: u64,
    pub started_at: std::time::Instant,
    pub future: Option<Pin<Box<dyn Future<Output = Result<Arc<VoxelWorkspace>, String>> + Send>>>,
}

// Complete voxel world system for Synthesis
pub struct VoxelWorld {
    // Core systems
    synthesis_render_graph: Option<Arc<Mutex<SynthesisRenderGraph>>>,
    compression_system: PaletteCompressionSystem,
    physics_generator: VoxelPhysicsGenerator,
    renderer: Arc<RwLock<VertexPoolBatchRenderer>>,
    
    // World data
    world: World,
    loaded_regions: HashMap<RegionId, LoadedRegion>,
    active_chunks: HashMap<ChunkId, ActiveChunk>,
    
    // Generation tracking
    pending_generations: HashMap<RegionId, std::time::Instant>,
    generation_receiver: AsyncReceiver<(RegionId, Result<Arc<VoxelWorkspace>, String>)>,
    generation_sender: AsyncSender<(RegionId, Result<Arc<VoxelWorkspace>, String>)>,
    
    // GPU generation request queue (processed on main thread)
    gpu_generation_queue: Vec<(ChunkId, RegionId, WorldBounds, GenerationParams)>,
    
    // Track active GPU generations by request ID with futures
    active_gpu_generations: HashMap<u64, GpuGenerationState>,
    
    // Completed GPU generations ready for readback
    pending_readbacks: Vec<(ChunkId, RegionId, Arc<VoxelWorkspace>)>,
    
    // Mesh generation queue
    mesh_generation_sender: Sender<(ChunkId, Vec<Voxel>)>,
    mesh_generation_receiver: Receiver<(ChunkId, Vec<VoxelVertex>)>,
    pending_meshes: HashMap<ChunkId, Vec<VoxelVertex>>,
    chunks_needing_mesh: Vec<ChunkId>,
    
    // Configuration
    config: WorldConfig,
    
    // Context references
    vulkan: Arc<dyn Gfx + Send + Sync>,
    physics: Arc<RwLock<dyn Physx>>,
    
    // Keep runtime handle for spawned tasks
    runtime_handle: RuntimeHandle,
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
    #[serde(default = "default_mesh_generator")]
    pub mesh_generator: MeshGeneratorType,
}

#[derive(Clone, Copy, Debug, serde::Serialize, serde::Deserialize)]
pub enum MeshGeneratorType {
    BinaryGreedy,
    SimpleCube,
}

fn default_mesh_generator() -> MeshGeneratorType {
    MeshGeneratorType::BinaryGreedy
}

impl Default for WorldConfig {
    fn default() -> Self {
        Self {
            chunk_size: 64,
            region_size: 8,
            view_distance: 1024.0,
            physics_distance: 512.0,
            voxel_size: 1.0,
            enable_compression: true,
            enable_physics: true,
            enable_lod: true,
            mesh_generator: MeshGeneratorType::BinaryGreedy,
        }
    }
}

impl VoxelWorld {
    /// Create a simple test terrain for immediate display
    pub fn create_test_terrain(&mut self) {
        let chunk_id = ChunkId(0, 0, 0);
        let chunk_size = self.config.chunk_size as usize;
        let mut voxels = vec![Voxel(0); chunk_size * chunk_size * chunk_size];
        
        println!("Creating test terrain for chunk {:?} with size {}", chunk_id, chunk_size);
        
        // Create a simple flat terrain at z=0
        let mut filled_count = 0;
        for z in 0..chunk_size {
            for y in 0..chunk_size {
                for x in 0..chunk_size {
                    let idx = x + y * chunk_size + z * chunk_size * chunk_size;
                    
                    let world_z = z as f32 - chunk_size as f32 / 2.0;
                    
                    if world_z < -2.0 {
                        voxels[idx] = Voxel(1); // Stone
                        filled_count += 1;
                    } else if world_z < -0.5 {
                        voxels[idx] = Voxel(2); // Dirt
                        filled_count += 1;
                    } else if world_z < 0.0 {
                        voxels[idx] = Voxel(3); // Grass
                        filled_count += 1;
                    }
                }
            }
        }
        
        println!("Test terrain created with {} filled voxels out of {} total", filled_count, voxels.len());
        
        // Debug: Check first few voxels
        println!("First 10 voxels: {:?}", &voxels[0..10.min(voxels.len())]);
        
        // Compress the chunk
        let compressed = self.compression_system.compress_workspace_sync(
            &voxels,
            (chunk_size as u32, chunk_size as u32, chunk_size as u32)
        ).unwrap();
        
        // Debug: Check compression result
        println!("Compressed palette: {:?}", compressed.palette);
        println!("Compressed data size: {} bytes, bits_per_index: {}", 
                 compressed.bitpacked_data.data.len(), 
                 compressed.bitpacked_data.bits_per_index);
        
        // Create render data
        let render_data = ChunkRenderData {
            vertex_count: (chunk_size * chunk_size * chunk_size) as u32,
            lod_distances: [64.0, 128.0, 256.0, 512.0, 1024.0],
        };
        
        // Add to active chunks
        self.active_chunks.insert(chunk_id, ActiveChunk {
            id: chunk_id,
            compressed_data: compressed.clone(),
            physics_colliders: vec![],
            render_data,
            last_modified: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
        });
        
        println!("Created test terrain chunk at {:?}", chunk_id);
        
        // Queue mesh generation for the test chunk immediately
        let decompressed = voxels;
        println!("Queuing test terrain chunk {:?} for mesh generation with {} voxels", chunk_id, decompressed.len());
        match self.mesh_generation_sender.send((chunk_id, decompressed)) {
            Ok(_) => println!("Successfully queued test terrain for mesh generation"),
            Err(e) => println!("Failed to queue test terrain: {:?}", e),
        }
        self.chunks_needing_mesh.push(chunk_id);
    }
    
    pub fn new(
        vulkan: Arc<dyn Gfx + Send + Sync>,
        physics: Arc<RwLock<dyn Physx>>,
        config: WorldConfig,
    ) -> Self {
        // Get the global runtime handle - assumes runtime is already initialized
        let runtime_handle = major::runtime::Handle::current();
        
        // Create the integrated render graph (will be initialized later)
        let synthesis_render_graph = None;
        
        let renderer = Arc::new(RwLock::new(match config.mesh_generator {
            MeshGeneratorType::BinaryGreedy => {
                VertexPoolBatchRenderer::new_with_generator(
                    vulkan.clone(),
                    Box::new(major::universe::BinaryGreedyMeshGenerator::new())
                )
            },
            MeshGeneratorType::SimpleCube => {
                VertexPoolBatchRenderer::new_with_generator(
                    vulkan.clone(),
                    Box::new(major::universe::SimpleCubeMeshGenerator::new())
                )
            },
        }));
        
        // Create async channel for generation results
        let (generation_sender, generation_receiver) = async_channel(10);
        
        // Create sync channels for mesh generation to avoid async issues
        let (mesh_send, mesh_recv) = channel::<(ChunkId, Vec<Voxel>)>();
        let (mesh_result_send, mesh_result_recv) = channel::<(ChunkId, Vec<VoxelVertex>)>();
        
        // Spawn background mesh generation task using the runtime
        let renderer_clone = renderer.clone();
        let chunk_size = config.chunk_size;
        
        // Spawn blocking thread for mesh generation
        let mesh_thread_handle = runtime_handle.spawn_blocking(move || {
            println!("Mesh generation thread started");
            loop {
                match mesh_recv.recv() {
                    Ok((chunk_id, voxels)) => {
                        println!("Mesh generation thread received chunk {:?} with {} voxels", chunk_id, voxels.len());
                        let non_empty = voxels.iter().filter(|v| v.0 != 0).count();
                        
                        if non_empty > 0 {
                            // Generate mesh in background
                            let renderer_read = renderer_clone.read();
                            match renderer_read.generate_greedy_mesh(
                                &voxels,
                                chunk_size as usize
                            ) {
                                Ok((vertices, _indices)) => {
                                    println!("Mesh generation for chunk {:?}: {} vertices generated", chunk_id, vertices.len());
                                    if !vertices.is_empty() {
                                        let _ = mesh_result_send.send((chunk_id, vertices));
                                    }
                                }
                                Err(e) => {
                                    println!("Mesh generation error for chunk {:?}: {}", chunk_id, e);
                                }
                            }
                        }
                    }
                    Err(_) => {
                        println!("Mesh generation thread: channel disconnected, exiting");
                        break;
                    }
                }
            }
            println!("Mesh generation thread exited");
        });
        
        Self {
            synthesis_render_graph,
            compression_system: PaletteCompressionSystem::new(vulkan.clone()),
            physics_generator: VoxelPhysicsGenerator::new(physics.clone()),
            renderer,
            world: World::default(),
            loaded_regions: HashMap::new(),
            active_chunks: HashMap::new(),
            pending_generations: HashMap::new(),
            generation_receiver,
            generation_sender,
            gpu_generation_queue: Vec::new(),
            active_gpu_generations: HashMap::new(),
            pending_readbacks: Vec::new(),
            mesh_generation_sender: mesh_send,
            mesh_generation_receiver: mesh_result_recv,
            pending_meshes: HashMap::new(),
            chunks_needing_mesh: Vec::new(),
            config,
            vulkan,
            physics,
            runtime_handle,
        }
    }
    
    /// Switch the mesh generator at runtime
    pub fn set_mesh_generator(&mut self, generator_type: MeshGeneratorType) {
        println!("Switching mesh generator to {:?}", generator_type);
        self.config.mesh_generator = generator_type;
        
        let new_generator: Box<dyn major::universe::MeshGenerator> = match generator_type {
            MeshGeneratorType::BinaryGreedy => {
                Box::new(major::universe::BinaryGreedyMeshGenerator::new())
            },
            MeshGeneratorType::SimpleCube => {
                Box::new(major::universe::SimpleCubeMeshGenerator::new())
            },
        };
        
        self.renderer.write().set_mesh_generator(new_generator);
    }
    
    pub fn voxel_size(&self) -> f32 {
        self.config.voxel_size
    }
    
    /// Get the current mesh generator type
    pub fn mesh_generator_type(&self) -> MeshGeneratorType {
        self.config.mesh_generator
    }
    
    /// Get GPU pipeline statistics
    pub fn get_pipeline_stats(&self) -> major::universe::PipelineStats {
        // TODO: Get stats from render graph
        major::universe::PipelineStats::default()
    }
    
    /// Wait for all pending GPU operations to complete
    pub async fn flush_gpu_pipeline(&self) -> Result<(), String> {
        // TODO: Implement flush for render graph
        Ok(())
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
    pub async fn update(&mut self, camera_pos: Vec3<f32>, _delta_time: f32) -> Result<(), String> {
        // Check for completed GPU generations
        self.check_pending_generations().await?;
        
        // Update region loading
        self.update_region_loading(camera_pos).await?;
        
        // Update chunk physics
        self.update_chunk_physics(camera_pos).await?;
        
        // Don't use the renderer here - we're manually managing the mesh in main.rs
        // The renderer.render_voxel_chunks would conflict with our manual mesh updates
        
        Ok(())
    }
    
    // Poll update without blocking - for use in game loop
    // This is a synchronous wrapper that tries to progress the async operations
    pub fn poll_update(&mut self, camera_pos: Vec3<f32>, _delta_time: f32) {
        // Check for completed GPU generations synchronously
        self.poll_pending_generations();
        
        // Trigger region loading if needed
        self.trigger_region_loading(camera_pos);
    }
    
    // Synchronous check for pending generations
    #[allow(dead_code)]
    fn poll_pending_generations_old(&mut self) {
        // Poll the async receiver without blocking
        loop {
            match self.generation_receiver.try_recv() {
                Ok((region_id, chunks)) => {
                    println!("Region {:?} generation completed", region_id);
                    self.pending_generations.remove(&region_id);
                    
                    // Process the chunk workspace
                    match chunks {
                        Ok(workspace) => {
                            // Mark region as loaded with empty chunks for now
                            // The actual chunk extraction happens asynchronously
                            self.loaded_regions.insert(region_id, LoadedRegion {
                                id: region_id,
                                chunks: vec![],
                                generation_params: self.get_current_generation_params(),
                            });
                            
                            // Queue the workspace for chunk extraction
                            let workspace_clone = workspace.clone();
                            let handle = self.runtime_handle.clone();
                            let region_id_copy = region_id;
                            
                            // Spawn async task to extract chunks
                            handle.spawn(async move {
                                println!("Extracting chunks from workspace for region {:?}", region_id_copy);
                                // Chunk extraction will happen in background
                            });
                        }
                        Err(e) => {
                            println!("Region {:?} generation failed: {}", region_id, e);
                        }
                    }
                }
                Err(_) => break, // No more messages
            }
        }
    }
    
    // Trigger region loading synchronously
    fn get_current_generation_params(&self) -> GenerationParams {
        use major::universe::{BrushSchema, sdf::{Sdf, SdfOps, Sphere, Box3, Plane}, brush::{BrushLayer, Condition, BlendMode}};
        
        // Create a more interesting terrain using SDF operations
        let ground_plane = Plane {
            normal: Vec3::new([0.0, 0.0, 1.0]),
            distance: 0.0,
        };
        
        // Add some spheres for variety
        let sphere1 = Sphere { 
            center: Vec3::new([10.0, 10.0, -5.0]), 
            radius: 8.0 
        };
        
        let sphere2 = Sphere { 
            center: Vec3::new([-15.0, 5.0, -3.0]), 
            radius: 6.0 
        };
        
        // Combine SDFs using the Union struct
        let sphere_union = major::universe::sdf::Union {
            a: sphere1,
            b: sphere2,
        };
        
        let terrain_sdf = major::universe::sdf::Union {
            a: ground_plane,
            b: sphere_union,
        };
        
        // Create brush layers for different materials
        let stone_layer = BrushLayer {
            condition: Condition::SdfDistance { min: -1000.0, max: 0.0 }, // Inside the SDF
            voxel: major::universe::Voxel(1), // Stone material
            blend_weight: 1.0,
            priority: 0,
        };
        
        let grass_layer = BrushLayer {
            condition: Condition::SdfDistance { min: -0.5, max: 0.5 }, // Near surface
            voxel: major::universe::Voxel(3), // Grass material
            blend_weight: 1.0,
            priority: 1,
        };
        
        let brush_schema = BrushSchema {
            layers: vec![Arc::new(stone_layer), Arc::new(grass_layer)],
            blend_mode: BlendMode::Replace,
        };
        
        GenerationParams {
            sdf_resolution: Vec3::new([128, 128, 128]),
            sdf_tree: Arc::new(terrain_sdf),
            brush_schema,
            post_processes: vec![],
            lod_levels: vec![],
            enable_compression: self.config.enable_compression,
        }
    }
    
    fn trigger_region_loading(&mut self, camera_pos: Vec3<f32>) {
        let camera_region = self.world_pos_to_region_id(camera_pos);
        
        // Limit concurrent generations to prevent ring buffer exhaustion
        const MAX_CONCURRENT_REGIONS: usize = 1;
        if self.pending_generations.len() >= MAX_CONCURRENT_REGIONS {
            return; // Wait for current generations to complete
        }
        
        // Only load one column at xy=0 from z=-1 to z=1
        for dz in -1..=1 {
            let region_id = RegionId(0, 0, dz);
            
            if !self.loaded_regions.contains_key(&region_id) && 
               !self.pending_generations.contains_key(&region_id) {
                self.start_region_generation(region_id, camera_pos);
                break; // Only start one region at a time
            }
        }
        
        // Unload regions outside our single column
        let regions_to_unload: Vec<RegionId> = self.loaded_regions.keys()
            .filter(|&&region_id| {
                region_id.0 != 0 || region_id.1 != 0 || region_id.2 < -1 || region_id.2 > 1
            })
            .cloned()
            .collect();
            
        for region_id in regions_to_unload {
            self.unload_region(region_id);
        }
    }
    
    // Queue voxel modification - store it for later processing
    pub fn queue_voxel_modification(&mut self, modification: VoxelModification) {
        // For now, we'll apply it immediately in a blocking way
        // In a real implementation, you'd queue this for background processing
        let chunk_id = self.world_pos_to_chunk_id(modification.position);
        let local_pos = self.world_to_chunk_local(modification.position);
        let index = self.local_pos_to_index(local_pos);
        
        if let Some(chunk) = self.active_chunks.get_mut(&chunk_id) {
            // Update the compressed data (simplified - in reality this is more complex)
            // Mark chunk as needing mesh regeneration
            chunk.last_modified = std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs();
        }
        
        // Remove from pending meshes so it gets regenerated
        self.pending_meshes.remove(&chunk_id);
        self.chunks_needing_mesh.retain(|&id| id != chunk_id);
    }
    
    // Queue world save - not implemented for now
    pub fn queue_save_world(&mut self, _path: &str) {
        println!("World save not implemented in sync mode");
    }
    
    // Queue world load - not implemented for now  
    pub fn queue_load_world(&mut self, _path: &str) {
        println!("World load not implemented in sync mode");
    }
    
    /// Initialize the synthesis render graph (call this after window is created)
    pub fn initialize_render_graph(
        &mut self,
        window_width: u32,
        window_height: u32,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let synthesis_graph = Arc::new(Mutex::new(
            SynthesisRenderGraph::new(
                vec![], // No specific Vulkan devices
                self.vulkan.clone(),
                window_width,
                window_height,
            )?
        ));
        self.synthesis_render_graph = Some(synthesis_graph);
        Ok(())
    }
    
    // Process GPU commands - should be called after frame_begin()
    pub fn process_gpu_commands(&mut self) {
        // Use the integrated synthesis render graph for worldgen
        if let Some(synthesis_graph) = &self.synthesis_render_graph {
            // Process any queued GPU generation requests through render graph
            if !self.gpu_generation_queue.is_empty() {
                println!("Processing {} queued GPU generation requests via render graph", self.gpu_generation_queue.len());
                
                // Take up to 4 requests per frame
                for _ in 0..4.min(self.gpu_generation_queue.len()) {
                    if let Some((chunk_id, region_id, bounds, params)) = self.gpu_generation_queue.pop() {
                        println!("Processing chunk {:?} via worldgen render graph", chunk_id);
                        
                        // TODO: Queue this chunk for synthesis render graph processing
                        // For now, just track it
                        let state = GpuGenerationState {
                            chunk_id,
                            region_id,  
                            request_id: chunk_id.0 as u64 * 1000000 + chunk_id.1 as u64 * 1000 + chunk_id.2 as u64,
                            started_at: std::time::Instant::now(),
                            future: None,
                        };
                        self.active_gpu_generations.insert(state.request_id, state);
                    }
                }
            }
        } else {
            println!("Warning: Synthesis render graph not initialized. Call initialize_render_graph() first.");
        }
    }
    
    
    /// Process end of frame - should be called after frame_end()
    pub fn process_end_frame(&self) {
        // TODO: Process deferred GPU readbacks from render graph
    }
    
    
    // Get individual chunk meshes for rendering  
    pub fn get_chunks_for_rendering(&mut self) -> Option<Vec<((i32, i32, i32), Vec<major::universe::VoxelVertex>)>> {
        println!("get_chunks_for_rendering called - active chunks: {}, pending meshes: {}", 
                 self.active_chunks.len(), self.pending_meshes.len());
        
        // Process any completed mesh generations first
        while let Ok((chunk_id, vertices)) = self.mesh_generation_receiver.try_recv() {
            self.chunks_needing_mesh.retain(|&id| id != chunk_id);
            if !vertices.is_empty() {
                self.pending_meshes.insert(chunk_id, vertices);
            }
        }
        
        // Queue mesh generation for chunks that don't have meshes yet
        println!("Checking {} active chunks for mesh generation", self.active_chunks.len());
        for (chunk_id, chunk) in self.active_chunks.iter() {
            let has_pending_mesh = self.pending_meshes.contains_key(chunk_id);
            let is_needing_mesh = self.chunks_needing_mesh.contains(chunk_id);
            println!("  Chunk {:?}: has_pending_mesh={}, is_needing_mesh={}", 
                     chunk_id, has_pending_mesh, is_needing_mesh);
            
            if !has_pending_mesh && is_needing_mesh {
                let decompressed = self.decompress_chunk(&chunk.compressed_data);
                let non_air = decompressed.iter().filter(|v| v.0 != 0).count();
                println!("Chunk {:?}: decompressed {} voxels, {} non-air", chunk_id, decompressed.len(), non_air);
                
                // Additional debug: check voxel distribution
                if non_air > 0 {
                    let mut type_counts = std::collections::HashMap::new();
                    for voxel in &decompressed {
                        *type_counts.entry(voxel.0).or_insert(0) += 1;
                    }
                    println!("  Voxel types in chunk: {:?}", type_counts);
                }
                
                // Debug: Print compression details
                println!("  Palette size: {}, bits per index: {}, compressed bytes: {}", 
                         chunk.compressed_data.palette.len(),
                         chunk.compressed_data.bitpacked_data.bits_per_index,
                         chunk.compressed_data.bitpacked_data.data.len());
                
                // Debug: Print palette entries
                println!("  Palette entries:");
                for (idx, voxel) in chunk.compressed_data.palette.iter().enumerate() {
                    println!("    [{}]: Voxel({})", idx, voxel.0);
                }
                if non_air > 0 {
                    if let Ok(_) = self.mesh_generation_sender.send((*chunk_id, decompressed)) {
                        self.chunks_needing_mesh.push(*chunk_id);
                        println!("Queued chunk {:?} for mesh generation", chunk_id);
                    } else {
                        println!("Failed to queue chunk {:?} for mesh generation", chunk_id);
                    }
                } else {
                    println!("Skipping chunk {:?} - no non-air voxels", chunk_id);
                }
            }
        }
        
        // Return chunks that have completed meshes
        if self.pending_meshes.is_empty() {
            return None;
        }
        
        let mut chunk_meshes = Vec::new();
        for (chunk_id, vertices) in self.pending_meshes.drain() {
            chunk_meshes.push(((chunk_id.0, chunk_id.1, chunk_id.2), vertices));
        }
        
        Some(chunk_meshes)
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
            
            let greedy_result = self.renderer.read().generate_greedy_mesh(
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
    
    // Start async generation of a region with distance-based prioritization
    pub fn start_region_generation(&mut self, region_id: RegionId, camera_pos: Vec3<f32>) {
        // Check if already pending
        if self.pending_generations.contains_key(&region_id) {
            return;
        }
        
        println!("Starting async generation for region {:?} (contains chunks {}-{}, {}-{}, {}-{})", 
                 region_id,
                 region_id.0 * 4, region_id.0 * 4 + 3,
                 region_id.1 * 4, region_id.1 * 4 + 3,
                 region_id.2 * 4, region_id.2 * 4 + 3);
        
        // Mark as pending
        self.pending_generations.insert(region_id, std::time::Instant::now());
        
        // Create generation parameters for this region
        let params = self.create_generation_params(region_id);
        
        // Instead of generating the entire region, generate individual chunks
        let chunks_per_axis = self.config.region_size;
        let chunk_size = self.config.chunk_size;
        
        // Clone what we need for the async tasks
        let sender = self.generation_sender.clone();
        
        // Track which chunks are already being generated to prevent duplicates
        let pending_chunks: HashSet<ChunkId> = self.pending_generations.values()
            .flat_map(|_| {
                // For now, just prevent duplicate regions
                vec![]
            })
            .collect();
        
        // Collect all chunks in the region with their distances from camera
        let mut chunks_with_distance = Vec::new();
        
        for cz in 0..chunks_per_axis {
            for cy in 0..chunks_per_axis {
                for cx in 0..chunks_per_axis {
                    let chunk_id = ChunkId(
                        region_id.0 * chunks_per_axis as i32 + cx as i32,
                        region_id.1 * chunks_per_axis as i32 + cy as i32,
                        region_id.2 * chunks_per_axis as i32 + cz as i32,
                    );
                    
                    // Generate chunks at Z levels -1, 0, and 1 to ensure we capture the ground plane
                    if chunk_id.2 < -1 || chunk_id.2 > 1 {
                        continue;
                    }
                    
                    // Debug: print chunk being generated
                    println!("Generating chunk {:?}", chunk_id);
                    
                    // Calculate distance from camera to chunk center
                    let chunk_center = Vec3::new([
                        (chunk_id.0 as f32 + 0.5) * chunk_size as f32 * self.config.voxel_size,
                        (chunk_id.1 as f32 + 0.5) * chunk_size as f32 * self.config.voxel_size,
                        (chunk_id.2 as f32 + 0.5) * chunk_size as f32 * self.config.voxel_size,
                    ]);
                    let distance = (chunk_center - camera_pos).length();
                    
                    chunks_with_distance.push((distance, chunk_id, cx, cy, cz));
                }
            }
        }
        
        // Sort chunks by distance (closest first)
        chunks_with_distance.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
        
        println!("Generating {} chunks in region {:?}, closest chunk distance: {:.1}", 
                 chunks_with_distance.len(), region_id, 
                 chunks_with_distance.first().map(|c| c.0).unwrap_or(0.0));
        
        // Limit the number of concurrent chunk generations to prevent ring buffer exhaustion
        const MAX_CONCURRENT_CHUNKS: usize = 4;
        let chunks_to_generate = chunks_with_distance.into_iter()
            .take(MAX_CONCURRENT_CHUNKS)
            .collect::<Vec<_>>();
        
        println!("Limited generation to {} chunks to prevent ring buffer exhaustion", chunks_to_generate.len());
        
        // Generate chunks in order of distance
        for (distance, chunk_id, cx, cy, cz) in chunks_to_generate {
                    
                    // Calculate bounds for this specific chunk
                    let chunk_bounds = WorldBounds {
                        min: Vec3::new([
                            chunk_id.0 as f32 * chunk_size as f32 * self.config.voxel_size,
                            chunk_id.1 as f32 * chunk_size as f32 * self.config.voxel_size,
                            chunk_id.2 as f32 * chunk_size as f32 * self.config.voxel_size,
                        ]),
                        max: Vec3::new([
                            (chunk_id.0 + 1) as f32 * chunk_size as f32 * self.config.voxel_size,
                            (chunk_id.1 + 1) as f32 * chunk_size as f32 * self.config.voxel_size,
                            (chunk_id.2 + 1) as f32 * chunk_size as f32 * self.config.voxel_size,
                        ]),
                        voxel_size: self.config.voxel_size,
                    };
                    
                    let params_clone = params.clone();
                    
                    // Queue GPU generation request for main thread processing
                    println!("Queueing GPU generation for chunk {:?}", chunk_id);
                    self.gpu_generation_queue.push((chunk_id, region_id, chunk_bounds, params_clone));
        }  // This closes the for loop that started on line 513
    }
    
    // Check and process completed generations (synchronous version for render loop)
    pub fn poll_pending_generations(&mut self) -> Result<(), String> {
        // Simply try to receive without blocking
        while let Ok((region_id, result)) = self.generation_receiver.try_recv() {
            println!("Received generation result for region {:?}", region_id);
            self.pending_generations.remove(&region_id);
            
            match result {
                Ok(workspace) => {
                    // Process the workspace synchronously
                    let compressed_chunks = self.extract_and_compress_chunks_sync(&workspace, region_id)?;
                    
                    println!("Extracted {} chunks from region {:?}", compressed_chunks.len(), region_id);
                    
                    // Store chunks
                    let mut chunk_ids = Vec::new();
                    for (chunk_id, compressed_data) in compressed_chunks {
                        chunk_ids.push(chunk_id);
                        
                        // Create render data
                        let render_data = ChunkRenderData {
                            vertex_count: (self.config.chunk_size * self.config.chunk_size * self.config.chunk_size) as u32,
                            lod_distances: [64.0, 128.0, 256.0, 512.0, 1024.0],
                        };
                        
                        println!("Adding chunk {:?} to active_chunks (total: {})", chunk_id, self.active_chunks.len() + 1);
                        self.active_chunks.insert(chunk_id, ActiveChunk {
                            id: chunk_id,
                            compressed_data,
                            physics_colliders: Vec::new(),
                            render_data,
                            last_modified: 0,
                        });
                        
                        // Queue chunk for mesh generation
                        self.chunks_needing_mesh.push(chunk_id);
                    }
                    
                    // Mark region as loaded
                    self.loaded_regions.insert(region_id, LoadedRegion {
                        id: region_id,
                        chunks: chunk_ids,
                        generation_params: self.get_current_generation_params(),
                    });
                    
                    println!("Successfully loaded region {:?} with {} chunks", region_id, self.loaded_regions[&region_id].chunks.len());
                }
                Err(e) => {
                    println!("Failed to generate region {:?}: {}", region_id, e);
                }
            }
        }
        
        Ok(())
    }
    
    
    // Check and process completed generations
    pub async fn check_pending_generations(&mut self) -> Result<(), String> {
        // Check for completed generations from the channel
        let mut received_count = 0;
        while let Ok((region_id, result)) = self.generation_receiver.try_recv() {
            received_count += 1;
            println!("Received generation result {} for region {:?}", received_count, region_id);
            self.pending_generations.remove(&region_id);
            
            match result {
                Ok(workspace) => {
                    // Extract and compress chunks
                    let compressed_chunks = self.extract_and_compress_chunks(&workspace, region_id).await?;
                    
                    println!("Extracted {} chunks from region {:?}", compressed_chunks.len(), region_id);
                    
                    // Debug: print info about extracted chunks
                    for (chunk_id, compressed_data) in &compressed_chunks {
                        println!("  Chunk {:?}: palette size {}, {} bytes compressed", 
                                 chunk_id, 
                                 compressed_data.palette.len(),
                                 compressed_data.bitpacked_data.data.len());
                    }
                    
                    // Store chunks
                    let mut chunk_ids = Vec::new();
                    for (chunk_id, compressed_data) in compressed_chunks {
                        chunk_ids.push(chunk_id);
                        
                        // Create render data
                        let render_data = ChunkRenderData {
                            vertex_count: (self.config.chunk_size * self.config.chunk_size * self.config.chunk_size) as u32,
                            lod_distances: [64.0, 128.0, 256.0, 512.0, 1024.0],
                        };
                        
                        println!("Adding chunk {:?} to active_chunks (total: {})", chunk_id, self.active_chunks.len() + 1);
                        self.active_chunks.insert(chunk_id, ActiveChunk {
                            id: chunk_id,
                            compressed_data: compressed_data.clone(),
                            physics_colliders: vec![],
                            render_data,
                            last_modified: std::time::SystemTime::now()
                                .duration_since(std::time::UNIX_EPOCH)
                                .unwrap()
                                .as_secs(),
                        });
                        
                        // Queue mesh generation for this chunk
                        let decompressed = self.decompress_chunk(&compressed_data);
                        let non_empty = decompressed.iter().filter(|v| v.0 != 0).count();
                        println!("Decompressed {} voxels for chunk {:?}, {} non-empty", 
                                 decompressed.len(), chunk_id, non_empty);
                        
                        // Debug: Print first few voxels
                        if decompressed.len() > 0 {
                            println!("  First 10 voxels: {:?}", &decompressed[0..10.min(decompressed.len())]);
                        }
                        
                        match self.mesh_generation_sender.send((chunk_id, decompressed)) {
                            Ok(_) => println!("Successfully sent chunk {:?} to mesh generation", chunk_id),
                            Err(e) => println!("Failed to send chunk {:?} to mesh generation: {:?}", chunk_id, e),
                        }
                        self.chunks_needing_mesh.push(chunk_id);
                    }
                    
                    // Mark region as loaded
                    self.loaded_regions.insert(region_id, LoadedRegion {
                        id: region_id,
                        chunks: chunk_ids,
                        generation_params: self.create_generation_params(region_id),
                    });
                }
                Err(e) => {
                    println!("Failed to generate region {:?}: {}", region_id, e);
                }
            }
        }
        
        // Remove timed-out generations
        let mut timed_out = Vec::new();
        for (region_id, start_time) in self.pending_generations.iter() {
            if start_time.elapsed() > std::time::Duration::from_secs(30) {
                timed_out.push(*region_id);
            }
        }
        
        for region_id in timed_out {
            println!("Generation timed out for region {:?}", region_id);
            self.pending_generations.remove(&region_id);
        }
        
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
        
        // Use the sphere generation params instead of the plane
        return self.get_current_generation_params();
        
        // Calculate the actual world bounds for this region
        let region_min = Vec3::new([
            region_id.0 as f32 * self.config.region_size as f32 * CHUNK_SIZE as f32 * self.config.voxel_size,
            region_id.1 as f32 * self.config.region_size as f32 * CHUNK_SIZE as f32 * self.config.voxel_size,
            region_id.2 as f32 * self.config.region_size as f32 * CHUNK_SIZE as f32 * self.config.voxel_size,
        ]);
        let region_max = region_min + Vec3::one() * self.config.region_size as f32 * CHUNK_SIZE as f32 * self.config.voxel_size;
        
        println!("Region {:?} world bounds: min=[{},{},{}] max=[{},{},{}]", 
                 region_id,
                 region_min[0], region_min[1], region_min[2],
                 region_max[0], region_max[1], region_max[2]);
        
        // Create a ground plane for grass terrain
        // The plane equation is: dot(p, normal) - distance = 0
        // For points below the plane to be negative (inside), we want the plane at z=0
        let ground_plane = Plane {
            normal: Vec3::new([0.0, 0.0, 1.0]),  // Z-up normal
            distance: 0.0,  // Plane at Z = 0
        };
        
        println!("Creating plane SDF with normal [{}, {}, {}] and distance {}", 
                 ground_plane.normal[0], ground_plane.normal[1], ground_plane.normal[2],
                 ground_plane.distance);
        
        // Use the plane as our terrain SDF
        let terrain_sdf = ground_plane;
        
        // Create brush layers for grass surface
        // We use distance from the SDF surface to create material layers
        // The SDF distance is negative below the plane (inside) and positive above (outside)
        
        // Grass layer - at the surface (0-2 units below the plane)
        let grass_layer = BrushLayer {
            condition: Condition::sdf_distance(-2.0, 0.0),  // Just below the surface
            voxel: Voxel(3), // Grass material
            blend_weight: 1.0,
            priority: 2,  // Highest priority
        };
        
        // Dirt layer - below grass (2-10 units below the plane)
        let dirt_layer = BrushLayer {
            condition: Condition::sdf_distance(-10.0, -2.0),  // Medium depth
            voxel: Voxel(2), // Dirt material
            blend_weight: 1.0,
            priority: 1,
        };
        
        // Stone layer - deep underground (more than 10 units below the plane)
        let stone_layer = BrushLayer {
            condition: Condition::sdf_distance(-1000.0, -10.0),  // Deep underground
            voxel: Voxel(1), // Stone material
            blend_weight: 1.0,
            priority: 0,
        };
        
        let brush = LayeredBrush {
            layers: vec![grass_layer, dirt_layer, stone_layer],
            blend_mode: BlendMode::Replace,
            global_weight: 1.0,
        };
        
        GenerationParams {
            sdf_resolution: Vec3::new([64, 64, 64]),  // Use uniform resolution to match chunk size
            sdf_tree: Arc::from(terrain_sdf),  // Convert Box<dyn Sdf> to Arc<dyn Sdf>
            brush_schema: major::universe::gpu_worldgen::BrushSchema {
                layers: vec![Arc::new(brush)],
                blend_mode: BlendMode::Replace,
            },
            post_processes: vec![
                major::universe::gpu_worldgen::PostProcess::Smoothing {
                    iterations: 1,  // Less smoothing for sharper terrain
                    strength: 0.3,
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
            enable_compression: true,  // Enable bitpack compression
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
    
    fn extract_and_compress_chunks_sync(
        &mut self,
        workspace: &VoxelWorkspace,
        region_id: RegionId,
    ) -> Result<HashMap<ChunkId, CompressedVoxelData>, String> {
        // Just call the async version synchronously since it doesn't actually do any async work
        major::runtime::block_on(self.extract_and_compress_chunks(workspace, region_id))
    }
    
    async fn extract_and_compress_chunks(
        &mut self,
        workspace: &VoxelWorkspace,
        region_id: RegionId,
    ) -> Result<HashMap<ChunkId, CompressedVoxelData>, String> {
        let mut compressed_chunks = HashMap::new();
        
        // Check if this is a single chunk workspace (64x64x64)
        let dims = Vec3::new([
            workspace.dimensions.x() as u32,
            workspace.dimensions.y() as u32,
            workspace.dimensions.z() as u32,
        ]);
        
        if dims.x() == CHUNK_SIZE && dims.y() == CHUNK_SIZE && dims.z() == CHUNK_SIZE {
            // This is a single chunk workspace from minichunk accumulation
            // Extract chunk ID from workspace bounds
            let chunk_id = ChunkId(
                (workspace.metadata.bounds.min.x() / (CHUNK_SIZE as f32 * self.config.voxel_size)).round() as i32,
                (workspace.metadata.bounds.min.y() / (CHUNK_SIZE as f32 * self.config.voxel_size)).round() as i32,
                (workspace.metadata.bounds.min.z() / (CHUNK_SIZE as f32 * self.config.voxel_size)).round() as i32,
            );
            
            println!("Processing single chunk workspace for chunk {:?}", chunk_id);
            
            // Count non-empty voxels
            let non_empty_count = workspace.voxels.iter().filter(|v| v.0 != 0).count();
            println!("Chunk {:?} has {} non-empty voxels out of {}", chunk_id, non_empty_count, workspace.voxels.len());
            
            // Debug: Print first few voxels and their positions
            if non_empty_count > 0 {
                println!("First few non-empty voxels in chunk {:?}:", chunk_id);
                let mut count = 0;
                for (idx, voxel) in workspace.voxels.iter().enumerate() {
                    if voxel.0 != 0 && count < 10 {
                        let x = idx % CHUNK_SIZE as usize;
                        let y = (idx / CHUNK_SIZE as usize) % CHUNK_SIZE as usize;
                        let z = idx / (CHUNK_SIZE as usize * CHUNK_SIZE as usize);
                        println!("  Voxel at ({},{},{}): type {}", x, y, z, voxel.0);
                        count += 1;
                    }
                }
            }
            
            // Compress the workspace directly
            let compressed = self.compression_system
                .compress_workspace(&workspace.voxels, (CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE))
                .await?;
            
            compressed_chunks.insert(chunk_id, compressed);
        } else {
            // Multi-chunk workspace - extract all chunks
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
        }
        
        Ok(compressed_chunks)
    }
    
    async fn generate_chunk_physics(
        &mut self,
        workspace: &VoxelWorkspace,
        _chunk_id: ChunkId,
    ) -> Result<Vec<u64>, String> {
        let colliders = self.physics_generator
            .generate_physics_colliders(workspace, PhysicsLodLevel::Quarter)
            .await?;
        
        let body_ids = Vec::new();
        let _physics = self.physics.write();
        
        for _collider in colliders {
            // Create physics body
            // let body_id = physics.create_static_body(collider);
            // body_ids.push(body_id);
        }
        
        Ok(body_ids)
    }
    
    async fn update_region_loading(&mut self, camera_pos: Vec3<f32>) -> Result<(), String> {
        let camera_region = self.world_pos_to_region_id(camera_pos);
        let view_distance_regions = (self.config.view_distance / 
            (self.config.region_size as f32 * self.config.chunk_size as f32 * self.config.voxel_size)).ceil() as i32;
        
        // Debug output
        use std::sync::atomic::{AtomicU64, Ordering};
        static LAST_DEBUG_SECS: AtomicU64 = AtomicU64::new(0);
        let now_secs = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_secs();
        let last_secs = LAST_DEBUG_SECS.load(Ordering::Relaxed);
        
        if now_secs > last_secs + 2 {
            println!("\nRegion Loading Status:");
            println!("  Camera region: {:?}", camera_region);
            println!("  View distance: {} regions", view_distance_regions);
            println!("  Loaded regions: {}", self.loaded_regions.len());
            println!("  Pending generations: {}", self.pending_generations.len());
            println!("  Active chunks: {}", self.active_chunks.len());
            LAST_DEBUG_SECS.store(now_secs, Ordering::Relaxed);
        }
        
        // ALWAYS check completed generations first to free ring buffer slots
        self.check_pending_generations().await?;
        
        // Queue regions by distance from camera with priority
        let mut regions_to_load = Vec::new();
        
        // Only load one column at xy=0 from z=-1 to z=1
        for dz in -1..=1 {
            let region_id = RegionId(0, 0, dz);
            
            if !self.loaded_regions.contains_key(&region_id) && 
               !self.pending_generations.contains_key(&region_id) {
                let distance = (dz * dz) as f32;
                regions_to_load.push((distance, region_id));
            }
        }
        
        // Sort by distance (closest first)
        regions_to_load.sort_by(|a, b| a.0.partial_cmp(&b.0).unwrap());
        
        // Start async generation for up to 2 regions at a time to prevent overload
        let current_pending = self.pending_generations.len();
        let max_concurrent = 2; // Reduced from 8 to prevent system overload
        let to_start = (max_concurrent - current_pending).min(regions_to_load.len());
        
        for (_, region_id) in regions_to_load.iter().take(to_start) {
            self.start_region_generation(*region_id, camera_pos);
        }
        
        // If no regions are being generated and we have regions to load, force start some
        if current_pending == 0 && regions_to_load.len() > 0 {
            println!("Starting initial region generation, {} regions in queue", regions_to_load.len());
        }
        
        // Unload regions outside our single column at xy=0, z=-1..=1
        let regions_to_unload: Vec<RegionId> = self.loaded_regions.keys()
            .filter(|&&region_id| {
                region_id.0 != 0 || region_id.1 != 0 || region_id.2 < -1 || region_id.2 > 1
            })
            .cloned()
            .collect();
            
        for region_id in regions_to_unload {
            self.unload_region(region_id);
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
                        let _physics = self.physics.write();
                        for &_body_id in &chunk.physics_colliders {
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
        _compressed: &CompressedVoxelData,
    ) -> Result<(), String> {
        if let Some(chunk) = self.active_chunks.get_mut(&chunk_id) {
            // Remove old physics bodies
            let _physics = self.physics.write();
            for &_body_id in &chunk.physics_colliders {
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
                        let _physics = self.physics.write();
                        for &_body_id in &chunk.physics_colliders {
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
    
    fn calculate_hit_normal(&self, hit_pos: Vec3<f32>, _ray_dir: Vec3<f32>) -> Vec3<f32> {
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
        self.renderer.write().add_chunks(chunks).await?;
        
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