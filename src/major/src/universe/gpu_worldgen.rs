use crate::math::Vec3;
use crate::gfx::Gfx;
use super::{Voxel, sdf::Sdf, brush::{Brush, EvaluationContext}};
use super::gpu_thread_executor::{GpuThreadExecutor, MainThreadCommand, WorkerTask};
use std::sync::{Arc, RwLock};
use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::mpsc;

#[derive(Clone)]
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
}

#[derive(Clone)]
pub struct GenerationParams {
    pub sdf_resolution: Vec3<u32>,
    pub sdf_tree: Arc<dyn super::sdf::Sdf>,  // Add the SDF tree
    pub brush_schema: BrushSchema,
    pub post_processes: Vec<PostProcess>,
    pub lod_levels: Vec<LodLevel>,
}

#[derive(Clone)]
pub struct BrushSchema {
    pub layers: Vec<Arc<dyn Brush>>,
    pub blend_mode: super::brush::BlendMode,
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
    pub bounds: WorldBounds,
    pub voxels: Vec<Voxel>,
    pub dimensions: (u32, u32, u32),
    pub metadata: WorkspaceMetadata,
}

#[derive(Clone)]
pub struct WorkspaceMetadata {
    pub unique_voxels: Vec<Voxel>,
    pub histogram: HashMap<Voxel, u32>,
    pub surface_voxels: Vec<u32>,
}

impl VoxelWorkspace {
    pub fn from_gpu_buffer(
        buffer: Vec<Voxel>,
        bounds: WorldBounds,
    ) -> Self {
        let dimensions = bounds.dimensions();
        let metadata = Self::compute_metadata(&buffer);
        
        Self {
            bounds,
            voxels: buffer,
            dimensions,
            metadata,
        }
    }
    
    fn compute_metadata(voxels: &[Voxel]) -> WorkspaceMetadata {
        let mut histogram = HashMap::new();
        let mut surface_voxels = Vec::new();
        
        for (idx, voxel) in voxels.iter().enumerate() {
            *histogram.entry(*voxel).or_insert(0) += 1;
            
            // TODO: Detect surface voxels
            // if is_surface_voxel(idx, voxels) {
            //     surface_voxels.push(idx as u32);
            // }
        }
        
        let mut unique_voxels: Vec<_> = histogram.keys().copied().collect();
        unique_voxels.sort_by_key(|v| std::cmp::Reverse(histogram[v]));
        
        WorkspaceMetadata {
            unique_voxels,
            histogram,
            surface_voxels,
        }
    }
    
    pub fn extract_all_chunks(&self) -> Vec<CompressedChunk> {
        // Extract 64x64x64 chunks from workspace
        let chunk_size = 64;
        let chunks_x = (self.dimensions.0 + chunk_size - 1) / chunk_size;
        let chunks_y = (self.dimensions.1 + chunk_size - 1) / chunk_size;
        let chunks_z = (self.dimensions.2 + chunk_size - 1) / chunk_size;
        
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
                    
                    if wx < self.dimensions.0 && wy < self.dimensions.1 && wz < self.dimensions.2 {
                        let world_idx = (wz * self.dimensions.1 * self.dimensions.0 +
                                       wy * self.dimensions.0 + wx) as usize;
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
    
    /// Start async GPU generation and return immediately
    pub fn start_async_generation(
        &self,
        bounds: WorldBounds,
        params: GenerationParams,
    ) -> AsyncGenerationHandle {
        // For now, still use CPU implementation but wrapped in async handle
        // TODO: Implement actual GPU compute dispatch
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
        let evaluator = self.sdf_evaluator.clone();
        let brush_eval = self.brush_evaluator.clone();
        
        // Spawn background task
        let thread = std::thread::spawn(move || {
            println!("CPU generation thread spawned for bounds: [{:.1},{:.1},{:.1}] to [{:.1},{:.1},{:.1}]", 
                bounds_clone.min.x(), bounds_clone.min.y(), bounds_clone.min.z(),
                bounds_clone.max.x(), bounds_clone.max.y(), bounds_clone.max.z());
            
            // Simulate async work
            *status.write().unwrap() = GenerationStatus::Running;
            println!("CPU generation: Status set to Running");
            
            // Run generation (for now still CPU-based)
            let result = Self::generate_cpu_fallback(bounds_clone, params_clone, evaluator, brush_eval);
            println!("CPU generation: generate_cpu_fallback completed with result: {}", result.is_ok());
            
            match &result {
                Ok(workspace) => {
                    println!("Generation completed successfully. Voxel count: {}", workspace.voxels.len());
                    // Count non-empty voxels
                    let non_empty = workspace.voxels.iter().filter(|v| v.0 != 0).count();
                    println!("Non-empty voxels: {}", non_empty);
                }
                Err(e) => {
                    println!("Generation failed: {}", e);
                }
            }
            
            *status.write().unwrap() = GenerationStatus::Complete(result);
        });
        
        handle
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
        
        Ok(VoxelWorkspace::from_gpu_buffer(workspace_buffer, bounds))
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
        Ok(VoxelWorkspace::from_gpu_buffer(workspace_buffer, bounds))
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
                    
                    // Calculate normal from SDF gradient
                    // For a plane with normal [0,0,1], the gradient is constant [0,0,1]
                    let normal = Vec3::new([0.0, 0.0, 1.0]); // Z-up for horizontal plane
                    
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