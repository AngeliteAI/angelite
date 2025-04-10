const std = @import("std");

// Import from the include module we set up in build.zig
pub const include = @import("include");

// Re-export the include modules for backward compatibility
pub const mat = include.mat;
pub const quat = include.quat;
pub const vec = include.vec;

    pub usingnamespace @import("scalar.zig");   // Local scalar.zig in src directory
    pub usingnamespace @import("vec.zig");      // Local vec.zig in src directory
    pub usingnamespace @import("mat.zig");      // Local mat.zig in src directory
    pub usingnamespace @import("quat.zig");     // Local quat.zig in src directory
