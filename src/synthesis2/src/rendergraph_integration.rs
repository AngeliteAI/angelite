use major::gfx::rendergraph::*;
use major::gfx::rendergraph_composer::{SubGraphBuilder, SyncPoint, SyncType, SubGraph, RenderGraphComposer};
use major::gfx::vk::rendergraph_impl::VulkanRenderGraph;
use major::universe::gpu_worldgen_rendergraph::WorldgenRenderGraph;
use major::physx::vk::physics_rendergraph::PhysicsRenderGraph;
use std::sync::{Arc, Mutex};

/// Wrapper for composable render graph
struct ComposableRenderGraph {
    main_graph: Box<dyn RenderGraph>,
    composer: RenderGraphComposer,
}

impl ComposableRenderGraph {
    fn new(main_graph: Box<dyn RenderGraph>) -> Self {
        Self {
            main_graph,
            composer: RenderGraphComposer::new(),
        }
    }
    
    fn add_sub_graph(&mut self, sub_graph: SubGraph) -> Result<(), Box<dyn std::error::Error>> {
        self.composer.add_subgraph(sub_graph);
        Ok(())
    }
    
    fn add_sync_point(&mut self, sync_point: SyncPoint) {
        // Store sync points for later processing
    }
    
    fn compile(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        self.composer.compose(&mut *self.main_graph)?;
        self.main_graph.compile()
    }
    
    fn execute(&mut self, gpu_index: u32) -> Result<(), Box<dyn std::error::Error>> {
        self.main_graph.execute(gpu_index)
    }
    
    fn execute_all_gpus(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        self.main_graph.execute_all_gpus()
    }
}

/// Main render graph integration for the synthesis game
pub struct SynthesisRenderGraph {
    composer: ComposableRenderGraph,
    worldgen: Arc<Mutex<WorldgenRenderGraph>>,
    physics: Arc<Mutex<PhysicsRenderGraph>>,
    
    // Frame resources
    color_target: ImageView,
    depth_target: ImageView,
    gbuffer_albedo: ImageView,
    gbuffer_normal: ImageView,
    gbuffer_motion: ImageView,
    
    // Shadow maps
    shadow_cascades: Vec<ImageView>,
    
    // Post-processing
    bloom_buffer: ImageView,
    final_output: ImageView,
    
    // Rendering state
    voxel_batch: Option<usize>, // Store as usize to make it Send + Sync
    gfx: Arc<dyn major::gfx::Gfx + Send + Sync>,
}

