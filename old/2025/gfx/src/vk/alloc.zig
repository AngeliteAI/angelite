const vk = @import("vk.zig");
const std = @import("std");
const heap = @import("heap.zig");
const stage = @import("stage.zig");
const task = @import("task.zig");
const logger = @import("../logger.zig");

/// Error type for allocation operations
pub const AllocError = error{
    InvalidatedStagingPointer,
    StagingBufferReset,
};

// Forward declaration for circular references
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
    /// Mutex for thread safety
    mutex: std.Thread.Mutex,
    /// Whether the allocation has been staged
    staged: bool,
    /// Whether the memory is currently mapped
    mapped: bool,

    /// Get a pointer to the staging memory for this allocation
    pub fn ptr(self: *Allocation) [*]u8 {
        return self.stage_ptr;
    }

    /// Map the staging memory for this allocation
    pub fn map(self: *Allocation) !void {
        if (!self.mapped) {
            try self.allocator.stage.mapMemory();
            self.mapped = true;
        }
    }

    /// Unmap the staging memory for this allocation
    pub fn unmap(self: *Allocation) void {
        if (self.mapped) {
            self.allocator.stage.unmapMemory();
            self.mapped = false;
        }
    }

    /// Flush this specific allocation to the GPU
    pub fn flush(self: *Allocation) !void {
        if (self.staged) {
            logger.info("Flushing allocation to GPU...", .{});

            // Ensure memory is mapped before flushing
            if (!self.mapped) {
                try self.map();
            }

            // Log the allocation details for debugging
            logger.info("Allocation details: size={}, stage_offset={}, heap_offset={}", .{
                self.size,
                self.stage_offset,
                self.heap_offset,
            });

            // Flush all staged allocations to GPU
            try self.allocator.flushAllStaged();

            // Don't unmap here - let the allocator handle unmapping
            // This prevents issues with multiple allocations sharing the same mapped memory
            logger.info("Allocation flushed successfully", .{});
        } else {
            logger.warn("Allocation is not staged, nothing to flush", .{});
        }
    }

    /// Write data to this allocation and return the number of bytes written
    pub fn write(self: *Allocation, data: []const u8) !usize {
        // Lock the mutex for thread safety
        self.mutex.lock();
        defer self.mutex.unlock();

        if (data.len > self.size) {
            return error.BufferTooSmall;
        }

        // Map memory if not already mapped
        try self.allocator.stage.mapMemory();

        // Calculate the offset in the mapped memory
        const offset = self.stage_offset;

        // Copy data to the mapped memory
        const dest = @as([*]u8, @ptrCast(@alignCast(self.allocator.stage.mapped_ptr.?))) + offset;
        @memcpy(dest[0..data.len], data);

        // Also update our local copy
        @memcpy(self.data[0..data.len], data);

        // Mark the allocation as staged
        self.staged = true;

        try self.allocator.staged_allocations.append(self);
        logger.info("Written {} bytes to allocation at offset {}", .{ data.len, offset });

        return data.len;
    }

    /// Get the GPU device address for this allocation
    pub fn deviceAddress(self: *Allocation) !u64 {
        // Lock the mutex for thread safety
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if the allocation is still valid
        if (self.epoch != self.allocator.current_epoch) {
            return error.AllocationStale;
        }

        // Get the heap device address
        const heap_address = try self.allocator.heap.getDeviceAddress();

        // Calculate the device address for this allocation
        const device_address = heap_address + self.heap_offset;

        logger.info("Device address for allocation at offset {}: 0x{x}", .{ self.heap_offset, device_address });

        return device_address;
    }
};

