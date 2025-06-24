// lib.zig - Root source file for the Angelite Windows component
const std = @import("std");

// Surface functionality - Windows implementation
pub const surface = struct {
    pub const windows = @import("surface/desktop/windows/desktop.zig");

    // Export the surface module functions directly
    pub usingnamespace windows;
};

// Graphics functionality - Vulkan implementation
pub const gfx = struct {
    pub const vulkan = @import("gfx/vk/render.zig");

    // Export the vulkan renderer functions directly
    pub usingnamespace vulkan;
};

// Input functionality

// Engine functionality
pub const engine = struct {
    // Will be expanded in the future
};

// This comptime block ensures all modules are included in the build
// The _ = @import() pattern forces the compiler to include these files
// even if they're not directly used
comptime {
    // Windows components
    _ = @import("surface/desktop/windows/desktop.zig");
    _ = @import("gfx/vk/render.zig");

    // Import this file to generate initialization code
    _ = @This();
}

// Library version information
pub const version = struct {
    pub const major = 0;
    pub const minor = 1;
    pub const patch = 0;

    pub fn versionString() []const u8 {
        return std.fmt.comptimePrint("{d}.{d}.{d}", .{ major, minor, patch });
    }
};

// Test function
test "angelite windows component tests" {
    // Run tests for all modules
    _ = @import("surface/desktop/windows/desktop.zig");
    _ = @import("gfx/vk/render.zig");
}
