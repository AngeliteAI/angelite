use std::sync::{Arc, Mutex, mpsc};
use std::sync::atomic::Ordering;
use std::thread;
use std::collections::{VecDeque, HashMap, BinaryHeap};
use std::cmp::Ordering as CmpOrdering;
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll};
use std::ffi::c_void;
use crate::math::Vec3;
use crate::debug::{Debug, DEBUG};
use super::gpu_readback::{DeferredReadbackManager, WorldgenRingBuffer};
use super::gpu_worldgen::{CHUNK_SIZE};
use super::GpuWorldGenPipeline;
use super::adaptive_worldgen::AdaptiveWorldgenScheduler;
use crate::runtime::executor::{Executor, Handle as ExecutorHandle};
use crate::gfx::{BufferUsage, MemoryAccess, GpuEncoder};

// Command buffer wrapper and tracker are no longer needed with the new encoder API

/// Pending minichunk batch for processing
#[derive(Clone)]
struct PendingMinichunkBatch {
    chunk_id: super::gpu_worldgen::ChunkId,
    minichunks: Vec<(usize, super::gpu_worldgen::WorldBounds)>,
    params: super::gpu_worldgen::GenerationParams,
    accumulator: Arc<Mutex<super::gpu_worldgen::ChunkAccumulator>>,
    priority: i32, // Higher priority = process first
}

impl PartialEq for PendingMinichunkBatch {
    fn eq(&self, other: &Self) -> bool {
        self.priority == other.priority
    }
}

impl Eq for PendingMinichunkBatch {}

impl PartialOrd for PendingMinichunkBatch {
    fn partial_cmp(&self, other: &Self) -> Option<CmpOrdering> {
        Some(self.cmp(other))
    }
}

impl Ord for PendingMinichunkBatch {
    fn cmp(&self, other: &Self) -> CmpOrdering {
        // Higher priority comes first in BinaryHeap (max heap)
        self.priority.cmp(&other.priority)
    }
}

/// Batch of minichunks to process in a single workspace
struct MinichunkWorkspaceBatch {
    chunk_id: super::gpu_worldgen::ChunkId,
    minichunks: Vec<(usize, super::gpu_worldgen::WorldBounds)>,
    params: super::gpu_worldgen::GenerationParams,
    accumulator: Arc<Mutex<super::gpu_worldgen::ChunkAccumulator>>,
}

/// Commands that need to be executed on the main thread (GPU API calls)
pub enum MainThreadCommand {
    CreateBuffer { size: usize, id: u64 },
    UpdateBuffer { id: u64, data: Vec<u8> },
    DispatchCompute { shader: u32, workgroups: (u32, u32, u32) },
    ReadBuffer { id: u64, callback: mpsc::Sender<Vec<u8>> },
    ExecuteGpuWorldgen {
        bounds: super::gpu_worldgen::WorldBounds,
        params: super::gpu_worldgen::GenerationParams,
        result_sender: mpsc::Sender<Result<super::gpu_worldgen::VoxelWorkspace, String>>,
    },
}

/// Work that can be done on worker threads
pub enum WorkerTask {
    ProcessSdf {
        bounds: super::gpu_worldgen::WorldBounds,
        resolution: Vec3<u32>,
        sdf_tree: Arc<dyn super::sdf::Sdf>,
        result_sender: mpsc::Sender<Result<Vec<f32>, String>>,
    },
    ProcessBrushes {
        sdf_field: Vec<f32>,
        brush_schema: super::gpu_worldgen::BrushSchema,
        bounds: super::gpu_worldgen::WorldBounds,
        sdf_resolution: Vec3<u32>,
        voxel_count: usize,
        result_sender: mpsc::Sender<Result<Vec<super::Voxel>, String>>,
    },
}

/// Async task executor that coordinates CPU work with GPU commands
pub struct GpuThreadExecutor {
    executor: Arc<Executor>,
    task_sender: mpsc::Sender<WorkerTask>,
    main_thread_sender: mpsc::Sender<MainThreadCommand>,
    shutdown: Arc<Mutex<bool>>,
    /// Receiver for tasks - kept here so we can spawn async tasks
    task_receiver: Arc<Mutex<mpsc::Receiver<WorkerTask>>>,
    /// Pending futures that need to be polled
    pending_tasks: Arc<Mutex<Vec<Pin<Box<dyn Future<Output = ()> + Send>>>>>,
}

impl GpuThreadExecutor {
    pub fn new(
        num_threads: usize,
        main_thread_sender: mpsc::Sender<MainThreadCommand>,
    ) -> Self {
        let (task_sender, task_receiver) = mpsc::channel();
        let task_receiver = Arc::new(Mutex::new(task_receiver));
        let shutdown = Arc::new(Mutex::new(false));
        
        // Create async executor with the specified number of threads
        let executor = Arc::new(Executor::new(num_threads));
        
        let result = Self {
            executor: executor.clone(),
            task_sender,
            main_thread_sender,
            shutdown,
            task_receiver,
            pending_tasks: Arc::new(Mutex::new(Vec::new())),
        };
        
        // Spawn async workers to process tasks
        for i in 0..num_threads {
            let receiver = result.task_receiver.clone();
            let shutdown_flag = result.shutdown.clone();
            let main_sender = result.main_thread_sender.clone();
            
            // Spawn an async task for each worker
            executor.spawn(async move {
                println!("Async worker {} started", i);
                
                loop {
                    // Check shutdown
                    if *shutdown_flag.lock().unwrap() {
                        break;
                    }
                    
                    // Try to get next task (non-blocking)
                    let task = {
                        let receiver = receiver.lock().unwrap();
                        receiver.try_recv()
                    };
                    
                    match task {
                        Ok(WorkerTask::ProcessSdf { bounds, resolution, sdf_tree, result_sender }) => {
                            // Process SDF on CPU
                            let result = Self::process_sdf_cpu(bounds, resolution, sdf_tree);
                            let _ = result_sender.send(result);
                        }
                        Ok(WorkerTask::ProcessBrushes { 
                            sdf_field, 
                            brush_schema, 
                            bounds, 
                            sdf_resolution,
                            voxel_count,
                            result_sender 
                        }) => {
                            // Process brushes on CPU
                            let result = Self::process_brushes_cpu(
                                sdf_field, 
                                brush_schema, 
                                bounds, 
                                sdf_resolution,
                                voxel_count
                            );
                            let _ = result_sender.send(result);
                        }
                        Err(mpsc::TryRecvError::Empty) => {
                            // No work available, yield to other tasks
                            // Sleep for a short time to avoid busy waiting
                            std::thread::sleep(std::time::Duration::from_micros(100));
                        }
                        Err(mpsc::TryRecvError::Disconnected) => {
                            // Channel closed, exit
                            break;
                        }
                    }
                }
                
                println!("Async worker {} shutting down", i);
            });
        }
        
        result
    }
    
    pub fn submit_task(&self, task: WorkerTask) -> Result<(), String> {
        self.task_sender.send(task)
            .map_err(|_| "Failed to submit task to worker pool".to_string())
    }
    
    pub fn shutdown(self) {
        *self.shutdown.lock().unwrap() = true;
        
        // The executor will handle cleanup of async tasks
        // No need to manually join threads as they're managed by the executor
    }
    
    /// Poll the executor to make progress on tasks
    /// This should be called from the main loop for cooperative scheduling
    pub fn poll(&self) {
        // The executor has its own worker threads that continuously poll tasks
        // This method is provided for future use if we need custom scheduling
    }
    
    // Calculate SDF gradient using finite differences
    fn calculate_sdf_gradient(
        sdf_field: &[f32],
        idx: usize,
        dims_x: u32,
        dims_y: u32,
        dims_z: u32,
    ) -> Vec3<f32> {
        let x = (idx % dims_x as usize) as u32;
        let y = ((idx / dims_x as usize) % dims_y as usize) as u32;
        let z = (idx / (dims_x as usize * dims_y as usize)) as u32;
        
        let mut gradient = Vec3::new([0.0, 0.0, 0.0]);
        
        // X gradient
        if x > 0 && x < dims_x - 1 {
            let idx_left = idx - 1;
            let idx_right = idx + 1;
            gradient[0] = sdf_field[idx_right] - sdf_field[idx_left];
        }
        
        // Y gradient
        if y > 0 && y < dims_y - 1 {
            let idx_down = idx - dims_x as usize;
            let idx_up = idx + dims_x as usize;
            gradient[1] = sdf_field[idx_up] - sdf_field[idx_down];
        }
        
        // Z gradient
        if z > 0 && z < dims_z - 1 {
            let idx_back = idx - (dims_x * dims_y) as usize;
            let idx_front = idx + (dims_x * dims_y) as usize;
            gradient[2] = sdf_field[idx_front] - sdf_field[idx_back];
        }
        
        // Normalize gradient to get normal
        let length = gradient.length();
        if length > 0.0001 {
            gradient / length
        } else {
            Vec3::new([0.0, 0.0, 1.0]) // Default to up normal if gradient is zero
        }
    }
    
