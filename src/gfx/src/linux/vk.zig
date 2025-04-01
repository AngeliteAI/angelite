const c = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cInclude("xcb/xcb.h");
    @cInclude("vulkan/vulkan_xcb.h");
});
const std = @import("std");
const xcb = @import("xcb.zig");

pub const COPY = c.VK_LOGIC_OP_COPY;
pub const VIEWPORT = c.VK_DYNAMIC_STATE_VIEWPORT;
pub const SCISSOR = c.VK_DYNAMIC_STATE_SCISSOR;
pub const SAMPLE_COUNT_1 = c.VK_SAMPLE_COUNT_1_BIT;
pub const LayerProperties = c.VkLayerProperties;
pub const SIGNALED = c.VK_FENCE_CREATE_SIGNALED_BIT;
pub const PipelineStageFlags = c.VkPipelineStageFlags;
pub const PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
pub const OUT_OF_DATE = c.VK_ERROR_OUT_OF_DATE_KHR;

pub const StructureType = enum(c_uint) {
    AppInfo = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
    InstanceInfo = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
    DeviceQueueCreateInfo = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
    DeviceCreateInfo = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
    CommandPoolCreateInfo = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
    CommandBufferAllocateInfo = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    CommandBufferBeginInfo = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    SubmitInfo = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
    ShaderModuleCreateInfo = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    PipelineLayoutCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    SwapchainCreateInfoKHR = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    PresentInfoKHR = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
    ImageViewCreateInfo = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
    RenderingInfoKHR = c.VK_STRUCTURE_TYPE_RENDERING_INFO_KHR,
    RenderingAttachmentInfoKHR = c.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO_KHR,
    XcbSurfaceCreateInfoKHR = c.VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR,

    // Pipeline-related structure types
    GraphicsPipelineCreateInfo = c.VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
    PipelineViewportStateCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
    PipelineMultisampleStateCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
    PipelineDynamicStateCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
    PipelineShaderStageCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
    PipelineVertexInputStateCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    PipelineInputAssemblyStateCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
    PipelineRasterizationStateCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
    PipelineColorBlendStateCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
    PipelineDepthStencilStateCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,

    DependencyInfoKHR = c.VK_STRUCTURE_TYPE_DEPENDENCY_INFO_KHR,
    BufferMemoryBarrier2KHR = c.VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER_2_KHR,
    ImageMemoryBarrier2KHR = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2_KHR,
    MemoryBarrier2KHR = c.VK_STRUCTURE_TYPE_MEMORY_BARRIER_2_KHR,
    PhysicalDeviceSynchronization2FeaturesKHR = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES_KHR,

    // Descriptor-related structure types
    DescriptorSetLayoutCreateInfo = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,

    // Add these for pipeline rendering and descriptors
    PhysicalDeviceDynamicRenderingFeatures = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES_KHR,
    PhysicalDeviceDescriptorIndexingFeatures = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES_EXT,

    // Synchronization-related structure types
    FenceCreateInfo = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
    SemaphoreCreateInfo = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    PipelineRenderingCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
};

pub const NULL = c.VK_NULL_HANDLE;

pub fn sTy(ty: StructureType) c.VkStructureType {
    // Using a direct cast since we know StructureType uses c_uint as its tag type
    return @as(c.VkStructureType, @intFromEnum(ty));
}

pub const API_VERSION_1_0 = c.VK_API_VERSION_1_0;
pub const API_VERSION_1_3 = c.VK_API_VERSION_1_3;
pub const MAKE_VERSION = c.VK_MAKE_VERSION;

pub const AppInfo = c.VkApplicationInfo;
pub const InstanceInfo = c.VkInstanceCreateInfo;
pub const DeviceQueueCreateInfo = c.VkDeviceQueueCreateInfo;
pub const DeviceCreateInfo = c.VkDeviceCreateInfo;

pub const Result = c.VkResult;
pub const Instance = c.VkInstance;
pub const PhysicalDevice = c.VkPhysicalDevice;
pub const PhysicalDeviceProperties = c.VkPhysicalDeviceProperties;
pub const PhysicalDeviceMemoryProperties = c.VkPhysicalDeviceMemoryProperties;
pub const Device = c.VkDevice;
pub const Pipeline = c.VkPipeline;
pub const PipelineLayout = c.VkPipelineLayout;
pub const ShaderModule = c.VkShaderModule;

pub const MEMORY_HEAP_DEVICE_LOCAL_BIT = c.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT;
pub const SUCCESS = c.VK_SUCCESS;

