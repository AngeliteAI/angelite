const std = @import("std");
const vk = @import("vk.zig");
const heap = @import("heap.zig");
const stage = @import("stage.zig");
const math = @import("math");
const alloc = @import("alloc.zig");

// GPU-compatible camera data - always written to position 0 in the heap
pub const GpuCameraData = extern struct {
    viewProjection: math.Mat4,
};

// Push constant structure for bindless camera access
pub const CameraPushConstants = struct {
    // Device address of the heap buffer (64-bit GPU pointer)
    heap_address: u64,
    // Additional parameters can be added here
    camera_offset: u64,
};

// Camera system that uses the renderer's heap and stage
pub const RendererCamera = struct {
    device: vk.Device,
    renderer_heap: *heap.Heap, // Pointer to renderer's heap
    renderer_stage: *stage.Stage, // Pointer to renderer's stage
    camera_data: GpuCameraData,
    allocator: *alloc.Allocator,
    std_allocator: *std.mem.Allocator,
    camera_allocation: ?*alloc.Allocation = null,

    // Create the camera system using the renderer's heap and stage
    pub fn create(
        device: vk.Device,
        renderer_heap: *heap.Heap,
        renderer_stage: *stage.Stage,
        allocator: *alloc.Allocator,
        std_allocator: *std.mem.Allocator,
    ) !*RendererCamera {
        // Initialize camera data at position (0,0,0)
        const initial_camera = GpuCameraData{
            .viewProjection = math.m4Id(),
        };

        const self = try std_allocator.create(RendererCamera);
        self.* = .{
            .device = device,
            .renderer_heap = renderer_heap,
            .renderer_stage = renderer_stage,
            .camera_data = initial_camera,
            .allocator = allocator,
            .std_allocator = std_allocator,
        };

        // Create the camera allocation
        self.camera_allocation = try allocator.alloc(@sizeOf(GpuCameraData), 16);
        if (self.camera_allocation) |allocation| {
            // Write initial camera data
            _ = try allocation.write(std.mem.asBytes(&initial_camera));
            // Flush to GPU
            try allocation.flush();
        }

        return self;
    }

    // Update the camera data (writes to position 0 in the heap)
    pub fn update(self: *RendererCamera, view: math.Mat4, projection: math.Mat4) !void {
        std.debug.print("Camera update called with view: {any}, projection: {any}\n", .{ view, projection });

        // Update the camera data with explicit view-projection matrix
        const viewProj = math.m4Mul(projection, view);
        std.debug.print("Computed view-projection matrix: {any}\n", .{viewProj});

        self.camera_data = GpuCameraData{
            .viewProjection = viewProj,
        };

        // Print the size of GpuCameraData to verify correct structure size
        std.debug.print("Size of GpuCameraData: {} bytes\n", .{@sizeOf(GpuCameraData)});

        // Log the viewProjection matrix to debug in column-major format (how Zig stores it)
        std.debug.print("\nCamera data viewProjection matrix (column-major, same as data[]):\n", .{});
        const m = self.camera_data.viewProjection.data;
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{ m[0], m[1], m[2], m[3] });
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{ m[4], m[5], m[6], m[7] });
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{ m[8], m[9], m[10], m[11] });
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{ m[12], m[13], m[14], m[15] });

        // Also show how the shader will view this matrix (row-major when used)
        std.debug.print("\nMatrix as seen in shader (row-major access):\n", .{});
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{ m[0], m[4], m[8], m[12] });
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{ m[1], m[5], m[9], m[13] });
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{ m[2], m[6], m[10], m[14] });
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{ m[3], m[7], m[11], m[15] });

        // Display projection and view separately to help with debugging
        std.debug.print("\nInput matrices:\n", .{});
        std.debug.print("Projection matrix:\n{any}\n", .{projection});
        std.debug.print("View matrix:\n{any}\n", .{view});

        // Write the camera data to the allocation and flush it in a single operation
        if (self.camera_allocation) |allocation| {
            // Lock the mutex for thread safety
            // Write the data
            if (std.mem.asBytes(&self.camera_data).len > allocation.size) {
                return error.BufferTooSmall;
            }

            // Map memory if not already mapped
            try self.allocator.stage.mapMemory();

            // Copy data to the mapped memory
            _ = try allocation.write(std.mem.asBytes(&self.camera_data));

            // Mark the allocation as staged
            allocation.staged = true;

            // Flush all staged allocations to GPU
            try self.allocator.flushAllStaged();

            std.debug.print("Camera data updated and flushed to GPU\n", .{});
        } else {
            return error.NoCameraAllocation;
        }
    }

    // Get the device address of the camera data
    pub fn getDeviceAddress(self: *RendererCamera) !u64 {
        if (self.camera_allocation) |allocation| {
            return try allocation.deviceAddress();
        } else {
            return error.NoCameraAllocation;
        }
    }

    // Clean up resources
    pub fn destroy(self: *RendererCamera) void {
        // Clean up camera allocation if it exists
        if (self.camera_allocation != null) {
            // We don't need to explicitly deallocate the allocation
            // as it will be cleaned up when the allocator is reset
            self.camera_allocation = null;
        }

        // Only free our own memory, not the renderer's resources
        self.std_allocator.destroy(self);
    }
};
