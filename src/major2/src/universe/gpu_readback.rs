use std::sync::Arc;
use std::collections::VecDeque;
use crate::gfx::{Gfx, Buffer, BufferUsage, MemoryAccess, GpuEncoder, Fence};
use std::marker::PhantomData;

/// Trait for types that can be read back from GPU
pub trait GpuReadback: Sized {
    fn size_bytes(&self) -> usize {
        std::mem::size_of::<Self>()
    }
    
    fn from_bytes(bytes: &[u8]) -> Result<Self, String>;
    fn from_bytes_vec(bytes: &[u8]) -> Result<Vec<Self>, String> {
        let item_size = std::mem::size_of::<Self>();
        if bytes.len() % item_size != 0 {
            return Err(format!("Buffer size {} not divisible by item size {}", bytes.len(), item_size));
        }
        
        let count = bytes.len() / item_size;
        let mut result = Vec::with_capacity(count);
        
        for i in 0..count {
            let start = i * item_size;
            let end = start + item_size;
            result.push(Self::from_bytes(&bytes[start..end])?);
        }
        
        Ok(result)
    }
}

/// Implementation for primitive types
impl GpuReadback for u32 {
    fn from_bytes(bytes: &[u8]) -> Result<Self, String> {
        if bytes.len() < 4 {
            return Err("Not enough bytes for u32".to_string());
        }
        Ok(u32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]))
    }
}

impl GpuReadback for f32 {
    fn from_bytes(bytes: &[u8]) -> Result<Self, String> {
        if bytes.len() < 4 {
            return Err("Not enough bytes for f32".to_string());
        }
        Ok(f32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]))
    }
}

impl GpuReadback for super::Voxel {
    fn from_bytes(bytes: &[u8]) -> Result<Self, String> {
        if bytes.len() < std::mem::size_of::<usize>() {
            return Err("Not enough bytes for Voxel".to_string());
        }
        // For GPU compatibility, voxels are stored as u32 but we need to convert to usize
        let value = u32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]);
        Ok(super::Voxel(value as usize))
    }
}

/// GPU readback manager that handles async buffer transfers
pub struct GpuReadbackManager<T: GpuReadback> {
    gfx: Arc<dyn Gfx + Send + Sync>,
    staging_buffer: Option<*const Buffer>,
    size: usize,
    _phantom: PhantomData<T>,
}

impl<T: GpuReadback> GpuReadbackManager<T> {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>) -> Self {
        Self {
            gfx,
            staging_buffer: None,
            size: 0,
            _phantom: PhantomData,
        }
    }
    
    /// Prepare staging buffer for readback
    pub fn prepare(&mut self, count: usize) -> Result<(), String> {
        let size = count * std::mem::size_of::<T>();
        
        // Destroy old buffer if size changed
        if let Some(old_buffer) = self.staging_buffer {
            if self.size != size {
                self.gfx.buffer_destroy(old_buffer);
                self.staging_buffer = None;
            }
        }
        
        // Create new staging buffer if needed
        if self.staging_buffer.is_none() {
            self.staging_buffer = Some(self.gfx.buffer_create(size, BufferUsage::Staging, MemoryAccess::GpuToCpu));
            self.size = size;
        }
        
        Ok(())
    }
    
    /// Start async readback from GPU buffer to staging
    pub fn start_readback(
        &self,
        src_buffer: *const Buffer,
        encoder: &mut dyn GpuEncoder,
    ) -> Result<(), String> {
        let staging = self.staging_buffer
            .ok_or_else(|| "Staging buffer not prepared".to_string())?;
        
        // Record copy command
        encoder.copy_buffer(
            unsafe { &*(src_buffer as *const Buffer) },
            unsafe { &*(staging as *const Buffer) },
            self.size
        );
        
        Ok(())
    }
    
    /// Complete readback and get data
    pub fn complete_readback(&self) -> Result<Vec<T>, String> {
        let staging = self.staging_buffer
            .ok_or_else(|| "Staging buffer not prepared".to_string())?;
        
        // DO NOT WAIT - this is for deferred readback only
        // The caller must ensure GPU work is complete before calling this
        
        // Read from staging buffer
        if let Some(data) = self.gfx.buffer_map_read(staging) {
            // Convert bytes to typed data
            let result = T::from_bytes_vec(data);
            self.gfx.buffer_unmap(staging);
            result
        } else {
            Err("Failed to map staging buffer for reading".to_string())
        }
    }
    
    /// Perform synchronous readback (blocks until complete)
    pub fn readback_sync(
        &mut self,
        _src_buffer: *const Buffer,
        _count: usize,
    ) -> Result<Vec<T>, String> {
        Err("Synchronous readback is no longer supported. Use deferred readback with encoders.".to_string())
    }
}

