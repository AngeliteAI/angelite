const std = @import("std");
const raw = @import("raw.zig");
const errors = @import("errors.zig");

/// Command pool abstraction
pub const CommandPool = struct {
    handle: raw.CommandPool,
    device: raw.Device,
    queue_family_index: u32,

    /// Create a new command pool
    pub fn create(device: raw.Device, queue_family_index: u32) errors.Error!CommandPool {
        const create_info = raw.CommandPoolCreateInfo{
            .sType = raw.sTy(.CommandPoolCreateInfo),
            .pNext = null,
            .flags = raw.COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .queueFamilyIndex = queue_family_index,
        };

        var handle: raw.CommandPool = undefined;
        const result = raw.createCommandPool(device, &create_info, null, &handle);
        try errors.checkResult(result);

        return CommandPool{
            .handle = handle,
            .device = device,
            .queue_family_index = queue_family_index,
        };
    }

    /// Destroy the command pool
    pub fn destroy(self: *CommandPool) void {
        raw.destroyCommandPool(self.device, self.handle, null);
        self.* = undefined;
    }

    /// Allocate command buffers from this pool
    pub fn allocateCommandBuffers(self: CommandPool, count: u32, primary: bool) errors.Error![]CommandBuffer {
        const allocate_info = raw.CommandBufferAllocateInfo{
            .sType = raw.sTy(.CommandBufferAllocateInfo),
            .pNext = null,
            .commandPool = self.handle,
            .level = if (primary) raw.COMMAND_BUFFER_LEVEL_PRIMARY else @as(c_int, 0), // VK_COMMAND_BUFFER_LEVEL_SECONDARY
            .commandBufferCount = count,
        };

        // Allocate raw command buffers
        const raw_command_buffers = try std.heap.page_allocator.alloc(raw.CommandBuffer, count);
        errdefer std.heap.page_allocator.free(raw_command_buffers);

        const result = raw.allocateCommandBuffers(self.device, &allocate_info, raw_command_buffers.ptr);
        if (result != raw.SUCCESS) {
            std.heap.page_allocator.free(raw_command_buffers);
            return errors.Error.ResourceCreationFailed;
        }

        // Create our command buffer wrappers
        const command_buffers = try std.heap.page_allocator.alloc(CommandBuffer, count);
        errdefer std.heap.page_allocator.free(command_buffers);

        for (raw_command_buffers, 0..) |buffer, i| {
            command_buffers[i] = CommandBuffer{
                .handle = buffer,
                .device = self.device,
                .pool = self.handle,
                .is_recording = false,
            };
        }

        std.heap.page_allocator.free(raw_command_buffers);
        return command_buffers;
    }

    /// Free command buffers allocated from this pool
    pub fn freeCommandBuffers(self: CommandPool, command_buffers: []CommandBuffer) void {
        // Extract raw handles
        var raw_handles = std.heap.page_allocator.alloc(raw.CommandBuffer, command_buffers.len) catch {
            return;
        };
        defer std.heap.page_allocator.free(raw_handles);

        for (command_buffers, 0..) |buffer, i| {
            raw_handles[i] = buffer.handle;
        }

        // Free the command buffers
        raw.freeCommandBuffers(self.device, self.handle, @intCast(command_buffers.len), raw_handles.ptr);

        // Free our wrapper array
        std.heap.page_allocator.free(command_buffers);
    }

    /// Get the raw command pool handle
    pub fn getHandle(self: CommandPool) raw.CommandPool {
        return self.handle;
    }
};