pub const createInstance = c.vkCreateInstance;
pub const enumeratePhysicalDevices = c.vkEnumeratePhysicalDevices;
pub const getPhysicalDeviceProperties = c.vkGetPhysicalDeviceProperties;
pub const getPhysicalDeviceMemoryProperties = c.vkGetPhysicalDeviceMemoryProperties;
pub const createDevice = c.vkCreateDevice;
pub const destroyDevice = c.vkDestroyDevice;
pub const destroyInstance = c.vkDestroyInstance;
pub const getSwapchainImages = c.vkGetSwapchainImagesKHR;
pub const createImageView = c.vkCreateImageView;
pub const destroyImageView = c.vkDestroyImageView;
pub const enumerateInstanceExtensionProperties = c.vkEnumerateInstanceExtensionProperties;
pub const queuePresent = c.vkQueuePresentKHR;
pub const resetFences = c.vkResetFences;
pub const waitForFences = c.vkWaitForFences;
pub const createSemaphore = c.vkCreateSemaphore;
pub const destroySemaphore = c.vkDestroySemaphore;
pub const createFence = c.vkCreateFence;
pub const destroyFence = c.vkDestroyFence;
pub const enumerateDeviceExtensionProperties = c.vkEnumerateDeviceExtensionProperties;
pub const SemaphoreCreateInfo = c.VkSemaphoreCreateInfo;
pub const FenceCreateInfo = c.VkFenceCreateInfo;
pub const ExtensionProperties = c.VkExtensionProperties;

pub const XcbSurfaceCreateInfo = c.VkXcbSurfaceCreateInfoKHR;
pub const Surface = c.VkSurfaceKHR;

// Vulkan surface-related constants
pub const KHR_SURFACE_EXTENSION_NAME = c.VK_KHR_SURFACE_EXTENSION_NAME;
pub const KHR_XCB_SURFACE_EXTENSION_NAME = c.VK_KHR_XCB_SURFACE_EXTENSION_NAME;

// Vulkan surface-related functions
pub const createXcbSurfaceKHR = c.vkCreateXcbSurfaceKHR;
pub const destroySurfaceKHR = c.vkDestroySurfaceKHR;
pub const getPhysicalDeviceSurfaceSupportKHR = c.vkGetPhysicalDeviceSurfaceSupportKHR;
pub const getPhysicalDeviceSurfaceCapabilitiesKHR = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR;
pub const getPhysicalDeviceSurfaceFormatsKHR = c.vkGetPhysicalDeviceSurfaceFormatsKHR;
pub const getPhysicalDeviceSurfacePresentModesKHR = c.vkGetPhysicalDeviceSurfacePresentModesKHR;
pub const enumerateInstanceLayerProperties = c.vkEnumerateInstanceLayerProperties;

// Function to create an XCB surface
pub fn createXcbSurface(instance: Instance, connection: *xcb.Connection, window: xcb.Window) ?Surface {
    const create_info = XcbSurfaceCreateInfo{
        .sType = sTy(.InstanceInfo),
        .pNext = null,
        .connection = connection,
        .window = window,
    };

    var surface: Surface = undefined;
    const result = createXcbSurfaceKHR(instance, &create_info, null, &surface);
    if (result != SUCCESS) {
        return null;
    }
    return surface;
}

// ...existing code...

// Swapchain-related constants
pub const KHR_SWAPCHAIN_EXTENSION_NAME = c.VK_KHR_SWAPCHAIN_EXTENSION_NAME;

// Swapchain-related structures
pub const SwapchainCreateInfo = c.VkSwapchainCreateInfoKHR;
pub const Swapchain = c.VkSwapchainKHR;
pub const PresentMode = c.VkPresentModeKHR;
pub const SurfaceFormat = c.VkSurfaceFormatKHR;
pub const Extent2D = c.VkExtent2D;

// Swapchain-related functions
pub const createSwapchainKHR = c.vkCreateSwapchainKHR;
pub const destroySwapchainKHR = c.vkDestroySwapchainKHR;
pub const getSwapchainImagesKHR = c.vkGetSwapchainImagesKHR;
pub const acquireNextImageKHR = c.vkAcquireNextImageKHR;
pub const queuePresentKHR = c.vkQueuePresentKHR;

// Helper function to create a swapchain
pub fn createSwapchain(
    device: Device,
    surface: Surface,
    surface_format: SurfaceFormat,
    extent: Extent2D,
    present_mode: PresentMode,
    old_swapchain: ?Swapchain,
) ?Swapchain {
    const create_info = SwapchainCreateInfo{
        .sType = sTy(.InstanceInfo),
        .pNext = null,
        .surface = surface,
        .minImageCount = 2, // Double buffering
        .imageFormat = surface_format.format,
        .imageColorSpace = surface_format.colorSpace,
        .imageExtent = extent,
        .imageArrayLayers = 1,
        .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = 0,
        .pQueueFamilyIndices = null,
        .preTransform = c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR,
        .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        .presentMode = present_mode,
        .clipped = true,
        .oldSwapchain = old_swapchain orelse null,
    };

    var swapchain: Swapchain = undefined;
    const result = createSwapchainKHR(device, &create_info, null, &swapchain);
    if (result != SUCCESS) {
        return null;
    }
    return swapchain;
}