impl<T: GpuReadback> Drop for GpuReadbackManager<T> {
    fn drop(&mut self) {
        if let Some(buffer) = self.staging_buffer {
            self.gfx.buffer_destroy(buffer);
        }
    }
}

/// Batch readback for multiple buffers
pub struct BatchGpuReadback {
    gfx: Arc<dyn Gfx + Send + Sync>,
    transfers: Vec<PendingTransfer>,
}

struct PendingTransfer {
    src_buffer: *const Buffer,
    staging_buffer: *const Buffer,
    size: usize,
    offset: usize,
}

impl BatchGpuReadback {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>) -> Self {
        Self {
            gfx,
            transfers: Vec::new(),
        }
    }
    
    /// Queue a buffer for readback
    pub fn queue_readback(
        &mut self,
        src_buffer: *const Buffer,
        size: usize,
    ) -> usize {
        let staging = self.gfx.buffer_create(size, BufferUsage::Staging, MemoryAccess::GpuToCpu);
        let index = self.transfers.len();
        
        self.transfers.push(PendingTransfer {
            src_buffer,
            staging_buffer: staging,
            size,
            offset: 0,
        });
        
        index
    }
    
    /// Execute all queued transfers
    pub fn execute(&self) -> Result<(), String> {
        // Get the current frame's encoder instead of creating a new one
        if let Some(encoder) = self.gfx.get_frame_encoder() {
            // Record all copy commands to the frame's encoder
            for transfer in &self.transfers {
                encoder.copy_buffer(
                    unsafe { &*(transfer.src_buffer as *const Buffer) },
                    unsafe { &*(transfer.staging_buffer as *const Buffer) },
                    transfer.size
                );
                encoder.memory_barrier();
            }
            Ok(())
        } else {
            // No active frame encoder, can't process
            Err("No active frame encoder available".to_string())
        }
    }
    
    /// Get readback data by index
    pub fn get_data<T: GpuReadback>(&self, index: usize) -> Result<Vec<T>, String> {
        let transfer = self.transfers.get(index)
            .ok_or_else(|| format!("Invalid transfer index {}", index))?;
        
        if let Some(data) = self.gfx.buffer_map_read(transfer.staging_buffer) {
            let result = T::from_bytes_vec(data);
            self.gfx.buffer_unmap(transfer.staging_buffer);
            result
        } else {
            Err("Failed to map staging buffer for reading".to_string())
        }
    }
    
    /// Clean up all staging buffers
    pub fn cleanup(&mut self) {
        for transfer in &self.transfers {
            self.gfx.buffer_destroy(transfer.staging_buffer);
        }
        self.transfers.clear();
    }
}

impl Drop for BatchGpuReadback {
    fn drop(&mut self) {
        self.cleanup();
    }
}

/// A deferred GPU readback request
pub struct DeferredReadbackRequest {
    pub id: u64,
    pub buffer: *const Buffer,
    pub staging_buffer: *const Buffer,
    pub size: usize,
    pub frame_submitted: u64,
    pub callback: Box<dyn FnOnce(Vec<u8>) + Send>,
    pub fence: Option<*const Fence>,
    pub signal_value: u64,
}

// SAFETY: GPU buffer pointers are only accessed from the main thread
unsafe impl Send for DeferredReadbackRequest {}
unsafe impl Sync for DeferredReadbackRequest {}

/// Manages deferred GPU readbacks with frame synchronization
pub struct DeferredReadbackManager {
    pending_readbacks: std::sync::Mutex<std::collections::VecDeque<DeferredReadbackRequest>>,
    current_frame: std::sync::atomic::AtomicU64,
    frames_in_flight: usize,
    gfx: Arc<dyn Gfx + Send + Sync>,
    next_semaphore_value: std::sync::atomic::AtomicU64,
}

