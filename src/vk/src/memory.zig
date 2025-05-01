const std = @import("std");
const raw = @import("raw.zig");
const errors = @import("errors.zig");
const commands = @import("commands.zig");
const device_mod = @import("device.zig");

/// Buffer abstraction with utility functions
pub const Buffer = struct {
    handle: raw.Buffer,
    device: raw.Device,
    memory: raw.DeviceMemory,
    size: u64,
    memory_property_flags: raw.MemoryPropertyFlags,
    usage_flags: raw.BufferUsageFlags,

    /// Configuration options for creating a buffer
    pub const CreateInfo = struct {
        size: u64,
        usage_flags: raw.BufferUsageFlags,
        memory_property_flags: raw.MemoryPropertyFlags,
        device_address: bool = false,
    };

    /// Create a new buffer with the given configuration
    pub fn create(device: raw.Device, physical_device: device_mod.PhysicalDevice, create_info: CreateInfo) errors.Error!Buffer {
        const buffer_info = raw.BufferCreateInfo{
            .sType = raw.sTy(.BufferCreateInfo),
            .pNext = null,
            .flags = if (create_info.device_address) raw.BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT else 0,
            .size = create_info.size,
            .usage = create_info.usage_flags,
            .sharingMode = raw.SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        var buffer: raw.Buffer = undefined;
        const result = raw.createBuffer(device, &buffer_info, null, &buffer);
        try errors.checkResult(result);

        // Get memory requirements
        var mem_requirements: raw.MemoryRequirements = undefined;
        raw.getBufferMemoryRequirements(device, buffer, &mem_requirements);

        // Find a suitable memory type
        const memory_type_index = try physical_device.findMemoryType(mem_requirements.memoryTypeBits, create_info.memory_property_flags);

        // Prepare memory allocation
        var alloc_flags_info: ?*raw.MemoryAllocateFlagsInfo = null;
        var alloc_flags_data: raw.MemoryAllocateFlagsInfo = undefined;

        // Set up for device address if requested
        if (create_info.device_address) {
            alloc_flags_data = raw.MemoryAllocateFlagsInfo{
                .sType = raw.sTy(.MemoryAllocateFlagsInfo),
                .pNext = null,
                .flags = raw.MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT,
                .deviceMask = 0,
            };
            alloc_flags_info = &alloc_flags_data;
        }

        // Allocate memory
        const alloc_info = raw.MemoryAllocateInfo{
            .sType = raw.sTy(.MemoryAllocateInfo),
            .pNext = if (alloc_flags_info) |info| @ptrCast(info) else null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };

        var memory: raw.DeviceMemory = undefined;
        const mem_result = raw.allocateMemory(device, &alloc_info, null, &memory);

        if (mem_result != raw.SUCCESS) {
            raw.destroyBuffer(device, buffer, null);
            return errors.Error.OutOfDeviceMemory;
        }

        // Bind memory to buffer
        const bind_result = raw.bindBufferMemory(device, buffer, memory, 0);

        if (bind_result != raw.SUCCESS) {
            raw.freeMemory(device, memory, null);
            raw.destroyBuffer(device, buffer, null);
            return errors.Error.ResourceCreationFailed;
        }

        return Buffer{
            .handle = buffer,
            .device = device,
            .memory = memory,
            .size = create_info.size,
            .memory_property_flags = create_info.memory_property_flags,
            .usage_flags = create_info.usage_flags,
        };
    }

    /// Destroy the buffer and free resources
    pub fn destroy(self: *Buffer) void {
        raw.destroyBuffer(self.device, self.handle, null);
        raw.freeMemory(self.device, self.memory, null);
        self.* = undefined;
    }

    /// Map the buffer memory to host accessible memory
    pub fn map(self: Buffer, offset: u64, size: u64) errors.Error!*anyopaque {
        var data: ?*anyopaque = null;
        const result = raw.mapMemory(self.device, self.memory, offset, if (size == 0) raw.WHOLE_SIZE else size, 0, &data);
        try errors.checkResult(result);
        return data.?;
    }

    /// Unmap the buffer memory
    pub fn unmap(self: Buffer) void {
        raw.unmapMemory(self.device, self.memory);
    }

    /// Copy data to the buffer
    pub fn copyFromHost(self: Buffer, data: []const u8) errors.Error!void {
        if (self.size < data.len) {
            return errors.Error.ResourceCreationFailed;
        }

        // Check if memory is host visible
        if ((self.memory_property_flags & raw.MEMORY_PROPERTY_HOST_VISIBLE_BIT) == 0) {
            return errors.Error.ResourceCreationFailed;
        }

        // Map memory
        var mapped = try self.map(0, raw.WHOLE_SIZE);

        // Copy data
        @memcpy(@as([*]u8, @ptrCast(mapped))[0..data.len], data);

        // If memory isn't coherent, flush it
        if ((self.memory_property_flags & raw.MEMORY_PROPERTY_HOST_COHERENT_BIT) == 0) {
            const mapped_range = raw.MappedMemoryRange{
                .sType = raw.sTy(.MemoryAllocateInfo),
                .pNext = null,
                .memory = self.memory,
                .offset = 0,
                .size = raw.WHOLE_SIZE,
            };
            _ = raw.flushMappedMemoryRanges(self.device, 1, &mapped_range);
        }

        // Unmap memory
        self.unmap();
    }

    /// Copy data from this buffer to another buffer
    pub fn copyToBuffer(self: Buffer, dst_buffer: Buffer, command_pool: raw.CommandPool, queue: raw.Queue) errors.Error!void {
        // Create temporary command buffer
        var cmd = try commands.createSingleTimeCommands(self.device, command_pool);

        // Set up copy region
        const region = raw.BufferCopy{
            .srcOffset = 0,
            .dstOffset = 0,
            .size = self.size,
        };

        // Record copy command
        cmd.copyBuffer(self.handle, dst_buffer.handle, &[_]raw.BufferCopy{region});

        // Submit and cleanup command buffer
        try commands.endSingleTimeCommands(cmd, queue);
    }

    /// Get the device address of this buffer (for shader access)
    pub fn getDeviceAddress(self: Buffer) u64 {
        if ((self.usage_flags & raw.BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT) == 0) {
            return 0;
        }

        const info = raw.BufferDeviceAddressInfo{
            .sType = raw.sTy(.BufferDeviceAddressInfo),
            .pNext = null,
            .buffer = self.handle,
        };

        return raw.getBufferDeviceAddress(self.device, &info);
    }

    /// Get the raw buffer handle
    pub fn getHandle(self: Buffer) raw.Buffer {
        return self.handle;
    }

    /// Get the size of the buffer
    pub fn getSize(self: Buffer) u64 {
        return self.size;
    }
};

/// Image abstraction with utility functions
pub const Image = struct {
    handle: raw.Image,
    device: raw.Device,
    memory: raw.DeviceMemory,
    view: ?raw.ImageView,
    width: u32,
    height: u32,
    depth: u32,
    format: raw.Format,
    tiling: raw.ImageTiling,
    usage: u32,
    aspect_flags: raw.ImageAspectFlags,

    /// Configuration options for creating an image
    pub const CreateInfo = struct {
        width: u32,
        height: u32,
        depth: u32 = 1,
        format: raw.Format,
        tiling: raw.ImageTiling = raw.IMAGE_TILING_OPTIMAL,
        usage: u32,
        memory_property_flags: raw.MemoryPropertyFlags,
        create_view: bool = true,
        aspect_flags: raw.ImageAspectFlags = raw.IMAGE_ASPECT_COLOR_BIT,
    };

    /// Create a new image with the given configuration
    pub fn create(device: raw.Device, physical_device: device_mod.PhysicalDevice, create_info: CreateInfo) errors.Error!Image {
        // Create image
        const image_info = raw.ImageCreateInfo{
            .sType = raw.sTy(.ImageCreateInfo),
            .pNext = null,
            .flags = 0,
            .imageType = raw.IMAGE_TYPE_2D,
            .format = @intFromEnum(create_info.format),
            .extent = .{
                .width = create_info.width,
                .height = create_info.height,
                .depth = create_info.depth,
            },
            .mipLevels = 1,
            .arrayLayers = 1,
            .samples = raw.SAMPLE_COUNT_1_BIT,
            .tiling = create_info.tiling,
            .usage = create_info.usage,
            .sharingMode = raw.SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
            .initialLayout = raw.IMAGE_LAYOUT_UNDEFINED,
        };

        var image: raw.Image = undefined;
        const result = raw.createImage(device, &image_info, null, &image);
        try errors.checkResult(result);

        // Get memory requirements
        var mem_requirements: raw.MemoryRequirements = undefined;
        raw.getImageMemoryRequirements(device, image, &mem_requirements);

        // Find memory type
        const memory_type_index = try physical_device.findMemoryType(mem_requirements.memoryTypeBits, create_info.memory_property_flags);

        // Allocate memory
        const alloc_info = raw.MemoryAllocateInfo{
            .sType = raw.sTy(.MemoryAllocateInfo),
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };

        var memory: raw.DeviceMemory = undefined;
        const mem_result = raw.allocateMemory(device, &alloc_info, null, &memory);

        if (mem_result != raw.SUCCESS) {
            raw.destroyImage(device, image, null);
            return errors.Error.OutOfDeviceMemory;
        }

        // Bind memory to image
        const bind_result = raw.bindImageMemory(device, image, memory, 0);

        if (bind_result != raw.SUCCESS) {
            raw.freeMemory(device, memory, null);
            raw.destroyImage(device, image, null);
            return errors.Error.ResourceCreationFailed;
        }

        var view: ?raw.ImageView = null;

        // Create image view if requested
        if (create_info.create_view) {
            const view_info = raw.ImageViewCreateInfo{
                .sType = raw.sTy(.ImageViewCreateInfo),
                .pNext = null,
                .flags = 0,
                .image = image,
                .viewType = raw.IMAGE_VIEW_TYPE_2D,
                .format = @intFromEnum(create_info.format),
                .components = .{
                    .r = raw.COMPONENT_SWIZZLE_IDENTITY,
                    .g = raw.COMPONENT_SWIZZLE_IDENTITY,
                    .b = raw.COMPONENT_SWIZZLE_IDENTITY,
                    .a = raw.COMPONENT_SWIZZLE_IDENTITY,
                },
                .subresourceRange = .{
                    .aspectMask = create_info.aspect_flags,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
            };

            var image_view: raw.ImageView = undefined;
            const view_result = raw.createImageView(device, &view_info, null, &image_view);

            if (view_result != raw.SUCCESS) {
                raw.freeMemory(device, memory, null);
                raw.destroyImage(device, image, null);
                return errors.Error.ResourceCreationFailed;
            }

            view = image_view;
        }

        return Image{
            .handle = image,
            .device = device,
            .memory = memory,
            .view = view,
            .width = create_info.width,
            .height = create_info.height,
            .depth = create_info.depth,
            .format = create_info.format,
            .tiling = create_info.tiling,
            .usage = create_info.usage,
            .aspect_flags = create_info.aspect_flags,
        };
    }

    /// Destroy the image and free resources
    pub fn destroy(self: *Image) void {
        if (self.view) |view| {
            raw.destroyImageView(self.device, view, null);
        }
        raw.destroyImage(self.device, self.handle, null);
        raw.freeMemory(self.device, self.memory, null);
        self.* = undefined;
    }

    /// Transition the image layout from one layout to another
    pub fn transitionLayout(self: Image, command_buffer: commands.CommandBuffer, old_layout: raw.ImageLayout, new_layout: raw.ImageLayout) void {
        var src_access_mask: raw.AccessFlags2KHR = raw.ACCESS_2_NONE;
        var dst_access_mask: raw.AccessFlags2KHR = raw.ACCESS_2_NONE;
        var src_stage_mask: raw.PipelineStageFlags2KHR = raw.PIPELINE_STAGE_2_NONE_KHR;
        var dst_stage_mask: raw.PipelineStageFlags2KHR = raw.PIPELINE_STAGE_2_NONE_KHR;

        if (old_layout == raw.IMAGE_LAYOUT_UNDEFINED and
            new_layout == raw.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
        {
            // Transfer write operation - used as destination in a transfer
            src_access_mask = raw.ACCESS_2_NONE;
            dst_access_mask = raw.ACCESS_2_MEMORY_WRITE_BIT;
            src_stage_mask = raw.PIPELINE_STAGE_2_TOP_OF_PIPE_BIT_KHR;
            dst_stage_mask = raw.PIPELINE_STAGE_2_ALL_COMMANDS_BIT_KHR;
        } else if (old_layout == raw.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL and
            new_layout == raw.IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
        {
            // Read in a shader after transfer is done
            src_access_mask = raw.ACCESS_2_MEMORY_WRITE_BIT;
            dst_access_mask = raw.ACCESS_2_MEMORY_READ_BIT;
            src_stage_mask = raw.PIPELINE_STAGE_2_ALL_COMMANDS_BIT_KHR;
            dst_stage_mask = raw.PIPELINE_STAGE_2_ALL_COMMANDS_BIT_KHR;
        } else if (old_layout == raw.IMAGE_LAYOUT_UNDEFINED and
            new_layout == raw.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
        {
            // Use as color attachment
            src_access_mask = raw.ACCESS_2_NONE;
            dst_access_mask = raw.ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT_KHR |
                raw.ACCESS_2_COLOR_ATTACHMENT_READ_BIT_KHR;
            src_stage_mask = raw.PIPELINE_STAGE_2_TOP_OF_PIPE_BIT_KHR;
            dst_stage_mask = raw.PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR;
        } else if (old_layout == raw.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL and
            new_layout == raw.IMAGE_LAYOUT_PRESENT_SRC_KHR)
        {
            // Use for presentation
            src_access_mask = raw.ACCESS_2_COLOR_ATTACHMENT_WRITE_BIT_KHR;
            dst_access_mask = raw.ACCESS_2_MEMORY_READ_BIT;
            src_stage_mask = raw.PIPELINE_STAGE_2_COLOR_ATTACHMENT_OUTPUT_BIT_KHR;
            dst_stage_mask = raw.PIPELINE_STAGE_2_BOTTOM_OF_PIPE_BIT_KHR;
        } else {
            // Default/fallback transition - allow everything but wait for memory safety
            src_access_mask = raw.ACCESS_2_MEMORY_WRITE_BIT;
            dst_access_mask = raw.ACCESS_2_MEMORY_READ_BIT | raw.ACCESS_2_MEMORY_WRITE_BIT;
            src_stage_mask = raw.PIPELINE_STAGE_2_ALL_COMMANDS_BIT_KHR;
            dst_stage_mask = raw.PIPELINE_STAGE_2_ALL_COMMANDS_BIT_KHR;
        }

        // Create image barrier
        const barrier = raw.ImageMemoryBarrier2KHR{
            .sType = raw.sTy(.ImageMemoryBarrier2KHR),
            .pNext = null,
            .srcStageMask = src_stage_mask,
            .srcAccessMask = src_access_mask,
            .dstStageMask = dst_stage_mask,
            .dstAccessMask = dst_access_mask,
            .oldLayout = old_layout,
            .newLayout = new_layout,
            .srcQueueFamilyIndex = raw.QUEUE_FAMILY_IGNORED,
            .dstQueueFamilyIndex = raw.QUEUE_FAMILY_IGNORED,
            .image = self.handle,
            .subresourceRange = .{
                .aspectMask = self.aspect_flags,
                .baseMipLevel = 0,
                .levelCount = raw.REMAINING_MIP_LEVELS,
                .baseArrayLayer = 0,
                .layerCount = raw.REMAINING_ARRAY_LAYERS,
            },
        };

        // Submit the barrier
        command_buffer.pipelineBarrier(0, 0, 0, null, null, &[_]raw.ImageMemoryBarrier2KHR{barrier});
    }

    /// Copy data from a buffer to this image
    pub fn copyFromBuffer(self: Image, command_buffer: commands.CommandBuffer, buffer: Buffer) void {
        const region = raw.BufferImageCopy{
            .bufferOffset = 0,
            .bufferRowLength = 0,
            .bufferImageHeight = 0,
            .imageSubresource = .{
                .aspectMask = self.aspect_flags,
                .mipLevel = 0,
                .baseArrayLayer = 0,
                .layerCount = 1,
            },
            .imageOffset = .{ .x = 0, .y = 0, .z = 0 },
            .imageExtent = .{
                .width = self.width,
                .height = self.height,
                .depth = self.depth,
            },
        };

        command_buffer.copyBufferToImage(buffer.handle, self.handle, raw.IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &[_]raw.BufferImageCopy{region});
    }

    /// Get the raw image handle
    pub fn getHandle(self: Image) raw.Image {
        return self.handle;
    }

    /// Get the image view if it was created
    pub fn getView(self: Image) ?raw.ImageView {
        return self.view;
    }

    /// Get the format of the image
    pub fn getFormat(self: Image) raw.Format {
        return self.format;
    }

    /// Get the dimensions of the image
    pub fn getDimensions(self: Image) struct { width: u32, height: u32, depth: u32 } {
        return .{
            .width = self.width,
            .height = self.height,
            .depth = self.depth,
        };
    }
};