    fn process_sdf_cpu(
        bounds: super::gpu_worldgen::WorldBounds,
        resolution: Vec3<u32>,
        sdf_tree: Arc<dyn super::sdf::Sdf>,
    ) -> Result<Vec<f32>, String> {
        let size = (resolution.x() * resolution.y() * resolution.z()) as usize;
        let mut sdf_values = Vec::with_capacity(size);
        
        // Evaluate SDF at each grid point
        for z in 0..resolution.z() {
            for y in 0..resolution.y() {
                for x in 0..resolution.x() {
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
                    
                    let distance = sdf_tree.distance(world_pos);
                    sdf_values.push(distance);
                }
            }
        }
        
        Ok(sdf_values)
    }
    
    fn process_brushes_cpu(
        sdf_field: Vec<f32>,
        brush_schema: super::gpu_worldgen::BrushSchema,
        bounds: super::gpu_worldgen::WorldBounds,
        sdf_resolution: Vec3<u32>,
        voxel_count: usize,
    ) -> Result<Vec<super::Voxel>, String> {
        let mut output = vec![super::Voxel(0); voxel_count];
        let dims = bounds.dimensions();
        let sdf_dims_x = sdf_resolution.x();
        let sdf_dims_y = sdf_resolution.y();
        let sdf_dims_z = sdf_resolution.z();
        
        // Process each voxel
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
                    
                    // Sample SDF field
                    let sdf_pos = (world_pos - bounds.min) / (bounds.max - bounds.min);
                    let sdf_x = (sdf_pos.x() * (sdf_dims_x - 1) as f32) as usize;
                    let sdf_y = (sdf_pos.y() * (sdf_dims_y - 1) as f32) as usize;
                    let sdf_z = (sdf_pos.z() * (sdf_dims_z - 1) as f32) as usize;
                    
                    let sdf_idx = sdf_z.min(sdf_dims_z as usize - 1) * (sdf_dims_y * sdf_dims_x) as usize +
                                  sdf_y.min(sdf_dims_y as usize - 1) * sdf_dims_x as usize +
                                  sdf_x.min(sdf_dims_x as usize - 1);
                    
                    let sdf_distance = sdf_field[sdf_idx];
                    
                    // Calculate normal from SDF gradient
                    let normal = Self::calculate_sdf_gradient(&sdf_field, sdf_idx, sdf_dims_x, sdf_dims_y, sdf_dims_z);
                    let surface_position = world_pos - normal * sdf_distance;
                    
                    let ctx = super::brush::EvaluationContext {
                        position: world_pos,
                        sdf_value: sdf_distance,
                        normal,
                        surface_position,
                        depth_from_surface: -sdf_distance,
                    };
                    
                    // Evaluate brushes
                    let mut final_voxel = super::Voxel(0);
                    let mut max_priority = i32::MIN;
                    
                    for brush in &brush_schema.layers {
                        if let Some((voxel, weight)) = brush.sample(&ctx) {
                            let priority = brush.priority();
                            if priority > max_priority || (priority == max_priority && weight > 0.5) {
                                max_priority = priority;
                                final_voxel = voxel;
                            }
                        }
                    }
                    
                    output[voxel_idx] = final_voxel;
                }
            }
        }
        
        Ok(output)
    }
}

/// Handle for coordinating with the main thread
pub struct MainThreadCoordinator {
    receiver: mpsc::Receiver<MainThreadCommand>,
    readback_manager: Arc<DeferredReadbackManager>,
    worldgen_ring_buffer: Arc<Mutex<Option<WorldgenRingBuffer>>>,
    frames_in_flight: usize,
    gfx: Arc<dyn crate::gfx::Gfx + Send + Sync>,
    current_frame: Arc<Mutex<u64>>,
    /// Queue for worldgen requests that came in before a frame was active
    pending_worldgen_requests: Arc<Mutex<Vec<(super::gpu_worldgen::WorldBounds, super::gpu_worldgen::GenerationParams, mpsc::Sender<Result<super::gpu_worldgen::VoxelWorkspace, String>>)>>>,
    /// Pending chunks being accumulated from minichunks
    pending_chunks: Arc<Mutex<HashMap<super::gpu_worldgen::ChunkId, Arc<Mutex<super::gpu_worldgen::ChunkAccumulator>>>>>,
    /// Result senders for completed chunks
    chunk_result_senders: Arc<Mutex<HashMap<super::gpu_worldgen::ChunkId, mpsc::Sender<Result<super::gpu_worldgen::VoxelWorkspace, String>>>>>,
    /// GPU pipeline for worldgen
    gpu_pipeline: Arc<Mutex<Option<Box<GpuWorldGenPipeline>>>>,
    /// Queue of pending minichunk batches (priority queue)
    pending_minichunk_batches: Arc<Mutex<BinaryHeap<PendingMinichunkBatch>>>,
    /// Adaptive scheduler for frame-rate dependent workload management
    adaptive_scheduler: Arc<Mutex<AdaptiveWorldgenScheduler>>,
}

/// Serialize an SDF tree to GPU format
fn serialize_sdf_tree(sdf_tree: &Arc<dyn super::sdf::Sdf>) -> Result<Vec<super::sdf_serialization::GpuSdfNode>, String> {
    use super::sdf_serialization::*;
    
    let mut serializer = SdfSerializer::new();
    serializer.serialize_sdf(&**sdf_tree)?;
    Ok(serializer.get_sdf_nodes().to_vec())
}

impl MainThreadCoordinator {
    pub fn new(gfx: Arc<dyn crate::gfx::Gfx + Send + Sync>) -> (Self, mpsc::Sender<MainThreadCommand>) {
        Self::with_frames_in_flight(gfx, 3) // Standard double/triple buffering
    }
    
    pub fn with_frames_in_flight(gfx: Arc<dyn crate::gfx::Gfx + Send + Sync>, frames_in_flight: usize) -> (Self, mpsc::Sender<MainThreadCommand>) {
        let (sender, receiver) = mpsc::channel();
        let coordinator = Self { 
            receiver,
            readback_manager: Arc::new(DeferredReadbackManager::new(gfx.clone(), frames_in_flight)),
            gfx,
            worldgen_ring_buffer: Arc::new(Mutex::new(None)),
            frames_in_flight,
            current_frame: Arc::new(Mutex::new(0)),
            pending_worldgen_requests: Arc::new(Mutex::new(Vec::new())),
            pending_chunks: Arc::new(Mutex::new(HashMap::new())),
            chunk_result_senders: Arc::new(Mutex::new(HashMap::new())),
            gpu_pipeline: Arc::new(Mutex::new(None)),
            pending_minichunk_batches: Arc::new(Mutex::new(BinaryHeap::new())),
            adaptive_scheduler: Arc::new(Mutex::new(AdaptiveWorldgenScheduler::new())),
        };
        (coordinator, sender)
    }
    
    /// Set the GPU pipeline for worldgen
    pub fn set_gpu_pipeline(&self, pipeline: Box<GpuWorldGenPipeline>) {
        let mut gpu_pipeline = self.gpu_pipeline.lock().unwrap();
        *gpu_pipeline = Some(pipeline);
    }
    
    /// Process completed readbacks and advance frame
    pub fn end_frame(&self, gfx: &dyn crate::gfx::Gfx) {
        // Update adaptive scheduler with frame timing
        self.adaptive_scheduler.lock().unwrap().frame_start();
        
        // Advance frame counter
        self.readback_manager.advance_frame();
        
        // Process readbacks more aggressively to ensure minichunks complete
        // First try normal processing
        let current_frame = self.readback_manager.current_frame();
        self.readback_manager.process_completed_readbacks(gfx, current_frame);
        
        // Then force-process any old readbacks that might be stuck
        // Use frames_in_flight as the threshold to ensure GPU has finished
        self.readback_manager.force_process_old_readbacks(gfx, self.frames_in_flight as u64);
        
        // Try to process pending minichunk batches if workspaces are available
        // This is critical for continuing minichunk processing
        self.process_pending_minichunk_batches(gfx);
    }
    
