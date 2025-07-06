use std::sync::Arc;
use crate::gfx::rendergraph::*;
use crate::gfx::{Gfx, Buffer, BufferUsage, MemoryAccess};
use crate::math::Vec3;
use super::{WorldBounds, GenerationParams, Voxel, ChunkId};

/// Worldgen implementation using render graph
pub struct WorldgenRenderGraph {
    gfx: Arc<dyn Gfx + Send + Sync>,
    
    // GPU buffers for worldgen
    sdf_tree_buffer: *const Buffer,
    brush_program_buffer: *const Buffer,
    params_buffer: *const Buffer,
    output_field_buffer: *const Buffer,
    world_params_buffer: *const Buffer,
    output_voxels_buffer: *const Buffer,
    
    // Buffer views for render graph
    sdf_tree_view: Option<BufferView>,
    brush_program_view: Option<BufferView>,
    params_view: Option<BufferView>,
    output_field_view: Option<BufferView>,
    world_params_view: Option<BufferView>,
    output_voxels_view: Option<BufferView>,
    
    // Pipeline handles
    sdf_eval_pipeline: Option<ResourceId>,
    brush_eval_pipeline: Option<ResourceId>,
    compression_pipeline: Option<ResourceId>,
    
    // Configuration
    max_chunk_size: u32,
    workgroup_size: u32,
}

impl WorldgenRenderGraph {
    pub fn new(gfx: Arc<dyn Gfx + Send + Sync>) -> Result<Self, Box<dyn std::error::Error>> {
        // Create GPU buffers for worldgen
        let sdf_tree_buffer = gfx.buffer_create(
            80 * 16, // SDF tree nodes
            BufferUsage::Storage | BufferUsage::TransferDst,
            MemoryAccess::GpuOnly,
        );
        
        let brush_program_buffer = gfx.buffer_create(
            144 * 16, // Brush program data
            BufferUsage::Storage | BufferUsage::TransferDst,
            MemoryAccess::GpuOnly,
        );
        
        let params_buffer = gfx.buffer_create(
            64, // Generation parameters
            BufferUsage::Storage | BufferUsage::TransferDst,
            MemoryAccess::CpuToGpu,
        );
        
        let output_field_buffer = gfx.buffer_create(
            4 * 1024 * 1024, // 4MB for SDF field
            BufferUsage::Storage | BufferUsage::TransferSrc,
            MemoryAccess::GpuOnly,
        );
        
        let world_params_buffer = gfx.buffer_create(
            64 * 16, // World parameters for multiple chunks
            BufferUsage::Storage | BufferUsage::TransferDst,
            MemoryAccess::CpuToGpu,
        );
        
        let output_voxels_buffer = gfx.buffer_create(
            4 * 1024 * 1024, // 4MB for voxel data
            BufferUsage::Storage | BufferUsage::TransferSrc,
            MemoryAccess::GpuToCpu,
        );
        
        Ok(Self {
            gfx,
            sdf_tree_buffer,
            brush_program_buffer,
            params_buffer,
            output_field_buffer,
            world_params_buffer,
            output_voxels_buffer,
            sdf_tree_view: None,
            brush_program_view: None,
            params_view: None,
            output_field_view: None,
            world_params_view: None,
            output_voxels_view: None,
            sdf_eval_pipeline: None,
            brush_eval_pipeline: None,
            compression_pipeline: None,
            max_chunk_size: 128,
            workgroup_size: 8,
        })
    }
    
    pub fn register_with_graph(&mut self, graph: &mut dyn RenderGraph) -> Result<(), Box<dyn std::error::Error>> {
        // Register persistent buffers
        self.sdf_tree_view = Some(graph.use_persistent_buffer(
            &(self.sdf_tree_buffer as *const _ as *mut std::ffi::c_void),
            80 * 16,
            BufferUsage {
                storage: true,
                transfer_dst: true,
                device_address: true,
                ..Default::default()
            },
            GpuMask::all(),
        )?);
        
        self.brush_program_view = Some(graph.use_persistent_buffer(
            &(self.brush_program_buffer as *const _ as *mut std::ffi::c_void),
            144 * 16,
            BufferUsage {
                storage: true,
                transfer_dst: true,
                device_address: true,
                ..Default::default()
            },
            GpuMask::all(),
        )?);
        
        self.params_view = Some(graph.use_persistent_buffer(
            &(self.params_buffer as *const _ as *mut std::ffi::c_void),
            64,
            BufferUsage {
                storage: true,
                transfer_dst: true,
                device_address: true,
                ..Default::default()
            },
            GpuMask::all(),
        )?);
        
        self.output_field_view = Some(graph.use_persistent_buffer(
            &(self.output_field_buffer as *const _ as *mut std::ffi::c_void),
            4 * 1024 * 1024,
            BufferUsage {
                storage: true,
                transfer_src: true,
                device_address: true,
                ..Default::default()
            },
            GpuMask::all(),
        )?);
        
        self.world_params_view = Some(graph.use_persistent_buffer(
            &(self.world_params_buffer as *const _ as *mut std::ffi::c_void),
            64 * 16,
            BufferUsage {
                storage: true,
                transfer_dst: true,
                device_address: true,
                ..Default::default()
            },
            GpuMask::all(),
        )?);
        
        self.output_voxels_view = Some(graph.use_persistent_buffer(
            &(self.output_voxels_buffer as *const _ as *mut std::ffi::c_void),
            4 * 1024 * 1024,
            BufferUsage {
                storage: true,
                transfer_src: true,
                device_address: true,
                ..Default::default()
            },
            GpuMask::all(),
        )?);
        
        // Register compute pipelines
        self.sdf_eval_pipeline = Some(ResourceId(2001));
        self.brush_eval_pipeline = Some(ResourceId(2002));
        self.compression_pipeline = Some(ResourceId(2003));
        
        Ok(())
    }
    
