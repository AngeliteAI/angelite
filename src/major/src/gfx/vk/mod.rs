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

pub struct Vulkan {
    renderer: Arc<Mutex<*mut zig::Renderer>>,
    meshes: Vec<Mesh>,
    batches: Vec<Batch>,
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

    fn mesh_update_indices(&self, mesh: *const super::Mesh, indices: &[super::Index]) {
        let mesh_ptr = mesh as *mut Mesh;
        let mesh = unsafe { &mut *mesh_ptr };
        
        // Convert indices to u32 format
        let indices_u32: Vec<u32> = indices.iter().map(|idx| match idx {
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
            return;
        }
        
        let renderer_guard = self.renderer.lock().unwrap();
        let renderer_ptr = *renderer_guard;
        
        // Create draw command if this is the first time
        if mesh.command_index_ptr.is_null() {
            let vertices = mesh.vertices.as_ref().unwrap();
            
            // Use stored attributes or defaults
            let normal_dir_vec = vec![4u32; vertices.len()];
            let normal_dirs = mesh.normal_dirs.as_ref().unwrap_or(&normal_dir_vec);
            
            let color_vec = vec![crate::gfx::Color::white(); vertices.len()];
            let colors = mesh.colors.as_ref().unwrap_or(&color_vec);
            
            let size_vec = vec![[1.0f32, 1.0f32]; vertices.len()];
            let sizes = mesh.face_sizes.as_ref().unwrap_or(&size_vec);
            
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
