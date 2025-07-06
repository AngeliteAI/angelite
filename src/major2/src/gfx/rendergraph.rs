use std::any::Any;
use std::hash::Hash;
use std::collections::HashMap;
use std::sync::Arc;

/// GPU-agnostic render graph interface
/// This defines common concepts that can be implemented by any graphics backend

/// Resource types supported by the render graph
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ResourceType {
    Buffer,
    Image,
    AccelerationStructure,
}

/// Access patterns for resources
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AccessType {
    pub read: bool,
    pub write: bool,
    pub concurrent: bool,
}

impl AccessType {
    pub const NONE: Self = Self { read: false, write: false, concurrent: false };
    pub const READ: Self = Self { read: true, write: false, concurrent: true };
    pub const WRITE: Self = Self { read: false, write: true, concurrent: false };
    pub const READ_WRITE: Self = Self { read: true, write: true, concurrent: false };
    pub const WRITE_CONCURRENT: Self = Self { read: false, write: true, concurrent: true };
    pub const READ_WRITE_CONCURRENT: Self = Self { read: true, write: true, concurrent: true };
}

/// Pipeline stages where resources can be accessed
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PipelineStage {
    None,
    VertexInput,
    VertexShader,
    TessellationControl,
    TessellationEvaluation,
    GeometryShader,
    FragmentShader,
    TaskShader,
    MeshShader,
    ComputeShader,
    RayTracingShader,
    Transfer,
    Host,
    AccelerationStructureBuild,
    ColorAttachment,
    DepthStencilAttachment,
    Resolve,
    Present,
    IndirectCommand,
    AllGraphics,
    AllCommands,
}

/// Task types for better optimization
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaskType {
    General,
    Compute,
    Raster,
    RayTracing,
    Transfer,
}

/// Opaque resource handle - backend specific
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ResourceId(pub u64);

/// View into a buffer resource
#[derive(Debug, Clone)]
pub struct BufferView {
    pub id: ResourceId,
    pub offset: u64,
    pub size: Option<u64>, // None means whole buffer
}

/// View into an image resource
#[derive(Debug, Clone)]
pub struct ImageView {
    pub id: ResourceId,
    pub base_mip_level: u32,
    pub mip_level_count: Option<u32>,
    pub base_array_layer: u32,
    pub array_layer_count: Option<u32>,
    pub aspect: ImageAspect,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ImageAspect {
    Color,
    Depth,
    Stencil,
    DepthStencil,
}

/// Resource view that can be either buffer or image
#[derive(Debug, Clone)]
pub enum ResourceView {
    Buffer(BufferView),
    Image(ImageView),
    AccelerationStructure(ResourceId),
}

/// Task attachment information
#[derive(Debug, Clone)]
pub struct TaskAttachment {
    pub name: String,
    pub resource: ResourceView,
    pub access: AccessType,
    pub stage: PipelineStage,
}

/// Interface provided to task callbacks
pub trait TaskInterface {
    /// Get the backend-specific command encoder
    fn encoder(&mut self) -> &mut dyn Any;
    
    /// Get scratch memory for temporary allocations
    fn scratch_memory(&mut self) -> &mut [u8];
    
    /// Get the current frame index
    fn frame_index(&self) -> u32;
    
    /// Get the GPU index for multi-GPU setups
    fn gpu_index(&self) -> u32;
    
    /// Get backend-specific handle for a resource
    fn get_native_handle(&self, id: ResourceId) -> Option<&dyn Any>;
    
    /// Get self as Any for downcasting
    fn as_any(&self) -> &dyn Any;
    
