const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // Force Debug mode for better LLDB debugging
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .Debug,
    });

    // Add Vulkan dependencies
    const vulkan_headers_dep = b.dependency("vulkan_headers", .{});
    const vulkan_registry_path = vulkan_headers_dep.path("registry/vk.xml");

    const vulkan_zig_dep = b.dependency("vulkan_zig", .{
        .registry = vulkan_registry_path,
    });
    const vulkan_module = vulkan_zig_dep.module("vulkan-zig");

    // Create a single shared library for Windows with all components
    const windows_lib = b.addSharedLibrary(.{
        .name = "angelite_windows",
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add debug information for better LLDB line number correlation
    windows_lib.want_lto = false;
    windows_lib.bundle_compiler_rt = true;

    // Add vulkan module to the Windows library
    windows_lib.root_module.addImport("vulkan", vulkan_module);

    // Link against C library for Windows APIs
    windows_lib.linkLibC();

    // Export all necessary symbols for the unified Windows library
    windows_lib.root_module.export_symbol_names = &[_][]const u8{
        // Surface API
        "surface_init",
        "surface_deinit",
        "surface_handle_messages",
        "surface_create_window",
        "surface_destroy_window",
        "surface_get_dimensions",
        "surface_set_title",

        // Renderer API
        "renderer_init",
        "renderer_deinit",
        "renderer_init_vertex_pool",
        "renderer_request_buffer",
        "renderer_add_mesh",
        "renderer_update_vertices",
        "renderer_update_normals",
        "renderer_update_colors",
        "renderer_release_buffer",
        "renderer_mask_by_facing",
        "renderer_order_front_to_back",
        "renderer_begin_frame",
        "renderer_render",
        "renderer_end_frame",

        // Input API
        "input_init",
        "input_deinit",
        "input_poll",
        "input_get_keyboard_state",
        "input_get_mouse_state",
    };

    b.installArtifact(windows_lib);

    // Create a test step
    const main_tests = b.addTest(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Also add debug info to tests
    main_tests.want_lto = false;
    main_tests.bundle_compiler_rt = true;
    main_tests.root_module.addImport("vulkan", vulkan_module);
    main_tests.linkLibC();

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