// ...existing code...

// Command pool-related constants
pub const CommandPoolCreateInfo = c.VkCommandPoolCreateInfo;
pub const CommandPool = c.VkCommandPool;
pub const CommandBufferAllocateInfo = c.VkCommandBufferAllocateInfo;
pub const CommandBuffer = c.VkCommandBuffer;
pub const CommandBufferLevel = c.VkCommandBufferLevel;

// Command pool-related functions

// Command pool creation function
pub fn createCommandPool(
    device: Device,
    queue_family_index: u32,
) ?CommandPool {
    const create_info = CommandPoolCreateInfo{
        .sType = sTy(.InstanceInfo),
        .pNext = null,
        .flags = COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT, // Adjust flags as needed
        .queueFamilyIndex = queue_family_index,
    };

    var command_pool: CommandPool = undefined;
    const result = c.vkCreateCommandPool(device, &create_info, null, &command_pool);
    if (result != SUCCESS) {
        return null;
    }
    return command_pool;
}

// Command buffer allocation function
pub fn allocateCommandBuffers(
    device: Device,
    command_pool: CommandPool,
    level: CommandBufferLevel,
    count: u32,
) ?[]CommandBuffer {
    const allocate_info = CommandBufferAllocateInfo{
        .sType = sTy(.InstanceInfo),
        .pNext = null,
        .commandPool = command_pool,
        .level = level,
        .commandBufferCount = count,
    };

    const command_buffers = std.heap.page_allocator.alloc(CommandBuffer, count) catch {
        return null;
    };

    const result = c.vkAllocateCommandBuffers(device, &allocate_info, command_buffers.ptr);
    if (result != SUCCESS) {
        std.heap.page_allocator.free(command_buffers);
        return null;
    }
    return command_buffers;
}

// Command buffer freeing function
pub fn freeCommandBuffers(
    device: Device,
    command_pool: CommandPool,
    command_buffers: []CommandBuffer,
) void {
    c.vkFreeCommandBuffers(device, command_pool, @intCast(command_buffers.len), command_buffers.ptr);
    std.heap.page_allocator.free(command_buffers);
}

// Command pool destruction function
pub fn destroyCommandPool(
    device: Device,
    command_pool: CommandPool,
) void {
    c.vkDestroyCommandPool(device, command_pool, null);
}

// Queue-related structures
pub const Queue = c.VkQueue;
pub const SubmitInfo = c.VkSubmitInfo;
pub const PresentInfoKHR = c.VkPresentInfoKHR;
pub const Fence = c.VkFence;
pub const Semaphore = c.VkSemaphore;

// Queue-related constants
pub const QUEUE_GRAPHICS_BIT = c.VK_QUEUE_GRAPHICS_BIT;
pub const QUEUE_COMPUTE_BIT = c.VK_QUEUE_COMPUTE_BIT;
pub const QUEUE_TRANSFER_BIT = c.VK_QUEUE_TRANSFER_BIT;
pub const QUEUE_SPARSE_BINDING_BIT = c.VK_QUEUE_SPARSE_BINDING_BIT;

pub const PipelineDepthStencilStateCreateInfo = c.VkPipelineDepthStencilStateCreateInfo;
// Add these constants to your vk.zig file
pub const LESS_OR_EQUAL = c.VK_COMPARE_OP_LESS_OR_EQUAL;
pub const KEEP = c.VK_STENCIL_OP_KEEP;
pub const REPLACE = c.VK_STENCIL_OP_REPLACE;
pub const ZERO = c.VK_STENCIL_OP_ZERO;
pub const INCREMENT_AND_CLAMP = c.VK_STENCIL_OP_INCREMENT_AND_CLAMP;
pub const DECREMENT_AND_CLAMP = c.VK_STENCIL_OP_DECREMENT_AND_CLAMP;
pub const INVERT = c.VK_STENCIL_OP_INVERT;
pub const INCREMENT_AND_WRAP = c.VK_STENCIL_OP_INCREMENT_AND_WRAP;
pub const ALWAYS = c.VK_COMPARE_OP_ALWAYS;
pub const NEVER = c.VK_COMPARE_OP_NEVER;

