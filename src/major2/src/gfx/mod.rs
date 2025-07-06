pub mod color;
#[cfg(target_os = "macos")]
pub mod metal;
#[cfg(any(target_os = "windows", target_os = "linux"))]
pub mod vk;
pub mod rendergraph;
pub mod rendergraph_composer;

use crate::{engine::Surface, math};

pub use color::Color;

// GPU-agnostic resource handles - opaque to users
pub enum Mesh {}
pub enum Batch {}
pub enum Camera {}
pub enum Buffer {}
pub enum Shader {}
pub enum Fence {}

pub enum Index {
    U8(u8),
    U16(u16),
    U32(u32),
}

// GPU-agnostic buffer usage hints
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BufferUsage {
    Vertex,        // Vertex data
    Index,         // Index data
    Uniform,       // Uniform/constant data
    Storage,       // Read/write storage
    Staging,       // CPU-visible transfer buffer
}

// GPU-agnostic memory access patterns
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MemoryAccess {
    GpuOnly,       // Device-local, fastest for GPU
    CpuToGpu,      // CPU writes, GPU reads
    GpuToCpu,      // GPU writes, CPU reads
    Shared,        // CPU and GPU can access
}

// Submission info for GPU work
pub struct SubmitInfo<'a> {
    pub wait_fences: &'a [(&'a Fence, u64)],    // Fences to wait on before execution
    pub signal_fences: &'a [(&'a Fence, u64)],  // Fences to signal after execution
}

impl<'a> Default for SubmitInfo<'a> {
    fn default() -> Self {
        Self {
            wait_fences: &[],
            signal_fences: &[],
        }
    }
}

// GPU work encoder - replaces command buffers
pub trait GpuEncoder {
    // Transfer operations
    fn copy_buffer(&mut self, src: &Buffer, dst: &Buffer, size: usize);
    fn write_buffer(&mut self, buffer: &Buffer, data: &[u8], offset: usize);
    
    // Compute operations
    fn dispatch_compute(&mut self, shader: &Shader, x: u32, y: u32, z: u32);
    fn set_compute_buffer(&mut self, slot: u32, buffer: &Buffer);
    
    // Synchronization
    fn memory_barrier(&mut self);
    
    // Type introspection for downcasting
    fn as_any(&self) -> &dyn std::any::Any;
}

pub trait Gfx {
    fn new(surface: &dyn Surface) -> Box<dyn Gfx>
    where
        Self: Sized;
    
    fn as_any(&self) -> &dyn std::any::Any;

    // Mesh operations
    fn mesh_create(&self) -> *const Mesh;
    fn mesh_destroy(&self, mesh: *const Mesh);
    fn mesh_update_vertices(&self, mesh: *const Mesh, vertices: &[math::Vec3f]);
    fn mesh_update_normal_dirs(&self, mesh: *const Mesh, normal_dirs: &[u32]);
    fn mesh_update_albedo(&self, mesh: *const Mesh, colors: &[Color]);
    fn mesh_update_indices(&self, mesh: *const Mesh, indices: &[Index]);
    fn mesh_update_face_sizes(&self, mesh: *const Mesh, sizes: &[[f32; 2]]);

    // Batch operations for drawing
    fn batch_create(&self) -> *const Batch;
    fn batch_destroy(&self, batch: *const Batch);
    fn batch_add_mesh(&self, batch: *const Batch, mesh: *const Mesh);
    fn batch_remove_mesh(&self, batch: *const Batch, mesh: *const Mesh);
    fn batch_queue_draw(&self, batch: *const Batch);

    // Camera operations
    fn camera_create(&self) -> *const Camera;
    fn camera_set_projection(&self, camera: *const Camera, projection: &[f32; 16]);
    fn camera_set_transform(&self, camera: *const Camera, transform: &[f32; 16]);
    fn camera_set_main(&self, camera: *const Camera);

    // Frame operations
    fn frame_begin(&self);
    fn frame_commit_draw(&self);
    fn frame_end(&self);
    
    // Buffer operations
    fn buffer_create(&self, size: usize, usage: BufferUsage, access: MemoryAccess) -> *const Buffer;
    fn buffer_destroy(&self, buffer: *const Buffer);
    fn buffer_map_read(&self, buffer: *const Buffer) -> Option<&[u8]>;
    fn buffer_map_write(&self, buffer: *const Buffer) -> Option<&mut [u8]>;
    fn buffer_unmap(&self, buffer: *const Buffer);
    
    // Shader operations
    fn shader_create_compute(&self, code: &[u8]) -> *const Shader;
    fn shader_destroy(&self, shader: *const Shader);
    
    // GPU work submission
    fn create_encoder(&self) -> Box<dyn GpuEncoder + '_>;
    fn submit_encoder(&self, encoder: Box<dyn GpuEncoder + '_>, info: SubmitInfo);
    
    // Fence operations for synchronization
    fn fence_create(&self, initial_value: u64) -> *const Fence;
    fn fence_destroy(&self, fence: *const Fence);
    fn fence_get_value(&self, fence: *const Fence) -> u64;
    fn fence_wait(&self, fence: *const Fence, value: u64, timeout_ns: u64) -> bool;
    fn fence_signal(&self, fence: *const Fence, value: u64);
    
    // Get the encoder for the current frame (if in frame_begin/frame_end)
    fn get_frame_encoder(&self) -> Option<&mut dyn GpuEncoder>;
    
    // Create a render graph for this backend
    fn create_render_graph(&self, desc: &rendergraph::RenderGraphDesc) -> Result<Box<dyn rendergraph::RenderGraph>, Box<dyn std::error::Error>> {
        Err("Render graph not implemented for this backend".into())
    }
    
    // Load compute shader from file
    fn load_compute_shader(&self, path: &str) -> Result<*const Shader, Box<dyn std::error::Error>> {
        use std::fs;
        let code = fs::read(path)?;
        Ok(self.shader_create_compute(&code))
    }
}