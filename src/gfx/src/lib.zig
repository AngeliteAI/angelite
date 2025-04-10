const std = @import("std");

pub const include = @import("include");

const builtin = @import("builtin");

// Import platform-specific surface module
pub usingnamespace switch (builtin.os.tag) {
    .windows => @import("windows/surface.zig"),
    .linux => @import("linux/surface.zig"),
    else => @compileError("Unsupported platform"),
};

pub usingnamespace @import("vk/render.zig");

// Library information
pub const version = "0.1.0";

