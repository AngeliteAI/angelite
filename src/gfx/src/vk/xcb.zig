const c = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("vulkan/vulkan_xcb.h");
});

pub const XcbSurfaceCreateInfoKHR = c.VkXcbSurfaceCreateInfoKHR;
pub const Connection = *c.xcb_connection_t;
pub const Window = c.xcb_window_t;

// Vulkan surface-related constants
pub const KHR_XCB_SURFACE_EXTENSION_NAME = c.VK_KHR_XCB_SURFACE_EXTENSION_NAME;

// Vulkan surface-related functions
pub const createXcbSurfaceKHR = c.vkCreateXcbSurfaceKHR;
