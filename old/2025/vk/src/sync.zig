const std = @import("std");
const raw = @import("raw.zig");
const errors = @import("errors.zig");

/// Fence abstraction with utility functions
pub const Fence = struct {
    handle: raw.Fence,
    device: raw.Device,
    signaled: bool,

    /// Create a new fence
    pub fn create(device: raw.Device, signaled: bool) errors.Error!Fence {
        const create_info = raw.FenceCreateInfo{
            .sType = raw.sTy(.FenceCreateInfo),
            .pNext = null,
            .flags = if (signaled) raw.SIGNALED else 0,
        };

        var handle: raw.Fence = undefined;
        const result = raw.createFence(device, &create_info, null, &handle);
        try errors.checkResult(result);

        return Fence{
            .handle = handle,
            .device = device,
            .signaled = signaled,
        };
    }

    /// Destroy the fence
    pub fn destroy(self: *Fence) void {
        raw.destroyFence(self.device, self.handle, null);
        self.* = undefined;
    }

    /// Wait for the fence to be signaled
    pub fn wait(self: *Fence, timeout: u64) errors.Error!void {
        const result = raw.waitForFences(self.device, 1, &self.handle, raw.TRUE, timeout);
        try errors.checkResult(result);
        self.signaled = true;
    }

    /// Reset the fence to the unsignaled state
    pub fn reset(self: *Fence) errors.Error!void {
        const result = raw.resetFences(self.device, 1, &self.handle);
        try errors.checkResult(result);
        self.signaled = false;
    }

    /// Get the raw fence handle
    pub fn getHandle(self: Fence) raw.Fence {
        return self.handle;
    }

    /// Check if the fence is in the signaled state
    pub fn isSignaled(self: Fence) bool {
        return self.signaled;
    }
};

/// Semaphore abstraction with utility functions
pub const Semaphore = struct {
    handle: raw.Semaphore,
    device: raw.Device,

    /// Create a new semaphore
    pub fn create(device: raw.Device) errors.Error!Semaphore {
        const create_info = raw.SemaphoreCreateInfo{
            .sType = raw.sTy(.SemaphoreCreateInfo),
            .pNext = null,
            .flags = 0,
        };

        var handle: raw.Semaphore = undefined;
        const result = raw.createSemaphore(device, &create_info, null, &handle);
        try errors.checkResult(result);

        return Semaphore{
            .handle = handle,
            .device = device,
        };
    }

    /// Destroy the semaphore
    pub fn destroy(self: *Semaphore) void {
        raw.destroySemaphore(self.device, self.handle, null);
        self.* = undefined;
    }

    /// Get the raw semaphore handle
    pub fn getHandle(self: Semaphore) raw.Semaphore {
        return self.handle;
    }
};

/// Helper to create multiple synchronized objects at once
pub const SyncObjectsPool = struct {
    image_available_semaphores: []Semaphore,
    render_finished_semaphores: []Semaphore,
    in_flight_fences: []Fence,
    device: raw.Device,
    allocator: std.mem.Allocator,

    /// Create a pool of synchronization objects for rendering
    pub fn create(allocator: std.mem.Allocator, device: raw.Device, count: usize) errors.Error!SyncObjectsPool {
        var image_available_semaphores = try allocator.alloc(Semaphore, count);
        errdefer allocator.free(image_available_semaphores);

        var render_finished_semaphores = try allocator.alloc(Semaphore, count);
        errdefer allocator.free(render_finished_semaphores);

        var in_flight_fences = try allocator.alloc(Fence, count);
        errdefer allocator.free(in_flight_fences);

        var i: usize = 0;
        errdefer {
            while (i > 0) : (i -= 1) {
                image_available_semaphores[i - 1].destroy();
                render_finished_semaphores[i - 1].destroy();
                in_flight_fences[i - 1].destroy();
            }
        }

        while (i < count) : (i += 1) {
            image_available_semaphores[i] = try Semaphore.create(device);
            render_finished_semaphores[i] = try Semaphore.create(device);
            in_flight_fences[i] = try Fence.create(device, true);
        }

        return SyncObjectsPool{
            .image_available_semaphores = image_available_semaphores,
            .render_finished_semaphores = render_finished_semaphores,
            .in_flight_fences = in_flight_fences,
            .device = device,
            .allocator = allocator,
        };
    }

    /// Destroy all synchronization objects in the pool
    pub fn destroy(self: *SyncObjectsPool) void {
        for (self.image_available_semaphores) |*semaphore| {
            semaphore.destroy();
        }

        for (self.render_finished_semaphores) |*semaphore| {
            semaphore.destroy();
        }

        for (self.in_flight_fences) |*fence| {
            fence.destroy();
        }

        self.allocator.free(self.image_available_semaphores);
        self.allocator.free(self.render_finished_semaphores);
        self.allocator.free(self.in_flight_fences);

        self.* = undefined;
    }

    /// Get synchronization objects for a specific frame
    pub fn getSyncObjectsForFrame(self: SyncObjectsPool, frame_index: usize) struct {
        image_available: *Semaphore,
        render_finished: *Semaphore,
        in_flight: *Fence,
    } {
        const index = frame_index % self.image_available_semaphores.len;
        return .{
            .image_available = &self.image_available_semaphores[index],
            .render_finished = &self.render_finished_semaphores[index],
            .in_flight = &self.in_flight_fences[index],
        };
    }
};
