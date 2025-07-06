use std::ffi::{CString, c_void};
use std::fmt::Debug;
use std::mem::ManuallyDrop;
use std::ptr;
use std::sync::{Arc, Mutex};
use std::any::Any;

use crate::math;
use crate::gfx::Fence;

pub mod rendergraph_impl;

pub struct Mesh {
    buffer_index: u32,
    command_index_ptr: *mut u32,
    vertex_count: u32,
    position: [f32; 3],
    group: u32,
    // Store vertex data for incremental updates
    vertices: Option<Vec<crate::math::Vec3f>>,
    normal_dirs: Option<Vec<u32>>,
    colors: Option<Vec<crate::gfx::Color>>,
    face_sizes: Option<Vec<[f32; 2]>>,
    indices: Option<Vec<u32>>,
}

pub struct Batch {
    meshes: Vec<*const super::Mesh>,
}

pub struct Camera {
    zig_camera: *mut c_void,
}

// Compute resource structs
pub struct GpuBuffer {
    handle: *mut c_void,
    size: usize,
    buffer_type: u32,
}

pub struct ComputeShader {
    handle: *mut c_void,
}

pub struct CommandBuffer {
    handle: *mut c_void,
}

pub struct TimelineSemaphore {
    handle: *mut c_void,
    current_value: Arc<Mutex<u64>>,
}

pub struct Vulkan {
    renderer: Arc<Mutex<*mut zig::Renderer>>,
    meshes: Vec<Mesh>,
    batches: Vec<Batch>,
    // Compute resources
    buffers: Vec<GpuBuffer>,
    compute_shaders: Vec<ComputeShader>,
    command_buffers: Vec<CommandBuffer>,
    // Worldgen - using RefCell for interior mutability to allow lazy initialization
    worldgen: std::cell::RefCell<Option<*mut c_void>>,
}

// GPU encoder implementation for Vulkan
pub struct VulkanEncoder {
    renderer: Arc<Mutex<*mut zig::Renderer>>,
    command_buffer: *mut c_void,
    is_frame_encoder: bool,
}

impl super::GpuEncoder for VulkanEncoder {
    fn copy_buffer(&mut self, src: &super::Buffer, dst: &super::Buffer, size: usize) {
        let src_ptr = src as *const super::Buffer as *const c_void;
        let dst_ptr = dst as *const super::Buffer as *const c_void;
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            // Use the encoder's command buffer for the copy
            zig::renderer_buffer_copy(renderer_ptr, src_ptr as *mut c_void, dst_ptr as *mut c_void, size as u64);
        }
    }
    
    fn write_buffer(&mut self, buffer: &super::Buffer, data: &[u8], offset: usize) {
        let buffer_ptr = buffer as *const super::Buffer as *const c_void;
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            zig::renderer_buffer_write(
                renderer_ptr,
                buffer_ptr as *mut c_void,
                data.as_ptr(),
                data.len() as u64,
                offset as u64,
            );
        }
    }
    
    fn dispatch_compute(&mut self, shader: &super::Shader, x: u32, y: u32, z: u32) {
        let shader_ptr = shader as *const super::Shader as *const c_void;
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            zig::renderer_compute_bind_shader(renderer_ptr, self.command_buffer, shader_ptr as *mut c_void);
            zig::renderer_compute_dispatch(renderer_ptr, self.command_buffer, x, y, z);
        }
    }
    
    fn set_compute_buffer(&mut self, slot: u32, buffer: &super::Buffer) {
        let buffer_ptr = buffer as *const super::Buffer as *const c_void;
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            zig::renderer_compute_bind_buffer(renderer_ptr, self.command_buffer, slot, buffer_ptr as *mut c_void);
        }
    }
    
    fn memory_barrier(&mut self) {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            zig::renderer_compute_memory_barrier(renderer_ptr, self.command_buffer);
        }
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

impl Drop for VulkanEncoder {
    fn drop(&mut self) {
        // Clean up the command buffer if it wasn't submitted
        if !self.is_frame_encoder && !self.command_buffer.is_null() {
            let renderer_guard = self.renderer.lock().unwrap();
            let renderer_ptr = *renderer_guard;
            
            unsafe {
                // Destroy the command buffer without submitting
                zig::renderer_command_buffer_destroy(renderer_ptr, self.command_buffer);
            }
        }
    }
}

// Module for Zig interop
pub mod zig {
    use std::ffi::c_void;
    use std::mem::MaybeUninit;

    #[repr(C)]
    #[derive(Debug)]
    pub struct Renderer {
        _opaque: [u8; 0],
    }

