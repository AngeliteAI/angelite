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
    
    // Add Tracy support
    windows_lib.addIncludePath(b.path("vendor/tracy/public"));
    windows_lib.addCSourceFile(.{
        .file = b.path("vendor/tracy/public/TracyClient.cpp"),
        .flags = &[_][]const u8{
            "-DTRACY_ENABLE=1",
            // Keep the connection open until Tracy connects
            "-DTRACY_NO_EXIT=1",
            // Disable RDTSC instruction which might cause issues
            "-DTRACY_TIMER_FALLBACK=1",
            // Allow Tracy to broadcast its presence for discovery
            // "-DTRACY_NO_BROADCAST=1",
            // Allow code transfer for better debugging
            // "-DTRACY_NO_CODE_TRANSFER=1",
            // Allow connections from any host for development  
            // "-DTRACY_ONLY_LOCALHOST=1",
            "-fno-exceptions",
            "-fno-rtti",
        },
    });
    windows_lib.linkLibCpp();
    
    // Link Windows libraries required by Tracy
    windows_lib.linkSystemLibrary("ws2_32");  // Windows Sockets
    windows_lib.linkSystemLibrary("dbghelp"); // Debug symbols
    windows_lib.linkSystemLibrary("advapi32"); // Advanced Windows API

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

        // Camera API
        "renderer_camera_create",
        "renderer_camera_destroy",
        "renderer_camera_set_projection",
        "renderer_camera_set_transform",
        "renderer_camera_set_main",
        
        // Compute API
        "renderer_buffer_create",
        "renderer_buffer_destroy",
        "renderer_buffer_write",
        "renderer_buffer_read",
        "renderer_buffer_copy",
        "renderer_compute_shader_create",
        "renderer_compute_shader_destroy",
        "renderer_command_buffer_begin",
        "renderer_command_buffer_end",
        "renderer_compute_bind_shader",
        "renderer_compute_bind_buffer",
        "renderer_compute_dispatch",
        "renderer_compute_memory_barrier",
        "renderer_command_buffer_submit",
        "renderer_device_wait_idle",
        "renderer_get_current_command_buffer",
        
        // Physics integration
        "renderer_get_device_info",
        "renderer_get_device_dispatch",
        "renderer_get_physical_device",
        "renderer_get_instance_dispatch",
        
        // Additional mesh functions
        "renderer_update_draw_command_vertex_count",
        
        // Input API
        "input_init",
        "input_deinit",
        "input_poll",
        "input_get_keyboard_state",
        "input_get_mouse_state",
        
        // GPU Worldgen API
        "gpu_worldgen_create",
        "gpu_worldgen_destroy",
        "gpu_worldgen_generate",
        "gpu_worldgen_allocate_descriptor_set",
        
        // Tracy FFI API
        "tracy_zone_begin",
        "tracy_zone_end",
        "tracy_frame_mark",
        "tracy_frame_mark_named",
        "tracy_plot",
        "tracy_message",
        "tracy_message_color",
        "tracy_thread_name",
        "tracy_alloc",
        "tracy_free",
        "tracy_is_connected",
        "tracy_startup",
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