pub const Allocator = struct {
    device: vk.Device,
    heap: *heap.Heap,
    stage: *stage.Stage,
    graph: *task.Graph,
    bump: usize,
    allocation_memory: std.heap.ArenaAllocator,
    current_epoch: u32,
    mutex: std.Thread.Mutex,
    staged_allocations: std.ArrayList(*Allocation),

    pub fn init(device: vk.Device, heap_ptr: *heap.Heap, stage_ptr: *stage.Stage, graph_ptr: *task.Graph) Allocator {
        return Allocator{
            .device = device,
            .heap = heap_ptr,
            .stage = stage_ptr,
            .graph = graph_ptr,
            .bump = 0,
            .allocation_memory = std.heap.ArenaAllocator.init(std.heap.c_allocator),
            .current_epoch = 0,
            .mutex = std.Thread.Mutex{},
            .staged_allocations = std.ArrayList(*Allocation).init(std.heap.c_allocator),
        };
    }

    /// Flush all staged allocations to the GPU
    pub fn flush(self: *Allocator) !void {
        // Check if we have any staged allocations
        if (self.staged_allocations.items.len == 0) {
            logger.info("No staged allocations to flush", .{});
            return;
        }

        for (self.staged_allocations.items) |allocation| {
            self.stage.uploads.append(.{
                .offset = allocation.stage_offset,
                .size = allocation.size,
                .data = allocation.data,
                .heap_offset = allocation.heap_offset,
            }) catch unreachable;
        }
    }

    /// Reset the allocator, clearing all allocations
    pub fn reset(self: *Allocator) !void {
        // Reset the bump pointer to a non-zero value
        self.bump = 0;

        // Reset the stage buffer offset
        self.stage.resetOffset();

        // Increment the epoch to invalidate existing allocations
        self.current_epoch += 1;

        // Reset the allocation memory
        self.allocation_memory.deinit();
        self.allocation_memory = std.heap.ArenaAllocator.init(std.heap.c_allocator);

        // Clear staged allocations
        self.staged_allocations.clearRetainingCapacity();

        logger.info("Allocator reset, epoch incremented to {}", .{self.current_epoch});
    }

    /// Clean up the allocator resources
    pub fn deinit(self: *Allocator) void {
        // Free the allocation memory
        self.allocation_memory.deinit();

        // Free the staged allocations list
        self.staged_allocations.deinit();
    }

    pub fn alloc(self: *Allocator, size: usize) !*Allocation {
        // For PhysicalStorageBuffer64, we need 16-byte alignment
        const alignment = 16;
        const aligned_offset = std.mem.alignForward(usize, self.bump, alignment);

        logger.info("Allocating {} bytes at heap offset {} (aligned from {})", .{ size, aligned_offset, self.bump });

        // Check if we need to grow the heap
        const end_offset = aligned_offset + size;
        if (end_offset > self.heap.size) {
            // Try to grow the heap to accommodate the new allocation
            // Stage's command buffer is used for copying data when growing
            //panic for now TODO
            unreachable;
            // try self.heap.grow(end_offset, self.stage.staging_resource.buffer_copy_pass.command_buffer);
        }

        // Map the staging buffer memory if it's not already mapped
        try self.stage.mapMemory();

        // Create a temporary buffer of zeros for the initial upload
        // This is a safer approach than using std.mem.zeroes for dynamic sizes
        const temp_buffer = try std.heap.c_allocator.alloc(u8, size);
        defer std.heap.c_allocator.free(temp_buffer);
        @memset(temp_buffer, 0); // Initialize to zeros

        // Reserve space in the staging buffer for this allocation
        // This returns the offset in the staging buffer
        const stage_offset = try self.stage.queueUpload(temp_buffer, aligned_offset);
        logger.info("Allocated {} bytes at heap offset {} and stage offset {}", .{ size, aligned_offset, stage_offset });

        // Get a pointer to the staged data in the mapping
        const stage_ptr = @as([*]u8, @ptrCast(@alignCast(self.stage.mapped_ptr.?))) + stage_offset;

        // Update the bump pointer to the end of the allocation in the heap
        self.bump = end_offset;

        // Allocate memory for our local data copy
        const data = try self.allocation_memory.allocator().alloc(u8, size);
        @memset(data, 0); // Initialize to zeros

        // Copy the initial zeros to the data buffer
        @memcpy(data, temp_buffer);

        // Create the allocation object
        const allocation = try self.allocation_memory.allocator().create(Allocation);
        allocation.* = Allocation{
            .stage_ptr = stage_ptr,
            .size = size,
            .heap_offset = aligned_offset,
            .allocator = self,
            .epoch = self.current_epoch,
            .stage_offset = stage_offset,
            .data = data,
            .mutex = std.Thread.Mutex{},
            .staged = true,
            .mapped = false,
        };

        // Add to staged allocations list
        try self.staged_allocations.append(allocation);

        return allocation;
    }

    pub fn flushAllStaged(self: *Allocator) !void {
        // Lock the mutex for thread safety
        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if we have any staged allocations
        if (self.staged_allocations.items.len == 0) {
            logger.info("No staged allocations to flush", .{});
            return;
        }

        logger.info("Flushing {} staged allocations to GPU...", .{self.staged_allocations.items.len});

        // Log the staged allocations for debugging
        for (self.staged_allocations.items) |allocation| {
            logger.info("Staged allocation: offset={}, size={}, heap_offset={}", .{
                allocation.stage_offset,
                allocation.size,
                allocation.heap_offset,
            });
        }

        // Make sure memory is mapped before flushing
        if (self.stage.mapped_ptr == null) {
            try self.stage.mapMemory();
        }

        // Actually flush the data to the GPU
        try self.flush();

        // Clear the staged allocations list
        self.staged_allocations.clearRetainingCapacity();

        logger.info("All staged allocations flushed to GPU", .{});
    }
};
