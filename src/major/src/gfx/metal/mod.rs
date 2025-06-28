use crate::engine::Surface;
use crate::gfx::{Batch, Camera, Gfx, Index, Mesh};
use std::ffi::c_void;
use std::ptr::NonNull;
use std::sync::Arc;

// External function declarations for Swift Metal implementation
#[link(name = "angelite_swift", kind = "dylib")]
unsafe extern "C" {
    fn metal_renderer_create(surface_ptr: *mut c_void) -> *mut c_void;
    fn metal_renderer_destroy(renderer_ptr: *mut c_void);

    fn metal_mesh_create(renderer_ptr: *mut c_void) -> *mut c_void;
    fn metal_mesh_destroy(renderer_ptr: *mut c_void, mesh_ptr: *mut c_void);
    fn metal_mesh_update_vertices(
        renderer_ptr: *mut c_void,
        mesh_ptr: *mut c_void,
        vertices: *const f32,
        count: usize,
    );
    fn metal_mesh_update_indices_u8(
        renderer_ptr: *mut c_void,
        mesh_ptr: *mut c_void,
        indices: *const u8,
        count: usize,
    );
    fn metal_mesh_update_indices_u16(
        renderer_ptr: *mut c_void,
        mesh_ptr: *mut c_void,
        indices: *const u16,
        count: usize,
    );
    fn metal_mesh_update_indices_u32(
        renderer_ptr: *mut c_void,
        mesh_ptr: *mut c_void,
        indices: *const u32,
        count: usize,
    );

    fn metal_batch_create(renderer_ptr: *mut c_void) -> *mut c_void;
    fn metal_batch_destroy(renderer_ptr: *mut c_void, batch_ptr: *mut c_void);
    fn metal_batch_add_mesh(
        renderer_ptr: *mut c_void,
        batch_ptr: *mut c_void,
        mesh_ptr: *mut c_void,
    );
    fn metal_batch_remove_mesh(
        renderer_ptr: *mut c_void,
        batch_ptr: *mut c_void,
        mesh_ptr: *mut c_void,
    );
    fn metal_batch_queue_draw(renderer_ptr: *mut c_void, batch_ptr: *mut c_void);

    fn metal_camera_create(renderer_ptr: *mut c_void) -> *mut c_void;
    fn metal_camera_set_projection(
        renderer_ptr: *mut c_void,
        camera_ptr: *mut c_void,
        projection: *const f32,
    );
    fn metal_camera_set_transform(
        renderer_ptr: *mut c_void,
        camera_ptr: *mut c_void,
        transform: *const f32,
    );
    fn metal_camera_set_main(renderer_ptr: *mut c_void, camera_ptr: *mut c_void);

    fn metal_frame_begin(renderer_ptr: *mut c_void);
    fn metal_frame_commit_draw(renderer_ptr: *mut c_void);
    fn metal_frame_end(renderer_ptr: *mut c_void);
}

pub struct MetalRenderer {
    ptr: NonNull<c_void>,
}

// Safety implementation
unsafe impl Send for MetalRenderer {}
unsafe impl Sync for MetalRenderer {}

impl Drop for MetalRenderer {
    fn drop(&mut self) {
        unsafe {
            metal_renderer_destroy(self.ptr.as_ptr());
        }
    }
}

impl Gfx for MetalRenderer {
    fn new(surface: Box<dyn Surface>) -> Box<dyn Gfx>
    where
        Self: Sized,
    {
        let surface_ptr = surface.raw();
        dbg!(surface_ptr);
        println!("Creating Metal renderer with surface: {:?}", surface_ptr);
        let ptr = unsafe { metal_renderer_create(surface_ptr) };

        if ptr.is_null() {
            panic!("Failed to create Metal renderer");
        }

        Box::new(MetalRenderer {
            ptr: NonNull::new(ptr).unwrap(),
        })
    }

    fn mesh_create(&self) -> *const Mesh {
        unsafe { metal_mesh_create(self.ptr.as_ptr()) as *const Mesh }
    }

    fn mesh_destroy(&self, mesh: *const Mesh) {
        unsafe { metal_mesh_destroy(self.ptr.as_ptr(), mesh as *mut c_void) }
    }

