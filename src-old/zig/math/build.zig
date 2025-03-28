const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a static library
    const lib = b.addStaticLibrary(.{
        .name = "math",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("root.zig"),
    });

    // Add include path
    lib.addIncludePath(b.path("include"));

    // Bundle compiler_rt
    lib.bundle_compiler_rt = true;

    // Install headers
    lib.installHeadersDirectory(b.path("include"), "", .{});

    // Install the library
    b.installArtifact(lib);
}
