use std::sync::Arc;
use crate::gfx::rendergraph::*;
use crate::gfx::rendergraph_composer::*;
use crate::gfx::{Gfx, RenderGraphDesc};
use crate::physx::vk::physics_rendergraph::PhysicsRenderGraph;
use crate::universe::worldgen_rendergraph::WorldgenRenderGraph;
use crate::math::Vec3;

/// Integrated renderer that combines physics, worldgen, and rendering using rendergraph
pub struct IntegratedRenderer {
    gfx: Arc<dyn Gfx + Send + Sync>,
    render_graph: Box<dyn RenderGraph>,
    composer: RenderGraphComposer,
    
    // Sub-systems
    physics: PhysicsRenderGraph,
    worldgen: WorldgenRenderGraph,
    
    // Readback manager for deferred GPU reads
    readback_id: u64,
    pending_readbacks: std::collections::HashMap<u64, Box<dyn FnOnce(&[u8]) + Send>>,
}

impl IntegratedRenderer {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>) -> Result<Self, Box<dyn std::error::Error>> {
        // Create render graph
        let desc = RenderGraphDesc {
            enable_reordering: true,
            enable_aliasing: true,
            use_split_barriers: true,
            enable_multi_queue: true,
            scratch_memory_size: 1024 * 1024, // 1MB scratch
            enable_debug_labels: cfg!(debug_assertions),
            record_debug_info: cfg!(debug_assertions),
        };
        
        let mut render_graph = crate::gfx::vk::rendergraph_impl::VulkanRenderGraph::new_from_vulkan(
            gfx.as_any().downcast_ref::<crate::gfx::vk::Vulkan>()
                .ok_or("Expected Vulkan backend")?,
            &desc,
        )?;
        
        // Create sub-systems
        let mut physics = PhysicsRenderGraph::new(gfx.clone())?;
        let mut worldgen = WorldgenRenderGraph::new(gfx.clone())?;
        
        // Register sub-systems with render graph
        physics.register_with_graph(&mut *render_graph)?;
        worldgen.register_with_graph(&mut *render_graph)?;
        
        // Create composer
        let composer = RenderGraphComposer::new();
        
