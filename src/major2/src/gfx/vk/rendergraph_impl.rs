use std::any::Any;
use std::ffi::{CString, c_void};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use crate::gfx::rendergraph::*;

// FFI declarations for Zig render graph
#[repr(C)]
struct RenderGraphInfo {
    device_count: u32,
    devices: *const *const c_void,
    enable_reordering: bool,
    enable_aliasing: bool,
    use_split_barriers: bool,
    enable_multi_queue: bool,
    scratch_memory_size: usize,
    enable_debug_labels: bool,
    record_debug_info: bool,
    // GPU devices sorted by power (most powerful first)
    gpu_power_indices: *const u32,
}

#[repr(C)]
struct TransientBufferInfoFFI {
    size: u64,
    usage: u32,
    name: *const i8,
}

#[repr(C)]
struct TransientImageInfoFFI {
    width: u32,
    height: u32,
    depth: u32,
    format: u32,
    usage: u32,
    mip_levels: u32,
    array_layers: u32,
    samples: u32,
    name: *const i8,
}

#[repr(C)]
struct TaskAttachmentInfoFFI {
    resource_type: i32,
    resource_handle: *mut c_void,
    access: u8,
    stage: i32,
    name: *const i8,
}

#[repr(C)]
struct TaskInfoFFI {
    name: *const i8,
    task_type: i32,
    attachments: *const TaskAttachmentInfoFFI,
    attachment_count: u32,
    callback: extern "C" fn(*mut c_void),
    user_data: *mut c_void,
    condition_mask: u32,
    condition_value: u32,
    // Queue selection: main (0), compute (1-8), transfer (9-10)
    queue_index: u32,
    // GPU preference: 0 = most powerful, 1 = second most powerful, etc.
    gpu_preference: u32,
}

// FFI function declarations
unsafe extern "C" {
    fn rendergraph_create(info: *const RenderGraphInfo) -> *mut c_void;
    fn rendergraph_destroy(handle: *mut c_void);
    fn rendergraph_create_transient_buffer(handle: *mut c_void, info: *const TransientBufferInfoFFI) -> *mut c_void;
    fn rendergraph_create_transient_image(handle: *mut c_void, info: *const TransientImageInfoFFI) -> *mut c_void;
    fn rendergraph_use_persistent_buffer(
        handle: *mut c_void,
        buffer: *mut c_void,
        size: u64,
        usage: u32,
        gpu_mask: u32,
    ) -> *mut c_void;
    fn rendergraph_use_persistent_image(
        handle: *mut c_void,
        image: *mut c_void,
        width: u32,
        height: u32,
        depth: u32,
        format: u32,
        usage: u32,
        gpu_mask: u32,
    ) -> *mut c_void;
    fn rendergraph_add_task(handle: *mut c_void, info: *const TaskInfoFFI) -> bool;
    fn rendergraph_set_condition(handle: *mut c_void, condition_index: u32, value: bool);
    fn rendergraph_compile(handle: *mut c_void) -> bool;
    fn rendergraph_execute(handle: *mut c_void, gpu_index: u32) -> bool;
    fn rendergraph_execute_on_all_gpus(handle: *mut c_void) -> bool;
    fn rendergraph_get_gpu_count(handle: *mut c_void) -> u32;
    fn rendergraph_get_debug_info(handle: *mut c_void, buffer: *mut u8, buffer_size: usize) -> usize;
    fn rendergraph_destroy_buffer_view(view: *mut c_void);
    fn rendergraph_destroy_image_view(view: *mut c_void);
    fn rendergraph_get_task_interface(user_data: *mut c_void) -> *const TaskInterfaceFFI;
    
    // Inline task builder FFI
    fn rendergraph_inline_task_compute(handle: *mut c_void, name: *const i8) -> *mut c_void;
    fn rendergraph_inline_task_raster(handle: *mut c_void, name: *const i8) -> *mut c_void;
    fn rendergraph_inline_task_transfer(handle: *mut c_void, name: *const i8) -> *mut c_void;
    fn rendergraph_inline_task_reads(task: *mut c_void, stage: i32, view: *mut c_void) -> *mut c_void;
    fn rendergraph_inline_task_writes(task: *mut c_void, stage: i32, view: *mut c_void) -> *mut c_void;
    fn rendergraph_inline_task_samples(task: *mut c_void, stage: i32, view: *mut c_void) -> *mut c_void;
    fn rendergraph_inline_task_execute(task: *mut c_void, callback: extern "C" fn(*mut c_void), user_data: *mut c_void) -> bool;
}