    unsafe extern "C" {
        // Renderer functions
        pub fn renderer_init(surface_raw: *mut c_void) -> *mut Renderer;
        pub fn renderer_deinit(renderer: *mut Renderer);
        pub fn renderer_init_vertex_pool(
            renderer: *mut Renderer,
            buffer_count: u32,
            vertex_per_buffer: u32,
            max_draw_commands: u32,
        ) -> bool;

        // Buffer management
        pub fn renderer_request_buffer(renderer: *mut Renderer) -> u32;
        pub fn renderer_add_mesh(
            renderer: *mut Renderer,
            buffer_idx: u32,
            vertices: *const c_void,
            vertex_count: u32,
            position: *const f32,
            group: u32,
            index_ptr: *mut *mut u32,
        ) -> bool;
        pub fn renderer_update_vertices(
            renderer: *mut Renderer,
            buffer_idx: u32,
            vertices: *const c_void,
            vertex_count: u32,
        ) -> bool;
        pub fn renderer_update_normals(
            renderer: *mut Renderer,
            buffer_idx: u32,
            normals: *const c_void,
            vertex_count: u32,
        ) -> bool;
        pub fn renderer_update_colors(
            renderer: *mut Renderer,
            buffer_idx: u32,
            colors: *const c_void,
            vertex_count: u32,
        ) -> bool;
        pub fn renderer_update_draw_command_vertex_count(
            renderer: *mut Renderer,
            command_index_ptr: *mut u32,
            vertex_count: u32,
        ) -> bool;
        pub fn renderer_release_buffer(
            renderer: *mut Renderer,
            buffer_idx: u32,
            command_index_ptr: *mut u32,
        ) -> bool;

        // Rendering functions
        pub fn renderer_mask_by_facing(
            renderer: *mut Renderer,
            camera_position: *const f32,
        ) -> bool;
        pub fn renderer_order_front_to_back(
            renderer: *mut Renderer,
            camera_position: *const f32,
        ) -> bool;
        pub fn renderer_begin_frame(renderer: *mut Renderer) -> bool;
        pub fn renderer_render(renderer: *mut Renderer) -> bool;
        pub fn renderer_end_frame(renderer: *mut Renderer) -> bool;
        
        // Compute operations
        pub fn renderer_buffer_create(renderer: *mut Renderer, size: u64, buffer_type: u32) -> *mut c_void;
        pub fn renderer_buffer_destroy(renderer: *mut Renderer, buffer: *mut c_void);
        pub fn renderer_buffer_write(renderer: *mut Renderer, buffer: *mut c_void, data: *const u8, size: u64, offset: u64) -> bool;
        pub fn renderer_buffer_read(renderer: *mut Renderer, buffer: *mut c_void, data: *mut u8, size: u64, offset: u64) -> bool;
        pub fn renderer_buffer_copy(renderer: *mut Renderer, src: *mut c_void, dst: *mut c_void, size: u64) -> bool;
        pub fn renderer_buffer_get_size(renderer: *mut Renderer, buffer: *mut c_void) -> u64;
        pub fn renderer_buffer_map(renderer: *mut Renderer, buffer: *mut c_void) -> *mut c_void;
        pub fn renderer_buffer_unmap(renderer: *mut Renderer, buffer: *mut c_void);
        
        pub fn renderer_compute_shader_create(renderer: *mut Renderer, spirv_data: *const u8, size: u64) -> *mut c_void;
        pub fn renderer_compute_shader_destroy(renderer: *mut Renderer, shader: *mut c_void);
        
        pub fn renderer_command_buffer_create(renderer: *mut Renderer) -> *mut c_void;
        pub fn renderer_command_buffer_destroy(renderer: *mut Renderer, cmd: *mut c_void);
        pub fn renderer_command_buffer_begin(renderer: *mut Renderer, cmd: *mut c_void) -> bool;
        pub fn renderer_command_buffer_end(renderer: *mut Renderer, cmd: *mut c_void) -> bool;
        
        pub fn renderer_compute_bind_shader(renderer: *mut Renderer, cmd: *mut c_void, shader: *mut c_void);
        pub fn renderer_compute_bind_buffer(renderer: *mut Renderer, cmd: *mut c_void, binding: u32, buffer: *mut c_void);
        pub fn renderer_compute_dispatch(renderer: *mut Renderer, cmd: *mut c_void, x: u32, y: u32, z: u32);
        pub fn renderer_compute_memory_barrier(renderer: *mut Renderer, cmd_buffer: *mut c_void);
        
        pub fn renderer_command_buffer_submit(renderer: *mut Renderer, cmd: *mut c_void) -> bool;
        pub fn renderer_device_wait_idle(renderer: *mut Renderer);
        pub fn renderer_get_current_command_buffer(renderer: *mut Renderer) -> *mut c_void;
        
        // Timeline semaphore functions
        pub fn renderer_timeline_semaphore_create(renderer: *mut Renderer, initial_value: u64) -> *mut c_void;
        pub fn renderer_timeline_semaphore_destroy(renderer: *mut Renderer, semaphore: *mut c_void);
        pub fn renderer_timeline_semaphore_get_value(renderer: *mut Renderer, semaphore: *mut c_void) -> u64;
        pub fn renderer_timeline_semaphore_signal(renderer: *mut Renderer, semaphore: *mut c_void, value: u64);
        pub fn renderer_timeline_semaphore_wait(renderer: *mut Renderer, semaphore: *mut c_void, value: u64, timeout_ns: u64) -> bool;
        pub fn renderer_command_buffer_wait_semaphore(renderer: *mut Renderer, cmd: *mut c_void, semaphore: *mut c_void, value: u64);
        pub fn renderer_command_buffer_signal_semaphore(renderer: *mut Renderer, cmd: *mut c_void, semaphore: *mut c_void, value: u64);
        pub fn renderer_command_buffer_submit_with_semaphores(
            renderer: *mut Renderer,
            cmd: *mut c_void,
            wait_semaphores: *const c_void,
            wait_values: *const u64,
            wait_count: u32,
            signal_semaphores: *const c_void,
            signal_values: *const u64,
            signal_count: u32,
        ) -> bool;

        // Camera functions
        pub fn renderer_camera_create(renderer: *mut Renderer) -> *mut c_void;
        pub fn renderer_camera_destroy(renderer: *mut Renderer, camera: *mut c_void);
        pub fn renderer_camera_set_projection(
            renderer: *mut Renderer,
            camera: *mut c_void,
            projection: *const f32,
        );
        pub fn renderer_camera_set_transform(
            renderer: *mut Renderer,
            camera: *mut c_void,
            transform: *const f32,
        );
        pub fn renderer_camera_set_main(renderer: *mut Renderer, camera: *mut c_void);
        
        // Physics integration
        pub fn renderer_get_device_info(
            renderer: *mut Renderer,
            out_device: *mut c_void,
            out_queue: *mut c_void,
            out_command_pool: *mut c_void,
        ) -> bool;
        
        // GPU Worldgen functions
        pub fn gpu_worldgen_create(renderer: *mut Renderer, allocator: *mut c_void) -> *mut c_void;
        pub fn gpu_worldgen_destroy(worldgen: *mut c_void);
        pub fn gpu_worldgen_generate(
            worldgen: *mut c_void,
            cmd: *mut c_void,
            bounds_min_x: f32,
            bounds_min_y: f32,
            bounds_min_z: f32,
            bounds_max_x: f32,
            bounds_max_y: f32,
            bounds_max_z: f32,
            resolution_x: u32,
            resolution_y: u32,
            resolution_z: u32,
            voxel_size: f32,
            sdf_tree_buffer_ptr: *mut c_void,
            params_buffer_ptr: *mut c_void,
            output_buffer_ptr: *mut c_void,
            world_params_buffer_ptr: *mut c_void,
            output_voxels_buffer_ptr: *mut c_void,
        );
        
        pub fn gpu_worldgen_generate_adaptive(
            worldgen: *mut c_void,
            cmd: *mut c_void,
            bounds_min_x: f32,
            bounds_min_y: f32,
            bounds_min_z: f32,
            bounds_max_x: f32,
            bounds_max_y: f32,
            bounds_max_z: f32,
            resolution_x: u32,
            resolution_y: u32,
            resolution_z: u32,
            voxel_size: f32,
            sdf_tree_buffer_ptr: *mut c_void,
            params_buffer_ptr: *mut c_void,
            output_buffer_ptr: *mut c_void,
            world_params_buffer_ptr: *mut c_void,
            output_voxels_buffer_ptr: *mut c_void,
            start_offset: u32,
            max_workgroups: u32,
        ) -> u32;
        
        pub fn gpu_worldgen_generate_adaptive_with_brush(
            worldgen: *mut c_void,
            cmd: *mut c_void,
            bounds_min_x: f32,
            bounds_min_y: f32,
            bounds_min_z: f32,
            bounds_max_x: f32,
            bounds_max_y: f32,
            bounds_max_z: f32,
            resolution_x: u32,
            resolution_y: u32,
            resolution_z: u32,
            voxel_size: f32,
            sdf_tree_buffer_ptr: *mut c_void,
            params_buffer_ptr: *mut c_void,
            output_buffer_ptr: *mut c_void,
            world_params_buffer_ptr: *mut c_void,
            output_voxels_buffer_ptr: *mut c_void,
            brush_buffer_ptr: *const c_void,  // Can be null
            start_offset: u32,
            max_workgroups: u32,
        ) -> u32;
        
        pub fn renderer_render_batch(
            renderer: *mut c_void,
            cmd: *mut c_void,
            batch: *mut c_void,
        );
    }
}

