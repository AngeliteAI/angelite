pub mod metal;

use crate::engine::Surface;

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
    fn new(surface: Box<dyn Surface>) -> Box<dyn Gfx>
    where
        Self: Sized;

    fn mesh_create(&self) -> *const Mesh;
    fn mesh_destroy(&self, mesh: *const Mesh);
    fn mesh_update_vertices(&self, mesh: *const Mesh, vertices: &[f32]);
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