/// Vulkan implementation of the render graph
pub struct VulkanRenderGraph {
    handle: *mut c_void,
    devices: Vec<*mut super::zig::Renderer>,
    gpu_power_order: Vec<u32>,
    resource_map: HashMap<ResourceId, *mut c_void>,
    next_resource_id: u64,
    scratch_memory: Vec<u8>,
    debug_buffer: Vec<u8>,
}

unsafe impl Send for VulkanRenderGraph {}
unsafe impl Sync for VulkanRenderGraph {}

impl VulkanRenderGraph {
    pub fn new(renderer_ptr: *mut super::zig::Renderer, desc: &RenderGraphDesc) -> Result<Self, Box<dyn std::error::Error>> {
        // Get device info from renderer to determine GPU capabilities
        let device_ptrs = vec![renderer_ptr as *const c_void];
        let gpu_power_order = vec![0u32]; // Primary GPU is most powerful for now
        
        // In the future, we can query device properties to determine actual power order
        // based on factors like:
        // - Device type (discrete vs integrated)
        // - Memory size
        // - Compute unit count
        // - Clock speeds
        
        let info = RenderGraphInfo {
            device_count: device_ptrs.len() as u32,
            devices: device_ptrs.as_ptr(),
            enable_reordering: desc.enable_reordering,
            enable_aliasing: desc.enable_aliasing,
            use_split_barriers: desc.use_split_barriers,
            enable_multi_queue: desc.enable_multi_queue,
            scratch_memory_size: desc.scratch_memory_size,
            enable_debug_labels: desc.enable_debug_labels,
            record_debug_info: desc.record_debug_info,
            gpu_power_indices: gpu_power_order.as_ptr(),
        };
        
        let handle = unsafe { rendergraph_create(&info) };
        if handle.is_null() {
            return Err("Failed to create render graph".into());
        }
        
        Ok(Self {
            handle,
            devices: vec![renderer_ptr],
            gpu_power_order,
            resource_map: HashMap::new(),
            next_resource_id: 1,
            scratch_memory: vec![0; desc.scratch_memory_size],
            debug_buffer: vec![0; 64 * 1024], // 64KB for debug info
        })
    }
    
    /// Create a render graph from Vulkan device
    pub fn new_from_vulkan(vulkan: &super::Vulkan, desc: &RenderGraphDesc) -> Result<Self, Box<dyn std::error::Error>> {
        // Get renderer from Vulkan
        let renderer_ptr = *vulkan.renderer.lock().unwrap();
        Self::new(renderer_ptr, desc)
    }
    
    /// Create a render graph with multiple GPU devices
    pub fn new_multi_gpu(renderer_ptrs: Vec<*mut super::zig::Renderer>, desc: &RenderGraphDesc) -> Result<Self, Box<dyn std::error::Error>> {
        if renderer_ptrs.is_empty() {
            return Err("No GPU devices provided".into());
        }
        
        // Convert to device pointers
        let device_ptrs: Vec<*const c_void> = renderer_ptrs.iter()
            .map(|&ptr| ptr as *const c_void)
            .collect();
        
        // Determine GPU power order
        // For now, assume GPUs are provided in power order (most powerful first)
        let gpu_power_order: Vec<u32> = (0..renderer_ptrs.len() as u32).collect();
        
        let info = RenderGraphInfo {
            device_count: device_ptrs.len() as u32,
            devices: device_ptrs.as_ptr(),
            enable_reordering: desc.enable_reordering,
            enable_aliasing: desc.enable_aliasing,
            use_split_barriers: desc.use_split_barriers,
            enable_multi_queue: desc.enable_multi_queue,
            scratch_memory_size: desc.scratch_memory_size,
            enable_debug_labels: desc.enable_debug_labels,
            record_debug_info: desc.record_debug_info,
            gpu_power_indices: gpu_power_order.as_ptr(),
        };
        
        let handle = unsafe { rendergraph_create(&info) };
        if handle.is_null() {
            return Err("Failed to create multi-GPU render graph".into());
        }
        
        Ok(Self {
            handle,
            devices: renderer_ptrs,
            gpu_power_order,
            resource_map: HashMap::new(),
            next_resource_id: 1,
            scratch_memory: vec![0; desc.scratch_memory_size],
            debug_buffer: vec![0; 64 * 1024], // 64KB for debug info
        })
    }
}

