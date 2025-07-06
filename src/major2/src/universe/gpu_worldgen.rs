use crate::math::Vec3;
use crate::gfx::Gfx;
use super::{Voxel, brush::Brush};
use super::gpu_thread_executor::{GpuThreadExecutor, MainThreadCommand};
use super::adaptive_worldgen::AsyncWorldgenProcessor;
use std::sync::{Arc, RwLock, Mutex};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, AtomicUsize, Ordering};
use std::sync::mpsc;

// Minichunk size for incremental generation
pub const MINICHUNK_SIZE: u32 = 8; // 8x8x8 = 512 voxels per minichunk
pub const CHUNK_SIZE: u32 = 64; // Standard chunk size

// Chunk identifier
#[derive(Clone, Copy, Debug, Hash, Eq, PartialEq)]
pub struct ChunkId(pub i32, pub i32, pub i32);

// Minichunk accumulator for building up chunks incrementally
pub struct ChunkAccumulator {
    pub voxels: Vec<Voxel>,  // 64x64x64 voxel storage
    pub completed_minichunks: Arc<AtomicUsize>,
    pub total_minichunks: usize,
}

impl ChunkAccumulator {
    pub fn new() -> Self {
        let voxel_count = (CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE) as usize;
        let minichunks_per_axis = CHUNK_SIZE / MINICHUNK_SIZE;
        let total_minichunks = (minichunks_per_axis * minichunks_per_axis * minichunks_per_axis) as usize;
        
        println!("Creating ChunkAccumulator: {} voxels, {} minichunks ({} per axis)",
                voxel_count, total_minichunks, minichunks_per_axis);
        
        // Initialize with a debug pattern to verify proper stitching
        // Air (0) by default, will be overwritten by minichunk data
        let mut voxels = vec![Voxel(0); voxel_count];
        
        Self {
            voxels,
            completed_minichunks: Arc::new(AtomicUsize::new(0)),
            total_minichunks,
        }
    }
    
    pub fn add_minichunk(&mut self, minichunk_offset: Vec3<u32>, minichunk_data: &[Voxel]) {
        // Calculate where this minichunk goes in the full chunk
        let base_x = minichunk_offset.x() as usize;
        let base_y = minichunk_offset.y() as usize;
        let base_z = minichunk_offset.z() as usize;
        
        // Validate offset is aligned to minichunk boundaries
        if base_x % MINICHUNK_SIZE as usize != 0 || 
           base_y % MINICHUNK_SIZE as usize != 0 || 
           base_z % MINICHUNK_SIZE as usize != 0 {
            println!("WARNING: Minichunk offset not aligned: ({}, {}, {})", base_x, base_y, base_z);
        }
        
        // Validate minichunk data size
        let expected_size = (MINICHUNK_SIZE * MINICHUNK_SIZE * MINICHUNK_SIZE) as usize;
        if minichunk_data.len() != expected_size {
            println!("WARNING: Minichunk data size mismatch: {} vs expected {}", 
                    minichunk_data.len(), expected_size);
        }
        
        // Count non-empty voxels for debugging
        let non_empty = minichunk_data.iter().filter(|v| v.0 != 0).count();
        if non_empty > 0 {
            println!("Adding minichunk at offset ({}, {}, {}) with {} non-empty voxels", 
                    base_x, base_y, base_z, non_empty);
        }
        
        // Copy minichunk data into the appropriate position
        let mut idx = 0;
        for z in 0..MINICHUNK_SIZE as usize {
            for y in 0..MINICHUNK_SIZE as usize {
                for x in 0..MINICHUNK_SIZE as usize {
                    let chunk_x = base_x + x;
                    let chunk_y = base_y + y;
                    let chunk_z = base_z + z;
                    
                    if chunk_x < CHUNK_SIZE as usize && 
                       chunk_y < CHUNK_SIZE as usize && 
                       chunk_z < CHUNK_SIZE as usize {
                        let chunk_idx = chunk_z * (CHUNK_SIZE as usize * CHUNK_SIZE as usize) +
                                       chunk_y * CHUNK_SIZE as usize +
                                       chunk_x;
                        self.voxels[chunk_idx] = minichunk_data[idx];
                    } else {
                        println!("WARNING: Minichunk voxel out of bounds: ({}, {}, {})", 
                                chunk_x, chunk_y, chunk_z);
                    }
                    idx += 1;
                }
            }
        }
        
        let completed = self.completed_minichunks.fetch_add(1, Ordering::Relaxed) + 1;
        println!("Minichunk {}/{} completed", completed, self.total_minichunks);
    }
    
    pub fn is_complete(&self) -> bool {
        self.completed_minichunks.load(Ordering::Relaxed) >= self.total_minichunks
    }
    
    pub fn progress(&self) -> f32 {
        self.completed_minichunks.load(Ordering::Relaxed) as f32 / self.total_minichunks as f32
    }
}

#[derive(Clone, Copy)]
pub struct WorldBounds {
    pub min: Vec3<f32>,
    pub max: Vec3<f32>,
    pub voxel_size: f32,
}

impl WorldBounds {
    pub fn voxel_count(&self) -> usize {
        let size = self.max - self.min;
        let voxels_x = (size.x() / self.voxel_size).ceil() as usize;
        let voxels_y = (size.y() / self.voxel_size).ceil() as usize;
        let voxels_z = (size.z() / self.voxel_size).ceil() as usize;
        voxels_x * voxels_y * voxels_z
    }
    
