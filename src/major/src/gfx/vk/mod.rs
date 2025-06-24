use std::ffi::{CString, c_void};
use std::fmt::Debug;
use std::mem::ManuallyDrop;
use std::ptr;
use std::sync::{Arc, Mutex};

use crate::math;

pub struct Mesh {
    buffer_index: u32,
    command_index_ptr: *mut u32,
    vertex_count: u32,
    position: [f32; 3],
    group: u32,
    // Store vertex data for incremental updates
    vertices: Option<Vec<crate::math::Vector<f32, 3>>>,
    normals: Option<Vec<crate::math::Vector<f32, 3>>>,
    colors: Option<Vec<crate::gfx::Color>>,
}

pub struct Batch {
    meshes: Vec<*const super::Mesh>,
}

pub struct Camera {
    position: [f32; 3],
    projection: [f32; 16],
    transform: [f32; 16],
    is_main: bool,
}

pub struct Vulkan {
    renderer: Arc<Mutex<*mut zig::Renderer>>,
    meshes: Vec<Mesh>,
    batches: Vec<Batch>,
    cameras: Vec<Camera>,
    main_camera: Option<usize>,
}

// Module for Zig interop
mod zig {
    use std::ffi::c_void;
    use std::mem::MaybeUninit;

    #[repr(C)]
    #[derive(Debug)]
    pub struct Renderer {
        _opaque: [u8; 0],
    }

    unsafe extern "C" {
        // Renderer functions
        pub fn renderer_init() -> *mut Renderer;
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
    }
}

impl super::Gfx for Vulkan {
    fn new(surface: Box<dyn crate::engine::Surface>) -> Box<dyn super::Gfx>
    where
        Self: Sized,
    {
        // Initialize Vulkan renderer
        let renderer_ptr = unsafe { zig::renderer_init() };

        // Create Arc<Mutex<*mut zig::Renderer>> to store the pointer
        let renderer = Arc::new(Mutex::new(renderer_ptr));

        // Initialize vertex pool with reasonable defaults
        unsafe {
            zig::renderer_init_vertex_pool(renderer_ptr, 100, 1024, 1000);
        }

        Box::new(Vulkan {
            renderer: renderer,
            meshes: Vec::new(),
            batches: Vec::new(),
            cameras: Vec::new(),
            main_camera: None,
        })
    }

