pub const vk = @import("vk.zig");
pub const std = @import("std");
pub const frame = @import("frame.zig");

pub const ResourceType = enum { Buffer, Image };

pub const ResourceState = struct {
    accessMask: vk.AccessFlags = 0,
    stageMask: vk.PipelineStageFlags = vk.PIPELINE_STAGE_NONE,
    layout: vk.ImageLayout = vk.IMAGE_LAYOUT_UNDEFINED,
    queueFamilyIndex: u32 = vk.QUEUE_FAMILY_IGNORED,
};

pub const ResourceUsage = struct {
    resource: *Resource,
    requiredState: ResourceState,
    isWrite: bool,
};

pub const Resource = struct {
    name: []const u8,
    ty: ResourceType,
    handle: ?union {
        buffer: vk.Buffer,
        image: vk.Image,
    },
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

        switch (ty) {
            .Buffer => resource.handle.buffer = handle,
            .Image => resource.handle.image = handle,
        }

        return resource;
    }

    pub fn createView(self: *Resource, allocator: std.mem.Allocator, viewType: vk.ImageViewType, format: vk.Format) !void {
        if (self.ty != .Image) return error.InvalidResourceType;

        const imageViewInfo = vk.ImageViewCreateInfo{
            .sType = vk.sTy(vk.StructureType.ImageViewCreateInfo),
            .image = self.handle.image,
            .viewType = viewType,
            .format = format,
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

        self.view.imageView = try allocator.create(vk.ImageView);
        const result = vk.createImageView(vk.device, &imageViewInfo, null, &self.view.imageView);
        if (result != vk.SUCCESS) {
            allocator.destroy(self.view.imageView);
            return error.CreateImageViewFailed;
        }
    }

    pub fn deinit(self: *Resource, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.destroy(self);
    }
};

pub const Pass = struct {
    name: []const u8,
    inputs: std.ArrayList(ResourceUsage),
    outputs: std.ArrayList(ResourceUsage),
    execute: *const fn (ctx: PassContext) void,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, execute: *const fn (ctx: PassContext) void) !*Pass {
        const pass = try allocator.create(Pass);
        pass.* = Pass{
            .name = try allocator.dupe(u8, name),
            .inputs = std.ArrayList(ResourceUsage).init(allocator),
            .outputs = std.ArrayList(ResourceUsage).init(allocator),
            .execute = execute,
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

pub const PassContext = struct { cmd: vk.CommandBuffer, frame: *frame.Frame, userData: ?*anyopaque, pass: *Pass };

pub const Graph = struct {
    allocator: std.mem.Allocator,
    passes: std.ArrayList(*Pass),
    resources: std.ArrayList(*Resource),
    userData: ?*anyopaque,

    pub fn init(allocator: std.mem.Allocator, userData: ?*anyopaque) !*Graph {
        const graph = try allocator.create(Graph);
        graph.* = Graph{
            .allocator = allocator,
            .passes = std.ArrayList(*Pass).init(allocator),
            .resources = std.ArrayList(*Resource).init(allocator),
            .userData = userData,
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
    pub fn execute(self: *Graph, cmd: vk.CommandBuffer, activeFrame: *frame.Frame) !void {
        const executionOrder = try self.buildExecutionOrder();
        defer self.allocator.free(executionOrder);

        for (executionOrder) |pass| {
            try self.insertBarriers(cmd, self.passes.items[pass]);
            const activePass = self.passes.items[pass];
            const activeExecute = activePass.execute;

            activeExecute(.{
                .cmd = cmd,
                .userData = self.userData,
                .pass = activePass,
                .frame = activeFrame
            });
            for (activePass.outputs) |output| {
                output.resource.currentState = output.requiredState;
            }
            for (activePass.inputs) |input| {
                input.resource.currentState = input.requiredState;
            }
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
        // Collect all necessary transitions for this pass
        var imageBarriers = std.ArrayList(vk.ImageMemoryBarrier2KHR).init(self.allocator);
        defer imageBarriers.deinit();

        var bufferBarriers = std.ArrayList(vk.BufferMemoryBarrier2KHR).init(self.allocator);
        defer bufferBarriers.deinit();

        // Process inputs
        for (pass.inputs.items) |input| {
            try Graph.addBarrierIfNeeded(&imageBarriers, &bufferBarriers, input);
        }

        // Process outputs
        for (pass.outputs.items) |output| {
            try Graph.addBarrierIfNeeded(&imageBarriers, &bufferBarriers, output);
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
        }
    }
    fn addBarrierIfNeeded(imageBarriers: *std.ArrayList(vk.ImageMemoryBarrier2KHR), bufferBarriers: *std.ArrayList(vk.BufferMemoryBarrier2KHR), usage: ResourceUsage) !void {
        const resource = usage.resource;
        const current = resource.currentState;
        const required = usage.requiredState;

        // Check if barrier is needed at all
        const needsBarrier = (current.accessMask != required.accessMask) or
            (current.stageMask != required.stageMask) or
            (resource.ty == .Image and current.layout != required.layout) or
            (current.queueFamilyIndex != required.queueFamilyIndex);

        if (!needsBarrier) return;

        switch (resource.ty) {
            .Image => {
                // Create image memory barrier
                const imageBarrier = vk.ImageMemoryBarrier2KHR{
                    .sType = vk.sTy(vk.StructureType.ImageMemoryBarrier2KHR),
                    .srcStageMask = current.stageMask,
                    .srcAccessMask = current.accessMask,
                    .dstStageMask = required.stageMask,
                    .dstAccessMask = required.accessMask,
                    .oldLayout = current.layout,
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
            },
            .Buffer => {
                // Create buffer memory barrier
                const bufferBarrier = vk.BufferMemoryBarrier2KHR{
                    .sType = vk.sTy(vk.StructureType.BufferMemoryBarrier2KHR),
                    .srcStageMask = current.stageMask,
                    .srcAccessMask = current.accessMask,
                    .dstStageMask = required.stageMask,
                    .dstAccessMask = required.accessMask,
                    .srcQueueFamilyIndex = current.queueFamilyIndex,
                    .dstQueueFamilyIndex = required.queueFamilyIndex,
                    .buffer = resource.handle.?.buffer,
                    .offset = 0,
                    .size = vk.WHOLE_SIZE,
                };

                try bufferBarriers.append(bufferBarrier);
            },
        }
    }
};
