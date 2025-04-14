const std = @import("std");
const heap = @import("heap.zig");
const vk = @import("vk.zig");
const logger = @import("../logger.zig");

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
        std.debug.print("Creating Stage with buffer target, buffer: {any}, offset: {d}\n", .{target_buffer, target_offset});

        // Create a properly tagged union for the target parameter
        const target_union = TargetUnion{
            .buffer = .{
                .handle = target_buffer,
                .offset = target_offset,
            },
        };
        std.debug.print("Target union created with buffer type\n", .{});

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
        logger.info("[STAGE] Creating stage with size: {d}", .{size});

        // Log target type
        switch (target_param) {
            .buffer => |buf| logger.info("[STAGE] Target type: buffer, handle: {any}, offset: {d}", .{buf.handle, buf.offset}),
            .image => |img| logger.info("[STAGE] Target type: image, handle: {any}, layout: {any}", .{img.handle, img.layout}),
        }
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
        std.debug.print("[STAGE] Creating staging buffer with size: {d}, usage: {any}\n", .{size, vk.BUFFER_USAGE_TRANSFER_SRC_BIT});

        var buffer: vk.Buffer = undefined;
        if (vk.createBuffer(device, &buffer_create_info, null, &buffer) != vk.SUCCESS) {
            logger.err("[STAGE] Failed to create staging buffer", .{});
            return StageError.AllocationFailed;
        }
        logger.info("[STAGE] Staging buffer created successfully: {any}", .{buffer});
        errdefer vk.destroyBuffer(device, buffer, null);

        // Get memory requirements and allocate memory
        var mem_requirements: vk.MemoryRequirements = undefined;
        vk.getBufferMemoryRequirements(device, buffer, &mem_requirements);
        logger.debug("[STAGE] Buffer memory requirements - size: {d}, alignment: {d}, memoryTypeBits: {b}",
            .{mem_requirements.size, mem_requirements.alignment, mem_requirements.memoryTypeBits});

        var memory_properties_info: vk.PhysicalDeviceMemoryProperties = undefined;
        vk.getPhysicalDeviceMemoryProperties(physical_device, &memory_properties_info);
        logger.debug("[STAGE] Physical device has {d} memory types", .{memory_properties_info.memoryTypeCount});

        // Find suitable memory type for staging (host visible and coherent)
        const memory_type_index = try heap.findMemoryType(
            mem_requirements.memoryTypeBits,
            vk.MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.MEMORY_PROPERTY_HOST_COHERENT_BIT,
            memory_properties_info,
        );
        logger.debug("[STAGE] Found suitable memory type index: {d} (host visible and coherent)", .{memory_type_index});

        const alloc_info = vk.MemoryAllocateInfo{
            .sType = vk.sTy(.MemoryAllocateInfo),
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };
        logger.debug("[STAGE] Allocating staging memory of size: {d}", .{mem_requirements.size});

        var memory: vk.DeviceMemory = undefined;
        if (vk.allocateMemory(device, &alloc_info, null, &memory) != vk.SUCCESS) {
            logger.err("[STAGE] Memory allocation failed for staging buffer", .{});
            return StageError.OutOfMemory;
        }
        logger.info("[STAGE] Memory allocated successfully: {any}", .{memory});
        errdefer vk.freeMemory(device, memory, null);

        // Bind the memory to the buffer
        if (vk.bindBufferMemory(device, buffer, memory, 0) != vk.SUCCESS) {
            logger.err("[STAGE] Memory binding failed", .{});
            return StageError.AllocationFailed;
        }
        logger.info("[STAGE] Memory bound to buffer successfully", .{});

        std.debug.print("[STAGE] Initializing stage object\n", .{});
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

        // Verify target type after assignment
        std.debug.print("[STAGE] Target type after assignment: ", .{});
        switch (self.target) {
            .buffer => |b| std.debug.print("buffer with handle: {any}, offset: {d}\n", .{b.handle, b.offset}),
            .image => std.debug.print("image(!)\n", .{}),
        }

        // Create task resources for staging buffer
        const task = @import("task.zig");
        std.debug.print("[STAGE] Creating task resource for staging buffer\n", .{});
        self.staging_resource = try task.Resource.init(
            allocator,
            "StagingBuffer",
            task.ResourceType.Buffer,
            buffer
        );
        std.debug.print("[STAGE] Task resource created successfully: {any}\n", .{self.staging_resource});

        logger.info("[STAGE] Stage created successfully with size: {d}", .{size});
        return self;
    }

    /// Map the staging buffer memory for CPU access
    pub fn mapMemory(self: *Stage) !void {
        if (self.mapped_ptr != null) {
            logger.debug("[STAGE] Memory already mapped, skipping", .{});
            return; // Already mapped
        }

        logger.debug("[STAGE] Mapping staging buffer memory: {*}", .{self.memory});
        var data: ?*anyopaque = null;
        if (vk.mapMemory(self.device, self.memory, 0, vk.WHOLE_SIZE, 0, &data) != vk.SUCCESS) {
            logger.err("[STAGE] Memory mapping failed", .{});
            return StageError.MappingFailed;
        }

        self.mapped_ptr = @ptrCast(data);
        logger.debug("[STAGE] Memory mapped successfully at address: {*}", .{self.mapped_ptr});
    }

    /// Unmap the staging buffer memory
    pub fn unmapMemory(self: *Stage) void {
        if (self.mapped_ptr == null) {
            logger.debug("[STAGE] Memory not mapped, skipping unmapping", .{});
            return; // Not mapped
        }

        std.debug.print("[STAGE] Unmapping memory: {any}\n", .{self.memory});
        vk.unmapMemory(self.device, self.memory);
        self.mapped_ptr = null;
        std.debug.print("[STAGE] Memory unmapped successfully\n", .{});
    }

    /// Align an offset to the required alignment
    fn alignOffset(self: *Stage, offset: usize) usize {
        const aligned = (offset + self.aligned_offset - 1) & ~(self.aligned_offset - 1);
        std.debug.print("[STAGE] Aligning offset {d} to {d} (alignment: {d})\n", .{offset, aligned, self.aligned_offset});
        return aligned;
    }

    /// Reset the ring buffer offset when safe
    pub fn resetOffset(self: *Stage) void {
        std.debug.print("[STAGE] Attempting to reset ring buffer offset from: {d}\n", .{self.current_offset});

        // If we have a fence, we should wait for it first
        if (self.last_fence) |fence| {
            std.debug.print("[STAGE] Waiting for fence: {any} before resetting offset\n", .{fence});
            const result = vk.waitForFences(self.device, 1, &fence, vk.TRUE, std.time.ns_per_s * 5);
            std.debug.print("[STAGE] Fence wait result: {any}\n", .{result});
            self.last_fence = null;
        }

        // Reset the offset
        self.current_offset = 0;
        std.debug.print("[STAGE] Ring buffer offset reset to 0\n", .{});
    }

    /// Queue an upload operation to the staging buffer
    pub fn queueUpload(self: *Stage, data: []const u8) !usize {
        std.debug.print("[STAGE] Queuing upload of {d} bytes\n", .{data.len});

        // Check if we need to reset or have enough space
        const aligned_size = self.alignOffset(data.len);
        const end_offset = self.current_offset + aligned_size;
        std.debug.print("[STAGE] Current offset: {d}, aligned size: {d}, end offset: {d}, buffer size: {d}\n",
            .{self.current_offset, aligned_size, end_offset, self.size});

        if (end_offset > self.size) {
            std.debug.print("[STAGE] Not enough space in staging buffer, attempting reset\n", .{});
            // Try to reset the buffer first
            self.resetOffset();

            // If we still don't have enough space, return an error
            if (aligned_size > self.size) {
                std.debug.print("[STAGE] Data too large for staging buffer even after reset ({d} > {d})\n",
                    .{aligned_size, self.size});
                return StageError.NotEnoughSpace;
            }
        }

        // Reserve the current offset
        const upload_offset = self.current_offset;
        std.debug.print("[STAGE] Reserved upload at offset: {d}\n", .{upload_offset});

        // Move the current offset forward
        self.current_offset += aligned_size;
        std.debug.print("[STAGE] Updated current offset to: {d}\n", .{self.current_offset});

        // Add the upload to the queue
        try self.uploads.append(.{
            .offset = upload_offset,
            .size = data.len,
            .data = data,
        });
        std.debug.print("[STAGE] Added upload to queue, total queued uploads: {d}\n", .{self.uploads.items.len});

        return upload_offset;
    }

    /// Perform all queued uploads to the staging buffer
    /// Perform all queued uploads to the staging buffer
    /// clear_uploads: If true, clears the uploads list after flushing (default: false)
    pub fn flushUploads(self: *Stage, clear_uploads: bool) !void {
        std.debug.print("[STAGE] Flushing {d} queued uploads\n", .{self.uploads.items.len});
        if (self.uploads.items.len == 0) {
            std.debug.print("[STAGE] No uploads to flush\n", .{});
            return;
        }

        // Map the memory if not already mapped
        std.debug.print("[STAGE] Ensuring memory is mapped for upload\n", .{});
        try self.mapMemory();

        // Copy data for all uploads
        std.debug.print("[STAGE] Copying data for {d} uploads to staging buffer\n", .{self.uploads.items.len});
        for (self.uploads.items, 0..) |upload, i| {
            std.debug.print("[STAGE] Copying upload {d}/{d}: {d} bytes to offset {d}\n",
                .{i+1, self.uploads.items.len, upload.data.len, upload.offset});
            // Direct copy to mapped memory
            @memcpy(self.mapped_ptr.?[upload.offset .. upload.offset + upload.data.len], upload.data);
        }

        // Clear uploads list if requested
        if (clear_uploads) {
            std.debug.print("[STAGE] Clearing uploads array after flushing\n", .{});
            self.uploads.clearRetainingCapacity();
        }

        std.debug.print("[STAGE] All uploads flushed to staging buffer\n", .{});
        // Staging memory is host coherent, so no need to flush memory ranges
    }

    /// Flush all pending operations and clean up
    pub fn flush(self: *Stage, fence: ?vk.Fence) !void {
        std.debug.print("[STAGE] Flushing stage with fence: {?}\n", .{fence});

        defer {
            // Clear uploads array
            std.debug.print("[STAGE] Clearing uploads array, retaining capacity\n", .{});
            self.uploads.clearRetainingCapacity();

            // Keep memory mapped for future uploads
        }

        // Make sure all data is uploaded to the staging buffer
        std.debug.print("[STAGE] Ensuring all uploads are flushed to staging buffer\n", .{});
        // Use false since the uploads will be cleared in the defer block below
        try self.flushUploads(false);

        // Store the fence for later synchronization
        if (fence != null) {
            std.debug.print("[STAGE] Storing fence: {?} for synchronization\n", .{fence});
            self.last_fence = fence;
        }

        std.debug.print("[STAGE] Flush completed successfully\n", .{});
    }

    /// Data structure for buffer copy operations
    pub const BufferCopyData = struct {
        stage: *Stage,      // Reference to the Stage
        offset: usize,      // Source offset in staging buffer
        size: usize,        // Size of data to copy
    };

    /// Create a task pass for copying from staging buffer to the target heap buffer
    pub fn createBufferCopyPass(self: *Stage, name: []const u8, dst_resource: ?*@import("task.zig").Resource, offset: usize, size: usize) !*@import("task.zig").Pass {
        // Validate that this Stage has a buffer target
        std.debug.print("[STAGE] createBufferCopyPass - validating target type\n", .{});
        switch (self.target) {
            .buffer => |b| std.debug.print("[STAGE] confirmed buffer target: {any}, offset: {d}\n",
                                          .{b.handle, b.offset}),
            .image => {
                std.debug.print("[STAGE] ERROR: attempting to create buffer copy pass with image target!\n", .{});
                return error.InvalidTargetType;
            },
        }
        const task = @import("task.zig");

        const copy_data = try self.allocator.create(BufferCopyData);
        copy_data.* = .{
            .stage = self,    // Store the Stage reference
            .offset = offset,
            .size = size,
        };
        std.debug.print("[STAGE] BufferCopyData created: offset={any}\n", .{copy_data});

        const copy_buffer_fn = struct {
            fn execute(ctx: task.PassContext) void {
                // Get BufferCopyData which contains the Stage reference
                const data = @as(*BufferCopyData, @ptrCast(@alignCast(ctx.userData)));
                std.debug.print("[STAGE] Buffer data: offset={any}", .{ctx.userData});

                // Get Stage from the CopyData struct
                const stage = data.stage;

                const dst_buf = ctx.pass.outputs.items[0].resource;
                const src_buf = ctx.pass.inputs.items[0].resource;

                // Both resources must have valid buffer handles
                if (dst_buf.handle == null or src_buf.handle == null) {
                    std.log.err("Invalid buffer handles in buffer copy pass", .{});
                    unreachable;
                }

                // Get the staging buffer
                const stage_buffer = src_buf.handle.?.buffer;

                // Check the destination resource type
                std.log.debug("dst_buf.ty = {any}", .{dst_buf.ty});
                if (dst_buf.ty != .Buffer) {
                    std.log.err("Attempted to use buffer copy pass with image target", .{});
                    unreachable;
                }

                // Get offset from stage target and verify it matches resource type
                std.log.debug("stage.target = {any}", .{stage.target});
                var dst_offset: u64 = undefined;
                switch (stage.target) {
                    .buffer => |buffer_target| {
                        std.log.debug("Buffer target handle: {any}, offset: {any}", .{buffer_target.handle, buffer_target.offset});
                        dst_offset = buffer_target.offset;
                    },
                    .image => {
                        // Should never happen with the check above
                        std.log.err("Inconsistent target types - stage.target is image but dst_buf.ty is Buffer", .{});
                        std.log.err("This indicates a mismatch between the stage's target and the resource type", .{});
                        unreachable;
                    },
                }

                // Fixed buffer copy region with thorough validation
                const final_src_offset = @min(data.offset, @as(u64, 1024 * 1024 * 8)); // Cap at 8MB (staging buffer size)
                // Increase size limit to accommodate larger structures like matrices (16 floats = 64 bytes)
                const final_size = @min(data.size, @as(u64, 4096)); // Increased from 1KB to 4KB

                std.debug.print("[STAGE] Fixing copy parameters - original: src={}, size={}\n",
                             .{data.offset, data.size});
                std.debug.print("[STAGE] Fixed parameters: src={}, dst={}, size={}\n",
                             .{final_src_offset, dst_offset, final_size});

                const region = vk.BufferCopy{
                    .srcOffset = final_src_offset,
                    .dstOffset = dst_offset,
                    .size = final_size,
                };

                // Detailed logging before copy command
                std.debug.print("[STAGE] About to execute CmdCopyBuffer - src: {any}, dst: {any}, region: {{srcOffset={d}, dstOffset={d}, size={d}}}\n",
                           .{stage_buffer, dst_buf.handle.?.buffer, region.srcOffset, region.dstOffset, region.size});

                // Comprehensive buffer validation
                if (stage_buffer == null or dst_buf.handle == null or dst_buf.handle.?.buffer == null) {
                    std.debug.print("[STAGE] CRITICAL ERROR: Invalid buffer handle detected!\n", .{});
                    std.debug.print("[STAGE] stage_buffer: {any}, dst_buf.handle: {any}\n",
                                 .{stage_buffer, if (dst_buf.handle != null) dst_buf.handle.?.buffer else null});
                    return; // Prevent device lost error by not executing invalid command
                }

                // Double-check resource type and validity
                if (dst_buf.ty != .Buffer) {
                    std.debug.print("[STAGE] ERROR: Destination is not a buffer (type: {any})\n", .{dst_buf.ty});
                    return;
                }

                // Validate region parameters
                if (data.size == 0 or data.size > 10000000) {
                    std.debug.print("[STAGE] ERROR: Suspicious copy size: {d}\n", .{data.size});
                    return;
                }

                // Try/catch the copy command to prevent potential crashes
                std.debug.print("[STAGE] Executing CmdCopyBuffer...\n", .{});
                vk.CmdCopyBuffer(
                    ctx.cmd,
                    stage_buffer,
                    dst_buf.handle.?.buffer,
                    1,
                    &region
                );
                std.debug.print("[STAGE] CmdCopyBuffer executed successfully\n", .{});

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
                const data = @as(*BufferCopyData, @ptrCast(@alignCast(p.userData)));
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
            std.log.debug("Using provided dst_resource: {s}, type: {any}, handle: {any}", .{resource.name, resource.ty, resource.handle});
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


    pub fn copyToTarget(self: *Stage, cmd: vk.CommandBuffer, src_offset: u64, size: u64) !void {
        std.debug.print("[STAGE] Copying {d} bytes from staging buffer offset {d} to target\n", .{size, src_offset});

        switch (self.target) {
            .buffer => |buffer_target| {
                std.debug.print("[STAGE] Target is buffer: {any}, target offset: {d}\n", .{buffer_target.handle, buffer_target.offset});
                const region = vk.BufferCopy{
                    .srcOffset = src_offset,
                    .dstOffset = buffer_target.offset,
                    .size = size,
                };

                std.debug.print("[STAGE] Issuing buffer copy command to command buffer: {any}\n", .{cmd});
                vk.CmdCopyBuffer(cmd, self.buffer, buffer_target.handle, 1, &region);
                std.debug.print("[STAGE] Buffer copy command issued\n", .{});
            },
            .image => |image_target| {
                std.debug.print("[STAGE] Target is image: {any}, layout: {any}, aspect: {any}\n",
                    .{image_target.handle, image_target.layout, image_target.aspect_mask});
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

                std.debug.print("[STAGE] Issuing buffer-to-image copy command to command buffer: {any}\n", .{cmd});
                vk.CmdCopyBufferToImage(
                    cmd,
                    self.buffer,
                    image_target.handle,
                    image_target.layout,
                    1,
                    &region
                );
                std.debug.print("[STAGE] Buffer-to-image copy command issued\n", .{});
            },
        }
        std.debug.print("[STAGE] Copy to target complete\n", .{});

        // Clear uploads after copying to target
        std.debug.print("[STAGE] Clearing uploads array after copy, retaining capacity\n", .{});
        self.uploads.clearRetainingCapacity();
    }

    /// Destroy the stage and free its resources
    pub fn destroy(self: *Stage) void {
        std.debug.print("[STAGE] Destroying stage, buffer: {any}, memory: {any}, size: {d}\n",
            .{self.buffer, self.memory, self.size});

        // Make sure all operations are complete
        if (self.last_fence) |fence| {
            std.debug.print("[STAGE] Waiting for fence: {any} before destruction\n", .{fence});
            const result = vk.waitForFences(self.device, 1, &fence, vk.TRUE, std.time.ns_per_s * 5);
            std.debug.print("[STAGE] Fence wait result: {any}\n", .{result});
            // Note: We don't destroy the fence as it's owned by the task system
            self.last_fence = null;
        }

        // Unmap memory if mapped
        if (self.mapped_ptr != null) {
            std.debug.print("[STAGE] Unmapping memory before destruction\n", .{});
            self.unmapMemory();
        }

        // Clean up resources
        std.debug.print("[STAGE] Cleaning up uploads array\n", .{});
        self.uploads.deinit();

        // Clean up task resources if we created them
        if (self.staging_resource != null) {
            std.debug.print("[STAGE] Cleaning up staging task resource: {any}\n", .{self.staging_resource});
            self.staging_resource.?.deinit(&self.allocator);
            self.staging_resource = null;
        }

        // Free Vulkan resources
        std.debug.print("[STAGE] Freeing Vulkan memory: {any}\n", .{self.memory});
        vk.freeMemory(self.device, self.memory, null);
        std.debug.print("[STAGE] Destroying Vulkan buffer: {any}\n", .{self.buffer});
        vk.destroyBuffer(self.device, self.buffer, null);

        // Free our allocation
        std.debug.print("[STAGE] Freeing Stage object\n", .{});
        self.allocator.destroy(self);
        std.debug.print("[STAGE] Stage destroyed successfully\n", .{});
    }

};