    /// Process pending minichunk batches when workspaces become available
    fn process_pending_minichunk_batches(&self, gfx: &dyn crate::gfx::Gfx) {
        // Check if we have pending batches
        let pending_count = self.pending_minichunk_batches.lock().unwrap().len();
        if pending_count == 0 {
            return; // Nothing to process
        }
        
        // Get the current frame's encoder
        let mut encoder = match gfx.get_frame_encoder() {
            Some(enc) => enc,
            None => {
                // No active frame encoder, can't process
                return;
            }
        };
        
        // Also check how many chunks are currently being processed
        let active_chunks = self.pending_chunks.lock().unwrap().len();
        
        println!("Processing pending minichunk batches: {} batches waiting, {} active chunks", pending_count, active_chunks);
        
        let mut processed_any = false;
        
        // Process batches while we have available workspaces
        loop {
            // First check if we have any available workspaces - need to lock ring buffer for each check
            let available_count = {
                let ring_buffer_opt = self.worldgen_ring_buffer.lock().unwrap();
                match ring_buffer_opt.as_ref() {
                    Some(rb) => rb.available_workspace_count(),
                    None => return, // Ring buffer not initialized
                }
            };
            
            if available_count == 0 {
                println!("No available workspaces, stopping batch processing");
                break;
            }
            
            // Get next pending batch (highest priority)
            let pending_batch = {
                let mut pending_batches = self.pending_minichunk_batches.lock().unwrap();
                pending_batches.pop()
            };
            
            match pending_batch {
                Some(batch) => {
                    // Process this batch
                    println!("Processing pending minichunk batch for chunk {:?} with {} minichunks (available workspaces: {})", 
                             batch.chunk_id, batch.minichunks.len(), available_count);
                    
                    // Process minichunks in groups per workspace based on PID controller
                    let workgroup_budget = self.adaptive_scheduler.lock().unwrap().get_workgroup_budget() as usize;
                    let minichunks_per_workspace = workgroup_budget.max(1).min(16); // Clamp between 1-16
                    let workspace_batches: Vec<Vec<_>> = batch.minichunks
                        .chunks(minichunks_per_workspace)
                        .map(|chunk| chunk.to_vec())
                        .collect();
                    
                    let mut processed_in_batch = 0;
                    for (batch_idx, workspace_minichunks) in workspace_batches.iter().enumerate() {
                        // Try to queue the minichunk batch
                        if let Err(e) = self.queue_minichunks_to_workspace(
                            gfx,
                            encoder,
                            workspace_minichunks.clone(),
                            batch.params.clone(),
                            batch.chunk_id,
                            batch.accumulator.clone(),
                        ) {
                            println!("Failed to queue minichunk batch {}: {}", batch_idx, e);
                            // Put the remaining batches back in the queue
                            let remaining_minichunks: Vec<_> = workspace_batches[batch_idx..]
                                .iter()
                                .flat_map(|b| b.iter().cloned())
                                .collect();
                            if !remaining_minichunks.is_empty() {
                                println!("Re-queuing {} remaining minichunks from batch", remaining_minichunks.len());
                                let remaining_batch = PendingMinichunkBatch {
                                    chunk_id: batch.chunk_id,
                                    minichunks: remaining_minichunks,
                                    params: batch.params,
                                    accumulator: batch.accumulator,
                                    priority: batch.priority,
                                };
                                let mut pending_batches = self.pending_minichunk_batches.lock().unwrap();
                                pending_batches.push(remaining_batch);
                            }
                            // Break from processing this batch but continue loop to check workspace availability
                            break;
                        }
                        processed_any = true;
                        processed_in_batch += workspace_minichunks.len();
                    }
                    
                    if processed_in_batch > 0 {
                        println!("Successfully queued {} minichunks from this batch", processed_in_batch);
                    }
                }
                None => {
                    // No more pending batches
                    break;
                }
            }
        }
        
        // Don't end or submit the frame's encoder - that's handled by the render loop
        if processed_any {
            println!("Recorded minichunk processing commands to frame encoder");
        }
    }
    
    /// Process pending GPU commands on the main thread
    pub fn process_commands(&self, gfx: &dyn crate::gfx::Gfx) {
        // No longer need BufferType or ComputeDispatch with the new encoder API
        
        // First check if we should process any completed readbacks
        // This is important to free up workspaces for minichunk processing
        if let Ok(ring_buffer) = self.worldgen_ring_buffer.try_lock() {
            if ring_buffer.is_some() {
                drop(ring_buffer);
                let current_frame = self.readback_manager.current_frame();
                self.readback_manager.process_completed_readbacks(gfx, current_frame);
            }
        }
        
        // First, try to process any pending worldgen requests if we now have an active frame
        if gfx.get_frame_encoder().is_some() {
            let mut pending = self.pending_worldgen_requests.lock().unwrap();
            if !pending.is_empty() {
                println!("Found {} pending GPU worldgen requests to process", pending.len());
            }
            let requests: Vec<_> = pending.drain(..).collect();
            drop(pending);
            
            for (bounds, params, result_sender) in requests {
                println!("Processing pending GPU worldgen request for bounds [{:.1},{:.1},{:.1}] to [{:.1},{:.1},{:.1}]",
                    bounds.min.x(), bounds.min.y(), bounds.min.z(),
                    bounds.max.x(), bounds.max.y(), bounds.max.z());
                
                if let Some(cmd_buffer) = gfx.get_frame_encoder() {
                    
                    // Initialize ring buffer if needed
                    let mut ring_buffer_opt = self.worldgen_ring_buffer.lock().unwrap();
                    if ring_buffer_opt.is_none() {
                        *ring_buffer_opt = Some(WorldgenRingBuffer::new(gfx, self.frames_in_flight));
                    }
                    drop(ring_buffer_opt);
                    
                    // Execute using deferred readback
                    let result = self.execute_gpu_worldgen_deferred(gfx, cmd_buffer, bounds, params, result_sender.clone());
                    if let Err(e) = result {
                        println!("Deferred worldgen failed: {}", e);
                        let _ = result_sender.send(Err(e));
                    }
                }
            }
            
            // Always try to process any pending minichunk batches
            // This ensures continuous processing even if no new requests come in
            self.process_pending_minichunk_batches(gfx);
        }
        
        while let Ok(command) = self.receiver.try_recv() {
            match command {
                MainThreadCommand::CreateBuffer { size, id } => {
                    // In real implementation, create GPU buffer
                    println!("Main thread: Create buffer {} with size {}", id, size);
                }
                MainThreadCommand::UpdateBuffer { id, data } => {
                    // In real implementation, update GPU buffer
                    println!("Main thread: Update buffer {} with {} bytes", id, data.len());
                }
                MainThreadCommand::DispatchCompute { shader, workgroups } => {
                    // In real implementation, dispatch compute shader
                    println!("Main thread: Dispatch compute shader {} with workgroups {:?}", shader, workgroups);
                }
                MainThreadCommand::ReadBuffer { id, callback } => {
                    // In real implementation, read GPU buffer
                    println!("Main thread: Read buffer {}", id);
                    // For now, send dummy data
                    let _ = callback.send(vec![0u8; 1024]);
                }
                MainThreadCommand::ExecuteGpuWorldgen { bounds, params, result_sender } => {
                    println!("Main thread: Execute GPU worldgen for bounds [{:.1},{:.1},{:.1}] to [{:.1},{:.1},{:.1}]",
                        bounds.min.x(), bounds.min.y(), bounds.min.z(),
                        bounds.max.x(), bounds.max.y(), bounds.max.z());
                    
                    // Try to execute using deferred system if frame command buffer is available
                    if let Some(cmd) = gfx.get_frame_encoder() {
                        // Initialize ring buffer if needed
                        let mut ring_buffer_opt = self.worldgen_ring_buffer.lock().unwrap();
                        if ring_buffer_opt.is_none() {
                            *ring_buffer_opt = Some(WorldgenRingBuffer::new(gfx, self.frames_in_flight));
                        }
                        drop(ring_buffer_opt);
                        
                        // Execute using deferred readback
                        let result = self.execute_gpu_worldgen_deferred(gfx, cmd, bounds.clone(), params.clone(), result_sender.clone());
                        if let Err(e) = result {
                            println!("Deferred worldgen failed: {}", e);
                            let _ = result_sender.send(Err(e));
                        }
                    } else {
                        // No active frame, queue the request for later
                        println!("No active frame, queuing GPU worldgen request for later");
                        let mut pending = self.pending_worldgen_requests.lock().unwrap();
                        pending.push((bounds, params, result_sender));
                    }
                }
            }
        }
    }
    
    fn execute_gpu_worldgen_deferred(
        &self,
        gfx: &dyn crate::gfx::Gfx,
        encoder: &mut dyn crate::gfx::GpuEncoder,
        bounds: super::gpu_worldgen::WorldBounds,
        params: super::gpu_worldgen::GenerationParams,
        result_sender: mpsc::Sender<Result<super::gpu_worldgen::VoxelWorkspace, String>>,
    ) -> Result<(), String> {
        // Check if this is a chunk-aligned request
        let dims = bounds.dimensions();
        if dims.0 == super::gpu_worldgen::CHUNK_SIZE && 
           dims.1 == super::gpu_worldgen::CHUNK_SIZE && 
           dims.2 == super::gpu_worldgen::CHUNK_SIZE {
            // Process as minichunks with accumulation
            return self.execute_gpu_worldgen_minichunked(gfx, encoder, bounds, params, result_sender);
        }
        
        // Otherwise use original method
        self.execute_gpu_worldgen_original(gfx, encoder, bounds, params, result_sender)
    }
    
