const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    // Set default target to Windows with MSVC
    var target_options = b.standardTargetOptions(.{});
    if (builtin.os.tag == .windows) {
        // Force MSVC ABI when on Windows
        target_options.result.abi = .msvc;
    }
    const target = target_options;
    const optimize = b.standardOptimizeOption(.{});

    // Create a static library
    const lib = b.addStaticLibrary(.{
        .name = "math",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/lib.zig"),
    });

    lib.pie = true;

    // Create a submodule for include files
    const include_module = b.addModule("math.include", .{
        .root_source_file = b.path("include/mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the include module as a dependency of the main module
    lib.root_module.addImport("include", include_module);

    // Add include paths
    lib.addIncludePath(b.path("./"));

    // Bundle compiler_rt to prevent LNK1143 errors
    lib.bundle_compiler_rt = true;

    // Install the library
    b.installArtifact(lib);
}
