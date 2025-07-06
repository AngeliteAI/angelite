// lib.zig - Root source file for the Angelite Windows component
const std = @import("std");
pub const tracy = @import("tracy.zig");

// Surface functionality - Windows implementation
pub const surface = struct {
    pub const windows = @import("surface/desktop/windows/desktop.zig");

    // Export the surface module functions directly
    pub usingnamespace windows;
};

// Graphics functionality - Vulkan implementation
pub const gfx = struct {
    pub const render = @import("gfx/vk/render.zig");
    pub const main = @import("gfx/vk/gfx.zig");
    pub const vertex_pool = @import("gfx/vk/vertex_pool.zig");

    // Export all vulkan renderer functions directly
    pub usingnamespace render;
    pub usingnamespace main;
    pub usingnamespace vertex_pool;
};

// Physics functionality - GPU-accelerated physics
pub const physx = struct {
    pub const vk = @import("physx/vk/physx.zig");

    // Export the physics engine functions directly
    pub usingnamespace vk;
};

// World generation functionality - GPU-accelerated worldgen
pub const worldgen = struct {
    pub const vk = @import("universe/worldgen/vk/worldgen.zig");

    // Export all worldgen functions directly
    pub usingnamespace vk;
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
    _ = @import("gfx/vk/gfx.zig");
    _ = @import("gfx/vk/vertex_pool.zig");
    _ = @import("physx/vk/physx.zig");
    _ = @import("universe/worldgen/vk/worldgen.zig");

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
    _ = @import("physx/vk/physx.zig");
}
