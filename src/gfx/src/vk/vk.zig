const std = @import("std");

const c = @cImport({
    // Platform-specific definitions
    if (@import("builtin").os.tag == .windows) {
        // Define Windows types needed by Vulkan
        @cDefine("WINAPI", "__stdcall");
        @cDefine("APIENTRY", "__stdcall");
        @cDefine("CALLBACK", "__stdcall");

        // Basic Windows types needed by vulkan_win32.h
        @cDefine("HANDLE", "void*");
        @cDefine("HINSTANCE", "HANDLE");
        @cDefine("HWND", "HANDLE");
        @cDefine("HMONITOR", "HANDLE");
        @cDefine("DWORD", "unsigned long");
        @cDefine("BOOL", "int");
        @cDefine("LPCWSTR", "const wchar_t*");
        @cDefine("LPVOID", "void*");
        @cDefine("LPCVOID", "const void*");
        @cDefine("UINT", "unsigned int");
        @cDefine("LUID", "struct { DWORD LowPart; LONG HighPart; }");
        @cDefine("SECURITY_ATTRIBUTES", "struct { DWORD nLength; LPVOID lpSecurityDescriptor; BOOL bInheritHandle; }");
        @cDefine("LONG", "long");

        // Include Vulkan headers for Windows
        @cInclude("vulkan/vulkan.h");
        @cInclude("vulkan/vulkan_win32.h");
    } else {
        // Include Vulkan headers for XCB
        @cInclude("vulkan/vulkan.h");
        //Include xcb
        @cInclude("xcb/xcb.h");
        @cInclude("vulkan/vulkan_xcb.h");

        // Define XCB types needed by Vulkan
        @cDefine("xcb_connection_t", "struct xcb_connection_t");
        @cDefine("xcb_window_t", "uint32_t");
        @cDefine("xcb_visualid_t", "uint32_t");
    }
});

// Platform-specific constants and functions

pub const PlatformSpecificInfo = union(enum) {
    PlatformWindows: struct {
        hinstance: ?*anyopaque,
        hwnd: ?*anyopaque,
    },
    PlatformXcb: struct {
        connection: ?*anyopaque,
        window: ?u32,
    },
};
pub const SurfaceCreateInfo = blk: {
    if (@import("builtin").os.tag == .windows) {
        break :blk c.VkWin32SurfaceCreateInfoKHR;
    } else {
        break :blk c.VkXcbSurfaceCreateInfoKHR;
    }
};
pub const PhysicalDeviceSynchronization2Features = c.VkPhysicalDeviceSynchronization2Features;
pub const createVkSurface = blk: {
    if (@import("builtin").os.tag == .windows) {
        break :blk c.vkCreateWin32SurfaceKHR;
    } else {
        break :blk c.vkCreateXcbSurfaceKHR;
    }
};

pub const GENERIC_SURFACE_EXTENSION_NAME = "VK_KHR_surface";
pub const ImageAspectFlags = c.VkImageAspectFlags;