pub const SRC_COLOR = c.VK_SRC_COLOR;
pub const ONE_MINUS_SRC_COLOR = c.VK_ONE_MINUS_SRC_COLOR;
pub const ADD = c.VK_BLEND_OP_ADD;
pub const SUBTRACT = c.VK_BLEND_OP_SUBTRACT;
pub const REVERSE_SUBTRACT = c.VK_BLEND_OP_REVERSE_SUBTRACT;
pub const MIN = c.VK_BLEND_OP_MIN;
pub const MAX = c.VK_BLEND_OP_MAX;
pub const DST_COLOR = c.VK_BLEND_OP_DST_COLOR;
pub const ONE_MINUS_DST_COLOR = c.VK_BLEND_OP_ONE_MINUS_DST_COLOR;

// Physical device types
pub const PHYSICAL_DEVICE_TYPE_OTHER = c.VK_PHYSICAL_DEVICE_TYPE_OTHER;
pub const PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU = c.VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU;
pub const PHYSICAL_DEVICE_TYPE_DISCRETE_GPU = c.VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU;
pub const PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU = c.VK_PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU;
pub const PHYSICAL_DEVICE_TYPE_CPU = c.VK_PHYSICAL_DEVICE_TYPE_CPU;

// Queue-related functions
pub const getDeviceQueue = c.vkGetDeviceQueue;
pub const queueSubmit = c.vkQueueSubmit;
pub const queueWaitIdle = c.vkQueueWaitIdle;
pub const deviceWaitIdle = c.vkDeviceWaitIdle;

// Helper function to get a device queue
pub fn getQueue(device: Device, queue_family_index: u32, queue_index: u32) Queue {
    var queue: Queue = undefined;
    getDeviceQueue(device, queue_family_index, queue_index, &queue);
    return queue;
}

// Helper function to submit command buffers to a queue
pub fn submitToQueue(
    queue: Queue,
    submit_count: u32,
    submit_info: [*]const SubmitInfo,
    fence: Fence,
) !void {
    const result = queueSubmit(queue, submit_count, submit_info, fence);
    if (result != SUCCESS) {
        return error.QueueSubmitFailed;
    }
}

// Helper function to wait for a queue to finish
pub fn waitForQueue(queue: Queue) !void {
    const result = queueWaitIdle(queue);
    if (result != SUCCESS) {
        return error.QueueWaitFailed;
    }
}

// Helper function for presenting to a queue
pub fn presentToQueue(queue: Queue, present_info: *const PresentInfoKHR) !void {
    const result = queuePresentKHR(queue, present_info);
    if (result != SUCCESS) {
        return error.QueuePresentFailed;
    }
}

pub const XcbSurfaceCreateInfoKHR = c.VkXcbSurfaceCreateInfoKHR;

// Add these functions to your vk.zig file

// Version helper functions
pub fn API_VERSION_MAJOR(version: u32) u32 {
    return (version >> 22);
}

pub fn API_VERSION_MINOR(version: u32) u32 {
    return ((version >> 12) & 0x3ff);
}

pub fn API_VERSION_PATCH(version: u32) u32 {
    return (version & 0xfff);
}

// Add these to your vk.zig file

// Boolean values
pub const TRUE = c.VK_TRUE;
pub const FALSE = c.VK_FALSE;

// Extension names
pub const KHR_DYNAMIC_RENDERING_EXTENSION_NAME = c.VK_KHR_DYNAMIC_RENDERING_EXTENSION_NAME;
pub const KHR_PUSH_DESCRIPTOR_EXTENSION_NAME = c.VK_KHR_PUSH_DESCRIPTOR_EXTENSION_NAME;
pub const EXT_DESCRIPTOR_INDEXING_EXTENSION_NAME = c.VK_EXT_DESCRIPTOR_INDEXING_EXTENSION_NAME;

// Structure types for StructureType enum
pub const PhysicalDeviceDynamicRenderingFeatures = c.VkPhysicalDeviceDynamicRenderingFeaturesKHR;
pub const PhysicalDeviceDescriptorIndexingFeatures = c.VkPhysicalDeviceDescriptorIndexingFeaturesEXT;

// Queue family properties
pub const QueueFamilyProperties = c.VkQueueFamilyProperties;
pub const getPhysicalDeviceQueueFamilyProperties = c.vkGetPhysicalDeviceQueueFamilyProperties;

// Surface support function (capital G version is used in render.zig)
pub const GetPhysicalDeviceSurfaceSupportKHR = c.vkGetPhysicalDeviceSurfaceSupportKHR;

// ...existing code...

// Surface-related structures
pub const SurfaceCapabilitiesKHR = c.VkSurfaceCapabilitiesKHR;
pub const SurfaceFormatKHR = c.VkSurfaceFormatKHR;
pub const PresentModeKHR = c.VkPresentModeKHR;