    pub fn add_generation_tasks(
        &self,
        graph: &mut dyn RenderGraph,
        chunk_id: ChunkId,
        bounds: WorldBounds,
        params: GenerationParams,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let chunk_name = format!("chunk_{}_{}", chunk_id.0, chunk_id.1);
        
        // Calculate dispatch dimensions
        let chunk_size = bounds.max - bounds.min;
        let voxels_per_axis = (chunk_size.x() / bounds.voxel_size) as u32;
        let total_voxels = voxels_per_axis * voxels_per_axis * voxels_per_axis;
        let workgroups = (total_voxels + self.workgroup_size - 1) / self.workgroup_size;
        
        // 1. SDF evaluation task
        self.add_sdf_eval_task(graph, &chunk_name, workgroups)?;
        
        // 2. Brush evaluation task (if brushes are present)
        if params.brush_count > 0 {
            self.add_brush_eval_task(graph, &chunk_name, workgroups, params.brush_count)?;
        }
        
        // 3. Compression task
        self.add_compression_task(graph, &chunk_name, workgroups)?;
        
        Ok(())
    }
    
    fn add_sdf_eval_task(
        &self,
        graph: &mut dyn RenderGraph,
        chunk_name: &str,
        workgroups: u32,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let sdf_tree_view = self.sdf_tree_view.ok_or("SDF tree buffer not registered")?;
        let params_view = self.params_view.ok_or("Params buffer not registered")?;
        let output_field_view = self.output_field_view.ok_or("Output field buffer not registered")?;
        let world_params_view = self.world_params_view.ok_or("World params buffer not registered")?;
        
        graph.add_task(Task {
            name: format!("{}_sdf_eval", chunk_name),
            task_type: TaskType::Compute,
            attachments: vec![
                TaskAttachment {
                    name: "sdf_tree".into(),
                    resource: ResourceView::Buffer(sdf_tree_view),
                    access: AccessType { read: true, concurrent: true, ..Default::default() },
                    stage: PipelineStage::ComputeShader,
                },
                TaskAttachment {
                    name: "params".into(),
                    resource: ResourceView::Buffer(params_view),
                    access: AccessType { read: true, concurrent: true, ..Default::default() },
                    stage: PipelineStage::ComputeShader,
                },
                TaskAttachment {
                    name: "output_field".into(),
                    resource: ResourceView::Buffer(output_field_view),
                    access: AccessType { write: true, ..Default::default() },
                    stage: PipelineStage::ComputeShader,
                },
                TaskAttachment {
                    name: "world_params".into(),
                    resource: ResourceView::Buffer(world_params_view),
                    access: AccessType { read: true, concurrent: true, ..Default::default() },
                    stage: PipelineStage::ComputeShader,
                },
            ],
            callback: Box::new(move |interface| {
                // Dispatch SDF evaluation compute shader
                if let Some(cmd_buffer) = interface.encoder().downcast_ref::<*mut std::ffi::c_void>() {
                    println!("Dispatching SDF evaluation: {} workgroups", workgroups);
                }
                Ok(())
            }),
            queue: QueueType::Compute(0),
            gpu_preference: Some(GpuPreference::MostPowerful),
            condition_mask: 0,
            condition_value: 0,
        })?;
        
        Ok(())
    }
    
    fn add_brush_eval_task(
        &self,
        graph: &mut dyn RenderGraph,
        chunk_name: &str,
        workgroups: u32,
        brush_count: u32,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let brush_program_view = self.brush_program_view.ok_or("Brush program buffer not registered")?;
        let output_field_view = self.output_field_view.ok_or("Output field buffer not registered")?;
        let output_voxels_view = self.output_voxels_view.ok_or("Output voxels buffer not registered")?;
        
        graph.add_task(Task {
            name: format!("{}_brush_eval", chunk_name),
            task_type: TaskType::Compute,
            attachments: vec![
                TaskAttachment {
                    name: "brush_program".into(),
                    resource: ResourceView::Buffer(brush_program_view),
                    access: AccessType { read: true, concurrent: true, ..Default::default() },
                    stage: PipelineStage::ComputeShader,
                },
                TaskAttachment {
                    name: "output_field".into(),
                    resource: ResourceView::Buffer(output_field_view),
                    access: AccessType { read: true, concurrent: true, ..Default::default() },
                    stage: PipelineStage::ComputeShader,
                },
                TaskAttachment {
                    name: "output_voxels".into(),
                    resource: ResourceView::Buffer(output_voxels_view),
                    access: AccessType { write: true, ..Default::default() },
                    stage: PipelineStage::ComputeShader,
                },
            ],
            callback: Box::new(move |interface| {
                // Dispatch brush evaluation compute shader
                if let Some(cmd_buffer) = interface.encoder().downcast_ref::<*mut std::ffi::c_void>() {
                    println!("Dispatching brush evaluation: {} workgroups, {} brushes", workgroups, brush_count);
                }
                Ok(())
            }),
            queue: QueueType::Compute(0),
            gpu_preference: Some(GpuPreference::MostPowerful),
            condition_mask: 0,
            condition_value: 0,
        })?;
        
        Ok(())
    }
    