    pub fn dimensions(&self) -> (u32, u32, u32) {
        let size = self.max - self.min;
        (
            (size.x() / self.voxel_size).ceil() as u32,
            (size.y() / self.voxel_size).ceil() as u32,
            (size.z() / self.voxel_size).ceil() as u32,
        )
    }
    
    /// Split bounds into minichunks for incremental generation
    pub fn split_into_minichunks(&self) -> Vec<WorldBounds> {
        let dims = self.dimensions();
        let mut minichunks = Vec::new();
        
        for z in (0..dims.2).step_by(MINICHUNK_SIZE as usize) {
            for y in (0..dims.1).step_by(MINICHUNK_SIZE as usize) {
                for x in (0..dims.0).step_by(MINICHUNK_SIZE as usize) {
                    let min_x = self.min.x() + (x as f32 * self.voxel_size);
                    let min_y = self.min.y() + (y as f32 * self.voxel_size);
                    let min_z = self.min.z() + (z as f32 * self.voxel_size);
                    
                    let max_x = (self.min.x() + ((x + MINICHUNK_SIZE.min(dims.0 - x)) as f32 * self.voxel_size)).min(self.max.x());
                    let max_y = (self.min.y() + ((y + MINICHUNK_SIZE.min(dims.1 - y)) as f32 * self.voxel_size)).min(self.max.y());
                    let max_z = (self.min.z() + ((z + MINICHUNK_SIZE.min(dims.2 - z)) as f32 * self.voxel_size)).min(self.max.z());
                    
                    minichunks.push(WorldBounds {
                        min: Vec3::new([min_x, min_y, min_z]),
                        max: Vec3::new([max_x, max_y, max_z]),
                        voxel_size: self.voxel_size,
                    });
                }
            }
        }
        
        minichunks
    }
}

#[derive(Clone)]
pub struct GenerationParams {
    pub sdf_resolution: Vec3<u32>,
    pub sdf_tree: Arc<dyn super::sdf::Sdf>,  // Add the SDF tree
    pub brush_schema: BrushSchema,
    pub post_processes: Vec<PostProcess>,
    pub lod_levels: Vec<LodLevel>,
    pub enable_compression: bool,
}

impl GenerationParams {
    pub fn to_bytes(&self) -> Vec<u8> {
        // Serialize generation parameters for GPU
        let mut bytes = Vec::new();
        
        // The shader expects BrushParams structure:
        // vec4 bounds_min (not used here - that's in WorldParams)
        // vec4 bounds_max (not used here - that's in WorldParams)
        // uvec4 resolution (SDF resolution)
        // uvec4 layer_count
        
        // Write dummy bounds (16 bytes each) - actual bounds are in WorldParams
        bytes.extend_from_slice(&[0u8; 32]);
        
        // Write resolution (16 bytes - uvec4 in shader)
        bytes.extend_from_slice(&self.sdf_resolution.x().to_le_bytes());
        bytes.extend_from_slice(&self.sdf_resolution.y().to_le_bytes());
        bytes.extend_from_slice(&self.sdf_resolution.z().to_le_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes()); // padding
        
        // Write layer count (16 bytes - uvec4 in shader)
        let layer_count = self.brush_schema.layers.len() as u32;
        println!("GenerationParams::to_bytes - layer_count: {}", layer_count);
        bytes.extend_from_slice(&layer_count.to_le_bytes());
        bytes.extend_from_slice(&0u32.to_le_bytes()); // padding
        bytes.extend_from_slice(&0u32.to_le_bytes()); // padding
        bytes.extend_from_slice(&0u32.to_le_bytes()); // padding
        
        // Pad to at least 64 bytes for compatibility
        while bytes.len() < 64 {
            bytes.push(0);
        }
        
        println!("GenerationParams::to_bytes - total size: {} bytes", bytes.len());
        bytes
    }
}

// World parameters for GPU
#[derive(Clone, Copy)]
pub struct WorldParams {
    pub bounds_min: Vec3<f32>,
    pub bounds_max: Vec3<f32>,
    pub voxel_size: f32,
    pub resolution: Vec3<f32>,
}

impl WorldParams {
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut bytes = Vec::with_capacity(64);
        
        // Write bounds_min (12 bytes)
        bytes.extend_from_slice(&self.bounds_min.x().to_le_bytes());
        bytes.extend_from_slice(&self.bounds_min.y().to_le_bytes());
        bytes.extend_from_slice(&self.bounds_min.z().to_le_bytes());
        
        // Write bounds_max (12 bytes)
        bytes.extend_from_slice(&self.bounds_max.x().to_le_bytes());
        bytes.extend_from_slice(&self.bounds_max.y().to_le_bytes());
        bytes.extend_from_slice(&self.bounds_max.z().to_le_bytes());
        
        // Write voxel_size (4 bytes)
        bytes.extend_from_slice(&self.voxel_size.to_le_bytes());
        
        // Write resolution (12 bytes)
        bytes.extend_from_slice(&self.resolution.x().to_le_bytes());
        bytes.extend_from_slice(&self.resolution.y().to_le_bytes());
        bytes.extend_from_slice(&self.resolution.z().to_le_bytes());
        
        // Pad to 64 bytes
        bytes.resize(64, 0);
        bytes
    }
}

#[derive(Clone)]
pub struct BrushSchema {
    pub layers: Vec<Arc<dyn Brush>>,
    pub blend_mode: super::brush::BlendMode,
}