impl Vulkan {
    pub fn from_any(gfx: &dyn super::Gfx) -> Self {
        // This is a bit of a hack, but we need to convert from trait object
        // In production, we'd use a proper downcasting mechanism
        unimplemented!("from_any conversion not yet implemented")
    }
    
    /// Ensure worldgen is initialized, initializing it if necessary
    pub fn ensure_worldgen_initialized(&self) -> Result<(), String> {
        if self.worldgen.borrow().is_none() {
            self.init_worldgen()?;
        }
        Ok(())
    }
    
    /// Generate a chunk using GPU worldgen
    pub fn generate_chunk_gpu(
        &self,
        encoder: &mut dyn super::GpuEncoder,
        chunk_id: crate::universe::gpu_worldgen::ChunkId,
        bounds: crate::universe::gpu_worldgen::WorldBounds,
        params: crate::universe::gpu_worldgen::GenerationParams,
        workspace: &mut crate::universe::gpu_worldgen::VoxelWorkspace,
        accumulator: Arc<Mutex<crate::universe::gpu_worldgen::ChunkAccumulator>>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Get worldgen handle
        let worldgen = self.worldgen.borrow();
        let worldgen_ptr = worldgen.as_ref().ok_or("Worldgen not initialized")?;
        
        // Get command buffer from encoder
        let cmd = if let Some(vk_encoder) = encoder.as_any().downcast_ref::<VulkanEncoder>() {
            vk_encoder.command_buffer
        } else {
            return Err("Invalid encoder type".into());
        };
        
        // Create temporary buffers for worldgen
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        // Allocate buffers
        let sdf_buffer = unsafe { zig::renderer_buffer_create(renderer_ptr, 80 * 16, 0) };
        let params_buffer = unsafe { zig::renderer_buffer_create(renderer_ptr, 64, 0) };
        let output_buffer = unsafe { zig::renderer_buffer_create(renderer_ptr, 4 * 1024 * 1024, 0) };
        let world_params_buffer = unsafe { zig::renderer_buffer_create(renderer_ptr, 64 * 16, 0) };
        let output_voxels_buffer = unsafe { zig::renderer_buffer_create(renderer_ptr, 4 * 1024 * 1024, 0) };
        
        // Generate the chunk
        unsafe {
            zig::gpu_worldgen_generate(
                *worldgen_ptr,
                cmd,
                bounds.min.x(), bounds.min.y(), bounds.min.z(),
                bounds.max.x(), bounds.max.y(), bounds.max.z(),
                bounds.dimensions().0, bounds.dimensions().1, bounds.dimensions().2,
                bounds.voxel_size,
                sdf_buffer,
                params_buffer,
                output_buffer,
                world_params_buffer,
                output_voxels_buffer,
            );
        }
        
        // Read back results into workspace
        // This will be handled by the render graph's deferred readback system
        workspace.voxels.clear();
        let dims = bounds.dimensions();
        workspace.dimensions = crate::math::Vec3::xyz(dims.0 as f32, dims.1 as f32, dims.2 as f32);
        
        Ok(())
    }
}

impl super::Gfx for Vulkan {
    fn new(surface: &dyn crate::engine::Surface) -> Box<dyn super::Gfx>
    where
        Self: Sized,
    {

        // Initialize Vulkan renderer
        let renderer_ptr = unsafe { zig::renderer_init(surface.raw()) };

        // Create Arc<Mutex<*mut zig::Renderer>> to store the pointer
        let renderer = Arc::new(Mutex::new(renderer_ptr));

        // Initialize vertex pool with larger capacity for voxel rendering
        // Voxel chunks can have many vertices (up to 100k+ per chunk)
        let init_result = unsafe {
            zig::renderer_init_vertex_pool(renderer_ptr, 200, 100000, 10000)
        };
        println!("Vertex pool initialization result: {}", init_result);

        Box::new(Vulkan {
            renderer: renderer,
            meshes: Vec::new(),
            batches: Vec::new(),
            buffers: Vec::new(),
            compute_shaders: Vec::new(),
            command_buffers: Vec::new(),
            worldgen: std::cell::RefCell::new(None),
        })
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }

