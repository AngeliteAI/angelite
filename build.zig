const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    // Create the base library
    const base_lib = b.addSharedLibrary(.{
        .name = "deterministic-async-runtime",
        .root_source_file = b.path("src/zig/base/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Set up include path
    base_lib.addIncludePath(b.path("src/zig/base/include"));
    // Install the base library
    b.installArtifact(base_lib);

    // Create the input library with action_manager and stage
    const input_lib = b.addSharedLibrary(.{
        .name = "input",
        .root_source_file = b.path("src/win32/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(input_lib);

    // Create a module for documentation (optional)
    const docs = b.addInstallDirectory(.{
        .source_dir = base_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Build and install documentation");
    docs_step.dependOn(&docs.step);
    
    // Create a test step
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/zig/base/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    main_tests.addIncludePath(b.path("src/zig/base/src/include")); 
    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // Add tests for the input library
    const input_tests = b.addTest(.{
        .root_source_file = b.path("src/win32/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_input_tests = b.addRunArtifact(input_tests);
    test_step.dependOn(&run_input_tests.step);
}