    fn add_compression_task(
        &self,
        graph: &mut dyn RenderGraph,
        chunk_name: &str,
        workgroups: u32,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let output_voxels_view = self.output_voxels_view.ok_or("Output voxels buffer not registered")?;
        
        graph.add_task(Task {
            name: format!("{}_compression", chunk_name),
            task_type: TaskType::Compute,
            attachments: vec![
                TaskAttachment {
                    name: "voxels".into(),
                    resource: ResourceView::Buffer(output_voxels_view),
                    access: AccessType { read: true, write: true, ..Default::default() },
                    stage: PipelineStage::ComputeShader,
                },
            ],
            callback: Box::new(move |interface| {
                // Dispatch compression compute shader
                if let Some(cmd_buffer) = interface.encoder().downcast_ref::<*mut std::ffi::c_void>() {
                    println!("Dispatching voxel compression: {} workgroups", workgroups);
                }
                Ok(())
            }),
            queue: QueueType::Compute(1), // Use different queue for compression
            gpu_preference: Some(GpuPreference::SecondMostPowerful), // Can use secondary GPU
            condition_mask: 0,
            condition_value: 0,
        })?;
        
        Ok(())
    }
    
    // Add a readback task for generated voxels
    pub fn add_readback_task(
        &self,
        graph: &mut dyn RenderGraph,
        chunk_name: &str,
        voxel_count: u32,
        callback: impl FnOnce(Vec<Voxel>) + Send + 'static,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let output_voxels_view = self.output_voxels_view.ok_or("Output voxels buffer not registered")?;
        let buffer_size = voxel_count as u64 * 4; // u32 per voxel
        
        // Create staging buffer for readback
        let staging_buffer = graph.create_transient_buffer(&TransientBufferDesc {
            name: format!("{}_readback_staging", chunk_name),
            size: buffer_size,
            usage: BufferUsage {
                transfer_dst: true,
                ..Default::default()
            },
        })?;
        
        // Add copy task
        graph.add_task(Task {
            name: format!("{}_readback_copy", chunk_name),
            task_type: TaskType::Transfer,
            attachments: vec![
                TaskAttachment {
                    name: "src".into(),
                    resource: ResourceView::Buffer(output_voxels_view),
                    access: AccessType { read: true, concurrent: true, ..Default::default() },
                    stage: PipelineStage::Transfer,
                },
                TaskAttachment {
                    name: "dst".into(),
                    resource: ResourceView::Buffer(staging_buffer),
                    access: AccessType { write: true, ..Default::default() },
                    stage: PipelineStage::Transfer,
                },
            ],
            callback: Box::new(move |interface| {
                // Copy voxel data to staging buffer
                println!("Copying voxel data for readback");
                Ok(())
            }),
            queue: QueueType::Transfer(0),
            gpu_preference: None,
            condition_mask: 0,
            condition_value: 0,
        })?;
        
        // Add host read task (deferred)
        graph.add_task(Task {
            name: format!("{}_readback_host", chunk_name),
            task_type: TaskType::General,
            attachments: vec![
                TaskAttachment {
                    name: "staging".into(),
                    resource: ResourceView::Buffer(staging_buffer),
                    access: AccessType { read: true, concurrent: true, ..Default::default() },
                    stage: PipelineStage::Host,
                },
            ],
            callback: Box::new(move |interface| {
                // This would be called when the GPU work is complete
                println!("Worldgen readback complete for chunk");
                
                // Create dummy data for now
                let voxels = vec![Voxel(0); voxel_count as usize];
                callback(voxels);
                
                Ok(())
            }),
            queue: QueueType::Main,
            gpu_preference: None,
            condition_mask: 0,
            condition_value: 0,
        })?;
        
        Ok(())
    }
    
    // Helper to update generation parameters
    pub fn update_params(
        &self,
        params: &GenerationParams,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // In a real implementation, this would update the params buffer
        // through a mapped memory region or staging buffer
        Ok(())
    }
    
    // Helper to update world bounds
    pub fn update_world_bounds(
        &self,
        bounds: &WorldBounds,
    ) -> Result<(), Box<dyn std::error::Error>> {
        // In a real implementation, this would update the world params buffer
        Ok(())
    }
}