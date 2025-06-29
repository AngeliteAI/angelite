use std::sync::{Arc, Mutex, mpsc};
use std::thread;
use std::collections::VecDeque;
use crate::math::Vec3;

/// Commands that need to be executed on the main thread (GPU API calls)
pub enum MainThreadCommand {
    CreateBuffer { size: usize, id: u64 },
    UpdateBuffer { id: u64, data: Vec<u8> },
    DispatchCompute { shader: u32, workgroups: (u32, u32, u32) },
    ReadBuffer { id: u64, callback: mpsc::Sender<Vec<u8>> },
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

/// Thread pool executor that coordinates CPU work with GPU commands
pub struct GpuThreadExecutor {
    worker_threads: Vec<thread::JoinHandle<()>>,
    task_sender: mpsc::Sender<WorkerTask>,
    main_thread_sender: mpsc::Sender<MainThreadCommand>,
    shutdown: Arc<Mutex<bool>>,
}

impl GpuThreadExecutor {
    pub fn new(
        num_threads: usize,
        main_thread_sender: mpsc::Sender<MainThreadCommand>,
    ) -> Self {
        let (task_sender, task_receiver) = mpsc::channel();
        let task_receiver = Arc::new(Mutex::new(task_receiver));
        let shutdown = Arc::new(Mutex::new(false));
        
        let mut worker_threads = Vec::new();
        
        for i in 0..num_threads {
            let receiver = task_receiver.clone();
            let shutdown_flag = shutdown.clone();
            let main_sender = main_thread_sender.clone();
            
            let handle = thread::spawn(move || {
                println!("Worker thread {} started", i);
                
                loop {
                    // Check shutdown
                    if *shutdown_flag.lock().unwrap() {
                        break;
                    }
                    
                    // Get next task
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
                            // No work, sleep briefly
                            thread::sleep(std::time::Duration::from_millis(1));
                        }
                        Err(mpsc::TryRecvError::Disconnected) => {
                            // Channel closed, exit
                            break;
                        }
                    }
                }
                
                println!("Worker thread {} shutting down", i);
            });
            
            worker_threads.push(handle);
        }
        
        Self {
            worker_threads,
            task_sender,
            main_thread_sender,
            shutdown,
        }
    }
    
    pub fn submit_task(&self, task: WorkerTask) -> Result<(), String> {
        self.task_sender.send(task)
            .map_err(|_| "Failed to submit task to worker pool".to_string())
    }
    
    pub fn shutdown(self) {
        *self.shutdown.lock().unwrap() = true;
        
        // Wait for all workers to finish
        for handle in self.worker_threads {
            let _ = handle.join();
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
                    
                    // Calculate normal and create evaluation context
                    let normal = Vec3::new([0.0, 0.0, 1.0]); // Z-up
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
}

impl MainThreadCoordinator {
    pub fn new() -> (Self, mpsc::Sender<MainThreadCommand>) {
        let (sender, receiver) = mpsc::channel();
        (Self { receiver }, sender)
    }
    
    /// Process pending GPU commands on the main thread
    pub fn process_commands(&self, gfx: &dyn super::gfx::Gfx) {
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
            }
        }
    }
}