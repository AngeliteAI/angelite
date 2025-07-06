const std = @import("std");
const vk = @import("vulkan");
const rendergraph = @import("rendergraph.zig");
const gfx = @import("gfx.zig");
const vertex_pool = @import("vertex_pool.zig");

// Rendering integration with render graph
pub const RenderingRenderGraph = struct {
    allocator: std.mem.Allocator,
    device: *gfx.Device,
    
    // Render resources
    vertex_pool_buffer: vk.Buffer,
    index_buffer: vk.Buffer,
    draw_command_buffer: vk.Buffer,
    uniform_buffer: vk.Buffer,
    
    // Resource views
    vertex_pool_view: ?rendergraph.TaskBufferView,
    index_view: ?rendergraph.TaskBufferView,
    draw_command_view: ?rendergraph.TaskBufferView,
    uniform_view: ?rendergraph.TaskBufferView,
    
    // Render targets
    color_target: vk.Image,
    depth_target: vk.Image,
    color_view: ?rendergraph.TaskImageView,
    depth_view: ?rendergraph.TaskImageView,
    
    // Pipeline state
    graphics_pipeline: vk.Pipeline,
    pipeline_layout: vk.PipelineLayout,
    
    // Configuration
    max_vertices: u32,
    max_draw_commands: u32,
    render_width: u32,
    render_height: u32,
    
    pub fn init(
        allocator: std.mem.Allocator,
        device: *gfx.Device,
        max_vertices: u32,
        max_draw_commands: u32,
        width: u32,
        height: u32,
    ) !RenderingRenderGraph {
        // Create vertex pool buffer
        const vertex_pool_size = max_vertices * @sizeOf(vertex_pool.Vertex);
        const vertex_pool_buffer = try createBuffer(
            device,
            vertex_pool_size,
            .{ .vertex_buffer_bit = true, .storage_buffer_bit = true, .transfer_dst_bit = true, .shader_device_address_bit = true },
        );
        
        // Create index buffer
        const index_buffer_size = max_vertices * @sizeOf(u32); // Assuming u32 indices
        const index_buffer = try createBuffer(
            device,
            index_buffer_size,
            .{ .index_buffer_bit = true, .storage_buffer_bit = true, .transfer_dst_bit = true },
        );
        
        // Create draw command buffer (for indirect drawing)
        const draw_command_size = max_draw_commands * @sizeOf(vk.DrawIndexedIndirectCommand);
        const draw_command_buffer = try createBuffer(
            device,
            draw_command_size,
            .{ .indirect_buffer_bit = true, .storage_buffer_bit = true, .transfer_dst_bit = true },
        );
        
        // Create uniform buffer for matrices
        const uniform_size = 256; // Space for view/proj matrices and other uniforms
        const uniform_buffer = try createBuffer(
            device,
            uniform_size,
            .{ .uniform_buffer_bit = true, .transfer_dst_bit = true },
        );
        
        // Create render targets
        const color_target = try createImage(
            device,
            width,
            height,
            .b8g8r8a8_unorm,
            .{ .color_attachment_bit = true, .sampled_bit = true, .transfer_src_bit = true },
        );
        
        const depth_target = try createImage(
            device,
            width,
            height,
            .d32_sfloat,
            .{ .depth_stencil_attachment_bit = true, .sampled_bit = true },
        );
        
        // Create graphics pipeline (placeholder - would be loaded from shaders)
        const graphics_pipeline = vk.Pipeline.null_handle;
        const pipeline_layout = vk.PipelineLayout.null_handle;
        
        return .{
            .allocator = allocator,
            .device = device,
            .vertex_pool_buffer = vertex_pool_buffer,
            .index_buffer = index_buffer,
            .draw_command_buffer = draw_command_buffer,
            .uniform_buffer = uniform_buffer,
            .vertex_pool_view = null,
            .index_view = null,
            .draw_command_view = null,
            .uniform_view = null,
            .color_target = color_target,
            .depth_target = depth_target,
            .color_view = null,
            .depth_view = null,
            .graphics_pipeline = graphics_pipeline,
            .pipeline_layout = pipeline_layout,
            .max_vertices = max_vertices,
            .max_draw_commands = max_draw_commands,
            .render_width = width,
            .render_height = height,
        };
    }
    
    pub fn deinit(self: *RenderingRenderGraph) void {
        // Clean up resources
        self.device.dispatch.vkDestroyBuffer.?(self.device.device, self.vertex_pool_buffer, null);
        self.device.dispatch.vkDestroyBuffer.?(self.device.device, self.index_buffer, null);
        self.device.dispatch.vkDestroyBuffer.?(self.device.device, self.draw_command_buffer, null);
        self.device.dispatch.vkDestroyBuffer.?(self.device.device, self.uniform_buffer, null);
        self.device.dispatch.vkDestroyImage.?(self.device.device, self.color_target, null);
        self.device.dispatch.vkDestroyImage.?(self.device.device, self.depth_target, null);
        
        if (self.graphics_pipeline != .null_handle) {
            self.device.dispatch.vkDestroyPipeline.?(self.device.device, self.graphics_pipeline, null);
        }
        if (self.pipeline_layout != .null_handle) {
            self.device.dispatch.vkDestroyPipelineLayout.?(self.device.device, self.pipeline_layout, null);
        }
    }
    
    pub fn registerWithGraph(self: *RenderingRenderGraph, graph: *rendergraph.RenderGraph) !void {
        // Register persistent buffers
        self.vertex_pool_view = try graph.usePersistentBuffer(
            self.vertex_pool_buffer,
            self.max_vertices * @sizeOf(vertex_pool.Vertex),
            .{ .vertex_buffer_bit = true, .storage_buffer_bit = true, .transfer_dst_bit = true, .shader_device_address_bit = true },
            rendergraph.GpuMask.all(),
        );
        
        self.index_view = try graph.usePersistentBuffer(
            self.index_buffer,
            self.max_vertices * @sizeOf(u32),
            .{ .index_buffer_bit = true, .storage_buffer_bit = true, .transfer_dst_bit = true },
            rendergraph.GpuMask.all(),
        );
        
        self.draw_command_view = try graph.usePersistentBuffer(
            self.draw_command_buffer,
            self.max_draw_commands * @sizeOf(vk.DrawIndexedIndirectCommand),
            .{ .indirect_buffer_bit = true, .storage_buffer_bit = true, .transfer_dst_bit = true },
            rendergraph.GpuMask.all(),
        );
        
        self.uniform_view = try graph.usePersistentBuffer(
            self.uniform_buffer,
            256,
            .{ .uniform_buffer_bit = true, .transfer_dst_bit = true },
            rendergraph.GpuMask.all(),
        );
        
        // Register persistent images
        self.color_view = try graph.usePersistentImage(
            self.color_target,
            .{ .width = self.render_width, .height = self.render_height, .depth = 1 },
            .b8g8r8a8_unorm,
            .{ .color_attachment_bit = true, .sampled_bit = true, .transfer_src_bit = true },
            rendergraph.GpuMask.all(),
        );
        
        self.depth_view = try graph.usePersistentImage(
            self.depth_target,
            .{ .width = self.render_width, .height = self.render_height, .depth = 1 },
            .d32_sfloat,
            .{ .depth_stencil_attachment_bit = true, .sampled_bit = true },
            rendergraph.GpuMask.all(),
        );
    }
    
    pub fn addRenderingTasks(
        self: *RenderingRenderGraph,
        graph: *rendergraph.RenderGraph,
        physics_vertex_buffer: ?rendergraph.TaskBufferView,
        worldgen_vertex_buffer: ?rendergraph.TaskBufferView,
        swapchain_image: rendergraph.TaskImageView,
    ) !void {
        // 1. Clear render targets
        try self.addClearTask(graph);
        
        // 2. Render physics objects (if provided)
        if (physics_vertex_buffer) |buffer| {
            try self.addPhysicsRenderTask(graph, buffer);
        }
        
        // 3. Render worldgen meshes (if provided)
        if (worldgen_vertex_buffer) |buffer| {
            try self.addWorldgenRenderTask(graph, buffer);
        }
        
        // 4. Main scene render pass
        try self.addMainRenderTask(graph);
        
        // 5. Post-processing (if needed)
        try self.addPostProcessTask(graph);
        
        // 6. Copy to swapchain
        try self.addPresentTask(graph, swapchain_image);
    }
    
    fn addClearTask(self: *RenderingRenderGraph, graph: *rendergraph.RenderGraph) !void {
        var task = graph.raster("clear_render_targets");
        _ = task.writes(.color_attachment, self.color_view.?);
        _ = task.writes(.depth_stencil_attachment, self.depth_view.?);
        
        const clear_fn = struct {
            fn clear(interface: *rendergraph.TaskInterface) anyerror!void {
                // Set render area
                const render_area = vk.Rect2D{
                    .offset = .{ .x = 0, .y = 0 },
                    .extent = .{ .width = 1920, .height = 1080 }, // TODO: Get from interface
                };
                
                // Clear values
                const clear_values = [_]vk.ClearValue{
                    .{ .color = .{ .float_32 = .{ 0.1, 0.1, 0.2, 1.0 } } }, // Dark blue
                    .{ .depth_stencil = .{ .depth = 1.0, .stencil = 0 } },
                };
                
                // Dynamic rendering begin info
                const color_attachment = vk.RenderingAttachmentInfo{
                    .s_type = .rendering_attachment_info,
                    .p_next = null,
                    .image_view = interface.attachments[0].resource.image.id.handle, // Placeholder
                    .image_layout = .color_attachment_optimal,
                    .resolve_mode = .none,
                    .resolve_image_view = .null_handle,
                    .resolve_image_layout = .undefined,
                    .load_op = .clear,
                    .store_op = .store,
                    .clear_value = clear_values[0],
                };
                
                const depth_attachment = vk.RenderingAttachmentInfo{
                    .s_type = .rendering_attachment_info,
                    .p_next = null,
                    .image_view = interface.attachments[1].resource.image.id.handle, // Placeholder
                    .image_layout = .depth_stencil_attachment_optimal,
                    .resolve_mode = .none,
                    .resolve_image_view = .null_handle,
                    .resolve_image_layout = .undefined,
                    .load_op = .clear,
                    .store_op = .store,
                    .clear_value = clear_values[1],
                };
                
                const rendering_info = vk.RenderingInfo{
                    .s_type = .rendering_info,
                    .p_next = null,
                    .flags = .{},
                    .render_area = render_area,
                    .layer_count = 1,
                    .view_mask = 0,
                    .color_attachment_count = 1,
                    .p_color_attachments = @ptrCast(&color_attachment),
                    .p_depth_attachment = &depth_attachment,
                    .p_stencil_attachment = null,
                };
                
                interface.device.dispatch.vkCmdBeginRendering.?(interface.command_buffer, &rendering_info);
                interface.device.dispatch.vkCmdEndRendering.?(interface.command_buffer);
            }
        }.clear;
        
        try task.executes(clear_fn);
    }
    
    fn addPhysicsRenderTask(
        self: *RenderingRenderGraph,
        graph: *rendergraph.RenderGraph,
        physics_vertices: rendergraph.TaskBufferView,
    ) !void {
        var task = graph.raster("render_physics");
        _ = task.reads(.vertex_shader, physics_vertices);
        _ = task.reads(.vertex_shader, self.uniform_view.?);
        _ = task.writes(.color_attachment, self.color_view.?);
        _ = task.writes(.depth_stencil_attachment, self.depth_view.?);
        
        const render_fn = struct {
            fn render(interface: *rendergraph.TaskInterface) anyerror!void {
                // Render physics objects
                std.debug.print("Rendering physics objects\n", .{});
            }
        }.render;
        
        try task.executes(render_fn);
    }
    
    fn addWorldgenRenderTask(
        self: *RenderingRenderGraph,
        graph: *rendergraph.RenderGraph,
        worldgen_vertices: rendergraph.TaskBufferView,
    ) !void {
        var task = graph.raster("render_worldgen");
        _ = task.reads(.vertex_shader, worldgen_vertices);
        _ = task.reads(.vertex_shader, self.uniform_view.?);
        _ = task.writes(.color_attachment, self.color_view.?);
        _ = task.writes(.depth_stencil_attachment, self.depth_view.?);
        
        const render_fn = struct {
            fn render(interface: *rendergraph.TaskInterface) anyerror!void {
                // Render worldgen meshes
                std.debug.print("Rendering worldgen meshes\n", .{});
            }
        }.render;
        
        try task.executes(render_fn);
    }
    
    fn addMainRenderTask(self: *RenderingRenderGraph, graph: *rendergraph.RenderGraph) !void {
        var task = graph.raster("render_main_scene");
        _ = task.reads(.vertex_shader, self.vertex_pool_view.?);
        _ = task.reads(.vertex_shader, self.index_view.?);
        _ = task.reads(.indirect_command, self.draw_command_view.?);
        _ = task.reads(.vertex_shader, self.uniform_view.?);
        _ = task.writes(.color_attachment, self.color_view.?);
        _ = task.writes(.depth_stencil_attachment, self.depth_view.?);
        
        const render_fn = struct {
            fn render(interface: *rendergraph.TaskInterface) anyerror!void {
                // Main rendering logic
                std.debug.print("Rendering main scene\n", .{});
                
                // In a real implementation:
                // 1. Begin dynamic rendering
                // 2. Bind pipeline
                // 3. Bind descriptor sets
                // 4. Draw indirect
                // 5. End rendering
            }
        }.render;
        
        try task.executes(render_fn);
    }
    
    fn addPostProcessTask(self: *RenderingRenderGraph, graph: *rendergraph.RenderGraph) !void {
        // Create temporary buffer for post-processing
        const temp_image = try graph.createTransientImage(.{
            .width = self.render_width,
            .height = self.render_height,
            .depth = 1,
            .format = .r8g8b8a8_unorm,
            .usage = .{ .sampled_bit = true, .storage_bit = true },
            .mip_levels = 1,
            .array_layers = 1,
            .samples = 1,
            .name = "post_process_temp",
        });
        
        var task = graph.compute("post_process");
        _ = task.reads(.compute_shader, self.color_view.?);
        _ = task.writes(.compute_shader, temp_image);
        
        const post_fn = struct {
            fn process(interface: *rendergraph.TaskInterface) anyerror!void {
                // Post-processing compute shader
                const dispatch_x = (1920 + 7) / 8;
                const dispatch_y = (1080 + 7) / 8;
                interface.device.dispatch.vkCmdDispatch.?(interface.command_buffer, dispatch_x, dispatch_y, 1);
            }
        }.process;
        
        try task.executes(post_fn);
        
        // Copy back to color target
        var copy_task = graph.transfer("post_process_copy");
        _ = copy_task.reads(.transfer, temp_image);
        _ = copy_task.writes(.transfer, self.color_view.?);
        
        const copy_fn = struct {
            fn copy(interface: *rendergraph.TaskInterface) anyerror!void {
                // Copy processed image back
                std.debug.print("Copying post-processed image\n", .{});
            }
        }.copy;
        
        try copy_task.executes(copy_fn);
    }
    
    fn addPresentTask(
        self: *RenderingRenderGraph,
        graph: *rendergraph.RenderGraph,
        swapchain_image: rendergraph.TaskImageView,
    ) !void {
        var task = graph.transfer("copy_to_swapchain");
        _ = task.reads(.transfer, self.color_view.?);
        _ = task.writes(.transfer, swapchain_image);
        
        const present_fn = struct {
            fn present(interface: *rendergraph.TaskInterface) anyerror!void {
                // Copy rendered image to swapchain
                const src_image = try interface.getImage(interface.attachments[0].resource.image);
                const dst_image = try interface.getImage(interface.attachments[1].resource.image);
                
                const region = vk.ImageCopy{
                    .src_subresource = .{
                        .aspect_mask = .{ .color_bit = true },
                        .mip_level = 0,
                        .base_array_layer = 0,
                        .layer_count = 1,
                    },
                    .src_offset = .{ .x = 0, .y = 0, .z = 0 },
                    .dst_subresource = .{
                        .aspect_mask = .{ .color_bit = true },
                        .mip_level = 0,
                        .base_array_layer = 0,
                        .layer_count = 1,
                    },
                    .dst_offset = .{ .x = 0, .y = 0, .z = 0 },
                    .extent = .{ .width = 1920, .height = 1080, .depth = 1 }, // TODO: Get from interface
                };
                
                interface.device.dispatch.vkCmdCopyImage.?(
                    interface.command_buffer,
                    src_image,
                    .transfer_src_optimal,
                    dst_image,
                    .transfer_dst_optimal,
                    1,
                    @ptrCast(&region),
                );
            }
        }.present;
        
        try task.executes(present_fn);
    }
    
    // Helper functions
    fn createBuffer(device: *gfx.Device, size: vk.DeviceSize, usage: vk.BufferUsageFlags) !vk.Buffer {
        const create_info = vk.BufferCreateInfo{
            .size = size,
            .usage = usage,
            .sharing_mode = .exclusive,
        };
        
        var buffer: vk.Buffer = undefined;
        const result = device.dispatch.vkCreateBuffer.?(device.device, &create_info, null, &buffer);
        if (result != .success) return error.VulkanError;
        
        // TODO: Allocate and bind memory
        
        return buffer;
    }
    
    fn createImage(
        device: *gfx.Device,
        width: u32,
        height: u32,
        format: vk.Format,
        usage: vk.ImageUsageFlags,
    ) !vk.Image {
        const create_info = vk.ImageCreateInfo{
            .image_type = .@"2d",
            .format = format,
            .extent = .{ .width = width, .height = height, .depth = 1 },
            .mip_levels = 1,
            .array_layers = 1,
            .samples = .{ .@"1_bit" = true },
            .tiling = .optimal,
            .usage = usage,
            .sharing_mode = .exclusive,
            .initial_layout = .undefined,
        };
        
        var image: vk.Image = undefined;
        const result = device.dispatch.vkCreateImage.?(device.device, &create_info, null, &image);
        if (result != .success) return error.VulkanError;
        
        // TODO: Allocate and bind memory
        
        return image;
    }
};