    fn execute_gpu_worldgen_minichunked(
        &self,
        gfx: &dyn crate::gfx::Gfx,
        encoder: &mut dyn crate::gfx::GpuEncoder,
        bounds: super::gpu_worldgen::WorldBounds,
        params: super::gpu_worldgen::GenerationParams,
        result_sender: mpsc::Sender<Result<super::gpu_worldgen::VoxelWorkspace, String>>,
    ) -> Result<(), String> {
        use super::gpu_worldgen::{ChunkId, ChunkAccumulator, MINICHUNK_SIZE, CHUNK_SIZE};
        
        // Calculate chunk ID from bounds
        let chunk_id = ChunkId(
            (bounds.min.x() / (CHUNK_SIZE as f32 * bounds.voxel_size)) as i32,
            (bounds.min.y() / (CHUNK_SIZE as f32 * bounds.voxel_size)) as i32,
            (bounds.min.z() / (CHUNK_SIZE as f32 * bounds.voxel_size)) as i32,
        );
        
        println!("Processing chunk {:?} as minichunks", chunk_id);
        
        // Get or create accumulator for this chunk
        let accumulator = {
            let mut pending = self.pending_chunks.lock().unwrap();
            pending.entry(chunk_id)
                .or_insert_with(|| Arc::new(Mutex::new(ChunkAccumulator::new())))
                .clone()
        };
        
        // Split into minichunks and queue them
        let minichunks = bounds.split_into_minichunks();
        println!("Queuing {} minichunks for chunk {:?}", minichunks.len(), chunk_id);
        
        // Validate we have the expected number of minichunks
        let minichunks_per_axis = CHUNK_SIZE / MINICHUNK_SIZE; // 64/8 = 8
        let expected_minichunks = (minichunks_per_axis * minichunks_per_axis * minichunks_per_axis) as usize; // 8*8*8 = 512
        if minichunks.len() != expected_minichunks {
            println!("WARNING: Expected {} minichunks but got {} (chunk size: {}, minichunk size: {}, per axis: {})", 
                    expected_minichunks, minichunks.len(), CHUNK_SIZE, MINICHUNK_SIZE, minichunks_per_axis);
        }
        
        // Store the result sender with the chunk
        {
            let mut senders = self.chunk_result_senders.lock().unwrap();
            senders.insert(chunk_id, result_sender);
        }
        
        // Process minichunks in batches to avoid exhausting ring buffer
        // Get workgroup budget from adaptive scheduler
        let workgroup_budget = self.adaptive_scheduler.lock().unwrap().get_workgroup_budget() as usize;
        // Each workspace can handle multiple minichunks based on PID controller
        let minichunks_per_workspace = workgroup_budget.max(1).min(16); // Clamp between 1-16 minichunks per workspace
        let batch_size = minichunks_per_workspace * ((self.frames_in_flight * 9) / 10).max(1); // Use 90% of workspaces
        let minichunk_iter = minichunks.into_iter().enumerate();
        let minichunk_batches: Vec<Vec<_>> = minichunk_iter
            .collect::<Vec<_>>()
            .chunks(batch_size)
            .map(|chunk| chunk.to_vec())
            .collect();
        
        let total_minichunks = minichunk_batches.iter().map(|b| b.len()).sum::<usize>();
        println!("Processing {} minichunks in {} batches of up to {} each (frames_in_flight: {})", 
                 total_minichunks, 
                 minichunk_batches.len(), 
                 batch_size,
                 self.frames_in_flight);
        
        // Queue first batch immediately and store remaining batches
        let mut batches_iter = minichunk_batches.into_iter();
        
        if let Some(first_batch) = batches_iter.next() {
            // Process minichunks in groups per workspace
            let workspace_batches: Vec<Vec<_>> = first_batch
                .chunks(minichunks_per_workspace)
                .map(|chunk| chunk.to_vec())
                .collect();
            
            println!("PID controller: Processing {} minichunks per workspace (workgroup budget: {})", 
                    minichunks_per_workspace, workgroup_budget);
            
            for workspace_minichunks in workspace_batches {
                // Queue multiple minichunks for a single workspace
                self.queue_minichunks_to_workspace(
                    gfx,
                    encoder,
                    workspace_minichunks,
                    params.clone(),
                    chunk_id,
                    accumulator.clone(),
                )?;
            }
        }
        
        // Queue remaining batches for later processing
        for batch in batches_iter {
            let pending_batch = PendingMinichunkBatch {
                chunk_id,
                minichunks: batch,
                params: params.clone(),
                accumulator: accumulator.clone(),
                priority: 0, // Default priority, can be overridden by caller
            };
            
            let mut pending_batches = self.pending_minichunk_batches.lock().unwrap();
            pending_batches.push(pending_batch);
        }
        
        Ok(())
    }
    