impl SynthesisRenderGraph {
    pub fn new(
        _vulkan_devices: Vec<Arc<major::gfx::vk::Vulkan>>,
        gfx: Arc<dyn major::gfx::Gfx + Send + Sync>,
        window_width: u32,
        window_height: u32,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        // Create main render graph
        let desc = RenderGraphDesc {
            enable_reordering: true,
            enable_aliasing: true,
            use_split_barriers: true,
            enable_multi_queue: true,
            scratch_memory_size: 512 * 1024, // 512KB
            enable_debug_labels: true,
            record_debug_info: cfg!(debug_assertions),
        };
        
        // Create render graph from the gfx instance
        let main_graph = gfx.create_render_graph(&desc)?;
        let mut composer = ComposableRenderGraph::new(main_graph);
        
        // Create frame resources
        let color_target = composer.main_graph.create_transient_image(&TransientImageDesc {
            width: window_width,
            height: window_height,
            depth: 1,
            format: ImageFormat::R16G16B16A16Float,
            usage: ImageUsage {
                color_attachment: true,
                sampled: true,
                storage: true,
                ..Default::default()
            },
            mip_levels: 1,
            array_layers: 1,
            samples: 1,
            name: "color_target".to_string(),
        })?;
        
        let depth_target = composer.main_graph.create_transient_image(&TransientImageDesc {
            width: window_width,
            height: window_height,
            depth: 1,
            format: ImageFormat::D32Float,
            usage: ImageUsage {
                depth_stencil_attachment: true,
                sampled: true,
                ..Default::default()
            },
            mip_levels: 1,
            array_layers: 1,
            samples: 1,
            name: "depth_target".to_string(),
        })?;
        
        // G-buffer for deferred rendering
        let gbuffer_albedo = composer.main_graph.create_transient_image(&TransientImageDesc {
            width: window_width,
            height: window_height,
            depth: 1,
            format: ImageFormat::R8G8B8A8Unorm,
            usage: ImageUsage {
                color_attachment: true,
                sampled: true,
                ..Default::default()
            },
            mip_levels: 1,
            array_layers: 1,
            samples: 1,
            name: "gbuffer_albedo".to_string(),
        })?;
        
        let gbuffer_normal = composer.main_graph.create_transient_image(&TransientImageDesc {
            width: window_width,
            height: window_height,
            depth: 1,
            format: ImageFormat::R16G16B16A16Float,
            usage: ImageUsage {
                color_attachment: true,
                sampled: true,
                ..Default::default()
            },
            mip_levels: 1,
            array_layers: 1,
            samples: 1,
            name: "gbuffer_normal".to_string(),
        })?;
        
        let gbuffer_motion = composer.main_graph.create_transient_image(&TransientImageDesc {
            width: window_width,
            height: window_height,
            depth: 1,
            format: ImageFormat::R16G16Float,
            usage: ImageUsage {
                color_attachment: true,
                sampled: true,
                ..Default::default()
            },
            mip_levels: 1,
            array_layers: 1,
            samples: 1,
            name: "gbuffer_motion".to_string(),
        })?;
        
        // Shadow cascades
        let mut shadow_cascades = Vec::new();
        for i in 0..4 {
            let size = 2048 >> i; // 2048, 1024, 512, 256
            let shadow_map = composer.main_graph.create_transient_image(&TransientImageDesc {
                width: size,
                height: size,
                depth: 1,
                format: ImageFormat::D32Float,
                usage: ImageUsage {
                    depth_stencil_attachment: true,
                    sampled: true,
                    ..Default::default()
                },
                mip_levels: 1,
                array_layers: 1,
                samples: 1,
                name: format!("shadow_cascade_{}", i),
            })?;
            shadow_cascades.push(shadow_map);
        }
        
        // Post-processing buffers
        let bloom_buffer = composer.main_graph.create_transient_image(&TransientImageDesc {
            width: window_width / 2,
            height: window_height / 2,
            depth: 1,
            format: ImageFormat::R16G16B16A16Float,
            usage: ImageUsage {
                color_attachment: true,
                sampled: true,
                storage: true,
                ..Default::default()
            },
            mip_levels: 5, // For bloom mip chain
            array_layers: 1,
            samples: 1,
            name: "bloom_buffer".to_string(),
        })?;
        
        let final_output = composer.main_graph.create_transient_image(&TransientImageDesc {
            width: window_width,
            height: window_height,
            depth: 1,
            format: ImageFormat::R8G8B8A8Unorm,
            usage: ImageUsage {
                storage: true,
                transfer_src: true,
                ..Default::default()
            },
            mip_levels: 1,
            array_layers: 1,
            samples: 1,
            name: "final_output".to_string(),
        })?;
        
        // Create worldgen render graph
        let worldgen = Arc::new(Mutex::new(WorldgenRenderGraph::new(
            gfx.clone(),
            8, // 8 workspaces
        )?));
        
        let physics = Arc::new(Mutex::new(PhysicsRenderGraph::new(
            &mut *composer.main_graph,
            100000, // 100k particles
            64,     // 64x64x64 grid
        )?));
        
        Ok(Self {
            composer,
            worldgen,
            physics,
            color_target,
            depth_target,
            gbuffer_albedo,
            gbuffer_normal,
            gbuffer_motion,
            shadow_cascades,
            bloom_buffer,
            final_output,
            voxel_batch: None,
            gfx,
        })
    }
    
    /// Set the voxel batch to render
    pub fn set_voxel_batch(&mut self, batch: *const major::gfx::Batch) {
        self.voxel_batch = Some(batch as usize);
    }
    