pub const PLATFORM_SURFACE_EXTENSION_NAME = blk: {
    if (@import("builtin").os.tag == .windows) {
        break :blk "VK_KHR_win32_surface";
    } else {
        break :blk "VK_KHR_xcb_surface";
    }
};
pub const BufferMemoryBarrier = c.VkBufferMemoryBarrier;
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
    BufferCreateInfo = c.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
    CommandPoolCreateInfo = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
    CommandBufferAllocateInfo = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
    CommandBufferBeginInfo = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
    SubmitInfo = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
    ShaderModuleCreateInfo = c.VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
    BufferDeviceAddressInfo = c.VK_STRUCTURE_TYPE_BUFFER_DEVICE_ADDRESS_INFO_EXT,
    PipelineLayoutCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    SwapchainCreateInfoKHR = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
    PresentInfoKHR = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
    ImageViewCreateInfo = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
    RenderingInfoKHR = c.VK_STRUCTURE_TYPE_RENDERING_INFO_KHR,
    RenderingAttachmentInfoKHR = c.VK_STRUCTURE_TYPE_RENDERING_ATTACHMENT_INFO_KHR,
    Win32SurfaceCreateInfoKHR = c.VK_STRUCTURE_TYPE_WIN32_SURFACE_CREATE_INFO_KHR,
    XcbSurfaceCreateInfoKHR = c.VK_STRUCTURE_TYPE_XCB_SURFACE_CREATE_INFO_KHR,
    ImageMemoryBarrier = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER,
    BufferMemoryBarrier = c.VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER,
    ImageCreateInfo = c.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO,
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
    ComputePipelineCreateInfo = c.VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
    PipelineDepthStencilStateCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,

    DependencyInfoKHR = c.VK_STRUCTURE_TYPE_DEPENDENCY_INFO_KHR,
    BufferMemoryBarrier2KHR = c.VK_STRUCTURE_TYPE_BUFFER_MEMORY_BARRIER_2_KHR,
    ImageMemoryBarrier2KHR = c.VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER_2_KHR,
    MemoryBarrier2KHR = c.VK_STRUCTURE_TYPE_MEMORY_BARRIER_2_KHR,
    PhysicalDeviceSynchronization2FeaturesKHR = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SYNCHRONIZATION_2_FEATURES_KHR,
    MemoryAllocateFlagsInfo = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_FLAGS_INFO,

    // Descriptor-related structure types
    DescriptorSetLayoutCreateInfo = c.VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,

    // Add these for pipeline rendering and descriptors
    PhysicalDeviceDynamicRenderingFeatures = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DYNAMIC_RENDERING_FEATURES_KHR,
    PhysicalDeviceDescriptorIndexingFeatures = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DESCRIPTOR_INDEXING_FEATURES_EXT,
    PhysicalDeviceBufferDeviceAddressFeatures = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_BUFFER_DEVICE_ADDRESS_FEATURES,
    PhysicalDeviceScalarBlockLayoutFeatures = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SCALAR_BLOCK_LAYOUT_FEATURES_EXT,
    PhysicalDeviceSubgroupProperties = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_PROPERTIES,
    PhysicalDeviceShaderAtomicInt64Features = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_ATOMIC_INT64_FEATURES_KHR,
    PhysicalDeviceProperties2 = c.VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2_KHR,
    // Synchronization-related structure types
    FenceCreateInfo = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
    SemaphoreCreateInfo = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
    PipelineRenderingCreateInfo = c.VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO,
    MemoryAllocateInfo = c.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
};

pub const PhysicalDeviceProperties2 = c.VkPhysicalDeviceProperties2;
pub const FormatFeatureFlags = c.VkFormatFeatureFlags;
pub const SAMPLE_COUNT_1_BIT = c.VK_SAMPLE_COUNT_1_BIT;
pub const getPhysicalDeviceProperties2 = c.vkGetPhysicalDeviceProperties2;
pub const NULL = c.VK_NULL_HANDLE;
pub const SpecializationMapEntry = c.VkSpecializationMapEntry;

pub fn sTy(ty: StructureType) c.VkStructureType {
    // Using an explicit cast to c_int since VkStructureType is a c_int
    return @as(c.VkStructureType, if (@import("builtin").os.tag == .windows)
        @as(c_int, @intCast(@intFromEnum(ty)))
    else
        @as(c_uint, @intCast(@intFromEnum(ty))));
}

pub const API_VERSION_1_0 = c.VK_API_VERSION_1_0;
pub const API_VERSION_1_3 = c.VK_API_VERSION_1_3;
pub const MAKE_VERSION = c.VK_MAKE_VERSION;
pub const ApplicationInfo = c.VkApplicationInfo;
pub const Bool32 = c.VkBool32;
pub const InstanceCreateInfo = c.VkInstanceCreateInfo;
pub const DeviceQueueCreateInfo = c.VkDeviceQueueCreateInfo;
pub const DeviceCreateInfo = c.VkDeviceCreateInfo;
pub const enumerateInstanceLayerProperties = c.vkEnumerateInstanceLayerProperties;
pub const enumerateInstanceExtensionProperties = c.vkEnumerateInstanceExtensionProperties;
pub const ImageTiling = c.VkImageTiling;
pub const MemoryAllocateFlagsInfo = c.VkMemoryAllocateFlagsInfo;
pub const Result = c.VkResult;
pub const Instance = c.VkInstance;
pub const PhysicalDevice = c.VkPhysicalDevice;
pub const PhysicalDeviceProperties = c.VkPhysicalDeviceProperties;
pub const PhysicalDeviceMemoryProperties = c.VkPhysicalDeviceMemoryProperties;
pub const MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT = c.VK_MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT;
pub const Device = c.VkDevice;
pub const Pipeline = c.VkPipeline;
pub const PipelineLayout = c.VkPipelineLayout;
pub const ShaderModule = c.VkShaderModule;
pub const ACCESS_TRANSFER_READ_BIT = c.VK_ACCESS_TRANSFER_READ_BIT;
pub const ACCESS_TRANSFER_WRITE_BIT = c.VK_ACCESS_TRANSFER_WRITE_BIT;
pub const ComputePipelineCreateInfo = c.VkComputePipelineCreateInfo;
pub const PIPELINE_STAGE_VERTEX_SHADER_BIT = c.VK_PIPELINE_STAGE_VERTEX_SHADER_BIT;
pub const PIPELINE_STAGE_FRAGMENT_SHADER_BIT = c.VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;