    fn queue_minichunks_to_workspace(
        &self,
        gfx: &dyn crate::gfx::Gfx,
        encoder: &mut dyn crate::gfx::GpuEncoder,
        minichunks: Vec<(usize, super::gpu_worldgen::WorldBounds)>,
        params: super::gpu_worldgen::GenerationParams,
        chunk_id: super::gpu_worldgen::ChunkId,
        accumulator: Arc<Mutex<super::gpu_worldgen::ChunkAccumulator>>,
    ) -> Result<(), String> {
        use super::gpu_worldgen::MINICHUNK_SIZE;
        // No longer need BufferType with the new encoder API
        
        if minichunks.is_empty() {
            return Ok(());
        }
        
        // Get workspace from ring buffer - extract needed info and release lock quickly
        let (workspace_buffers, workspace_id) = {
            let mut ring_buffer_opt = self.worldgen_ring_buffer.lock().unwrap();
            let ring_buffer = ring_buffer_opt.as_mut()
                .ok_or_else(|| "Ring buffer not initialized".to_string())?;
            
            let workspace = ring_buffer.get_next_workspace()
                .ok_or_else(|| "No available workspace in ring buffer".to_string())?;
            
            // Calculate total voxel count for all minichunks
            let minichunk_voxel_count = (MINICHUNK_SIZE * MINICHUNK_SIZE * MINICHUNK_SIZE) as usize;
            let total_voxel_count = minichunk_voxel_count * minichunks.len();
            
            // Update workspace metadata - store first minichunk bounds as reference
            workspace.bounds = Some(minichunks[0].1.clone());
            workspace.voxel_count = total_voxel_count;
            workspace.frame_submitted = None;
            
            // Extract buffer pointers and workspace id
            let buffers = (
                workspace.sdf_buffer,
                workspace.brush_buffer,
                workspace.params_buffer,
                workspace.output_buffer,
                workspace.world_params_buffer,
                workspace.output_voxels_buffer,
            );
            let id = workspace.workspace_id;
            
            (buffers, id)
        }; // Release ring buffer lock here
        
        println!("Processing {} minichunks in workspace {}", minichunks.len(), workspace_id);
        
        // Unpack workspace buffers
        let (sdf_buffer, brush_buffer, params_buffer, output_buffer, world_params_buffer, output_voxels_buffer) = workspace_buffers;
        
        // Write SDF parameters to buffer (bounds, resolution, root node index)
        // This is the SdfParamsBuffer structure from the shader
        let mut sdf_params_data = Vec::new();
        
        // Calculate overall bounds for all minichunks
        let mut overall_min = minichunks[0].1.min;
        let mut overall_max = minichunks[0].1.max;
        
        // Find the actual bounding box of all minichunks
        for (_, bounds) in &minichunks {
            overall_min = Vec3::new([
                overall_min.x().min(bounds.min.x()),
                overall_min.y().min(bounds.min.y()),
                overall_min.z().min(bounds.min.z()),
            ]);
            overall_max = Vec3::new([
                overall_max.x().max(bounds.max.x()),
                overall_max.y().max(bounds.max.y()),
                overall_max.z().max(bounds.max.z()),
            ]);
        }
        
        println!("Overall bounds: [{}, {}, {}] to [{}, {}, {}]", 
                overall_min.x(), overall_min.y(), overall_min.z(),
                overall_max.x(), overall_max.y(), overall_max.z());
        
        // bounds_min (vec4)
        sdf_params_data.extend_from_slice(&overall_min.x().to_le_bytes());
        sdf_params_data.extend_from_slice(&overall_min.y().to_le_bytes());
        sdf_params_data.extend_from_slice(&overall_min.z().to_le_bytes());
        sdf_params_data.extend_from_slice(&0.0f32.to_le_bytes()); // padding
        
        // bounds_max (vec4)
        sdf_params_data.extend_from_slice(&overall_max.x().to_le_bytes());
        sdf_params_data.extend_from_slice(&overall_max.y().to_le_bytes());
        sdf_params_data.extend_from_slice(&overall_max.z().to_le_bytes());
        sdf_params_data.extend_from_slice(&0.0f32.to_le_bytes()); // padding
        
        // resolution (uvec4) - overall resolution for SDF evaluation
        // This must match what we pass to worldgen_generate_adaptive
        let overall_size = overall_max - overall_min;
        let resolution_x = (overall_size.x() / minichunks[0].1.voxel_size).ceil() as u32;
        let resolution_y = (overall_size.y() / minichunks[0].1.voxel_size).ceil() as u32;
        let resolution_z = (overall_size.z() / minichunks[0].1.voxel_size).ceil() as u32;
        
        sdf_params_data.extend_from_slice(&resolution_x.to_le_bytes());
        sdf_params_data.extend_from_slice(&resolution_y.to_le_bytes());
        sdf_params_data.extend_from_slice(&resolution_z.to_le_bytes());
        sdf_params_data.extend_from_slice(&0u32.to_le_bytes()); // root node index = 0
        
        // SAFETY: Converting buffer pointer to reference for encoder API
        unsafe {
            encoder.write_buffer(&*(params_buffer as *const crate::gfx::Buffer), &sdf_params_data, 0);
        }
        
        // Serialize and write SDF tree to buffer
        use super::sdf_serialization::{SdfSerializer, GpuSdfNode};
        
        // Use the SDF tree from the generation parameters
        let sdf_nodes = serialize_sdf_tree(&params.sdf_tree)?;
        
        // Convert to bytes
        let sdf_bytes: Vec<u8> = sdf_nodes.iter()
            .flat_map(|node| {
                let mut bytes = Vec::new();
                // Write node_type and padding
                bytes.extend_from_slice(&node.node_type.to_le_bytes());
                bytes.extend_from_slice(&node._padding1[0].to_le_bytes());
                bytes.extend_from_slice(&node._padding1[1].to_le_bytes());
                bytes.extend_from_slice(&node._padding1[2].to_le_bytes());
                // Write params (4x4 floats)
                for param_row in &node.params {
                    for param in param_row {
                        bytes.extend_from_slice(&param.to_le_bytes());
                    }
                }
                // Write children and padding
                bytes.extend_from_slice(&node.children[0].to_le_bytes());
                bytes.extend_from_slice(&node.children[1].to_le_bytes());
                bytes.extend_from_slice(&node._padding2[0].to_le_bytes());
                bytes.extend_from_slice(&node._padding2[1].to_le_bytes());
                bytes
            })
            .collect();
        
        // SAFETY: Converting buffer pointer to reference for encoder API
        unsafe {
            encoder.write_buffer(&*(sdf_buffer as *const crate::gfx::Buffer), &sdf_bytes, 0);
        }
        
        // Write brush parameters buffer (BrushParams structure from shader)
        let mut brush_params_data = Vec::new();
        
        // bounds_min (vec4) - same as SDF params
        brush_params_data.extend_from_slice(&overall_min.x().to_le_bytes());
        brush_params_data.extend_from_slice(&overall_min.y().to_le_bytes());
        brush_params_data.extend_from_slice(&overall_min.z().to_le_bytes());
        brush_params_data.extend_from_slice(&0.0f32.to_le_bytes());
        
        // bounds_max (vec4)
        brush_params_data.extend_from_slice(&overall_max.x().to_le_bytes());
        brush_params_data.extend_from_slice(&overall_max.y().to_le_bytes());
        brush_params_data.extend_from_slice(&overall_max.z().to_le_bytes());
        brush_params_data.extend_from_slice(&0.0f32.to_le_bytes());
        
        // resolution (uvec4) - must match SDF field resolution
        brush_params_data.extend_from_slice(&resolution_x.to_le_bytes());
        brush_params_data.extend_from_slice(&resolution_y.to_le_bytes());
        brush_params_data.extend_from_slice(&resolution_z.to_le_bytes());
        brush_params_data.extend_from_slice(&0u32.to_le_bytes());
        
        // layer_count (uvec4) - set to actual layer count
        let layer_count = params.brush_schema.layers.len() as u32;
        brush_params_data.extend_from_slice(&layer_count.to_le_bytes());
        brush_params_data.extend_from_slice(&0u32.to_le_bytes());
        brush_params_data.extend_from_slice(&0u32.to_le_bytes());
        brush_params_data.extend_from_slice(&0u32.to_le_bytes());
        
        // Write brush data to buffers (instructions and layers)
        let (brush_instructions, brush_layers) = params.brush_schema.to_gpu_bytes();
        
        // For now, concatenate them into a single buffer
        // TODO: Use separate buffers for instructions and layers
        let mut brush_data = brush_instructions;
        let instruction_size = brush_data.len();
        brush_data.extend_from_slice(&brush_layers);
        
        // Store the offset where layers start for the shader
        // This should be passed to the shader via push constants
        println!("Brush instructions size: {} bytes, layers start at offset {}", 
                 instruction_size, instruction_size);
        
        // SAFETY: Converting buffer pointer to reference for encoder API
        unsafe {
            encoder.write_buffer(&*(brush_buffer as *const crate::gfx::Buffer), &brush_data, 0);
        }
        
        // Write world parameters for each minichunk
        // We'll pack multiple minichunk bounds into the world params buffer
        let mut world_params_data = Vec::new();
        for (_, minichunk_bounds) in &minichunks {
            // Calculate proper resolution based on bounds and voxel size
            let dims = minichunk_bounds.dimensions();
            let world_params = super::gpu_worldgen::WorldParams {
                bounds_min: minichunk_bounds.min,
                bounds_max: minichunk_bounds.max,
                voxel_size: minichunk_bounds.voxel_size,
                resolution: Vec3::new([
                    dims.0 as f32,
                    dims.1 as f32,
                    dims.2 as f32,
                ]),
            };
            world_params_data.extend_from_slice(&world_params.to_bytes());
        }
        // SAFETY: Converting buffer pointer to reference for encoder API
        unsafe {
            encoder.write_buffer(&*(world_params_buffer as *const crate::gfx::Buffer), &world_params_data, 0);
        }
        
        // Get Vulkan implementation
        let vulkan = gfx.as_any()
            .downcast_ref::<crate::gfx::vk::Vulkan>()
            .ok_or_else(|| "GPU worldgen requires Vulkan backend".to_string())?;
        
        // Execute worldgen with multiple workgroups - one per minichunk
        let num_workgroups = minichunks.len() as u32;
        // Calculate total resolution for all minichunks
        // The SDF needs to cover the entire batch bounds, not just one minichunk
        let overall_bounds_size = overall_max - overall_min;
        let total_resolution_x = (overall_bounds_size.x() / minichunks[0].1.voxel_size).ceil() as u32;
        let total_resolution_y = (overall_bounds_size.y() / minichunks[0].1.voxel_size).ceil() as u32;
        let total_resolution_z = (overall_bounds_size.z() / minichunks[0].1.voxel_size).ceil() as u32;
        
        vulkan.worldgen_generate_adaptive_with_brush(
            encoder,
            [overall_min.x(), overall_min.y(), overall_min.z()], // Overall batch bounds min
            [overall_max.x(), overall_max.y(), overall_max.z()], // Overall batch bounds max
            [total_resolution_x, total_resolution_y, total_resolution_z], // Total resolution for entire batch
            minichunks[0].1.voxel_size,
            sdf_buffer,
            params_buffer,
            output_buffer,
            world_params_buffer,
            output_voxels_buffer,
            brush_buffer,  // Pass the brush buffer
            0, // start_offset
            num_workgroups, // Multiple workgroups for multiple minichunks
        ).map_err(|e| format!("GPU worldgen generation failed: {}", e))?;
        
        // Submit deferred readback for all minichunks
        let minichunk_voxel_count = (MINICHUNK_SIZE * MINICHUNK_SIZE * MINICHUNK_SIZE) as usize;
        let total_size_bytes = minichunk_voxel_count * minichunks.len() * std::mem::size_of::<u32>(); // Voxels stored as u32 on GPU
        
        let chunk_id_copy = chunk_id;
        let accumulator_copy = accumulator.clone();
        let pending_chunks = self.pending_chunks.clone();
        let chunk_result_senders = self.chunk_result_senders.clone();
        let minichunks_copy = minichunks.clone();
        let worldgen_ring_buffer = self.worldgen_ring_buffer.clone();
        
        // Submit readback for all minichunks in this workspace
        self.readback_manager.submit_readback(
            output_voxels_buffer,
            total_size_bytes,
            move |data| {
                println!("Minichunk batch readback complete for workspace {} ({} minichunks, {} bytes)", 
                         workspace_id, minichunks_copy.len(), data.len());
                
                // Convert GPU data to voxels for each minichunk
                let bytes_per_minichunk = minichunk_voxel_count * std::mem::size_of::<u32>();
                
                for (i, (idx, _)) in minichunks_copy.iter().enumerate() {
                    let start_offset = i * bytes_per_minichunk;
                    let end_offset = start_offset + bytes_per_minichunk;
                    
                    if end_offset <= data.len() {
                        let minichunk_data = &data[start_offset..end_offset];
                        let mut voxels = Vec::with_capacity(minichunk_voxel_count);
                        
                        // Convert u32 GPU data to Voxel
                        for j in (0..minichunk_data.len()).step_by(4) {
                            if j + 3 < minichunk_data.len() {
                                let value = u32::from_le_bytes([
                                    minichunk_data[j],
                                    minichunk_data[j + 1],
                                    minichunk_data[j + 2],
                                    minichunk_data[j + 3],
                                ]);
                                voxels.push(super::Voxel(value as usize));
                            }
                        }
                        
                        // Calculate minichunk offset
                        let minichunk_offset = Vec3::new([
                            ((idx % 8) * MINICHUNK_SIZE as usize) as f32,
                            (((idx / 8) % 8) * MINICHUNK_SIZE as usize) as f32,
                            ((idx / 64) * MINICHUNK_SIZE as usize) as f32,
                        ]);
                        
                        // Add to accumulator
                        if let Ok(mut acc) = accumulator_copy.lock() {
                            let offset_u32 = Vec3::new([
                                minichunk_offset.x() as u32,
                                minichunk_offset.y() as u32,
                                minichunk_offset.z() as u32,
                            ]);
                            acc.add_minichunk(offset_u32, &voxels);
                            
                            // Check if chunk is complete
                            let completed = acc.completed_minichunks.load(Ordering::Relaxed);
                            if completed >= acc.total_minichunks {
                                println!("Chunk {:?} complete! All {} minichunks processed", chunk_id_copy, acc.total_minichunks);
                                
                                // Send completed chunk
                                if let Some(sender) = chunk_result_senders.lock().unwrap().remove(&chunk_id_copy) {
                                    let metadata = super::gpu_worldgen::WorkspaceMetadata {
                                        bounds: super::gpu_worldgen::WorldBounds {
                                            min: Vec3::new([
                                                chunk_id_copy.0 as f32 * super::gpu_worldgen::CHUNK_SIZE as f32,
                                                chunk_id_copy.1 as f32 * super::gpu_worldgen::CHUNK_SIZE as f32,
                                                chunk_id_copy.2 as f32 * super::gpu_worldgen::CHUNK_SIZE as f32,
                                            ]),
                                            max: Vec3::new([
                                                (chunk_id_copy.0 + 1) as f32 * super::gpu_worldgen::CHUNK_SIZE as f32,
                                                (chunk_id_copy.1 + 1) as f32 * super::gpu_worldgen::CHUNK_SIZE as f32,
                                                (chunk_id_copy.2 + 1) as f32 * super::gpu_worldgen::CHUNK_SIZE as f32,
                                            ]),
                                            voxel_size: 1.0,
                                        },
                                        generation_time: std::time::Duration::from_millis(0),
                                        voxel_count: acc.voxels.len(),
                                        non_empty_count: acc.voxels.iter().filter(|v| v.0 != 0).count(),
                                    };
                                    
                                    let workspace = super::gpu_worldgen::VoxelWorkspace {
                                        voxels: acc.voxels.clone(),
                                        dimensions: Vec3::new([
                                            super::gpu_worldgen::CHUNK_SIZE as f32,
                                            super::gpu_worldgen::CHUNK_SIZE as f32,
                                            super::gpu_worldgen::CHUNK_SIZE as f32,
                                        ]),
                                        metadata,
                                    };
                                    
                                    let _ = sender.send(Ok(workspace));
                                }
                                
                                // Remove from pending chunks
                                pending_chunks.lock().unwrap().remove(&chunk_id_copy);
                            }
                        }
                    }
                }
                
                // Release workspace AFTER processing data
                let mut ring_buffer_opt = worldgen_ring_buffer.lock().unwrap();
                if let Some(ring_buffer) = ring_buffer_opt.as_mut() {
                    ring_buffer.release_workspace(workspace_id);
                }
            }
        );
        
        Ok(())
    }
    
