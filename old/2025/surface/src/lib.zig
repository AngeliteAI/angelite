const std = @import("std");

pub const include = @import("include");

const builtin = @import("builtin");

// Import platform-specific surface module
pub usingnamespace switch (builtin.os.tag) {
    .windows => @import("win32/surface.zig"),
    .linux => @import("linux/surface.zig"),
    .macos => @import("macos/Surface.swift"),
    else => @compileError("Unsupported platform"),
};

// Library information
pub const version = "0.1.0";