    /// Build and execute a frame
    pub fn render_frame(
        &mut self,
        frame_data: &FrameData,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // Clear previous frame's tasks
        // Keep the same main graph, just reset the composer
        self.composer.composer = RenderGraphComposer::new();
        
        // 1. Physics simulation sub-graph
        let physics_graph = self.physics.lock().unwrap();
        let physics_sub = physics_graph.build_sub_graph(frame_data.dt, [0.0, -9.81, 0.0]);
        self.composer.add_sub_graph(physics_sub.build())?;
        
        // 2. Shadow rendering sub-graph
        let shadow_sub = self.build_shadow_sub_graph(frame_data);
        self.composer.add_sub_graph(shadow_sub)?;
        
        // 3. G-buffer rendering sub-graph
        let gbuffer_sub = self.build_gbuffer_sub_graph(frame_data);
        self.composer.add_sub_graph(gbuffer_sub)?;
        
        // 4. Lighting sub-graph
        let lighting_sub = self.build_lighting_sub_graph(frame_data);
        self.composer.add_sub_graph(lighting_sub)?;
        
        // 5. Transparency sub-graph
        let transparency_sub = self.build_transparency_sub_graph(frame_data);
        self.composer.add_sub_graph(transparency_sub)?;
        
        // 6. Post-processing sub-graph
        let post_sub = self.build_post_processing_sub_graph(frame_data);
        self.composer.add_sub_graph(post_sub)?;
        
        // Add synchronization points
        self.composer.add_sync_point(physics_graph.create_sync_point());
        
        self.composer.add_sync_point(SyncPoint {
            name: "shadow_complete".to_string(),
            id: 0,
            wait_for: vec!["shadow_rendering".to_string()],
            signal_to: vec!["deferred_lighting".to_string()],
            sync_type: SyncType::Event,
        });
        
        self.composer.add_sync_point(SyncPoint {
            name: "gbuffer_complete".to_string(),
            id: 1,
            wait_for: vec!["gbuffer_rendering".to_string()],
            signal_to: vec!["deferred_lighting".to_string()],
            sync_type: SyncType::Event,
        });
        
        self.composer.add_sync_point(SyncPoint {
            name: "opaque_complete".to_string(),
            id: 2,
            wait_for: vec!["deferred_lighting".to_string()],
            signal_to: vec!["transparency".to_string()],
            sync_type: SyncType::Barrier,
        });
        
        // Compile and execute
        self.composer.compile()?;
        
        // Execute on all GPUs if multi-GPU is enabled
        if frame_data.use_multi_gpu {
            self.composer.execute_all_gpus()?;
        } else {
            self.composer.execute(0)?;
        }
        
        Ok(())
    }
    
    fn build_shadow_sub_graph(&self, frame_data: &FrameData) -> SubGraph {
        let mut builder = SubGraphBuilder::new("shadow_rendering");
        builder.priority(20); // High priority - shadows needed for lighting
        
        // Render shadow cascades
        for (cascade_idx, shadow_map) in self.shadow_cascades.iter().enumerate() {
            builder.add_task(Task {
                name: format!("shadow_cascade_{}", cascade_idx),
                task_type: TaskType::Raster,
                attachments: vec![
                    TaskAttachment {
                        name: "shadow_map".to_string(),
                        resource: ResourceView::Image(shadow_map.clone()),
                        access: AccessType::WRITE,
                        stage: PipelineStage::DepthStencilAttachment,
                    },
                ],
                callback: Box::new(move |interface| {
                    // Render shadow casters for this cascade
                    // interface.render_shadow_cascade(cascade_idx)?;
                    Ok(())
                }),
                condition_mask: 0x1, // Enable shadows condition
                condition_value: 0x1,
                queue: QueueType::Main,
                gpu_preference: None,
            });
        }
        
        builder.build()
    }
    