impl Drop for VulkanRenderGraph {
    fn drop(&mut self) {
        if !self.handle.is_null() {
            unsafe { rendergraph_destroy(self.handle) };
        }
    }
}

impl RenderGraph for VulkanRenderGraph {
    fn create_transient_buffer(&mut self, desc: &TransientBufferDesc) -> Result<BufferView, Box<dyn std::error::Error>> {
        let name = CString::new(desc.name.as_str())?;
        
        let info = TransientBufferInfoFFI {
            size: desc.size,
            usage: buffer_usage_to_vk(desc.usage),
            name: name.as_ptr(),
        };
        
        let view_handle = unsafe { rendergraph_create_transient_buffer(self.handle, &info) };
        if view_handle.is_null() {
            return Err("Failed to create transient buffer".into());
        }
        
        let id = ResourceId(self.next_resource_id);
        self.next_resource_id += 1;
        self.resource_map.insert(id, view_handle);
        
        Ok(BufferView {
            id,
            offset: 0,
            size: None,
        })
    }
    
    fn create_transient_image(&mut self, desc: &TransientImageDesc) -> Result<ImageView, Box<dyn std::error::Error>> {
        let name = CString::new(desc.name.as_str())?;
        
        let info = TransientImageInfoFFI {
            width: desc.width,
            height: desc.height,
            depth: desc.depth,
            format: format_to_vk(desc.format),
            usage: image_usage_to_vk(desc.usage),
            mip_levels: desc.mip_levels,
            array_layers: desc.array_layers,
            samples: desc.samples,
            name: name.as_ptr(),
        };
        
        let view_handle = unsafe { rendergraph_create_transient_image(self.handle, &info) };
        if view_handle.is_null() {
            return Err("Failed to create transient image".into());
        }
        
        let id = ResourceId(self.next_resource_id);
        self.next_resource_id += 1;
        self.resource_map.insert(id, view_handle);
        
        Ok(ImageView {
            id,
            base_mip_level: 0,
            mip_level_count: None,
            base_array_layer: 0,
            array_layer_count: None,
            aspect: ImageAspect::Color,
        })
    }
    
    fn use_persistent_buffer(
        &mut self,
        handle: &dyn Any,
        size: u64,
        usage: BufferUsage,
        gpu_mask: GpuMask,
    ) -> Result<BufferView, Box<dyn std::error::Error>> {
        // Downcast to Vulkan buffer handle
        let buffer_ptr = handle.downcast_ref::<*mut c_void>()
            .ok_or("Invalid buffer handle type")?;
        
        let view_handle = unsafe {
            rendergraph_use_persistent_buffer(
                self.handle,
                *buffer_ptr,
                size,
                buffer_usage_to_vk(usage),
                gpu_mask.0,
            )
        };
        
        if view_handle.is_null() {
            return Err("Failed to use persistent buffer".into());
        }
        
        let id = ResourceId(self.next_resource_id);
        self.next_resource_id += 1;
        self.resource_map.insert(id, view_handle);
        
        Ok(BufferView {
            id,
            offset: 0,
            size: None,
        })
    }
    
