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

    // Determine platform-specific source file and dependencies
    const is_windows = target.result.os.tag == .windows;
    const is_macos = target.result.os.tag == .macos;

    const root_source_path = "src/lib.zig";

    // Set the root source file based on target OS
    std.debug.print("Building for target OS: {s}\n", .{@tagName(target.result.os.tag)});
    std.debug.print("Using source file: {s}\n", .{root_source_path});

    // Create a module that can be imported by other build scripts
    const surface_module = b.addModule("surface", .{
        .root_source_file = b.path(root_source_path),
        .target = target,
        .optimize = optimize,
    });
    
    // Create a submodule for include files
    const include_module = b.addModule("include", .{
        .root_source_file = b.path("include/mod.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    // Add the include module as a dependency of the main module
    surface_module.addImport("include", include_module);

    // Create a static library for external consumption
    const lib = b.addStaticLibrary(.{
        .name = "surface",
        .root_source_file = b.path(root_source_path),
        .target = target,
        .optimize = optimize,
    });
    
    // Make sure the library also has access to the include module
    lib.root_module.addImport("include", include_module);
    
    // Platform specific settings
    if (is_windows) {
        lib.linkLibC();
        std.debug.print("Linking Windows libraries\n", .{});
    } else if (is_macos) {
        // macOS dependencies - frameworks are linked differently
        // through the build.rs Rust file for macOS
        std.debug.print("macOS build - frameworks handled by build.rs\n", .{});
    } else {
        // Linux dependencies
        lib.linkLibC();
        lib.linkSystemLibrary("xcb");
        std.debug.print("Linking Linux libraries\n", .{});
    }
    
    // Bundle compiler-rt to prevent LNK1143 errors
    lib.bundle_compiler_rt = true;
    
    // Disable LTO which can cause COMDAT section issues
    lib.want_lto = false;

    // Install library
    b.installArtifact(lib);
}