impl BrushSchema {
    /// Convert brush layers to GPU format using the brush compiler
    pub fn to_gpu_bytes(&self) -> (Vec<u8>, Vec<u8>) {
        use super::brush_compiler::BrushCompiler;
        
        let mut compiler = BrushCompiler::new();
        match compiler.compile_schema(self) {
            Ok((instructions, layers)) => (instructions, layers),
            Err(e) => {
                panic!("FATAL: Failed to compile brush schema: {}. Synthesis must provide valid world generation parameters.", e);
            }
        }
    }
}

#[derive(Clone)]
pub enum PostProcess {
    Smoothing { iterations: u32, strength: f32 },
    Erosion { iterations: u32, strength: f32 },
    Dilation { iterations: u32, strength: f32 },
    AmbientOcclusion { radius: f32, samples: u32 },
}

#[derive(Clone)]
pub struct LodLevel {
    pub distance: f32,
    pub simplification: f32,
}

#[derive(Clone)]
pub struct VoxelWorkspace {
    pub voxels: Vec<Voxel>,
    pub dimensions: Vec3<f32>,
    pub metadata: WorkspaceMetadata,
}

#[derive(Clone)]
pub struct WorkspaceMetadata {
    pub bounds: WorldBounds,
    pub generation_time: std::time::Duration,
    pub voxel_count: usize,
    pub non_empty_count: usize,
}

impl VoxelWorkspace {
    pub fn from_gpu_buffer(
        buffer: Vec<Voxel>,
        bounds: WorldBounds,
        generation_time: std::time::Duration,
    ) -> Self {
        let dimensions = bounds.dimensions();
        let non_empty_count = buffer.iter().filter(|v| v.0 != 0).count();
        
        let metadata = WorkspaceMetadata {
            bounds,
            generation_time,
            voxel_count: buffer.len(),
            non_empty_count,
        };
        
        Self {
            voxels: buffer,
            dimensions: Vec3::new([dimensions.0 as f32, dimensions.1 as f32, dimensions.2 as f32]),
            metadata,
        }
    }
    
    pub fn extract_all_chunks(&self) -> Vec<CompressedChunk> {
        // Extract 64x64x64 chunks from workspace
        let chunk_size = 64;
        let dims_u32 = Vec3::new([
            self.dimensions.x() as u32,
            self.dimensions.y() as u32,
            self.dimensions.z() as u32,
        ]);
        let chunks_x = (dims_u32.x() + chunk_size - 1) / chunk_size;
        let chunks_y = (dims_u32.y() + chunk_size - 1) / chunk_size;
        let chunks_z = (dims_u32.z() + chunk_size - 1) / chunk_size;
        
        let mut chunks = Vec::new();
        
        for cz in 0..chunks_z {
            for cy in 0..chunks_y {
                for cx in 0..chunks_x {
                    let chunk_data = self.extract_chunk(cx, cy, cz, chunk_size);
                    let chunk_pos = Vec3::new([cx as i32, cy as i32, cz as i32]);
                    if let Some(compressed) = compress_chunk_with_position(chunk_data, chunk_pos) {
                        chunks.push(compressed);
                    }
                }
            }
        }
        
        chunks
    }
    
    fn extract_chunk(&self, cx: u32, cy: u32, cz: u32, size: u32) -> Vec<Voxel> {
        let mut chunk_data = vec![Voxel(0); (size * size * size) as usize];
        
        for z in 0..size {
            for y in 0..size {
                for x in 0..size {
                    let wx = cx * size + x;
                    let wy = cy * size + y;
                    let wz = cz * size + z;
                    
                    let dims_u32 = Vec3::new([
                        self.dimensions.x() as u32,
                        self.dimensions.y() as u32,
                        self.dimensions.z() as u32,
                    ]);
                    if wx < dims_u32.x() && wy < dims_u32.y() && wz < dims_u32.z() {
                        let world_idx = (wz * dims_u32.y() * dims_u32.x() +
                                       wy * dims_u32.x() + wx) as usize;
                        let chunk_idx = (z * size * size + y * size + x) as usize;
                        chunk_data[chunk_idx] = self.voxels[world_idx];
                    }
                }
            }
        }
        
        chunk_data
    }
}

pub struct CompressedChunk {
    pub position: Vec3<i32>,
    pub palette: Vec<Voxel>,
    pub indices: BitpackedData,
    pub metadata: ChunkMetadata,
}

#[derive(Clone)]
pub struct BitpackedData {
    pub data: Vec<u8>,
    pub bits_per_index: u8,
}

pub struct ChunkMetadata {
    pub has_surface: bool,
    pub lod_levels: Vec<LodData>,
}

pub struct LodData {
    pub level: u32,
    pub simplified_data: Vec<u8>,
}

fn compress_chunk_with_position(data: Vec<Voxel>, position: Vec3<i32>) -> Option<CompressedChunk> {
    // Build palette
    let mut palette_map = HashMap::new();
    let mut palette = Vec::new();
    
    for voxel in &data {
        if !palette_map.contains_key(voxel) {
            palette_map.insert(*voxel, palette.len() as u8);
            palette.push(*voxel);
        }
    }
    
    if palette.is_empty() {
        return None;
    }
    
    // Calculate bits needed
    // When palette has only 1 entry, we still need 0 bits (special case handled in decompression)
    let bits_per_index = if palette.len() <= 1 {
        0
    } else {
        (palette.len() as f32).log2().ceil() as u8
    };
    
    // Bitpack indices
    let indices = bitpack_indices(&data, &palette_map, bits_per_index);
    
    Some(CompressedChunk {
        position,
        palette,
        indices,
        metadata: ChunkMetadata {
            has_surface: true, // TODO: Detect
            lod_levels: vec![],
        },
    })
}