    fn use_persistent_image(
        &mut self,
        handle: &dyn Any,
        desc: &TransientImageDesc,
        gpu_mask: GpuMask,
    ) -> Result<ImageView, Box<dyn std::error::Error>> {
        let image_ptr = handle.downcast_ref::<*mut c_void>()
            .ok_or("Invalid image handle type")?;
        
        let view_handle = unsafe {
            rendergraph_use_persistent_image(
                self.handle,
                *image_ptr,
                desc.width,
                desc.height,
                desc.depth,
                format_to_vk(desc.format),
                image_usage_to_vk(desc.usage),
                gpu_mask.0,
            )
        };
        
        if view_handle.is_null() {
            return Err("Failed to use persistent image".into());
        }
        
        let id = ResourceId(self.next_resource_id);
        self.next_resource_id += 1;
        self.resource_map.insert(id, view_handle);
        
        Ok(ImageView {
            id,
            base_mip_level: 0,
            mip_level_count: None,
            base_array_layer: 0,
            array_layer_count: None,
            aspect: ImageAspect::Color,
        })
    }
    
    fn add_task(&mut self, task: Task) -> Result<(), Box<dyn std::error::Error>> {
        // Convert attachments
        let mut attachments_ffi = Vec::new();
        let mut attachment_names = Vec::new();
        
        for attachment in &task.attachments {
            let name = CString::new(attachment.name.as_str())?;
            
            let (resource_type, resource_handle) = match &attachment.resource {
                ResourceView::Buffer(view) => {
                    let handle = self.resource_map.get(&view.id)
                        .ok_or("Unknown buffer resource")?;
                    (0, *handle) // 0 = buffer
                }
                ResourceView::Image(view) => {
                    let handle = self.resource_map.get(&view.id)
                        .ok_or("Unknown image resource")?;
                    (1, *handle) // 1 = image
                }
                ResourceView::AccelerationStructure(id) => {
                    let handle = self.resource_map.get(id)
                        .ok_or("Unknown acceleration structure resource")?;
                    (2, *handle) // 2 = blas/tlas
                }
            };
            
            attachments_ffi.push(TaskAttachmentInfoFFI {
                resource_type,
                resource_handle,
                access: access_type_to_bits(attachment.access),
                stage: pipeline_stage_to_ffi(attachment.stage),
                name: name.as_ptr(),
            });
            
            attachment_names.push(name);
        }
        
        // Create task callback wrapper
        let callback = Arc::new(task.callback);
        let callback_ptr = Box::into_raw(Box::new(callback));
        
        let task_name = CString::new(task.name.as_str())?;
        
        let info = TaskInfoFFI {
            name: task_name.as_ptr(),
            task_type: task_type_to_ffi(task.task_type),
            attachments: attachments_ffi.as_ptr(),
            attachment_count: attachments_ffi.len() as u32,
            callback: task_callback_wrapper,
            user_data: callback_ptr as *mut c_void,
            condition_mask: task.condition_mask,
            condition_value: task.condition_value,
            queue_index: queue_to_index(task.queue),
            gpu_preference: match task.gpu_preference.unwrap_or(GpuPreference::MostPowerful) {
                GpuPreference::MostPowerful => 0,
                GpuPreference::SecondMostPowerful => 1,
                GpuPreference::LeastPowerful => 2,
                GpuPreference::Specific(idx) => 3 + idx,
            },
        };
        
        let success = unsafe { rendergraph_add_task(self.handle, &info) };
        
        if !success {
            // Clean up callback
            unsafe { 
                let _ = Box::from_raw(callback_ptr);
            }
            return Err("Failed to add task".into());
        }
        
        Ok(())
    }
    
    fn set_condition(&mut self, index: u32, value: bool) {
        unsafe { rendergraph_set_condition(self.handle, index, value) };
    }
    
    fn compile(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let success = unsafe { rendergraph_compile(self.handle) };
        if !success {
            return Err("Failed to compile render graph".into());
        }
        Ok(())
    }
    
    fn execute(&mut self, gpu_index: u32) -> Result<(), Box<dyn std::error::Error>> {
        let success = unsafe { rendergraph_execute(self.handle, gpu_index) };
        if !success {
            return Err("Failed to execute render graph".into());
        }
        Ok(())
    }
    