    fn mesh_create(&self) -> *const super::Mesh {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        

        // Request a buffer from the vertex pool
        let buffer_index = unsafe { zig::renderer_request_buffer(renderer_ptr) };
        
        println!("mesh_create: allocated buffer_index={}", buffer_index);

        let mesh = Mesh {
            buffer_index,
            command_index_ptr: ptr::null_mut(),
            vertex_count: 0,
            position: [0.0, 0.0, 0.0],
            group: 0,
            vertices: None,
            normal_dirs: None,
            colors: None,
            face_sizes: None,
            indices: None,
        };

        let mesh_ptr = Box::into_raw(Box::new(mesh)) as *const super::Mesh;
        mesh_ptr
    }

    fn mesh_destroy(&self, mesh: *const super::Mesh) {
        let mesh_ptr = mesh as *const Mesh;
        let mesh = unsafe { Box::from_raw(mesh_ptr as *mut Mesh) };

        // Only release the buffer if a command index was created
        if !mesh.command_index_ptr.is_null() {
            let renderer_guard = self.renderer.lock().unwrap();
            let renderer_ptr = *renderer_guard;

            unsafe {
                zig::renderer_release_buffer(
                    renderer_ptr,
                    mesh.buffer_index,
                    mesh.command_index_ptr,
                );
            }
        }
    }

    fn mesh_update_vertices(&self, mesh: *const super::Mesh, vertices: &[math::Vec3f]) {
        let mesh_ptr = mesh as *mut Mesh;
        let mesh = unsafe { &mut *mesh_ptr };

        // Store vertices for later use with other attributes
        mesh.vertices = Some(vertices.to_vec());
        mesh.vertex_count = vertices.len() as u32;
        
        // Try to create/update the mesh if we have vertices
        self.try_update_mesh(mesh);
    }

    fn mesh_update_normal_dirs(&self, mesh: *const super::Mesh, normal_dirs: &[u32]) {
        let mesh_ptr = mesh as *mut Mesh;
        let mesh = unsafe { &mut *mesh_ptr };

        // Store normal directions for later use
        mesh.normal_dirs = Some(normal_dirs.to_vec());

        // Try to create/update the mesh
        self.try_update_mesh(mesh);
    }

    fn mesh_update_albedo(&self, mesh: *const super::Mesh, colors: &[crate::gfx::Color]) {
        let mesh_ptr = mesh as *mut Mesh;
        let mesh = unsafe { &mut *mesh_ptr };

        // Store colors for later use
        mesh.colors = Some(colors.to_vec());

        // Try to create/update the mesh
        self.try_update_mesh(mesh);
    }

    fn mesh_update_indices(&self, mesh: *const super::Mesh, _indices: &[super::Index]) {
        let mesh_ptr = mesh as *mut Mesh;
        let mesh = unsafe { &mut *mesh_ptr };
        
        // Convert indices to u32 format
        let indices_u32: Vec<u32> = _indices.iter().map(|idx| match idx {
            super::Index::U8(val) => *val as u32,
            super::Index::U16(val) => *val as u32,
            super::Index::U32(val) => *val,
        }).collect();
        
        // Store indices for later use
        mesh.indices = Some(indices_u32);
        
        // Try to create/update the mesh
        self.try_update_mesh(mesh);
    }

    fn mesh_update_face_sizes(&self, mesh: *const super::Mesh, sizes: &[[f32; 2]]) {
        let mesh_ptr = mesh as *mut Mesh;
        let mesh = unsafe { &mut *mesh_ptr };
        
        // Store face sizes for later use
        mesh.face_sizes = Some(sizes.to_vec());
        
        // Try to create/update the mesh
        self.try_update_mesh(mesh);
    }

    fn batch_create(&self) -> *const super::Batch {
        let batch = Batch { meshes: Vec::new() };

        Box::into_raw(Box::new(batch)) as *const super::Batch
    }

    fn batch_destroy(&self, batch: *const super::Batch) {
        let batch_ptr = batch as *const Batch;
        unsafe {
            let _ = Box::from_raw(batch_ptr as *mut Batch);
        }
    }

    fn batch_add_mesh(&self, batch: *const super::Batch, mesh: *const super::Mesh) {
        let batch_ptr = batch as *mut Batch;
        let batch = unsafe { &mut *batch_ptr };

        batch.meshes.push(mesh);
    }

    fn batch_remove_mesh(&self, batch: *const super::Batch, mesh: *const super::Mesh) {
        let batch_ptr = batch as *mut Batch;
        let batch = unsafe { &mut *batch_ptr };

        batch.meshes.retain(|&m| m != mesh);
    }

    fn batch_queue_draw(&self, batch: *const super::Batch) {
        let batch_ptr = batch as *const Batch;
        let batch = unsafe { &*batch_ptr };
        println!("batch_queue_draw called with {} meshes", batch.meshes.len());
        
        // Since meshes are already created with draw commands in the vertex pool,
        // we don't need to do anything here. The draw commands are already active.
        // This function exists for API compatibility with systems that may
        // require explicit draw command submission.
        
        // Debug: Print info about each mesh in the batch
        for (i, &mesh_ptr) in batch.meshes.iter().enumerate() {
            let mesh = unsafe { &*(mesh_ptr as *const Mesh) };
            println!("  Mesh {}: buffer_index={}, vertex_count={}, has_command={}",
                i, mesh.buffer_index, mesh.vertex_count, !mesh.command_index_ptr.is_null());
        }
    }

    fn camera_create(&self) -> *const super::Camera {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;

        // Create camera using Zig renderer
        let zig_camera = unsafe { zig::renderer_camera_create(renderer_ptr) };

        let camera = Camera { zig_camera };

        Box::into_raw(Box::new(camera)) as *const super::Camera
    }

    fn camera_set_projection(&self, camera: *const super::Camera, projection: &[f32; 16]) {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        let camera_ptr = camera as *const Camera;
        let camera = unsafe { &*camera_ptr };

        unsafe {
            zig::renderer_camera_set_projection(
                renderer_ptr,
                camera.zig_camera,
                projection.as_ptr(),
            );
        }
    }

    fn camera_set_transform(&self, camera: *const super::Camera, transform: &[f32; 16]) {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        let camera_ptr = camera as *const Camera;
        let camera = unsafe { &*camera_ptr };

        unsafe {
            zig::renderer_camera_set_transform(
                renderer_ptr,
                camera.zig_camera,
                transform.as_ptr(),
            );
        }
    }

