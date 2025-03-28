const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "gfx-test",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link with system libraries
    exe.linkLibC();
    exe.linkLibCpp();
    exe.linkSystemLibrary("vulkan");
    exe.linkSystemLibrary("xcb");
    exe.linkSystemLibrary("glslang");
    exe.linkSystemLibrary("SPIRV");
    exe.linkSystemLibrary("SPVRemapper");

    // Add C++ compilation flags for glslang

    // Ensure stl is properly linked
    exe.linkSystemLibrary("stdc++");

    // Continue with the rest of your build script
    b.installArtifact(exe);

    // ... rest of your build configuration
}