    fn execute_all_gpus(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let success = unsafe { rendergraph_execute_on_all_gpus(self.handle) };
        if !success {
            return Err("Failed to execute render graph on all GPUs".into());
        }
        Ok(())
    }
    
    fn get_debug_info(&self) -> Option<String> {
        let size = unsafe { 
            rendergraph_get_debug_info(
                self.handle, 
                self.debug_buffer.as_ptr() as *mut u8,
                self.debug_buffer.len()
            )
        };
        
        if size > 0 {
            String::from_utf8(self.debug_buffer[..size].to_vec()).ok()
        } else {
            None
        }
    }
    
    fn gpu_count(&self) -> u32 {
        unsafe { rendergraph_get_gpu_count(self.handle) }
    }
    
    fn use_persistent_shader(
        &mut self,
        handle: &dyn Any,
        gpu_mask: GpuMask,
    ) -> Result<ResourceId, Box<dyn std::error::Error>> {
        // Shaders are handled as part of pipelines in Vulkan
        // For now, we'll return a dummy resource ID
        let id = ResourceId(self.next_resource_id);
        self.next_resource_id += 1;
        Ok(id)
    }
}

// Task callback wrapper
extern "C" fn task_callback_wrapper(user_data: *mut c_void) {
    unsafe {
        let callback_ptr = user_data as *mut Arc<TaskCallback>;
        let callback = &*callback_ptr;
        
        // Get the actual interface from FFI
        let interface_ptr = rendergraph_get_task_interface(user_data);
        if interface_ptr.is_null() {
            eprintln!("Failed to get task interface");
            return;
        }
        
        let mut interface = VulkanTaskInterface {
            encoder: (*interface_ptr).command_buffer,
            scratch_memory: Vec::new(),
            frame_index: (*interface_ptr).frame_index,
            gpu_index: (*interface_ptr).gpu_index,
            renderer: (*interface_ptr).renderer,
        };
        
        let _ = callback(&mut interface);
    }
}

#[repr(C)]
struct TaskInterfaceFFI {
    command_buffer: *mut c_void,
    scratch_memory: *mut u8,
    scratch_memory_size: usize,
    frame_index: u32,
    gpu_index: u32,
    renderer: *mut c_void,
}

pub struct VulkanTaskInterface {
    pub encoder: *mut c_void,
    pub scratch_memory: Vec<u8>,
    pub frame_index: u32,
    pub gpu_index: u32,
    pub renderer: *mut c_void,
}

impl TaskInterface for VulkanTaskInterface {
    fn encoder(&mut self) -> &mut dyn Any {
        &mut self.encoder
    }
    
    fn scratch_memory(&mut self) -> &mut [u8] {
        &mut self.scratch_memory
    }
    
    fn frame_index(&self) -> u32 {
        self.frame_index
    }
    
    fn gpu_index(&self) -> u32 {
        self.gpu_index
    }
    
    fn get_native_handle(&self, _id: ResourceId) -> Option<&dyn Any> {
        // Resource handles are managed by the render graph implementation
        None
    }
    
    fn as_any(&self) -> &dyn Any {
        self
    }
}

// Helper functions for conversions
fn buffer_usage_to_vk(usage: BufferUsage) -> u32 {
    let mut flags = 0u32;
    if usage.transfer_src { flags |= 0x00000001; } // VK_BUFFER_USAGE_TRANSFER_SRC_BIT
    if usage.transfer_dst { flags |= 0x00000002; } // VK_BUFFER_USAGE_TRANSFER_DST_BIT
    if usage.uniform { flags |= 0x00000010; } // VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT
    if usage.storage { flags |= 0x00000020; } // VK_BUFFER_USAGE_STORAGE_BUFFER_BIT
    if usage.index { flags |= 0x00000040; } // VK_BUFFER_USAGE_INDEX_BUFFER_BIT
    if usage.vertex { flags |= 0x00000080; } // VK_BUFFER_USAGE_VERTEX_BUFFER_BIT
    if usage.indirect { flags |= 0x00000100; } // VK_BUFFER_USAGE_INDIRECT_BUFFER_BIT
    if usage.device_address { flags |= 0x00020000; } // VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT
    flags
}