// Surface-related constants
pub const COLOR_SPACE_SRGB_NONLINEAR_KHR = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
pub const PRESENT_MODE_FIFO_KHR = c.VK_PRESENT_MODE_FIFO_KHR;
pub const PRESENT_MODE_MAILBOX_KHR = c.VK_PRESENT_MODE_MAILBOX_KHR;
pub const PRESENT_MODE_IMMEDIATE_KHR = c.VK_PRESENT_MODE_IMMEDIATE_KHR;
pub const COMPOSITE_ALPHA_OPAQUE_BIT_KHR = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;

// Image-related constants
pub const FORMAT_B8G8R8A8_SRGB = c.VK_FORMAT_B8G8R8A8_SRGB;
pub const IMAGE_USAGE_COLOR_ATTACHMENT_BIT = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
pub const SHARING_MODE_EXCLUSIVE = c.VK_SHARING_MODE_EXCLUSIVE;

// Surface transformation constants
pub const SURFACE_TRANSFORM_IDENTITY_BIT_KHR = c.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;

// Surface functions
pub const GetPhysicalDeviceSurfaceCapabilitiesKHR = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR;
pub const GetPhysicalDeviceSurfaceFormatsKHR = c.vkGetPhysicalDeviceSurfaceFormatsKHR;
pub const GetPhysicalDeviceSurfacePresentModesKHR = c.vkGetPhysicalDeviceSurfacePresentModesKHR;
pub const CreateSwapchainKHR = c.vkCreateSwapchainKHR;

// Image/view-related types
pub const Image = c.VkImage;
pub const ImageView = c.VkImageView;
pub const ImageViewCreateInfo = c.VkImageViewCreateInfo;
pub const SwapchainCreateInfoKHR = c.VkSwapchainCreateInfoKHR;

// Dynamic rendering types and constants
pub const RenderingAttachmentInfoKHR = c.VkRenderingAttachmentInfoKHR;
pub const RenderingInfoKHR = c.VkRenderingInfoKHR;
pub const ATTACHMENT_LOAD_OP_CLEAR = c.VK_ATTACHMENT_LOAD_OP_CLEAR;
pub const ATTACHMENT_STORE_OP_STORE = c.VK_ATTACHMENT_STORE_OP_STORE;
pub const IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
pub const PIPELINE_BIND_POINT_GRAPHICS = c.VK_PIPELINE_BIND_POINT_GRAPHICS;

// Command buffer functions for dynamic rendering
pub const CmdBindPipeline = c.vkCmdBindPipeline;
pub const CmdDraw = c.vkCmdDraw;
pub const CmdSetScissor = c.vkCmdSetScissor;
pub const CmdSetViewport = c.vkCmdSetViewport;
pub const BeginCommandBuffer = c.vkBeginCommandBuffer;
pub const EndCommandBuffer = c.vkEndCommandBuffer;
pub const CreateImageView = c.vkCreateImageView;
pub const AcquireNextImageKHR = c.vkAcquireNextImageKHR;

// Command buffer and synchronization types
pub const CommandBufferBeginInfo = c.VkCommandBufferBeginInfo;
pub const COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
pub const IMAGE_ASPECT_COLOR_BIT = c.VK_IMAGE_ASPECT_COLOR_BIT;
pub const COMPONENT_SWIZZLE_IDENTITY = c.VK_COMPONENT_SWIZZLE_IDENTITY;
pub const IMAGE_VIEW_TYPE_2D = c.VK_IMAGE_VIEW_TYPE_2D;

pub const COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;

pub const COMMAND_BUFFER_LEVEL_PRIMARY = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY;

pub const RESOLVE_MODE_NONE_KHR = c.VK_RESOLVE_MODE_NONE_KHR;

pub const RENDER_PASS_LOAD_OP_CLEAR = c.VK_ATTACHMENT_LOAD_OP_CLEAR;
pub const RENDER_PASS_STORE_OP_STORE = c.VK_ATTACHMENT_STORE_OP_STORE;
pub const ClearValue = c.VkClearValue;
pub const ClearColorValue = c.VkClearColorValue;