fn bitpack_indices(
    data: &[Voxel],
    palette_map: &HashMap<Voxel, u8>,
    bits_per_index: u8,
) -> BitpackedData {
    let total_bits = data.len() * bits_per_index as usize;
    let total_bytes = (total_bits + 7) / 8;
    let mut packed_data = vec![0u8; total_bytes];
    
    let mut bit_offset = 0;
    for voxel in data {
        let index = palette_map[voxel] as u32;
        
        // Pack bits
        for bit in 0..bits_per_index {
            if index & (1 << bit) != 0 {
                let byte_idx = bit_offset / 8;
                let bit_idx = bit_offset % 8;
                packed_data[byte_idx] |= 1 << bit_idx;
            }
            bit_offset += 1;
        }
    }
    
    BitpackedData {
        data: packed_data,
        bits_per_index,
    }
}

// Async generation handle
pub struct AsyncGenerationHandle {
    pub id: u64,
    pub status: Arc<RwLock<GenerationStatus>>,
}

pub enum GenerationStatus {
    Pending,
    Running,
    Complete(Result<VoxelWorkspace, String>),
}

impl AsyncGenerationHandle {
    pub fn is_complete(&self) -> bool {
        matches!(*self.status.read().unwrap(), GenerationStatus::Complete(_))
    }
    
    pub fn try_get_result(&self) -> Option<Result<Arc<VoxelWorkspace>, String>> {
        let status = self.status.read().unwrap();
        match &*status {
            GenerationStatus::Complete(result) => match result {
                Ok(ws) => Some(Ok(Arc::new(ws.clone()))),
                Err(e) => Some(Err(e.clone())),
            },
            _ => None,
        }
    }
}

// GPU World Generator with thread pool
pub struct GpuWorldGenerator {
    gfx: Arc<dyn Gfx + Send + Sync>,
    sdf_evaluator: GpuSdfEvaluator,
    brush_evaluator: GpuBrushEvaluator,
    post_processor: GpuPostProcessor,
    thread_executor: Option<Arc<GpuThreadExecutor>>,
    main_thread_sender: Option<mpsc::Sender<MainThreadCommand>>,
    adaptive_processor: Option<AsyncWorldgenProcessor>,
    // Chunk accumulation cache
    chunk_cache: Arc<Mutex<HashMap<ChunkId, Arc<Mutex<ChunkAccumulator>>>>>,
}

