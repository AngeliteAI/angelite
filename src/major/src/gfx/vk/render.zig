const std = @import("std");
const builtin = std.builtin;
// Import vulkan directly - we know it will be available through the build system
const vk = @import("vulkan");
const os = std.os;
const kernel32 = std.os.windows.kernel32;

const vertex_pool = @import("vertex_pool.zig");
const math = std.math;

// Export C interface functions for Rust FFI
/// Camera object for handling view and projection matrices
pub const Camera = struct {
    view_matrix: [16]f32,
    proj_matrix: [16]f32,

    pub fn init() Camera {
        return Camera{
            // Identity view matrix (camera at origin looking +Y forward, +Z up)
            .view_matrix = .{
                1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0,
            },
            // Simple perspective projection matrix
            // FOV ~90 degrees, aspect 1:1, near 0.1, far 100.0
            .proj_matrix = .{
                1.0, 0.0, 0.0, 0.0,
                0.0, -1.0, 0.0,          0.0, // Negative to flip Y for Vulkan
                0.0, 0.0,  100.0 / 99.9, 1.0,
                0.0, 0.0,  -10.0 / 99.9, 0.0,
            },
        };
    }
};

pub export fn renderer_init(surface_raw: ?*anyopaque) ?*Renderer {
    std.debug.print("Initializing Vulkan renderer...\n", .{});

    if (surface_raw == null) {
        std.debug.print("Error: surface_raw is null in renderer_init\n", .{});
        return null;
    }

    const renderer = std.heap.c_allocator.create(Renderer) catch |err| {
        std.debug.print("Error allocating renderer: {}\n", .{err});
        return null;
    };

    renderer.* = Renderer.init(std.heap.c_allocator, surface_raw) catch |err| {
        std.debug.print("Error initializing renderer: {}\n", .{err});
        std.heap.c_allocator.destroy(renderer);
        return null;
    };

    std.debug.print("Renderer successfully initialized: {any}\n", .{renderer});
    return renderer;
}

pub export fn renderer_deinit(renderer: ?*Renderer) void {
    if (renderer) |renderer_ptr| {
        renderer_ptr.deinit();
        std.heap.c_allocator.destroy(renderer_ptr);
    }
}

pub export fn renderer_init_vertex_pool(
    renderer: ?*Renderer,
    buffer_count: u32,
    vertex_per_buffer: u32,
    max_draw_commands: u32,
) bool {
    if (renderer) |r| {
        r.initVertexPool(buffer_count, vertex_per_buffer, max_draw_commands) catch return false;
        return true;
    }
    return false;
}

pub export fn renderer_request_buffer(renderer: ?*Renderer) u32 {
    if (renderer) |r| {
        return (r.requestBuffer() catch return std.math.maxInt(u32)) orelse std.math.maxInt(u32);
    }
    return std.math.maxInt(u32);
}

pub export fn renderer_add_mesh(
    renderer: ?*Renderer,
    buffer_idx: u32,
    vertices_ptr: [*]const u8,
    vertex_count: u32,
    position_ptr: [*]const f32,
    group: u32,
    out_index_ptr: *?*u32,
) bool {
    if (renderer) |r| {
        // Convert raw vertices pointer to slice of Vertex
        const vertices_bytes = @as([*]const u8, @ptrCast(vertices_ptr))[0 .. vertex_count * @sizeOf(vertex_pool.Vertex)];
        const vertices = std.mem.bytesAsSlice(vertex_pool.Vertex, vertices_bytes);

        // Convert position array to [3]f32
        const position = [3]f32{ position_ptr[0], position_ptr[1], position_ptr[2] };

        // Add mesh and get index pointer
        out_index_ptr.* = r.addMesh(buffer_idx, @alignCast(vertices), position, group) catch return false;
        return true;
    }
    return false;
}

pub export fn renderer_update_vertices(
    renderer: ?*Renderer,
    buffer_idx: u32,
    vertices_ptr: [*]const u8,
    vertex_count: u32,
) bool {
    if (renderer) |r| {
        // Convert raw vertices pointer to slice of Vertex
        const vertices_bytes = @as([*]const u8, @ptrCast(vertices_ptr))[0 .. vertex_count * @sizeOf(vertex_pool.Vertex)];
        const vertices = std.mem.bytesAsSlice(vertex_pool.Vertex, vertices_bytes);

        // Update vertex data in the buffer
        if (buffer_idx < r.vertex_pool.?.stage_buffers.items.len) {
            r.vertex_pool.?.fillVertexData(buffer_idx, @alignCast(vertices)) catch return false;
            return true;
        }
    }
    return false;
}

pub export fn renderer_update_normals(
    renderer: ?*Renderer,
    buffer_idx: u32,
    normals_ptr: [*]const u8,
    vertex_count: u32,
) bool {
    if (renderer) |r| {
        // Convert raw normals pointer to slice of Vertex (contains position, normal, color)
        const vertices_bytes = @as([*]const u8, @ptrCast(normals_ptr))[0 .. vertex_count * @sizeOf(vertex_pool.Vertex)];
        const vertices = std.mem.bytesAsSlice(vertex_pool.Vertex, vertices_bytes);

        // Update only the normal component in the buffer
        if (buffer_idx < r.vertex_pool.?.stage_buffers.items.len) {
            const stage = &r.vertex_pool.?.stage_buffers.items[buffer_idx];

            if (stage.mapped_memory) |mapped| {
                const dest_vertices = @as([*]vertex_pool.Vertex, @ptrCast(@alignCast(mapped)))[0..vertex_count];

                // Copy only normal direction data for each vertex
                for (0..vertex_count) |i| {
                    dest_vertices[i].normal_dir = vertices[i].normal_dir;
                }

                return true;
            }
        }
    }
    return false;
}

pub export fn renderer_update_colors(
    renderer: ?*Renderer,
    buffer_idx: u32,
    colors_ptr: [*]const u8,
    vertex_count: u32,
) bool {
    if (renderer) |r| {
        // Convert raw colors pointer to slice of Vertex (contains position, normal, color)
        const vertices_bytes = @as([*]const u8, @ptrCast(colors_ptr))[0 .. vertex_count * @sizeOf(vertex_pool.Vertex)];
        const vertices = std.mem.bytesAsSlice(vertex_pool.Vertex, vertices_bytes);

        // Update only the color component in the buffer
        if (buffer_idx < r.vertex_pool.?.stage_buffers.items.len) {
            const stage = &r.vertex_pool.?.stage_buffers.items[buffer_idx];

            if (stage.mapped_memory) |mapped| {
                const dest_vertices = @as([*]vertex_pool.Vertex, @ptrCast(@alignCast(mapped)))[0..vertex_count];

                // Copy only color data for each vertex
                for (0..vertex_count) |i| {
                    dest_vertices[i].color = vertices[i].color;
                }

                return true;
            }
        }
    }
    return false;
}

pub export fn renderer_release_buffer(
    renderer: ?*Renderer,
    buffer_idx: u32,
    command_index_ptr: ?*u32,
) bool {
    if (renderer) |r| {
        if (command_index_ptr) |idx_ptr| {
            r.releaseBuffer(buffer_idx, idx_ptr) catch return false;
            return true;
        }
    }
    return false;
}

pub export fn renderer_mask_by_facing(
    renderer: ?*Renderer,
    camera_position_ptr: [*]const f32,
) bool {
    if (renderer) |r| {
        const position = [3]f32{ camera_position_ptr[0], camera_position_ptr[1], camera_position_ptr[2] };
        r.maskByFacing(position) catch return false;
        return true;
    }
    return false;
}

pub export fn renderer_order_front_to_back(
    renderer: ?*Renderer,
    camera_position_ptr: [*]const f32,
) bool {
    if (renderer) |r| {
        const position = [3]f32{ camera_position_ptr[0], camera_position_ptr[1], camera_position_ptr[2] };
        r.orderFrontToBack(position) catch return false;
        return true;
    }
    return false;
}

/// Create a camera for the renderer
pub export fn renderer_camera_create(renderer: ?*Renderer) ?*Camera {
    if (renderer != null) {
        const camera = std.heap.c_allocator.create(Camera) catch return null;
        camera.* = Camera.init();
        return camera;
    }
    return null;
}

/// Destroy a camera created with renderer_camera_create
pub export fn renderer_camera_destroy(renderer: ?*Renderer, camera: ?*Camera) void {
    _ = renderer; // unused
    if (camera) |cam| {
        std.heap.c_allocator.destroy(cam);
    }
}

/// Set camera projection matrix
pub export fn renderer_camera_set_projection(
    _: ?*Renderer,
    camera: ?*Camera,
    projection_ptr: [*]const f32,
) void {
    if (camera) |cam| {
        // Copy projection matrix
        for (0..16) |i| {
            cam.proj_matrix[i] = projection_ptr[i];
        }
    }
}

/// Set camera transform (view matrix)
pub export fn renderer_camera_set_transform(
    _: ?*Renderer,
    camera: ?*Camera,
    transform_ptr: [*]const f32,
) void {
    if (camera) |cam| {
        // Copy transform/view matrix
        for (0..16) |i| {
            cam.view_matrix[i] = transform_ptr[i];
        }
    }
}

/// Set the main camera for the renderer
pub export fn renderer_camera_set_main(
    renderer: ?*Renderer,
    camera: ?*Camera,
) void {
    if (renderer) |r| {
        if (camera) |cam| {
            r.main_camera = cam;
        }
    }
}

/// Get Vulkan device info for physics integration
pub export fn renderer_get_device_info(
    renderer: ?*Renderer,
    out_device: *vk.Device,
    out_queue: *vk.Queue,
    out_command_pool: *vk.CommandPool,
) bool {
    if (renderer) |r| {
        out_device.* = r.device.device;
        out_queue.* = r.device.graphics_queue;
        out_command_pool.* = r.command_pool;
        return true;
    }
    return false;
}

/// Get device dispatch table for physics
pub export fn renderer_get_device_dispatch(
    renderer: ?*Renderer,
) ?*const vk.DeviceDispatch {
    if (renderer) |r| {
        return &r.device.dispatch;
    }
    return null;
}