impl DeferredReadbackManager {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>, frames_in_flight: usize) -> Self {
        Self {
            pending_readbacks: std::sync::Mutex::new(std::collections::VecDeque::new()),
            current_frame: std::sync::atomic::AtomicU64::new(0),
            frames_in_flight,
            gfx,
            next_semaphore_value: std::sync::atomic::AtomicU64::new(1),
        }
    }
    
    /// Submit a readback request that will be processed after the current frame completes
    pub fn submit_readback(
        &self,
        buffer: *const Buffer,
        size: usize,
        callback: impl FnOnce(Vec<u8>) + Send + 'static,
    ) -> u64 {
        // Create staging buffer for this readback
        let staging_buffer = self.gfx.buffer_create(size, BufferUsage::Staging, MemoryAccess::GpuToCpu);
        if staging_buffer.is_null() {
            println!("Error: Failed to create staging buffer for readback");
            return 0;
        }
        
        // Record the copy command to the current frame's encoder
        // This assumes we're being called during frame rendering
        if let Some(encoder) = self.gfx.get_frame_encoder() {
            encoder.copy_buffer(
                unsafe { &*(buffer as *const Buffer) },
                unsafe { &*(staging_buffer as *const Buffer) },
                size
            );
        } else {
            println!("Error: No active frame encoder for readback copy");
            self.gfx.buffer_destroy(staging_buffer);
            return 0;
        }
        
        let mut pending = self.pending_readbacks.lock().unwrap();
        let current_frame = self.current_frame.load(std::sync::atomic::Ordering::Acquire);
        
        let id = self.next_request_id();
        // Create a fence for this readback
        let fence = self.gfx.fence_create(0);
        let signal_value = self.next_semaphore_value.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
        
        // Signal the fence after the copy command
        self.gfx.fence_signal(fence, signal_value);
        
        let request = DeferredReadbackRequest {
            id,
            buffer,
            staging_buffer,
            size,
            frame_submitted: current_frame,
            callback: Box::new(callback),
            fence: Some(fence),
            signal_value,
        };
        
        println!("Submitting readback {} at frame {} (will be ready at frame {})", 
                 id, current_frame, current_frame + self.frames_in_flight as u64);
        
        pending.push_back(request);
        id
    }
    
    /// Process pending readbacks for completed frames
    pub fn process_completed_readbacks(&self, gfx: &dyn Gfx, completed_frame: u64) {
        let mut pending = self.pending_readbacks.lock().unwrap();
        let mut completed = Vec::new();
        
        let pending_count = pending.len();
        if pending_count > 0 {
            println!("Processing readbacks: {} pending, completed_frame: {}, frames_in_flight: {}", 
                     pending_count, completed_frame, self.frames_in_flight);
        }
        
        // Find all readbacks that are ready
        // Check if enough frames have passed since submission
        while let Some(request) = pending.front() {
            // Calculate how many frames have passed since submission
            let frames_elapsed = if completed_frame >= request.frame_submitted {
                completed_frame - request.frame_submitted
            } else {
                // Handle wrap-around or initialization issues
                self.frames_in_flight as u64
            };
            
            println!("Checking readback {}: submitted frame {}, current frame {}, {} frames elapsed (need {})", 
                     request.id, request.frame_submitted, completed_frame, frames_elapsed, self.frames_in_flight);
            
            if frames_elapsed >= self.frames_in_flight as u64 {
                if let Some(request) = pending.pop_front() {
                    println!("Readback {} ready (submitted frame {}, current frame {})", 
                             request.id, request.frame_submitted, completed_frame);
                    completed.push(request);
                }
            } else {
                break;
            }
        }
        
        drop(pending); // Release lock before processing callbacks
        
        println!("Processing {} completed readbacks", completed.len());
        
        // Process completed readbacks
        for request in completed {
            // Read from the staging buffer, not the original GPU buffer
            if let Some(data) = gfx.buffer_map_read(request.staging_buffer) {
                let data_vec = data.to_vec();
                gfx.buffer_unmap(request.staging_buffer);
                // Clean up the staging buffer
                gfx.buffer_destroy(request.staging_buffer);
                // Clean up the fence if present
                if let Some(fence) = request.fence {
                    gfx.fence_destroy(fence);
                }
                (request.callback)(data_vec);
            }
        }
    }
    
    /// Advance to the next frame
    pub fn advance_frame(&self) {
        let new_frame = self.current_frame.fetch_add(1, std::sync::atomic::Ordering::Release) + 1;
        println!("DeferredReadbackManager: advanced to frame {}", new_frame);
    }
    
    /// Get the current frame number
    pub fn current_frame(&self) -> u64 {
        self.current_frame.load(std::sync::atomic::Ordering::Acquire)
    }
    
    /// Force process readbacks that have been pending for more than max_pending_frames
    pub fn force_process_old_readbacks(&self, gfx: &dyn Gfx, max_pending_frames: u64) {
        let mut pending = self.pending_readbacks.lock().unwrap();
        let mut completed = Vec::new();
        
        let pending_count = pending.len();
        let current_frame = self.current_frame.load(std::sync::atomic::Ordering::Acquire);
        
        if pending_count > 0 {
            println!("Force processing old readbacks: {} pending, max age: {} frames, current frame: {}", 
                     pending_count, max_pending_frames, current_frame);
        }
        
        // Only process readbacks that are old enough
        let mut i = 0;
        while i < pending.len() {
            let request = &pending[i];
            let frames_elapsed = if current_frame >= request.frame_submitted {
                current_frame - request.frame_submitted
            } else {
                // Handle wrap-around or initialization issues
                max_pending_frames + 1
            };
            
            // Only force process if it's been more than max_pending_frames
            if frames_elapsed > max_pending_frames {
                if let Some(request) = pending.remove(i) {
                    println!("Force processing readback {} (was submitted at frame {}, {} frames elapsed)", 
                             request.id, request.frame_submitted, frames_elapsed);
                    completed.push(request);
                }
            } else {
                i += 1;
            }
        }
        
        drop(pending); // Release lock before processing callbacks
        
        if !completed.is_empty() {
            println!("Force processing {} readbacks", completed.len());
        }
        
        // Process completed readbacks
        for request in completed {
            // Read from the staging buffer, not the original GPU buffer
            if let Some(data) = gfx.buffer_map_read(request.staging_buffer) {
                let data_vec = data.to_vec();
                gfx.buffer_unmap(request.staging_buffer);
                // Clean up the staging buffer
                gfx.buffer_destroy(request.staging_buffer);
                // Clean up the fence if present
                if let Some(fence) = request.fence {
                    gfx.fence_destroy(fence);
                }
                (request.callback)(data_vec);
            }
        }
    }
    
    fn next_request_id(&self) -> u64 {
        static COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
        COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed)
    }
}