impl GpuWorldGenerator {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>) -> Self {
        Self {
            sdf_evaluator: GpuSdfEvaluator::new(gfx.clone()),
            brush_evaluator: GpuBrushEvaluator::new(gfx.clone()),
            post_processor: GpuPostProcessor::new(gfx.clone()),
            gfx,
            thread_executor: None,
            main_thread_sender: None,
            adaptive_processor: Some(AsyncWorldgenProcessor::new()),
            chunk_cache: Arc::new(Mutex::new(HashMap::new())),
        }
    }
    
    /// Initialize with thread executor for async operation
    pub fn with_thread_executor(
        mut self, 
        executor: Arc<GpuThreadExecutor>,
        main_thread_sender: mpsc::Sender<MainThreadCommand>
    ) -> Self {
        self.thread_executor = Some(executor);
        self.main_thread_sender = Some(main_thread_sender);
        self
    }
    
    /// Process adaptive worldgen tasks for this frame
    /// Returns true if there's more work to do
    pub fn process_frame(&self) -> bool {
        if let Some(ref processor) = self.adaptive_processor {
            processor.process_frame(self.gfx.as_ref())
        } else {
            false
        }
    }
    
    /// Queue generation using adaptive processor
    pub fn queue_adaptive_generation(
        &self,
        bounds: WorldBounds,
        params: GenerationParams,
    ) -> mpsc::Receiver<Result<VoxelWorkspace, String>> {
        if let Some(ref processor) = self.adaptive_processor {
            processor.queue_generation(bounds, params)
        } else {
            // Fallback to immediate generation
            let (tx, rx) = mpsc::channel();
            let result = self.generate_immediate(bounds, params);
            let _ = tx.send(result);
            rx
        }
    }
    
    fn generate_immediate(
        &self,
        bounds: WorldBounds,
        params: GenerationParams,
    ) -> Result<VoxelWorkspace, String> {
        // Simple immediate generation for fallback
        let voxel_count = bounds.voxel_count();
        let workspace_buffer = vec![Voxel(0); voxel_count];
        Ok(VoxelWorkspace::from_gpu_buffer(workspace_buffer, bounds, std::time::Duration::from_millis(0)))
    }
    
    /// Start async GPU generation and return immediately
    pub fn start_async_generation(
        &self,
        bounds: WorldBounds,
        params: GenerationParams,
    ) -> AsyncGenerationHandle {
        let handle = AsyncGenerationHandle {
            id: {
                static COUNTER: AtomicU64 = AtomicU64::new(0);
                COUNTER.fetch_add(1, Ordering::Relaxed)
            },
            status: Arc::new(RwLock::new(GenerationStatus::Pending)),
        };
        
        let status = handle.status.clone();
        let bounds_clone = bounds.clone();
        let params_clone = params.clone();
        let gfx = self.gfx.clone();
        let evaluator = self.sdf_evaluator.clone();
        let brush_eval = self.brush_evaluator.clone();
        
        // Check if we have main thread communication
        if let (Some(executor), Some(sender)) = (self.thread_executor.as_ref(), self.main_thread_sender.as_ref()) {
            // Use GPU implementation with main thread dispatch
            let sender = sender.clone();
            let thread = std::thread::spawn(move || {
                println!("GPU generation thread spawned for bounds: [{:.1},{:.1},{:.1}] to [{:.1},{:.1},{:.1}]", 
                    bounds_clone.min.x(), bounds_clone.min.y(), bounds_clone.min.z(),
                    bounds_clone.max.x(), bounds_clone.max.y(), bounds_clone.max.z());
                
                *status.write().unwrap() = GenerationStatus::Running;
                
                // Dispatch GPU work via main thread
                let result = Self::generate_gpu(bounds_clone, params_clone, gfx, sender);
                
                match &result {
                    Ok(workspace) => {
                        println!("GPU generation completed successfully. Voxel count: {}", workspace.voxels.len());
                        let non_empty = workspace.voxels.iter().filter(|v| v.0 != 0).count();
                        println!("Non-empty voxels: {}", non_empty);
                    }
                    Err(e) => {
                        println!("GPU generation failed: {}", e);
                    }
                }
                
                *status.write().unwrap() = GenerationStatus::Complete(result);
            });
        } else {
            // Fall back to CPU implementation
            let thread = std::thread::spawn(move || {
                println!("CPU generation thread spawned (no GPU executor available)");
                
                *status.write().unwrap() = GenerationStatus::Running;
                
                let result = Self::generate_cpu_fallback(bounds_clone, params_clone, evaluator, brush_eval);
                
                match &result {
                    Ok(workspace) => {
                        println!("CPU generation completed successfully. Voxel count: {}", workspace.voxels.len());
                        let non_empty = workspace.voxels.iter().filter(|v| v.0 != 0).count();
                        println!("Non-empty voxels: {}", non_empty);
                    }
                    Err(e) => {
                        println!("CPU generation failed: {}", e);
                    }
                }
                
                *status.write().unwrap() = GenerationStatus::Complete(result);
            });
        }
        
        handle
    }
    
    fn generate_gpu(
        bounds: WorldBounds,
        params: GenerationParams,
        gfx: Arc<dyn Gfx + Send + Sync>,
        sender: mpsc::Sender<MainThreadCommand>,
    ) -> Result<VoxelWorkspace, String> {
        use std::sync::mpsc;
        
        let voxel_count = bounds.voxel_count();
        println!("GPU generation: starting for {} voxels", voxel_count);
        
        // Create synchronization channel for results
        let (result_sender, result_receiver) = mpsc::channel();
        
        // Send GPU compute command to main thread
        let cmd = MainThreadCommand::ExecuteGpuWorldgen {
            bounds: bounds.clone(),
            params: params.clone(),
            result_sender,
        };
        
        sender.send(cmd).map_err(|e| format!("Failed to send GPU command: {}", e))?;
        
        // Wait for GPU work to complete
        println!("GPU generation: waiting for result...");
        match result_receiver.recv() {
            Ok(Ok(workspace)) => {
                println!("GPU generation completed successfully");
                Ok(workspace)
            }
            Ok(Err(e)) => {
                println!("GPU generation failed: {}", e);
                Err(e)
            }
            Err(e) => {
                println!("Failed to receive GPU result: {}", e);
                Err(format!("GPU communication error: {}", e))
            }
        }
    }
    
    fn generate_cpu_fallback(
        bounds: WorldBounds,
        params: GenerationParams,
        sdf_eval: GpuSdfEvaluator,
        brush_eval: GpuBrushEvaluator,
    ) -> Result<VoxelWorkspace, String> {
        let voxel_count = bounds.voxel_count();
        println!("CPU fallback: generating {} voxels", voxel_count);
        
        // Execute CPU work synchronously in thread
        // In the real implementation, GPU commands would be queued to main thread
        let sdf_field = sdf_eval.evaluate_sdf_field_cpu(&bounds, params.sdf_resolution, &params.sdf_tree)?;
        println!("CPU fallback: SDF field evaluated, {} values", sdf_field.len());
        
        // Debug first few SDF values
        if sdf_field.len() > 10 {
            println!("First 10 SDF values: {:?}", &sdf_field[0..10]);
        }
        
        let mut workspace_buffer = vec![Voxel(0); voxel_count];
        brush_eval.evaluate_brushes_cpu(
            &sdf_field,
            &params.brush_schema,
            &mut workspace_buffer,
            &bounds,
            params.sdf_resolution,
        )?;
        
        // Count non-empty voxels after brush evaluation
        let non_empty = workspace_buffer.iter().filter(|v| v.0 != 0).count();
        println!("CPU fallback: after brush evaluation, {} non-empty voxels out of {}", non_empty, workspace_buffer.len());
        
        Ok(VoxelWorkspace::from_gpu_buffer(workspace_buffer, bounds, std::time::Duration::from_millis(0)))
    }
    
    pub async fn generate_world_region(
        &mut self,
        bounds: WorldBounds,
        params: GenerationParams,
    ) -> Result<VoxelWorkspace, String> {
        // 1. Allocate GPU workspace
        let voxel_count = bounds.voxel_count();
        let workspace_size = voxel_count * std::mem::size_of::<Voxel>();
        
        // 2. Evaluate SDF field
        let sdf_field = self.sdf_evaluator.evaluate_sdf_field(
            &bounds,
            params.sdf_resolution,
            &params.sdf_tree,
        ).await?;
        
        // 3. Apply brush layers
        let mut workspace_buffer = vec![Voxel(0); voxel_count];
        self.brush_evaluator.evaluate_brushes(
            &sdf_field,
            &params.brush_schema,
            &mut workspace_buffer,
            &bounds,
            params.sdf_resolution, // Pass the actual SDF resolution
        ).await?;
        
        // Debug: count non-empty voxels after brush evaluation
        let non_empty = workspace_buffer.iter().filter(|v| v.0 != 0).count();
        println!("After brush evaluation: {} non-empty voxels out of {}", non_empty, workspace_buffer.len());
        
        // Debug: check voxel distribution
        let mut voxel_counts = std::collections::HashMap::new();
        for voxel in &workspace_buffer {
            *voxel_counts.entry(voxel.0).or_insert(0) += 1;
        }
        println!("Voxel type distribution:");
        for voxel_type in 0..=4 {
            let count = voxel_counts.get(&voxel_type).unwrap_or(&0);
            if *count > 0 {
                let voxel_name = match voxel_type {
                    0 => "Air",
                    1 => "Stone", 
                    2 => "Dirt",
                    3 => "Grass",
                    4 => "Sand",
                    _ => "Unknown",
                };
                println!("  Type {} ({}): {} voxels", voxel_type, voxel_name, count);
            }
        }
        
        // Debug: Check bounds and dimensions
        println!("Workspace bounds: min={:?}, max={:?}", bounds.min, bounds.max);
        println!("Workspace dimensions: {:?}", bounds.dimensions());
        println!("SDF resolution: {:?}", params.sdf_resolution);
        
        // 4. Post-processing
        for process in &params.post_processes {
            self.post_processor.apply_process(
                &mut workspace_buffer,
                process,
                &bounds,
            ).await?;
        }
        
        // Debug: count after post-processing
        let non_empty_post = workspace_buffer.iter().filter(|v| v.0 != 0).count();
        println!("After post-processing: {} non-empty voxels out of {}", non_empty_post, workspace_buffer.len());
        
        // 5. Create workspace
        Ok(VoxelWorkspace::from_gpu_buffer(workspace_buffer, bounds, std::time::Duration::from_millis(0)))
    }
}