    fn camera_set_main(&self, camera: *const super::Camera) {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        let camera_ptr = camera as *const Camera;
        let camera = unsafe { &*camera_ptr };

        unsafe {
            zig::renderer_camera_set_main(renderer_ptr, camera.zig_camera);
        }
    }

    fn frame_begin(&self) {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;

        // Begin the frame - camera matrices are handled by the Zig layer
        unsafe {
            if !zig::renderer_begin_frame(renderer_ptr) {
                panic!("Whoopsie daisy!");
            }
        }
    }

    fn frame_commit_draw(&self) {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;

        unsafe {
            // Render the scene
            zig::renderer_render(renderer_ptr);
        }
    }

    fn frame_end(&self) {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;

        unsafe {
            // End the frame
            zig::renderer_end_frame(renderer_ptr);
        }
    }
    
    // New GPU-agnostic methods
    fn buffer_create(&self, size: usize, usage: super::BufferUsage, access: super::MemoryAccess) -> *const super::Buffer {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        // Map usage and access to Vulkan buffer type
        let buffer_type_u32 = match (usage, access) {
            (super::BufferUsage::Storage, _) => 0,
            (super::BufferUsage::Uniform, _) => 1,
            (super::BufferUsage::Staging, _) => 2,
            (super::BufferUsage::Vertex, _) => 3,
            (super::BufferUsage::Index, _) => 4,
        };
        
        let handle = unsafe {
            zig::renderer_buffer_create(renderer_ptr, size as u64, buffer_type_u32)
        };
        
        if handle.is_null() {
            return ptr::null();
        }
        
        // Return the handle directly as an opaque pointer
        handle as *const super::Buffer
    }
    
    fn buffer_destroy(&self, buffer: *const super::Buffer) {
        if buffer.is_null() {
            return;
        }
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            zig::renderer_buffer_destroy(renderer_ptr, buffer as *mut c_void);
        }
    }
    
    fn buffer_map_read(&self, buffer: *const super::Buffer) -> Option<&[u8]> {
        if buffer.is_null() {
            return None;
        }
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        // Get buffer size first
        let size = unsafe {
            zig::renderer_buffer_get_size(renderer_ptr, buffer as *mut c_void)
        };
        
        if size == 0 {
            return None;
        }
        
        // Map the buffer memory
        let ptr = unsafe {
            zig::renderer_buffer_map(renderer_ptr, buffer as *mut c_void)
        };
        
        if ptr.is_null() {
            return None;
        }
        
        // Return a slice to the mapped memory
        Some(unsafe { std::slice::from_raw_parts(ptr as *const u8, size as usize) })
    }
    
    fn buffer_map_write(&self, buffer: *const super::Buffer) -> Option<&mut [u8]> {
        // Not implemented for Vulkan - use staging buffers instead
        None
    }
    
    fn buffer_unmap(&self, buffer: *const super::Buffer) {
        if buffer.is_null() {
            return;
        }
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            zig::renderer_buffer_unmap(renderer_ptr, buffer as *mut c_void);
        }
    }
    
    fn shader_create_compute(&self, code: &[u8]) -> *const super::Shader {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        let handle = unsafe {
            zig::renderer_compute_shader_create(
                renderer_ptr,
                code.as_ptr(),
                code.len() as u64,
            )
        };
        
        if handle.is_null() {
            return ptr::null();
        }
        
        handle as *const super::Shader
    }
    
    fn shader_destroy(&self, shader: *const super::Shader) {
        if shader.is_null() {
            return;
        }
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            zig::renderer_compute_shader_destroy(renderer_ptr, shader as *mut c_void);
        }
    }
    
    fn create_encoder(&self) -> Box<dyn super::GpuEncoder + '_> {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        // Create a new command buffer for this encoder
        let cmd_buffer = unsafe {
            zig::renderer_command_buffer_create(renderer_ptr)
        };
        
        if !cmd_buffer.is_null() {
            unsafe {
                zig::renderer_command_buffer_begin(renderer_ptr, cmd_buffer);
            }
        }
        
        Box::new(VulkanEncoder {
            renderer: self.renderer.clone(),
            command_buffer: cmd_buffer,
            is_frame_encoder: false,
        })
    }
    
    fn submit_encoder(&self, encoder: Box<dyn super::GpuEncoder + '_>, info: super::SubmitInfo) {
        // Downcast to get the VulkanEncoder
        let encoder_any = encoder.as_any();
        if let Some(vk_encoder) = encoder_any.downcast_ref::<VulkanEncoder>() {
            let renderer_guard = self.renderer.lock().unwrap();
            let renderer_ptr = *renderer_guard;
            
            // End the command buffer
            unsafe {
                zig::renderer_command_buffer_end(renderer_ptr, vk_encoder.command_buffer);
            }
            
            // Submit with fence synchronization
            if !info.wait_fences.is_empty() || !info.signal_fences.is_empty() {
                // Extract fence handles and values
                let wait_handles: Vec<*mut c_void> = info.wait_fences.iter()
                    .map(|(fence, _)| *fence as *const Fence as *const c_void as *mut c_void)
                    .collect();
                let wait_values: Vec<u64> = info.wait_fences.iter()
                    .map(|(_, val)| *val)
                    .collect();
                    
                let signal_handles: Vec<*mut c_void> = info.signal_fences.iter()
                    .map(|(fence, _)| *fence as *const Fence as *const c_void as *mut c_void)
                    .collect();
                let signal_values: Vec<u64> = info.signal_fences.iter()
                    .map(|(_, val)| *val)
                    .collect();
                
                unsafe {
                    zig::renderer_command_buffer_submit_with_semaphores(
                        renderer_ptr,
                        vk_encoder.command_buffer,
                        wait_handles.as_ptr() as *const c_void,
                        wait_values.as_ptr(),
                        wait_handles.len() as u32,
                        signal_handles.as_ptr() as *const c_void,
                        signal_values.as_ptr(),
                        signal_handles.len() as u32,
                    );
                }
            } else {
                // Simple submit without synchronization
                unsafe {
                    zig::renderer_command_buffer_submit(renderer_ptr, vk_encoder.command_buffer);
                }
            }
        }
        
        // Encoder is dropped here, cleaning up resources
    }
    
    fn fence_create(&self, initial_value: u64) -> *const super::Fence {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        let handle = unsafe {
            zig::renderer_timeline_semaphore_create(renderer_ptr, initial_value)
        };
        
        if handle.is_null() {
            return ptr::null();
        }
        
        handle as *const super::Fence
    }
    
    fn fence_destroy(&self, fence: *const super::Fence) {
        if fence.is_null() {
            return;
        }
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            zig::renderer_timeline_semaphore_destroy(renderer_ptr, fence as *mut c_void);
        }
    }
    
    fn fence_get_value(&self, fence: *const super::Fence) -> u64 {
        if fence.is_null() {
            return 0;
        }
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            zig::renderer_timeline_semaphore_get_value(renderer_ptr, fence as *mut c_void)
        }
    }
    
    fn fence_wait(&self, fence: *const super::Fence, value: u64, timeout_ns: u64) -> bool {
        if fence.is_null() {
            return false;
        }
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            zig::renderer_timeline_semaphore_wait(renderer_ptr, fence as *mut c_void, value, timeout_ns)
        }
    }
    
    fn fence_signal(&self, fence: *const super::Fence, value: u64) {
        if fence.is_null() {
            return;
        }
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            zig::renderer_timeline_semaphore_signal(renderer_ptr, fence as *mut c_void, value);
        }
    }
    
    fn get_frame_encoder(&self) -> Option<&mut dyn super::GpuEncoder> {
        // Get the current frame's command buffer from the renderer
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        unsafe {
            let cmd_handle = zig::renderer_get_current_command_buffer(renderer_ptr);
            if cmd_handle.is_null() {
                None
            } else {
                // Use thread-local storage for the frame encoder
                thread_local! {
                    static FRAME_ENCODER: std::cell::RefCell<Option<Box<VulkanEncoder>>> = std::cell::RefCell::new(None);
                }
                
                FRAME_ENCODER.with(|encoder| {
                    let mut encoder_ref = encoder.borrow_mut();
                    
                    // Create or update the frame encoder
                    match encoder_ref.as_mut() {
                        Some(enc) => {
                            enc.command_buffer = cmd_handle;
                        }
                        None => {
                            *encoder_ref = Some(Box::new(VulkanEncoder {
                                renderer: self.renderer.clone(),
                                command_buffer: cmd_handle,
                                is_frame_encoder: true,
                            }));
                        }
                    }
                    
                    // Return a raw pointer that we'll convert to a reference
                    // This is safe because the thread-local encoder lives for the thread's lifetime
                    encoder_ref.as_mut().map(|enc| {
                        let ptr = enc.as_mut() as *mut dyn super::GpuEncoder;
                        unsafe { &mut *ptr }
                    })
                })
            }
        }
    }
    
    fn create_render_graph(&self, desc: &super::rendergraph::RenderGraphDesc) -> Result<Box<dyn super::rendergraph::RenderGraph>, Box<dyn std::error::Error>> {
        // Create a new Vulkan render graph implementation
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        // Create the render graph through FFI
        let render_graph = rendergraph_impl::VulkanRenderGraph::new(renderer_ptr, desc)?;
        
        Ok(Box::new(render_graph))
    }
}

