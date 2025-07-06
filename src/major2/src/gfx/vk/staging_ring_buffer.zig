const std = @import("std");
const vk = @import("vulkan-zig");
const Renderer = @import("render.zig").Renderer;

pub const StagingRingBuffer = struct {
    renderer: *Renderer,
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
    size: u64,
    alignment: u64,
    write_offset: u64,
    fence_value: u64,
    mapped_ptr: [*]u8,
    
    // Per-frame fence tracking
    frame_fences: []FrameFence,
    current_frame: u32,
    
    const FrameFence = struct {
        fence_value: u64,
        offset: u64,
        size: u64,
    };
    
    pub fn init(renderer: *Renderer, size: u64, max_frames: u32) !StagingRingBuffer {
        const device = renderer.device.device;
        const dispatch = &renderer.device.dispatch;
        
        // Ensure size is aligned to 256 bytes for typical GPU requirements
        const alignment: u64 = 256;
        const aligned_size = (size + alignment - 1) & ~(alignment - 1);
        
        // Create buffer with HOST_VISIBLE | HOST_COHERENT for CPU access
        const buffer_info = vk.BufferCreateInfo{
            .size = aligned_size,
            .usage = .{ 
                .transfer_src_bit = true,
                .transfer_dst_bit = true,
            },
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = null,
        };
        
        var buffer: vk.Buffer = undefined;
        const result = dispatch.vkCreateBuffer.?(device, &buffer_info, null, &buffer);
        if (result != .success) return error.BufferCreationFailed;
        
        // Get memory requirements
        var mem_reqs: vk.MemoryRequirements = undefined;
        dispatch.vkGetBufferMemoryRequirements.?(device, buffer, &mem_reqs);
        
        // Find suitable memory type - HOST_VISIBLE and HOST_COHERENT
        const mem_type_index = findMemoryType(
            renderer,
            mem_reqs.memory_type_bits,
            .{ .host_visible_bit = true, .host_coherent_bit = true }
        ) orelse return error.NoSuitableMemoryType;
        
        // Allocate memory
        const alloc_info = vk.MemoryAllocateInfo{
            .allocation_size = mem_reqs.size,
            .memory_type_index = mem_type_index,
        };
        
        var memory: vk.DeviceMemory = undefined;
        if (dispatch.vkAllocateMemory.?(device, &alloc_info, null, &memory) != .success) {
            dispatch.vkDestroyBuffer.?(device, buffer, null);
            return error.MemoryAllocationFailed;
        }
        
        // Bind memory to buffer
        if (dispatch.vkBindBufferMemory.?(device, buffer, memory, 0) != .success) {
            dispatch.vkFreeMemory.?(device, memory, null);
            dispatch.vkDestroyBuffer.?(device, buffer, null);
            return error.MemoryBindFailed;
        }
        
        // Map the entire buffer permanently
        var mapped_ptr: ?*anyopaque = undefined;
        if (dispatch.vkMapMemory.?(device, memory, 0, vk.WHOLE_SIZE, .{}, &mapped_ptr) != .success) {
            dispatch.vkFreeMemory.?(device, memory, null);
            dispatch.vkDestroyBuffer.?(device, buffer, null);
            return error.MemoryMapFailed;
        }
        
        // Allocate frame fence tracking
        const allocator = renderer.allocator;
        const frame_fences = try allocator.alloc(FrameFence, max_frames);
        for (frame_fences) |*fence| {
            fence.* = .{
                .fence_value = 0,
                .offset = 0,
                .size = 0,
            };
        }
        
        return .{
            .renderer = renderer,
            .buffer = buffer,
            .memory = memory,
            .size = aligned_size,
            .alignment = alignment,
            .write_offset = 0,
            .fence_value = 0,
            .mapped_ptr = @ptrCast(mapped_ptr.?),
            .frame_fences = frame_fences,
            .current_frame = 0,
        };
    }
    
    pub fn deinit(self: *StagingRingBuffer) void {
        const device = self.renderer.device.device;
        const dispatch = &self.renderer.device.dispatch;
        
        dispatch.vkUnmapMemory.?(device, self.memory);
        dispatch.vkDestroyBuffer.?(device, self.buffer, null);
        dispatch.vkFreeMemory.?(device, self.memory, null);
        self.renderer.allocator.free(self.frame_fences);
    }
    
    pub const Allocation = struct {
        buffer: vk.Buffer,
        offset: u64,
        ptr: [*]u8,
        size: u64,
    };
    
    /// Allocate space in the ring buffer, potentially waiting for old allocations to be freed
    pub fn allocate(self: *StagingRingBuffer, size: u64) !Allocation {
        // Align allocation size
        const aligned_size = (size + self.alignment - 1) & ~(self.alignment - 1);
        
        // Check if we need to wrap around
        if (self.write_offset + aligned_size > self.size) {
            // Wrap to beginning
            self.write_offset = 0;
        }
        
        // Check if we're overlapping with in-flight frames
        const end_offset = self.write_offset + aligned_size;
        for (self.frame_fences) |fence| {
            if (fence.fence_value == 0) continue;
            
            // Check if this allocation would overlap with an in-flight range
            const fence_end = fence.offset + fence.size;
            
            // Check for overlap
            if (self.write_offset < fence_end and end_offset > fence.offset) {
                // Wait for this fence before continuing
                // In a real implementation, you'd wait on the GPU fence here
                // For now, we'll just return an error to indicate the buffer is full
                return error.StagingBufferFull;
            }
        }
        
        const allocation = Allocation{
            .buffer = self.buffer,
            .offset = self.write_offset,
            .ptr = self.mapped_ptr + self.write_offset,
            .size = aligned_size,
        };
        
        self.write_offset = end_offset;
        if (self.write_offset >= self.size) {
            self.write_offset = 0;
        }
        
        return allocation;
    }
    
    /// Mark a range as in-use for the current frame
    pub fn markInUse(self: *StagingRingBuffer, offset: u64, size: u64, fence_value: u64) void {
        self.frame_fences[self.current_frame] = .{
            .fence_value = fence_value,
            .offset = offset,
            .size = size,
        };
    }
    
    /// Advance to the next frame
    pub fn nextFrame(self: *StagingRingBuffer) void {
        self.current_frame = (self.current_frame + 1) % @intCast(self.frame_fences.len);
    }
    
    /// Copy data to the staging buffer and return the allocation
    pub fn stage(self: *StagingRingBuffer, data: []const u8) !Allocation {
        const allocation = try self.allocate(data.len);
        @memcpy(allocation.ptr[0..data.len], data);
        return allocation;
    }
    
    /// Record a copy command from staging buffer to destination
    pub fn recordCopy(
        self: *StagingRingBuffer,
        cmd: vk.CommandBuffer,
        allocation: Allocation,
        dst_buffer: vk.Buffer,
        dst_offset: u64,
    ) void {
        const dispatch = &self.renderer.device.dispatch;
        
        const copy_region = vk.BufferCopy{
            .src_offset = allocation.offset,
            .dst_offset = dst_offset,
            .size = allocation.size,
        };
        
        dispatch.vkCmdCopyBuffer.?(
            cmd,
            allocation.buffer,
            dst_buffer,
            1,
            @ptrCast(&copy_region)
        );
    }
    
    fn findMemoryType(renderer: *Renderer, type_filter: u32, properties: vk.MemoryPropertyFlags) ?u32 {
        const mem_props = renderer.device.physical_device.memory_properties;
        
        var i: u32 = 0;
        while (i < mem_props.memory_type_count) : (i += 1) {
            const type_bit = @as(u32, 1) << @intCast(i);
            if ((type_filter & type_bit) != 0) {
                const mem_type = mem_props.memory_types[i];
                if (mem_type.property_flags.contains(properties)) {
                    return i;
                }
            }
        }
        
        return null;
    }
};