pub const PIPELINE_STAGE_TRANSFER_BIT = c.VK_PIPELINE_STAGE_TRANSFER_BIT;
pub const ACCESS_SHADER_READ_BIT = c.VK_ACCESS_SHADER_READ_BIT;
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
pub const PIPELINE_STAGE_COMPUTE_SHADER_BIT = c.VK_PIPELINE_STAGE_COMPUTE_SHADER_BIT;
pub const ACCESS_SHADER_WRITE_BIT = c.VK_ACCESS_SHADER_WRITE_BIT;
pub const DeviceSize = c.VkDeviceSize;
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
pub const COMPUTE = c.VK_SHADER_STAGE_COMPUTE_BIT;
pub const PIPELINE_BIND_POINT_COMPUTE = c.VK_PIPELINE_BIND_POINT_COMPUTE;
pub const cmdDispatch = c.vkCmdDispatch;
pub fn createSurface(instance: Instance, platform_specific_info: PlatformSpecificInfo) ?Surface {
    const create_info = switch (@import("builtin").os.tag) {
        .windows => c.VkWin32SurfaceCreateInfoKHR{
            .sType = sTy(.Win32SurfaceCreateInfoKHR),
            .pNext = null,
            .hinstance = platform_specific_info.PlatformWindows.hinstance,
            .hwnd = platform_specific_info.PlatformWindows.hwnd,
        },
        else => c.VkXcbSurfaceCreateInfoKHR{
            .sType = sTy(.XcbSurfaceCreateInfoKHR),
            .pNext = null,
            .connection = @as(?*c.struct_xcb_connection_t, @ptrCast(platform_specific_info.PlatformXcb.connection)),
            .window = platform_specific_info.PlatformXcb.window.?,
        },
    };
    var surface: Surface = undefined;
    const result = createVkSurface(instance, &create_info, null, &surface);
    if (result != SUCCESS) {
        return null;
    }
    return surface;
}

// Swapchain-related constants
pub const KHR_SWAPCHAIN_EXTENSION_NAME = c.VK_KHR_SWAPCHAIN_EXTENSION_NAME;

pub const SUBOPTIMAL_KHR = c.VK_SUBOPTIMAL_KHR;
pub const Surface = c.VkSurfaceKHR;
// Swapchain-related structures
pub const SwapchainCreateInfo = c.VkSwapchainCreateInfoKHR;
pub const Swapchain = c.VkSwapchainKHR;
pub const PresentMode = c.VkPresentModeKHR;
pub const SurfaceFormat = c.VkSurfaceFormatKHR;
pub const Extent2D = c.VkExtent2D;

// Swapchain-related functions
pub const destroySwapchainKHR = c.vkDestroySwapchainKHR;
pub const getSwapchainImagesKHR = c.vkGetSwapchainImagesKHR;
pub const queuePresentKHR = c.vkQueuePresentKHR;
pub const PhysicalDeviceFeatures = c.VkPhysicalDeviceFeatures;

// Command pool-related constants
pub const CommandPoolCreateInfo = c.VkCommandPoolCreateInfo;
pub const CommandPool = c.VkCommandPool;
pub const CommandBufferAllocateInfo = c.VkCommandBufferAllocateInfo;
pub const CommandBuffer = c.VkCommandBuffer;
pub const CommandBufferLevel = c.VkCommandBufferLevel;

pub const ERROR_DEVICE_LOST = c.VK_ERROR_DEVICE_LOST;
pub const ERROR_OUT_OF_HOST_MEMORY = c.VK_ERROR_OUT_OF_HOST_MEMORY;

pub const ERROR_OUT_OF_DEVICE_MEMORY = c.VK_ERROR_OUT_OF_DEVICE_MEMORY;

// Command pool-related functions

