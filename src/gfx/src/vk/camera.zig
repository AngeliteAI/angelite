const std = @import("std");
const vk = @import("vk.zig");
const heap = @import("heap.zig");
const stage = @import("stage.zig");
const math = @import("math");
const task = @import("task.zig");

// GPU-compatible camera data - always written to position 0 in the heap
pub const GpuCameraData = struct {
    viewProjection: math.Mat4,
    position: math.Vec3,
    padding: f32 = 0.0, // For alignment
};

// Push constant structure for bindless camera access
pub const CameraPushConstants = struct {
    // Device address of the heap buffer (64-bit GPU pointer)
    heap_address: u64,
    // Additional parameters can be added here
    model_matrix: math.Mat4 = math.m4Id(),
};

// Camera system that uses the renderer's heap and stage
pub const RendererCamera = struct {
    device: vk.Device,
    renderer_heap: *heap.Heap,  // Pointer to renderer's heap
    renderer_stage: *stage.Stage, // Pointer to renderer's stage
    camera_data: GpuCameraData,
    allocator: std.mem.Allocator,

    // Create the camera system using the renderer's heap and stage
    pub fn create(
        device: vk.Device,
        renderer_heap: *heap.Heap,
        renderer_stage: *stage.Stage,
        allocator: std.mem.Allocator,
    ) !*RendererCamera {
        // Initialize camera data at position (0,0,0)
        const initial_camera = GpuCameraData{
            .viewProjection = math.m4Id(),
            .position = math.v3Zero(), // Position 0
            .padding = 0.0,
        };

        const self = try allocator.create(RendererCamera);
        self.* = .{
            .device = device,
            .renderer_heap = renderer_heap,
            .renderer_stage = renderer_stage,
            .camera_data = initial_camera,
            .allocator = allocator,
        };

        return self;
    }

    // Update the camera data (writes to position 0 in the heap)
    pub fn update(self: *RendererCamera, position: math.Vec3, view: math.Mat4, projection: math.Mat4) !usize {
        // Update the camera data
        self.camera_data = GpuCameraData{
            .viewProjection = math.m4Mul(projection, view),
            .position = position,
            .padding = 0.0,
        };

        // Upload the camera data to the renderer's staging buffer at position 0
        const offset = try self.renderer_stage.queueUpload(std.mem.asBytes(&self.camera_data));
        try self.renderer_stage.flushUploads();

        return offset;
    }

    // Create a task pass for updating the camera in the task graph
    pub fn createCameraPass(self: *RendererCamera, name: []const u8) !*task.Pass {
        // Create the pass for updating the camera data (at position 0)
        return self.renderer_stage.createBufferCopyPass(
            name,
            null, // Use the built-in resource for the target
            0,    // Source offset in staging buffer
            @sizeOf(GpuCameraData), // Size of data
        );
    }

    // Copy the camera data using a command buffer (for immediate updates)
    pub fn copyToHeap(self: *RendererCamera, cmd: vk.CommandBuffer) !void {
        try self.renderer_stage.copyToTarget(cmd, 0, @sizeOf(GpuCameraData));
    }

    // Clean up resources - doesn't destroy heap or stage since those belong to the renderer
    pub fn destroy(self: *RendererCamera) void {
        // Only free our own memory, not the renderer's resources
        self.allocator.destroy(self);
    }
};
