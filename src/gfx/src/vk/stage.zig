const std = @import("std");
const heap = @import("heap.zig");
const vk = @import("vk.zig");

pub const StageError = error{
    AllocationFailed,
    OutOfMemory,
    MappingFailed,
    InvalidOffset,
    NotEnoughSpace,
    CopyFailed,
};

/// Represents a single upload operation to be performed
pub const Upload = struct {
    offset: usize,
    size: usize,
    data: []const u8,
};

// Target union type used throughout the module
pub const TargetUnion = union(enum) {
    buffer: struct {
        handle: vk.Buffer,
        offset: u64 = 0,
    },
    image: struct {
        handle: vk.Image,
        layout: vk.ImageLayout,
        aspect_mask: vk.ImageAspectFlags = vk.IMAGE_ASPECT_COLOR_BIT,
    },
};

/// A Stage is a staging buffer with ring buffer functionality
pub const Stage = struct {
    device: vk.Device,
    physical_device: vk.PhysicalDevice,
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
    queue_family_index: u32,
    size: usize,
    uploads: std.ArrayList(Upload),
    allocator: std.mem.Allocator,
    mapped_ptr: ?[*]u8,

    // Ring buffer tracking
    current_offset: usize = 0,
    last_fence: ?vk.Fence = null,
    aligned_offset: usize = 16, // Default alignment for most GPUs

    // Target resource this stage uploads to
    target: TargetUnion,

    // Task system integration
    staging_resource: ?*@import("task.zig").Resource = null,

    /// Create a new staging buffer with the specified size and buffer target
    pub fn createWithBufferTarget(
        device: vk.Device,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
        size: usize,
        target_buffer: vk.Buffer,
        target_offset: u64,
        allocator: std.mem.Allocator,
    ) !*Stage {
        // Create a properly tagged union for the target parameter
        const target_union = TargetUnion{
            .buffer = .{
                .handle = target_buffer,
                .offset = target_offset,
            },
        };
        return createStage(device, physical_device, queue_family_index, size, target_union, allocator);
    }

    /// Create a new staging buffer with the specified size and image target
    pub fn createWithImageTarget(
        device: vk.Device,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
        size: usize,
        target_image: vk.Image,
        target_layout: vk.ImageLayout,
        aspect_mask: vk.ImageAspectFlags,
        allocator: std.mem.Allocator,
    ) !*Stage {
        // Create a properly tagged union for the target parameter
        const target_union = TargetUnion{
            .image = .{
                .handle = target_image,
                .layout = target_layout,
                .aspect_mask = aspect_mask,
            },
        };
        return createStage(device, physical_device, queue_family_index, size, target_union, allocator);
    }

    /// Internal function to create a stage with any target type
    fn createStage(
        device: vk.Device,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
        size: usize,
        target_param: TargetUnion,
        allocator: std.mem.Allocator,
    ) !*Stage {
        const self = try allocator.create(Stage);
        errdefer allocator.destroy(self);

        // Create buffer for staging
        const buffer_create_info = vk.BufferCreateInfo{
            .sType = vk.sTy(.BufferCreateInfo),
            .pNext = null,
            .flags = 0,
            .size = size,
            .usage = vk.BUFFER_USAGE_TRANSFER_SRC_BIT,
            .sharingMode = vk.SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        var buffer: vk.Buffer = undefined;
        if (vk.createBuffer(device, &buffer_create_info, null, &buffer) != vk.SUCCESS) {
            return StageError.AllocationFailed;
        }
        errdefer vk.destroyBuffer(device, buffer, null);

        // Get memory requirements and allocate memory
        var mem_requirements: vk.MemoryRequirements = undefined;
        vk.getBufferMemoryRequirements(device, buffer, &mem_requirements);

        var memory_properties_info: vk.PhysicalDeviceMemoryProperties = undefined;
        vk.getPhysicalDeviceMemoryProperties(physical_device, &memory_properties_info);

        // Find suitable memory type for staging (host visible and coherent)
        const memory_type_index = try heap.findMemoryType(
            mem_requirements.memoryTypeBits,
            vk.MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.MEMORY_PROPERTY_HOST_COHERENT_BIT,
            memory_properties_info,
        );

        const alloc_info = vk.MemoryAllocateInfo{
            .sType = vk.sTy(.MemoryAllocateInfo),
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };

        var memory: vk.DeviceMemory = undefined;
        if (vk.allocateMemory(device, &alloc_info, null, &memory) != vk.SUCCESS) {
            return StageError.OutOfMemory;
        }
        errdefer vk.freeMemory(device, memory, null);

        // Bind the memory to the buffer
        if (vk.bindBufferMemory(device, buffer, memory, 0) != vk.SUCCESS) {
            return StageError.AllocationFailed;
        }

        self.* = .{
            .device = device,
            .physical_device = physical_device,
            .buffer = buffer,
            .memory = memory,
            .queue_family_index = queue_family_index,
            .size = size,
            .uploads = std.ArrayList(Upload).init(allocator),
            .allocator = allocator,
            .mapped_ptr = null,
            .current_offset = 0,
            .last_fence = null,
            .aligned_offset = 256, // Common alignment for most GPUs (adjust as needed)
            .target = target_param,  // Directly use the anonymous struct
            .staging_resource = null,
        };

        // Create task resources for staging buffer
        const task = @import("task.zig");
        self.staging_resource = try task.Resource.init(
            allocator,
            "StagingBuffer",
            task.ResourceType.Buffer,
            buffer
        );

        return self;
    }

    /// Map the staging buffer memory for CPU access
    pub fn mapMemory(self: *Stage) !void {
        if (self.mapped_ptr != null) return; // Already mapped

        var data: ?*anyopaque = null;
        if (vk.mapMemory(self.device, self.memory, 0, vk.WHOLE_SIZE, 0, &data) != vk.SUCCESS) {
            return StageError.MappingFailed;
        }

        self.mapped_ptr = @ptrCast(data);
    }

    /// Unmap the staging buffer memory
    pub fn unmapMemory(self: *Stage) void {
        if (self.mapped_ptr == null) return; // Not mapped

        vk.unmapMemory(self.device, self.memory);
        self.mapped_ptr = null;
    }

    /// Align an offset to the required alignment
    fn alignOffset(self: *Stage, offset: usize) usize {
        return (offset + self.aligned_offset - 1) & ~(self.aligned_offset - 1);
    }

    /// Reset the ring buffer offset when safe
    pub fn resetOffset(self: *Stage) void {
        // If we have a fence, we should wait for it first
        if (self.last_fence) |fence| {
            _ = vk.waitForFences(self.device, 1, &fence, vk.TRUE, std.time.ns_per_s * 5);
            self.last_fence = null;
        }

        // Reset the offset
        self.current_offset = 0;
    }

    /// Queue an upload operation to the staging buffer
    pub fn queueUpload(self: *Stage, data: []const u8) !usize {
        // Check if we need to reset or have enough space
        const aligned_size = self.alignOffset(data.len);
        const end_offset = self.current_offset + aligned_size;

        if (end_offset > self.size) {
            // Try to reset the buffer first
            self.resetOffset();

            // If we still don't have enough space, return an error
            if (aligned_size > self.size) {
                return StageError.NotEnoughSpace;
            }
        }

        // Reserve the current offset
        const upload_offset = self.current_offset;

        // Move the current offset forward
        self.current_offset += aligned_size;

        // Add the upload to the queue
        try self.uploads.append(.{
            .offset = upload_offset,
            .size = data.len,
            .data = data,
        });

        return upload_offset;
    }

    /// Perform all queued uploads to the staging buffer
    pub fn flushUploads(self: *Stage) !void {
        if (self.uploads.items.len == 0) return;

        // Map the memory if not already mapped
        try self.mapMemory();

        // Copy data for all uploads
        for (self.uploads.items) |upload| {
            // Direct copy to mapped memory
            @memcpy(self.mapped_ptr.?[upload.offset .. upload.offset + upload.data.len], upload.data);
        }

        // Staging memory is host coherent, so no need to flush memory ranges
    }

    /// Flush all pending operations and clean up
    pub fn flush(self: *Stage, fence: ?vk.Fence) !void {
        defer {
            // Clear uploads array
            self.uploads.clearRetainingCapacity();

            // Keep memory mapped for future uploads
        }

        // Make sure all data is uploaded to the staging buffer
        try self.flushUploads();

        // Store the fence for later synchronization
        if (fence != null) {
            self.last_fence = fence;
        }
    }

    /// Create a task pass for copying from staging buffer to the target heap buffer
    pub fn createBufferCopyPass(self: *Stage, name: []const u8, dst_resource: ?*@import("task.zig").Resource, offset: usize, size: usize) !*@import("task.zig").Pass {
        const task = @import("task.zig");

        // Create a pass for the buffer copy operation
        const CopyData = struct {
            offset: usize,
            size: usize,
        };

        const copy_data = try self.allocator.create(CopyData);
        copy_data.* = .{
            .offset = offset,
            .size = size,
        };

        const copy_buffer_fn = struct {
            fn execute(ctx: task.PassContext) void {
                const stage = @as(*Stage, @ptrCast(@alignCast(ctx.userData)));
                const dst_buf = ctx.pass.outputs.items[0].resource;
                const src_buf = ctx.pass.inputs.items[0].resource;

                // Both resources must have valid buffer handles
                if (dst_buf.handle == null or src_buf.handle == null) {
                    std.log.err("Invalid buffer handles in buffer copy pass", .{});
                    return;
                }

                // Get copy data from pass userData
                const data = @as(*CopyData, @ptrCast(@alignCast(ctx.userData)));

                // Get the staging buffer
                const stage_buffer = src_buf.handle.?.buffer;

                // Handle different target types
                switch (stage.target) {
                    .buffer => |buffer_target| {
                        // Create a buffer copy region
                        const region = vk.BufferCopy{
                            .srcOffset = data.offset,
                            .dstOffset = buffer_target.offset,
                            .size = data.size,
                        };

                        // Record buffer copy command
                        vk.CmdCopyBuffer(
                            ctx.cmd,
                            stage_buffer,
                            dst_buf.handle.?.buffer,
                            1,
                            &region
                        );
                    },
                    .image => |_| {
                        // This pass is for buffer targets only
                        // Use createImageCopyPass for image targets
                        std.log.err("Attempted to use buffer copy pass with image target", .{});
                    },
                }

                // Store the fence for synchronization if provided
                if (ctx.in_flight_fence != null) {
                    stage.last_fence = ctx.in_flight_fence;
                }
            }
        }.execute;

        const pass = try task.Pass.init(self.allocator, name, copy_buffer_fn);
        pass.userData = copy_data;

        // Add custom cleanup function
        pass.deinit_fn = struct {
            fn deinit(p: *task.Pass, alloc: *anyopaque) void {
                const data = @as(*CopyData, @ptrCast(@alignCast(p.userData)));
                const allocator = @as(*std.mem.Allocator, @ptrCast(@alignCast(alloc)));
                allocator.destroy(data);
                p.userData = null;

                // Call regular deinit
                task.Pass.deinit(p, allocator.*);
            }
        }.deinit;

        // Add the source (staging) buffer as input
        try pass.addInput(self.staging_resource.?, task.ResourceState{
            .accessMask = vk.ACCESS_TRANSFER_READ_BIT,
            .stageMask = vk.PIPELINE_STAGE_TRANSFER_BIT,
            .layout = undefined, // Not used for buffers
            .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        });

        // Add the destination buffer as output
        if (dst_resource) |resource| {
            try pass.addOutput(resource, task.ResourceState{
                .accessMask = vk.ACCESS_SHADER_READ_BIT,
                .stageMask = vk.PIPELINE_STAGE_VERTEX_SHADER_BIT | vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                .layout = undefined, // Not used for buffers
                .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            });
        } else {
            // If dst_resource is null, we need to create or get a resource for the target
            // Extract the buffer from the target union
            const buffer = switch (self.target) {
                .buffer => |b| b.handle,
                .image => {
                    std.log.err("Expected buffer target, got image target", .{});
                    return error.InvalidTargetType;
                },
            };

            const target_resource = try task.Resource.init(
                self.allocator,
                "TargetBuffer",
                task.ResourceType.Buffer,
                buffer
            );

            try pass.addOutput(target_resource, task.ResourceState{
                .accessMask = vk.ACCESS_SHADER_READ_BIT,
                .stageMask = vk.PIPELINE_STAGE_VERTEX_SHADER_BIT | vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                .layout = undefined, // Not used for buffers
                .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            });
        }

        return pass;
    }

    /// Create a task pass for copying from staging buffer to an image
    pub fn createImageCopyPass(self: *Stage, name: []const u8, dst_resource: *@import("task.zig").Resource, regions: []const vk.BufferImageCopy, dst_layout: vk.ImageLayout) !*@import("task.zig").Pass {
        const task = @import("task.zig");

        // Data to be stored with the pass
        const ImageCopyData = struct {
            regions: []const vk.BufferImageCopy,
            layout: vk.ImageLayout,
        };

        const copy_data = try self.allocator.create(ImageCopyData);
        copy_data.* = .{
            .regions = try self.allocator.dupe(vk.BufferImageCopy, regions),
            .layout = dst_layout,
        };

        const copy_image_fn = struct {
            fn execute(ctx: task.PassContext) void {
                _ = @as(*Stage, @ptrCast(@alignCast(ctx.userData)));
                const dst_image = ctx.pass.outputs.items[0].resource;
                const src_buf = ctx.pass.inputs.items[0].resource;

                // Both resources must have valid handles
                if (dst_image.handle == null or dst_image.ty != task.ResourceType.Image or
                    src_buf.handle == null or src_buf.ty != task.ResourceType.Buffer) {
                    std.log.err("Invalid resource handles in image copy pass", .{});
                    return;
                }

                // Get the copy data
                const data = @as(*ImageCopyData, @ptrCast(@alignCast(ctx.userData)));

                // Record buffer-to-image copy command
                vk.CmdCopyBufferToImage(
                    ctx.cmd,
                    src_buf.handle.?.buffer,
                    dst_image.handle.?.image,
                    data.layout,
                    @intCast(data.regions.len),
                    data.regions.ptr
                );
            }
        }.execute;

        var pass = try task.Pass.init(self.allocator, name, copy_image_fn);
        pass.userData = copy_data;

        // Add an proper cleanup function
        pass.deinit_fn = struct {
            fn deinit(p: *task.Pass, alloc: std.mem.Allocator) void {
                const data = @as(*ImageCopyData, @ptrCast(@alignCast(p.userData)));
                alloc.free(data.regions);
                alloc.destroy(data);
                p.userData = null;

                // Call regular deinit
                task.Pass.deinit(p, alloc);
            }
        }.deinit;

        // Add the source (staging) buffer as input
        try pass.addInput(self.staging_resource.?, task.ResourceState{
            .accessMask = vk.ACCESS_TRANSFER_READ_BIT,
            .stageMask = vk.PIPELINE_STAGE_TRANSFER_BIT,
            .layout = undefined, // Not used for buffers
            .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        });

        // Add the destination image as output
        try pass.addOutput(dst_resource, task.ResourceState{
            .accessMask = vk.ACCESS_SHADER_READ_BIT,
            .stageMask = vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            .layout = dst_layout,
            .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        });

        return pass;
    }

    /// Copy data from the staging buffer to the target (either buffer or image)
    pub fn copyToTarget(self: *Stage, cmd: vk.CommandBuffer, src_offset: u64, size: u64) !void {
        switch (self.target) {
            .buffer => |buffer_target| {
                const region = vk.BufferCopy{
                    .srcOffset = src_offset,
                    .dstOffset = buffer_target.offset,
                    .size = size,
                };

                vk.CmdCopyBuffer(cmd, self.buffer, buffer_target.handle, 1, &region);
            },
            .image => |image_target| {
                const region = vk.BufferImageCopy{
                    .bufferOffset = src_offset,
                    .bufferRowLength = 0,  // Tightly packed
                    .bufferImageHeight = 0, // Tightly packed
                    .imageSubresource = .{
                        .aspectMask = image_target.aspect_mask,
                        .mipLevel = 0,
                        .baseArrayLayer = 0,
                        .layerCount = 1,
                    },
                    .imageOffset = .{ .x = 0, .y = 0, .z = 0 },
                    .imageExtent = .{
                        .width = @intCast(size), // This is a simplification
                        .height = 1,
                        .depth = 1,
                    },
                };

                vk.CmdCopyBufferToImage(
                    cmd,
                    self.buffer,
                    image_target.handle,
                    image_target.layout,
                    1,
                    &region
                );
            },
        }
    }

    /// Destroy the stage and free its resources
    pub fn destroy(self: *Stage) void {
        // Make sure all operations are complete
        if (self.last_fence) |fence| {
            _ = vk.waitForFences(self.device, 1, &fence, vk.TRUE, std.time.ns_per_s * 5);
            // Note: We don't destroy the fence as it's owned by the task system
            self.last_fence = null;
        }

        // Unmap memory if mapped
        if (self.mapped_ptr != null) {
            self.unmapMemory();
        }

        // Clean up resources
        self.uploads.deinit();

        // Clean up task resources if we created them
        if (self.staging_resource != null) {
            self.staging_resource.?.deinit(&self.allocator);
            self.staging_resource = null;
        }

        // Free Vulkan resources
        vk.freeMemory(self.device, self.memory, null);
        vk.destroyBuffer(self.device, self.buffer, null);

        // Free our allocation
        self.allocator.destroy(self);
    }

};