// GPU SDF Evaluator
#[derive(Clone)]
pub struct GpuSdfEvaluator {
    gfx: Arc<dyn Gfx + Send + Sync>,
}

impl GpuSdfEvaluator {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>) -> Self {
        Self { gfx }
    }
    
    pub async fn evaluate_sdf_field(
        &self,
        bounds: &WorldBounds,
        resolution: Vec3<u32>,
        sdf_tree: &Arc<dyn super::sdf::Sdf>,
    ) -> Result<Vec<f32>, String> {
        // In production, this would dispatch GPU compute
        // For now, delegate to CPU implementation
        self.evaluate_sdf_field_cpu(bounds, resolution, sdf_tree)
    }
    
    pub fn evaluate_sdf_field_gpu(
        &self,
        bounds: &WorldBounds,
        resolution: Vec3<u32>,
        sdf_tree: &Arc<dyn super::sdf::Sdf>,
        sdf_buffer: &mut dyn std::any::Any,
    ) -> Result<(), String> {
        // Convert SDF tree to GPU format
        let gpu_nodes = self.convert_sdf_tree_to_gpu(sdf_tree)?;
        
        // Upload to GPU buffer
        // Note: In real implementation, we'd cast the buffer handle and use gfx API
        // For now, this is a placeholder since GpuBuffer is an opaque type
        
        Ok(())
    }
    
    fn convert_sdf_tree_to_gpu(&self, sdf_tree: &Arc<dyn super::sdf::Sdf>) -> Result<Vec<u8>, String> {
        // GPU SDF Node structure (matches GLSL layout)
        #[repr(C, align(16))]
        struct GpuSdfNode {
            node_type: u32,
            _padding1: [u32; 3],
            params: [[f32; 4]; 4],
            children: [u32; 2],
            _padding2: [u32; 2],
        }
        
        let mut nodes = Vec::new();
        
        // For now, create a simple plane node
        let plane_node = GpuSdfNode {
            node_type: 2, // SDF_PLANE
            _padding1: [0; 3],
            params: [
                [0.0, 0.0, 1.0, 0.0], // normal = [0, 0, 1], distance = 0
                [0.0; 4],
                [0.0; 4],
                [0.0; 4],
            ],
            children: [0, 0],
            _padding2: [0; 2],
        };
        
        nodes.push(plane_node);
        
        // Convert to bytes
        let bytes = unsafe {
            std::slice::from_raw_parts(
                nodes.as_ptr() as *const u8,
                nodes.len() * std::mem::size_of::<GpuSdfNode>()
            ).to_vec()
        };
        
        Ok(bytes)
    }
    
    pub fn evaluate_sdf_field_cpu(
        &self,
        bounds: &WorldBounds,
        resolution: Vec3<u32>,
        sdf_tree: &Arc<dyn super::sdf::Sdf>,
    ) -> Result<Vec<f32>, String> {
        println!("GpuSdfEvaluator: Evaluating SDF field with bounds min=[{:.1},{:.1},{:.1}] max=[{:.1},{:.1},{:.1}], resolution {:?}", 
            bounds.min.x(), bounds.min.y(), bounds.min.z(),
            bounds.max.x(), bounds.max.y(), bounds.max.z(),
            resolution);
        let size = (resolution.x() * resolution.y() * resolution.z()) as usize;
        let mut sdf_values = Vec::with_capacity(size);
        
        // Evaluate SDF at each grid point
        for z in 0..resolution.z() {
            for y in 0..resolution.y() {
                for x in 0..resolution.x() {
                    // Calculate world position with better precision
                    let bounds_size = bounds.max - bounds.min;
                    let voxel_size = Vec3::new([
                        bounds_size.x() / resolution.x() as f32,
                        bounds_size.y() / resolution.y() as f32,
                        bounds_size.z() / resolution.z() as f32,
                    ]);
                    
                    let world_pos = bounds.min + Vec3::new([
                        x as f32 * voxel_size.x(),
                        y as f32 * voxel_size.y(),
                        z as f32 * voxel_size.z(),
                    ]);
                    
                    // Evaluate SDF
                    let distance = sdf_tree.distance(world_pos);
                    sdf_values.push(distance);
                }
            }
        }
        
        Ok(sdf_values)
    }
}