impl Vulkan {
    /// Get the renderer pointer for physics integration
    pub fn get_renderer_ptr(&self) -> *mut zig::Renderer {
        let renderer_guard = self.renderer.lock().unwrap();
        *renderer_guard
    }
    
    /// Try to update mesh - creates draw command if needed and updates GPU data
    fn try_update_mesh(&self, mesh: &mut Mesh) {
        // Need vertices to do anything
        if mesh.vertices.is_none() {
            println!("try_update_mesh: No vertices set yet, skipping");
            return;
        }
        
        println!("try_update_mesh: vertices={}, normals={}, colors={}, sizes={}", 
            mesh.vertices.is_some(), mesh.normal_dirs.is_some(), 
            mesh.colors.is_some(), mesh.face_sizes.is_some());
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        // Create draw command if this is the first time
        if mesh.command_index_ptr.is_null() {
            // For voxel rendering, we need all attributes to be set
            // Check if we have all required attributes
            if mesh.normal_dirs.is_none() || mesh.colors.is_none() || mesh.face_sizes.is_none() {
                println!("try_update_mesh: Waiting for all attributes to be set before creating mesh");
                return;
            }
            
            let vertices = mesh.vertices.as_ref().unwrap();
            let normal_dirs = mesh.normal_dirs.as_ref().unwrap();
            let colors = mesh.colors.as_ref().unwrap();
            let sizes = mesh.face_sizes.as_ref().unwrap();
            
            // Create initial vertex data with all attributes
            let vertex_data = Self::create_vertex_data_with_sizes(vertices, normal_dirs, colors, sizes);
            
            // Create the mesh in the renderer
            let mut command_index_ptr: *mut u32 = std::ptr::null_mut();
            let success = unsafe {
                zig::renderer_add_mesh(
                    renderer_ptr,
                    mesh.buffer_index,
                    vertex_data.as_ptr() as *const c_void,
                    vertices.len() as u32,
                    mesh.position.as_ptr(),
                    mesh.group,
                    &mut command_index_ptr as *mut *mut u32,
                )
            };
            
            println!("renderer_add_mesh returned: success={}, command_index_ptr={:?}, buffer_index={}", 
                success, command_index_ptr, mesh.buffer_index);
            
            if success && !command_index_ptr.is_null() {
                mesh.command_index_ptr = command_index_ptr;
                println!("Successfully created mesh with {} vertices", vertices.len());
                
                // Debug: print first vertex details
                if vertices.len() > 0 {
                    println!("First vertex: pos={:?}, normal={}, color={:?}, size={:?}",
                        vertices[0].0, normal_dirs[0], colors[0], sizes[0]);
                }
            } else {
                println!("Failed to create draw command for mesh!");
            }
        } else {
            // Update existing mesh
            self.update_mesh_gpu_data(mesh, renderer_ptr);
        }
    }
    