/// A ring buffer workspace for GPU world generation
pub struct WorldgenRingBuffer {
    workspaces: Vec<WorldgenWorkspace>,
    current_index: usize,
    frames_in_flight: usize,
    /// Queue of callbacks waiting for a workspace to become available
    waiting_queue: VecDeque<Box<dyn FnOnce(&mut WorldgenWorkspace) + Send>>,
}

/// A single workspace in the ring buffer
pub struct WorldgenWorkspace {
    // GPU buffers for this workspace
    pub sdf_buffer: *const Buffer,
    pub brush_buffer: *const Buffer,
    pub params_buffer: *const Buffer,
    pub output_buffer: *const Buffer,
    pub world_params_buffer: *const Buffer,
    pub output_voxels_buffer: *const Buffer,
    
    // Metadata
    pub bounds: Option<super::gpu_worldgen::WorldBounds>,
    pub voxel_count: usize,
    pub in_use: bool,
    pub frame_submitted: Option<u64>,
    pub workspace_id: usize, // Unique ID for this workspace
}

// SAFETY: GPU buffer pointers are only accessed from the main thread
unsafe impl Send for WorldgenWorkspace {}
unsafe impl Sync for WorldgenWorkspace {}

impl WorldgenRingBuffer {
    pub fn new(gfx: &dyn Gfx, frames_in_flight: usize) -> Self {
        let mut workspaces: Vec<WorldgenWorkspace> = Vec::with_capacity(frames_in_flight);
        
        // Pre-allocate buffers for each workspace
        // Memory usage per workspace:
        // - SDF buffer: 1.25 KB
        // - Brush buffer: 2.25 KB  
        // - Params buffer: 64 bytes
        // - Output buffer: 4 MB (for SDF field)
        // - World params buffer: 64 bytes
        // - Output voxels buffer: 4 MB (for voxel data)
        // Total: ~8 MB per workspace
        for i in 0..frames_in_flight {
            let sdf_buffer = gfx.buffer_create(80 * 16, BufferUsage::Storage, MemoryAccess::GpuOnly);
            let brush_buffer = gfx.buffer_create(144 * 16, BufferUsage::Storage, MemoryAccess::GpuOnly);
            let params_buffer = gfx.buffer_create(64, BufferUsage::Storage, MemoryAccess::CpuToGpu);
            let output_buffer = gfx.buffer_create(4 * 1024 * 1024, BufferUsage::Storage, MemoryAccess::GpuOnly); // 4MB for SDF
            // Create world_params_buffer large enough for multiple minichunks
            // Each minichunk needs 64 bytes, support up to 16 minichunks per workspace
            let world_params_buffer = gfx.buffer_create(64 * 16, BufferUsage::Storage, MemoryAccess::CpuToGpu);
            // Calculate buffer size for minichunks (8x8x8 voxels)
            // Each voxel is 4 bytes (u32), so minichunk needs 8*8*8*4 = 2048 bytes
            // Add some padding for alignment and safety
            let minichunk_voxel_count = 8 * 8 * 8;
            let voxel_size_bytes = 4; // u32
            let minichunk_buffer_size = minichunk_voxel_count * voxel_size_bytes;
            // Use a reasonable size that can handle both minichunks and small chunks
            // 64x64x64 chunk = 262144 voxels * 4 bytes = 1MB
            let output_voxels_buffer = gfx.buffer_create(4 * 1024 * 1024, BufferUsage::Storage, MemoryAccess::GpuToCpu); // 4MB for voxels (supports up to 128x128x128)
            
            // Check if any buffer creation failed
            if sdf_buffer.is_null() || brush_buffer.is_null() || params_buffer.is_null() ||
               output_buffer.is_null() || world_params_buffer.is_null() || output_voxels_buffer.is_null() {
                // Clean up any successfully created buffers
                if !sdf_buffer.is_null() { gfx.buffer_destroy(sdf_buffer); }
                if !brush_buffer.is_null() { gfx.buffer_destroy(brush_buffer); }
                if !params_buffer.is_null() { gfx.buffer_destroy(params_buffer); }
                if !output_buffer.is_null() { gfx.buffer_destroy(output_buffer); }
                if !world_params_buffer.is_null() { gfx.buffer_destroy(world_params_buffer); }
                if !output_voxels_buffer.is_null() { gfx.buffer_destroy(output_voxels_buffer); }
                
                // Clean up previously created workspaces
                for j in 0..i {
                    gfx.buffer_destroy(workspaces[j].sdf_buffer);
                    gfx.buffer_destroy(workspaces[j].brush_buffer);
                    gfx.buffer_destroy(workspaces[j].params_buffer);
                    gfx.buffer_destroy(workspaces[j].output_buffer);
                    gfx.buffer_destroy(workspaces[j].world_params_buffer);
                    gfx.buffer_destroy(workspaces[j].output_voxels_buffer);
                }
                
                panic!("Failed to create GPU buffers for worldgen ring buffer workspace {}", i);
            }
            
            let workspace = WorldgenWorkspace {
                sdf_buffer,
                brush_buffer,
                params_buffer,
                output_buffer,
                world_params_buffer,
                output_voxels_buffer,
                bounds: None,
                voxel_count: 0,
                in_use: false,
                frame_submitted: None,
                workspace_id: i, // Assign unique ID
            };
            workspaces.push(workspace);
        }
        
        Self {
            workspaces,
            current_index: 0,
            frames_in_flight,
            waiting_queue: VecDeque::new(),
        }
    }
    
