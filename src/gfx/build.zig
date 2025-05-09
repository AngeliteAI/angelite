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

    // Get the surface dependency
    const surface_dep = b.dependency("surface", .{
        .target = target,
        .optimize = optimize,
    });
    const surface_module = surface_dep.module("surface");

    // Get the math dependency
    const math_dep = b.dependency("math", .{
        .target = target,
        .optimize = optimize,
    });
    // The math module is exported as the root module of the library
    const math_module = math_dep.artifact("math").root_module;
    
    // Get the trace dependency
    const trace_dep = b.dependency("trace", .{
        .target = target,
        .optimize = optimize,
    });
    const trace_module = trace_dep.module("trace");

    // Create a module that can be imported by other build scripts
    const gfx_module = b.addModule("gfx", .{
        .root_source_file = b.path(root_source_path),
        .target = target,
        .optimize = optimize,
    });

    // Add surface module as a dependency
    gfx_module.addImport("surface", surface_module);

    // Add math module as a dependency
    gfx_module.addImport("math", math_module);
    
    // Add trace module as a dependency
    gfx_module.addImport("trace", trace_module);

    // Create a submodule for include files
    const include_module = b.addModule("include", .{
        .root_source_file = b.path("include/mod.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the include module as a dependency of the main module
    include_module.addImport("math", math_module);
    gfx_module.addImport("include", include_module);

    // Add include paths
    gfx_module.addIncludePath(b.path("./"));

    // Add Vulkan SDK include path
    if (is_windows) {
        const vulkan_sdk = std.process.getEnvVarOwned(b.allocator, "VULKAN_SDK") catch |err| {
            std.debug.print("Error: VULKAN_SDK environment variable not found.\n{s}", .{@errorName(err)});
            return;
        };
        defer b.allocator.free(vulkan_sdk);

        const include_path = b.pathJoin(&.{vulkan_sdk, "Include"});
        gfx_module.addIncludePath(.{ .cwd_relative = include_path });
    }

    // Create a shared library for external consumption
    const lib = b.addSharedLibrary(.{
        .name = "gfx",
        .root_source_file = b.path(root_source_path),
        .target = target,
        .optimize = optimize,
        .version = .{ .major = 0, .minor = 1, .patch = 0 },
    });

    // Make sure the library also has access to the include module
    lib.root_module.addImport("include", include_module);

    // Add the surface module to the library
    lib.root_module.addImport("surface", surface_module);

    // Add the math module to the library
    lib.root_module.addImport("math", math_module);
    
    // Add the trace module to the library
    lib.root_module.addImport("trace", trace_module);

    // Add Vulkan SDK include path to the library as well
    if (is_windows) {
        const vulkan_sdk = std.process.getEnvVarOwned(b.allocator, "VULKAN_SDK") catch |err| {
            std.debug.print("Error: VULKAN_SDK environment variable not found.\n{s}", .{@errorName(err)});
            return;
        };
        defer b.allocator.free(vulkan_sdk);

        const include_path = b.pathJoin(&.{vulkan_sdk, "Include"});
        lib.addIncludePath(.{ .cwd_relative = include_path });
    }

    // Disable optimization to avoid COMDAT issues

    // Bundle compiler-rt to prevent LNK1143 errors
    lib.bundle_compiler_rt = true;

    // Disable LTO which can cause COMDAT section issues
    lib.want_lto = false;

    // Force MSVC-compatible options
    if (is_windows) {
        lib.linkLibC();

        const vulkan_sdk = std.process.getEnvVarOwned(b.allocator, "VULKAN_SDK") catch |err| {
            std.debug.print("Error: VULKAN_SDK environment variable not found.\n{s}", .{@errorName(err)});
            return;
        };
        defer b.allocator.free(vulkan_sdk);

        const lib_path = b.pathJoin(&.{vulkan_sdk, "Lib"});
        lib.addLibraryPath(.{ .cwd_relative = lib_path });

        // Link only essential libraries - remove ones that might be causing issues
        lib.linkSystemLibrary("vulkan-1");
        lib.linkSystemLibrary("user32");
        lib.linkSystemLibrary("gdi32");

        std.debug.print("Linking Windows libraries with MSVC ABI\n", .{});
    } else if (is_macos) {
        // macOS dependencies - Metal and related frameworks are linked differently
        // through the build.rs Rust file for macOS
        std.debug.print("macOS build - frameworks handled by build.rs\n", .{});
    } else {
        // Linux dependencies
	lib.linkLibC();
        lib.linkSystemLibrary("vulkan");
        lib.linkSystemLibrary("xcb");
        lib.linkSystemLibrary("X11");
        lib.linkSystemLibrary("X11-xcb");
        std.debug.print("Linking Linux libraries\n", .{});
    }

    // Print the output path for debugging

    // Install library
    b.installArtifact(lib);
}
