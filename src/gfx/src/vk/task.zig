pub const vk = @import("vk.zig");
pub const std = @import("std");
const logger = @import("../logger.zig");
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

// Add a new struct to track modified regions
pub const ModifiedRegion = struct {
    offset: usize,
    size: usize,
};

pub const ResourceAccess = struct {
    sequence: u64, // When this access occurred
    region: ?ModifiedRegion,
    isWrite: bool,
};

pub const ResourceUsage = struct {
    resource: *Resource,
    requiredState: ResourceState,
    isWrite: bool,
    // Add a field to track which region of the resource is being accessed
    region: ?ModifiedRegion = null,
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
    // Track both read and write accesses with sequence numbers
    lastReadAccess: ?ResourceAccess = null,
    lastWriteAccess: ?ResourceAccess = null,
    // Keep modified regions for compatibility
    modifiedRegions: std.ArrayList(ModifiedRegion),

    // Add sequence counter
    accessSequence: u64 = 0,

    pub fn init(allocator: *std.mem.Allocator, name: []const u8, ty: ResourceType, handle: anytype) !*Resource {
        var resource = try allocator.create(Resource);
        resource.* = Resource{
            .name = try allocator.dupe(u8, name),
            .ty = ty,
            .modifiedRegions = std.ArrayList(ModifiedRegion).init(allocator.*),
            .accessSequence = 0,
        };

        // Check if handle is null
        if (handle == null) {
            // Allow null handles for resources that will be initialized later
            resource.handle = null;
            return resource;
        }

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

    pub fn deinit(self: *Resource, allocator: *std.mem.Allocator) void {
        if (self.name.len > 0) allocator.free(self.name);
        self.name = "";
        self.modifiedRegions.deinit();
        allocator.destroy(self);
    }

    pub fn recordAccess(self: *Resource, region: ?ModifiedRegion, isWrite: bool) void {
        self.accessSequence += 1;
        const access = ResourceAccess{
            .sequence = self.accessSequence,
            .region = region,
            .isWrite = isWrite,
        };

        if (isWrite) {
            self.lastWriteAccess = access;
        } else {
            self.lastReadAccess = access;
        }
    }

    pub fn needsBarrier(self: *Resource, region: ?ModifiedRegion, isWrite: bool) bool {
        // Always need barrier for first access
        if (self.lastReadAccess == null and self.lastWriteAccess == null) {
            return true;
        }

        // Write after any access needs barrier
        if (isWrite) {
            return true;
        }

        // Read after write needs barrier
        if (self.lastWriteAccess) |lastWrite| {
            // If regions overlap
            if (region != null and lastWrite.region != null) {
                const r = region.?;
                const w = lastWrite.region.?;
                if (r.offset < w.offset + w.size and r.offset + r.size > w.offset) {
                    return true;
                }
            } else {
                // If either region is null, assume overlap
                return true;
            }
        }

        return false;
    }
};

fn pass_submit_execute(ctx: PassContext) void {
    std.debug.print("[TASK] === SUBMIT PASS - CRITICAL SYNC POINT ===\n", .{});
    std.debug.print("[TASK] Command buffer: {any}\n", .{ctx.cmd});
    std.debug.print("[TASK] Queue: {any}\n", .{ctx.queue});
    std.debug.print("[TASK] In-flight fence: {any}\n", .{ctx.in_flight_fence});
    std.debug.print("[TASK] Image available semaphore: {any}\n", .{ctx.image_available_semaphore});
    std.debug.print("[TASK] Render finished semaphore: {any}\n", .{ctx.render_finished_semaphore});

    // Check if any handles are null
    if (ctx.cmd == null) {
        std.debug.print("[TASK] ERROR: Command buffer is null!\n", .{});
        return;
    }
    if (ctx.queue == null) {
        std.debug.print("[TASK] ERROR: Queue is null!\n", .{});
        return;
    }
    if (ctx.in_flight_fence == null) {
        std.debug.print("[TASK] ERROR: In-flight fence is null!\n", .{});
    }

    // Submit the queue
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

    std.debug.print("[TASK] SUBMITTING COMMAND BUFFER - Waiting on semaphore {any}, signaling semaphore {any}\n", .{ ctx.image_available_semaphore, ctx.render_finished_semaphore });

    const result = vk.queueSubmit(ctx.queue, 1, &submitInfo, ctx.in_flight_fence);
    if (result != vk.SUCCESS) {
        std.debug.print("[TASK] ERROR: Queue submission failed with result: {any}\n", .{result});

        // Try to get more info about the error
        if (result == vk.ERROR_DEVICE_LOST) {
            std.debug.print("[TASK] CRITICAL ERROR: Device lost during submission!\n", .{});
        } else if (result == vk.ERROR_OUT_OF_HOST_MEMORY) {
            std.debug.print("[TASK] ERROR: Out of host memory\n", .{});
        } else if (result == vk.ERROR_OUT_OF_DEVICE_MEMORY) {
            std.debug.print("[TASK] ERROR: Out of device memory\n", .{});
        }
    } else {
        std.debug.print("[TASK] Queue submission SUCCESSFUL - command buffer {any} submitted with fence {any}\n", .{ ctx.cmd, ctx.in_flight_fence });
    }
}

pub var pass_submit: Pass = undefined;

// Initialize pass_submit at runtime
pub fn getPassSubmit(renderer: *anyopaque) *Pass {
    if (pass_submit.name.len == 0) {
        pass_submit = Pass{
            .name = "submit",
            .inputs = getEmptyArrayList(ResourceUsage),
            .outputs = getEmptyArrayList(ResourceUsage),
            .execute = pass_submit_execute,
            .cmd = false,
        };
    }
    pass_submit.userData = renderer;

    return &pass_submit;
}

fn pass_present_execute(ctx: PassContext) void {
    logger.info("[TASK] Executing present pass with image index {}", .{ctx.frame.index});

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

    logger.info("[TASK] Presenting swapchain image to display", .{});
    const result = vk.queuePresentKHR(ctx.queue, &presentInfo);

    if (result != vk.SUCCESS) {
        logger.err("Failed to present queue: {any}", .{result});
    } else {
        logger.info("[TASK] Queue presentation successful", .{});
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

    pub fn init(allocator: *std.mem.Allocator, name: []const u8, execute: *const fn (ctx: PassContext) void) !*Pass {
        const pass = try allocator.create(Pass);
        pass.* = Pass{
            .name = try allocator.dupe(u8, name),
            .inputs = std.ArrayList(ResourceUsage).init(allocator.*),
            .outputs = std.ArrayList(ResourceUsage).init(allocator.*),
            .execute = execute,
            .cmd = true,
        };
        return pass;
    }
    pub fn deinit(self: *Pass, allocator: *std.mem.Allocator) void {
        // Note: We don't check resource lifetime here - resources are managed externally
        // or by their owners
        self.inputs.deinit();
        self.outputs.deinit();
        if (self.name.len > 0) allocator.free(self.name);
        self.name = "";
        // Don't set execute to null as it requires a valid function pointer
    }

    pub fn addInput(self: *Pass, resource: *Resource, requiredState: ResourceState, region: ?ModifiedRegion) !void {
        try self.inputs.append(.{
            .resource = resource,
            .requiredState = requiredState,
            .isWrite = false,
            .region = region,
        });
    }

    pub fn addOutput(self: *Pass, resource: *Resource, requiredState: ResourceState, region: ?ModifiedRegion) !void {
        try self.outputs.append(.{
            .resource = resource,
            .requiredState = requiredState,
            .isWrite = true,
            .region = region,
        });

        // If this is a write operation and a region is specified, add it to the modified regions
        if (region) |r| {
            try resource.modifiedRegions.append(r);
        }
    }
};

pub const PassContext = struct { cmd: vk.CommandBuffer, queue: vk.Queue, swapchain: vk.Swapchain, render_finished_semaphore: vk.Semaphore, image_available_semaphore: vk.Semaphore, in_flight_fence: vk.Fence, frame: *frame.Frame, userData: ?*anyopaque, pass: *Pass = undefined };

pub const HandleState = struct {
    state: ResourceState,
    firstUseInPass: bool = true,
    firstUseInFrame: bool = true,
    modifiedRegions: std.ArrayList(ModifiedRegion),

    pub fn init(allocator: std.mem.Allocator) HandleState {
        return HandleState{
            .state = ResourceState{},
            .modifiedRegions = std.ArrayList(ModifiedRegion).init(allocator),
        };
    }

    pub fn deinit(self: *HandleState) void {
        self.modifiedRegions.deinit();
    }
};

pub const Graph = struct {
    allocator: *std.mem.Allocator,
    passes: std.ArrayList(*Pass),
    resources: std.ArrayList(*Resource),
    userData: ?*anyopaque,
    use_sync2: bool = true,

    // Track states by handle instead of by Resource
    bufferStates: std.AutoHashMap(vk.Buffer, HandleState),
    imageStates: std.AutoHashMap(vk.Image, HandleState),

    swapchain: vk.Swapchain,
    render_finished_semaphore: vk.Semaphore,
    image_available_semaphore: vk.Semaphore,
    in_flight_fence: vk.Fence,
    queue: vk.Queue,

    pub fn init(allocator: *std.mem.Allocator, userData: ?*anyopaque, swapchain: vk.Swapchain, render_finished_semaphore: vk.Semaphore, image_available_semaphore: vk.Semaphore, in_flight_fence: vk.Fence, queue: vk.Queue, use_sync2: bool) !*Graph {
        const graph = try allocator.create(Graph);
        graph.* = Graph{
            .allocator = allocator,
            .passes = std.ArrayList(*Pass).init(allocator.*),
            .resources = std.ArrayList(*Resource).init(allocator.*),
            .userData = userData,
            .swapchain = swapchain,
            .render_finished_semaphore = render_finished_semaphore,
            .image_available_semaphore = image_available_semaphore,
            .in_flight_fence = in_flight_fence,
            .queue = queue,
            .use_sync2 = use_sync2,
            .bufferStates = std.AutoHashMap(vk.Buffer, HandleState).init(allocator.*),
            .imageStates = std.AutoHashMap(vk.Image, HandleState).init(allocator.*),
        };
        return graph;
    }

    pub fn deinit(self: *Graph) void {
        // Clean up handle states
        var buffer_it = self.bufferStates.iterator();
        while (buffer_it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.bufferStates.deinit();

        var image_it = self.imageStates.iterator();
        while (image_it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.imageStates.deinit();

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

    pub fn hasPass(self: *Graph, pass: *Pass) bool {
        for (self.passes.items) |existing_pass| {
            if (existing_pass == pass) {
                return true;
            }
        }
        return false;
    }

    pub fn addResource(self: *Graph, resource: *Resource) !void {
        try self.resources.append(resource);
    }

    pub fn execute(self: *Graph, cmd: vk.CommandBuffer, passContext: PassContext) !void {
        logger.info("[TASK] Starting graph execution with {d} passes", .{self.passes.items.len});
        var activePassContext = passContext;

        logger.info("[TASK] Building execution order", .{});
        const executionOrder = try self.buildExecutionOrder();
        defer self.allocator.free(executionOrder);
        logger.info("[TASK] Built execution order with {d} passes", .{executionOrder.len});

        const DeferNonCmd = struct {
            passContext: PassContext,
            execute: *const fn (ctx: PassContext) void,
        };

        var nonCmds = std.AutoHashMap(u64, DeferNonCmd).init(self.allocator.*); // Using StringHashMap instead

        logger.info("[TASK] Initializing resource states for all passes", .{});
        for (executionOrder) |pass| {
            const activePass = self.passes.items[pass];
            logger.debug("[TASK] Initializing state for pass: {s}", .{activePass.name});
            //loop through all resources in pass
            for (activePass.inputs.items) |usage| {
                usage.resource.currentState.firstUseInFrame = true;
            }
            for (activePass.outputs.items) |usage| {
                usage.resource.currentState.firstUseInFrame = true;
            }
        }

        logger.info("[TASK] Beginning command buffer recording", .{});
        _ = vk.BeginCommandBuffer(cmd, &.{
            .sType = vk.sTy(vk.StructureType.CommandBufferBeginInfo),
            .flags = vk.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null,
        });

        logger.info("[TASK] Executing {d} passes in sequence", .{executionOrder.len});
        for (executionOrder, 0..) |pass, i| {
            const activePass = self.passes.items[pass];
            logger.info("[TASK] Executing pass {d}/{d}: '{s}'", .{ i + 1, executionOrder.len, activePass.name });

            // Reset first-use flags for this pass
            logger.debug("[TASK] Resetting first-use flags for {s}", .{activePass.name});
            for (activePass.inputs.items) |usage| {
                usage.resource.currentState.firstUseInPass = true;
            }
            for (activePass.outputs.items) |usage| {
                usage.resource.currentState.firstUseInPass = true;
            }

            const activeExecute = activePass.execute;

            logger.debug("[TASK] Inserting barriers for pass {s}", .{activePass.name});
            try self.insertBarriers(cmd, activePass);

            activePassContext.pass = activePass;

            // CRITICAL FIX: Use each pass's own userData instead of the shared context userData
            // This ensures each pass gets its correct userData pointer
            activePassContext.userData = activePass.userData;

            if (activePass.cmd) {
                std.debug.print("[TASK] ==== STARTING PASS EXECUTION: {s} ====\n", .{activePass.name});
                std.debug.print("[TASK] Command buffer: {any}\n", .{activePassContext.cmd});
                std.debug.print("[TASK] Using pass-specific userData: {any}\n", .{activePassContext.userData});

                if (std.mem.eql(u8, activePass.name, "CameraUpdate")) {
                    std.debug.print("[TASK] CAMERA PASS EXECUTION - detailed debugging\n", .{});
                    std.debug.print("[TASK] Camera pass inputs: {d}, outputs: {d}\n", .{ activePass.inputs.items.len, activePass.outputs.items.len });

                    if (activePass.userData != null) {
                        std.debug.print("[TASK] Camera pass userData is {any}\n", .{activePass.userData});
                    } else {
                        std.debug.print("[TASK] WARNING: Camera pass userData is NULL!\n", .{});
                    }
                }

                logger.debug("[TASK] Executing command-based pass: {s}", .{activePass.name});
                activeExecute(activePassContext);
                std.debug.print("[TASK] ==== COMPLETED PASS EXECUTION: {s} ====\n", .{activePass.name});
            } else {
                logger.debug("[TASK] Deferring non-command pass: {s}", .{activePass.name});

                // CRITICAL FIX: Ensure the deferred pass also uses its own userData
                var deferredPassContext = activePassContext;
                deferredPassContext.userData = activePass.userData;

                const nextNonCmd = DeferNonCmd{ .execute = activeExecute, .passContext = deferredPassContext };
                nonCmds.put(i, nextNonCmd) catch |err| {
                    logger.err("[TASK] Failed to queue deferred pass: {s}, error: {any}", .{ activePass.name, err });
                    return err;
                };
            }
            logger.info("[TASK] Completed pass: {s}", .{activePass.name});
        }

        logger.info("[TASK] Ending command buffer recording", .{});
        _ = vk.EndCommandBuffer(cmd);

        logger.info("[TASK] Executing {d} deferred non-command passes", .{nonCmds.count()});

        // Create a sorted array of indices for nonCmds
        var sortedIndices = std.ArrayList(usize).init(self.allocator.*);
        defer sortedIndices.deinit();

        // Collect all indices from the nonCmds map
        var nonCmds_it = nonCmds.iterator();
        while (nonCmds_it.next()) |entry| {
            try sortedIndices.append(entry.key_ptr.*);
        }

        // Sort the indices from low to high
        std.sort.insertion(usize, sortedIndices.items, {}, std.sort.asc(usize));

        // Execute nonCmds in sorted order
        for (sortedIndices.items) |passIndex| {
            const pc = nonCmds.get(passIndex).?;
            logger.info("[TASK] Executing deferred pass {d}: {s}", .{ passIndex, pc.passContext.pass.name });
            pc.execute(pc.passContext);
        }

        logger.info("[TASK] Graph execution completed successfully", .{});
    }

    fn buildExecutionOrder(self: *Graph) ![]usize {
        logger.debug("[TASK] Building execution order for {d} passes", .{self.passes.items.len});

        // For simplicity, just use the order passes were added
        // A more sophisticated implementation would analyze dependencies
        // and potentially reorder for improved parallelism
        var result = try self.allocator.alloc(usize, self.passes.items.len);
        for (0..self.passes.items.len) |i| {
            result[i] = i;
            logger.debug("[TASK] Added pass {d} to execution order: {s}", .{ i, self.passes.items[i].name });
        }

        logger.debug("[TASK] Execution order built successfully", .{});
        return result;
    }
    fn insertBarriers(self: *Graph, commandBuffer: vk.CommandBuffer, pass: *Pass) !void {
        logger.debug("[TASK] Inserting barriers for pass '{s}' (resources: {d} inputs, {d} outputs)", .{ pass.name, pass.inputs.items.len, pass.outputs.items.len });

        if (self.use_sync2) {
            logger.debug("[TASK] Using Synchronization 2 API for barriers", .{});
            // Use Synchronization 2 (existing implementation)
            var imageBarriers = std.ArrayList(vk.ImageMemoryBarrier2KHR).init(self.allocator.*);
            defer imageBarriers.deinit();

            var bufferBarriers = std.ArrayList(vk.BufferMemoryBarrier2KHR).init(self.allocator.*);
            defer bufferBarriers.deinit();

            // Process inputs
            logger.debug("[TASK] Processing {d} input barriers for pass '{s}'", .{ pass.inputs.items.len, pass.name });
            for (pass.inputs.items, 0..) |input, i| {
                logger.debug("[TASK] Processing input {d}/{d}: {s}", .{ i + 1, pass.inputs.items.len, input.resource.name });
                try self.addBarrierIfNeededSync2(&imageBarriers, input);
            }

            // Process outputs
            logger.debug("[TASK] Processing {d} output barriers for pass '{s}'", .{ pass.outputs.items.len, pass.name });
            for (pass.outputs.items, 0..) |output, i| {
                logger.debug("[TASK] Processing output {d}/{d}: {s}", .{ i + 1, pass.outputs.items.len, output.resource.name });
                try self.addBarrierIfNeededSync2(&imageBarriers, output);
            }

            // If we have any barriers, insert them
            if (imageBarriers.items.len > 0 or bufferBarriers.items.len > 0) {
                logger.info("[TASK] Inserting {d} image barriers and {d} buffer barriers", .{ imageBarriers.items.len, bufferBarriers.items.len });

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
                logger.debug("[TASK] Pipeline barriers inserted successfully", .{});
            } else {
                logger.debug("[TASK] No barriers needed for pass '{s}'", .{pass.name});
            }
        } else {
            logger.debug("[TASK] Using Synchronization 1 API (fallback) for barriers", .{});
            // Use Synchronization 1 (fallback)
            var imageBarriers = std.ArrayList(vk.ImageMemoryBarrier).init(self.allocator.*);
            defer imageBarriers.deinit();

            var bufferBarriers = std.ArrayList(vk.BufferMemoryBarrier).init(self.allocator.*);
            defer bufferBarriers.deinit();

            // Initialize to sensible defaults instead of 0
            var srcStageMask: vk.PipelineStageFlags = vk.PIPELINE_STAGE_TOP_OF_PIPE_BIT;
            var dstStageMask: vk.PipelineStageFlags = vk.PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT;

            // Process inputs
            logger.debug("[TASK] Processing {d} input barriers for pass '{s}'", .{ pass.inputs.items.len, pass.name });
            for (pass.inputs.items, 0..) |input, i| {
                logger.debug("[TASK] Processing input {d}/{d}: {s}", .{ i + 1, pass.inputs.items.len, input.resource.name });
                try self.addBarrierIfNeededSync1(&imageBarriers, &bufferBarriers, input, &srcStageMask, &dstStageMask);
            }

            // Process outputs
            logger.debug("[TASK] Processing {d} output barriers for pass '{s}'", .{ pass.outputs.items.len, pass.name });
            for (pass.outputs.items, 0..) |output, i| {
                logger.debug("[TASK] Processing output {d}/{d}: {s}", .{ i + 1, pass.outputs.items.len, output.resource.name });
                try self.addBarrierIfNeededSync1(&imageBarriers, &bufferBarriers, output, &srcStageMask, &dstStageMask);
            }

            // If we have any barriers, insert them
            if (imageBarriers.items.len > 0 or bufferBarriers.items.len > 0) {
                logger.info("[TASK] Inserting {d} image barriers and {d} buffer barriers with stage masks: src=0x{x}, dst=0x{x}", .{ imageBarriers.items.len, bufferBarriers.items.len, srcStageMask, dstStageMask });

                vk.cmdPipelineBarrier(commandBuffer, srcStageMask, dstStageMask, 0, // No dependency flags
                    0, null, // No memory barriers
                    @intCast(bufferBarriers.items.len), if (bufferBarriers.items.len > 0) bufferBarriers.items.ptr else null, @intCast(imageBarriers.items.len), if (imageBarriers.items.len > 0) imageBarriers.items.ptr else null);

                logger.debug("[TASK] Pipeline barriers inserted successfully", .{});
            } else {
                logger.debug("[TASK] No barriers needed for pass '{s}'", .{pass.name});
            }
        }
    }

    fn addBarrierIfNeededSync2(self: *Graph, imageBarriers: *std.ArrayList(vk.ImageMemoryBarrier2KHR), usage: ResourceUsage) !void {
        const resource = usage.resource;

        // Skip if resource has no handle
        if (resource.handle == null) {
            logger.debug("[BARRIER] Skipping barrier for resource '{s}': no handle", .{resource.name});
            return;
        }

        // Get or create handle state
        var handleState = try self.getOrCreateHandleState(resource);
        const current = &handleState.state;
        const required = usage.requiredState;

        // Check if the region being accessed overlaps with any modified regions
        var needsBarrier = false;

        // If this is a read operation and a region is specified, check if it overlaps with any modified regions
        if (!usage.isWrite) {
            if (usage.region) |region| {
                for (handleState.modifiedRegions.items) |modifiedRegion| {
                    // Check for overlap
                    if (region.offset < modifiedRegion.offset + modifiedRegion.size and
                        region.offset + region.size > modifiedRegion.offset)
                    {
                        needsBarrier = true;
                        break;
                    }
                }
            }
        }

        // Always create barrier for image layout transitions
        // or when access/stage masks change
        needsBarrier = needsBarrier or
            (current.accessMask != required.accessMask) or
            (current.stageMask != required.stageMask) or
            (current.layout != required.layout) or
            (current.queueFamilyIndex != required.queueFamilyIndex);

        // Force barrier creation for first use in a pass
        const forceBarrier = (resource.ty == .Image and handleState.firstUseInPass);

        logger.debug("[BARRIER] Resource '{s}': needsBarrier={}, forceBarrier={}", .{ resource.name, needsBarrier, forceBarrier });

        if (!needsBarrier and !forceBarrier) {
            logger.debug("[BARRIER] No barrier needed for resource '{s}'", .{resource.name});
            return;
        }

        switch (resource.ty) {
            .Image => {
                if (resource.handle == null) {
                    logger.err("[BARRIER] Invalid resource handle for '{s}'", .{resource.name});
                    return error.InvalidResourceHandle;
                }

                logger.debug("[BARRIER] Creating image barrier for '{s}'", .{resource.name});
                logger.debug("[BARRIER] Current state: access=0x{x}, stage=0x{x}, layout={any}", .{ current.accessMask, current.stageMask, current.layout });
                logger.debug("[BARRIER] Required state: access=0x{x}, stage=0x{x}, layout={any}", .{ required.accessMask, required.stageMask, required.layout });

                // Determine the actual source layout
                const srcLayout = blk: {
                    if (current.layout == vk.IMAGE_LAYOUT_UNDEFINED) {
                        // Only use UNDEFINED if the current layout is already undefined
                        logger.debug("[BARRIER] Using UNDEFINED as source layout for '{s}'", .{resource.name});
                        break :blk vk.IMAGE_LAYOUT_UNDEFINED;
                    } else {
                        // Otherwise preserve the actual current layout
                        logger.debug("[BARRIER] Using current layout as source layout for '{s}': {any}", .{ resource.name, current.layout });
                        break :blk current.layout;
                    }
                };

                // Determine source stage and access masks based on the layout
                const srcStageMask = if (srcLayout == vk.IMAGE_LAYOUT_UNDEFINED)
                    vk.PIPELINE_STAGE_2_TOP_OF_PIPE_BIT_KHR
                else
                    current.stageMask;

                const srcAccessMask = if (srcLayout == vk.IMAGE_LAYOUT_UNDEFINED)
                    @as(vk.AccessFlags2KHR, 0)
                else
                    current.accessMask;

                logger.debug("[BARRIER] Final barrier params for '{s}': srcStage=0x{x}, srcAccess=0x{x}, dstStage=0x{x}, dstAccess=0x{x}, oldLayout={any}, newLayout={any}", .{ resource.name, srcStageMask, srcAccessMask, required.stageMask, required.accessMask, srcLayout, required.layout });

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
                        .aspectMask = vk.IMAGE_ASPECT_COLOR_BIT,
                        .baseMipLevel = 0,
                        .levelCount = vk.REMAINING_MIP_LEVELS,
                        .baseArrayLayer = 0,
                        .layerCount = vk.REMAINING_ARRAY_LAYERS,
                    },
                };

                try imageBarriers.append(imageBarrier);
                logger.debug("[BARRIER] Added image barrier for '{s}'", .{resource.name});

                // Mark that this resource has been used
                handleState.firstUseInPass = false;
                handleState.firstUseInFrame = false;

                // Update the current state to match the required state
                handleState.state = required;
                logger.debug("[BARRIER] Updated current state for '{s}'", .{resource.name});
            },
            .Buffer => {
                // Similar changes for buffer barriers...
                logger.debug("[BARRIER] Buffer barriers not yet implemented for '{s}'", .{resource.name});
            },
        }
    }
    fn addBarrierIfNeededSync1(self: *Graph, imageBarriers: *std.ArrayList(vk.ImageMemoryBarrier), bufferBarriers: *std.ArrayList(vk.BufferMemoryBarrier), usage: ResourceUsage, srcStageMask: *vk.PipelineStageFlags, dstStageMask: *vk.PipelineStageFlags) !void {
        const resource = usage.resource;

        // Skip if resource has no handle
        if (resource.handle == null) {
            logger.debug("[BARRIER-SYNC1] Skipping barrier for resource '{s}': no handle", .{resource.name});
            return;
        }

        // Get or create handle state
        var handleState = try self.getOrCreateHandleState(resource);
        const current = &handleState.state;
        const required = usage.requiredState;

        // Check if the region being accessed overlaps with any modified regions
        var needsBarrier = false;

        // If this is a read operation and a region is specified, check if it overlaps with any modified regions
        if (!usage.isWrite) {
            if (usage.region) |region| {
                for (handleState.modifiedRegions.items) |modifiedRegion| {
                    // Check for overlap
                    if (region.offset < modifiedRegion.offset + modifiedRegion.size and
                        region.offset + region.size > modifiedRegion.offset)
                    {
                        needsBarrier = true;
                        break;
                    }
                }
            }
        }

        // Check if barrier is needed at all
        needsBarrier = needsBarrier or
            (current.accessMask != required.accessMask) or
            (current.stageMask != required.stageMask) or
            (resource.ty == .Image and current.layout != required.layout) or
            (current.queueFamilyIndex != required.queueFamilyIndex);

        // Force barrier creation for first use of an image in a pass
        const forceBarrier = (resource.ty == .Image and handleState.firstUseInPass);

        logger.debug("[BARRIER-SYNC1] Resource '{s}': needsBarrier={}, forceBarrier={}", .{ resource.name, needsBarrier, forceBarrier });

        if (!needsBarrier and !forceBarrier) {
            logger.debug("[BARRIER-SYNC1] No barrier needed for resource '{s}'", .{resource.name});
            return;
        }

        switch (resource.ty) {
            .Image => {
                if (resource.handle == null) {
                    logger.err("[BARRIER-SYNC1] Invalid resource handle for '{s}'", .{resource.name});
                    return error.InvalidResourceHandle;
                }

                logger.debug("[BARRIER-SYNC1] Creating image barrier for '{s}'", .{resource.name});
                logger.debug("[BARRIER-SYNC1] Current state: access=0x{x}, stage=0x{x}, layout={any}", .{ current.accessMask, current.stageMask, current.layout });
                logger.debug("[BARRIER-SYNC1] Required state: access=0x{x}, stage=0x{x}, layout={any}", .{ required.accessMask, required.stageMask, required.layout });

                // For first use in a frame, set source layout to UNDEFINED
                const oldLayout = if (handleState.firstUseInFrame)
                    vk.IMAGE_LAYOUT_UNDEFINED
                else
                    current.layout;

                // Set stage masks - use TOP_OF_PIPE for first use and ensure stage masks are never zero
                const useSrcStageMask = if (handleState.firstUseInFrame)
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

                logger.debug("[BARRIER-SYNC1] Stage masks for '{s}': src=0x{x}, dst=0x{x}", .{ resource.name, useSrcStageMask, useDstStageMask });

                // Source access mask may be 0 for first use in frame
                const srcAccess = if (handleState.firstUseInFrame) 0 else @as(u32, @truncate(current.accessMask));

                logger.debug("[BARRIER-SYNC1] Final barrier params for '{s}': srcAccess=0x{x}, dstAccess=0x{x}, oldLayout={any}, newLayout={any}", .{ resource.name, srcAccess, @as(u32, @truncate(required.accessMask)), oldLayout, required.layout });

                // Create image memory barrier for Sync 1
                const imageBarrier = vk.ImageMemoryBarrier{
                    .sType = vk.sTy(vk.StructureType.ImageMemoryBarrier),
                    .pNext = null,
                    .srcAccessMask = srcAccess,
                    .dstAccessMask = @truncate(required.accessMask),
                    .oldLayout = oldLayout,
                    .newLayout = required.layout,
                    .srcQueueFamilyIndex = current.queueFamilyIndex,
                    .dstQueueFamilyIndex = required.queueFamilyIndex,
                    .image = resource.handle.?.image,
                    .subresourceRange = .{
                        .aspectMask = vk.IMAGE_ASPECT_COLOR_BIT,
                        .baseMipLevel = 0,
                        .levelCount = vk.REMAINING_MIP_LEVELS,
                        .baseArrayLayer = 0,
                        .layerCount = vk.REMAINING_ARRAY_LAYERS,
                    },
                };

                try imageBarriers.append(imageBarrier);
                logger.debug("[BARRIER-SYNC1] Added image barrier for '{s}'", .{resource.name});

                // Mark that this resource has been used
                handleState.firstUseInPass = false;
                handleState.firstUseInFrame = false;

                // Update the current state to match the required state
                handleState.state = required;
                logger.debug("[BARRIER-SYNC1] Updated current state for '{s}'", .{resource.name});
            },
            .Buffer => {
                if (resource.handle == null) {
                    logger.err("[BARRIER-SYNC1] Invalid resource handle for buffer '{s}'", .{resource.name});
                    return error.InvalidResourceHandle;
                }

                logger.debug("[BARRIER-SYNC1] Creating buffer barrier for '{s}'", .{resource.name});
                logger.debug("[BARRIER-SYNC1] Current state: access=0x{x}, stage=0x{x}", .{ current.accessMask, current.stageMask });
                logger.debug("[BARRIER-SYNC1] Required state: access=0x{x}, stage=0x{x}", .{ required.accessMask, required.stageMask });

                // Similar logic for buffers - stage masks need proper handling
                const useSrcStageMask = if (handleState.firstUseInFrame)
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

                logger.debug("[BARRIER-SYNC1] Stage masks for '{s}': src=0x{x}, dst=0x{x}", .{ resource.name, useSrcStageMask, useDstStageMask });

                // Source access mask may be 0 for first use in frame
                const srcAccess = if (handleState.firstUseInFrame) 0 else @as(u32, @truncate(current.accessMask));

                logger.debug("[BARRIER-SYNC1] Final barrier params for buffer '{s}': srcAccess=0x{x}, dstAccess=0x{x}", .{ resource.name, srcAccess, @as(u32, @truncate(required.accessMask)) });

                // Create buffer memory barrier for Sync 1
                const bufferBarrier = vk.BufferMemoryBarrier{
                    .sType = vk.sTy(vk.StructureType.BufferMemoryBarrier),
                    .pNext = null,
                    .srcAccessMask = srcAccess,
                    .dstAccessMask = @truncate(required.accessMask),
                    .srcQueueFamilyIndex = current.queueFamilyIndex,
                    .dstQueueFamilyIndex = required.queueFamilyIndex,
                    .buffer = resource.handle.?.buffer,
                    .offset = 0,
                    .size = vk.WHOLE_SIZE,
                };

                try bufferBarriers.append(bufferBarrier);
                logger.debug("[BARRIER-SYNC1] Added buffer barrier for '{s}'", .{resource.name});

                // Mark that this resource has been used
                handleState.firstUseInPass = false;
                handleState.firstUseInFrame = false;

                // Update the current state to match the required state
                handleState.state = required;
                logger.debug("[BARRIER-SYNC1] Updated current state for '{s}'", .{resource.name});
            },
        }
    }

    fn getOrCreateHandleState(self: *Graph, resource: *Resource) !*HandleState {
        if (resource.handle) |handle| {
            switch (resource.ty) {
                .Buffer => {
                    const gop = try self.bufferStates.getOrPut(handle.buffer);
                    if (!gop.found_existing) {
                        gop.value_ptr.* = HandleState.init(self.allocator.*);
                    }
                    return gop.value_ptr;
                },
                .Image => {
                    const gop = try self.imageStates.getOrPut(handle.image);
                    if (!gop.found_existing) {
                        gop.value_ptr.* = HandleState.init(self.allocator.*);
                    }
                    return gop.value_ptr;
                },
            }
        }
        return error.NoResourceHandle;
    }
};
