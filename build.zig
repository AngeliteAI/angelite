const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // Create a library with a single root source file
    const lib = b.addSharedLibrary(.{
        .name = "deterministic-async-runtime",
        .root_source_file = b.path("src/zig/base/src/lib.zig"), // Fixed path syntax
        .target = target,
        .optimize = optimize,
    });
    // Set up include path
    lib.addIncludePath(b.path("src/zig/base/include")); // Fixed path syntax
    // Install the library
    b.installArtifact(lib);
    // Create a module for documentation (optional)
    const docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Build and install documentation");
    docs_step.dependOn(&docs.step);
    // Create a test step
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/zig/base/src/lib.zig"), // Fixed path syntax
        .target = target,
        .optimize = optimize,
    });
    main_tests.addIncludePath(b.path("src/zig/base/src/include")); // Fixed path syntax
    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
