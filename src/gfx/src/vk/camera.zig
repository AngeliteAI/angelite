const std = @import("std");
const vk = @import("vk.zig");
const heap = @import("heap.zig");
const stage = @import("stage.zig");
const math = @import("math");
const task = @import("task.zig");

// GPU-compatible camera data - always written to position 0 in the heap
pub const GpuCameraData = extern struct {
    viewProjection: math.Mat4,
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
    heap_resource: ?*task.Resource = null, // Store the heap resource to ensure proper lifetime
    last_upload_offset: usize = 0, // Track the last upload offset to ensure proper copy

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
    pub fn update(self: *RendererCamera, view: math.Mat4, projection: math.Mat4) !usize {
        std.debug.print("Camera update called with view: {any}, projection: {any}\n", .{view, projection});

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
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{m[0], m[1], m[2], m[3]});
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{m[4], m[5], m[6], m[7]});
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{m[8], m[9], m[10], m[11]});
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{m[12], m[13], m[14], m[15]});

        // Also show how the shader will view this matrix (row-major when used)
        std.debug.print("\nMatrix as seen in shader (row-major access):\n", .{});
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{m[0], m[4], m[8], m[12]});
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{m[1], m[5], m[9], m[13]});
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{m[2], m[6], m[10], m[14]});
        std.debug.print("[ {d:9.6}, {d:9.6}, {d:9.6}, {d:9.6} ]\n", .{m[3], m[7], m[11], m[15]});

        // Display projection and view separately to help with debugging
        std.debug.print("\nInput matrices:\n", .{});
        std.debug.print("Projection matrix:\n{any}\n", .{projection});
        std.debug.print("View matrix:\n{any}\n", .{view});

        // Safely upload the camera data - first validate the size
        const camera_bytes = std.mem.asBytes(&self.camera_data);
        std.debug.print("Camera data size for upload: {} bytes\n", .{camera_bytes.len});

        // Additional safety checks
        if (camera_bytes.len != @sizeOf(GpuCameraData) or camera_bytes.len > 1024) {
            std.debug.print("ERROR: Unexpected camera data size!\n", .{});
            return error.InvalidCameraDataSize;
        }

        // Upload with explicit safety guarantees
        const offset = try self.renderer_stage.queueUpload(camera_bytes);

        // Validate the offset before storing
        if (offset > 1024 * 1024) { // Sanity check - should be well under 1MB
            std.debug.print("ERROR: Implausible staging offset: {}\n", .{offset});
            return error.InvalidStagingOffset;
        }

        // Store the validated offset for later use
        self.last_upload_offset = offset;
        std.debug.print("Camera data queued at offset: {} (VALIDATED)\n", .{offset});

        // Flush the uploads to ensure data is in the staging buffer
        // The camera_pass will handle copying from staging buffer to heap
        try self.renderer_stage.flushUploads(true);

        std.debug.print("Camera data updated and queued for transfer\n", .{});
        return offset;
    }

    // Create a task pass for updating the camera in the task graph
    pub fn createCameraPass(self: *RendererCamera, name: []const u8) !*task.Pass {
        // Ensure the heap buffer is valid before proceeding
        const heap_buffer = self.renderer_heap.getBuffer();
        std.debug.print("Heap buffer for camera: {any}\n", .{heap_buffer});

        // Initialize the heap resource if it hasn't been created yet
        if (self.heap_resource == null) {
            std.debug.print("Creating new heap resource for camera\n", .{});
            self.heap_resource = try task.Resource.init(
                self.allocator,
                "CameraHeapTarget",
                task.ResourceType.Buffer,
                heap_buffer
            );
        }

        // Verify the resource is valid
        if (self.heap_resource.?.handle == null or
            (self.heap_resource.?.handle != null and self.heap_resource.?.handle.?.buffer == null)) {
            std.debug.print("ERROR: Heap resource handle is invalid!\n", .{});
            // Try to recreate it
            self.heap_resource.?.deinit(&self.allocator);
            self.heap_resource = try task.Resource.init(
                self.allocator,
                "CameraHeapTarget",
                task.ResourceType.Buffer,
                heap_buffer
            );
        }

        // Get the heap buffer and create a direct buffer copy pass
        // This approach completely avoids using the stage.target field which is being corrupted

        // Create the pass using our fixed buffer copy pass function
        const size = @sizeOf(GpuCameraData);
        
        // Debug: Verify the exact size of GpuCameraData (should be 64 bytes for 16 floats)
        std.debug.print("Creating camera pass: data size is {} bytes, offset: {}\n",
                      .{size, self.last_upload_offset});
        
        // Print memory layout of the first few bytes for debugging
        const camera_bytes = std.mem.asBytes(&self.camera_data);
        if (camera_bytes.len >= 16) {
            std.debug.print("First 16 bytes: {} {} {} {}\n", 
                .{camera_bytes[0], camera_bytes[1], camera_bytes[2], camera_bytes[3]});
            std.debug.print("Last 16 bytes: {} {} {} {}\n", 
                .{camera_bytes[size-4], camera_bytes[size-3], camera_bytes[size-2], camera_bytes[size-1]});
        }
        
        // Ensure buffer alignment is correct and we're copying the entire matrix
        return self.renderer_stage.createBufferCopyPass(
            name,
            self.heap_resource.?, // Use the stored resource (non-optional here)
            self.last_upload_offset,  // Source offset in staging buffer
            size, // Size of entire data structure
        );
    }

    // Copy the camera data using a command buffer (for immediate updates)
    pub fn copyToHeap(self: *RendererCamera, cmd: vk.CommandBuffer) !void {
        const size = @sizeOf(GpuCameraData);
        std.debug.print("Copying camera data: {} bytes from offset {} to heap\n", .{size, self.last_upload_offset});
        try self.renderer_stage.copyToTarget(cmd, self.last_upload_offset, size);
    }

    // Update an existing camera pass with the latest upload offset
    pub fn updateCameraPass(self: *RendererCamera, pass: *task.Pass) void {
        if (pass.userData == null) {
            std.debug.print("Warning: Camera pass has no userData to update\n", .{});
            return;
        }

        // The pass userData is a BufferCopyData struct from stage.zig
        // Import it to ensure we're using the exact same type
        const BufferCopyData = stage.Stage.BufferCopyData;

        // Update the source offset to the latest upload offset
        const data = @as(*BufferCopyData, @ptrCast(@alignCast(pass.userData)));
        std.debug.print("Updating camera pass source offset from {} to {}\n", .{data.offset, self.last_upload_offset});
        data.offset = self.last_upload_offset;
    }

    // Clean up resources - doesn't destroy heap or stage since those belong to the renderer
    pub fn destroy(self: *RendererCamera) void {
        // Clean up heap resource if it exists
        if (self.heap_resource != null) {
            self.heap_resource.?.deinit(&self.allocator);
            self.heap_resource = null;
        }

        // Only free our own memory, not the renderer's resources
        self.allocator.destroy(self);
    }
};
