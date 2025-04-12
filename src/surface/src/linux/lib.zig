const std = @import("std");

// Re-export Linux-specific modules
pub const render = @import("render.zig");
pub const surface = @import("surface.zig");

// Library information
pub const version = "0.1.0";
