pub const vk = @import("vk.zig");
pub const std = @import("std");
pub const frame = @import("frame.zig");

// Type imports
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// Global allocator for task system
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var taskAllocator = gpa.allocator();

// Function to get an allocator-enabled empty ArrayList
fn getEmptyArrayList(comptime T: type) std.ArrayList(T) {
    return std.ArrayList(T).init(taskAllocator);
}

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

// Custom equality function since we can't use std.meta.eql
pub fn resourcesEqual(a: anytype, b: @TypeOf(a)) bool {
    return @intFromPtr(a) == @intFromPtr(b);
}

pub const Resource = struct {
    name: []const u8,
    ty: ResourceType,
    handle: ?ResourceHandle = null,
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

        // Check the actual type of the handle and assign accordingly
        if (ty == .Buffer) {
            // Ensure handle is a vk.Buffer
            if (@TypeOf(handle) != vk.Buffer) {
                return error.TypeMismatch;
            }
            resource.handle = .{ .buffer = handle };
        } else if (ty == .Image) {
            // Ensure handle is a vk.Image
            if (@TypeOf(handle) != vk.Image) {
                return error.TypeMismatch;
            }
            resource.handle = .{ .image = handle };
        }

        return resource;
    }

    pub fn createView(self: *Resource, device: vk.Device, viewType: vk.ImageViewType, format: vk.Format) !void {
        // Creating view for resource
        if (self.ty != .Image) {
            // Resource is not an image, cannot create view
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
        const result = vk.createImageView(device, &imageViewInfo, null, &imageView);
        if (result != vk.SUCCESS) {
            return error.CreateImageViewFailed;
        }
        self.view = .{ .imageView = imageView };

        // Successfully created view for resource
    }

    pub fn deinit(self: *Resource, allocator_ptr: *anyopaque) void {
        const allocator = @as(*Allocator, @ptrCast(@alignCast(allocator_ptr)));
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

pub var pass_submit: Pass = undefined;

// Initialize pass_submit at runtime
pub fn getPassSubmit() *Pass {
    if (pass_submit.name.len == 0) {
        pass_submit = Pass{
            .name = "submit",
            .inputs = getEmptyArrayList(ResourceUsage),
            .outputs = getEmptyArrayList(ResourceUsage),
            .execute = pass_submit_execute,
            .cmd = false,
        };
    }
    return &pass_submit;
}

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
        unreachable;
    }
}

