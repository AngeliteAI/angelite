pub const vk = @import("vk.zig");
pub const std = @import("std");
pub const frame = @import("frame.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const taskAllocator = gpa.allocator();
pub const ResourceType = enum { Buffer, Image };

pub const ResourceState = struct {
    accessMask: vk.AccessFlags = 0,
    stageMask: vk.PipelineStageFlags = vk.PIPELINE_STAGE_NONE,
    layout: vk.ImageLayout = vk.IMAGE_LAYOUT_UNDEFINED,
    queueFamilyIndex: u32 = vk.QUEUE_FAMILY_IGNORED,

    firstUseInPass: bool = true,
    firstUseInFrame: bool = true,
};

pub const ResourceUsage = struct {
    resource: *Resource,
    requiredState: ResourceState,
    isWrite: bool,
};

pub const ResourceHandle = union {
    buffer: vk.Buffer,
    image: vk.Image,
};

pub const Resource = struct {
    name: []const u8,
    ty: ResourceType,
    handle: ?ResourceHandle,
    view: ?union {
        bufferView: vk.BufferView,
        imageView: vk.ImageView,
    } = null,

    currentState: ResourceState = .{},

    pub fn init(allocator: std.mem.Allocator, name: []const u8, ty: ResourceType, handle: anytype) !*Resource {
        var resource = try allocator.create(Resource);
        resource.* = Resource{
            .name = try allocator.dupe(u8, name),
            .ty = ty,
        };

        resource.handle = switch (ty) {
            .Buffer => .{ .buffer = handle },
            .Image => .{ .image = handle },
        };

        return resource;
    }

    pub fn createView(self: *Resource, device: vk.Device, viewType: vk.ImageViewType, format: vk.Format) !void {
        std.log.debug("Creating view for resource '{s}'", .{self.name});
        if (self.ty != .Image) {
            std.log.err("Resource '{s}' is not an image, cannot create view", .{self.name});
            return error.InvalidResourceType;
        }

        const imageViewInfo = vk.ImageViewCreateInfo{
            .sType = vk.sTy(vk.StructureType.ImageViewCreateInfo),
            .image = self.handle.?.image,
            .viewType = viewType,
            .format = @as(
                if (@import("builtin").os.tag == .windows) c_int else c_uint,
                @intCast(@intFromEnum(format)),
            ),
            .components = vk.ComponentMapping{
                .r = vk.COMPONENT_SWIZZLE_IDENTITY,
                .g = vk.COMPONENT_SWIZZLE_IDENTITY,
                .b = vk.COMPONENT_SWIZZLE_IDENTITY,
                .a = vk.COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = vk.ImageSubresourceRange{
                .aspectMask = vk.IMAGE_ASPECT_COLOR_BIT, // Customize as needed
                .baseMipLevel = 0,
                .levelCount = vk.REMAINING_MIP_LEVELS,
                .baseArrayLayer = 0,
                .layerCount = vk.REMAINING_ARRAY_LAYERS,
            },
        };

        var imageView: vk.ImageView = undefined;
        std.debug.print("creating...", .{});
        const result = vk.createImageView(device, &imageViewInfo, null, &imageView);
        if (result != vk.SUCCESS) {
            std.log.err("vkCreateImageView failed with code {d}", .{result});
            return error.CreateImageViewFailed;
        }
        self.view = .{ .imageView = imageView };

        std.log.debug("Successfully created view for resource '{s}'", .{self.name});
    }

    pub fn deinit(self: *Resource, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.destroy(self);
    }
};

fn pass_submit_execute(ctx: PassContext) void {
    //Submit the queue
    const waitStage: u32 = @intCast(vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);
    const submitInfo = vk.SubmitInfo{
        .sType = vk.sTy(vk.StructureType.SubmitInfo),
        .pNext = null,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &ctx.image_available_semaphore,
        .pWaitDstStageMask = &waitStage,
        .commandBufferCount = 1,
        .pCommandBuffers = &ctx.cmd,
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &ctx.render_finished_semaphore,
    };

    _ = vk.queueSubmit(ctx.queue, 1, &submitInfo, ctx.in_flight_fence);
}

pub var pass_submit = Pass{
    .name = "submit",
    .inputs = std.ArrayList(ResourceUsage).init(taskAllocator),
    .outputs = std.ArrayList(ResourceUsage).init(taskAllocator),
    .execute = pass_submit_execute,
    .cmd = false,
};

fn pass_present_execute(ctx: PassContext) void {
    //present the queue
    const presentInfo = vk.PresentInfoKHR{
        .sType = vk.sTy(vk.StructureType.PresentInfoKHR),
        .pNext = null,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &ctx.render_finished_semaphore,
        .swapchainCount = 1,
        .pSwapchains = &ctx.swapchain,
        .pImageIndices = &ctx.frame.index,
        .pResults = null,
    };

    const result = vk.queuePresentKHR(ctx.queue, &presentInfo);

    if (result != vk.SUCCESS) {
        std.log.err("vkQueuePresentKHR failed with code {d}", .{result});
        unreachable;
    }
}

pub fn pass_present(swapchain_resource: *Resource) *Pass {
    var inputs = std.ArrayList(ResourceUsage).init(taskAllocator);
    const outputs = std.ArrayList(ResourceUsage).init(taskAllocator);
    const first = inputs.addOne() catch unreachable;
    first.* = ResourceUsage{
        .resource = swapchain_resource,
        .requiredState = ResourceState{
            .accessMask = vk.ACCESS_MEMORY_READ_BIT,
            .stageMask = vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
            .layout = vk.IMAGE_LAYOUT_PRESENT_SRC_KHR,
            .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        },
        .isWrite = false,
    };
    const pass = taskAllocator.create(Pass) catch unreachable;

    pass.* = Pass{
        .name = "present",
        .inputs = inputs,
        .outputs = outputs,
        .execute = pass_present_execute,
        .cmd = false,
    };
    return pass;
}

pub const Pass = struct {
    name: []const u8,
    inputs: std.ArrayList(ResourceUsage),
    outputs: std.ArrayList(ResourceUsage),
    execute: *const fn (ctx: PassContext) void,
    cmd: bool,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, execute: *const fn (ctx: PassContext) void) !*Pass {
        const pass = try allocator.create(Pass);
        pass.* = Pass{
            .name = try allocator.dupe(u8, name),
            .inputs = std.ArrayList(ResourceUsage).init(allocator),
            .outputs = std.ArrayList(ResourceUsage).init(allocator),
            .execute = execute,
            .cmd = true,
        };
        return pass;
    }
    pub fn deinit(self: *Pass, allocator: std.mem.Allocator) void {
        for (self.inputs.items) |input| {
            if (allocator.isLastUse(input.resource)) {
                input.resource.deinit(allocator);
            }
        }
        for (self.outputs.items) |output| {
            if (allocator.isLastUse(output.resource)) {
                output.resource.deinit(allocator);
            }
        }
        self.inputs.deinit();
        self.outputs.deinit();
        self.name = null;
        self.execute = null;
    }

    pub fn addInput(self: *Pass, resource: *Resource, requiredState: ResourceState) !void {
        try self.inputs.append(.{
            .resource = resource,
            .requiredState = requiredState,
            .isWrite = false,
        });
    }

    pub fn addOutput(self: *Pass, resource: *Resource, requiredState: ResourceState) !void {
        try self.outputs.append(.{
            .resource = resource,
            .requiredState = requiredState,
            .isWrite = true,
        });
    }
};

pub const PassContext = struct { cmd: vk.CommandBuffer, queue: vk.Queue, swapchain: vk.Swapchain, render_finished_semaphore: vk.Semaphore, image_available_semaphore: vk.Semaphore, in_flight_fence: vk.Fence, frame: *frame.Frame, userData: ?*anyopaque, pass: *Pass = undefined };

pub const Graph = struct {
    allocator: std.mem.Allocator,
    passes: std.ArrayList(*Pass),
    resources: std.ArrayList(*Resource),
    userData: ?*anyopaque,
    use_sync2: bool = true, // Default to using Sync 2

    swapchain: vk.Swapchain,
    render_finished_semaphore: vk.Semaphore,
    image_available_semaphore: vk.Semaphore,
    in_flight_fence: vk.Fence,
    queue: vk.Queue,

    pub fn init(allocator: std.mem.Allocator, userData: ?*anyopaque, swapchain: vk.Swapchain, render_finished_semaphore: vk.Semaphore, image_available_semaphore: vk.Semaphore, in_flight_fence: vk.Fence, queue: vk.Queue, use_sync2: bool) !*Graph {
        const graph = try allocator.create(Graph);
        graph.* = Graph{
            .allocator = allocator,
            .passes = std.ArrayList(*Pass).init(allocator),
            .resources = std.ArrayList(*Resource).init(allocator),
            .userData = userData,
            .swapchain = swapchain,
            .render_finished_semaphore = render_finished_semaphore,
            .image_available_semaphore = image_available_semaphore,
            .in_flight_fence = in_flight_fence,
            .queue = queue,
            .use_sync2 = use_sync2,
        };
        return graph;
    }

    pub fn deinit(self: *Graph) void {
        for (self.passes.items) |pass| {
            pass.deinit(self.allocator);
        }
        self.passes.deinit();
        for (self.resources.items) |resource| {
            resource.deinit(self.allocator);
        }
        self.resources.deinit();
        self.allocator.destroy(self);
    }

    pub fn addPass(self: *Graph, pass: *Pass) !void {
        try self.passes.append(pass);
    }

    pub fn addResource(self: *Graph, resource: *Resource) !void {
        try self.resources.append(resource);
    }

    pub fn execute(self: *Graph, cmd: vk.CommandBuffer, activeFrame: *frame.Frame, passContext: PassContext) !void {
        var activePassContext = passContext;
        std.log.debug("Graph execution started for frame {d}", .{activeFrame.index});

        const executionOrder = try self.buildExecutionOrder();
        defer self.allocator.free(executionOrder);
        std.log.debug("Built execution order with {d} passes", .{executionOrder.len});

        const DeferNonCmd = struct {
            passContext: PassContext,
            execute: *const fn (ctx: PassContext) void,
        };

        var nonCmds = std.AutoHashMap(u64, DeferNonCmd).init(taskAllocator);

        for (executionOrder) |pass| {
            const activePass = self.passes.items[pass];
            //loop through all resources in pass
            for (activePass.inputs.items) |usage| {
                usage.resource.currentState.firstUseInFrame = true;
            }
            for (activePass.outputs.items) |usage| {
                usage.resource.currentState.firstUseInFrame = true;
            }
        }
        _ = vk.BeginCommandBuffer(cmd, &.{
            .sType = vk.sTy(vk.StructureType.CommandBufferBeginInfo),
            .flags = vk.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null,
        });
        for (executionOrder, 0..) |pass, i| {
            const activePass = self.passes.items[pass];
            std.log.debug("Executing pass [{d}/{d}]: '{s}'", .{ i + 1, executionOrder.len, activePass.name });
            for (activePass.inputs.items) |usage| {
                usage.resource.currentState.firstUseInPass = true;
            }
            for (activePass.outputs.items) |usage| {
                usage.resource.currentState.firstUseInPass = true;
            }
            std.log.debug("  - Inserting barriers for pass '{s}'", .{activePass.name});

            const activeExecute = activePass.execute;

            try self.insertBarriers(cmd, activePass);

            std.log.debug("  - Calling execute function for pass '{s}'", .{activePass.name});
            activePassContext.pass = activePass;
            if (activePass.cmd) {
                activeExecute(activePassContext);
            } else {
                const nextNonCmd = DeferNonCmd{ .execute = activeExecute, .passContext = activePassContext };
                nonCmds.put(i, nextNonCmd) catch |err| {
                    std.log.err("Failed to add non-command pass '{s}' to deferred execution: {any}", .{ activePass.name, err });
                    return err;
                };
            }
        }

        _ = vk.EndCommandBuffer(cmd);

        //loop through nonitems AutoHashMap and execute them from low to high
        var nonCmds_it = nonCmds.iterator();
        while (nonCmds_it.next()) |entry| {
            const pc = entry.value_ptr.*;
            pc.execute(pc.passContext);
        }

        std.log.debug("Graph execution completed for frame {d}", .{activeFrame.index});
    }

    fn buildExecutionOrder(self: *Graph) ![]usize {
        std.log.debug("Building execution order for graph with {d} passes", .{self.passes.items.len});

        // For simplicity, just use the order passes were added
        // A more sophisticated implementation would analyze dependencies
        // and potentially reorder for improved parallelism
        var result = try self.allocator.alloc(usize, self.passes.items.len);
        for (0..self.passes.items.len) |i| {
            result[i] = i;
            std.log.debug("  - Execution position {d}: '{s}'", .{ i, self.passes.items[i].name });
        }

        std.log.debug("Execution order build complete, returning {d} passes", .{result.len});
        return result;
    }
    fn insertBarriers(self: *Graph, commandBuffer: vk.CommandBuffer, pass: *Pass) !void {
        std.log.debug("Inserting barriers for pass '{s}' with {d} inputs and {d} outputs", .{ pass.name, pass.inputs.items.len, pass.outputs.items.len });

        if (self.use_sync2) {
            // Use Synchronization 2 (existing implementation)
            var imageBarriers = std.ArrayList(vk.ImageMemoryBarrier2KHR).init(self.allocator);
            defer imageBarriers.deinit();

            var bufferBarriers = std.ArrayList(vk.BufferMemoryBarrier2KHR).init(self.allocator);
            defer bufferBarriers.deinit();

            // Process inputs
            std.log.debug("  - Processing {d} input resources for barriers", .{pass.inputs.items.len});
            for (pass.inputs.items, 0..) |input, i| {
                std.log.debug("    - Input {d}: Resource '{s}' (type: {s})", .{ i, input.resource.name, @tagName(input.resource.ty) });
                try Graph.addBarrierIfNeededSync2(&imageBarriers, input);
            }

            // Process outputs
            std.log.debug("  - Processing {d} output resources for barriers", .{pass.outputs.items.len});
            for (pass.outputs.items, 0..) |output, i| {
                std.log.debug("    - Output {d}: Resource '{s}' (type: {s})", .{ i, output.resource.name, @tagName(output.resource.ty) });
                try Graph.addBarrierIfNeededSync2(&imageBarriers, output);
            }

            // If we have any barriers, insert them
            std.log.debug("  - Generated {d} image barriers and {d} buffer barriers", .{ imageBarriers.items.len, bufferBarriers.items.len });

            if (imageBarriers.items.len > 0 or bufferBarriers.items.len > 0) {
                std.log.debug("  - Inserting dependency info with barriers", .{});
                const dependencyInfo = vk.DependencyInfoKHR{
                    .sType = vk.sTy(vk.StructureType.DependencyInfoKHR),
                    .dependencyFlags = 0,
                    .memoryBarrierCount = 0,
                    .pMemoryBarriers = null,
                    .bufferMemoryBarrierCount = @intCast(bufferBarriers.items.len),
                    .pBufferMemoryBarriers = if (bufferBarriers.items.len > 0) bufferBarriers.items.ptr else null,
                    .imageMemoryBarrierCount = @intCast(imageBarriers.items.len),
                    .pImageMemoryBarriers = if (imageBarriers.items.len > 0) imageBarriers.items.ptr else null,
                };

                vk.cmdPipelineBarrier2KHR(commandBuffer, &dependencyInfo);
                std.log.debug("  - Pipeline barrier command inserted", .{});
            } else {
                std.log.debug("  - No barriers needed, skipping cmdPipelineBarrier2KHR", .{});
            }
        } else {
            // Use Synchronization 1 (fallback)
            var imageBarriers = std.ArrayList(vk.ImageMemoryBarrier).init(self.allocator);
            defer imageBarriers.deinit();

            var bufferBarriers = std.ArrayList(vk.BufferMemoryBarrier).init(self.allocator);
            defer bufferBarriers.deinit();

            // Initialize to sensible defaults instead of 0
            var srcStageMask: vk.PipelineStageFlags = vk.PIPELINE_STAGE_TOP_OF_PIPE_BIT;
            var dstStageMask: vk.PipelineStageFlags = vk.PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;

            // Process inputs
            std.log.debug("  - Processing {d} input resources for barriers (Sync 1)", .{pass.inputs.items.len});
            for (pass.inputs.items, 0..) |input, i| {
                std.log.debug("    - Input {d}: Resource '{s}' (type: {s})", .{ i, input.resource.name, @tagName(input.resource.ty) });
                try Graph.addBarrierIfNeededSync1(&imageBarriers, &bufferBarriers, input, &srcStageMask, &dstStageMask);
            }

            // Process outputs
            std.log.debug("  - Processing {d} output resources for barriers (Sync 1)", .{pass.outputs.items.len});
            for (pass.outputs.items, 0..) |output, i| {
                std.log.debug("    - Output {d}: Resource '{s}' (type: {s})", .{ i, output.resource.name, @tagName(output.resource.ty) });
                try Graph.addBarrierIfNeededSync1(&imageBarriers, &bufferBarriers, output, &srcStageMask, &dstStageMask);
            }

            // If we have any barriers, insert them
            std.log.debug("  - Generated {d} image barriers and {d} buffer barriers (Sync 1)", .{ imageBarriers.items.len, bufferBarriers.items.len });

            if (imageBarriers.items.len > 0 or bufferBarriers.items.len > 0) {
                std.log.debug("  - Inserting pipeline barrier (Sync 1)", .{});
                vk.cmdPipelineBarrier(commandBuffer, srcStageMask, dstStageMask, 0, // No dependency flags
                    0, null, // No memory barriers
                    @intCast(bufferBarriers.items.len), if (bufferBarriers.items.len > 0) bufferBarriers.items.ptr else null, @intCast(imageBarriers.items.len), if (imageBarriers.items.len > 0) imageBarriers.items.ptr else null);
                std.log.debug("  - Pipeline barrier command inserted (Sync 1)", .{});
            } else {
                std.log.debug("  - No barriers needed, skipping cmdPipelineBarrier (Sync 1)", .{});
            }
        }

        std.log.debug("Barrier insertion completed for pass '{s}'", .{pass.name});
    }

    fn addBarrierIfNeededSync2(imageBarriers: *std.ArrayList(vk.ImageMemoryBarrier2KHR), usage: ResourceUsage) !void {
        const resource = usage.resource;
        std.log.debug("      Checking if barrier needed for resource '{s}'", .{resource.name});

        // Skip if resource has no handle
        if (resource.handle == null) {
            std.log.debug("      - Resource has no handle, skipping barrier", .{});
            return;
        }

        const current = resource.currentState;
        const required = usage.requiredState;

        std.log.debug("      - Current state: accessMask=0x{x}, stageMask=0x{x}, layout={d}, queueFamilyIndex={d}", .{ current.accessMask, current.stageMask, current.layout, current.queueFamilyIndex });
        std.log.debug("      - Required state: accessMask=0x{x}, stageMask=0x{x}, layout={d}, queueFamilyIndex={d}", .{ required.accessMask, required.stageMask, required.layout, required.queueFamilyIndex });

        // Always create barrier for image layout transitions
        // or when access/stage masks change
        const needsBarrier = (current.accessMask != required.accessMask) or
            (current.stageMask != required.stageMask) or
            (current.layout != required.layout) or // Add check for layout transition
            (current.queueFamilyIndex != required.queueFamilyIndex);
        std.log.debug("      - needsBarrier initial value: {any}", .{needsBarrier});

        // Force barrier creation for first use in a pass
        const forceBarrier = (resource.ty == .Image and resource.currentState.firstUseInPass);

        std.log.debug("      - forceBarrier value: {any}", .{forceBarrier});

        if (!needsBarrier and !forceBarrier) {
            std.log.debug("      - No barrier needed, states are compatible", .{});
            return;
        }

        std.log.debug("      - Barrier needed, creating {s} barrier", .{@tagName(resource.ty)});

        switch (resource.ty) {
            .Image => {
                if (resource.handle == null) {
                    std.log.debug("      - Image resource has null handle!", .{});
                    return error.InvalidResourceHandle;
                }

                // Determine the actual source layout
                const srcLayout = blk: {
                    if (current.layout == vk.IMAGE_LAYOUT_UNDEFINED) {
                        // Only use UNDEFINED if the current layout is already undefined
                        break :blk vk.IMAGE_LAYOUT_UNDEFINED;
                    } else {
                        // Otherwise preserve the actual current layout
                        break :blk current.layout;
                    }
                };

                std.log.debug("      - srcLayout: {d}", .{srcLayout});

                // Determine source stage and access masks based on the layout
                const srcStageMask = if (srcLayout == vk.IMAGE_LAYOUT_UNDEFINED)
                    vk.PIPELINE_STAGE_2_TOP_OF_PIPE_BIT_KHR
                else
                    current.stageMask;

                const srcAccessMask = if (srcLayout == vk.IMAGE_LAYOUT_UNDEFINED)
                    @as(vk.AccessFlags2KHR, 0) // Explicitly cast to AccessFlags2KHR
                else
                    current.accessMask;

                // Create image memory barrier with proper initial layout
                const imageBarrier = vk.ImageMemoryBarrier2KHR{
                    .sType = vk.sTy(vk.StructureType.ImageMemoryBarrier2KHR),
                    .srcStageMask = srcStageMask,
                    .srcAccessMask = srcAccessMask,
                    .dstStageMask = required.stageMask,
                    .dstAccessMask = required.accessMask,
                    .oldLayout = srcLayout,
                    .newLayout = required.layout,
                    .srcQueueFamilyIndex = current.queueFamilyIndex,
                    .dstQueueFamilyIndex = required.queueFamilyIndex,
                    .image = resource.handle.?.image,
                    .subresourceRange = .{
                        .aspectMask = vk.IMAGE_ASPECT_COLOR_BIT, // Customize as needed
                        .baseMipLevel = 0,
                        .levelCount = vk.REMAINING_MIP_LEVELS,
                        .baseArrayLayer = 0,
                        .layerCount = vk.REMAINING_ARRAY_LAYERS,
                    },
                };

                std.log.debug("      - Image barrier created: srcStageMask=0x{x}, srcAccessMask=0x{x}, dstStageMask=0x{x}, dstAccessMask=0x{x}, oldLayout={d}, newLayout={d}", .{ imageBarrier.srcStageMask, imageBarrier.srcAccessMask, imageBarrier.dstStageMask, imageBarrier.dstAccessMask, imageBarrier.oldLayout, imageBarrier.newLayout });

                try imageBarriers.append(imageBarrier);
                std.log.debug("      - Image barrier appended to list", .{});

                // Mark that this resource has been used
                resource.currentState.firstUseInPass = false;
                resource.currentState.firstUseInFrame = false;
            },
            .Buffer => {
                std.log.debug("      - Processing buffer resource (no implementation yet)", .{});
                // Similar changes for buffer barriers...
                // ...existing buffer barrier code...
            },
        }

        std.log.debug("      - Barrier addition complete for resource '{s}'", .{resource.name});
    }
    fn addBarrierIfNeededSync1(imageBarriers: *std.ArrayList(vk.ImageMemoryBarrier), bufferBarriers: *std.ArrayList(vk.BufferMemoryBarrier), usage: ResourceUsage, srcStageMask: *vk.PipelineStageFlags, dstStageMask: *vk.PipelineStageFlags) !void {
        const resource = usage.resource;
        std.log.debug("      Checking if barrier needed for resource '{s}' (Sync 1)", .{resource.name});

        // Skip if resource has no handle
        if (resource.handle == null) {
            std.log.debug("      - Resource has no handle, skipping barrier (Sync 1)", .{});
            return;
        }

        const current = resource.currentState;
        const required = usage.requiredState;

        // Check if barrier is needed at all
        const needsBarrier = (current.accessMask != required.accessMask) or
            (current.stageMask != required.stageMask) or
            (resource.ty == .Image and current.layout != required.layout) or
            (current.queueFamilyIndex != required.queueFamilyIndex);

        // Force barrier creation for first use of an image in a pass
        const forceBarrier = (resource.ty == .Image and resource.currentState.firstUseInPass);

        if (!needsBarrier and !forceBarrier) {
            std.log.debug("      - No barrier needed, states are compatible (Sync 1)", .{});
            return;
        }

        std.log.debug("      - Barrier needed, creating {s} barrier (Sync 1)", .{@tagName(resource.ty)});

        switch (resource.ty) {
            .Image => {
                if (resource.handle == null) {
                    return error.InvalidResourceHandle;
                }

                // For first use in a frame, set source layout to UNDEFINED
                const oldLayout = if (resource.currentState.firstUseInFrame)
                    vk.IMAGE_LAYOUT_UNDEFINED
                else
                    current.layout;

                // Set stage masks - use TOP_OF_PIPE for first use and ensure stage masks are never zero
                const useSrcStageMask = if (resource.currentState.firstUseInFrame)
                    @as(u32, @intCast(vk.PIPELINE_STAGE_TOP_OF_PIPE_BIT))
                else if (current.stageMask == 0)
                    @as(u32, @intCast(vk.PIPELINE_STAGE_TOP_OF_PIPE_BIT))
                else
                    current.stageMask;

                const useDstStageMask = if (required.stageMask == 0)
                    @as(u32, @intCast(vk.PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT))
                else
                    required.stageMask;

                // Update combined stage masks for the barrier command
                srcStageMask.* |= @truncate(useSrcStageMask);
                dstStageMask.* |= @truncate(useDstStageMask);

                // Create image memory barrier for Sync 1
                const imageBarrier = vk.ImageMemoryBarrier{
                    .sType = vk.sTy(vk.StructureType.ImageMemoryBarrier),
                    .pNext = null,
                    .srcAccessMask = if (resource.currentState.firstUseInFrame) 0 else @truncate(current.accessMask),
                    .dstAccessMask = @truncate(required.accessMask),
                    .oldLayout = oldLayout,
                    .newLayout = required.layout,
                    .srcQueueFamilyIndex = current.queueFamilyIndex,
                    .dstQueueFamilyIndex = required.queueFamilyIndex,
                    .image = resource.handle.?.image,
                    .subresourceRange = .{
                        .aspectMask = vk.IMAGE_ASPECT_COLOR_BIT, // Customize as needed
                        .baseMipLevel = 0,
                        .levelCount = vk.REMAINING_MIP_LEVELS,
                        .baseArrayLayer = 0,
                        .layerCount = vk.REMAINING_ARRAY_LAYERS,
                    },
                };

                try imageBarriers.append(imageBarrier);
                std.log.debug("      - Image barrier created for full image range (Sync 1)", .{});

                // Mark that this resource has been used
                resource.currentState.firstUseInPass = false;
                resource.currentState.firstUseInFrame = false;
            },
            .Buffer => {
                if (resource.handle == null) {
                    return error.InvalidResourceHandle;
                }

                // Similar logic for buffers - stage masks need proper handling
                const useSrcStageMask = if (resource.currentState.firstUseInFrame)
                    @as(u32, @intCast(vk.PIPELINE_STAGE_TOP_OF_PIPE_BIT))
                else if (current.stageMask == 0)
                    @as(u32, @intCast(vk.PIPELINE_STAGE_TOP_OF_PIPE_BIT))
                else
                    current.stageMask;

                const useDstStageMask = if (required.stageMask == 0)
                    @as(u32, @intCast(vk.PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT))
                else
                    required.stageMask;

                // Update combined stage masks
                srcStageMask.* |= @truncate(useSrcStageMask);
                dstStageMask.* |= @truncate(useDstStageMask);

                // Create buffer memory barrier for Sync 1
                const bufferBarrier = vk.BufferMemoryBarrier{
                    .sType = vk.sTy(vk.StructureType.BufferMemoryBarrier),
                    .pNext = null,
                    .srcAccessMask = if (resource.currentState.firstUseInFrame) 0 else @truncate(current.accessMask),
                    .dstAccessMask = @truncate(required.accessMask),
                    .srcQueueFamilyIndex = current.queueFamilyIndex,
                    .dstQueueFamilyIndex = required.queueFamilyIndex,
                    .buffer = resource.handle.?.buffer,
                    .offset = 0,
                    .size = vk.WHOLE_SIZE,
                };

                try bufferBarriers.append(bufferBarrier);
                std.log.debug("      - Buffer barrier created for full buffer range (Sync 1)", .{});

                // Mark that this resource has been used
                resource.currentState.firstUseInPass = false;
                resource.currentState.firstUseInFrame = false;
            },
        }
        std.log.debug("      - Barrier addition complete for resource '{s}' (Sync 1)", .{resource.name});
    }
};