    fn mesh_create(&self) -> *const super::Mesh {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;

        // Request a buffer from the vertex pool
        let buffer_index = unsafe { zig::renderer_request_buffer(renderer_ptr) };

        let mesh = Mesh {
            buffer_index,
            command_index_ptr: ptr::null_mut(),
            vertex_count: 0,
            position: [0.0, 0.0, 0.0],
            group: 0,
            vertices: None,
            normals: None,
            colors: None,
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

    fn mesh_update_vertices(&self, mesh: *const super::Mesh, vertices: &[math::Vector<f32, 3>]) {
        let mesh_ptr = mesh as *mut Mesh;
        let mesh = unsafe { &mut *mesh_ptr };

        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;

        // Store vertices for later use with other attributes
        mesh.vertices = Some(vertices.to_vec());
        mesh.vertex_count = vertices.len() as u32;

        if mesh.command_index_ptr.is_null() {
            // First time - need to create the mesh
            let mut cmd_index_ptr: *mut u32 = ptr::null_mut();

            // Initialize with default normals and colors if not provided yet
            let default_normals = if mesh.normals.is_none() {
                vec![math::Vector::<f32, 3>::default(); vertices.len()]
            } else {
                mesh.normals.clone().unwrap()
            };

            let default_colors = if mesh.colors.is_none() {
                vec![crate::gfx::Color::white(); vertices.len()]
            } else {
                mesh.colors.clone().unwrap()
            };

            // Combine vertices, normals, and colors into an interleaved format
            let vertex_data = Self::create_vertex_data(vertices, &default_normals, &default_colors);

            unsafe {
                zig::renderer_add_mesh(
                    renderer_ptr,
                    mesh.buffer_index,
                    vertex_data.as_ptr() as *const c_void,
                    vertices.len() as u32,
                    mesh.position.as_ptr(),
                    mesh.group,
                    &mut cmd_index_ptr,
                );
            }

            mesh.command_index_ptr = cmd_index_ptr;
        } else {
            // Update existing mesh vertices
            // Need to combine with existing normals and colors
            let normal_vec = vec![math::Vector::<f32, 3>::default(); vertices.len()];
            let normals = mesh.normals.as_ref().unwrap_or(&normal_vec);
            let color_vec = vec![crate::gfx::Color::white(); vertices.len()];
            let colors = mesh.colors.as_ref().unwrap_or(&color_vec);

            // Combine vertices, normals, and colors into an interleaved format
            let vertex_data = Self::create_vertex_data(vertices, normals, colors);

            unsafe {
                zig::renderer_update_vertices(
                    renderer_ptr,
                    mesh.buffer_index,
                    vertex_data.as_ptr() as *const c_void,
                    vertices.len() as u32,
                );
            }
        }
    }

    fn mesh_update_normals(&self, mesh: *const super::Mesh, normals: &[math::Vector<f32, 3>]) {
        let mesh_ptr = mesh as *mut Mesh;
        let mesh = unsafe { &mut *mesh_ptr };

        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;

        // Store normals for later use
        mesh.normals = Some(normals.to_vec());

        if mesh.command_index_ptr.is_null() || mesh.vertices.is_none() {
            // Can't update normals without vertices
            return;
        }

        // Update the normals in the renderer
        let vertices = mesh.vertices.as_ref().unwrap();
        let color_vec = vec![crate::gfx::Color::white(); vertices.len()];
        let colors = mesh.colors.as_ref().unwrap_or(&color_vec);

        // Create interleaved normal data
        let normal_data = Self::create_vertex_data(vertices, normals, colors);

        unsafe {
            zig::renderer_update_normals(
                renderer_ptr,
                mesh.buffer_index,
                normal_data.as_ptr() as *const c_void,
                normals.len() as u32,
            );
        }
    }

    fn mesh_update_albedo(&self, mesh: *const super::Mesh, colors: &[crate::gfx::Color]) {
        let mesh_ptr = mesh as *mut Mesh;
        let mesh = unsafe { &mut *mesh_ptr };

        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;

        // Store colors for later use
        mesh.colors = Some(colors.to_vec());

        if mesh.command_index_ptr.is_null() || mesh.vertices.is_none() {
            // Can't update colors without vertices
            return;
        }

        // Update the colors in the renderer
        let vertices = mesh.vertices.as_ref().unwrap();
        let normal_vec = vec![math::Vector::<f32, 3>::default(); vertices.len()];
        let normals = mesh.normals.as_ref().unwrap_or(&normal_vec);

        // Create interleaved color data
        let color_data = Self::create_vertex_data(vertices, normals, colors);

        unsafe {
            zig::renderer_update_colors(
                renderer_ptr,
                mesh.buffer_index,
                color_data.as_ptr() as *const c_void,
                colors.len() as u32,
            );
        }
    }

    fn mesh_update_indices(&self, mesh: *const super::Mesh, indices: &[super::Index]) {
        // Our vertex pooling implementation handles indices automatically
        // This function is kept for API compatibility
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
        // With our vertex pooling system, meshes are automatically queued
        // when they're created. This is kept for API compatibility.
    }

    fn camera_create(&self) -> *const super::Camera {
        let camera = Camera {
            position: [0.0, 0.0, 0.0],
            projection: [
                1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
            ],
            transform: [
                1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0,
            ],
            is_main: false,
        };

        Box::into_raw(Box::new(camera)) as *const super::Camera
    }

    fn camera_set_projection(&self, camera: *const super::Camera, projection: &[f32; 16]) {
        let camera_ptr = camera as *mut Camera;
        let camera = unsafe { &mut *camera_ptr };

        camera.projection.copy_from_slice(projection);
    }

    fn camera_set_transform(&self, camera: *const super::Camera, transform: &[f32; 16]) {
        let camera_ptr = camera as *mut Camera;
        let camera = unsafe { &mut *camera_ptr };

        camera.transform.copy_from_slice(transform);

        // Extract position from the transform matrix (translation component)
        camera.position[0] = transform[12];
        camera.position[1] = transform[13];
        camera.position[2] = transform[14];
    }

    fn camera_set_main(&self, camera: *const super::Camera) {
        // Find this camera in our list or add it
        let camera_ptr = camera as *const Camera;

        // Mark as main camera
        let camera = unsafe { &mut *(camera_ptr as *mut Camera) };
        camera.is_main = true;
    }

    fn frame_begin(&self) {
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;

        // Apply view frustum culling and ordering based on the main camera
        if let Some(camera) = self.cameras.iter().find(|c| c.is_main) {
            unsafe {
                // Apply true back-face culling
                zig::renderer_mask_by_facing(renderer_ptr, camera.position.as_ptr());

                // Apply front-to-back ordering for better rendering
                zig::renderer_order_front_to_back(renderer_ptr, camera.position.as_ptr());

                // Begin the frame
                zig::renderer_begin_frame(renderer_ptr);
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
}

impl Vulkan {
    // Helper function to create interleaved vertex data from separate attributes
    fn create_vertex_data(
        vertices: &[math::Vector<f32, 3>],
        normals: &[math::Vector<f32, 3>],
        colors: &[crate::gfx::Color],
    ) -> Vec<f32> {
        let mut vertex_data = Vec::with_capacity(vertices.len() * 10); // 3 position + 3 normal + 4 color

        for i in 0..vertices.len() {
            // Add position (3 floats)
            vertex_data.push(vertices[i].0[0]);
            vertex_data.push(vertices[i].0[1]);
            vertex_data.push(vertices[i].0[2]);

            // Add normal (3 floats)
            if i < normals.len() {
                vertex_data.push(normals[i].0[0]);
                vertex_data.push(normals[i].0[1]);
                vertex_data.push(normals[i].0[2]);
            } else {
                // Default normal if not enough provided
                vertex_data.push(0.0);
                vertex_data.push(1.0);
                vertex_data.push(0.0);
            }

            // Add color (4 floats)
            if i < colors.len() {
                vertex_data.push(colors[i].r);
                vertex_data.push(colors[i].g);
                vertex_data.push(colors[i].b);
                vertex_data.push(colors[i].a);
            } else {
                // Default color if not enough provided
                vertex_data.push(1.0);
                vertex_data.push(1.0);
                vertex_data.push(1.0);
                vertex_data.push(1.0);
            }
        }

        vertex_data
    }
}

impl Drop for Vulkan {
    fn drop(&mut self) {
        // Clean up all resources
        unsafe {
            // Get the raw pointer to the renderer
            if let Ok(mut lock) = self.renderer.lock() {
                let renderer_ptr = *lock;

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