pub const Rect2D = c.VkRect2D;
pub const Offset2D = c.VkOffset2D;
pub const Format = enum(c_uint) {
    // Standard formats
    Undefined = c.VK_FORMAT_UNDEFINED,

    // 8-bit formats
    R8Unorm = c.VK_FORMAT_R8_UNORM,
    R8Snorm = c.VK_FORMAT_R8_SNORM,
    R8Uint = c.VK_FORMAT_R8_UINT,
    R8Sint = c.VK_FORMAT_R8_SINT,
    R8G8Unorm = c.VK_FORMAT_R8G8_UNORM,
    R8G8Snorm = c.VK_FORMAT_R8G8_SNORM,
    R8G8Uint = c.VK_FORMAT_R8G8_UINT,
    R8G8Sint = c.VK_FORMAT_R8G8_SINT,
    R8G8B8Unorm = c.VK_FORMAT_R8G8B8_UNORM,
    R8G8B8Snorm = c.VK_FORMAT_R8G8B8_SNORM,
    R8G8B8Uint = c.VK_FORMAT_R8G8B8_UINT,
    R8G8B8Sint = c.VK_FORMAT_R8G8B8_SINT,
    R8G8B8A8Unorm = c.VK_FORMAT_R8G8B8A8_UNORM,
    R8G8B8A8Snorm = c.VK_FORMAT_R8G8B8A8_SNORM,
    R8G8B8A8Uint = c.VK_FORMAT_R8G8B8A8_UINT,
    R8G8B8A8Sint = c.VK_FORMAT_R8G8B8A8_SINT,
    R8G8B8A8Srgb = c.VK_FORMAT_R8G8B8A8_SRGB,
    B8G8R8A8Unorm = c.VK_FORMAT_B8G8R8A8_UNORM,
    B8G8R8A8Srgb = c.VK_FORMAT_B8G8R8A8_SRGB,

    // 16-bit formats
    R16Unorm = c.VK_FORMAT_R16_UNORM,
    R16Snorm = c.VK_FORMAT_R16_SNORM,
    R16Uint = c.VK_FORMAT_R16_UINT,
    R16Sint = c.VK_FORMAT_R16_SINT,
    R16Sfloat = c.VK_FORMAT_R16_SFLOAT,
    R16G16Unorm = c.VK_FORMAT_R16G16_UNORM,
    R16G16Snorm = c.VK_FORMAT_R16G16_SNORM,
    R16G16Uint = c.VK_FORMAT_R16G16_UINT,
    R16G16Sint = c.VK_FORMAT_R16G16_SINT,
    R16G16Sfloat = c.VK_FORMAT_R16G16_SFLOAT,
    R16G16B16Unorm = c.VK_FORMAT_R16G16B16_UNORM,
    R16G16B16Snorm = c.VK_FORMAT_R16G16B16_SNORM,
    R16G16B16Uint = c.VK_FORMAT_R16G16B16_UINT,
    R16G16B16Sint = c.VK_FORMAT_R16G16B16_SINT,
    R16G16B16Sfloat = c.VK_FORMAT_R16G16B16_SFLOAT,
    R16G16B16A16Unorm = c.VK_FORMAT_R16G16B16A16_UNORM,
    R16G16B16A16Snorm = c.VK_FORMAT_R16G16B16A16_SNORM,
    R16G16B16A16Uint = c.VK_FORMAT_R16G16B16A16_UINT,
    R16G16B16A16Sint = c.VK_FORMAT_R16G16B16A16_SINT,
    R16G16B16A16Sfloat = c.VK_FORMAT_R16G16B16A16_SFLOAT,

    // 32-bit formats
    R32Uint = c.VK_FORMAT_R32_UINT,
    R32Sint = c.VK_FORMAT_R32_SINT,
    R32Sfloat = c.VK_FORMAT_R32_SFLOAT,
    R32G32Uint = c.VK_FORMAT_R32G32_UINT,
    R32G32Sint = c.VK_FORMAT_R32G32_SINT,
    R32G32Sfloat = c.VK_FORMAT_R32G32_SFLOAT,
    R32G32B32Uint = c.VK_FORMAT_R32G32B32_UINT,
    R32G32B32Sint = c.VK_FORMAT_R32G32B32_SINT,
    R32G32B32Sfloat = c.VK_FORMAT_R32G32B32_SFLOAT,
    R32G32B32A32Uint = c.VK_FORMAT_R32G32B32A32_UINT,
    R32G32B32A32Sint = c.VK_FORMAT_R32G32B32A32_SINT,
    R32G32B32A32Sfloat = c.VK_FORMAT_R32G32B32A32_SFLOAT,
};

pub const Viewport = c.VkViewport;
pub const FILL = c.VK_POLYGON_MODE_FILL;

// Function pointer types
pub var cmdBeginRenderingKHR: *const fn (CommandBuffer, *const RenderingInfoKHR) callconv(.C) void = undefined;
pub var cmdEndRenderingKHR: *const fn (CommandBuffer) callconv(.C) void = undefined;