/// Command buffer abstraction
pub const CommandBuffer = struct {
    handle: raw.CommandBuffer,
    device: raw.Device,
    pool: raw.CommandPool,
    is_recording: bool,

    /// Begin recording commands to this command buffer
    pub fn begin(self: *CommandBuffer, one_time_submit: bool) errors.Error!void {
        if (self.is_recording) {
            return errors.Error.InitializationFailed;
        }

        const begin_info = raw.CommandBufferBeginInfo{
            .sType = raw.sTy(.CommandBufferBeginInfo),
            .pNext = null,
            .flags = if (one_time_submit) raw.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT else 0,
            .pInheritanceInfo = null,
        };

        const result = raw.BeginCommandBuffer(self.handle, &begin_info);
        try errors.checkResult(result);

        self.is_recording = true;
    }

    /// End recording commands to this command buffer
    pub fn end(self: *CommandBuffer) errors.Error!void {
        if (!self.is_recording) {
            return errors.Error.InitializationFailed;
        }

        const result = raw.EndCommandBuffer(self.handle);
        try errors.checkResult(result);

        self.is_recording = false;
    }

    /// Bind a pipeline to this command buffer
    pub fn bindPipeline(
        self: CommandBuffer,
        bind_point: c_int, // VK_PIPELINE_BIND_POINT_GRAPHICS or VK_PIPELINE_BIND_POINT_COMPUTE
        pipeline: raw.Pipeline,
    ) void {
        raw.cmdBindPipeline(self.handle, bind_point, pipeline);
    }

    /// Draw primitives
    pub fn draw(self: CommandBuffer, vertex_count: u32, instance_count: u32, first_vertex: u32, first_instance: u32) void {
        raw.cmdDraw(self.handle, vertex_count, instance_count, first_vertex, first_instance);
    }

    /// Set the viewport
    pub fn setViewport(self: CommandBuffer, first_viewport: u32, viewports: []const raw.Viewport) void {
        raw.cmdSetViewport(self.handle, first_viewport, @intCast(viewports.len), viewports.ptr);
    }

    /// Set the scissor rectangle
    pub fn setScissor(self: CommandBuffer, first_scissor: u32, scissors: []const raw.Rect2D) void {
        raw.cmdSetScissor(self.handle, first_scissor, @intCast(scissors.len), scissors.ptr);
    }

    /// Begin a render pass using dynamic rendering
    pub fn beginRendering(self: CommandBuffer, rendering_info: *const raw.RenderingInfoKHR) void {
        raw.cmdBeginRenderingKHR(self.handle, rendering_info);
    }

    /// End a render pass using dynamic rendering
    pub fn endRendering(self: CommandBuffer) void {
        raw.cmdEndRenderingKHR(self.handle);
    }

    /// Insert a pipeline barrier
    pub fn pipelineBarrier(self: CommandBuffer, src_stage_mask: raw.PipelineStageFlags, dst_stage_mask: raw.PipelineStageFlags, dependency_flags: u32, memory_barriers: ?[]const raw.MemoryBarrier2KHR, buffer_memory_barriers: ?[]const raw.BufferMemoryBarrier2KHR, image_memory_barriers: ?[]const raw.ImageMemoryBarrier2KHR) void {
        // Setup dependency info for synchronization2
        const dep_info = raw.DependencyInfoKHR{
            .sType = raw.sTy(.DependencyInfoKHR),
            .pNext = null,
            .dependencyFlags = dependency_flags,
            .memoryBarrierCount = if (memory_barriers) |barriers| @intCast(barriers.len) else 0,
            .pMemoryBarriers = if (memory_barriers) |barriers| barriers.ptr else null,
            .bufferMemoryBarrierCount = if (buffer_memory_barriers) |barriers| @intCast(barriers.len) else 0,
            .pBufferMemoryBarriers = if (buffer_memory_barriers) |barriers| barriers.ptr else null,
            .imageMemoryBarrierCount = if (image_memory_barriers) |barriers| @intCast(barriers.len) else 0,
            .pImageMemoryBarriers = if (image_memory_barriers) |barriers| barriers.ptr else null,
        };

        // Use synchronization2 barrier
        raw.cmdPipelineBarrier2KHR(self.handle, &dep_info);
    }

    /// Copy data from one buffer to another
    pub fn copyBuffer(self: CommandBuffer, src_buffer: raw.Buffer, dst_buffer: raw.Buffer, regions: []const raw.BufferCopy) void {
        raw.cmdCopyBuffer(self.handle, src_buffer, dst_buffer, @intCast(regions.len), regions.ptr);
    }

    /// Copy data from a buffer to an image
    pub fn copyBufferToImage(self: CommandBuffer, src_buffer: raw.Buffer, dst_image: raw.Image, dst_image_layout: raw.ImageLayout, regions: []const raw.BufferImageCopy) void {
        raw.cmdCopyBufferToImage(self.handle, src_buffer, dst_image, dst_image_layout, @intCast(regions.len), regions.ptr);
    }

    /// Push constants to the pipeline
    pub fn pushConstants(self: CommandBuffer, layout: raw.PipelineLayout, stage_flags: u32, offset: u32, size: u32, values: *const anyopaque) void {
        raw.cmdPushConstants(self.handle, layout, stage_flags, offset, size, values);
    }

    /// Dispatch a compute shader
    pub fn dispatch(self: CommandBuffer, group_count_x: u32, group_count_y: u32, group_count_z: u32) void {
        raw.cmdDispatch(self.handle, group_count_x, group_count_y, group_count_z);
    }

    /// Get the raw command buffer handle
    pub fn getHandle(self: CommandBuffer) raw.CommandBuffer {
        return self.handle;
    }
};

/// Creates a simple one-time command buffer for quick operations
pub fn createSingleTimeCommands(device: raw.Device, command_pool: raw.CommandPool) errors.Error!CommandBuffer {
    // Allocate a command buffer
    const allocate_info = raw.CommandBufferAllocateInfo{
        .sType = raw.sTy(.CommandBufferAllocateInfo),
        .pNext = null,
        .commandPool = command_pool,
        .level = raw.COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };

    var command_buffer: raw.CommandBuffer = undefined;
    const result = raw.allocateCommandBuffers(device, &allocate_info, &command_buffer);
    try errors.checkResult(result);

    // Begin command buffer
    const begin_info = raw.CommandBufferBeginInfo{
        .sType = raw.sTy(.CommandBufferBeginInfo),
        .pNext = null,
        .flags = raw.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
    };

    const begin_result = raw.BeginCommandBuffer(command_buffer, &begin_info);
    try errors.checkResult(begin_result);

    return CommandBuffer{
        .handle = command_buffer,
        .device = device,
        .pool = command_pool,
        .is_recording = true,
    };
}

/// Submits and frees a single-time command buffer
pub fn endSingleTimeCommands(command_buffer: CommandBuffer, queue: raw.Queue) errors.Error!void {
    // End command buffer recording
    const end_result = raw.EndCommandBuffer(command_buffer.handle);
    try errors.checkResult(end_result);

    // Submit command buffer
    const submit_info = raw.SubmitInfo{
        .sType = raw.sTy(.SubmitInfo),
        .pNext = null,
        .waitSemaphoreCount = 0,
        .pWaitSemaphores = null,
        .pWaitDstStageMask = null,
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffer.handle,
        .signalSemaphoreCount = 0,
        .pSignalSemaphores = null,
    };

    const submit_result = raw.queueSubmit(queue, 1, &submit_info, raw.NULL);
    try errors.checkResult(submit_result);

    // Wait for command to complete
    const wait_result = raw.queueWaitIdle(queue);
    try errors.checkResult(wait_result);

    // Free command buffer
    raw.freeCommandBuffers(command_buffer.device, command_buffer.pool, 1, &command_buffer.handle);
}
