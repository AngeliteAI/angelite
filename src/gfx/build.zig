const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a module that can be imported by other build scripts
    const gfx_module = b.addModule("gfx", .{
        .root_source_file = b.path("src/linux/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add include paths
    gfx_module.addIncludePath(b.path("include"));

    // Create a static library for external consumption (optional)
    const lib = b.addStaticLibrary(.{
        .name = "gfx",
        .root_source_file = b.path("src/linux/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibC();
    lib.linkSystemLibrary("vulkan");
    lib.linkSystemLibrary("xcb");

    // Install library
    b.installArtifact(lib);

    // Add tests
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/linux/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    main_tests.linkLibC();
    main_tests.linkSystemLibrary("vulkan");
    main_tests.linkSystemLibrary("xcb");

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}

// Export build artifacts for use as a dependency by other packages
pub fn getModule(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Module {
    const module = b.createModule(.{
        .root_source_file = b.path("src/linux/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    module.addIncludePath("include");

    return module;
}
