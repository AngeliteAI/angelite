use crate::math::Vec3;
use crate::gfx::Gfx;
use super::{gpu_worldgen::{GpuWorldGenerator, WorldBounds, GenerationParams, VoxelWorkspace, CompressedChunk}, Voxel};
use super::gpu_thread_executor::{GpuThreadExecutor, MainThreadCommand, MainThreadCoordinator};
use std::sync::{Arc, Mutex, RwLock, Condvar};
use std::sync::mpsc::{channel, Sender, Receiver};
use std::collections::{VecDeque, HashMap};
use std::thread;
use std::time::{Duration, Instant};

/// Request for GPU world generation
pub struct GenerationRequest {
    pub id: u64,
    pub bounds: WorldBounds,
    pub params: GenerationParams,
    pub priority: i32,
}

/// Result of a generation operation
pub struct GenerationResult {
    pub id: u64,
    pub result: Result<Arc<VoxelWorkspace>, String>,
    pub generation_time_ms: u64,
}

/// GPU synchronization state
#[derive(Clone)]
struct GpuSyncState {
    pub fence_value: u64,
    pub is_complete: bool,
}

/// Channel for async communication of results
pub type ResultChannel = Arc<Mutex<Option<Result<Arc<VoxelWorkspace>, String>>>>;

/// GPU world generation pipeline with proper queuing and synchronization
pub struct GpuWorldGenPipeline {
    gfx: Arc<dyn Gfx + Send + Sync>,
    generator: Arc<Mutex<GpuWorldGenerator>>,
    
    // Request queuing
    request_queue: Arc<Mutex<VecDeque<(GenerationRequest, ResultChannel)>>>,
    queue_condvar: Arc<Condvar>,
    
    // GPU synchronization
    gpu_fence: Arc<Mutex<u64>>,
    pending_operations: Arc<Mutex<Vec<(u64, GpuSyncState)>>>,
    
    // Results tracking for non-blocking queries
    completed_results: Arc<Mutex<HashMap<u64, Result<Arc<VoxelWorkspace>, String>>>>,
    
    // Worker thread
    worker_thread: Mutex<Option<thread::JoinHandle<()>>>,
    shutdown_flag: Arc<RwLock<bool>>,
    
    // Thread executor for CPU work
    thread_executor: Arc<GpuThreadExecutor>,
    main_coordinator: Arc<Mutex<MainThreadCoordinator>>,
    
    // Statistics
    stats: Arc<Mutex<PipelineStats>>,
}

#[derive(Default, Clone)]
pub struct PipelineStats {
    pub total_requests: u64,
    pub completed_requests: u64,
    pub failed_requests: u64,
    pub average_generation_time_ms: f64,
    pub queue_length: usize,
    pub gpu_utilization: f32,
}

impl GpuWorldGenPipeline {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>) -> Self {
        // Create main thread coordinator
        let (coordinator, main_sender) = MainThreadCoordinator::new(gfx.clone());
        
        // Create thread executor with more worker threads for faster generation
        let num_threads = std::thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(4)
            .max(4);
        println!("Creating GPU thread executor with {} worker threads", num_threads);
        let thread_executor = Arc::new(GpuThreadExecutor::new(num_threads, main_sender.clone()));
        
        // Create generator with thread executor
        let generator = Arc::new(Mutex::new(
            GpuWorldGenerator::new(gfx.clone())
                .with_thread_executor(thread_executor.clone(), main_sender)
        ));
        
        let pipeline = Self {
            gfx: gfx.clone(),
            generator,
            request_queue: Arc::new(Mutex::new(VecDeque::new())),
            queue_condvar: Arc::new(Condvar::new()),
            gpu_fence: Arc::new(Mutex::new(0)),
            pending_operations: Arc::new(Mutex::new(Vec::new())),
            completed_results: Arc::new(Mutex::new(HashMap::new())),
            worker_thread: Mutex::new(None),
            shutdown_flag: Arc::new(RwLock::new(false)),
            stats: Arc::new(Mutex::new(PipelineStats::default())),
            thread_executor,
            main_coordinator: Arc::new(Mutex::new(coordinator)),
        };
        
        // Set the GPU pipeline in the coordinator so it can be used for minichunk generation
        // Note: We can't do this here because it would create a circular reference
        // The caller must set this after creating the pipeline
        