    /// Update mesh GPU data with current attributes
    fn update_mesh_gpu_data(&self, mesh: &mut Mesh, renderer_ptr: *mut zig::Renderer) {
        if mesh.vertices.is_none() {
            return;
        }
        
        let vertices = mesh.vertices.as_ref().unwrap();
        
        // Use stored attributes or defaults
        let normal_dir_vec = vec![4u32; vertices.len()];
        let normal_dirs = mesh.normal_dirs.as_ref().unwrap_or(&normal_dir_vec);
        
        let color_vec = vec![crate::gfx::Color::white(); vertices.len()];
        let colors = mesh.colors.as_ref().unwrap_or(&color_vec);
        
        let size_vec = vec![[1.0f32, 1.0f32]; vertices.len()];
        let sizes = mesh.face_sizes.as_ref().unwrap_or(&size_vec);
        
        // Ensure we have the right number of attributes
        let vertex_count = vertices.len();
        let normal_dirs = if normal_dirs.len() >= vertex_count {
            &normal_dirs[..vertex_count]
        } else {
            &normal_dir_vec[..vertex_count]
        };
        
        let colors = if colors.len() >= vertex_count {
            &colors[..vertex_count]
        } else {
            &color_vec[..vertex_count]
        };
        
        let sizes = if sizes.len() >= vertex_count {
            &sizes[..vertex_count]
        } else {
            &size_vec[..vertex_count]
        };
        
        // Create interleaved vertex data
        let vertex_data = Self::create_vertex_data_with_sizes(vertices, normal_dirs, colors, sizes);
        
        // Debug: log first few vertices
        if vertices.len() > 0 && sizes.len() > 0 {
            println!("DEBUG: Updating {} vertices, data for first 3:", vertices.len());
            for i in 0..3.min(vertices.len()) {
                println!("  Vertex {}:", i);
                println!("    Position: {:?}", vertices[i]);
                println!("    Size: {:?}", sizes[i]);
                println!("    Normal dir: {}", normal_dirs[i]);
                println!("    Color: [{:.2}, {:.2}, {:.2}, {:.2}]", colors[i].r, colors[i].g, colors[i].b, colors[i].a);
            }
            
            // Check byte layout
            if vertex_data.len() >= 80 {
                println!("  First vertex bytes (40): {:02x?}", &vertex_data[0..40]);
                println!("  Second vertex bytes (40): {:02x?}", &vertex_data[40..80]);
            }
        }
        
        unsafe {
            zig::renderer_update_vertices(
                renderer_ptr,
                mesh.buffer_index,
                vertex_data.as_ptr() as *const c_void,
                vertices.len() as u32,
            );
            
            // Update draw command vertex count if needed
            if !mesh.command_index_ptr.is_null() {
                zig::renderer_update_draw_command_vertex_count(
                    renderer_ptr,
                    mesh.command_index_ptr,
                    vertices.len() as u32,
                );
            }
        }
    }
    
    // Helper function to create interleaved vertex data from separate attributes
    fn create_vertex_data(
        vertices: &[math::Vec3f],
        normal_dirs: &[u32],
        colors: &[crate::gfx::Color],
    ) -> Vec<u8> {
        // Use default size of 1x1
        let default_sizes = vec![[1.0f32, 1.0f32]; vertices.len()];
        Self::create_vertex_data_with_sizes(vertices, normal_dirs, colors, &default_sizes)
    }
    
    fn create_vertex_data_with_sizes(
        vertices: &[math::Vec3f],
        normal_dirs: &[u32],
        colors: &[crate::gfx::Color],
        sizes: &[[f32; 2]],
    ) -> Vec<u8> {
        // Match the Zig vertex format exactly (40 bytes per vertex):
        // position (3 f32) + size (2 f32) + normal_dir (u32) + color (4 f32)
        let mut vertex_data = Vec::with_capacity(vertices.len() * 40); // 40 bytes per vertex

        for i in 0..vertices.len() {
            // Add position (3 f32s) - 12 bytes
            vertex_data.extend_from_slice(&vertices[i][0].to_ne_bytes());
            vertex_data.extend_from_slice(&vertices[i][1].to_ne_bytes());
            vertex_data.extend_from_slice(&vertices[i][2].to_ne_bytes());

            // Add size (2 f32s) - 8 bytes
            if i < sizes.len() {
                vertex_data.extend_from_slice(&sizes[i][0].to_ne_bytes());
                vertex_data.extend_from_slice(&sizes[i][1].to_ne_bytes());
            } else {
                vertex_data.extend_from_slice(&1.0f32.to_ne_bytes());
                vertex_data.extend_from_slice(&1.0f32.to_ne_bytes());
            }

            // Add normal direction (1 u32) - 4 bytes
            let normal_dir = if i < normal_dirs.len() {
                normal_dirs[i]
            } else {
                4u32  // Default to +Z direction
            };
            vertex_data.extend_from_slice(&normal_dir.to_ne_bytes());

            // Add color (4 f32s) - 16 bytes
            if i < colors.len() {
                vertex_data.extend_from_slice(&colors[i].r.to_ne_bytes());
                vertex_data.extend_from_slice(&colors[i].g.to_ne_bytes());
                vertex_data.extend_from_slice(&colors[i].b.to_ne_bytes());
                vertex_data.extend_from_slice(&colors[i].a.to_ne_bytes());
            } else {
                // Default color if not enough provided
                vertex_data.extend_from_slice(&1.0f32.to_ne_bytes());
                vertex_data.extend_from_slice(&1.0f32.to_ne_bytes());
                vertex_data.extend_from_slice(&1.0f32.to_ne_bytes());
                vertex_data.extend_from_slice(&1.0f32.to_ne_bytes());
            }
        }

        vertex_data
    }
    
    /// Initialize GPU worldgen
    pub fn init_worldgen(&self) -> Result<(), String> {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        // Create a dummy allocator pointer for now
        let allocator = std::ptr::null_mut();
        
        let worldgen_ptr = unsafe {
            zig::gpu_worldgen_create(renderer_ptr, allocator)
        };
        
        if worldgen_ptr.is_null() {
            return Err("Failed to create GPU worldgen".to_string());
        }
        
        *self.worldgen.borrow_mut() = Some(worldgen_ptr);
        Ok(())
    }
    