pub fn loadDeviceExtensionFunctions(device: Device) void {
    // Function to load a device function pointer
    const loadDeviceProc = struct {
        fn load(dev: Device, name: [*:0]const u8) ?*const anyopaque {
            return c.vkGetDeviceProcAddr(dev, name);
        }
    }.load;

    // Load dynamic rendering functions
    if (@as(?*const anyopaque, loadDeviceProc(device, "vkCmdBeginRenderingKHR"))) |proc_addr| {
        cmdBeginRenderingKHR = @ptrCast(proc_addr);
        std.debug.print("Successfully loaded vkCmdBeginRenderingKHR\n", .{});
    } else {
        std.debug.print("Failed to load vkCmdBeginRenderingKHR\n", .{});
    }

    if (@as(?*const anyopaque, loadDeviceProc(device, "vkCmdEndRenderingKHR"))) |proc_addr| {
        cmdEndRenderingKHR = @ptrCast(proc_addr);
        std.debug.print("Successfully loaded vkCmdEndRenderingKHR\n", .{});
    } else {
        std.debug.print("Failed to load vkCmdEndRenderingKHR\n", .{});
    }

    if (@as(?*const anyopaque, loadDeviceProc(device, "vkCmdPipelineBarrier2KHR"))) |proc_addr| {
        cmdPipelineBarrier2KHR = @ptrCast(proc_addr);
        std.debug.print("Successfully loaded vkCmdPipelineBarrier2KHR\n", .{});
    } else {
        std.debug.print("Failed to load vkCmdPipelineBarrier2KHR\n", .{});
    }
}

pub const DescriptorSetLayout = c.VkDescriptorSetLayout;
pub const DescriptorSetLayoutBinding = c.VkDescriptorSetLayoutBinding;
pub const DescriptorSetLayoutCreateInfo = c.VkDescriptorSetLayoutCreateInfo;
pub const DescriptorSetLayoutBindingFlagsCreateInfo = c.VkDescriptorSetLayoutBindingFlagsCreateInfo;
pub const DescriptorSetLayoutBindingFlags = c.VkDescriptorSetLayoutBindingFlagsCreateInfo;
pub const VertexInputBindingDescription = c.VkVertexInputBindingDescription;
pub const VertexInputAttributeDescription = c.VkVertexInputAttributeDescription;
pub const PipelineVertexInputStateCreateInfo = c.VkPipelineVertexInputStateCreateInfo;
pub const PipelineInputAssemblyStateCreateInfo = c.VkPipelineInputAssemblyStateCreateInfo;
pub const PipelineRasterizationStateCreateInfo = c.VkPipelineRasterizationStateCreateInfo;
pub const PrimitiveTopology = c.VkPrimitiveTopology;
pub const CullModeFlags = c.VkCullModeFlags;
pub const FrontFace = c.VkFrontFace;
pub const TRIANGLE_LIST = c.VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
pub const CULL_MODE_BACK = c.VK_CULL_MODE_BACK_BIT;
pub const CLOCKWISE = c.VK_FRONT_FACE_CLOCKWISE;
pub const PipelineColorBlendStateCreateInfo = c.VkPipelineColorBlendStateCreateInfo;
pub const ShaderModuleCreateInfo = c.VkShaderModuleCreateInfo;

pub const createShaderModule = c.vkCreateShaderModule;
pub const PipelineLayoutCreateInfo = c.VkPipelineLayoutCreateInfo;
pub const PushConstantRange = c.VkPushConstantRange;

pub const SHADER_STAGE_VERTEX = c.VK_SHADER_STAGE_VERTEX_BIT;
pub const SHADER_STAGE_FRAGMENT = c.VK_SHADER_STAGE_FRAGMENT_BIT;
pub const SHADER_STAGE_COMPUTE = c.VK_SHADER_STAGE_COMPUTE_BIT;

// ...existing code...

// Add missing pipeline-related types
pub const PipelineCache = c.VkPipelineCache;
pub const GraphicsPipelineCreateInfo = c.VkGraphicsPipelineCreateInfo;
pub const PipelineViewportStateCreateInfo = c.VkPipelineViewportStateCreateInfo;
pub const PipelineMultisampleStateCreateInfo = c.VkPipelineMultisampleStateCreateInfo;
pub const PipelineColorBlendAttachmentState = c.VkPipelineColorBlendAttachmentState;
pub const PipelineDynamicStateCreateInfo = c.VkPipelineDynamicStateCreateInfo;
pub const PipelineShaderStageCreateInfo = c.VkPipelineShaderStageCreateInfo;
pub const SpecializationInfo = c.VkSpecializationInfo;
pub const DynamicState = c.VkDynamicState;

