const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "gfx-test",
        .root_source_file = b.path("./src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link with system libraries
    exe.linkLibC();
    exe.linkSystemLibrary("vulkan");
    exe.linkSystemLibrary("xcb");
    // Add the gfx library as a module

    // Import the gfx build.zig to use as a dependency
    const gfx_dep = b.dependency("gfx", .{
        .target = target,
        .optimize = optimize,
    });

    // Get the module from the dependency
    const gfx_module = gfx_dep.module("gfx");

    // Add the module to your executable
    exe.root_module.addImport("gfx", gfx_module);

    // Add C++ compilation flags for glslang if needed
    // exe.addCSourceFile(b.path("../../gfx/src/shaders.cpp"), &.{"-std=c++17"});
    // exe.linkSystemLibrary("glslang");

    // Continue with the rest of your build script
    b.installArtifact(exe);

    // ... rest of your build configuration
}