    fn queue_minichunk_generation(
        &self,
        gfx: &dyn crate::gfx::Gfx,
        encoder: &mut dyn crate::gfx::GpuEncoder,
        minichunk_bounds: super::gpu_worldgen::WorldBounds,
        params: super::gpu_worldgen::GenerationParams,
        chunk_id: super::gpu_worldgen::ChunkId,
        minichunk_offset: crate::math::Vec3<f32>,
        accumulator: Arc<Mutex<super::gpu_worldgen::ChunkAccumulator>>,
    ) -> Result<(), String> {
        use super::gpu_worldgen::MINICHUNK_SIZE;
        // No longer need BufferType with the new encoder API
        
        // Get workspace from ring buffer - extract needed info and release lock quickly
        let (workspace_buffers, workspace_id) = {
            let mut ring_buffer_opt = self.worldgen_ring_buffer.lock().unwrap();
            let ring_buffer = ring_buffer_opt.as_mut()
                .ok_or_else(|| "Ring buffer not initialized".to_string())?;
            
            let workspace = ring_buffer.get_next_workspace()
                .ok_or_else(|| "No available workspace in ring buffer".to_string())?;
            
            // Calculate minichunk voxel count (8x8x8 = 512)
            let minichunk_voxel_count = (MINICHUNK_SIZE * MINICHUNK_SIZE * MINICHUNK_SIZE) as usize;
            
            // Update workspace metadata
            workspace.bounds = Some(minichunk_bounds.clone());
            workspace.voxel_count = minichunk_voxel_count;
            // Don't use readback manager's frame - it starts at 0
            // Instead, we'll set this when we submit the readback
            workspace.frame_submitted = None;
            
            // Extract buffer pointers and workspace id
            let buffers = (
                workspace.sdf_buffer,
                workspace.brush_buffer,
                workspace.params_buffer,
                workspace.output_buffer,
                workspace.world_params_buffer,
                workspace.output_voxels_buffer,
            );
            let id = workspace.workspace_id;
            
            (buffers, id)
        }; // Release ring buffer lock here
        
        // Calculate minichunk voxel count (8x8x8 = 512)
        let minichunk_voxel_count = (MINICHUNK_SIZE * MINICHUNK_SIZE * MINICHUNK_SIZE) as usize;
        
        // Unpack workspace buffers
        let (sdf_buffer, brush_buffer, params_buffer, output_buffer, world_params_buffer, output_voxels_buffer) = workspace_buffers;
        
        // Write generation parameters to buffer
        let params_data = params.to_bytes();
        // SAFETY: Converting buffer pointer to reference for encoder API
        unsafe {
            encoder.write_buffer(&*(params_buffer as *const crate::gfx::Buffer), &params_data, 0);
        }
        
        // Write brush data to buffers (instructions and layers)
        let (brush_instructions, brush_layers) = params.brush_schema.to_gpu_bytes();
        
        // For now, concatenate them into a single buffer
        // TODO: Use separate buffers for instructions and layers
        let mut brush_data = brush_instructions;
        let instruction_size = brush_data.len();
        brush_data.extend_from_slice(&brush_layers);
        
        // Store the offset where layers start for the shader
        // This should be passed to the shader via push constants
        println!("Brush instructions size: {} bytes, layers start at offset {}", 
                 instruction_size, instruction_size);
        
        // SAFETY: Converting buffer pointer to reference for encoder API
        unsafe {
            encoder.write_buffer(&*(brush_buffer as *const crate::gfx::Buffer), &brush_data, 0);
        }
        
        // Write world parameters
        let world_params = super::gpu_worldgen::WorldParams {
            bounds_min: minichunk_bounds.min,
            bounds_max: minichunk_bounds.max,
            voxel_size: minichunk_bounds.voxel_size,
            resolution: Vec3::new([
                MINICHUNK_SIZE as f32,
                MINICHUNK_SIZE as f32,
                MINICHUNK_SIZE as f32,
            ]),
        };
        let world_params_data = world_params.to_bytes();
        // SAFETY: Converting buffer pointer to reference for encoder API
        unsafe {
            encoder.write_buffer(&*(world_params_buffer as *const crate::gfx::Buffer), &world_params_data, 0);
        }
        
        // Execute GPU worldgen for this minichunk
        // Get Vulkan implementation
        let vulkan = gfx.as_any()
            .downcast_ref::<crate::gfx::vk::Vulkan>()
            .ok_or_else(|| "GPU worldgen requires Vulkan backend".to_string())?;
        
        // Execute worldgen on the provided encoder with adaptive processing and brush support
        vulkan.worldgen_generate_adaptive_with_brush(
            encoder,
            [minichunk_bounds.min.x(), minichunk_bounds.min.y(), minichunk_bounds.min.z()],
            [minichunk_bounds.max.x(), minichunk_bounds.max.y(), minichunk_bounds.max.z()],
            [MINICHUNK_SIZE, MINICHUNK_SIZE, MINICHUNK_SIZE],
            minichunk_bounds.voxel_size,
            sdf_buffer,
            params_buffer,
            output_buffer,
            world_params_buffer,
            output_voxels_buffer,
            brush_buffer,  // Pass the brush buffer
            0, // start_offset
            1, // One workgroup for this single minichunk
        ).map_err(|e| format!("GPU worldgen generation failed: {}", e))?;
        
        // Submit deferred readback for the minichunk
        let minichunk_size_bytes = minichunk_voxel_count * std::mem::size_of::<u32>(); // Voxels stored as u32 on GPU
        let chunk_id_copy = chunk_id;
        let minichunk_offset_copy = minichunk_offset;
        let accumulator_copy = accumulator.clone();
        let pending_chunks = self.pending_chunks.clone();
        let chunk_result_senders = self.chunk_result_senders.clone();
        let ring_buffer_clone = self.worldgen_ring_buffer.clone();
        
        self.readback_manager.submit_readback(
            output_voxels_buffer,
            minichunk_size_bytes,
            move |data| {
                // Convert GPU data to voxels
                let mut voxels = Vec::with_capacity(minichunk_voxel_count);
                let mut non_air_count = 0;
                for i in 0..minichunk_voxel_count {
                    let offset = i * 4;
                    if offset + 3 < data.len() {
                        let value = u32::from_le_bytes([
                            data[offset],
                            data[offset + 1],
                            data[offset + 2],
                            data[offset + 3],
                        ]);
                        if value != 0 {
                            non_air_count += 1;
                        }
                        voxels.push(super::Voxel(value as usize));
                    } else {
                        voxels.push(super::Voxel(0));
                    }
                }
                
                // Always print debug info for minichunks with negative Z
                let z_coord = chunk_id_copy.2 * 64 + minichunk_offset_copy.z() as i32;
                if z_coord < 0 {
                    println!("Minichunk at chunk {:?} offset {:?} (world Z: {}) has {} non-air voxels out of {}", 
                            chunk_id_copy, minichunk_offset_copy, z_coord, non_air_count, minichunk_voxel_count);
                    
                    // Print first few voxel values
                    if non_air_count == 0 {
                        print!("  First 10 voxel values (all should be non-zero!): ");
                        for i in 0..10.min(voxels.len()) {
                            print!("{} ", voxels[i].0);
                        }
                        println!();
                    }
                } else {
                    println!("Minichunk at {:?} has {} non-air voxels out of {}", 
                            minichunk_offset_copy, non_air_count, minichunk_voxel_count);
                }
                
                // Add to accumulator
                let mut acc = accumulator_copy.lock().unwrap();
                acc.add_minichunk(
                    Vec3::new([
                        minichunk_offset_copy.x() as u32,
                        minichunk_offset_copy.y() as u32,
                        minichunk_offset_copy.z() as u32,
                    ]),
                    &voxels,
                );
                
                // Check if chunk is complete
                if acc.is_complete() {
                    println!("Chunk {:?} complete with all {} minichunks", chunk_id_copy, acc.total_minichunks);
                    
                    // Get result sender
                    let sender = {
                        let mut senders = chunk_result_senders.lock().unwrap();
                        senders.remove(&chunk_id_copy)
                    };
                    
                    if let Some(sender) = sender {
                        // Create final workspace from accumulated data
                        let workspace = super::gpu_worldgen::VoxelWorkspace {
                            voxels: acc.voxels.clone(),
                            dimensions: Vec3::new([
                                CHUNK_SIZE as f32,
                                CHUNK_SIZE as f32,
                                CHUNK_SIZE as f32,
                            ]),
                            metadata: super::gpu_worldgen::WorkspaceMetadata {
                                bounds: super::gpu_worldgen::WorldBounds {
                                    min: Vec3::new([
                                        chunk_id_copy.0 as f32 * CHUNK_SIZE as f32,
                                        chunk_id_copy.1 as f32 * CHUNK_SIZE as f32,
                                        chunk_id_copy.2 as f32 * CHUNK_SIZE as f32,
                                    ]),
                                    max: Vec3::new([
                                        (chunk_id_copy.0 + 1) as f32 * CHUNK_SIZE as f32,
                                        (chunk_id_copy.1 + 1) as f32 * CHUNK_SIZE as f32,
                                        (chunk_id_copy.2 + 1) as f32 * CHUNK_SIZE as f32,
                                    ]),
                                    voxel_size: 1.0,
                                },
                                generation_time: std::time::Duration::from_millis(0),
                                voxel_count: (CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE) as usize,
                                non_empty_count: acc.voxels.iter().filter(|v| v.0 != 0).count(),
                            },
                        };
                        
                        let _ = sender.send(Ok(workspace));
                    }
                    
                    // Remove from pending chunks
                    let mut pending = pending_chunks.lock().unwrap();
                    pending.remove(&chunk_id_copy);
                } else {
                    let completed = acc.completed_minichunks.load(Ordering::Relaxed);
                    println!("Chunk {:?} progress: {:.1}% ({}/{} minichunks)", 
                            chunk_id_copy, acc.progress() * 100.0, completed, acc.total_minichunks);
                }
                
                // Release the ring buffer workspace
                if let Ok(mut rb) = ring_buffer_clone.lock() {
                    if let Some(rb) = rb.as_mut() {
                        rb.release_workspace(workspace_id);
                    }
                }
            },
        );
        
        Ok(())
    }
    