// Command pool creation function
pub fn createCommandPool(
    device: Device,
    queue_family_index: u32,
) ?CommandPool {
    const create_info = CommandPoolCreateInfo{
        .sType = sTy(.CommandPoolCreateInfo),
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
        .sType = sTy(.CommandBufferAllocateInfo),
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
pub const NOT_READY = c.VK_NOT_READY;
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
pub const cmdPipelineBarrier = c.vkCmdPipelineBarrier;

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
pub const PhysicalDeviceBufferDeviceAddressFeatures = extern struct {
    sType: c.VkStructureType,
    pNext: ?*const anyopaque,
    bufferDeviceAddress: c.VkBool32,
    bufferDeviceAddressCaptureReplay: c.VkBool32,
    bufferDeviceAddressMultiDevice: c.VkBool32,
};

// Add scalar block layout features
pub const PhysicalDeviceScalarBlockLayoutFeatures = c.VkPhysicalDeviceScalarBlockLayoutFeaturesEXT;
pub const PhysicalDeviceShaderAtomicInt64Features = c.VkPhysicalDeviceShaderAtomicInt64FeaturesKHR;

// Queue family properties
pub const QueueFamilyProperties = c.VkQueueFamilyProperties;
pub const getPhysicalDeviceQueueFamilyProperties = c.vkGetPhysicalDeviceQueueFamilyProperties;

// Surface support function (capital G version is used in render.zig)
pub const getPhysicalDeviceSurfaceSupportKHR = c.vkGetPhysicalDeviceSurfaceSupportKHR;

// ...existing code...

// Surface-related structures
pub const SurfaceCapabilitiesKHR = c.VkSurfaceCapabilitiesKHR;
pub const SurfaceFormatKHR = c.VkSurfaceFormatKHR;
pub const PresentModeKHR = c.VkPresentModeKHR;

// Surface-related constants
pub const COLOR_SPACE_SRGB_NONLINEAR_KHR = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR;
pub const PRESENT_MODE_FIFO_KHR = c.VK_PRESENT_MODE_FIFO_KHR;
pub const createComputePipelines = c.vkCreateComputePipelines;
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
pub const getPhysicalDeviceSurfaceCapabilitiesKHR = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR;
pub const getPhysicalDeviceSurfaceFormatsKHR = c.vkGetPhysicalDeviceSurfaceFormatsKHR;
pub const getPhysicalDeviceSurfacePresentModesKHR = c.vkGetPhysicalDeviceSurfacePresentModesKHR;
pub const createSwapchainKHR = c.vkCreateSwapchainKHR;
pub const destroySurfaceKHR = c.vkDestroySurfaceKHR;

// Image/view-related types
pub const Image = c.VkImage;
pub const ImageView = c.VkImageView;
pub const SwapchainCreateInfoKHR = c.VkSwapchainCreateInfoKHR;

// Dynamic rendering types and constants
pub const RenderingAttachmentInfoKHR = c.VkRenderingAttachmentInfoKHR;
pub const RenderingInfoKHR = c.VkRenderingInfoKHR;
pub const ATTACHMENT_LOAD_OP_CLEAR = c.VK_ATTACHMENT_LOAD_OP_CLEAR;
pub const ATTACHMENT_STORE_OP_STORE = c.VK_ATTACHMENT_STORE_OP_STORE;
pub const IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
pub const PIPELINE_BIND_POINT_GRAPHICS = c.VK_PIPELINE_BIND_POINT_GRAPHICS;

// Command buffer functions for dynamic rendering
pub const cmdBindPipeline = c.vkCmdBindPipeline;
pub const cmdDraw = c.vkCmdDraw;
pub const cmdSetScissor = c.vkCmdSetScissor;
pub const cmdSetViewport = c.vkCmdSetViewport;
pub const BeginCommandBuffer = c.vkBeginCommandBuffer;
pub const EndCommandBuffer = c.vkEndCommandBuffer;
pub const acquireNextImageKHR = c.vkAcquireNextImageKHR;
pub const getPhysicalDeviceFeatures = c.vkGetPhysicalDeviceFeatures;

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
pub const RENDER_PASS_LOAD_OP_LOAD = c.VK_ATTACHMENT_LOAD_OP_LOAD;
pub const RENDER_PASS_STORE_OP_STORE = c.VK_ATTACHMENT_STORE_OP_STORE;
pub const ClearValue = c.VkClearValue;
pub const ClearColorValue = c.VkClearColorValue;

pub const Rect2D = c.VkRect2D;
pub const Offset2D = c.VkOffset2D;
pub const ImageViewType = c.VkImageViewType;
pub const ComponentMapping = c.VkComponentMapping;

pub const Viewport = c.VkViewport;
pub const FILL = c.VK_POLYGON_MODE_FILL;

// Function pointer types
pub var cmdBeginRenderingKHR: *const fn (CommandBuffer, *const RenderingInfoKHR) callconv(.C) void = undefined;
pub var cmdEndRenderingKHR: *const fn (CommandBuffer) callconv(.C) void = undefined;
pub const PIPELINE_STAGE_TOP_OF_PIPE_BIT = c.VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
pub const PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT = c.VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;

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

    if (@as(?*const anyopaque, loadDeviceProc(device, "vkCmdPipelineBarrier2"))) |proc_addr| {
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

// Shader stages as bit flags for push constants and other operations
pub const SHADER_STAGE_VERTEX_BIT = c.VK_SHADER_STAGE_VERTEX_BIT;
pub const SHADER_STAGE_FRAGMENT_BIT = c.VK_SHADER_STAGE_FRAGMENT_BIT;
pub const SHADER_STAGE_COMPUTE_BIT = c.VK_SHADER_STAGE_COMPUTE_BIT;

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
pub const COUNTER_CLOCKWISE = c.VK_FRONT_FACE_COUNTER_CLOCKWISE;
pub const CULL_MODE_NONE = c.VK_CULL_MODE_NONE;
pub const IMAGE_LAYOUT_UNDEFINED = c.VK_IMAGE_LAYOUT_UNDEFINED;
pub const QUEUE_FAMILY_IGNORED = c.VK_QUEUE_FAMILY_IGNORED;
pub const ACCESS_COLOR_ATTACHMENT_WRITE_BIT = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
pub const PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
pub const ACCESS_MEMORY_READ_BIT = c.VK_ACCESS_MEMORY_READ_BIT;
pub const IMAGE_LAYOUT_PRESENT_SRC_KHR = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
pub const REMAINING_ARRAY_LAYERS = c.VK_REMAINING_ARRAY_LAYERS;
pub const REMAINING_MIP_LEVELS = c.VK_REMAINING_MIP_LEVELS;
pub const WHOLE_SIZE = c.VK_WHOLE_SIZE;

// Memory and buffer related constants and functions
pub const BufferCreateInfo = c.VkBufferCreateInfo;
pub const MemoryAllocateInfo = c.VkMemoryAllocateInfo;
pub const MappedMemoryRange = c.VkMappedMemoryRange;
pub const DeviceMemory = c.VkDeviceMemory;
pub const MemoryPropertyFlags = c.VkMemoryPropertyFlags;
pub const BufferUsageFlags = c.VkBufferUsageFlags;
pub const MemoryRequirements = c.VkMemoryRequirements;
pub const BufferCopy = c.VkBufferCopy;
pub const BufferImageCopy = c.VkBufferImageCopy;

// Memory related constants
pub const MEMORY_PROPERTY_HOST_VISIBLE_BIT = c.VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT;
pub const MEMORY_PROPERTY_HOST_COHERENT_BIT = c.VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
pub const MEMORY_PROPERTY_DEVICE_LOCAL_BIT = c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;

// Buffer usage flags
pub const BUFFER_USAGE_TRANSFER_SRC_BIT = c.VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
pub const BUFFER_USAGE_TRANSFER_DST_BIT = c.VK_BUFFER_USAGE_TRANSFER_DST_BIT;
pub const BUFFER_USAGE_UNIFORM_BUFFER_BIT = c.VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT;
pub const BUFFER_USAGE_STORAGE_BUFFER_BIT = c.VK_BUFFER_USAGE_STORAGE_BUFFER_BIT;
pub const BUFFER_USAGE_INDEX_BUFFER_BIT = c.VK_BUFFER_USAGE_INDEX_BUFFER_BIT;
pub const BUFFER_USAGE_VERTEX_BUFFER_BIT = c.VK_BUFFER_USAGE_VERTEX_BUFFER_BIT;
pub const BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT = c.VK_BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT;

// Buffer creation flags
pub const BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT = c.VK_BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT;

// Device address info structure
pub const BufferDeviceAddressInfo = c.VkBufferDeviceAddressInfo;

// Memory and buffer functions
pub const createBuffer = c.vkCreateBuffer;
pub const destroyBuffer = c.vkDestroyBuffer;
pub const getBufferMemoryRequirements = c.vkGetBufferMemoryRequirements;
pub const allocateMemory = c.vkAllocateMemory;
pub const freeMemory = c.vkFreeMemory;
pub const bindBufferMemory = c.vkBindBufferMemory;
pub const mapMemory = c.vkMapMemory;
pub const unmapMemory = c.vkUnmapMemory;
pub const flushMappedMemoryRanges = c.vkFlushMappedMemoryRanges;
pub const invalidateMappedMemoryRanges = c.vkInvalidateMappedMemoryRanges;
pub const getBufferDeviceAddress = c.vkGetBufferDeviceAddress;

// Command buffer functions for buffer operations
pub const cmdCopyBuffer = c.vkCmdCopyBuffer;
pub const cmdCopyBufferToImage = c.vkCmdCopyBufferToImage;
pub const cmdPushConstants = c.vkCmdPushConstants;

// Add Windows-specific surface type definitions
pub const Win32SurfaceCreateInfoKHR = c.VkWin32SurfaceCreateInfoKHR;
pub const FormatProperties = c.VkFormatProperties;
pub const ImageViewCreateInfo = c.VkImageViewCreateInfo;
pub const ImageSubresourceRange = c.VkImageSubresourceRange;
pub const ImageMemoryBarrier = c.VkImageMemoryBarrier;
pub const PhysicalDeviceSubgroupProperties = c.VkPhysicalDeviceSubgroupProperties;

// Add depth buffer-related formats to the Format enum
pub const Format = enum(c_int) {
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

    // Depth formats
    D16Unorm = c.VK_FORMAT_D16_UNORM,
    D16UnormS8Uint = c.VK_FORMAT_D16_UNORM_S8_UINT,
    D24UnormS8Uint = c.VK_FORMAT_D24_UNORM_S8_UINT,
    D32Sfloat = c.VK_FORMAT_D32_SFLOAT,
    D32SfloatS8Uint = c.VK_FORMAT_D32_SFLOAT_S8_UINT,
    S8Uint = c.VK_FORMAT_S8_UINT,
};

// Add depth buffer-related constants
pub const IMAGE_ASPECT_DEPTH_BIT = c.VK_IMAGE_ASPECT_DEPTH_BIT;
pub const IMAGE_ASPECT_STENCIL_BIT = c.VK_IMAGE_ASPECT_STENCIL_BIT;
pub const IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT = c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;
pub const FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT = c.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT;

// Add depth buffer-related image layouts
pub const IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL;
pub const IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL = c.VK_IMAGE_LAYOUT_DEPTH_STENCIL_READ_ONLY_OPTIMAL;

// Add depth buffer-related access flags
pub const ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT = c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_READ_BIT;
pub const ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT = c.VK_ACCESS_DEPTH_STENCIL_ATTACHMENT_WRITE_BIT;

// Add depth buffer-related pipeline stage flags
pub const PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT = c.VK_PIPELINE_STAGE_EARLY_FRAGMENT_TESTS_BIT;
pub const PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT = c.VK_PIPELINE_STAGE_LATE_FRAGMENT_TESTS_BIT;

// Add depth buffer-related image creation flags
pub const IMAGE_TILING_OPTIMAL = c.VK_IMAGE_TILING_OPTIMAL;
pub const IMAGE_TILING_LINEAR = c.VK_IMAGE_TILING_LINEAR;

// Add depth buffer-related image types
pub const IMAGE_TYPE_2D = c.VK_IMAGE_TYPE_2D;

// Add depth buffer-related image view types

// Add depth buffer-related image creation info
pub const ImageCreateInfo = c.VkImageCreateInfo;

// Add depth buffer-related image view creation info
// pub const ImageViewCreateInfo = c.VkImageViewCreateInfo; // Duplicate removed

// Add depth buffer-related image subresource range
// pub const ImageSubresourceRange = c.VkImageSubresourceRange; // Duplicate removed

// Add depth buffer-related image memory barrier
// pub const ImageMemoryBarrier = c.VkImageMemoryBarrier; // Duplicate removed

// Add depth buffer-related image layout transition functions
// pub const cmdPipelineBarrier = c.vkCmdPipelineBarrier; // Duplicate removed

// Add depth buffer-related image creation and destruction functions
pub const createImage = c.vkCreateImage;
pub const destroyImage = c.vkDestroyImage;
pub const getImageMemoryRequirements = c.vkGetImageMemoryRequirements;
pub const bindImageMemory = c.vkBindImageMemory;
pub const createImageView = c.vkCreateImageView;
pub const destroyImageView = c.vkDestroyImageView;

// Add depth buffer-related format properties query function
pub const getPhysicalDeviceFormatProperties = c.vkGetPhysicalDeviceFormatProperties;