    fn build_gbuffer_sub_graph(&self, frame_data: &FrameData) -> SubGraph {
        let mut builder = SubGraphBuilder::new("gbuffer_rendering");
        builder.priority(15);
        builder.depends_on("physics_simulation"); // Wait for physics to update positions
        
        // Clear and render G-buffer
        builder.add_task(Task {
            name: "clear_gbuffer".to_string(),
            task_type: TaskType::Raster,
            attachments: vec![
                TaskAttachment {
                    name: "albedo".to_string(),
                    resource: ResourceView::Image(self.gbuffer_albedo.clone()),
                    access: AccessType::WRITE,
                    stage: PipelineStage::ColorAttachment,
                },
                TaskAttachment {
                    name: "normal".to_string(),
                    resource: ResourceView::Image(self.gbuffer_normal.clone()),
                    access: AccessType::WRITE,
                    stage: PipelineStage::ColorAttachment,
                },
                TaskAttachment {
                    name: "motion".to_string(),
                    resource: ResourceView::Image(self.gbuffer_motion.clone()),
                    access: AccessType::WRITE,
                    stage: PipelineStage::ColorAttachment,
                },
                TaskAttachment {
                    name: "depth".to_string(),
                    resource: ResourceView::Image(self.depth_target.clone()),
                    access: AccessType::WRITE,
                    stage: PipelineStage::DepthStencilAttachment,
                },
            ],
            callback: Box::new(|interface| {
                // Clear G-buffer
                Ok(())
            }),
            condition_mask: 0,
            condition_value: 0,
                queue: QueueType::Main,
                gpu_preference: None,
        });
        
        // Render opaque geometry
        builder.add_task(Task {
            name: "render_opaque".to_string(),
            task_type: TaskType::Raster,
            attachments: vec![
                TaskAttachment {
                    name: "albedo".to_string(),
                    resource: ResourceView::Image(self.gbuffer_albedo.clone()),
                    access: AccessType::WRITE,
                    stage: PipelineStage::ColorAttachment,
                },
                TaskAttachment {
                    name: "normal".to_string(),
                    resource: ResourceView::Image(self.gbuffer_normal.clone()),
                    access: AccessType::WRITE,
                    stage: PipelineStage::ColorAttachment,
                },
                TaskAttachment {
                    name: "motion".to_string(),
                    resource: ResourceView::Image(self.gbuffer_motion.clone()),
                    access: AccessType::WRITE,
                    stage: PipelineStage::ColorAttachment,
                },
                TaskAttachment {
                    name: "depth".to_string(),
                    resource: ResourceView::Image(self.depth_target.clone()),
                    access: AccessType::READ_WRITE,
                    stage: PipelineStage::DepthStencilAttachment,
                },
            ],
            callback: Box::new({
                let voxel_batch_ptr = self.voxel_batch;
                move |interface| {
                    // Render voxel batch if available
                    if let Some(batch_addr) = voxel_batch_ptr {
                        // Get the Vulkan task interface
                        if let Some(vk_iface) = interface.as_any().downcast_ref::<major::gfx::vk::rendergraph_impl::VulkanTaskInterface>() {
                            unsafe {
                                // Call Zig renderer to draw the batch
                                major::gfx::vk::zig::renderer_render_batch(
                                    vk_iface.renderer,
                                    vk_iface.encoder,
                                    batch_addr as *mut std::ffi::c_void,
                                );
                            }
                        }
                    }
                    Ok(())
                }
            }),
            condition_mask: 0,
            condition_value: 0,
                queue: QueueType::Main,
                gpu_preference: None,
        });
        
        builder.build()
    }
    
    fn build_lighting_sub_graph(&self, frame_data: &FrameData) -> SubGraph {
        let mut builder = SubGraphBuilder::new("deferred_lighting");
        builder.priority(10);
        builder.depends_on("gbuffer_rendering");
        builder.depends_on("shadow_rendering");
        
        // Deferred lighting pass
        builder.add_task(Task {
            name: "deferred_lighting".to_string(),
            task_type: TaskType::Compute,
            attachments: vec![
                // Read G-buffer
                TaskAttachment {
                    name: "albedo".to_string(),
                    resource: ResourceView::Image(self.gbuffer_albedo.clone()),
                    access: AccessType::READ,
                    stage: PipelineStage::ComputeShader,
                },
                TaskAttachment {
                    name: "normal".to_string(),
                    resource: ResourceView::Image(self.gbuffer_normal.clone()),
                    access: AccessType::READ,
                    stage: PipelineStage::ComputeShader,
                },
                TaskAttachment {
                    name: "depth".to_string(),
                    resource: ResourceView::Image(self.depth_target.clone()),
                    access: AccessType::READ,
                    stage: PipelineStage::ComputeShader,
                },
                // Read shadows
                TaskAttachment {
                    name: "shadow_0".to_string(),
                    resource: ResourceView::Image(self.shadow_cascades[0].clone()),
                    access: AccessType::READ,
                    stage: PipelineStage::ComputeShader,
                },
                // Write color
                TaskAttachment {
                    name: "color".to_string(),
                    resource: ResourceView::Image(self.color_target.clone()),
                    access: AccessType::WRITE,
                    stage: PipelineStage::ComputeShader,
                },
            ],
            callback: Box::new({
                let window_width = frame_data.window_width;
                let window_height = frame_data.window_height;
                move |interface| {
                    // Compute lighting
                    let dispatch_x = (window_width + 7) / 8;
                    let dispatch_y = (window_height + 7) / 8;
                    interface.dispatch_compute(dispatch_x, dispatch_y, 1)?;
                    Ok(())
                }
            }),
            condition_mask: 0,
            condition_value: 0,
                queue: QueueType::Main,
                gpu_preference: None,
        });
        
        builder.build()
    }
    