fn image_usage_to_vk(usage: ImageUsage) -> u32 {
    let mut flags = 0u32;
    if usage.transfer_src { flags |= 0x00000001; } // VK_IMAGE_USAGE_TRANSFER_SRC_BIT
    if usage.transfer_dst { flags |= 0x00000002; } // VK_IMAGE_USAGE_TRANSFER_DST_BIT
    if usage.sampled { flags |= 0x00000004; } // VK_IMAGE_USAGE_SAMPLED_BIT
    if usage.storage { flags |= 0x00000008; } // VK_IMAGE_USAGE_STORAGE_BIT
    if usage.color_attachment { flags |= 0x00000010; } // VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT
    if usage.depth_stencil_attachment { flags |= 0x00000020; } // VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT
    if usage.transient_attachment { flags |= 0x00000040; } // VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT
    flags
}

fn format_to_vk(format: ImageFormat) -> u32 {
    match format {
        ImageFormat::R8Unorm => 9, // VK_FORMAT_R8_UNORM
        ImageFormat::R8G8B8A8Unorm => 37, // VK_FORMAT_R8G8B8A8_UNORM
        ImageFormat::R8G8B8A8Srgb => 43, // VK_FORMAT_R8G8B8A8_SRGB
        ImageFormat::B8G8R8A8Unorm => 44, // VK_FORMAT_B8G8R8A8_UNORM
        ImageFormat::B8G8R8A8Srgb => 50, // VK_FORMAT_B8G8R8A8_SRGB
        ImageFormat::R16G16Float => 83, // VK_FORMAT_R16G16_SFLOAT
        ImageFormat::R16G16B16A16Float => 97, // VK_FORMAT_R16G16B16A16_SFLOAT
        ImageFormat::R32G32B32A32Float => 109, // VK_FORMAT_R32G32B32A32_SFLOAT
        ImageFormat::D32Float => 126, // VK_FORMAT_D32_SFLOAT
        ImageFormat::D24UnormS8Uint => 129, // VK_FORMAT_D24_UNORM_S8_UINT
        ImageFormat::D32FloatS8Uint => 130, // VK_FORMAT_D32_SFLOAT_S8_UINT
    }
}

fn access_type_to_bits(access: AccessType) -> u8 {
    let mut bits = 0u8;
    if access.concurrent { bits |= 0x01; }
    if access.read { bits |= 0x02; }
    if access.write { bits |= 0x08; }
    bits
}

fn pipeline_stage_to_ffi(stage: PipelineStage) -> i32 {
    match stage {
        PipelineStage::None => 0,
        PipelineStage::VertexInput => 1,
        PipelineStage::VertexShader => 1,
        PipelineStage::TessellationControl => 2,
        PipelineStage::TessellationEvaluation => 3,
        PipelineStage::GeometryShader => 4,
        PipelineStage::FragmentShader => 5,
        PipelineStage::TaskShader => 6,
        PipelineStage::MeshShader => 7,
        PipelineStage::ComputeShader => 8,
        PipelineStage::RayTracingShader => 9,
        PipelineStage::Transfer => 10,
        PipelineStage::Host => 11,
        PipelineStage::AccelerationStructureBuild => 12,
        PipelineStage::ColorAttachment => 13,
        PipelineStage::DepthStencilAttachment => 14,
        PipelineStage::Resolve => 15,
        PipelineStage::Present => 16,
        PipelineStage::IndirectCommand => 17,
        PipelineStage::AllGraphics => 19,
        PipelineStage::AllCommands => 20,
    }
}

fn task_type_to_ffi(task_type: TaskType) -> i32 {
    match task_type {
        TaskType::General => 0,
        TaskType::Compute => 1,
        TaskType::Raster => 2,
        TaskType::RayTracing => 3,
        TaskType::Transfer => 4,
    }
}

fn queue_to_index(queue: QueueType) -> u32 {
    match queue {
        QueueType::Main => 0,
        QueueType::Compute(index) => 1 + index.min(7), // Compute queues 1-8
        QueueType::Transfer(index) => 9 + index.min(1), // Transfer queues 9-10
    }
}