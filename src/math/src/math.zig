pub const PI = 3.14159265358979323846;
pub const TWO_PI = 6.28318530717958647692;
pub const HALF_PI = 1.57079632679489661923;
pub const INV_PI = 0.31830988618379067154;
pub const DEG_TO_RAD = 0.01745329251994329577;
pub const RAD_TO_DEG = 57.2957795130823208768;
pub const EPSILON = 0.000001;

// Rendering API flags to determine projection matrix convention
pub const RENDER_API_VULKAN = 0; // [0,1] Z-range
pub const RENDER_API_METAL = 1;  // [-1,1] Z-range
pub const RENDER_API_OPENGL = 2; // [-1,1] Z-range

// Set the current rendering API here (can also be set at runtime if needed)
// RENDER_API_VULKAN = [0,1] Z-range (Vulkan, DirectX)
// RENDER_API_METAL/OPENGL = [-1,1] Z-range (Metal, OpenGL)
pub const CURRENT_RENDER_API = if (@import("builtin").os.tag == .macos) 
                                  RENDER_API_METAL 
                               else 
                                  RENDER_API_VULKAN;