        Ok(Self {
            gfx,
            render_graph: Box::new(render_graph),
            composer,
            physics,
            worldgen,
            readback_id: 0,
            pending_readbacks: std::collections::HashMap::new(),
        })
    }
    
    /// Build and execute frame
    pub fn render_frame(
        &mut self,
        dt: f32,
        gravity: Vec3,
        world_gen_requests: Vec<WorldGenRequest>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Clear previous frame's graph
        self.composer.reset();
        
        // Add physics sub-graph
        self.physics.set_gravity(gravity);
        self.physics.add_physics_tasks(&mut *self.render_graph, dt)?;
        
        // Add worldgen tasks for pending requests
        for request in &world_gen_requests {
            self.worldgen.add_generation_tasks(
                &mut *self.render_graph,
                request.chunk_id,
                request.bounds.clone(),
                request.params.clone(),
            )?;
            
            // Add readback if requested
            if let Some(callback) = request.readback_callback.as_ref() {
                let readback_id = self.next_readback_id();
                let voxel_count = request.calculate_voxel_count();
                
                self.worldgen.add_readback_task(
                    &mut *self.render_graph,
                    &format!("chunk_{}_{}", request.chunk_id.0, request.chunk_id.1),
                    voxel_count,
                    {
                        let id = readback_id;
                        let callback = callback.clone();
                        move |voxels| {
                            // This will be called when readback completes
                            callback(id, voxels);
                        }
                    },
                )?;
            }
        }
        
        // Add rendering tasks
        self.add_rendering_tasks()?;
        
        // Set conditions based on what work we have
        self.render_graph.set_condition(0, !world_gen_requests.is_empty()); // Has worldgen work
        self.render_graph.set_condition(1, self.physics.body_count > 0); // Has physics work
        
        // Compile the graph
        self.render_graph.compile()?;
        
        // Execute on primary GPU
        self.render_graph.execute(0)?;
        
        // Process any completed readbacks
        self.process_readbacks()?;
        
        Ok(())
    }
    
    fn add_rendering_tasks(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        // Get swapchain image from current frame
        let swapchain_image = self.get_current_swapchain_image()?;
        
        // Main render pass
        self.render_graph.add_task(Task {
            name: "main_render_pass".into(),
            task_type: TaskType::Raster,
            attachments: vec![
                TaskAttachment {
                    name: "color".into(),
                    resource: ResourceView::Image(swapchain_image),
                    access: AccessType { write: true, ..Default::default() },
                    stage: PipelineStage::ColorAttachment,
                },
            ],
            callback: Box::new(|interface| {
                // Main rendering logic
                println!("Executing main render pass");
                Ok(())
            }),
            queue: QueueType::Main,
            gpu_preference: Some(GpuPreference::MostPowerful),
            condition_mask: 0,
            condition_value: 0,
        })?;
        
        Ok(())
    }
    
    fn get_current_swapchain_image(&self) -> Result<ImageView, Box<dyn std::error::Error>> {
        // In a real implementation, this would get the current swapchain image
        // For now, return a dummy view
        Ok(ImageView {
            id: ResourceId(9999),
            base_mip_level: 0,
            mip_level_count: Some(1),
            base_array_layer: 0,
            array_layer_count: Some(1),
            aspect: ImageAspect::Color,
        })
    }
    
    fn next_readback_id(&mut self) -> u64 {
        self.readback_id += 1;
        self.readback_id
    }
    
    fn process_readbacks(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        // In a real implementation, this would check timeline semaphores
        // and process completed readbacks
        Ok(())
    }
    
    /// Update physics state
    pub fn update_physics(&mut self, body_count: u32, substeps: u32) {
        self.physics.set_body_count(body_count);
        self.physics.set_substeps(substeps);
    }
    
    /// Submit physics readback request
    pub fn readback_physics_state(
        &mut self,
        callback: impl FnOnce(Vec<crate::physx::vk::physics_rendergraph::RigidBodyGPU>) + Send + 'static,
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.physics.add_readback_task(&mut *self.render_graph, callback)
    }
    
    /// Get debug information from render graph
    pub fn get_debug_info(&self) -> Option<String> {
        self.render_graph.get_debug_info()
    }
    
    /// Multi-GPU support: execute on all available GPUs
    pub fn render_frame_multi_gpu(
        &mut self,
        dt: f32,
        gravity: Vec3,
        world_gen_requests: Vec<WorldGenRequest>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Build the graph same as single GPU
        self.render_frame(dt, gravity, world_gen_requests)?;
        
        // But execute on all GPUs
        self.render_graph.execute_all_gpus()?;
        
        Ok(())
    }
}

/// Request for world generation
pub struct WorldGenRequest {
    pub chunk_id: super::super::universe::ChunkId,
    pub bounds: super::super::universe::WorldBounds,
    pub params: super::super::universe::GenerationParams,
    pub readback_callback: Option<Arc<dyn Fn(u64, Vec<super::super::universe::Voxel>) + Send + Sync>>,
}

impl WorldGenRequest {
    fn calculate_voxel_count(&self) -> u32 {
        let size = self.bounds.max - self.bounds.min;
        let voxels_per_axis = (size.x() / self.bounds.voxel_size) as u32;
        voxels_per_axis * voxels_per_axis * voxels_per_axis
    }
}

/// Example usage of the integrated renderer
#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_integrated_renderer() {
        // This would require a proper Vulkan context to run
        // Just showing the API usage
        
        /*
        let gfx = create_vulkan_context();
        let mut renderer = IntegratedRenderer::new(gfx).unwrap();
        
        // Configure physics
        renderer.update_physics(1000, 4); // 1000 bodies, 4 substeps
        
        // Create worldgen request
        let worldgen_requests = vec![
            WorldGenRequest {
                chunk_id: ChunkId(0, 0),
                bounds: WorldBounds {
                    min: Vec3::new([0.0, 0.0, 0.0]),
                    max: Vec3::new([64.0, 64.0, 64.0]),
                    voxel_size: 1.0,
                },
                params: GenerationParams {
                    brush_count: 5,
                    // ... other params
                },
                readback_callback: Some(Arc::new(|id, voxels| {
                    println!("Chunk {} generated with {} voxels", id, voxels.len());
                })),
            },
        ];
        
        // Render frame
        renderer.render_frame(
            0.016, // 16ms frame time
            Vec3::new([0.0, 0.0, -9.81]), // gravity
            worldgen_requests,
        ).unwrap();
        
        // Request physics state readback
        renderer.readback_physics_state(|bodies| {
            println!("Got {} physics bodies", bodies.len());
        }).unwrap();
        */
    }
}