// Add missing constants for dynamic state
pub const DYNAMIC_STATE_VIEWPORT = c.VK_DYNAMIC_STATE_VIEWPORT;
pub const DYNAMIC_STATE_SCISSOR = c.VK_DYNAMIC_STATE_SCISSOR;

// Add missing functions for pipeline creation
pub const createGraphicsPipelines = c.vkCreateGraphicsPipelines;
pub const createPipelineLayout = c.vkCreatePipelineLayout;
pub const createDescriptorSetLayout = c.vkCreateDescriptorSetLayout;

// Add missing functions for shader module
pub const destroyShaderModule = c.vkDestroyShaderModule;

// Add missing functions for pipeline layout management
pub const destroyPipelineLayout = c.vkDestroyPipelineLayout;
pub const destroyPipeline = c.vkDestroyPipeline;
pub const destroyDescriptorSetLayout = c.vkDestroyDescriptorSetLayout;

// Add missing blend constants and flags
pub const SRC_ALPHA = c.VK_BLEND_FACTOR_SRC_ALPHA;
pub const ONE_MINUS_SRC_ALPHA = c.VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA;
pub const ONE = c.VK_BLEND_FACTOR_ONE;
pub const R = c.VK_COLOR_COMPONENT_R_BIT;
pub const G = c.VK_COLOR_COMPONENT_G_BIT;
pub const B = c.VK_COLOR_COMPONENT_B_BIT;
pub const A = c.VK_COLOR_COMPONENT_A_BIT;

pub const PipelineRenderingCreateInfo = c.VkPipelineRenderingCreateInfo;

pub const KHR_SYNCHRONIZATION_2_EXTENSION_NAME = c.VK_KHR_SYNCHRONIZATION_2_EXTENSION_NAME;

// Add Synchronization2 structures
pub const DependencyInfoKHR = c.VkDependencyInfoKHR;
pub const BufferMemoryBarrier2KHR = c.VkBufferMemoryBarrier2KHR;
pub const ImageMemoryBarrier2KHR = c.VkImageMemoryBarrier2KHR;
pub const MemoryBarrier2KHR = c.VkMemoryBarrier2KHR;
pub const AccessFlags2KHR = c.VkAccessFlags2KHR;
pub const PipelineStageFlags2KHR = c.VkPipelineStageFlags2KHR;

// Add Synchronization2 constants
pub const PIPELINE_STAGE_2_NONE_KHR = c.VK_PIPELINE_STAGE_2_NONE_KHR;
pub const PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT_KHR = c.VK_PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT_KHR;
pub const PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR = c.VK_PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR;
pub const PIPELINE_STAGE_2_TOP_OF_PIPE_BIT_KHR = c.VK_PIPELINE_STAGE_2_TOP_OF_PIPE_BIT_KHR;
pub const PIPELINE_STAGE_2_ALL_COMMANDS_BIT_KHR = c.VK_PIPELINE_STAGE_2_ALL_COMMANDS_BIT_KHR;

// Add AccessFlags2 constants
pub const ACCESS_2_NONE = c.VK_ACCESS_2_NONE;
pub const ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT_KHR = c.VK_ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT_KHR;
pub const ACCESS_2_COLOR_ATTACHMENT_READ_BIT_KHR = c.VK_ACCESS_2_COLOR_ATTACHMENT_READ_BIT_KHR;
pub const ACCESS_2_MEMORY_READ_BIT = c.VK_ACCESS_2_MEMORY_READ_BIT;
pub const ACCESS_2_MEMORY_WRITE_BIT = c.VK_ACCESS_2_MEMORY_WRITE_BIT;

// Add Synchronization2 function pointer declarations
pub var cmdPipelineBarrier2KHR: *const fn (CommandBuffer, *const DependencyInfoKHR) callconv(.C) void = undefined;

pub const BufferView = c.VkBufferView;
pub const Buffer = c.VkBuffer;
pub const AccessFlags = c.VkAccessFlags;
pub const ImageLayout = c.VkImageLayout;
pub const PIPELINE_STAGE_NONE = c.VK_PIPELINE_STAGE_NONE;
pub const IMAGE_LAYOUT_UNDEFINED = c.VK_IMAGE_LAYOUT_UNDEFINED;
pub const QUEUE_FAMILY_IGNORED= c.VK_QUEUE_FAMILY_IGNORED;
pub const ACCESS_COLOR_ATTACHMENT_WRITE = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
pub const PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
pub const REMAINING_ARRAY_LAYERS = c.VK_REMAINING_ARRAY_LAYERS;
pub const REMAINING_MIP_LEVELS = c.VK_REMAINING_MIP_LEVELS;
pub const WHOLE_SIZE = c.VK_WHOLE_SIZE;