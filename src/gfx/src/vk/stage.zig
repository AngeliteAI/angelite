const std = @import("std");
const heap = @import("heap.zig");
const vk = @import("vk.zig");
const logger = @import("../logger.zig");
const task = @import("task.zig");

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
    heap_offset: usize,
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
    allocator: *std.mem.Allocator,
    mapped_ptr: ?[*]u8,

    // Ring buffer tracking
    current_offset: usize = 0,
    last_fence: ?vk.Fence = null,
    aligned_offset: usize = 16, // Changed from 1 to 16 for PhysicalStorageBuffer64 alignment

    // Target resource this stage uploads to
    target: TargetUnion,

    // Task system integration
    staging_resource: ?*task.Resource = null,
    // Store the staging pass to avoid creating multiple passes
    staging_pass: ?*task.Pass = null,

    ref_count: u32,
    destroyed: bool,
    mutex: std.Thread.Mutex,

    /// Create a new staging buffer with the specified size and buffer target
    pub fn createWithBufferTarget(
        device: vk.Device,
        physical_device: vk.PhysicalDevice,
        queue_family_index: u32,
        size: usize,
        target_buffer: vk.Buffer,
        target_offset: u64,
        allocator: *std.mem.Allocator,
    ) !*Stage {
        logger.info("Creating Stage with buffer target, buffer: {any}, offset: {d}", .{ target_buffer, target_offset });

        // Create a properly tagged union for the target parameter
        const target_union = TargetUnion{
            .buffer = .{
                .handle = target_buffer,
                .offset = target_offset,
            },
        };
        logger.debug("Target union created with buffer type", .{});

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
        allocator: *std.mem.Allocator,
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
        allocator: *std.mem.Allocator,
    ) !*Stage {
        logger.info("[STAGE] Creating stage with size: {d}", .{size});

        // Log target type
        switch (target_param) {
            .buffer => |buf| logger.info("[STAGE] Target type: buffer, handle: {any}, offset: {d}", .{ buf.handle, buf.offset }),
            .image => |img| logger.info("[STAGE] Target type: image, handle: {any}, layout: {any}", .{ img.handle, img.layout }),
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
        logger.info("[STAGE] Creating staging buffer with size: {d}, usage: {any}", .{ size, vk.BUFFER_USAGE_TRANSFER_SRC_BIT });

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
        logger.debug("[STAGE] Buffer memory requirements - size: {d}, alignment: {d}, memoryTypeBits: {b}", .{ mem_requirements.size, mem_requirements.alignment, mem_requirements.memoryTypeBits });

        var memory_properties_info: vk.PhysicalDeviceMemoryProperties = undefined;
        vk.getPhysicalDeviceMemoryProperties(physical_device, &memory_properties_info);
        logger.debug("[STAGE] Physical device has {d} memory types", .{memory_properties_info.memoryTypeCount});

        // Find suitable memory type for staging (host visible and coherent)
        const memory_type_index = try heap.findMemoryType(
            physical_device,
            mem_requirements.memoryTypeBits,
            vk.MEMORY_PROPERTY_HOST_VISIBLE_BIT | vk.MEMORY_PROPERTY_HOST_COHERENT_BIT,
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

        logger.info("[STAGE] Initializing stage object", .{});
        self.* = .{
            .device = device,
            .physical_device = physical_device,
            .buffer = buffer,
            .memory = memory,
            .queue_family_index = queue_family_index,
            .size = size,
            .uploads = std.ArrayList(Upload).init(allocator.*),
            .allocator = allocator,
            .mapped_ptr = null,
            .current_offset = 0,
            .last_fence = null,
            .aligned_offset = 16, // Changed from 1 to 16 for PhysicalStorageBuffer64 alignment
            .target = target_param, // Directly use the anonymous struct
            .staging_resource = null,
            .staging_pass = null,
            .ref_count = 0,
            .destroyed = false,
            .mutex = std.Thread.Mutex{},
        };

        // Verify target type after assignment
        logger.debug("[STAGE] Target type after assignment: ", .{});
        switch (self.target) {
            .buffer => |b| logger.debug("[STAGE] buffer with handle: {any}, offset: {d}", .{ b.handle, b.offset }),
            .image => logger.debug("[STAGE] image(!)", .{}),
        }

        // Create task resources for staging buffer
        logger.debug("[STAGE] Creating task resource for staging buffer", .{});
        self.staging_resource = try task.Resource.init(allocator, "StagingBuffer", task.ResourceType.Buffer, buffer);
        logger.debug("[STAGE] Task resource created successfully: {any}", .{self.staging_resource});

        logger.info("[STAGE] Stage created successfully with size: {d}", .{size});
        return self;
    }

    /// Map the staging buffer memory for CPU access
    pub fn mapMemory(self: *Stage) !void {
        if (self.mapped_ptr != null) return;

        // Add mutex lock for thread safety
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.destroyed) {
            return error.StageDestroyed;
        }

        var mapped_ptr: ?*anyopaque = null;
        const result = vk.mapMemory(
            self.device,
            self.memory,
            0,
            self.size,
            0,
            @ptrCast(&mapped_ptr),
        );

        if (result != vk.SUCCESS) {
            return error.VulkanError;
        }

        self.mapped_ptr = @ptrCast(mapped_ptr);
        logger.info("Memory mapped successfully at address: {*}", .{mapped_ptr});
    }

    /// Unmap the staging buffer memory
    pub fn unmapMemory(self: *Stage) void {
        // Add mutex lock for thread safety
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.mapped_ptr == null) return;

        vk.unmapMemory(self.device, self.memory);
        self.mapped_ptr = null;
        logger.info("Memory unmapped successfully", .{});
    }

    /// Align an offset to the required alignment
    fn alignOffset(self: *Stage, offset: usize) usize {
        const aligned = (offset + self.aligned_offset - 1) & ~(self.aligned_offset - 1);
        logger.debug("[STAGE] Aligning offset {d} to {d} (alignment: {d})", .{ offset, aligned, self.aligned_offset });
        return aligned;
    }

    /// Reset the ring buffer offset when safe
    pub fn resetOffset(self: *Stage) void {
        logger.debug("[STAGE] Attempting to reset ring buffer offset from: {d}", .{self.current_offset});

        // If we have a fence, we should wait for it first
        if (self.last_fence) |fence| {
            logger.debug("[STAGE] Waiting for fence: {any} before resetting offset", .{fence});
            const result = vk.waitForFences(self.device, 1, &fence, vk.TRUE, std.time.ns_per_s * 5);
            logger.debug("[STAGE] Fence wait result: {any}", .{result});
            self.last_fence = null;
        }

        // Reset the offset
        self.current_offset = 0;
        logger.debug("[STAGE] Ring buffer offset reset to 0", .{});
    }

    /// Queue an upload operation to the staging buffer
    pub fn queueUpload(self: *Stage, data: []const u8, heap_offset: usize) !usize {
        logger.debug("[STAGE] Queueing upload: size={d}, heap_offset={d}", .{ data.len, heap_offset });

        // Check if we have enough space in the staging buffer
        if (data.len > self.size) {
            logger.debug("[STAGE] Data size {d} exceeds staging buffer size {d}", .{ data.len, self.size });
            return error.StagingBufferFull;
        }

        // Calculate the offset, handling ring buffer wrapping
        var offset = self.current_offset;
        if (offset + data.len > self.size) {
            // We need to wrap around to the beginning
            logger.debug("[STAGE] Wrapping around ring buffer: current={d}, size={d}", .{ offset, self.size });
            offset = 0;
            self.current_offset = data.len;
        } else {
            self.current_offset += data.len;
        }

        // Map the memory if not already mapped
        if (self.mapped_ptr == null) {
            try self.mapMemory();
        }

        // Copy the data to the staging buffer:w

        @memcpy(self.mapped_ptr.?[offset .. offset + data.len], data);

        // Add the upload to the queue
        try self.uploads.append(.{
            .offset = offset,
            .size = data.len,
            .data = data,
            .heap_offset = heap_offset,
        });

        logger.debug("[STAGE] Upload queued: offset={d}, size={d}, heap_offset={d}", .{ offset, data.len, heap_offset });
        return offset;
    }

    /// Perform all queued uploads to the staging buffer
    /// clear_uploads: If true, clears the uploads list after flushing (default: false)
    pub fn flushUploads(self: *Stage, clear_uploads: bool) !void {
        logger.debug("[STAGE] Flushing {d} queued uploads", .{self.uploads.items.len});
        if (self.uploads.items.len == 0) {
            logger.debug("[STAGE] No uploads to flush", .{});
            return;
        }

        // Map the memory if not already mapped
        logger.debug("[STAGE] Ensuring memory is mapped for upload", .{});
        try self.mapMemory();

        // Copy data for all uploads
        logger.debug("[STAGE] Copying data for {d} uploads to staging buffer", .{self.uploads.items.len});
        for (self.uploads.items, 0..) |upload, i| {
            logger.debug("[STAGE] Copying upload {d}/{d}: {d} bytes to offset {d}", .{ i + 1, self.uploads.items.len, upload.data.len, upload.offset });
            // Direct copy to mapped memory
            @memcpy(self.mapped_ptr.?[upload.offset .. upload.offset + upload.data.len], upload.data);
        }

        // Clear uploads list if requested
        if (clear_uploads) {
            logger.debug("[STAGE] Clearing uploads array after flushing", .{});
            self.uploads.clearRetainingCapacity();
        }

        logger.debug("[STAGE] All uploads flushed to staging buffer", .{});
        // Staging memory is host coherent, so no need to flush memory ranges
    }

    /// Flush all pending operations and clean up
    pub fn flush(self: *Stage, fence: ?vk.Fence) !void {
        logger.debug("[STAGE] Flushing stage with fence: {?}", .{fence});

        defer {
            // Clear uploads array
            logger.debug("[STAGE] Clearing uploads array, retaining capacity", .{});
            self.uploads.clearRetainingCapacity();

            // Keep memory mapped for future uploads
        }

        // Make sure all data is uploaded to the staging buffer
        logger.debug("[STAGE] Ensuring all uploads are flushed to staging buffer", .{});
        // Use false since the uploads will be cleared in the defer block below
        try self.flushUploads(false);

        // Store the fence for later synchronization
        if (fence != null) {
            logger.debug("[STAGE] Storing fence: {?} for synchronization", .{fence});
            self.last_fence = fence;
        }

        logger.debug("[STAGE] Flush completed successfully", .{});
    }

    /// Data structure for buffer copy operations
    pub const BufferCopyData = struct {
        stage: *Stage, // Reference to the Stage
        offset: usize, // Source offset in staging buffer
        size: usize, // Size of data to copy
    };

    /// Create a task pass for copying from staging buffer to the target heap buffer
    pub fn createBufferCopyPass(self: *Stage, name: []const u8, dst_resource: ?*task.Resource, offset: usize, size: usize) !*task.Pass {
        // Validate that this Stage has a buffer target
        logger.debug("[STAGE] createBufferCopyPass - validating target type", .{});

        switch (self.target) {
            .buffer => |b| logger.debug("[STAGE] confirmed buffer target: {any}, offset: {d}", .{ b.handle, b.offset }),
            .image => {
                logger.debug("[STAGE] ERROR: attempting to create buffer copy pass with image target!", .{});
                return error.InvalidTargetType;
            },
        }

        const copy_data = try self.allocator.create(BufferCopyData);
        copy_data.* = .{
            .stage = self, // Store the Stage reference
            .offset = offset,
            .size = size,
        };
        logger.debug("[STAGE] BufferCopyData created: offset={any}", .{copy_data});

        const copy_buffer_fn = struct {
            fn execute(ctx: task.PassContext) void {
                // Get BufferCopyData which contains the Stage reference
                const data = @as(*BufferCopyData, @ptrCast(@alignCast(ctx.userData)));
                logger.debug("[STAGE] Buffer data: offset={any}", .{ctx.userData});

                // Get Stage from the CopyData struct
                const stage = data.stage;

                // Get the destination buffer
                const dst_buf = ctx.pass.outputs.items[0].resource;

                // Get the destination buffer handle
                if (dst_buf.handle == null or dst_buf.ty != .Buffer) {
                    logger.err("Invalid destination buffer in buffer copy pass", .{});
                    return;
                }

                // Get the destination offset from the stage target
                const dst_offset = switch (stage.target) {
                    .buffer => |b| b.offset,
                    .image => 0, // Should never happen
                };

                // Create the copy region
                const region = vk.BufferCopy{
                    .srcOffset = data.offset,
                    .dstOffset = dst_offset,
                    .size = data.size,
                };

                // Execute the copy command
                logger.debug("[STAGE] Executing cmdCopyBuffer - src: {any}, dst: {any}, region: {{srcOffset={d}, dstOffset={d}, size={d}}}", .{ stage.buffer, dst_buf.handle.?.buffer, region.srcOffset, region.dstOffset, region.size });

                vk.cmdCopyBuffer(ctx.cmd, stage.buffer, dst_buf.handle.?.buffer, 1, &region);

                // Store the fence for synchronization if provided
                if (ctx.in_flight_fence != null) {
                    stage.last_fence = ctx.in_flight_fence;
                }
            }
        }.execute;

        const pass = try task.Pass.init(self.allocator.*, name, copy_buffer_fn);
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
        }, .{
            .offset = 0,
            .size = self.size,
        });

        // Add the destination buffer as output
        if (dst_resource) |resource| {
            logger.debug("Using provided dst_resource: {s}, type: {any}, handle: {any}", .{ resource.name, resource.ty, resource.handle });
            try pass.addOutput(resource, task.ResourceState{
                .accessMask = vk.ACCESS_SHADER_READ_BIT,
                .stageMask = vk.PIPELINE_STAGE_VERTEX_SHADER_BIT | vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                .layout = undefined, // Not used for buffers
                .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            }, .{
                .offset = 0,
                .size = self.size,
            });
        } else {
            // If dst_resource is null, we need to create or get a resource for the target
            // Extract the buffer from the target union
            const buffer = switch (self.target) {
                .buffer => |b| b.handle,
                .image => {
                    logger.err("Expected buffer target, got image target", .{});
                    return error.InvalidTargetType;
                },
            };

            const target_resource = try task.Resource.init(self.allocator.*, "TargetBuffer", task.ResourceType.Buffer, buffer);

            try pass.addOutput(target_resource, task.ResourceState{
                .accessMask = vk.ACCESS_SHADER_READ_BIT,
                .stageMask = vk.PIPELINE_STAGE_VERTEX_SHADER_BIT | vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
                .layout = undefined, // Not used for buffers
                .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
            }, .{
                .offset = 0,
                .size = self.size,
            });
        }

        return pass;
    }

    /// Create a task pass for copying from staging buffer to an image
    pub fn createImageCopyPass(self: *Stage, name: []const u8, dst_resource: *task.Resource, regions: []const vk.BufferImageCopy, dst_layout: vk.ImageLayout) !*task.Pass {
        const copy_data = try self.allocator.create(struct {
            regions: []const vk.BufferImageCopy,
            layout: vk.ImageLayout,
        });
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
                    src_buf.handle == null or src_buf.ty != task.ResourceType.Buffer)
                {
                    logger.err("Invalid resource handles in image copy pass", .{});
                    return;
                }

                // Get the copy data
                const data = @as(*struct {
                    regions: []const vk.BufferImageCopy,
                    layout: vk.ImageLayout,
                }, @ptrCast(@alignCast(ctx.userData)));

                // Record buffer-to-image copy command
                vk.cmdCopyBufferToImage(ctx.cmd, src_buf.handle.?.buffer, dst_image.handle.?.image, data.layout, @intCast(data.regions.len), data.regions.ptr);
            }
        }.execute;

        var pass = try task.Pass.init(self.allocator.*, name, copy_image_fn);
        pass.userData = copy_data;

        // Add an proper cleanup function
        pass.deinit_fn = struct {
            fn deinit(p: *task.Pass, alloc: std.mem.Allocator) void {
                const data = @as(*struct {
                    regions: []const vk.BufferImageCopy,
                    layout: vk.ImageLayout,
                }, @ptrCast(@alignCast(p.userData)));
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
        }, .{
            .offset = 0,
            .size = self.size,
        });

        // Add the destination image as output
        try pass.addOutput(dst_resource, task.ResourceState{
            .accessMask = vk.ACCESS_SHADER_READ_BIT,
            .stageMask = vk.PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            .layout = dst_layout,
            .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        }, null);

        return pass;
    }

    pub fn copyToTarget(self: *Stage, cmd: vk.CommandBuffer, src_offset: u64, size: u64) !void {
        logger.debug("[STAGE] Copying {d} bytes from staging buffer offset {d} to target", .{ size, src_offset });

        switch (self.target) {
            .buffer => |buffer_target| {
                logger.debug("[STAGE] Target is buffer: {any}, target offset: {d}", .{ buffer_target.handle, buffer_target.offset });
                const region = vk.BufferCopy{
                    .srcOffset = src_offset,
                    .dstOffset = buffer_target.offset,
                    .size = size,
                };

                logger.debug("[STAGE] Issuing buffer copy command to command buffer: {any}", .{cmd});
                vk.cmdCopyBuffer(cmd, self.buffer, buffer_target.handle, 1, &region);
                logger.debug("[STAGE] Buffer copy command issued", .{});
            },
            .image => |image_target| {
                logger.debug("[STAGE] Target is image: {any}, layout: {any}, aspect: {any}", .{ image_target.handle, image_target.layout, image_target.aspect_mask });
                const region = vk.BufferImageCopy{
                    .bufferOffset = src_offset,
                    .bufferRowLength = 0, // Tightly packed
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

                logger.debug("[STAGE] Issuing buffer-to-image copy command to command buffer: {any}", .{cmd});
                vk.cmdCopyBufferToImage(cmd, self.buffer, image_target.handle, image_target.layout, 1, &region);
                logger.debug("[STAGE] Buffer-to-image copy command issued", .{});
            },
        }
        logger.debug("[STAGE] Copy to target complete", .{});

        // Clear uploads after copying to target
        logger.debug("[STAGE] Clearing uploads array after copy, retaining capacity", .{});
        self.uploads.clearRetainingCapacity();
    }

    /// Creates a staging pass for queued uploads
    pub fn createStagingPass(self: *Stage, name: []const u8) !*task.Pass {
        logger.debug("[STAGE] Creating staging pass '{s}' with {d} uploads", .{ name, self.uploads.items.len });

        // Define the execution function for the pass
        const execute_fn = struct {
            fn execute(ctx: task.PassContext) void {
                const stage = @as(*Stage, @ptrCast(@alignCast(ctx.userData)));

                // Get the staging buffer and target buffer
                const staging_buf = ctx.pass.inputs.items[0].resource;
                const target_buf = ctx.pass.outputs.items[0].resource;
                logger.debug("[STAGE] Staging buffer: {any}, target buffer: {any}", .{ staging_buf.handle, target_buf.handle });

                // Execute copy commands for each upload
                for (stage.uploads.items) |upload| {
                    logger.debug("[STAGE] Executing copy command: src_offset={d}, dst_offset={d}, size={d}", .{
                        upload.offset,
                        upload.heap_offset,
                        upload.size,
                    });

                    const region = vk.BufferCopy{
                        .srcOffset = upload.offset,
                        .dstOffset = upload.heap_offset,
                        .size = upload.size,
                    };

                    vk.cmdCopyBuffer(ctx.cmd, staging_buf.handle.?.buffer, target_buf.handle.?.buffer, 1, &region);
                }
                logger.debug("[STAGE] All copy commands executed", .{});

                // Store the fence for synchronization if provided
                if (ctx.in_flight_fence != null) {
                    stage.last_fence = ctx.in_flight_fence;
                }

                // Clear uploads after the pass is executed
                stage.uploads.clearRetainingCapacity();
                stage.current_offset = 0;
            }
        }.execute;

        // Create a new pass with the allocator, name, and execution function
        const pass = try task.Pass.init(self.allocator, name, execute_fn);
        pass.userData = self;

        // Add resources
        try pass.addInput(self.staging_resource.?, task.ResourceState{
            .accessMask = vk.ACCESS_TRANSFER_READ_BIT,
            .stageMask = vk.PIPELINE_STAGE_TRANSFER_BIT,
            .layout = undefined, // Not used for buffers
            .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        }, .{
            .offset = 0,
            .size = self.size,
        });

        // Extract the buffer from the target union
        const buffer = switch (self.target) {
            .buffer => |b| b.handle,
            .image => {
                logger.debug("[STAGE] ERROR: Cannot create staging pass with image target!", .{});
                return error.InvalidTargetType;
            },
        };

        // Create a resource for the target buffer
        const target_resource = try task.Resource.init(self.allocator, "TargetBuffer", task.ResourceType.Buffer, buffer);

        try pass.addOutput(target_resource, task.ResourceState{
            .accessMask = vk.ACCESS_TRANSFER_WRITE_BIT,
            .stageMask = vk.PIPELINE_STAGE_TRANSFER_BIT,
            .layout = undefined, // Not used for buffers
            .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        }, .{
            .offset = 0,
            .size = self.size,
        });

        return pass;
    }

    /// Destroy the stage and free its resources
    pub fn destroy(self: *Stage) void {
        if (self.destroyed) return;

        // Set destroyed flag first
        self.destroyed = true;

        // Only destroy if ref count is 0
        if (self.ref_count > 0) {
            logger.info("Stage marked as destroyed but ref count is {}, deferring actual destruction", .{self.ref_count});
            return;
        }

        logger.info("Destroying stage, buffer: {any}, memory: {any}, size: {d}", .{ self.buffer, self.memory, self.size });

        // Make sure all operations are complete
        if (self.last_fence) |fence| {
            logger.info("Waiting for fence: {any} before destruction", .{fence});
            const result = vk.waitForFences(self.device, 1, &fence, vk.TRUE, std.time.ns_per_s * 5);
            logger.info("Fence wait result: {any}", .{result});
            // Note: We don't destroy the fence as it's owned by the task system
            self.last_fence = null;
        }

        // Unmap memory if mapped
        if (self.mapped_ptr != null) {
            logger.info("Unmapping memory before destruction", .{});
            self.unmapMemory();
        }

        // Clean up resources
        logger.debug("[STAGE] Cleaning up uploads array", .{});
        self.uploads.deinit();

        // Clean up task resources if we created them
        if (self.staging_resource != null) {
            logger.debug("[STAGE] Cleaning up staging task resource: {any}", .{self.staging_resource});
            self.staging_resource.?.deinit(self.allocator);
            self.staging_resource = null;
        }

        // Clean up staging pass if we created it
        if (self.staging_pass != null) {
            logger.debug("[STAGE] Cleaning up staging pass: {any}", .{self.staging_pass});
            self.staging_pass.?.deinit(self.allocator.*);
            self.staging_pass = null;
        }

        // Free Vulkan resources
        logger.debug("[STAGE] Freeing Vulkan memory: {any}", .{self.memory});
        vk.freeMemory(self.device, self.memory, null);
        logger.debug("[STAGE] Destroying Vulkan buffer: {any}", .{self.buffer});
        vk.destroyBuffer(self.device, self.buffer, null);

        // Free our allocation
        logger.debug("[STAGE] Freeing Stage object", .{});
        self.allocator.destroy(self);
        logger.debug("[STAGE] Stage destroyed successfully", .{});
    }
};
