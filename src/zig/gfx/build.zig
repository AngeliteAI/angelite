const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "your-app-name",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add these lines to link with Vulkan
    exe.linkSystemLibrary("vulkan");

    // On some systems, you might also need:
    exe.addLibraryPath(.{ .path = "/usr/lib/x86_64-linux-gnu" });

    // Continue with the rest of your build script
    b.installArtifact(exe);

    // ... rest of your build configuration
}
