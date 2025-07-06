use std::collections::HashMap;

// Module declarations
pub mod vox;
pub mod worldgen;
pub mod sdf;
pub mod brush;
pub mod brush_compiler;
pub mod gpu_worldgen;
pub mod gpu_worldgen_pipeline;
pub mod palette_compression;
pub mod physics_integration;
pub mod vertex_pool_renderer;
pub mod performance;
pub mod voxel_renderer_bridge;
pub mod mesh_generator;
pub mod sdf_serialization;
pub mod gpu_thread_executor;
pub mod gpu_readback;
pub mod adaptive_worldgen;
pub mod gpu_worldgen_rendergraph;

#[cfg(test)]
mod tests;

// Re-exports for convenience
pub use vox::{Voxel, Chunk, Volume, Condition as VoxCondition};
pub use sdf::{Sdf, SdfOps};
pub use brush::{Brush, BrushLayer, LayeredBrush, Condition, EvaluationContext};
pub use gpu_worldgen::{GpuWorldGenerator, VoxelWorkspace, WorldBounds, GenerationParams, BrushSchema, CompressedChunk};
pub use gpu_worldgen_pipeline::{GpuWorldGenPipeline, GenerationRequest, GenerationResult, PipelineStats};
pub use palette_compression::{PaletteCompressionSystem, CompressedVoxelData};
pub use physics_integration::{VoxelPhysicsGenerator, VoxelPhysicsCollider, PhysicsLodLevel};
pub use vertex_pool_renderer::{VertexPoolBatchRenderer, ViewParams, VoxelVertex};
pub use performance::{VoxelPerformanceProfiler, PerformanceReport};
pub use voxel_renderer_bridge::VoxelRendererBridge;
pub use mesh_generator::{MeshGenerator, SimpleCubeMeshGenerator, BinaryGreedyMeshGenerator};

use crate::{engine, gfx, math};

pub struct EntityId(u64);

impl EntityId {
    pub unsafe fn from_actor(actor: *mut engine::Actor) -> Self {
        Self(actor as u64)
    }
    pub unsafe fn to_actor(&self) -> *mut engine::Actor {
        self.0 as *mut engine::Actor
    }
}

pub struct ObserverId(u64);

impl ObserverId {
    pub unsafe fn from_camera(camera: *mut gfx::Camera) -> Self {
        Self(camera as u64)
    }
    pub unsafe fn to_camera(&self) -> *mut gfx::Camera {
        self.0 as *mut gfx::Camera
    }
}

pub struct Entity {
    actor: EntityId,
}

#[derive(Default)]
pub struct World {
    origin: crate::math::Vec3<i64>,
    entities: HashMap<EntityId, Entity>,
    cameras: Vec<(ObserverId, EntityId)>,
}

impl World {}