/// Get physical device for physics
pub export fn renderer_get_physical_device(
    renderer: ?*Renderer,
) vk.PhysicalDevice {
    if (renderer) |r| {
        return r.device.physical_device.handle;
    }
    return .null_handle;
}

/// Get instance dispatch for physics
pub export fn renderer_get_instance_dispatch(
    renderer: ?*Renderer,
) ?*const vk.InstanceDispatch {
    if (renderer) |r| {
        return &r.instance.dispatch;
    }
    return null;
}

pub export fn renderer_begin_frame(renderer: ?*Renderer) bool {
    if (renderer == null) {
        std.debug.print("Error: renderer is null in begin_frame\n", .{});
        return false;
    }

    if (renderer) |r| {
        std.debug.print("Begin frame called - current_frame: {}, image_acquired: {}\n", .{ r.current_frame, r.image_acquired });
        // Create a command pool if we don't have one yet
        if (r.command_pool == .null_handle) {
            const command_pool_create_info = vk.CommandPoolCreateInfo{
                .queue_family_index = r.device.graphics_queue_family,
                .flags = .{ .transient_bit = true, .reset_command_buffer_bit = true },
            };

            var pool: vk.CommandPool = undefined;
            if (r.device.dispatch.vkCreateCommandPool.?(r.device.device, &command_pool_create_info, null, &pool) != .success) {
                std.debug.print("Failed to create command pool\n", .{});
                return false;
            }
            r.command_pool = pool;
            std.debug.print("Created new command pool in begin_frame: {any}\n", .{r.command_pool});

            // If we just created a command pool, recreate command buffers too
            r.createCommandBuffers() catch |err| {
                std.debug.print("Failed to create command buffers: {}\n", .{err});
                // Continue anyway, we'll try again in the next frame
            };
        }

        // Wait for the previous frame to finish and reset the fence
        if (r.in_flight_fences[r.current_frame] != .null_handle) {
            _ = r.device.dispatch.vkWaitForFences.?(r.device.device, 1, @as([*]const vk.Fence, @ptrCast(&r.in_flight_fences[r.current_frame])), vk.TRUE, std.math.maxInt(u64));
            _ = r.device.dispatch.vkResetFences.?(r.device.device, 1, @as([*]vk.Fence, @ptrCast(&r.in_flight_fences[r.current_frame])));
        }

        // Reset the command buffer for the current frame if it exists
        // Reset the command buffer for the current frame
        if (r.command_buffers[r.current_frame] != .null_handle) {
            const reset_result = r.device.dispatch.vkResetCommandBuffer.?(r.command_buffers[r.current_frame], .{});
            if (reset_result != .success) {
                std.debug.print("Failed to reset command buffer: {}\n", .{reset_result});
                // If we can't reset, try to recreate
                r.createCommandBuffers() catch |err| {
                    std.debug.print("Failed to recreate command buffers after reset failure: {}\n", .{err});
                    // Continue anyway and hope for the best
                };
            }
        } else {
            // If command buffer is null for some reason, recreate command buffers
            r.createCommandBuffers() catch |err| {
                std.debug.print("Failed to recreate command buffers: {}\n", .{err});
                // Try to continue anyway
            };
        }

        // Check if swapchain is valid
        if (r.swapchain == .null_handle) {
            std.debug.print("Cannot acquire image: swapchain is null\n", .{});
            r.current_image_index = std.math.maxInt(u32);
            r.image_acquired = false;
            return false;
        }

        var image_index: u32 = undefined;
        std.debug.print("Acquiring image with swapchain: {any}, semaphore: {any}, current frame: {}\n", .{ r.swapchain, r.image_available_semaphores[r.current_frame], r.current_frame });

        // Don't wait for device idle before each image acquisition - this can cause issues
        // _ = r.device.dispatch.vkDeviceWaitIdle.?(r.device.device);

        // Use a reasonable timeout for image acquisition
        const acquire_result = r.device.dispatch.vkAcquireNextImageKHR.?(r.device.device, r.swapchain, std.math.maxInt(u64), // Wait indefinitely - should not timeout in normal operation
            r.image_available_semaphores[r.current_frame], .null_handle, &image_index);

        std.debug.print("Acquire result: {}, image index: {}\n", .{ acquire_result, image_index });

        if (acquire_result == .error_out_of_date_khr or acquire_result == .suboptimal_khr) {
            std.debug.print("Swapchain outdated, recreating...\n", .{});
            // Wait for device to be idle before recreating the swapchain
            _ = r.device.dispatch.vkDeviceWaitIdle.?(r.device.device);
            // Recreate swapchain
            r.recreateSwapchain() catch |err| {
                std.debug.print("Failed to recreate swapchain: {}\n", .{err});
                r.current_image_index = std.math.maxInt(u32);
                r.image_acquired = false;
                return false;
            };
            // Wait a bit to ensure the swapchain is ready
            std.time.sleep(16 * std.time.ns_per_ms); // ~16ms (one frame at 60fps)
            // Try acquiring image again
            return renderer_begin_frame(renderer);
        } else if (acquire_result != .success) {
            std.debug.print("Failed to acquire swapchain image with result: {}\n", .{acquire_result});
            // Mark that we don't have a valid image
            r.current_image_index = std.math.maxInt(u32);
            r.image_acquired = false;
            return false;
        }

        r.current_image_index = image_index;
        r.image_acquired = true;
        return true;
    }
    return false;
}

