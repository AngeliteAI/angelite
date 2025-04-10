const c = @cImport({
    @cInclude("vulkan/vulkan_win32.h");
    @cInclude("windows.h");
});

pub const Win32SurfaceCreateInfoKHR = c.VkWin32SurfaceCreateInfoKHR;
pub const HINSTANCE = c.HINSTANCE;
pub const HWND = c.HWND;

// Vulkan surface-related constants
pub const KHR_WIN32_SURFACE_EXTENSION_NAME = c.VK_KHR_WIN32_SURFACE_EXTENSION_NAME;

// Vulkan surface-related functions
pub const createWin32SurfaceKHR = c.vkCreateWin32SurfaceKHR;