    /// Dispatch compute shader (convenience method)
    fn dispatch_compute(&mut self, x: u32, y: u32, z: u32) -> Result<(), Box<dyn std::error::Error>> {
        // Default implementation - backends can override
        Ok(())
    }
}

/// Task callback type
pub type TaskCallback = Box<dyn Fn(&mut dyn TaskInterface) -> Result<(), Box<dyn std::error::Error>> + Send + Sync>;

/// Queue type for multi-queue support
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum QueueType {
    Main,
    Compute(u32),  // Index 0-7
    Transfer(u32), // Index 0-1
}

impl Default for QueueType {
    fn default() -> Self {
        Self::Main
    }
}

/// GPU preference for multi-GPU task execution
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GpuPreference {
    MostPowerful,
    SecondMostPowerful,
    LeastPowerful,
    Specific(u32), // Specific GPU index
}

/// Task definition
pub struct Task {
    pub name: String,
    pub task_type: TaskType,
    pub attachments: Vec<TaskAttachment>,
    pub callback: TaskCallback,
    /// Permutation support - task only runs if (condition_values & condition_mask) == condition_value
    pub condition_mask: u32,
    pub condition_value: u32,
    /// Queue to execute on (defaults to main queue)
    pub queue: QueueType,
    /// GPU preference for multi-GPU systems
    pub gpu_preference: Option<GpuPreference>,
}

/// Transient resource descriptors
#[derive(Debug, Clone)]
pub struct TransientBufferDesc {
    pub size: u64,
    pub usage: BufferUsage,
    pub name: String,
}

#[derive(Debug, Clone)]
pub struct TransientImageDesc {
    pub width: u32,
    pub height: u32,
    pub depth: u32,
    pub format: ImageFormat,
    pub usage: ImageUsage,
    pub mip_levels: u32,
    pub array_layers: u32,
    pub samples: u32,
    pub name: String,
}

/// Common buffer usage flags
#[derive(Debug, Clone, Copy, Default)]
pub struct BufferUsage {
    pub transfer_src: bool,
    pub transfer_dst: bool,
    pub uniform: bool,
    pub storage: bool,
    pub index: bool,
    pub vertex: bool,
    pub indirect: bool,
    pub device_address: bool,
}

/// Common image usage flags
#[derive(Debug, Clone, Copy, Default)]
pub struct ImageUsage {
    pub transfer_src: bool,
    pub transfer_dst: bool,
    pub sampled: bool,
    pub storage: bool,
    pub color_attachment: bool,
    pub depth_stencil_attachment: bool,
    pub transient_attachment: bool,
}

/// Common image formats
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ImageFormat {
    R8Unorm,
    R8G8B8A8Unorm,
    R8G8B8A8Srgb,
    B8G8R8A8Unorm,
    B8G8R8A8Srgb,
    R16G16Float,
    R16G16B16A16Float,
    R32G32B32A32Float,
    D32Float,
    D24UnormS8Uint,
    D32FloatS8Uint,
    // Add more as needed
}

/// Multi-GPU support
#[derive(Debug, Clone, Copy)]
pub struct GpuMask(pub u32);

impl GpuMask {
    pub fn single(gpu_index: u32) -> Self {
        Self(1 << gpu_index)
    }
    
    pub fn all() -> Self {
        Self(u32::MAX)
    }
    
    pub fn contains(&self, gpu_index: u32) -> bool {
        (self.0 & (1 << gpu_index)) != 0
    }
}

/// Render graph builder options
#[derive(Debug, Clone)]
pub struct RenderGraphDesc {
    pub enable_reordering: bool,
    pub enable_aliasing: bool,
    pub use_split_barriers: bool,
    pub enable_multi_queue: bool,
    pub scratch_memory_size: usize,
    pub enable_debug_labels: bool,
    pub record_debug_info: bool,
}

impl Default for RenderGraphDesc {
    fn default() -> Self {
        Self {
            enable_reordering: true,
            enable_aliasing: true,
            use_split_barriers: true,
            enable_multi_queue: true,
            scratch_memory_size: 128 * 1024, // 128KB
            enable_debug_labels: true,
            record_debug_info: false,
        }
    }
}

/// Main render graph trait - backends implement this
pub trait RenderGraph: Send + Sync {
    /// Create a transient buffer
    fn create_transient_buffer(&mut self, desc: &TransientBufferDesc) -> Result<BufferView, Box<dyn std::error::Error>>;
    
    /// Create a transient image
    fn create_transient_image(&mut self, desc: &TransientImageDesc) -> Result<ImageView, Box<dyn std::error::Error>>;
    
    /// Register a persistent buffer
    fn use_persistent_buffer(
        &mut self,
        handle: &dyn Any,
        size: u64,
        usage: BufferUsage,
        gpu_mask: GpuMask,
    ) -> Result<BufferView, Box<dyn std::error::Error>>;
    
    /// Register a persistent image  
    fn use_persistent_image(
        &mut self,
        handle: &dyn Any,
        desc: &TransientImageDesc,
        gpu_mask: GpuMask,
    ) -> Result<ImageView, Box<dyn std::error::Error>>;
    
    /// Add a task to the graph
    fn add_task(&mut self, task: Task) -> Result<(), Box<dyn std::error::Error>>;
    
    /// Set permutation condition value
    fn set_condition(&mut self, index: u32, value: bool);
    
    /// Compile the graph - analyze dependencies, insert barriers, optimize
    fn compile(&mut self) -> Result<(), Box<dyn std::error::Error>>;
    
    /// Execute the compiled graph on a specific GPU
    fn execute(&mut self, gpu_index: u32) -> Result<(), Box<dyn std::error::Error>>;
    
    /// Execute on all GPUs
    fn execute_all_gpus(&mut self) -> Result<(), Box<dyn std::error::Error>>;
    