    fn execute_gpu_worldgen_original(
        &self,
        gfx: &dyn crate::gfx::Gfx,
        encoder: &mut dyn crate::gfx::GpuEncoder,
        bounds: super::gpu_worldgen::WorldBounds,
        params: super::gpu_worldgen::GenerationParams,
        result_sender: mpsc::Sender<Result<super::gpu_worldgen::VoxelWorkspace, String>>,
    ) -> Result<(), String> {
        let _zone = DEBUG.zone_begin("execute_gpu_worldgen_deferred");
        
        // No longer need BufferType with the new encoder API
        
        // Get the next available workspace
        let mut ring_buffer_opt = self.worldgen_ring_buffer.lock().unwrap();
        println!("Got ring buffer lock");
        let ring_buffer = ring_buffer_opt.as_mut()
            .ok_or_else(|| "Ring buffer not initialized".to_string())?;
        println!("Ring buffer is initialized");
        let workspace = ring_buffer.get_next_workspace()
            .ok_or_else(|| "No available workspace in ring buffer".to_string())?;
        println!("Got workspace at address: {:p}", workspace as *const _);
        println!("Workspace state: in_use={}, voxel_count={}, frame_submitted={:?}", 
                workspace.in_use, workspace.voxel_count, workspace.frame_submitted);
        
        // Store bounds and metadata
        let dims = bounds.dimensions();
        let voxel_count = (dims.0 * dims.1 * dims.2) as usize;
        println!("Worldgen dimensions: {}x{}x{} = {} voxels", dims.0, dims.1, dims.2, voxel_count);
        
        // Validate buffer size
        let required_size = std::mem::size_of::<u32>() * voxel_count;
        println!("Required output buffer size: {} bytes ({} MB)", required_size, required_size / (1024 * 1024));
        
        println!("About to set workspace.bounds...");
        workspace.bounds = Some(bounds.clone());
        println!("Successfully set workspace.bounds");
        workspace.voxel_count = voxel_count;
        workspace.frame_submitted = Some(self.readback_manager.current_frame());
        
        // Check buffer pointers before use
        println!("Checking workspace buffer pointers:");
        println!("  sdf_buffer: {:p}", workspace.sdf_buffer);
        println!("  brush_buffer: {:p}", workspace.brush_buffer);
        println!("  params_buffer: {:p}", workspace.params_buffer);
        println!("  output_buffer: {:p}", workspace.output_buffer);
        println!("  world_params_buffer: {:p}", workspace.world_params_buffer);
        println!("  output_voxels_buffer: {:p}", workspace.output_voxels_buffer);
        
        // Upload data to the workspace's buffers
        let sdf_data = self.convert_sdf_tree_for_gpu(&params.sdf_tree)?;
        println!("About to write to sdf_buffer at {:p}", workspace.sdf_buffer);
        // SAFETY: Converting buffer pointer to reference for encoder API
        unsafe {
            encoder.write_buffer(&*(workspace.sdf_buffer as *const crate::gfx::Buffer), &sdf_data, 0);
        }
        println!("Successfully wrote to sdf_buffer");
        
        let brush_data = self.convert_brushes_for_gpu(&params.brush_schema)?;
        // SAFETY: Converting buffer pointer to reference for encoder API
        unsafe {
            encoder.write_buffer(&*(workspace.brush_buffer as *const crate::gfx::Buffer), &brush_data, 0);
        }
        
        let params_data = self.serialize_params(&bounds, &params)?;
        // SAFETY: Converting buffer pointer to reference for encoder API
        unsafe {
            encoder.write_buffer(&*(workspace.params_buffer as *const crate::gfx::Buffer), &params_data, 0);
        }
        
        let world_params_data = vec![0u8; 64];
        // SAFETY: Converting buffer pointer to reference for encoder API
        unsafe {
            encoder.write_buffer(&*(workspace.world_params_buffer as *const crate::gfx::Buffer), &world_params_data, 0);
        }
        
        // Add memory barrier
        println!("Adding pre-worldgen memory barrier");
        encoder.memory_barrier();
        
        // Get Vulkan implementation
        println!("Getting Vulkan implementation");
        let vulkan = gfx.as_any()
            .downcast_ref::<crate::gfx::vk::Vulkan>()
            .ok_or_else(|| "GPU worldgen requires Vulkan backend".to_string())?;
        
        // Execute worldgen on the provided command buffer with brush buffer
        println!("Calling worldgen_generate with encoder and brush buffer");
        vulkan.worldgen_generate(
            encoder,
            [bounds.min.x(), bounds.min.y(), bounds.min.z()],
            [bounds.max.x(), bounds.max.y(), bounds.max.z()],
            [dims.0, dims.1, dims.2],
            bounds.voxel_size,
            workspace.sdf_buffer,
            workspace.params_buffer,
            workspace.output_buffer,
            workspace.world_params_buffer,
            workspace.output_voxels_buffer,
            workspace.brush_buffer,
        ).map_err(|e| format!("GPU worldgen generation failed: {}", e))?;
        
        // Add barrier after worldgen
        println!("Adding post-worldgen memory barrier");
        encoder.memory_barrier();
        
        // Submit readback request
        let output_size = std::mem::size_of::<u32>() * voxel_count;
        let workspace_id = workspace.workspace_id;
        let bounds_copy = bounds.clone();
        let ring_buffer_clone = self.worldgen_ring_buffer.clone();
        
        println!("Submitting readback for {} bytes (workspace {})", output_size, workspace_id);
        
        self.readback_manager.submit_readback(
            workspace.output_voxels_buffer,
            output_size,
            move |data| {
                println!("Readback callback triggered for workspace {}", workspace_id);
                
                // Convert bytes to voxels
                let mut voxels = Vec::with_capacity(voxel_count);
                for i in 0..voxel_count {
                    let offset = i * 4;
                    let value = u32::from_le_bytes([
                        data[offset],
                        data[offset + 1],
                        data[offset + 2],
                        data[offset + 3],
                    ]);
                    voxels.push(super::Voxel(value as usize));
                }
                
                // Count non-empty voxels
                let non_empty = voxels.iter().filter(|v| v.0 != 0).count();
                println!("Readback complete: {} non-empty voxels out of {}", non_empty, voxel_count);
                
                // Create workspace result
                let workspace = super::gpu_worldgen::VoxelWorkspace::from_gpu_buffer(voxels, bounds_copy, std::time::Duration::from_millis(0));
                
                // Release the ring buffer workspace
                if let Ok(mut rb) = ring_buffer_clone.lock() {
                    if let Some(rb) = rb.as_mut() {
                        rb.release_workspace(workspace_id);
                    }
                }
                
                // Send result through the channel
                println!("Sending result through channel");
                let _ = result_sender.send(Ok(workspace));
            },
        );
        
        Ok(())
    }
    
    
    fn serialize_params(
        &self,
        bounds: &super::gpu_worldgen::WorldBounds,
        _params: &super::gpu_worldgen::GenerationParams,
    ) -> Result<Vec<u8>, String> {
        // Serialize generation parameters to GPU format
        let mut data = Vec::new();
        
        // Bounds (min, max, voxel_size)
        data.extend_from_slice(&bounds.min.x().to_le_bytes());
        data.extend_from_slice(&bounds.min.y().to_le_bytes());
        data.extend_from_slice(&bounds.min.z().to_le_bytes());
        data.extend_from_slice(&0f32.to_le_bytes()); // padding
        
        data.extend_from_slice(&bounds.max.x().to_le_bytes());
        data.extend_from_slice(&bounds.max.y().to_le_bytes());
        data.extend_from_slice(&bounds.max.z().to_le_bytes());
        data.extend_from_slice(&bounds.voxel_size.to_le_bytes());
        
        // For SDF evaluation, use SDF resolution
        // For brush evaluation, it will use voxel dimensions from bounds
        let dims = bounds.dimensions();
        data.extend_from_slice(&dims.0.to_le_bytes());
        data.extend_from_slice(&dims.1.to_le_bytes());
        data.extend_from_slice(&dims.2.to_le_bytes());
        data.extend_from_slice(&0u32.to_le_bytes()); // root node index = 0
        
        // Layer count (required by brush evaluation shader)
        let layer_count = _params.brush_schema.layers.len() as u32;
        data.extend_from_slice(&layer_count.to_le_bytes());
        data.extend_from_slice(&0u32.to_le_bytes()); // padding y
        data.extend_from_slice(&0u32.to_le_bytes()); // padding z
        data.extend_from_slice(&0u32.to_le_bytes()); // padding w
        
        Ok(data)
    }
    
    
    fn convert_sdf_tree_for_gpu(&self, sdf_tree: &std::sync::Arc<dyn super::sdf::Sdf>) -> Result<Vec<u8>, String> {
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
        
        // Check if the SDF is a plane
        if let Some(plane) = sdf_tree.as_any().downcast_ref::<super::sdf::Plane>() {
            println!("Converting Plane SDF: normal=[{:.2}, {:.2}, {:.2}], distance={:.2}", 
                plane.normal.x(), plane.normal.y(), plane.normal.z(), plane.distance);
            
            let plane_node = GpuSdfNode {
                node_type: 2, // SDF_PLANE
                _padding1: [0; 3],
                params: [
                    [plane.normal.x(), plane.normal.y(), plane.normal.z(), plane.distance],
                    [0.0; 4],
                    [0.0; 4],
                    [0.0; 4],
                ],
                children: [0, 0],
                _padding2: [0; 2],
            };
            
            nodes.push(plane_node);
        } else {
            return Err(format!("Failed to convert SDF tree: unsupported SDF type. Only Plane SDFs are currently supported."));
        }
        
        // Convert to bytes
        let bytes = unsafe {
            std::slice::from_raw_parts(
                nodes.as_ptr() as *const u8,
                nodes.len() * std::mem::size_of::<GpuSdfNode>()
            ).to_vec()
        };
        
        Ok(bytes)
    }
    
