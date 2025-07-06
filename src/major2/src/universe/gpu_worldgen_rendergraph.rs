use std::any::Any;
use crate::gfx::rendergraph::*;
use crate::gfx::rendergraph_composer::{SubGraphBuilder, SyncPoint, SyncType};
use crate::gfx::{Gfx, GpuEncoder};
use super::gpu_worldgen::{WorldBounds, GenerationParams, VoxelWorkspace, ChunkId, ChunkAccumulator, CHUNK_SIZE, MINICHUNK_SIZE};
use crate::math::Vec3;
use super::gpu_readback::{DeferredReadbackManager, WorldgenRingBuffer};
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use super::Voxel;

/// Worldgen implementation using the render graph system
pub struct WorldgenRenderGraph {
    gfx: Arc<dyn Gfx + Send + Sync>,
    workspaces: Vec<VoxelWorkspace>,
    frame_index: u64,
}

impl WorldgenRenderGraph {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>, workspace_count: usize) -> Result<Self, Box<dyn std::error::Error>> {
        // Create workspaces
        let mut workspaces = Vec::new();
        for _ in 0..workspace_count {
            // Create empty workspace with proper metadata
            let empty_bounds = WorldBounds {
                min: Vec3::new([0.0, 0.0, 0.0]),
                max: Vec3::new([0.0, 0.0, 0.0]),
                voxel_size: 1.0,
            };
            let metadata = super::gpu_worldgen::WorkspaceMetadata {
                bounds: empty_bounds,
                generation_time: std::time::Duration::from_secs(0),
                voxel_count: 0,
                non_empty_count: 0,
            };
            let workspace = VoxelWorkspace {
                voxels: Vec::new(),
                dimensions: Vec3::new([0.0, 0.0, 0.0]),
                metadata,
            };
            workspaces.push(workspace);
        }
        
        Ok(Self {
            gfx,
            workspaces,
            frame_index: 0,
        })
    }
    
    pub fn generate_chunk(
        &mut self,
        chunk_id: ChunkId,
        bounds: WorldBounds,
        params: GenerationParams,
        accumulator: Arc<Mutex<ChunkAccumulator>>,
    ) -> Result<(), Box<dyn std::error::Error + '_>> {
        // Get next workspace
        let workspace_idx = (self.frame_index as usize) % self.workspaces.len();
        let workspace = &mut self.workspaces[workspace_idx];
        self.frame_index += 1;
        
        // Use the existing GPU worldgen through Vulkan
        if let Some(vulkan) = self.gfx.as_any().downcast_ref::<crate::gfx::vk::Vulkan>() {
            vulkan.ensure_worldgen_initialized()?;
            
            // Create encoder for GPU commands
            let mut encoder = self.gfx.create_encoder();
            
            // Generate the chunk using existing Vulkan worldgen
            vulkan.generate_chunk_gpu(
                &mut *encoder,
                chunk_id,
                bounds,
                params,
                workspace,
                accumulator,
            )?;
            
            // Submit the work with proper lifetime management
            // The encoder needs to be boxed with the same lifetime as self
            let submit_info = crate::gfx::SubmitInfo::default();
            self.gfx.submit_encoder(encoder, submit_info);
        }
        
        Ok(())
    }
    
    pub fn build_sub_graph(&self, dt: f32, gravity: [f32; 3]) -> SubGraphBuilder {
        let mut builder = SubGraphBuilder::new("worldgen");
        builder.priority(10);
        
        // Worldgen tasks would be added here dynamically based on pending work
        
        builder
    }
    
    pub fn create_sync_point(&self) -> SyncPoint {
        SyncPoint {
            name: "worldgen_complete".to_string(),
            id: 1000,
            wait_for: vec!["worldgen".to_string()],
            signal_to: vec![],
            sync_type: SyncType::Event,
        }
    }
}