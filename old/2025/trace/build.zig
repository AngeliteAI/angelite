const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    // Set default target with options
    var target_options = b.standardTargetOptions(.{});
    if (builtin.os.tag == .windows) {
        // Force MSVC ABI when on Windows
        target_options.result.abi = .msvc;
    }
    const target = target_options;
    const optimize = b.standardOptimizeOption(.{});

    // Define the root source file path
    const root_source_path = "src/trace.zig";

    // Create a module for trace functionality that can be imported by other modules
    // This is the key part that needs to be properly exported
    const trace_module = b.addModule("trace", .{
        .root_source_file = b.path(root_source_path),
    });

    // Export the module so it can be used as a dependency
    b.modules.put("trace", trace_module) catch unreachable;

    // Create a shared library for external consumption
    const trace_lib = b.addSharedLibrary(.{
        .name = "trace",
        .root_source_file = b.path(root_source_path),
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 0, .minor = 1, .patch = 0 },
    });

    // Add include paths if needed
    trace_lib.addIncludePath(b.path("include"));

    // Bundle compiler-rt to prevent link errors
    trace_lib.bundle_compiler_rt = true;

    // Install the library artifacts
    b.installArtifact(trace_lib);

    // Create test step
    const trace_tests = b.addTest(.{
        .root_source_file = b.path(root_source_path),
        .target = target,
        .optimize = optimize,
    });
    trace_tests.addIncludePath(b.path("include"));

}