    /// Get debug information if recording was enabled
    fn get_debug_info(&self) -> Option<String>;
    
    /// Get number of GPUs available
    fn gpu_count(&self) -> u32;
    
    /// Register a persistent shader
    fn use_persistent_shader(
        &mut self,
        handle: &dyn Any,
        gpu_mask: GpuMask,
    ) -> Result<ResourceId, Box<dyn std::error::Error>>;
}

/// Inline task builder for ergonomic API
pub struct InlineTaskBuilder<'a> {
    graph: &'a mut dyn RenderGraph,
    task: Task,
}

impl<'a> InlineTaskBuilder<'a> {
    pub fn new(graph: &'a mut dyn RenderGraph, name: impl Into<String>, task_type: TaskType) -> Self {
        Self {
            graph,
            task: Task {
                name: name.into(),
                task_type,
                attachments: Vec::new(),
                callback: Box::new(|_| Ok(())),
                condition_mask: 0,
                condition_value: 0,
                queue: QueueType::default(),
                gpu_preference: None,
            },
        }
    }
    
    pub fn reads(mut self, stage: PipelineStage, view: impl Into<ResourceView>) -> Self {
        self.task.attachments.push(TaskAttachment {
            name: format!("read_{}", self.task.attachments.len()),
            resource: view.into(),
            access: AccessType::READ,
            stage,
        });
        self
    }
    
    pub fn writes(mut self, stage: PipelineStage, view: impl Into<ResourceView>) -> Self {
        self.task.attachments.push(TaskAttachment {
            name: format!("write_{}", self.task.attachments.len()),
            resource: view.into(),
            access: AccessType::WRITE,
            stage,
        });
        self
    }
    
    pub fn reads_writes(mut self, stage: PipelineStage, view: impl Into<ResourceView>) -> Self {
        self.task.attachments.push(TaskAttachment {
            name: format!("read_write_{}", self.task.attachments.len()),
            resource: view.into(),
            access: AccessType::READ_WRITE,
            stage,
        });
        self
    }
    
    pub fn samples(mut self, stage: PipelineStage, view: ImageView) -> Self {
        self.task.attachments.push(TaskAttachment {
            name: format!("sample_{}", self.task.attachments.len()),
            resource: ResourceView::Image(view),
            access: AccessType::READ,
            stage,
        });
        self
    }
    
    pub fn condition(mut self, mask: u32, value: u32) -> Self {
        self.task.condition_mask = mask;
        self.task.condition_value = value;
        self
    }
    
    pub fn on_queue(mut self, queue: QueueType) -> Self {
        self.task.queue = queue;
        self
    }
    
    pub fn on_gpu(mut self, gpu_preference: GpuPreference) -> Self {
        self.task.gpu_preference = Some(gpu_preference);
        self
    }
    
    pub fn execute<F>(mut self, callback: F) -> Result<(), Box<dyn std::error::Error>>
    where
        F: Fn(&mut dyn TaskInterface) -> Result<(), Box<dyn std::error::Error>> + Send + Sync + 'static,
    {
        self.task.callback = Box::new(callback);
        self.graph.add_task(self.task)
    }
}

/// Extension trait for ergonomic API
pub trait RenderGraphExt: RenderGraph {
    fn compute(&mut self, name: impl Into<String>) -> InlineTaskBuilder 
    where 
        Self: Sized,
    {
        InlineTaskBuilder::new(self, name, TaskType::Compute)
    }
    
    fn raster(&mut self, name: impl Into<String>) -> InlineTaskBuilder 
    where 
        Self: Sized,
    {
        InlineTaskBuilder::new(self, name, TaskType::Raster)
    }
    
    fn transfer(&mut self, name: impl Into<String>) -> InlineTaskBuilder 
    where 
        Self: Sized,
    {
        InlineTaskBuilder::new(self, name, TaskType::Transfer)
    }
    
    fn ray_tracing(&mut self, name: impl Into<String>) -> InlineTaskBuilder 
    where 
        Self: Sized,
    {
        InlineTaskBuilder::new(self, name, TaskType::RayTracing)
    }
}

impl<T: RenderGraph + ?Sized> RenderGraphExt for T {}

/// Helper trait for converting to ResourceView
impl From<BufferView> for ResourceView {
    fn from(view: BufferView) -> Self {
        ResourceView::Buffer(view)
    }
}

impl From<ImageView> for ResourceView {
    fn from(view: ImageView) -> Self {
        ResourceView::Image(view)
    }
}

impl From<ResourceId> for ResourceView {
    fn from(id: ResourceId) -> Self {
        ResourceView::AccelerationStructure(id)
    }
}