pub export fn renderer_render(renderer: ?*Renderer) bool {
    if (renderer == null) {
        std.debug.print("Error: renderer is null in render\n", .{});
        return false;
    }

    if (renderer) |r| {
        if (r.vertex_pool) |_| {
            // The image must have been acquired successfully in begin_frame
            if (r.current_image_index == std.math.maxInt(u32) or !r.image_acquired) {
                std.debug.print("Invalid image index or image not acquired, skipping render\n", .{});
                // Attempt to recreate the swapchain
                std.debug.print("No valid image to present. Recreating swapchain...\n", .{});
                _ = r.device.dispatch.vkDeviceWaitIdle.?(r.device.device);
                r.recreateSwapchain() catch |err| {
                    std.debug.print("Failed to recreate swapchain during render: {}\n", .{err});
                };
                // Don't attempt to render this frame
                r.current_frame = (r.current_frame + 1) % r.max_frames_in_flight;
                return false;
            }

            const command_buffer = r.command_buffers[r.current_frame];

            // Begin command buffer (reset was done in begin_frame)
            const begin_info = vk.CommandBufferBeginInfo{
                .flags = .{ .one_time_submit_bit = true },
                .p_inheritance_info = null,
            };

            _ = r.device.dispatch.vkBeginCommandBuffer.?(command_buffer, &begin_info);

            // Transition images to proper layouts
            const barriers = [_]vk.ImageMemoryBarrier{
                // Color attachment
                .{
                    .src_access_mask = .{},
                    .dst_access_mask = .{ .color_attachment_write_bit = true },
                    .old_layout = .undefined,
                    .new_layout = .color_attachment_optimal,
                    .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .image = r.swapchain_images.items[r.current_image_index],
                    .subresource_range = .{
                        .aspect_mask = .{ .color_bit = true },
                        .base_mip_level = 0,
                        .level_count = 1,
                        .base_array_layer = 0,
                        .layer_count = 1,
                    },
                },
                // Depth attachment
                .{
                    .src_access_mask = .{},
                    .dst_access_mask = .{ .depth_stencil_attachment_write_bit = true },
                    .old_layout = .undefined,
                    .new_layout = .depth_stencil_attachment_optimal,
                    .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                    .image = r.depth_image,
                    .subresource_range = .{
                        .aspect_mask = .{ .depth_bit = true },
                        .base_mip_level = 0,
                        .level_count = 1,
                        .base_array_layer = 0,
                        .layer_count = 1,
                    },
                },
            };

            r.device.dispatch.vkCmdPipelineBarrier.?(command_buffer, .{ .top_of_pipe_bit = true }, .{ .color_attachment_output_bit = true, .early_fragment_tests_bit = true }, .{}, 0, null, 0, null, barriers.len, @ptrCast(&barriers));

            // Begin dynamic rendering
            const clear_color = vk.ClearValue{
                .color = .{ .float_32 = .{ 0.0, 0.0, 0.0, 1.0 } },
            };

            const color_attachment = vk.RenderingAttachmentInfo{
                .image_view = r.swapchain_image_views.items[r.current_image_index],
                .image_layout = .color_attachment_optimal,
                .resolve_mode = .{},
                .resolve_image_view = .null_handle,
                .resolve_image_layout = .undefined,
                .load_op = .clear,
                .store_op = .store,
                .clear_value = clear_color,
            };

            const depth_clear = vk.ClearValue{
                .depth_stencil = .{ .depth = 1.0, .stencil = 0 },
            };

            const depth_attachment = vk.RenderingAttachmentInfo{
                .image_view = r.depth_image_view,
                .image_layout = .depth_stencil_attachment_optimal,
                .resolve_mode = .{},
                .resolve_image_view = .null_handle,
                .resolve_image_layout = .undefined,
                .load_op = .clear,
                .store_op = .dont_care,
                .clear_value = depth_clear,
            };

            const rendering_info = vk.RenderingInfo{
                .render_area = .{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = r.swapchain_extent,
                },
                .layer_count = 1,
                .view_mask = 0,
                .color_attachment_count = 1,
                .p_color_attachments = @as(?[*]const vk.RenderingAttachmentInfo, @ptrCast(&color_attachment)),
                .p_depth_attachment = &depth_attachment,
                .p_stencil_attachment = null,
            };

            // Begin dynamic rendering
            r.device.dispatch.vkCmdBeginRendering.?(command_buffer, &rendering_info);

            // Set viewport and scissor
            // Vulkan uses Y-down, so we flip the viewport
            const viewport = vk.Viewport{
                .x = 0.0,
                .y = @as(f32, @floatFromInt(r.swapchain_extent.height)),
                .width = @floatFromInt(r.swapchain_extent.width),
                .height = -@as(f32, @floatFromInt(r.swapchain_extent.height)),
                .min_depth = 0.0,
                .max_depth = 1.0,
            };
            r.device.dispatch.vkCmdSetViewport.?(command_buffer, 0, 1, @as([*]const vk.Viewport, @ptrCast(&viewport)));

            const scissor = vk.Rect2D{
                .offset = .{ .x = 0, .y = 0 },
                .extent = r.swapchain_extent,
            };
            r.device.dispatch.vkCmdSetScissor.?(command_buffer, 0, 1, @as([*]const vk.Rect2D, @ptrCast(&scissor)));

            // Bind the graphics pipeline
            if (r.pipeline != .null_handle) {
                r.device.dispatch.vkCmdBindPipeline.?(command_buffer, .graphics, r.pipeline);
            }

            // Render the vertex pool
            r.renderVertexPool(command_buffer) catch |err| {
                std.debug.print("Failed to render vertex pool: {}\n", .{err});
                return false;
            };

            // End dynamic rendering
            r.device.dispatch.vkCmdEndRendering.?(command_buffer);

            // Transition image to present src
            const present_barrier = vk.ImageMemoryBarrier{
                .src_access_mask = .{ .color_attachment_write_bit = true },
                .dst_access_mask = .{},
                .old_layout = .color_attachment_optimal,
                .new_layout = .present_src_khr,
                .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .image = r.swapchain_images.items[r.current_image_index],
                .subresource_range = .{
                    .aspect_mask = .{ .color_bit = true },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
            };

            r.device.dispatch.vkCmdPipelineBarrier.?(command_buffer, .{ .color_attachment_output_bit = true }, .{ .bottom_of_pipe_bit = true }, .{}, 0, null, 0, null, 1, @ptrCast(&present_barrier));

            // End command buffer recording
            _ = r.device.dispatch.vkEndCommandBuffer.?(command_buffer);

            // Submit the command buffer
            const wait_semaphores = [_]vk.Semaphore{r.image_available_semaphores[r.current_frame]};
            const wait_stages = [_]vk.PipelineStageFlags{.{ .color_attachment_output_bit = true }};
            const signal_semaphores = [_]vk.Semaphore{r.render_finished_semaphores[r.current_frame]};

            std.debug.print("Submitting command buffer with wait semaphore: {any}, signal semaphore: {any}\n", .{ r.image_available_semaphores[r.current_frame], r.render_finished_semaphores[r.current_frame] });

            const submit_info = vk.SubmitInfo{
                .wait_semaphore_count = wait_semaphores.len,
                .p_wait_semaphores = &wait_semaphores,
                .p_wait_dst_stage_mask = &wait_stages,
                .command_buffer_count = 1,
                .p_command_buffers = @ptrCast(&command_buffer),
                .signal_semaphore_count = signal_semaphores.len,
                .p_signal_semaphores = &signal_semaphores,
            };

            // Reset the fence before submitting
            _ = r.device.dispatch.vkResetFences.?(r.device.device, 1, @ptrCast(&r.in_flight_fences[r.current_frame]));

            const submit_result = r.device.dispatch.vkQueueSubmit.?(r.device.graphics_queue, 1, @ptrCast(&submit_info), r.in_flight_fences[r.current_frame]);

            if (submit_result != .success) {
                std.debug.print("Failed to submit command buffer: {}\n", .{submit_result});
                r.image_acquired = false;
                return false;
            }

            return true;
        }
    }
    return false;
}

pub export fn renderer_end_frame(renderer: ?*Renderer) bool {
    if (renderer == null) {
        std.debug.print("Error: renderer is null in end_frame\n", .{});
        return false;
    }

    if (renderer) |r| {
        // Don't present if we don't have a valid image or if it wasn't properly acquired
        if (r.current_image_index == std.math.maxInt(u32) or !r.image_acquired) {
            std.debug.print("No valid image to present. Recreating swapchain...\n", .{});

            // Wait for device to be idle
            _ = r.device.dispatch.vkDeviceWaitIdle.?(r.device.device);

            // Recreate swapchain
            r.recreateSwapchain() catch |err| {
                std.debug.print("Failed to recreate swapchain: {}\n", .{err});
            };

            // Advance to next frame anyway
            r.current_frame = (r.current_frame + 1) % r.max_frames_in_flight;
            r.image_acquired = false; // Reset the flag
            return false;
        }

        // Present the frame
        const wait_semaphores = [_]vk.Semaphore{r.render_finished_semaphores[r.current_frame]};
        const swapchains = [_]vk.SwapchainKHR{r.swapchain};
        const image_indices = [_]u32{r.current_image_index};

        const present_info = vk.PresentInfoKHR{
            .wait_semaphore_count = wait_semaphores.len,
            .p_wait_semaphores = &wait_semaphores,
            .swapchain_count = swapchains.len,
            .p_swapchains = &swapchains,
            .p_image_indices = &image_indices,
            .p_results = null,
        };

        const present_result = r.device.dispatch.vkQueuePresentKHR.?(r.device.graphics_queue, &present_info);
        if (present_result == .error_out_of_date_khr or present_result == .suboptimal_khr) {
            std.debug.print("Swapchain outdated during present, recreating...\n", .{});
            // Wait for the device to be idle before recreating the swapchain
            _ = r.device.dispatch.vkDeviceWaitIdle.?(r.device.device);
            // Recreate swapchain
            r.recreateSwapchain() catch |err| {
                std.debug.print("Failed to recreate swapchain: {}\n", .{err});
            };
            // Wait a bit to ensure the swapchain is ready
            std.time.sleep(16 * std.time.ns_per_ms); // ~16ms (one frame at 60fps)
        } else if (present_result != .success) {
            std.debug.print("Failed to present frame with result: {}\n", .{present_result});
        }

        // Reset the image_acquired flag
        r.image_acquired = false;

        // Advance to next frame
        r.current_frame = (r.current_frame + 1) % r.max_frames_in_flight;
        return present_result == .success;
    }
    return false;
}

// Vertex pool module is imported at the top of the file

/// The instance is the connection between the application and the Vulkan library
/// It's the first thing that needs to be created when working with Vulkan
const Instance = struct {
    instance: vk.Instance,
    dispatch: vk.InstanceDispatch,

    // Extension names to enable
    const required_extensions = [_][*:0]const u8{
        // Common extensions
        // Platform-specific extensions can be added here
        "VK_KHR_win32_surface",
        "VK_KHR_surface",
    };

    /// Create a new Vulkan instance
    pub fn init(_: std.mem.Allocator) !Instance {
        // Load the Vulkan library
        std.debug.print("Loading vulkan base dispatch...\n", .{});
        // Initialize a new BaseDispatch - in vulkan-zig we can't use load() directly
        var vkb = vk.BaseDispatch{};

        // Manually load the first function we need
        vkb.vkGetInstanceProcAddr = @as(vk.PfnGetInstanceProcAddr, @ptrCast(getPlatformSpecificProcAddress("vkGetInstanceProcAddr")));

        if (vkb.vkGetInstanceProcAddr == null) {
            return error.FailedToLoadVulkan;
        }

        // Now load the CreateInstance function
        vkb.vkCreateInstance = @as(vk.PfnCreateInstance, @ptrCast(vkb.vkGetInstanceProcAddr.?(vk.Instance.null_handle, "vkCreateInstance")));

        if (vkb.vkCreateInstance == null) {
            return error.FailedToLoadVulkan;
        }

        vkb.vkEnumerateInstanceExtensionProperties = @as(vk.PfnEnumerateInstanceExtensionProperties, @ptrCast(vkb.vkGetInstanceProcAddr.?(vk.Instance.null_handle, "vkEnumerateInstanceExtensionProperties")));
        std.debug.print("Vulkan base dispatch loaded successfully\n", .{});

        // Set up the application info struct
        const app_info = vk.ApplicationInfo{
            .p_application_name = "Angelite",
            .application_version = 1,
            .p_engine_name = "Angelite Engine",
            .engine_version = 1 << 22,
            .api_version = @bitCast(vk.API_VERSION_1_3),
        };

        // Create the instance info struct
        const create_info = vk.InstanceCreateInfo{
            .p_application_info = &app_info,
            .enabled_extension_count = @intCast(required_extensions.len),
            .pp_enabled_extension_names = &required_extensions,
            // Enable validation layers in debug mode
            .enabled_layer_count = if (std.debug.runtime_safety) @as(u32, 1) else 0,
            .pp_enabled_layer_names = if (std.debug.runtime_safety)
                &[_][*:0]const u8{"VK_LAYER_KHRONOS_validation"}
            else
                undefined,
        };

        // Create the Vulkan instance
        std.debug.print("Creating vulkan instance...\n", .{});
        var instance: vk.Instance = undefined;
        try checkSuccess(vkb.vkCreateInstance.?(&create_info, null, &instance));
        std.debug.print("Vulkan instance created successfully\n", .{});

        // Load instance-level function pointers
        std.debug.print("Loading instance dispatch...\n", .{});

        // Create a new instance dispatch table
        const dispatch = try loadInstanceDispatch(instance, vkb.vkGetInstanceProcAddr.?);
        std.debug.print("Instance dispatch loaded successfully\n", .{});

        return Instance{
            .instance = instance,
            .dispatch = dispatch,
        };
    }

    pub fn loadInstanceDispatch(instance: vk.Instance, proc: vk.PfnGetInstanceProcAddr) !vk.InstanceDispatch {
        var dispatch: vk.InstanceDispatch = .{};

        const InstanceDispatchType = @TypeOf(dispatch);
        inline for (@typeInfo(InstanceDispatchType).@"struct".fields) |field| {
            std.debug.print("Loading instance function: {s}\n", .{field.name});
            const name = @as([*:0]const u8, @ptrCast(field.name));
            if (proc(instance, name)) |set| {
                @field(dispatch, field.name) = @ptrCast(set);
            }
        }

        return dispatch;
    }

    /// Clean up the Vulkan instance
    pub fn deinit(self: Instance) void {
        if (self.dispatch.vkDestroyInstance) |destroyInstance| {
            destroyInstance(self.instance, null);
        }
    }
};

/// A physical device (GPU) available on the system
const PhysicalDevice = struct {
    handle: vk.PhysicalDevice,
    properties: vk.PhysicalDeviceProperties,
    features: vk.PhysicalDeviceFeatures,
    memory_properties: vk.PhysicalDeviceMemoryProperties,
    graphics_queue_family: u32,
};

/// The logical device is our connection to a physical device
/// Device struct for managing logical device functions
pub const Device = struct {
    physical_device: PhysicalDevice,
    device: vk.Device,
    dispatch: vk.DeviceDispatch,
    graphics_queue: vk.Queue,
    graphics_queue_family: u32,

    /// Load device-specific function pointers
    pub fn loadDeviceDispatch(device: vk.Device, instance_dispatch: vk.InstanceDispatch) !vk.DeviceDispatch {
        var dispatch: vk.DeviceDispatch = .{};

        // Load device functions using vkGetDeviceProcAddr
        const DeviceDispatchType = @TypeOf(dispatch);
        inline for (@typeInfo(DeviceDispatchType).@"struct".fields) |field| {
            std.debug.print("Loading device function: {s}\n", .{field.name});
            const name = @as([*:0]const u8, @ptrCast(field.name));
            if (instance_dispatch.vkGetDeviceProcAddr.?(device, name)) |proc| {
                @field(dispatch, field.name) = @ptrCast(proc);
            }
        }

        return dispatch;
    }

    /// Create a new logical device
    pub fn init(allocator: std.mem.Allocator, instance: Instance) !Device {
        // Find a suitable physical device
        std.debug.print("Initializing Vulkan renderer...\n", .{});
        const physical_device = try pickPhysicalDevice(allocator, instance);

        // Device queue create info
        const queue_create_info = [_]vk.DeviceQueueCreateInfo{
            .{
                .queue_family_index = physical_device.graphics_queue_family,
                .queue_count = 1,
                .p_queue_priorities = &[_]f32{1.0},
            },
        };

        // Required device extensions
        const device_extensions = [_][*:0]const u8{
            "VK_KHR_swapchain",
            "VK_KHR_dynamic_rendering",
        };

        // Enable dynamic rendering feature
        const dynamic_rendering_features = vk.PhysicalDeviceDynamicRenderingFeatures{
            .s_type = vk.StructureType.physical_device_dynamic_rendering_features,
            .p_next = null,
            .dynamic_rendering = vk.TRUE,
        };

        // Create the logical device
        const device_create_info = vk.DeviceCreateInfo{
            .s_type = vk.StructureType.device_create_info,
            .p_next = &dynamic_rendering_features,
            .queue_create_info_count = queue_create_info.len,
            .p_queue_create_infos = &queue_create_info,
            .enabled_extension_count = device_extensions.len,
            .pp_enabled_extension_names = &device_extensions,
            .p_enabled_features = &physical_device.features,
        };

        var device: vk.Device = undefined;
        std.debug.print("Initializing Vulkan renderer512...\n", .{});
        try checkSuccess(instance.dispatch.vkCreateDevice.?(physical_device.handle, &device_create_info, null, &device));

        // Load device-level function pointers
        std.debug.print("Initializing Vulkan renderer...\n", .{});
        const dispatch = try loadDeviceDispatch(device, instance.dispatch);

        // Get the graphics queue
        var graphics_queue: vk.Queue = undefined;
        std.debug.print("Initializing Vulkan renderer...\n", .{});
        dispatch.vkGetDeviceQueue.?(device, physical_device.graphics_queue_family, 0, &graphics_queue);

        return Device{
            .physical_device = physical_device,
            .device = device,
            .dispatch = dispatch,
            .graphics_queue = graphics_queue,
            .graphics_queue_family = physical_device.graphics_queue_family,
        };
    }

    /// Clean up the logical device
    /// Clean up the Device
    pub fn deinit(self: Device) void {
        if (self.dispatch.vkDestroyDevice) |destroyDevice| {
            destroyDevice(self.device, null);
        }
    }
};

/// Helper function to pick a suitable physical device
fn pickPhysicalDevice(allocator: std.mem.Allocator, instance: Instance) !PhysicalDevice {
    // Enumerate physical devices
    var device_count: u32 = 0;
    std.debug.print("Initializing Vulkan renderer...\n", .{});
    std.debug.print("Enumerating physical devices...\n", .{});
    try checkSuccess(instance.dispatch.vkEnumeratePhysicalDevices.?(instance.instance, &device_count, null));
    std.debug.print("Found {} physical devices\n", .{device_count});

    if (device_count == 0) {
        return error.NoVulkanDevices;
    }

    const devices = try allocator.alloc(vk.PhysicalDevice, device_count);
    defer allocator.free(devices);

    std.debug.print("Initializing Vulkan renderer...\n", .{});
    try checkSuccess(instance.dispatch.vkEnumeratePhysicalDevices.?(instance.instance, &device_count, devices.ptr));

    // For now, just pick the first device
    const selected_device = devices[0];

    // Get device properties and features
    var properties: vk.PhysicalDeviceProperties = undefined;
    var features: vk.PhysicalDeviceFeatures = undefined;
    var memory_properties: vk.PhysicalDeviceMemoryProperties = undefined;

    std.debug.print("Initializing Vulkan renderer...\n", .{});
    _ = instance.dispatch.vkGetPhysicalDeviceProperties.?(selected_device, &properties);
    _ = instance.dispatch.vkGetPhysicalDeviceFeatures.?(selected_device, &features);
    _ = instance.dispatch.vkGetPhysicalDeviceMemoryProperties.?(selected_device, &memory_properties);

    // Find graphics queue family
    var queue_family_count: u32 = 0;
    _ = instance.dispatch.vkGetPhysicalDeviceQueueFamilyProperties.?(selected_device, &queue_family_count, null);

    const queue_families = try allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
    defer allocator.free(queue_families);

    std.debug.print("Initializing Vulkan renderer...\n", .{});
    _ = instance.dispatch.vkGetPhysicalDeviceQueueFamilyProperties.?(selected_device, &queue_family_count, queue_families.ptr);

    // Find a queue family that supports graphics
    var graphics_queue_family: ?u32 = null;
    for (queue_families, 0..) |queue_props, i| {
        if (queue_props.queue_flags.graphics_bit) {
            graphics_queue_family = @intCast(i);
            break;
        }
    }

    if (graphics_queue_family == null) {
        return error.NoGraphicsQueue;
    }

    return PhysicalDevice{
        .handle = selected_device,
        .properties = properties,
        .features = features,
        .memory_properties = memory_properties,
        .graphics_queue_family = graphics_queue_family.?,
    };
}

/// Check a Vulkan result and return an error if it's not success
fn checkSuccess(result: anytype) !void {
    if (result != .success) {
        std.debug.print("Vulkan error: {any}\n", .{result});
        return error.VulkanError;
    }
}

/// Function to get Vulkan function pointers
fn getProcAddress(instance: vk.Instance, name: [*:0]const u8) vk.PfnVoidFunction {
    // If we have a valid instance, try to get instance-specific functions
    if (instance != .null_handle) {
        if (@hasDecl(vk, "vkGetInstanceProcAddr")) {
            const func = vk.vkGetInstanceProcAddr(instance, name);
            if (func != null) {
                return func;
            }
        }
    }

    // Otherwise use the platform-specific approach
    return @as(vk.PfnVoidFunction, @ptrCast(getPlatformSpecificProcAddress(name)));
}

// Windows-specific implementation for loading Vulkan functions
fn getPlatformSpecificProcAddress(name: [*:0]const u8) ?*const anyopaque {
    const windows = struct {
        const HMODULE = *opaque {};
        const LPCSTR = [*:0]const u8;
        const FARPROC = *const anyopaque;

        extern "kernel32" fn LoadLibraryA(lpLibFileName: LPCSTR) ?HMODULE;
        extern "kernel32" fn GetProcAddress(hModule: HMODULE, lpProcName: LPCSTR) ?FARPROC;
    };

    // Load the Vulkan library if not already loaded
    const vulkan_dll_name = "vulkan-1.dll";

    // Use thread-local static storage for the handle to avoid reloading
    const vulkan_handle = blk: {
        const ThreadLocal = struct {
            var handle: ?windows.HMODULE = null;
        };

        if (ThreadLocal.handle == null) {
            ThreadLocal.handle = windows.LoadLibraryA(vulkan_dll_name);
            if (ThreadLocal.handle == null) {
                std.debug.print("Failed to load {s}\n", .{vulkan_dll_name});
                return null;
            }
        }

        break :blk ThreadLocal.handle.?;
    };

    // Get the function pointer
    const proc_addr = windows.GetProcAddress(vulkan_handle, name);
    if (proc_addr == null) {
        // This is expected for some functions, so no need to log every time
        // std.debug.print("Failed to get proc address for {s}\n", .{name});
    }

    return proc_addr;
}

/// Main renderer that manages the Vulkan instance and device
pub const Renderer = struct {
    allocator: std.mem.Allocator,
    instance: Instance,
    device: Device,
    vertex_pool: ?vertex_pool.VertexPool = null,

    // Pipeline resources
    pipeline_layout: vk.PipelineLayout = .null_handle,
    pipeline: vk.Pipeline = .null_handle,
    command_pool: vk.CommandPool = .null_handle,

    // Shader modules
    vertex_shader_module: vk.ShaderModule = .null_handle,
    geometry_shader_module: vk.ShaderModule = .null_handle,
    fragment_shader_module: vk.ShaderModule = .null_handle,

    // Swapchain resources
    surface: vk.SurfaceKHR = .null_handle,
    swapchain: vk.SwapchainKHR = .null_handle,
    swapchain_images: std.ArrayList(vk.Image),
    swapchain_image_views: std.ArrayList(vk.ImageView),
    swapchain_extent: vk.Extent2D = .{ .width = 800, .height = 600 },
    swapchain_format: vk.Format = .b8g8r8a8_unorm,

    // Depth buffer resources
    depth_image: vk.Image = .null_handle,
    depth_image_memory: vk.DeviceMemory = .null_handle,
    depth_image_view: vk.ImageView = .null_handle,
    depth_format: vk.Format = .d32_sfloat,

    // Synchronization primitives
    image_available_semaphores: [2]vk.Semaphore = .{ .null_handle, .null_handle },
    render_finished_semaphores: [2]vk.Semaphore = .{ .null_handle, .null_handle },
    in_flight_fences: [2]vk.Fence = .{ .null_handle, .null_handle },

    // Command buffers
    command_buffers: [2]vk.CommandBuffer = .{ .null_handle, .null_handle },

    // Frame management
    current_frame: usize = 0,
    max_frames_in_flight: usize = 2,
    current_image_index: u32 = 0, // Set to maxInt(u32) if no valid image
    image_acquired: bool = false, // Flag indicating if the image was successfully acquired

    // Main camera reference
    main_camera: ?*Camera = null,

    /// Initialize the Vulkan renderer
    pub fn init(allocator: std.mem.Allocator, surface_raw: ?*const anyopaque) !Renderer {
        std.debug.print("Internal Renderer.init called with surface_raw: {*}\n", .{surface_raw});
        var instance = try Instance.init(allocator);
        errdefer instance.deinit();

        var device = try Device.init(allocator, instance);
        errdefer device.deinit();

        var renderer = Renderer{
            .allocator = allocator,
            .instance = instance,
            .device = device,
            .swapchain_images = std.ArrayList(vk.Image).init(allocator),
            .swapchain_image_views = std.ArrayList(vk.ImageView).init(allocator),
        };

        try renderer.createSurface(surface_raw);
        if (renderer.surface == .null_handle) {
            return error.SurfaceCreationFailed;
        }
        try renderer.createSwapchain(.null_handle);
        try renderer.createDepthResources();
        try renderer.createRenderingResources();
        try renderer.createSynchronizationObjects();

        return renderer;
    }

    /// Initialize the vertex pool
    pub fn initVertexPool(self: *Renderer, buffer_count: u32, vertex_per_buffer: u32, max_draw_commands: u32) !void {
        if (self.vertex_pool != null) {
            return error.VertexPoolAlreadyInitialized;
        }

        // Create command pool first (needed for buffer operations)
        const command_pool_info = vk.CommandPoolCreateInfo{
            .queue_family_index = self.device.graphics_queue_family,
            .flags = .{ .reset_command_buffer_bit = true },
        };

        var pool: vk.CommandPool = undefined;
        if (self.device.dispatch.vkCreateCommandPool.?(self.device.device, &command_pool_info, null, &pool) != .success) {
            return error.FailedToCreateCommandPool;
        }
        self.command_pool = pool;
        std.debug.print("Created command pool in initVertexPool: {any}\n", .{self.command_pool});

        // Create command buffers - even if this fails, continue initialization
        self.createCommandBuffers() catch |err| {
            std.debug.print("Warning: Failed to create command buffers in initVertexPool: {} - will try again later\n", .{err});
        };

        // Create basic rendering resources
        try self.createRenderingResources();

        // Initialize vertex pool
        self.vertex_pool = try vertex_pool.VertexPool.init(self.allocator, self.device.device, self.device.physical_device.handle, self.device.dispatch, self.instance.dispatch, self.command_pool, self.device.graphics_queue, buffer_count, vertex_per_buffer, max_draw_commands);
    }

    fn loadShaderModule(self: *Renderer, comptime path: []const u8) !vk.ShaderModule {
        const shader_code = @embedFile(path);

        const create_info = vk.ShaderModuleCreateInfo{
            .code_size = shader_code.len,
            .p_code = @ptrCast(@alignCast(shader_code.ptr)),
        };

        var shader_module: vk.ShaderModule = .null_handle;
        const result = self.device.dispatch.vkCreateShaderModule.?(self.device.device, &create_info, null, &shader_module);

        if (result != .success) {
            return error.ShaderModuleCreationFailed;
        }

        return shader_module;
    }

    fn createRenderingResources(self: *Renderer) !void {

        // Create pipeline layout with push constants for vertex and geometry shaders
        const push_constant_range = vk.PushConstantRange{
            .stage_flags = .{ .vertex_bit = true, .geometry_bit = true },
            .offset = 0,
            .size = 128, // 2 mat4 matrices (viewMatrix + projMatrix) = 2 * 64 bytes = 128 bytes
        };

        const pipeline_layout_info = vk.PipelineLayoutCreateInfo{
            .set_layout_count = 0,
            .p_set_layouts = undefined,
            .push_constant_range_count = 1,
            .p_push_constant_ranges = @as(?[*]const vk.PushConstantRange, @ptrCast(&push_constant_range)),
        };

        _ = self.device.dispatch.vkCreatePipelineLayout.?(self.device.device, &pipeline_layout_info, null, &self.pipeline_layout);

        // Load shader modules
        self.vertex_shader_module = try self.loadShaderModule("ultra.vert.spirv");
        self.geometry_shader_module = try self.loadShaderModule("ultra.geom.spirv");
        self.fragment_shader_module = try self.loadShaderModule("ultra.frag.spirv");

        // Create a basic graphics pipeline
        // This is a simplified implementation that would need to be expanded with proper
        // shader modules for a real application

        // In a real application, you would load shader modules from files
        // For now, we'll create a very basic vertex shader and fragment shader

        // Vertex input state - describes the format of the vertex data
        const vertex_input_binding_description = vk.VertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(vertex_pool.Vertex),
            .input_rate = .vertex,
        };

        // Position attribute
        const vertex_input_attribute_descriptions = [_]vk.VertexInputAttributeDescription{
            // Position
            .{
                .binding = 0,
                .location = 0,
                .format = .r32g32b32_sfloat,
                .offset = @offsetOf(vertex_pool.Vertex, "position"),
            },
            // Normal direction
            .{
                .binding = 0,
                .location = 1,
                .format = .r32_uint,
                .offset = @offsetOf(vertex_pool.Vertex, "normal_dir"),
            },
            // Color
            .{
                .binding = 0,
                .location = 2,
                .format = .r32g32b32a32_sfloat,
                .offset = @offsetOf(vertex_pool.Vertex, "color"),
            },
        };

        const vertex_input_state_create_info = vk.PipelineVertexInputStateCreateInfo{
            .vertex_binding_description_count = 1,
            .p_vertex_binding_descriptions = @as(?[*]const vk.VertexInputBindingDescription, @ptrCast(&vertex_input_binding_description)),
            .vertex_attribute_description_count = vertex_input_attribute_descriptions.len,
            .p_vertex_attribute_descriptions = &vertex_input_attribute_descriptions,
        };

        // Input assembly state - describes what kind of primitives to render
        const input_assembly_state_create_info = vk.PipelineInputAssemblyStateCreateInfo{
            .topology = .point_list, // Points for geometry shader input
            .primitive_restart_enable = vk.FALSE,
        };

        // Viewport state - describes the viewport and scissors
        const viewport = vk.Viewport{
            .x = 0.0,
            .y = 0.0,
            .width = 800.0, // Would use swapchain extent in a real app
            .height = 600.0, // Would use swapchain extent in a real app
            .min_depth = 0.0,
            .max_depth = 1.0,
        };

        const scissor = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = 800, .height = 600 }, // Would use swapchain extent in a real app
        };

        const viewport_state_create_info = vk.PipelineViewportStateCreateInfo{
            .viewport_count = 1,
            .p_viewports = @as(?[*]const vk.Viewport, @ptrCast(&viewport)),
            .scissor_count = 1,
            .p_scissors = @as(?[*]const vk.Rect2D, @ptrCast(&scissor)),
        };

        // Rasterization state - describes how to rasterize primitives
        const rasterization_state_create_info = vk.PipelineRasterizationStateCreateInfo{
            .depth_clamp_enable = vk.FALSE,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = .fill,
            .cull_mode = .{}, // Disable culling to see all faces
            .front_face = .counter_clockwise,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0.0,
            .depth_bias_clamp = 0.0,
            .depth_bias_slope_factor = 0.0,
            .line_width = 1.0,
        };

        // Multisample state - describes multisampling parameters
        const multisample_state_create_info = vk.PipelineMultisampleStateCreateInfo{
            .rasterization_samples = .{ .@"1_bit" = true },
            .sample_shading_enable = vk.FALSE,
            .min_sample_shading = 1.0,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };

        // Depth and stencil state - describes depth and stencil testing
        const depth_stencil_state_create_info = vk.PipelineDepthStencilStateCreateInfo{
            .depth_test_enable = vk.TRUE,
            .depth_write_enable = vk.TRUE,
            .depth_compare_op = .less,
            .depth_bounds_test_enable = vk.FALSE,
            .stencil_test_enable = vk.FALSE,
            .front = .{
                .fail_op = .keep,
                .pass_op = .keep,
                .depth_fail_op = .keep,
                .compare_op = .always,
                .compare_mask = 0,
                .write_mask = 0,
                .reference = 0,
            },
            .back = .{
                .fail_op = .keep,
                .pass_op = .keep,
                .depth_fail_op = .keep,
                .compare_op = .always,
                .compare_mask = 0,
                .write_mask = 0,
                .reference = 0,
            },
            .min_depth_bounds = 0.0,
            .max_depth_bounds = 1.0,
        };

        // Color blend state - describes how to blend colors
        const color_blend_attachment_state = vk.PipelineColorBlendAttachmentState{
            .blend_enable = vk.TRUE,
            .src_color_blend_factor = .src_alpha,
            .dst_color_blend_factor = .one_minus_src_alpha,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
        };

        const color_blend_state_create_info = vk.PipelineColorBlendStateCreateInfo{
            .logic_op_enable = vk.FALSE,
            .logic_op = .copy,
            .attachment_count = 1,
            .p_attachments = @as(?[*]const vk.PipelineColorBlendAttachmentState, @ptrCast(&color_blend_attachment_state)),
            .blend_constants = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        };

        // Create shader stage create infos
        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
            .{
                .stage = .{ .vertex_bit = true },
                .module = self.vertex_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
            .{
                .stage = .{ .geometry_bit = true },
                .module = self.geometry_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
            .{
                .stage = .{ .fragment_bit = true },
                .module = self.fragment_shader_module,
                .p_name = "main",
                .p_specialization_info = null,
            },
        };

        // Dynamic state - viewport and scissor will be set at draw time
        const dynamic_states = [_]vk.DynamicState{ .viewport, .scissor };
        const dynamic_state_create_info = vk.PipelineDynamicStateCreateInfo{
            .dynamic_state_count = dynamic_states.len,
            .p_dynamic_states = &dynamic_states,
        };

        // Dynamic rendering info for pipeline creation
        const color_attachment_format = [_]vk.Format{self.swapchain_format};
        const pipeline_rendering_create_info = vk.PipelineRenderingCreateInfo{
            .view_mask = 0,
            .color_attachment_count = 1,
            .p_color_attachment_formats = &color_attachment_format,
            .depth_attachment_format = self.depth_format,
            .stencil_attachment_format = .undefined,
        };

        // Create the graphics pipeline with dynamic rendering
        const pipeline_create_info = vk.GraphicsPipelineCreateInfo{
            .p_next = &pipeline_rendering_create_info,
            .stage_count = shader_stages.len,
            .p_stages = &shader_stages,
            .p_vertex_input_state = &vertex_input_state_create_info,
            .p_input_assembly_state = &input_assembly_state_create_info,
            .p_viewport_state = &viewport_state_create_info,
            .p_rasterization_state = &rasterization_state_create_info,
            .p_multisample_state = &multisample_state_create_info,
            .p_depth_stencil_state = &depth_stencil_state_create_info,
            .p_color_blend_state = &color_blend_state_create_info,
            .p_dynamic_state = &dynamic_state_create_info,
            .layout = self.pipeline_layout,
            .render_pass = .null_handle, // Not used with dynamic rendering
            .subpass = 0,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        };

        const result = self.device.dispatch.vkCreateGraphicsPipelines.?(
            self.device.device,
            .null_handle,
            1,
            @as([*]const vk.GraphicsPipelineCreateInfo, @ptrCast(&pipeline_create_info)),
            null,
            @as([*]vk.Pipeline, @ptrCast(&self.pipeline)),
        );

        if (result != .success) {
            return error.GraphicsPipelineCreationFailed;
        }

        // Only create command pool if we don't have one yet
        if (self.command_pool == .null_handle) {
            const command_pool_create_info = vk.CommandPoolCreateInfo{
                .queue_family_index = self.device.graphics_queue_family,
                .flags = .{ .reset_command_buffer_bit = true },
            };

            const command_pool_result = self.device.dispatch.vkCreateCommandPool.?(self.device.device, &command_pool_create_info, null, &self.command_pool);
            if (command_pool_result != .success) {
                return error.CommandPoolCreationFailed;
            }
        }

        // Allocate command buffers
        try self.createCommandBuffers();
    }

    /// Recreate the swapchain when it becomes outdated
    fn recreateSwapchain(self: *Renderer) !void {
        // Wait until device is idle
        _ = self.device.dispatch.vkDeviceWaitIdle.?(self.device.device);

        // Reset synchronization objects first
        for (0..self.max_frames_in_flight) |i| {
            if (self.in_flight_fences[i] != .null_handle) {
                _ = self.device.dispatch.vkResetFences.?(self.device.device, 1, @ptrCast(&self.in_flight_fences[i]));
            }
        }

        // Clean up old swapchain resources
        for (self.swapchain_image_views.items) |view| {
            self.device.dispatch.vkDestroyImageView.?(self.device.device, view, null);
        }
        self.swapchain_image_views.clearRetainingCapacity();

        // Clean up old depth resources
        if (self.depth_image_view != .null_handle) {
            self.device.dispatch.vkDestroyImageView.?(self.device.device, self.depth_image_view, null);
            self.depth_image_view = .null_handle;
        }
        if (self.depth_image != .null_handle) {
            self.device.dispatch.vkDestroyImage.?(self.device.device, self.depth_image, null);
            self.depth_image = .null_handle;
        }
        if (self.depth_image_memory != .null_handle) {
            self.device.dispatch.vkFreeMemory.?(self.device.device, self.depth_image_memory, null);
            self.depth_image_memory = .null_handle;
        }

        // Store old swapchain for proper cleanup
        const old_swapchain = self.swapchain;
        self.swapchain = .null_handle;

        // Destroy old pipeline that depends on the swapchain
        if (self.pipeline != .null_handle) {
            self.device.dispatch.vkDestroyPipeline.?(self.device.device, self.pipeline, null);
            self.pipeline = .null_handle;
        }

        if (self.pipeline_layout != .null_handle) {
            self.device.dispatch.vkDestroyPipelineLayout.?(self.device.device, self.pipeline_layout, null);
            self.pipeline_layout = .null_handle;
        }

        // Reset synchronization objects
        for (0..self.max_frames_in_flight) |i| {
            if (self.in_flight_fences[i] != .null_handle) {
                _ = self.device.dispatch.vkResetFences.?(self.device.device, 1, @as([*]vk.Fence, @ptrCast(&self.in_flight_fences[i])));
            }
        }

        // Create new swapchain (passing the old one for optimization)
        try self.createSwapchain(old_swapchain);

        // Destroy old swapchain now that new one is created
        if (old_swapchain != .null_handle) {
            self.device.dispatch.vkDestroySwapchainKHR.?(self.device.device, old_swapchain, null);
        }

        // Recreate depth resources with new swapchain extent
        try self.createDepthResources();

        // Recreate pipeline with new swapchain settings
        try self.createRenderingResources();

        // Recreate synchronization objects to ensure they're in a valid state
        try self.createSynchronizationObjects();

        // Reset state
        self.image_acquired = false;
        self.current_image_index = 0;

        // Reset command buffers to ensure they're recreated with the new swapchain
        try self.createCommandBuffers();
    }

    fn createSwapchain(self: *Renderer, old_swapchain: vk.SwapchainKHR) !void {
        // First, check if surface is valid
        if (self.surface == .null_handle) {
            std.debug.print("Cannot create swapchain: surface is null\n", .{});
            return error.NoSurface;
        }

        // Get surface capabilities
        var surface_capabilities: vk.SurfaceCapabilitiesKHR = undefined;
        const caps_result = self.instance.dispatch.vkGetPhysicalDeviceSurfaceCapabilitiesKHR.?(
            self.device.physical_device.handle,
            self.surface,
            &surface_capabilities,
        );

        if (caps_result != .success) {
            std.debug.print("Failed to get surface capabilities: {}\n", .{caps_result});
            return error.FailedToGetSurfaceCapabilities;
        }

        // Choose the swapchain extent based on surface capabilities
        if (surface_capabilities.current_extent.width == 0xFFFFFFFF) {
            // If current extent is undefined (special value), use the window size
            // but clamped to min/max extents
            self.swapchain_extent = .{
                .width = std.math.clamp(800, surface_capabilities.min_image_extent.width, surface_capabilities.max_image_extent.width),
                .height = std.math.clamp(600, surface_capabilities.min_image_extent.height, surface_capabilities.max_image_extent.height),
            };
        } else {
            // Otherwise use the current extent
            self.swapchain_extent = surface_capabilities.current_extent;
        }

        // Make sure extent is at least 1x1
        if (self.swapchain_extent.width == 0) self.swapchain_extent.width = 1;
        if (self.swapchain_extent.height == 0) self.swapchain_extent.height = 1;
        // Query surface formats
        var format_count: u32 = 0;
        const format_count_result = self.instance.dispatch.vkGetPhysicalDeviceSurfaceFormatsKHR.?(self.device.physical_device.handle, self.surface, &format_count, null);

        if (format_count_result != .success) {
            std.debug.print("Failed to get surface format count: {}\n", .{format_count_result});
            return error.FailedToGetSurfaceFormats;
        }

        std.debug.print("Found {} surface formats\n", .{format_count});

        if (format_count == 0) {
            std.debug.print("No surface formats available\n", .{});
            return error.NoSurfaceFormatsAvailable;
        }

        const surface_formats = try self.allocator.alloc(vk.SurfaceFormatKHR, format_count);
        defer self.allocator.free(surface_formats);
        const get_formats_result = self.instance.dispatch.vkGetPhysicalDeviceSurfaceFormatsKHR.?(self.device.physical_device.handle, self.surface, &format_count, surface_formats.ptr);

        if (get_formats_result != .success) {
            std.debug.print("Failed to get surface formats: {}\n", .{get_formats_result});
            return error.FailedToGetSurfaceFormats;
        }

        if (format_count == 0) {
            std.debug.print("No surface formats available\n", .{});
            return error.NoSurfaceFormatsAvailable;
        }

        // Choose surface format - prefer BGRA8 with sRGB if available
        var surface_format: vk.SurfaceFormatKHR = undefined;
        var found_preferred_format = false;

        for (surface_formats) |format| {
            if (format.format == .b8g8r8a8_unorm and format.color_space == .srgb_nonlinear_khr) {
                surface_format = format;
                found_preferred_format = true;
                break;
            }
        }

        if (!found_preferred_format) {
            surface_format = surface_formats[0];
        }

        std.debug.print("Selected format: {}, color space: {}\n", .{ surface_format.format, surface_format.color_space });

        self.swapchain_format = surface_format.format;
        // Use the extent we already set above

        // Query present modes
        // Choose present mode
        var present_mode_count: u32 = 0;
        const present_mode_count_result = self.instance.dispatch.vkGetPhysicalDeviceSurfacePresentModesKHR.?(
            self.device.physical_device.handle,
            self.surface,
            &present_mode_count,
            null,
        );

        if (present_mode_count_result != .success) {
            std.debug.print("Failed to get present mode count: {}\n", .{present_mode_count_result});
            return error.FailedToGetPresentModes;
        }

        if (present_mode_count == 0) {
            std.debug.print("No present modes available\n", .{});
            return error.NoPresentModesAvailable;
        }

        const present_modes = try self.allocator.alloc(vk.PresentModeKHR, present_mode_count);
        defer self.allocator.free(present_modes);
        _ = self.instance.dispatch.vkGetPhysicalDeviceSurfacePresentModesKHR.?(
            self.device.physical_device.handle,
            self.surface,
            &present_mode_count,
            present_modes.ptr,
        );

        // Choose present mode - prefer mailbox for triple buffering, fallback to FIFO which is guaranteed
        var present_mode: vk.PresentModeKHR = .fifo_khr;

        // Only choose mailbox if we're not on a mobile device to avoid battery drain
        const prefer_mailbox = true; // Set to false for mobile platforms

        if (prefer_mailbox) {
            for (present_modes) |mode| {
                if (mode == .mailbox_khr) {
                    present_mode = mode;
                    break;
                }
            }
        }

        // Determine image count - always try for triple buffering unless impossible
        var image_count = surface_capabilities.min_image_count + 1;
        if (surface_capabilities.max_image_count > 0 and image_count > surface_capabilities.max_image_count) {
            image_count = surface_capabilities.max_image_count;
        }

        std.debug.print("Creating swapchain with image count: {}, extent: {}x{}\n", .{ image_count, self.swapchain_extent.width, self.swapchain_extent.height });

        std.debug.print("Creating swapchain with extent: {}x{}\n", .{ self.swapchain_extent.width, self.swapchain_extent.height });

        // Create swapchain
        const swapchain_create_info = vk.SwapchainCreateInfoKHR{
            .surface = self.surface,
            .min_image_count = image_count,
            .image_format = surface_format.format,
            .image_color_space = surface_format.color_space,
            .image_extent = self.swapchain_extent,
            .image_array_layers = 1,
            .image_usage = .{ .color_attachment_bit = true, .transfer_dst_bit = true }, // Allow screenshots
            .image_sharing_mode = .exclusive,
            .queue_family_index_count = 1,
            .p_queue_family_indices = @ptrCast(&self.device.graphics_queue_family),
            .pre_transform = surface_capabilities.current_transform,
            .composite_alpha = .{ .opaque_bit_khr = true },
            .present_mode = present_mode,
            .clipped = vk.TRUE,
            .old_swapchain = old_swapchain, // Use old swapchain for better transitions
        };

        const swapchain_result = self.device.dispatch.vkCreateSwapchainKHR.?(self.device.device, &swapchain_create_info, null, &self.swapchain);
        if (swapchain_result != .success) {
            std.debug.print("Failed to create swapchain: {}\n", .{swapchain_result});
            return error.SwapchainCreationFailed;
        }

        std.debug.print("Successfully created swapchain: {any}\n", .{self.swapchain});

        // Get swapchain images
        var swapchain_image_count: u32 = 0;
        const get_count_result = self.device.dispatch.vkGetSwapchainImagesKHR.?(self.device.device, self.swapchain, &swapchain_image_count, null);

        if (get_count_result != .success) {
            std.debug.print("Failed to get swapchain image count: {}\n", .{get_count_result});
            return error.FailedToGetSwapchainImages;
        }

        std.debug.print("Swapchain has {} images\n", .{swapchain_image_count});

        if (swapchain_image_count == 0) {
            std.debug.print("No swapchain images available\n", .{});
            return error.NoSwapchainImages;
        }

        try self.swapchain_images.resize(swapchain_image_count);

        const get_images_result = self.device.dispatch.vkGetSwapchainImagesKHR.?(self.device.device, self.swapchain, &swapchain_image_count, self.swapchain_images.items.ptr);

        if (get_images_result != .success) {
            std.debug.print("Failed to get swapchain images: {}\n", .{get_images_result});
            return error.FailedToGetSwapchainImages;
        }
        // Images already retrieved in the previous call

        // Create image views
        try self.swapchain_image_views.resize(swapchain_image_count);
        std.debug.print("Creating {} image views\n", .{swapchain_image_count});
        for (self.swapchain_images.items, 0..) |image, i| {
            const view_create_info = vk.ImageViewCreateInfo{
                .image = image,
                .view_type = .@"2d",
                .format = self.swapchain_format,
                .components = .{
                    .r = .identity,
                    .g = .identity,
                    .b = .identity,
                    .a = .identity,
                },
                .subresource_range = .{
                    .aspect_mask = .{ .color_bit = true },
                    .base_mip_level = 0,
                    .level_count = 1,
                    .base_array_layer = 0,
                    .layer_count = 1,
                },
            };

            const create_view_result = self.device.dispatch.vkCreateImageView.?(self.device.device, &view_create_info, null, &self.swapchain_image_views.items[i]);

            if (create_view_result != .success) {
                std.debug.print("Failed to create image view {}: {}\n", .{ i, create_view_result });
                return error.FailedToCreateImageView;
            }
        }
    }

    fn createDepthResources(self: *Renderer) !void {
        // Find a suitable depth format
        const depth_formats = [_]vk.Format{ .d32_sfloat, .d32_sfloat_s8_uint, .d24_unorm_s8_uint };

        var format_found = false;
        for (depth_formats) |format| {
            var format_properties: vk.FormatProperties = undefined;
            self.instance.dispatch.vkGetPhysicalDeviceFormatProperties.?(self.device.physical_device.handle, format, &format_properties);

            if (format_properties.optimal_tiling_features.depth_stencil_attachment_bit) {
                self.depth_format = format;
                format_found = true;
                break;
            }
        }

        if (!format_found) {
            return error.NoSuitableDepthFormat;
        }

        // Create depth image
        const image_create_info = vk.ImageCreateInfo{
            .image_type = .@"2d",
            .extent = .{
                .width = self.swapchain_extent.width,
                .height = self.swapchain_extent.height,
                .depth = 1,
            },
            .mip_levels = 1,
            .array_layers = 1,
            .format = self.depth_format,
            .tiling = .optimal,
            .initial_layout = .undefined,
            .usage = .{ .depth_stencil_attachment_bit = true },
            .sharing_mode = .exclusive,
            .samples = .{ .@"1_bit" = true },
            .flags = .{},
        };

        if (self.device.dispatch.vkCreateImage.?(self.device.device, &image_create_info, null, &self.depth_image) != .success) {
            return error.FailedToCreateDepthImage;
        }

        // Get memory requirements
        var mem_requirements: vk.MemoryRequirements = undefined;
        self.device.dispatch.vkGetImageMemoryRequirements.?(self.device.device, self.depth_image, &mem_requirements);

        // Find suitable memory type
        var memory_type_index: ?u32 = null;
        const memory_properties = self.device.physical_device.memory_properties;

        for (0..memory_properties.memory_type_count) |i| {
            if ((mem_requirements.memory_type_bits & (@as(u32, 1) << @intCast(i))) != 0 and
                memory_properties.memory_types[i].property_flags.device_local_bit)
            {
                memory_type_index = @intCast(i);
                break;
            }
        }

        if (memory_type_index == null) {
            return error.NoSuitableMemoryType;
        }

        // Allocate memory
        const alloc_info = vk.MemoryAllocateInfo{
            .allocation_size = mem_requirements.size,
            .memory_type_index = memory_type_index.?,
        };

        if (self.device.dispatch.vkAllocateMemory.?(self.device.device, &alloc_info, null, &self.depth_image_memory) != .success) {
            return error.FailedToAllocateDepthImageMemory;
        }

        // Bind memory to image
        if (self.device.dispatch.vkBindImageMemory.?(self.device.device, self.depth_image, self.depth_image_memory, 0) != .success) {
            return error.FailedToBindDepthImageMemory;
        }

        // Create image view
        const view_create_info = vk.ImageViewCreateInfo{
            .image = self.depth_image,
            .view_type = .@"2d",
            .format = self.depth_format,
            .components = .{
                .r = .identity,
                .g = .identity,
                .b = .identity,
                .a = .identity,
            },
            .subresource_range = .{
                .aspect_mask = .{ .depth_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        };

        if (self.device.dispatch.vkCreateImageView.?(self.device.device, &view_create_info, null, &self.depth_image_view) != .success) {
            return error.FailedToCreateDepthImageView;
        }
    }

    fn createCommandBuffers(self: *Renderer) !void {
        // Wait for device to be idle before manipulating command buffers
        _ = self.device.dispatch.vkDeviceWaitIdle.?(self.device.device);

        // Ensure we have a valid command pool
        if (self.command_pool == .null_handle) {
            std.debug.print("Creating new command pool for command buffer allocation\n", .{});
            const command_pool_create_info = vk.CommandPoolCreateInfo{
                .queue_family_index = self.device.graphics_queue_family,
                .flags = .{ .transient_bit = true, .reset_command_buffer_bit = true },
            };

            var pool: vk.CommandPool = undefined;
            if (self.device.dispatch.vkCreateCommandPool.?(self.device.device, &command_pool_create_info, null, &pool) != .success) {
                return error.CommandPoolCreationFailed;
            }
            self.command_pool = pool;
            std.debug.print("Created new command pool: {any}\n", .{self.command_pool});
        }

        // Free any existing command buffers first - only if they were previously allocated
        // Important: Only free if we have a valid handle to avoid validation errors
        if (self.command_buffers[0] != .null_handle) {
            // Reset command buffers to null to avoid freeing from wrong pool
            for (0..self.max_frames_in_flight) |i| {
                self.command_buffers[i] = .null_handle;
            }
        }

        const allocate_info = vk.CommandBufferAllocateInfo{
            .command_pool = self.command_pool,
            .level = .primary,
            .command_buffer_count = @intCast(self.max_frames_in_flight),
        };

        const command_buffer_result = self.device.dispatch.vkAllocateCommandBuffers.?(self.device.device, &allocate_info, &self.command_buffers);

        if (command_buffer_result != .success) {
            std.debug.print("Failed to allocate command buffers: {}\n", .{command_buffer_result});
            return error.CommandBufferAllocationFailed;
        }

        std.debug.print("Successfully allocated {} command buffers from pool {any}\n", .{ self.max_frames_in_flight, self.command_pool });
    }

    fn createSynchronizationObjects(self: *Renderer) !void {
        // Wait for device to be idle
        _ = self.device.dispatch.vkDeviceWaitIdle.?(self.device.device);

        // Destroy existing synchronization objects if they exist
        for (0..self.max_frames_in_flight) |i| {
            if (self.image_available_semaphores[i] != .null_handle) {
                self.device.dispatch.vkDestroySemaphore.?(self.device.device, self.image_available_semaphores[i], null);
                self.image_available_semaphores[i] = .null_handle;
            }
            if (self.render_finished_semaphores[i] != .null_handle) {
                self.device.dispatch.vkDestroySemaphore.?(self.device.device, self.render_finished_semaphores[i], null);
                self.render_finished_semaphores[i] = .null_handle;
            }
            if (self.in_flight_fences[i] != .null_handle) {
                self.device.dispatch.vkDestroyFence.?(self.device.device, self.in_flight_fences[i], null);
                self.in_flight_fences[i] = .null_handle;
            }
        }

        const semaphore_info = vk.SemaphoreCreateInfo{};
        const fence_info = vk.FenceCreateInfo{
            .flags = .{ .signaled_bit = true }, // Create fences in signaled state so first frame doesn't wait indefinitely
        };

        for (0..self.max_frames_in_flight) |i| {
            const image_semaphore_result = self.device.dispatch.vkCreateSemaphore.?(self.device.device, &semaphore_info, null, &self.image_available_semaphores[i]);

            if (image_semaphore_result != .success) {
                std.debug.print("Failed to create image available semaphore {}: {}\n", .{ i, image_semaphore_result });
                return error.FailedToCreateSemaphore;
            }

            const render_semaphore_result = self.device.dispatch.vkCreateSemaphore.?(self.device.device, &semaphore_info, null, &self.render_finished_semaphores[i]);

            if (render_semaphore_result != .success) {
                std.debug.print("Failed to create render finished semaphore {}: {}\n", .{ i, render_semaphore_result });
                return error.FailedToCreateSemaphore;
            }

            const fence_result = self.device.dispatch.vkCreateFence.?(self.device.device, &fence_info, null, &self.in_flight_fences[i]);

            if (fence_result != .success) {
                std.debug.print("Failed to create fence {}: {}\n", .{ i, fence_result });
                return error.FailedToCreateFence;
            }

            std.debug.print("Created sync objects for frame {}: semaphore1={any}, semaphore2={any}, fence={any}\n", .{ i, self.image_available_semaphores[i], self.render_finished_semaphores[i], self.in_flight_fences[i] });
        }
    }

    fn createSurface(self: *Renderer, raw: ?*const anyopaque) !void {
        if (raw == null) {
            std.debug.print("Error: Cannot create surface with null handle\n", .{});
            return error.InvalidSurfaceHandle;
        }

        // Create Win32 surface
        const hinstance = kernel32.GetModuleHandleW(null);
        if (hinstance == null) {
            std.debug.print("Error: Failed to get module handle\n", .{});
            return error.ModuleHandleNotFound;
        }

        const surface_create_info = vk.Win32SurfaceCreateInfoKHR{ .hinstance = @ptrCast(hinstance), .hwnd = @constCast(@ptrCast(raw.?)) };

        const result = self.instance.dispatch.vkCreateWin32SurfaceKHR.?(self.instance.instance, &surface_create_info, null, &self.surface);

        if (result != .success) {
            std.debug.print("Failed to create Win32 surface: {}\n", .{result});
            return error.SurfaceCreationFailed;
        }

        std.debug.print("Surface created successfully: {any}\n", .{self.surface});

        // Verify surface support
        var surface_support: vk.Bool32 = undefined;
        const support_result = self.instance.dispatch.vkGetPhysicalDeviceSurfaceSupportKHR.?(self.device.physical_device.handle, self.device.graphics_queue_family, self.surface, &surface_support);

        if (support_result != .success) {
            std.debug.print("Failed to check surface support: {}\n", .{support_result});
            return error.SurfaceSupportCheckFailed;
        }

        if (surface_support != vk.TRUE) {
            std.debug.print("Surface is not supported by the selected physical device and queue\n", .{});
            return error.SurfaceNotSupported;
        }

        std.debug.print("Surface support verified successfully\n", .{});
    }

    /// Request a stage buffer for mesh data
    pub fn requestBuffer(self: *Renderer) !?u32 {
        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        return try self.vertex_pool.?.requestBuffer();
    }

    /// Add mesh data to a buffer and create a draw command
    pub fn addMesh(self: *Renderer, buffer_idx: u32, vertices: []const vertex_pool.Vertex, position: [3]f32, group: u32) !*u32 {
        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        // Fill vertex data
        try self.vertex_pool.?.fillVertexData(buffer_idx, vertices);

        // Add draw command
        return try self.vertex_pool.?.addDrawCommand(buffer_idx, @intCast(vertices.len), position, group);
    }

    /// Release a buffer and its draw command
    pub fn releaseBuffer(self: *Renderer, buffer_idx: u32, command_index_ptr: *u32) !void {
        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        try self.vertex_pool.?.releaseBuffer(buffer_idx, command_index_ptr);
    }

    /// Mask draw commands based on view direction for back-face culling
    pub fn maskByFacing(self: *Renderer, camera_position: [3]f32) !void {
        // Define a simple predicate function for masking
        const PredContext = struct {};
        const predicate = struct {
            pub fn pred(_: PredContext, _: vertex_pool.DrawCommand) bool {
                return true; // Always include all commands
            }
        }.pred;

        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        // Define groups to include based on camera position
        // Determine which face directions are visible based on camera position
        var groups: [6]bool = .{false} ** 6;
        if (camera_position[0] < 0) groups[0] = true; // -X visible
        if (camera_position[0] > 0) groups[1] = true; // +X visible
        if (camera_position[1] < 0) groups[2] = true; // -Y visible
        if (camera_position[1] > 0) groups[3] = true; // +Y visible
        if (camera_position[2] < 0) groups[4] = true; // -Z visible
        if (camera_position[2] > 0) groups[5] = true; // +Z visible

        // Use predicate for masking
        self.vertex_pool.?.mask(PredContext{}, predicate);

        // Update the indirect buffer with masked commands
        try self.vertex_pool.?.updateIndirectBuffer();
    }

    /// Order draw commands from front-to-back for optimization
    pub fn orderFrontToBack(self: *Renderer, _: [3]f32) !void {
        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        // Simple compare function for distance sorting
        // Create a struct that stores the camera position

        //TODO
        // Update the indirect buffer with reordered commands
        try self.vertex_pool.?.updateIndirectBuffer();
    }

    /// Render using the vertex pool
    pub fn renderVertexPool(self: *Renderer, command_buffer: vk.CommandBuffer) !void {
        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        // Use the view and projection matrices from the main camera if available
        if (self.main_camera) |camera| {
            // Push the view matrix
            self.device.dispatch.vkCmdPushConstants.?(command_buffer, self.pipeline_layout, .{ .vertex_bit = true, .geometry_bit = true }, 0, 64, // size of mat4 (16 floats * 4 bytes)
                &camera.view_matrix);

            // Push the projection matrix
            self.device.dispatch.vkCmdPushConstants.?(command_buffer, self.pipeline_layout, .{ .vertex_bit = true, .geometry_bit = true }, 64, // offset after view matrix
                64, // size of mat4 (16 floats * 4 bytes)
                &camera.proj_matrix);
        } else {
            // Default matrices if no camera is set
            // View matrix: camera at (0, 0, 3) looking at origin
            const default_view = [16]f32{
                1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0,
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0,
            };

            // Simple perspective projection matrix
            const default_proj = [16]f32{
                1.0, 0.0, 0.0, 0.0,
                0.0, 1.0, 0.0, 0.0, // Negative to flip Y for Vulkan
                0.0, 0.0, 1.0, 0.0,
                0.0, 0.0, 0.0, 1.0,
            };

            // Push the default view matrix
            self.device.dispatch.vkCmdPushConstants.?(command_buffer, self.pipeline_layout, .{ .vertex_bit = true, .geometry_bit = true }, 0, 64, // size of mat4 (16 floats * 4 bytes)
                &default_view);

            // Push the default projection matrix
            self.device.dispatch.vkCmdPushConstants.?(command_buffer, self.pipeline_layout, .{ .vertex_bit = true, .geometry_bit = true }, 64, // offset after view matrix
                64, // size of mat4 (16 floats * 4 bytes)
                &default_proj);
        }

        try self.vertex_pool.?.render(command_buffer, self.pipeline_layout, self.pipeline);
    }

    /// Clean up all Vulkan resources
    pub fn deinit(self: *Renderer) void {
        // The camera is not owned by the renderer, so we don't free it here
        // The application that created the camera is responsible for freeing it
        // using renderer_camera_destroy()

        if (self.vertex_pool != null) {
            self.vertex_pool.?.deinit();
        }

        // Clean up depth resources
        if (self.depth_image_view != .null_handle) {
            if (self.device.dispatch.vkDestroyImageView) |destroyImageView| {
                destroyImageView(self.device.device, self.depth_image_view, null);
            }
        }
        if (self.depth_image != .null_handle) {
            if (self.device.dispatch.vkDestroyImage) |destroyImage| {
                destroyImage(self.device.device, self.depth_image, null);
            }
        }
        if (self.depth_image_memory != .null_handle) {
            if (self.device.dispatch.vkFreeMemory) |freeMemory| {
                freeMemory(self.device.device, self.depth_image_memory, null);
            }
        }

        if (self.pipeline != .null_handle) {
            if (self.device.dispatch.vkDestroyPipeline) |destroyPipeline| {
                destroyPipeline(self.device.device, self.pipeline, null);
            }
        }

        if (self.pipeline_layout != .null_handle) {
            if (self.device.dispatch.vkDestroyPipelineLayout) |destroyPipelineLayout| {
                destroyPipelineLayout(self.device.device, self.pipeline_layout, null);
            }
        }

        if (self.command_pool != .null_handle) {
            if (self.device.dispatch.vkDestroyCommandPool) |destroyCommandPool| {
                destroyCommandPool(self.device.device, self.command_pool, null);
            }
        }

        if (self.vertex_shader_module != .null_handle) {
            if (self.device.dispatch.vkDestroyShaderModule) |destroyShaderModule| {
                destroyShaderModule(self.device.device, self.vertex_shader_module, null);
            }
        }

        if (self.geometry_shader_module != .null_handle) {
            if (self.device.dispatch.vkDestroyShaderModule) |destroyShaderModule| {
                destroyShaderModule(self.device.device, self.geometry_shader_module, null);
            }
        }

        if (self.fragment_shader_module != .null_handle) {
            if (self.device.dispatch.vkDestroyShaderModule) |destroyShaderModule| {
                destroyShaderModule(self.device.device, self.fragment_shader_module, null);
            }
        }

        self.device.deinit();
        self.instance.deinit();
    }
};

/// Export renderer interface
pub const RendererInterface = struct {
    /// Check if Vulkan is available on the system
    pub fn isAvailable() bool {
        return false; // This will be implemented later
    }

    /// Get the name of the renderer
    pub fn getName() []const u8 {
        return "Vulkan";
    }

    /// Get Vertex type
    pub const Vertex = vertex_pool.Vertex;

    /// Get DrawCommand type
    pub const DrawCommand = vertex_pool.DrawCommand;
};
