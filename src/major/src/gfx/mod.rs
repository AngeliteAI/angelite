pub mod color;
#[cfg(target_os = "macos")]
pub mod metal;
#[cfg(any(target_os = "windows", target_os = "linux"))]
pub mod vk;

use crate::{engine::Surface, math};

pub use color::Color;

pub enum Mesh {}
pub enum Batch {}
pub enum Camera {}

pub enum Index {
    U8(u8),
    U16(u16),
    U32(u32),
}

//IMPLEMENT BASED ON THIS CLAUDE
pub trait Gfx {
    fn new(surface: &dyn Surface) -> Box<dyn Gfx>
    where
        Self: Sized;
    
    fn as_any(&self) -> &dyn std::any::Any;

    fn mesh_create(&self) -> *const Mesh;
    fn mesh_destroy(&self, mesh: *const Mesh);
    fn mesh_update_vertices(&self, mesh: *const Mesh, vertices: &[math::Vec3f]);
    fn mesh_update_normal_dirs(&self, mesh: *const Mesh, normal_dirs: &[u32]);
    fn mesh_update_albedo(&self, mesh: *const Mesh, colors: &[Color]);
    fn mesh_update_indices(&self, mesh: *const Mesh, indices: &[Index]);

    fn batch_create(&self) -> *const Batch;
    fn batch_destroy(&self, batch: *const Batch);
    fn batch_add_mesh(&self, batch: *const Batch, mesh: *const Mesh);
    fn batch_remove_mesh(&self, batch: *const Batch, mesh: *const Mesh);
    fn batch_queue_draw(&self, batch: *const Batch);

    fn camera_create(&self) -> *const Camera;
    fn camera_set_projection(&self, camera: *const Camera, projection: &[f32; 16]);
    fn camera_set_transform(&self, camera: *const Camera, transform: &[f32; 16]);
    fn camera_set_main(&self, camera: *const Camera);

    fn frame_begin(&self);
    fn frame_commit_draw(&self);
    fn frame_end(&self);
}