    /// Generate world using GPU compute with adaptive chunking and brush buffer
    pub fn worldgen_generate_adaptive_with_brush(
        &self,
        encoder: &mut dyn super::GpuEncoder,
        bounds_min: [f32; 3],
        bounds_max: [f32; 3],
        resolution: [u32; 3],
        voxel_size: f32,
        sdf_buffer: *const super::Buffer,
        params_buffer: *const super::Buffer,
        output_buffer: *const super::Buffer,
        world_params_buffer: *const super::Buffer,
        output_voxels_buffer: *const super::Buffer,
        brush_buffer: *const super::Buffer,
        start_offset: u32,
        max_workgroups: u32,
    ) -> Result<u32, String> {
        // Ensure worldgen is initialized (lazy initialization)
        let mut worldgen_ref = self.worldgen.borrow_mut();
        if worldgen_ref.is_none() {
            drop(worldgen_ref); // Release the borrow
            self.init_worldgen()?;
            worldgen_ref = self.worldgen.borrow_mut();
        }
        
        let worldgen_ptr = *worldgen_ref.as_ref().unwrap();
        
        // Extract the command buffer from the encoder
        let vk_encoder = encoder.as_any().downcast_ref::<VulkanEncoder>()
            .ok_or_else(|| "Expected VulkanEncoder".to_string())?;
        let cmd_buffer_handle = vk_encoder.command_buffer;
        
        // Note: These are now opaque Buffer pointers, not GpuBuffer
        // The Zig side will need to handle them appropriately
        
        // Create a temporary ComputeCommandBuffer struct that worldgen expects
        #[repr(C)]
        struct ComputeCommandBuffer {
            command_buffer: *mut c_void,
            fence: *mut c_void,
        }
        
        let compute_cmd = ComputeCommandBuffer {
            command_buffer: cmd_buffer_handle,
            fence: std::ptr::null_mut(), // No fence for current frame command buffer
        };
        
        // Call the adaptive generation function with brush buffer
        let processed = unsafe {
            zig::gpu_worldgen_generate_adaptive_with_brush(
                worldgen_ptr,
                &compute_cmd as *const ComputeCommandBuffer as *mut c_void,
                bounds_min[0], bounds_min[1], bounds_min[2],
                bounds_max[0], bounds_max[1], bounds_max[2],
                resolution[0], resolution[1], resolution[2],
                voxel_size,
                sdf_buffer as *mut c_void,
                params_buffer as *mut c_void,
                output_buffer as *mut c_void,
                world_params_buffer as *mut c_void,
                output_voxels_buffer as *mut c_void,
                brush_buffer as *mut c_void,
                start_offset,
                max_workgroups,
            )
        };
        
        Ok(processed)
    }
    
    /// Generate world using GPU compute
    pub fn worldgen_generate(
        &self,
        encoder: &mut dyn super::GpuEncoder,
        bounds_min: [f32; 3],
        bounds_max: [f32; 3],
        resolution: [u32; 3],
        voxel_size: f32,
        sdf_buffer: *const super::Buffer,
        params_buffer: *const super::Buffer,
        output_buffer: *const super::Buffer,
        world_params_buffer: *const super::Buffer,
        output_voxels_buffer: *const super::Buffer,
        brush_buffer: *const super::Buffer,
    ) -> Result<(), String> {
        // Use adaptive version with full workload
        let total_workgroups = {
            let group_size = 8;
            let groups_x = (resolution[0] + group_size - 1) / group_size;
            let groups_y = (resolution[1] + group_size - 1) / group_size;
            let groups_z = (resolution[2] + group_size - 1) / group_size;
            groups_x * groups_y * groups_z
        };
        
        self.worldgen_generate_adaptive_with_brush(
            encoder,
            bounds_min,
            bounds_max,
            resolution,
            voxel_size,
            sdf_buffer,
            params_buffer,
            output_buffer,
            world_params_buffer,
            output_voxels_buffer,
            brush_buffer,
            0, // start_offset
            total_workgroups, // process all workgroups
        )?;
        
        Ok(())
    }
    
    /// Generate world using GPU compute with adaptive chunking (legacy without brush buffer)
    pub fn worldgen_generate_adaptive(
        &self,
        encoder: &mut dyn super::GpuEncoder,
        bounds_min: [f32; 3],
        bounds_max: [f32; 3],
        resolution: [u32; 3],
        voxel_size: f32,
        sdf_buffer: *const super::Buffer,
        params_buffer: *const super::Buffer,
        output_buffer: *const super::Buffer,
        world_params_buffer: *const super::Buffer,
        output_voxels_buffer: *const super::Buffer,
        start_offset: u32,
        max_workgroups: u32,
    ) -> Result<u32, String> {
        // Call the new version with a null brush buffer
        self.worldgen_generate_adaptive_with_brush(
            encoder,
            bounds_min,
            bounds_max,
            resolution,
            voxel_size,
            sdf_buffer,
            params_buffer,
            output_buffer,
            world_params_buffer,
            output_voxels_buffer,
            std::ptr::null(), // No brush buffer
            start_offset,
            max_workgroups,
        )
    }
}

impl Drop for Vulkan {
    fn drop(&mut self) {
        // Clean up all resources
        unsafe {
            // Get the raw pointer to the renderer
            if let Ok(mut lock) = self.renderer.lock() {
                let renderer_ptr = *lock;

                // Clean up worldgen if initialized
                if let Some(worldgen_ptr) = self.worldgen.borrow().as_ref() {
                    zig::gpu_worldgen_destroy(*worldgen_ptr);
                }
                
                // Explicitly free all meshes and batches
                for mesh in &self.meshes {
                    if !mesh.command_index_ptr.is_null() {
                        zig::renderer_release_buffer(
                            renderer_ptr,
                            mesh.buffer_index,
                            mesh.command_index_ptr,
                        );
                    }
                }

                // Check if we're the last owner of the renderer pointer
                if Arc::strong_count(&self.renderer) == 1 {
                    zig::renderer_deinit(renderer_ptr);
                    *lock = std::ptr::null_mut(); // Clear the pointer after freeing
                }
            }
        }
    }
}
