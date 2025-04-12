const std = @import("std");
const vk = @import("vulkan");
const Allocator = std.mem.Allocator;
const Device = @import("device.zig").Device;

/// Resource that can be a source for readback operations
pub const Source = union(enum) {
    buffer: struct {
        buffer: vk.Buffer,
        offset: u64,
    },
    image: struct {
        image: vk.Image,
        layout: vk.ImageLayout,
        offset: vk.Offset3D = .{ .x = 0, .y = 0, .z = 0 },
        extent: vk.Extent3D,
        aspect_mask: vk.ImageAspectFlags,
    },
};

/// CPU memory destination for readback operations
pub const Destination = struct {
    ptr: [*]u8,
    size: u64,
};

/// Handle to a readback operation in progress
pub const Operation = struct {
    offset: u64,
    size: u64,
    fence_index: usize,
    destination: Destination,
};

/// A buffer for downloading data from GPU to CPU
/// Acts as a ring buffer to efficiently reuse memory
pub const Readback = struct {
    allocator: Allocator,
    device: Device,
    
    // Ring buffer resources
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
    memory_ptr: [*]u8,
    size: u64,
    offset: u64,
    
    // Synchronization
    fences: []vk.Fence,
    fence_index: usize,
    
    pub fn init(allocator: Allocator, device: Device, size: u64, max_concurrent_ops: usize) !Readback {
        const buffer = try device.createBuffer(size, .{
            .transfer_dst_bit = true,
        }, .{
            .host_visible_bit = true,
            .host_cached_bit = true,
        });
        
        const memory = try device.allocateMemoryForBuffer(buffer, .{
            .host_visible_bit = true,
            .host_cached_bit = true,
        });
        
        const memory_ptr = try device.mapMemory(memory, 0, size);
        
        var fences = try allocator.alloc(vk.Fence, max_concurrent_ops);
        errdefer allocator.free(fences);
        
        for (fences) |*fence| {
            fence.* = try device.createFence(.{});
        }
        
        return Readback{
            .allocator = allocator,
            .device = device,
            .buffer = buffer,
            .memory = memory,
            .memory_ptr = @ptrCast([*]u8, memory_ptr),
            .size = size,
            .offset = 0,
            .fences = fences,
            .fence_index = 0,
        };
    }
    
    pub fn deinit(self: *Readback) void {
        self.device.unmapMemory(self.memory);
        
        for (self.fences) |fence| {
            self.device.destroyFence(fence);
        }
        self.allocator.free(self.fences);
        
        self.device.destroyBuffer(self.buffer);
        self.device.freeMemory(self.memory);
    }
    
    /// Schedule a copy from a GPU resource to the readback buffer and to a CPU destination
    pub fn copyFromSource(self: *Readback, cmd: vk.CommandBuffer, source: Source, destination: Destination) !Operation {
        // Wait for previous operations to complete if we'd wrap around
        const aligned_size = std.mem.alignForward(destination.size, 256);
        if (self.offset + aligned_size > self.size) {
            self.offset = 0;
        }
        
        // Find a spot in the ring buffer
        const offset = self.offset;
        self.offset += aligned_size;
        
        // Record copy commands based on source type
        switch (source) {
            .buffer => |buf| {
                const copy_region = vk.BufferCopy{
                    .src_offset = buf.offset,
                    .dst_offset = offset,
                    .size = destination.size,
                };
                self.device.cmdCopyBuffer(cmd, buf.buffer, self.buffer, 1, @ptrCast([*]const vk.BufferCopy, &copy_region));
            },
            .image => |img| {
                const copy_region = vk.BufferImageCopy{
                    .buffer_offset = offset,
                    .buffer_row_length = 0,  // Tightly packed
                    .buffer_image_height = 0,  // Tightly packed
                    .image_subresource = .{
                        .aspect_mask = img.aspect_mask,
                        .mip_level = 0,
                        .base_array_layer = 0,
                        .layer_count = 1,
                    },
                    .image_offset = img.offset,
                    .image_extent = img.extent,
                };
                self.device.cmdCopyImageToBuffer(cmd, img.image, img.layout, self.buffer, 1, @ptrCast([*]const vk.BufferImageCopy, &copy_region));
            },
        }
        
        // Track this operation with a fence
        const fence_index = self.fence_index;
        self.fence_index = (self.fence_index + 1) % self.fences.len;
        
        return Operation{
            .offset = offset,
            .size = destination.size,
            .fence_index = fence_index,
            .destination = destination,
        };
    }
    
    /// Read data back to CPU after GPU has finished writing
    /// Call after the command buffer with the copy command has been submitted
    pub fn readToCpu(self: *Readback, handle: Operation) !void {
        // Wait for the GPU to finish writing to the readback buffer
        try self.device.waitForFence(self.fences[handle.fence_index]);
        try self.device.resetFence(self.fences[handle.fence_index]);
        
        // Ensure memory is visible to the CPU 
        try self.device.invalidateMappedMemoryRanges(&[_]vk.MappedMemoryRange{
            .{
                .memory = self.memory,
                .offset = handle.offset,
                .size = handle.size,
            },
        });
        
        // Copy data from the readback buffer to the destination pointer
        @memcpy(handle.destination.ptr[0..handle.size], self.memory_ptr[handle.offset..handle.offset + handle.size]);
    }
};