    fn build_transparency_sub_graph(&self, frame_data: &FrameData) -> SubGraph {
        let mut builder = SubGraphBuilder::new("transparency");
        builder.priority(5);
        builder.depends_on("deferred_lighting");
        
        // TODO: Add OIT or alpha blending passes
        
        builder.build()
    }
    
    fn build_post_processing_sub_graph(&self, frame_data: &FrameData) -> SubGraph {
        let mut builder = SubGraphBuilder::new("post_processing");
        builder.priority(0); // Lowest priority - runs last
        builder.depends_on("transparency");
        
        // Bloom
        if frame_data.enable_bloom {
            // Downsample and blur
            builder.add_task(Task {
                name: "bloom_downsample".to_string(),
                task_type: TaskType::Compute,
                attachments: vec![
                    TaskAttachment {
                        name: "color".to_string(),
                        resource: ResourceView::Image(self.color_target.clone()),
                        access: AccessType::READ,
                        stage: PipelineStage::ComputeShader,
                    },
                    TaskAttachment {
                        name: "bloom".to_string(),
                        resource: ResourceView::Image(self.bloom_buffer.clone()),
                        access: AccessType::WRITE,
                        stage: PipelineStage::ComputeShader,
                    },
                ],
                callback: Box::new(|interface| {
                    // Downsample and blur for bloom
                    Ok(())
                }),
                condition_mask: 0x2,
                condition_value: 0x2,
                queue: QueueType::Main,
                gpu_preference: None,
            });
        }
        
        // Tone mapping and final composite
        builder.add_task(Task {
            name: "tone_mapping".to_string(),
            task_type: TaskType::Compute,
            attachments: vec![
                TaskAttachment {
                    name: "color".to_string(),
                    resource: ResourceView::Image(self.color_target.clone()),
                    access: AccessType::READ,
                    stage: PipelineStage::ComputeShader,
                },
                TaskAttachment {
                    name: "bloom".to_string(),
                    resource: ResourceView::Image(self.bloom_buffer.clone()),
                    access: AccessType::READ,
                    stage: PipelineStage::ComputeShader,
                },
                TaskAttachment {
                    name: "output".to_string(),
                    resource: ResourceView::Image(self.final_output.clone()),
                    access: AccessType::WRITE,
                    stage: PipelineStage::ComputeShader,
                },
            ],
            callback: Box::new({
                let window_width = frame_data.window_width;
                let window_height = frame_data.window_height;
                move |interface| {
                    // Apply tone mapping and output final image
                    let dispatch_x = (window_width + 7) / 8;
                    let dispatch_y = (window_height + 7) / 8;
                    interface.dispatch_compute(dispatch_x, dispatch_y, 1)?;
                    Ok(())
                }
            }),
            condition_mask: 0,
            condition_value: 0,
                queue: QueueType::Main,
                gpu_preference: None,
        });
        
        builder.build()
    }
    
    /// Schedule worldgen work
    pub fn queue_worldgen(
        &mut self,
        chunk_id: major::universe::gpu_worldgen::ChunkId,
        bounds: major::universe::gpu_worldgen::WorldBounds,
        params: major::universe::gpu_worldgen::GenerationParams,
        accumulator: Arc<Mutex<major::universe::gpu_worldgen::ChunkAccumulator>>,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut worldgen = self.worldgen.lock().unwrap();
        match worldgen.generate_chunk(chunk_id, bounds, params, accumulator) {
            Ok(()) => Ok(()),
            Err(e) => Err(Box::new(std::io::Error::new(std::io::ErrorKind::Other, e.to_string())))
        }
    }
    
    /// Update render conditions
    pub fn set_render_conditions(&mut self, conditions: RenderConditions) {
        self.composer.main_graph.set_condition(0, conditions.enable_shadows);
        self.composer.main_graph.set_condition(1, conditions.enable_bloom);
        self.composer.main_graph.set_condition(2, conditions.enable_motion_blur);
        self.composer.main_graph.set_condition(3, conditions.enable_ssao);
    }
}

pub struct FrameData {
    pub dt: f32,
    pub window_width: u32,
    pub window_height: u32,
    pub use_multi_gpu: bool,
    pub enable_bloom: bool,
}

pub struct RenderConditions {
    pub enable_shadows: bool,
    pub enable_bloom: bool,
    pub enable_motion_blur: bool,
    pub enable_ssao: bool,
}