    /// Get the next available workspace
    pub fn get_next_workspace(&mut self) -> Option<&mut WorldgenWorkspace> {
        // Find the next available workspace
        let start_index = self.current_index;
        for i in 0..self.frames_in_flight {
            let idx = (start_index + i) % self.frames_in_flight;
            if !self.workspaces[idx].in_use {
                println!("Allocating workspace {} (current_index: {})", idx, self.current_index);
                self.workspaces[idx].in_use = true;
                self.workspaces[idx].workspace_id = idx; // Ensure workspace_id is set correctly
                self.current_index = (idx + 1) % self.frames_in_flight;
                
                // Count available workspaces
                let available_count = self.workspaces.iter().filter(|w| !w.in_use).count();
                println!("Available workspaces after allocation: {}/{}", available_count, self.workspaces.len());
                
                return Some(&mut self.workspaces[idx]);
            }
        }
        
        println!("WARNING: No available workspaces in ring buffer (all {} are in use)", self.frames_in_flight);
        None // All workspaces are in use
    }
    
    /// Queue a callback to be executed when a workspace becomes available
    pub fn queue_when_available<F>(&mut self, callback: F)
    where
        F: FnOnce(&mut WorldgenWorkspace) + Send + 'static,
    {
        self.waiting_queue.push_back(Box::new(callback));
        println!("Queued work for later execution (queue size: {})", self.waiting_queue.len());
    }
    
