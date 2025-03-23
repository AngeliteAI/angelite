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

    // Add these lines to link with Vulkan
    exe.linkSystemLibrary("vulkan");

        // Link with X11 library
        exe.linkSystemLibrary("X11");
    // On some systems, you might also need:

    // Continue with the rest of your build script
    b.installArtifact(exe);

    // ... rest of your build configuration
}