pub fn pass_present(swapchain_resource: *Resource) *Pass {
    var inputs = getEmptyArrayList(ResourceUsage);
    const outputs = getEmptyArrayList(ResourceUsage);
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
    userData: ?*anyopaque = null, // Added field to store user data
    deinit_fn: ?*const fn (p: *Pass, allocator: *anyopaque) void = null, // Custom deinitialization function

    pub fn init(allocator: Allocator, name: []const u8, execute: *const fn (ctx: PassContext) void) !*Pass {
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
    pub fn deinit(self: *Pass, allocator: Allocator) void {
        // Note: We don't check resource lifetime here - resources are managed externally
        // or by their owners
        self.inputs.deinit();
        self.outputs.deinit();
        if (self.name.len > 0) allocator.free(self.name);
        self.name = "";
        // Don't set execute to null as it requires a valid function pointer
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
            resource.deinit(&self.allocator);
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

    pub fn execute(self: *Graph, cmd: vk.CommandBuffer, passContext: PassContext) !void {
        var activePassContext = passContext;

        const executionOrder = try self.buildExecutionOrder();
        defer self.allocator.free(executionOrder);

        const DeferNonCmd = struct {
            passContext: PassContext,
            execute: *const fn (ctx: PassContext) void,
        };

        var nonCmds = std.AutoHashMap(u64, DeferNonCmd).init(self.allocator); // Using StringHashMap instead

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
            for (activePass.inputs.items) |usage| {
                usage.resource.currentState.firstUseInPass = true;
            }
            for (activePass.outputs.items) |usage| {
                usage.resource.currentState.firstUseInPass = true;
            }

            const activeExecute = activePass.execute;

            try self.insertBarriers(cmd, activePass);

            activePassContext.pass = activePass;
            if (activePass.cmd) {
                activeExecute(activePassContext);
            } else {
                const nextNonCmd = DeferNonCmd{ .execute = activeExecute, .passContext = activePassContext };
                nonCmds.put(i, nextNonCmd) catch |err| {
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

    }

    fn buildExecutionOrder(self: *Graph) ![]usize {

        // For simplicity, just use the order passes were added
        // A more sophisticated implementation would analyze dependencies
        // and potentially reorder for improved parallelism
        var result = try self.allocator.alloc(usize, self.passes.items.len);
        for (0..self.passes.items.len) |i| {
            result[i] = i;
        }

        return result;
    }
    fn insertBarriers(self: *Graph, commandBuffer: vk.CommandBuffer, pass: *Pass) !void {

        if (self.use_sync2) {
            // Use Synchronization 2 (existing implementation)
            var imageBarriers = std.ArrayList(vk.ImageMemoryBarrier2KHR).init(self.allocator);
            defer imageBarriers.deinit();

            var bufferBarriers = std.ArrayList(vk.BufferMemoryBarrier2KHR).init(self.allocator);
            defer bufferBarriers.deinit();

            // Process inputs
            for (pass.inputs.items) |input| {
                try Graph.addBarrierIfNeededSync2(&imageBarriers, input);
            }

            // Process outputs
            for (pass.outputs.items) |output| {
                try Graph.addBarrierIfNeededSync2(&imageBarriers, output);
            }

            // If we have any barriers, insert them

            if (imageBarriers.items.len > 0 or bufferBarriers.items.len > 0) {
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
            } else {
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
            for (pass.inputs.items) |input| {
                try Graph.addBarrierIfNeededSync1(&imageBarriers, &bufferBarriers, input, &srcStageMask, &dstStageMask);
            }

            // Process outputs
            for (pass.outputs.items) |output| {
                try Graph.addBarrierIfNeededSync1(&imageBarriers, &bufferBarriers, output, &srcStageMask, &dstStageMask);
            }

            // If we have any barriers, insert them

            if (imageBarriers.items.len > 0 or bufferBarriers.items.len > 0) {
                vk.cmdPipelineBarrier(commandBuffer, srcStageMask, dstStageMask, 0, // No dependency flags
                    0, null, // No memory barriers
                    @intCast(bufferBarriers.items.len), if (bufferBarriers.items.len > 0) bufferBarriers.items.ptr else null, @intCast(imageBarriers.items.len), if (imageBarriers.items.len > 0) imageBarriers.items.ptr else null);
            } else {
            }
        }

    }

    fn addBarrierIfNeededSync2(imageBarriers: *std.ArrayList(vk.ImageMemoryBarrier2KHR), usage: ResourceUsage) !void {
        const resource = usage.resource;

        // Skip if resource has no handle
        if (resource.handle == null) {
            return;
        }

        const current = resource.currentState;
        const required = usage.requiredState;


        // Always create barrier for image layout transitions
        // or when access/stage masks change
        const needsBarrier = (current.accessMask != required.accessMask) or
            (current.stageMask != required.stageMask) or
            (current.layout != required.layout) or // Add check for layout transition
            (current.queueFamilyIndex != required.queueFamilyIndex);

        // Force barrier creation for first use in a pass
        const forceBarrier = (resource.ty == .Image and resource.currentState.firstUseInPass);


        if (!needsBarrier and !forceBarrier) {
            return;
        }


        switch (resource.ty) {
            .Image => {
                if (resource.handle == null) {
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


                try imageBarriers.append(imageBarrier);

                // Mark that this resource has been used
                resource.currentState.firstUseInPass = false;
                resource.currentState.firstUseInFrame = false;
            },
            .Buffer => {
                // Similar changes for buffer barriers...
                // ...existing buffer barrier code...
            },
        }

    }
    fn addBarrierIfNeededSync1(imageBarriers: *std.ArrayList(vk.ImageMemoryBarrier), bufferBarriers: *std.ArrayList(vk.BufferMemoryBarrier), usage: ResourceUsage, srcStageMask: *vk.PipelineStageFlags, dstStageMask: *vk.PipelineStageFlags) !void {
        const resource = usage.resource;

        // Skip if resource has no handle
        if (resource.handle == null) {
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
            return;
        }


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

                // Mark that this resource has been used
                resource.currentState.firstUseInPass = false;
                resource.currentState.firstUseInFrame = false;
            },
        }
    }
};