    fn mesh_update_vertices(&self, mesh: *const Mesh, vertices: &[f32]) {
        unsafe {
            metal_mesh_update_vertices(
                self.ptr.as_ptr(),
                mesh as *mut c_void,
                vertices.as_ptr(),
                vertices.len(),
            )
        }
    }

    fn mesh_update_indices(&self, mesh: *const Mesh, indices: &[Index]) {
        // Handle different index types
        if indices.is_empty() {
            return;
        }

        match indices[0] {
            Index::U8(_) => {
                let indices_u8: Vec<u8> = indices
                    .iter()
                    .map(|idx| match idx {
                        Index::U8(val) => *val,
                        _ => panic!("Mixed index types are not supported"),
                    })
                    .collect();
                unsafe {
                    metal_mesh_update_indices_u8(
                        self.ptr.as_ptr(),
                        mesh as *mut c_void,
                        indices_u8.as_ptr(),
                        indices_u8.len(),
                    )
                }
            }
            Index::U16(_) => {
                let indices_u16: Vec<u16> = indices
                    .iter()
                    .map(|idx| match idx {
                        Index::U16(val) => *val,
                        _ => panic!("Mixed index types are not supported"),
                    })
                    .collect();
                unsafe {
                    metal_mesh_update_indices_u16(
                        self.ptr.as_ptr(),
                        mesh as *mut c_void,
                        indices_u16.as_ptr(),
                        indices_u16.len(),
                    )
                }
            }
            Index::U32(_) => {
                let indices_u32: Vec<u32> = indices
                    .iter()
                    .map(|idx| match idx {
                        Index::U32(val) => *val,
                        _ => panic!("Mixed index types are not supported"),
                    })
                    .collect();
                unsafe {
                    metal_mesh_update_indices_u32(
                        self.ptr.as_ptr(),
                        mesh as *mut c_void,
                        indices_u32.as_ptr(),
                        indices_u32.len(),
                    )
                }
            }
        }
    }

    fn batch_create(&self) -> *const Batch {
        unsafe { metal_batch_create(self.ptr.as_ptr()) as *const Batch }
    }

    fn batch_destroy(&self, batch: *const Batch) {
        unsafe { metal_batch_destroy(self.ptr.as_ptr(), batch as *mut c_void) }
    }

    fn batch_add_mesh(&self, batch: *const Batch, mesh: *const Mesh) {
        unsafe {
            metal_batch_add_mesh(self.ptr.as_ptr(), batch as *mut c_void, mesh as *mut c_void)
        }
    }

    fn batch_remove_mesh(&self, batch: *const Batch, mesh: *const Mesh) {
        unsafe {
            metal_batch_remove_mesh(self.ptr.as_ptr(), batch as *mut c_void, mesh as *mut c_void)
        }
    }

    fn batch_queue_draw(&self, batch: *const Batch) {
        unsafe { metal_batch_queue_draw(self.ptr.as_ptr(), batch as *mut c_void) }
    }

    fn camera_create(&self) -> *const Camera {
        unsafe { metal_camera_create(self.ptr.as_ptr()) as *const Camera }
    }

    fn camera_set_projection(&self, camera: *const Camera, projection: &[f32; 16]) {
        unsafe {
            metal_camera_set_projection(
                self.ptr.as_ptr(),
                camera as *mut c_void,
                projection.as_ptr(),
            )
        }
    }

    fn camera_set_transform(&self, camera: *const Camera, transform: &[f32; 16]) {
        unsafe {
            metal_camera_set_transform(self.ptr.as_ptr(), camera as *mut c_void, transform.as_ptr())
        }
    }

    fn camera_set_main(&self, camera: *const Camera) {
        unsafe { metal_camera_set_main(self.ptr.as_ptr(), camera as *mut c_void) }
    }

    fn frame_begin(&self) {
        unsafe { metal_frame_begin(self.ptr.as_ptr()) }
    }

    fn frame_commit_draw(&self) {
        unsafe { metal_frame_commit_draw(self.ptr.as_ptr()) }
    }

    fn frame_end(&self) {
        unsafe { metal_frame_end(self.ptr.as_ptr()) }
    }
}

// Factory function to create a new Metal renderer
pub fn create_metal_renderer(surface: Box<dyn Surface>) -> Box<dyn Gfx> {
    MetalRenderer::new(surface)
}