    /// Mark a workspace as available after readback completes
    pub fn release_workspace(&mut self, workspace_id: usize) {
        if workspace_id < self.workspaces.len() {
            println!("Releasing workspace {} (was in_use: {})", workspace_id, self.workspaces[workspace_id].in_use);
            
            // Check if there's queued work waiting for a workspace
            if let Some(callback) = self.waiting_queue.pop_front() {
                println!("Processing queued work on released workspace {} (queue size now: {})", 
                         workspace_id, self.waiting_queue.len());
                // Reset workspace state but keep it marked as in_use
                self.workspaces[workspace_id].frame_submitted = None;
                self.workspaces[workspace_id].bounds = None;
                // Execute the queued callback with this workspace
                callback(&mut self.workspaces[workspace_id]);
            } else {
                // No queued work, mark workspace as available
                self.workspaces[workspace_id].in_use = false;
                self.workspaces[workspace_id].frame_submitted = None;
                self.workspaces[workspace_id].bounds = None;
            }
            
            // Count available workspaces
            let available_count = self.workspaces.iter().filter(|w| !w.in_use).count();
            println!("Available workspaces after release: {}/{}", available_count, self.workspaces.len());
        } else {
            println!("WARNING: Attempted to release invalid workspace_id: {}", workspace_id);
        }
    }
    
    /// Get the number of available workspaces
    pub fn available_workspace_count(&self) -> usize {
        self.workspaces.iter().filter(|w| !w.in_use).count()
    }
    
    /// Get the total number of workspaces
    pub fn total_workspace_count(&self) -> usize {
        self.workspaces.len()
    }
    
    /// Process any waiting queue entries if workspaces are available
    /// Returns the number of queued items processed
    pub fn process_waiting_queue(&mut self) -> usize {
        let mut processed = 0;
        
        while !self.waiting_queue.is_empty() {
            // First check if we have an available workspace
            let workspace_available = {
                let start_index = self.current_index;
                let mut found = false;
                for i in 0..self.frames_in_flight {
                    let idx = (start_index + i) % self.frames_in_flight;
                    if !self.workspaces[idx].in_use {
                        found = true;
                        break;
                    }
                }
                found
            };
            
            if workspace_available {
                // Pop the callback first
                if let Some(callback) = self.waiting_queue.pop_front() {
                    let queue_len = self.waiting_queue.len();
                    // Now get the workspace
                    if let Some(workspace) = self.get_next_workspace() {
                        println!("Processing queued work from waiting queue (remaining: {})", queue_len);
                        callback(workspace);
                        processed += 1;
                    } else {
                        // This shouldn't happen, but handle it gracefully
                        self.waiting_queue.push_front(callback);
                        break;
                    }
                }
            } else {
                // No more workspaces available
                break;
            }
        }
        
        if processed > 0 {
            println!("Processed {} items from waiting queue", processed);
        }
        
        processed
    }
    
    /// Get the number of items waiting in the queue
    pub fn waiting_queue_size(&self) -> usize {
        self.waiting_queue.len()
    }
    
    /// Destroy all GPU resources
    pub fn destroy(&mut self, gfx: &dyn Gfx) {
        for workspace in &mut self.workspaces {
            gfx.buffer_destroy(workspace.sdf_buffer);
            gfx.buffer_destroy(workspace.brush_buffer);
            gfx.buffer_destroy(workspace.params_buffer);
            gfx.buffer_destroy(workspace.output_buffer);
            gfx.buffer_destroy(workspace.world_params_buffer);
            gfx.buffer_destroy(workspace.output_voxels_buffer);
        }
    }
}