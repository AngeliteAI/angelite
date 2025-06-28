use crate::math::Vec3;
use super::vox::Sdf;

pub struct Bounds {
    pub min: Vec3<f32>,
    pub max: Vec3<f32>,
}

pub trait Generator<Marker, Schema>: Send + Sync {
    type Output;
    
    fn world(&self) -> &super::World;
    
    async fn generate(&self, schema: Schema, bounds: Bounds) -> Self::Output;
}

pub enum GeometrySchema {
    Sdf(Box<dyn Sdf>),
    Brush(BrushSchema),
}

pub struct BrushSchema {
    pub layers: Vec<BrushLayer>,
}

pub struct BrushLayer {
    pub condition: super::vox::Condition,
    pub voxel: super::vox::Voxel,
}

pub struct Vulkan;
pub struct CPU;

pub mod sdf_plane;