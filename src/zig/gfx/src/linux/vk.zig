const c = @cImport({
    @cInclude("vulkan/vulkan.h");
    @cInclude("xcb/xcb.h");
    @cInclude("vulkan/vulkan_xcb.h");
});
const std = @import("std");
const xcb = @import("xcb.zig");

pub const StructureType = enum(c_uint) {
    AppInfo = 0,
    InstanceInfo = 1,
    DeviceQueueCreateInfo = 2,
    DeviceCreateInfo = 3,
    XcbSurfaceCreateInfoKHR = 1000005000,
};

pub const NULL = c.VK_NULL_HANDLE;

pub fn sTy(ty: StructureType) c.VkStructureType {
    // Using a direct cast since we know StructureType uses c_uint as its tag type
    return @as(c.VkStructureType, @intFromEnum(ty));
}

pub const API_VERSION_1_0 = c.VK_API_VERSION_1_0;
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

pub const MEMORY_HEAP_DEVICE_LOCAL_BIT = c.VK_MEMORY_HEAP_DEVICE_LOCAL_BIT;
pub const SUCCESS = c.VK_SUCCESS;

pub const createInstance = c.vkCreateInstance;
pub const enumeratePhysicalDevices = c.vkEnumeratePhysicalDevices;
pub const getPhysicalDeviceProperties = c.vkGetPhysicalDeviceProperties;
pub const getPhysicalDeviceMemoryProperties = c.vkGetPhysicalDeviceMemoryProperties;
pub const createDevice = c.vkCreateDevice;
pub const destroyDevice = c.vkDestroyDevice;
pub const destroyInstance = c.vkDestroyInstance;
pub const enumerateInstanceExtensionProperties = c.vkEnumerateInstanceExtensionProperties;
pub const enumerateDeviceExtensionProperties = c.vkEnumerateDeviceExtensionProperties;
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
        .flags = 0, // Adjust flags as needed
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