    /// Extract command buffer from encoder for Vulkan operations
    /// This is a temporary workaround until the worldgen API is updated to use encoders
    fn get_command_buffer_from_encoder(encoder: &dyn crate::gfx::GpuEncoder) -> Result<*mut c_void, String> {
        // Downcast to VulkanEncoder
        let vulkan_encoder = encoder.as_any()
            .downcast_ref::<crate::gfx::vk::VulkanEncoder>()
            .ok_or_else(|| "Expected VulkanEncoder for Vulkan backend".to_string())?;
        
        // SAFETY: We need to access the command_buffer field directly
        // VulkanEncoder struct layout:
        // - renderer: Arc<Mutex<*mut zig::Renderer>> (size depends on arch, typically 8 bytes)
        // - command_buffer: *mut c_void (8 bytes on 64-bit)
        // - is_frame_encoder: bool (1 byte + padding)
        let cmd_buffer_ptr = unsafe {
            let encoder_ptr = vulkan_encoder as *const _ as *const u8;
            let cmd_buffer_offset = std::mem::size_of::<std::sync::Arc<std::sync::Mutex<*mut std::ffi::c_void>>>();
            let cmd_buffer_ptr_ptr = encoder_ptr.add(cmd_buffer_offset) as *const *mut std::ffi::c_void;
            *cmd_buffer_ptr_ptr as *mut c_void
        };
        
        Ok(cmd_buffer_ptr)
    }
    
    fn convert_brushes_for_gpu(&self, brush_schema: &super::gpu_worldgen::BrushSchema) -> Result<Vec<u8>, String> {
        // GPU Brush structure (matches GLSL layout)
        #[repr(C, align(16))]
        struct GpuBrush {
            voxel_type: u32,
            priority: i32,
            condition_count: u32,
            _padding: u32,
            conditions: [[f32; 4]; 8], // Up to 8 conditions
        }
        
        let mut brushes = Vec::new();
        
        // Convert actual brush layers from the schema
        for layer in &brush_schema.layers {
            if let Some(layered_brush) = layer.as_any().downcast_ref::<super::brush::LayeredBrush>() {
                // Convert each layer in the layered brush
                for brush_layer in &layered_brush.layers {
                    let mut gpu_brush = GpuBrush {
                        voxel_type: brush_layer.voxel.0 as u32,
                        priority: brush_layer.priority,
                        condition_count: 0,
                        _padding: 0,
                        conditions: [[0.0; 4]; 8],
                    };
                    
                    // Convert the condition to GPU format
                    match &brush_layer.condition {
                        super::brush::Condition::Depth { min, max } => {
                            gpu_brush.condition_count = 1;
                            gpu_brush.conditions[0] = [0.0, *min, *max, 0.0]; // Type 0 = depth condition
                        }
                        _ => {
                            // For now, skip unsupported conditions
                            continue;
                        }
                    }
                    
                    brushes.push(gpu_brush);
                }
            }
        }
        
        // If no brushes were converted, fail
        if brushes.is_empty() {
            return Err("Failed to convert brush schema: no valid brush layers found. Ensure synthesis provides valid LayeredBrush with Depth conditions.".to_string());
        }
        
        println!("Converted {} brush layers to GPU format", brushes.len());
        for (i, brush) in brushes.iter().enumerate() {
            println!("  Brush {}: voxel_type={}, priority={}, conditions={}", 
                i, brush.voxel_type, brush.priority, brush.condition_count);
        }
        
        // Convert to bytes
        let bytes = unsafe {
            std::slice::from_raw_parts(
                brushes.as_ptr() as *const u8,
                brushes.len() * std::mem::size_of::<GpuBrush>()
            ).to_vec()
        };
        
        Ok(bytes)
    }
}