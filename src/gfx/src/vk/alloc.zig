const std = @import("std");
pub const heap = @import("heap.zig");
pub const stage = @import("stage.zig");

/// Error type for allocation operations
pub const AllocError = error{
    InvalidatedStagingPointer,
    StagingBufferReset,
};

// Forward declaration for circular references
pub const Allocator = struct;

/// Represents a single allocation managed by the allocator
pub const Allocation = struct {
    /// Pointer to the staging memory
    stage_ptr: [*]u8,
    /// Size of the allocation
    size: usize,
    /// Offset in the heap where this allocation will be placed
    heap_offset: usize,
    /// Reference to the allocator that created this allocation
    allocator: *Allocator,
    /// Epoch when this allocation was created or last updated
    epoch: u32,
    /// Offset in the staging buffer
    stage_offset: usize,
    /// Current data in the allocation (local copy)
    data: []u8,
    
    /// Get a pointer to the staging memory for this allocation
    pub fn ptr(self: *Allocation) [*]u8 {
        return self.stage_ptr;
    }
    
    /// Flush this specific allocation to the GPU
    pub fn flush(self: *Allocation) !void {
        // Check if the epoch has changed
        if (self.epoch != self.allocator.current_epoch) {
            // Epoch has changed, we need to restage the data
            // Map memory if needed
            try self.allocator.stage.mapMemory();
            
            // Queue an upload using our saved data
            const stage_offset = try self.allocator.stage.queueUpload(self.data);
            
            // Update our staging pointer and offset
            self.stage_ptr = @as([*]u8, @ptrCast(self.allocator.stage.mapped_ptr.?)) + stage_offset;
            self.stage_offset = stage_offset;
            
            // Update the epoch
            self.epoch = self.allocator.current_epoch;
        } else {
            // Epoch is the same, we can just use our current staging pointer
            // Map memory if needed
            try self.allocator.stage.mapMemory();
            
            // Queue an upload to the specific location in the heap
            // We copy from our local data to ensure consistency
            const stage_offset = try self.allocator.stage.queueUpload(self.data);
            
            // Update the stage_ptr to point to the new staging location
            self.stage_ptr = @as([*]u8, @ptrCast(self.allocator.stage.mapped_ptr.?)) + stage_offset;
            self.stage_offset = stage_offset;
        }
        
        // Flush the uploads to the GPU
        try self.allocator.stage.flushUploads();
    }
    
    /// Write data to this allocation and return the number of bytes written
    pub fn write(self: *Allocation, data: []const u8) !usize {
        // Map memory if needed
        try self.allocator.stage.mapMemory();
        
        // Calculate how much data we can write
        const bytes_to_write = @min(data.len, self.size);
        
        // Check if our epoch is current
        if (self.epoch != self.allocator.current_epoch) {
            // Epoch has changed, we need to restage this allocation
            // first update our local copy
            std.mem.copy(u8, self.data[0..bytes_to_write], data[0..bytes_to_write]);
            
            // Queue upload with new data
            const stage_offset = try self.allocator.stage.queueUpload(self.data);
            
            // Update our staging pointer and offset
            self.stage_ptr = @as([*]u8, @ptrCast(self.allocator.stage.mapped_ptr.?)) + stage_offset;
            self.stage_offset = stage_offset;
            
            // Update our epoch
            self.epoch = self.allocator.current_epoch;
        } else {
            // Epoch is current, just update our local copy and staging memory
            std.mem.copy(u8, self.data[0..bytes_to_write], data[0..bytes_to_write]);
            std.mem.copy(u8, self.stage_ptr[0..bytes_to_write], data[0..bytes_to_write]);
        }
        
        return bytes_to_write;
    }
    
    /// Get the GPU device address for this allocation
    pub fn deviceAddress(self: *Allocation) !u64 {
        const base_address = try self.allocator.heap.getDeviceAddress();
        return base_address + self.heap_offset;
    }
};

pub const Allocator = struct {
    heap: *heap.Heap,
    stage: *stage.Stage,

    bump: usize,
    
    // Memory for allocations
    allocation_memory: std.heap.ArenaAllocator,
    
    // Current epoch counter
    current_epoch: u32,

    pub fn init(heap: *heap.Heap, stage: *stage.Stage) Allocator {
        return Allocator {
            .heap = heap,
            .stage = stage,
            .bump = 0,
            .allocation_memory = std.heap.ArenaAllocator.init(std.heap.c_allocator),
            .current_epoch = 0,
        };
    }
    
    /// Flush all staged allocations to the GPU
    pub fn flush(self: *Allocator) !void {
        // Unmap the staging memory
        self.stage.unmapMemory();
        
        // Flush the uploads to the target (the heap buffer)
        try self.stage.flushUploads();
    }
    
    /// Reset the allocator, clearing all allocations
    pub fn reset(self: *Allocator) void {
        // Reset the bump pointer to the beginning
        self.bump = 0;
        
        // Reset the stage buffer offset
        self.stage.resetOffset();
        
        // Increment the epoch to invalidate existing allocations
        self.current_epoch += 1;
        
        // Reset the allocation memory
        self.allocation_memory.deinit();
        self.allocation_memory = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    }
    
    /// Clean up the allocator resources
    pub fn deinit(self: *Allocator) void {
        // Free the allocation memory
        self.allocation_memory.deinit();
    }

    pub fn alloc(self: *Allocator, size: usize, align: usize) !*Allocation {
        // Align the current offset according to the requested alignment
        const aligned_offset = std.mem.alignForward(self.bump, align);
        
        // Check if we need to grow the heap
        const end_offset = aligned_offset + size;
        if (end_offset > self.heap.size) {
            // Try to grow the heap to accommodate the new allocation
            // Stage's command buffer is used for copying data when growing
            try self.heap.grow(end_offset, self.stage.staging_resource.buffer_copy_pass.command_buffer);
        }
        
        // Map the staging buffer memory if it's not already mapped
        try self.stage.mapMemory();
        
        // Create a temporary buffer of zeros for the initial upload
        // This is a safer approach than using std.mem.zeroes for dynamic sizes
        var temp_buffer = try std.heap.c_allocator.alloc(u8, size);
        defer std.heap.c_allocator.free(temp_buffer);
        @memset(temp_buffer, 0); // Initialize to zeros
        
        // Reserve space in the staging buffer for this allocation
        // This returns the offset in the staging buffer
        const stage_offset = try self.stage.queueUpload(temp_buffer);
        
        // Get a pointer to the staged data in the mapping
        const stage_ptr = @as([*]u8, @ptrCast(self.stage.mapped_ptr.?)) + stage_offset;
        
        // Update the bump pointer to the end of the allocation in the heap
        self.bump = end_offset;
        
        // Allocate memory for our local data copy
        var data = try self.allocation_memory.allocator().alloc(u8, size);
        @memset(data, 0); // Initialize to zeros
        
        // Copy the initial zeros to the data buffer
        std.mem.copy(u8, data, temp_buffer);
        
        // Create the allocation object
        var allocation = try self.allocation_memory.allocator().create(Allocation);
        allocation.* = Allocation{
            .stage_ptr = stage_ptr,
            .size = size,
            .heap_offset = aligned_offset,
            .allocator = self,
            .epoch = self.current_epoch,
            .stage_offset = stage_offset,
            .data = data,
        };
        
        return allocation;
    }
};