// Calculate SDF gradient using finite differences
fn calculate_sdf_gradient(
    sdf_field: &[f32],
    idx: usize,
    dims_x: u32,
    dims_y: u32,
    dims_z: u32,
    bounds: &WorldBounds,
) -> Vec3<f32> {
    let x = (idx % dims_x as usize) as u32;
    let y = ((idx / dims_x as usize) % dims_y as usize) as u32;
    let z = (idx / (dims_x as usize * dims_y as usize)) as u32;
    
    let h = bounds.voxel_size * 0.5; // Half step for central differences
    let mut gradient = Vec3::new([0.0, 0.0, 0.0]);
    
    // X gradient
    if x > 0 && x < dims_x - 1 {
        let idx_left = idx - 1;
        let idx_right = idx + 1;
        gradient[0] = (sdf_field[idx_right] - sdf_field[idx_left]) / (2.0 * h);
    }
    
    // Y gradient
    if y > 0 && y < dims_y - 1 {
        let idx_down = idx - dims_x as usize;
        let idx_up = idx + dims_x as usize;
        gradient[1] = (sdf_field[idx_up] - sdf_field[idx_down]) / (2.0 * h);
    }
    
    // Z gradient
    if z > 0 && z < dims_z - 1 {
        let idx_back = idx - (dims_x * dims_y) as usize;
        let idx_front = idx + (dims_x * dims_y) as usize;
        gradient[2] = (sdf_field[idx_front] - sdf_field[idx_back]) / (2.0 * h);
    }
    
    // Normalize gradient to get normal
    let length = gradient.length();
    if length > 0.0001 {
        gradient / length
    } else {
        Vec3::new([0.0, 0.0, 1.0]) // Default to up normal if gradient is zero
    }
}

// GPU Brush Evaluator
#[derive(Clone)]
pub struct GpuBrushEvaluator {
    gfx: Arc<dyn Gfx + Send + Sync>,
}