        pipeline
    }
    
    /// Start the pipeline worker
    pub fn start(&self) {
        println!("GpuWorldGenPipeline::start() called");
        let generator = self.generator.clone();
        let request_queue = self.request_queue.clone();
        let queue_condvar = self.queue_condvar.clone();
        let gpu_fence = self.gpu_fence.clone();
        let pending_operations = self.pending_operations.clone();
        let completed_results = self.completed_results.clone();
        let stats = self.stats.clone();
        let shutdown_flag = self.shutdown_flag.clone();
        let gfx = self.gfx.clone();
        
        let worker = thread::spawn(move || {
            Self::worker_loop(
                generator,
                request_queue,
                queue_condvar,
                gpu_fence,
                pending_operations,
                completed_results,
                stats,
                shutdown_flag,
                gfx,
            );
        });
        
        *self.worker_thread.lock().unwrap() = Some(worker);
    }
    
    /// Stop the pipeline worker
    pub fn stop(&self) {
        *self.shutdown_flag.write().unwrap() = true;
        self.queue_condvar.notify_all();
        
        if let Some(thread) = self.worker_thread.lock().unwrap().take() {
            let _ = thread.join();
        }
    }
    
    /// Queue a generation request (blocking)
    pub fn queue_generation_blocking(
        &self,
        bounds: WorldBounds,
        params: GenerationParams,
        priority: i32,
    ) -> Result<Arc<VoxelWorkspace>, String> {
        println!("queue_generation_blocking called for bounds [{:.1},{:.1},{:.1}] to [{:.1},{:.1},{:.1}]",
            bounds.min.x(), bounds.min.y(), bounds.min.z(),
            bounds.max.x(), bounds.max.y(), bounds.max.z());
            
        let result_channel = Arc::new(Mutex::new(None));
        
        let request = GenerationRequest {
            id: self.next_request_id(),
            bounds,
            params,
            priority,
        };
        
        // Update stats
        {
            let mut stats = self.stats.lock().unwrap();
            stats.total_requests += 1;
            stats.queue_length += 1;
        }
        
        // Add to queue
        {
            let mut queue = self.request_queue.lock().unwrap();
            
            // Insert sorted by priority (higher priority first)
            let insert_pos = queue.iter()
                .position(|(r, _)| r.priority < request.priority)
                .unwrap_or(queue.len());
                
            println!("Request {} added to queue at position {}. Queue length: {}", request.id, insert_pos, queue.len());
            queue.insert(insert_pos, (request, result_channel.clone()));
        }
        
        // Notify worker
        self.queue_condvar.notify_one();
        
        // Wait for result
        loop {
            {
                let mut result = result_channel.lock().unwrap();
                if result.is_some() {
                    return result.take().unwrap();
                }
            }
            thread::sleep(Duration::from_millis(10));
        }
    }
    
    /// Queue a generation request (non-blocking) - returns request ID
    pub fn queue_generation_non_blocking(
        &self,
        bounds: WorldBounds,
        params: GenerationParams,
        priority: i32,
    ) -> Result<u64, String> {
        let request = GenerationRequest {
            id: self.next_request_id(),
            bounds,
            params,
            priority,
        };
        
        let request_id = request.id;
        
        // Update stats
        {
            let mut stats = self.stats.lock().unwrap();
            stats.total_requests += 1;
            stats.queue_length += 1;
        }
        
        // Add to queue with a dummy result channel (we won't wait for it)
        {
            let mut queue = self.request_queue.lock().unwrap();
            let result_channel = Arc::new(Mutex::new(None));
            
            // Insert sorted by priority (higher priority first)
            let insert_pos = queue.iter()
                .position(|(r, _)| r.priority < request.priority)
                .unwrap_or(queue.len());
                
            queue.insert(insert_pos, (request, result_channel));
        }
        
        // Notify worker
        self.queue_condvar.notify_one();
        
        Ok(request_id)
    }
    
    /// Check if a generation request is complete (non-blocking)
    pub fn check_generation_result(&self, request_id: u64) -> Option<Result<Arc<VoxelWorkspace>, String>> {
        let mut results = self.completed_results.lock().unwrap();
        results.remove(&request_id)
    }
    
    /// Get current pipeline statistics
    pub fn get_stats(&self) -> PipelineStats {
        self.stats.lock().unwrap().clone()
    }
    
    /// Process GPU commands on main thread (must be called from main thread)
    pub fn process_main_thread_commands(&self) {
        if let Ok(coordinator) = self.main_coordinator.try_lock() {
            coordinator.process_commands(&*self.gfx);
        }
    }
    
    /// Process end of frame - handle deferred readbacks (must be called from main thread after frame_end)
    pub fn process_end_frame(&self) {
        if let Ok(coordinator) = self.main_coordinator.try_lock() {
            coordinator.end_frame(&*self.gfx);
        }
    }
    
    /// Wait for all pending GPU operations to complete
    pub fn flush(&self) -> Result<(), String> {
        // Wait for queue to empty
        loop {
            let queue_empty = self.request_queue.lock().unwrap().is_empty();
            let pending_empty = self.pending_operations.lock().unwrap().is_empty();
            
            if queue_empty && pending_empty {
                break;
            }
            
            thread::sleep(Duration::from_millis(10));
        }
        
        Ok(())
    }
    
    /// Worker loop that processes generation requests
    fn worker_loop(
        generator: Arc<Mutex<GpuWorldGenerator>>,
        request_queue: Arc<Mutex<VecDeque<(GenerationRequest, ResultChannel)>>>,
        queue_condvar: Arc<Condvar>,
        gpu_fence: Arc<Mutex<u64>>,
        pending_operations: Arc<Mutex<Vec<(u64, GpuSyncState)>>>,
        completed_results: Arc<Mutex<HashMap<u64, Result<Arc<VoxelWorkspace>, String>>>>,
        stats: Arc<Mutex<PipelineStats>>,
        shutdown_flag: Arc<RwLock<bool>>,
        gfx: Arc<dyn Gfx + Send + Sync>,
    ) {
        println!("GPU pipeline worker thread started");
        loop {
            // Check shutdown
            if *shutdown_flag.read().unwrap() {
                break;
            }
            
            // Get next request
            let request_opt = {
                let mut queue = request_queue.lock().unwrap();
                
                // Wait for requests if queue is empty
                while queue.is_empty() && !*shutdown_flag.read().unwrap() {
                    println!("GPU pipeline worker: Waiting for requests...");
                    queue = queue_condvar.wait(queue).unwrap();
                    println!("GPU pipeline worker: Woke up, queue size: {}", queue.len());
                }
                
                queue.pop_front()
            };
            
            if let Some((request, result_channel)) = request_opt {
                println!("GPU pipeline worker: Processing request {} with priority {}", request.id, request.priority);
                // Update stats
                {
                    let mut stats = stats.lock().unwrap();
                    stats.queue_length = stats.queue_length.saturating_sub(1);
                }
                
                // Process request if GPU is available
                if Self::is_gpu_available(&pending_operations) {
                    let start_time = Instant::now();
                    let fence_value = Self::begin_gpu_operation(&gpu_fence, &pending_operations);
                    
                    // Start async generation
                    let generator_guard = generator.lock().unwrap();
                    let handle = generator_guard.start_async_generation(request.bounds, request.params);
                    drop(generator_guard);
                    
                    // Poll for completion
                    let result = loop {
                        if handle.is_complete() {
                            break handle.try_get_result().unwrap();
                        }
                        
                        // Check for shutdown
                        if *shutdown_flag.read().unwrap() {
                            break Err("Pipeline shutting down".to_string());
                        }
                        
                        // Small delay to avoid busy waiting
                        thread::sleep(Duration::from_millis(10));
                    };
                    
                    // Signal GPU operation complete
                    Self::complete_gpu_operation(&pending_operations, fence_value);
                    
                    // Update stats
                    let generation_time_ms = start_time.elapsed().as_millis() as u64;
                    {
                        let mut stats = stats.lock().unwrap();
                        match &result {
                            Ok(_) => {
                                stats.completed_requests += 1;
                                let total = stats.completed_requests as f64;
                                stats.average_generation_time_ms = 
                                    (stats.average_generation_time_ms * (total - 1.0) + generation_time_ms as f64) / total;
                            }
                            Err(_) => {
                                stats.failed_requests += 1;
                            }
                        }
                    }
                    
                    // Store result for non-blocking queries
                    completed_results.lock().unwrap().insert(request.id, result.clone());
                    
                    // Send result
                    *result_channel.lock().unwrap() = Some(result);
                }
            }
            
            // Update GPU utilization
            Self::update_gpu_utilization(&pending_operations, &stats);
            
            // Small delay to prevent busy spinning
            thread::sleep(Duration::from_millis(1));
        }
    }
    
    /// Check if GPU is available for new operations
    fn is_gpu_available(pending_operations: &Arc<Mutex<Vec<(u64, GpuSyncState)>>>) -> bool {
        let pending = pending_operations.lock().unwrap();
        // Allow up to 2 concurrent GPU operations
        pending.len() < 2
    }
    
    /// Begin a new GPU operation
    fn begin_gpu_operation(
        gpu_fence: &Arc<Mutex<u64>>,
        pending_operations: &Arc<Mutex<Vec<(u64, GpuSyncState)>>>,
    ) -> u64 {
        let fence_value = {
            let mut fence = gpu_fence.lock().unwrap();
            *fence += 1;
            *fence
        };
        
        let sync_state = GpuSyncState {
            fence_value,
            is_complete: false,
        };
        
        pending_operations.lock().unwrap().push((fence_value, sync_state));
        
        fence_value
    }
    
    /// Mark a GPU operation as complete
    fn complete_gpu_operation(
        pending_operations: &Arc<Mutex<Vec<(u64, GpuSyncState)>>>,
        fence_value: u64,
    ) {
        let mut pending = pending_operations.lock().unwrap();
        if let Some(pos) = pending.iter().position(|(v, _)| *v == fence_value) {
            pending[pos].1.is_complete = true;
        }
        
        // Remove completed operations
        pending.retain(|(_, state)| !state.is_complete);
    }
    
    /// Update GPU utilization metric
    fn update_gpu_utilization(
        pending_operations: &Arc<Mutex<Vec<(u64, GpuSyncState)>>>,
        stats: &Arc<Mutex<PipelineStats>>,
    ) {
        let pending_count = pending_operations.lock().unwrap().len();
        let utilization = (pending_count as f32 / 2.0).min(1.0); // Max 2 concurrent operations
        
        stats.lock().unwrap().gpu_utilization = utilization;
    }
    
    fn next_request_id(&self) -> u64 {
        static COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
    }
}

impl Drop for GpuWorldGenPipeline {
    fn drop(&mut self) {
        self.stop();
    }
}


#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_pipeline_creation() {
        // Test that pipeline can be created
    }
    
    #[test]
    fn test_priority_ordering() {
        // Test that requests are processed in priority order
    }
}