impl GpuBrushEvaluator {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>) -> Self {
        Self { gfx }
    }
    
    pub async fn evaluate_brushes(
        &self,
        sdf_field: &[f32],
        brush_schema: &BrushSchema,
        output: &mut [Voxel],
        bounds: &WorldBounds,
        sdf_resolution: Vec3<u32>,
    ) -> Result<(), String> {
        // In production, this would dispatch GPU compute
        // For now, delegate to CPU implementation
        self.evaluate_brushes_cpu(sdf_field, brush_schema, output, bounds, sdf_resolution)
    }
    
    pub fn evaluate_brushes_gpu(
        &self,
        brush_schema: &BrushSchema,
        brush_buffer: &mut dyn std::any::Any,
    ) -> Result<(), String> {
        // Convert brush schema to GPU format
        let gpu_brushes = self.convert_brushes_to_gpu(brush_schema)?;
        
        // Upload to GPU buffer
        // Note: In real implementation, we'd cast the buffer handle and use gfx API
        // For now, this is a placeholder since GpuBuffer is an opaque type
        
        Ok(())
    }
    
    fn convert_brushes_to_gpu(&self, brush_schema: &BrushSchema) -> Result<(Vec<u8>, Vec<u8>), String> {
        // Use the brush compiler to convert the schema
        let (instructions, layers) = brush_schema.to_gpu_bytes();
        
        if instructions.is_empty() || layers.is_empty() {
            panic!("FATAL: Brush compilation produced empty data. Synthesis must provide valid brush layers.");
        }
        
        Ok((instructions, layers))
    }
    
    pub fn evaluate_brushes_cpu(
        &self,
        sdf_field: &[f32],
        brush_schema: &BrushSchema,
        output: &mut [Voxel],
        bounds: &WorldBounds,
        sdf_resolution: Vec3<u32>,
    ) -> Result<(), String> {
        let dims = bounds.dimensions();
        let sdf_dims_x = sdf_resolution.x();
        let sdf_dims_y = sdf_resolution.y();
        let sdf_dims_z = sdf_resolution.z();
        
        // Iterate through each voxel
        for z in 0..dims.2 {
            for y in 0..dims.1 {
                for x in 0..dims.0 {
                    let voxel_idx = (z * dims.1 * dims.0 + y * dims.0 + x) as usize;
                    
                    // Calculate world position
                    let world_pos = bounds.min + Vec3::new([
                        x as f32 * bounds.voxel_size,
                        y as f32 * bounds.voxel_size,
                        z as f32 * bounds.voxel_size,
                    ]);
                    
                    // Sample SDF field (with interpolation)
                    let sdf_pos = (world_pos - bounds.min) / (bounds.max - bounds.min);
                    let sdf_x = (sdf_pos.x() * (sdf_dims_x - 1) as f32) as usize;
                    let sdf_y = (sdf_pos.y() * (sdf_dims_y - 1) as f32) as usize;
                    let sdf_z = (sdf_pos.z() * (sdf_dims_z - 1) as f32) as usize;
                    
                    let sdf_idx = sdf_z.min(sdf_dims_z as usize - 1) * (sdf_dims_y * sdf_dims_x) as usize +
                                  sdf_y.min(sdf_dims_y as usize - 1) * sdf_dims_x as usize +
                                  sdf_x.min(sdf_dims_x as usize - 1);
                    
                    let sdf_distance = sdf_field[sdf_idx];
                    
                    // Debug output for some voxels at different Z levels
                    let should_debug = voxel_idx < 5 || 
                                     (z == 0 && y == 0 && x < 5) ||
                                     (z == dims.2 / 2 && y == 0 && x < 5) ||
                                     (z == dims.2 - 1 && y == 0 && x < 5);
                    
                    if should_debug {
                        println!("Voxel[{}] at grid({},{},{}) world({:.1},{:.1},{:.1}): SDF = {:.3}", 
                                voxel_idx, x, y, z, world_pos.x(), world_pos.y(), world_pos.z(), sdf_distance);
                    }
                    
                    // Calculate normal from SDF gradient
                    // TODO: Calculate actual gradient from SDF field instead of hardcoding
                    let normal = calculate_sdf_gradient(&sdf_field, sdf_idx, sdf_dims_x, sdf_dims_y, sdf_dims_z, &bounds);
                    
                    // Surface position is where SDF = 0
                    // For a point at distance d from surface, surface is at position - normal * d
                    let surface_position = world_pos - normal * sdf_distance;
                    
                    // Create evaluation context
                    let ctx = super::brush::EvaluationContext {
                        position: world_pos,
                        sdf_value: sdf_distance,
                        normal,
                        surface_position,
                        depth_from_surface: -sdf_distance,
                    };
                    
                    // Debug first few voxels and some at different heights
                    let debug_output = false; // Disable debug output for now
                    
                    // Evaluate brushes
                    let mut final_voxel = Voxel(0); // Air by default
                    let mut max_priority = i32::MIN;
                    
                    for (brush_idx, brush) in brush_schema.layers.iter().enumerate() {
                        if let Some((voxel, weight)) = brush.sample(&ctx) {
                            let priority = brush.priority();
                            if priority > max_priority || (priority == max_priority && weight > 0.5) {
                                max_priority = priority;
                                final_voxel = voxel;
                                
                                if debug_output {
                                    println!("  -> Brush {} matched: voxel={}, priority={}, weight={}", 
                                        brush_idx, voxel.0, priority, weight);
                                }
                            }
                        }
                    }
                    
                    output[voxel_idx] = final_voxel;
                }
            }
        }
        
        Ok(())
    }
}

// GPU Post Processor
pub struct GpuPostProcessor {
    gfx: Arc<dyn Gfx + Send + Sync>,
}

impl GpuPostProcessor {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>) -> Self {
        Self { gfx }
    }
    
    pub async fn apply_process(
        &self,
        workspace: &mut [Voxel],
        process: &PostProcess,
        bounds: &WorldBounds,
    ) -> Result<(), String> {
        match process {
            PostProcess::Smoothing { iterations, strength } => {
                self.apply_smoothing(workspace, *iterations, *strength, bounds).await
            }
            PostProcess::Erosion { iterations, strength } => {
                self.apply_erosion(workspace, *iterations, *strength, bounds).await
            }
            PostProcess::Dilation { iterations, strength } => {
                self.apply_dilation(workspace, *iterations, *strength, bounds).await
            }
            PostProcess::AmbientOcclusion { radius, samples } => {
                self.apply_ambient_occlusion(workspace, *radius, *samples, bounds).await
            }
        }
    }
    
    async fn apply_smoothing(
        &self,
        workspace: &mut [Voxel],
        iterations: u32,
        strength: f32,
        bounds: &WorldBounds,
    ) -> Result<(), String> {
        // TODO: Implement GPU smoothing
        Ok(())
    }
    
    async fn apply_erosion(
        &self,
        workspace: &mut [Voxel],
        iterations: u32,
        strength: f32,
        bounds: &WorldBounds,
    ) -> Result<(), String> {
        // TODO: Implement GPU erosion
        Ok(())
    }
    
    async fn apply_dilation(
        &self,
        workspace: &mut [Voxel],
        iterations: u32,
        strength: f32,
        bounds: &WorldBounds,
    ) -> Result<(), String> {
        // TODO: Implement GPU dilation
        Ok(())
    }
    
    async fn apply_ambient_occlusion(
        &self,
        workspace: &mut [Voxel],
        radius: f32,
        samples: u32,
        bounds: &WorldBounds,
    ) -> Result<(), String> {
        // TODO: Implement GPU ambient occlusion
        Ok(())
    }
}