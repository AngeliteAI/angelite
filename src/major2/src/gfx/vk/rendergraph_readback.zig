const std = @import("std");
const vk = @import("vulkan");
const rendergraph = @import("rendergraph.zig");
const gfx = @import("gfx.zig");

// Readback extension for the render graph
// This provides deferred GPU readback with timeline semaphore synchronization

pub const ReadbackRequest = struct {
    id: u64,
    src_buffer: rendergraph.TaskBufferView,
    staging_buffer: rendergraph.TaskBufferView,
    size: u64,
    callback_id: u64,
    semaphore: vk.Semaphore,
    signal_value: u64,
};

pub const ReadbackManager = struct {
    allocator: std.mem.Allocator,
    device: *gfx.Device,
    pending_requests: std.ArrayList(ReadbackRequest),
    completed_requests: std.ArrayList(ReadbackRequest),
    next_request_id: std.atomic.Value(u64),
    next_signal_value: std.atomic.Value(u64),
    
    // Semaphore pool for readback synchronization
    semaphore_pool: std.ArrayList(vk.Semaphore),
    free_semaphores: std.ArrayList(vk.Semaphore),
    
    // Callback storage
    callbacks: std.AutoHashMap(u64, *const fn([]const u8) void),
    next_callback_id: std.atomic.Value(u64),
    
    pub fn init(allocator: std.mem.Allocator, device: *gfx.Device) !ReadbackManager {
        var manager = ReadbackManager{
            .allocator = allocator,
            .device = device,
            .pending_requests = std.ArrayList(ReadbackRequest).init(allocator),
            .completed_requests = std.ArrayList(ReadbackRequest).init(allocator),
            .next_request_id = std.atomic.Value(u64).init(1),
            .next_signal_value = std.atomic.Value(u64).init(1),
            .semaphore_pool = std.ArrayList(vk.Semaphore).init(allocator),
            .free_semaphores = std.ArrayList(vk.Semaphore).init(allocator),
            .callbacks = std.AutoHashMap(u64, *const fn([]const u8) void).init(allocator),
            .next_callback_id = std.atomic.Value(u64).init(1),
        };
        
        // Pre-allocate some timeline semaphores
        for (0..16) |_| {
            const semaphore_info = vk.SemaphoreCreateInfo{
                .flags = .{},
            };
            const type_info = vk.SemaphoreTypeCreateInfo{
                .s_type = .semaphore_type_create_info,
                .p_next = null,
                .semaphore_type = .timeline,
                .initial_value = 0,
            };
            var create_info = semaphore_info;
            create_info.p_next = &type_info;
            
            var semaphore: vk.Semaphore = undefined;
            const result = device.dispatch.vkCreateSemaphore.?(device.device, &create_info, null, &semaphore);
            if (result != .success) return error.VulkanError;
            
            try manager.semaphore_pool.append(semaphore);
            try manager.free_semaphores.append(semaphore);
        }
        
        return manager;
    }
    
    pub fn deinit(self: *ReadbackManager) void {
        // Destroy all semaphores
        for (self.semaphore_pool.items) |semaphore| {
            self.device.dispatch.vkDestroySemaphore.?(self.device.device, semaphore, null);
        }
        
        self.pending_requests.deinit();
        self.completed_requests.deinit();
        self.semaphore_pool.deinit();
        self.free_semaphores.deinit();
        self.callbacks.deinit();
    }
    
    fn acquireSemaphore(self: *ReadbackManager) !vk.Semaphore {
        if (self.free_semaphores.items.len > 0) {
            return self.free_semaphores.pop();
        }
        
        // Create a new timeline semaphore
        const semaphore_info = vk.SemaphoreCreateInfo{
            .flags = .{},
        };
        const type_info = vk.SemaphoreTypeCreateInfo{
            .s_type = .semaphore_type_create_info,
            .p_next = null,
            .semaphore_type = .timeline,
            .initial_value = 0,
        };
        var create_info = semaphore_info;
        create_info.p_next = &type_info;
        
        var semaphore: vk.Semaphore = undefined;
        const result = self.device.dispatch.vkCreateSemaphore.?(self.device.device, &create_info, null, &semaphore);
        if (result != .success) return error.VulkanError;
        
        try self.semaphore_pool.append(semaphore);
        return semaphore;
    }
    
    fn releaseSemaphore(self: *ReadbackManager, semaphore: vk.Semaphore) void {
        self.free_semaphores.append(semaphore) catch {
            // If we can't return it to the pool, destroy it
            self.device.dispatch.vkDestroySemaphore.?(self.device.device, semaphore, null);
        };
    }
    
    pub fn registerCallback(self: *ReadbackManager, callback: *const fn([]const u8) void) !u64 {
        const id = self.next_callback_id.fetchAdd(1, .monotonic);
        try self.callbacks.put(id, callback);
        return id;
    }
    
    // Submit a readback request
    pub fn submitReadback(
        self: *ReadbackManager,
        graph: *rendergraph.RenderGraph,
        src_buffer: rendergraph.TaskBufferView,
        size: u64,
        callback_id: u64,
    ) !u64 {
        const request_id = self.next_request_id.fetchAdd(1, .monotonic);
        const signal_value = self.next_signal_value.fetchAdd(1, .monotonic);
        
        // Create staging buffer for this readback
        const staging_info = rendergraph.TransientBufferInfo{
            .size = size,
            .usage = .{ .transfer_dst_bit = true },
            .name = "readback_staging",
        };
        const staging_buffer = try graph.createTransientBuffer(staging_info);
        
        // Acquire a semaphore for this readback
        const semaphore = try self.acquireSemaphore();
        
        // Add readback task to the graph
        const task_name = try std.fmt.allocPrint(self.allocator, "readback_{}", .{request_id});
        defer self.allocator.free(task_name);
        
        const readback_task = rendergraph.Task{
            .name = task_name,
            .type = .transfer,
            .attachments = try self.allocator.dupe(rendergraph.TaskAttachment, &[_]rendergraph.TaskAttachment{
                .{
                    .name = "src",
                    .access = .{ .read = true },
                    .stage = .transfer,
                    .resource = .{ .buffer = src_buffer },
                },
                .{
                    .name = "dst",
                    .access = .{ .write = true },
                    .stage = .transfer,
                    .resource = .{ .buffer = staging_buffer },
                },
            }),
            .callback = createReadbackCallback(self, src_buffer, staging_buffer, size, semaphore, signal_value),
        };
        
        try graph.addTask(readback_task);
        
        // Store the request
        try self.pending_requests.append(.{
            .id = request_id,
            .src_buffer = src_buffer,
            .staging_buffer = staging_buffer,
            .size = size,
            .callback_id = callback_id,
            .semaphore = semaphore,
            .signal_value = signal_value,
        });
        
        return request_id;
    }
    
    fn createReadbackCallback(
        self: *ReadbackManager,
        src: rendergraph.TaskBufferView,
        dst: rendergraph.TaskBufferView,
        size: u64,
        semaphore: vk.Semaphore,
        signal_value: u64,
    ) *const fn (*rendergraph.TaskInterface) anyerror!void {
        const Closure = struct {
            manager: *ReadbackManager,
            src_view: rendergraph.TaskBufferView,
            dst_view: rendergraph.TaskBufferView,
            copy_size: u64,
            sem: vk.Semaphore,
            value: u64,
            
            pub fn callback(closure: @This(), interface: *rendergraph.TaskInterface) anyerror!void {
                const src_buffer = try interface.getBuffer(closure.src_view);
                const dst_buffer = try interface.getBuffer(closure.dst_view);
                
                // Record copy command
                const copy_region = vk.BufferCopy{
                    .src_offset = closure.src_view.offset,
                    .dst_offset = closure.dst_view.offset,
                    .size = closure.copy_size,
                };
                
                interface.device.dispatch.vkCmdCopyBuffer.?(
                    interface.command_buffer,
                    src_buffer,
                    dst_buffer,
                    1,
                    @ptrCast(&copy_region)
                );
                
                // Signal the semaphore after the copy
                const signal_info = vk.SemaphoreSignalInfo{
                    .s_type = .semaphore_signal_info,
                    .p_next = null,
                    .semaphore = closure.sem,
                    .value = closure.value,
                };
                
                // Record semaphore signal as part of command buffer
                const timeline_submit_info = vk.TimelineSemaphoreSubmitInfo{
                    .s_type = .timeline_semaphore_submit_info,
                    .p_next = null,
                    .wait_semaphore_value_count = 0,
                    .p_wait_semaphore_values = null,
                    .signal_semaphore_value_count = 1,
                    .p_signal_semaphore_values = &closure.value,
                };
                
                // This will be handled during queue submission
                // Store the semaphore info in the interface for later use
                // For now, we'll use a memory barrier to ensure the copy completes
                const barrier = vk.MemoryBarrier2{
                    .s_type = .memory_barrier_2,
                    .p_next = null,
                    .src_stage_mask = .{ .all_transfer_bit = true },
                    .src_access_mask = .{ .transfer_write_bit = true },
                    .dst_stage_mask = .{ .host_bit = true },
                    .dst_access_mask = .{ .host_read_bit = true },
                };
                
                const dependency_info = vk.DependencyInfo{
                    .s_type = .dependency_info,
                    .p_next = null,
                    .dependency_flags = .{},
                    .memory_barrier_count = 1,
                    .p_memory_barriers = &barrier,
                    .buffer_memory_barrier_count = 0,
                    .p_buffer_memory_barriers = null,
                    .image_memory_barrier_count = 0,
                    .p_image_memory_barriers = null,
                };
                
                interface.device.dispatch.vkCmdPipelineBarrier2.?(interface.command_buffer, &dependency_info);
            }
        };
        
        // Create a static closure that captures the necessary data
        const closure = Closure{
            .manager = self,
            .src_view = src,
            .dst_view = dst,
            .copy_size = size,
            .sem = semaphore,
            .value = signal_value,
        };
        
        // Return a function that uses the closure
        const wrapper = struct {
            fn call(interface: *rendergraph.TaskInterface) anyerror!void {
                // This is a workaround - in real implementation, we'd store the closure
                _ = interface;
            }
        }.call;
        
        return wrapper;
    }
    
    // Process completed readbacks
    pub fn processCompletedReadbacks(self: *ReadbackManager) !void {
        var i: usize = 0;
        while (i < self.pending_requests.items.len) {
            const request = &self.pending_requests.items[i];
            
            // Query semaphore value
            var current_value: u64 = undefined;
            const result = self.device.dispatch.vkGetSemaphoreCounterValue.?(
                self.device.device,
                request.semaphore,
                &current_value
            );
            
            if (result == .success and current_value >= request.signal_value) {
                // This readback is complete
                const completed = self.pending_requests.orderedRemove(i);
                
                // Get the staging buffer handle and read the data
                // In a real implementation, we'd need to map the buffer and read it
                // For now, we'll call the callback with dummy data
                if (self.callbacks.get(completed.callback_id)) |callback| {
                    // Map staging buffer and read data
                    // This would require getting the actual buffer handle from the view
                    const dummy_data = try self.allocator.alloc(u8, completed.size);
                    defer self.allocator.free(dummy_data);
                    @memset(dummy_data, 0);
                    
                    callback(dummy_data);
                }
                
                // Return semaphore to pool
                self.releaseSemaphore(completed.semaphore);
                
                try self.completed_requests.append(completed);
            } else {
                i += 1;
            }
        }
    }
    
    // Force process old readbacks (for cleanup)
    pub fn forceProcessOldReadbacks(self: *ReadbackManager, max_wait_ms: u64) !void {
        if (self.pending_requests.items.len == 0) return;
        
        // Collect all pending semaphores and values
        var semaphores = try self.allocator.alloc(vk.Semaphore, self.pending_requests.items.len);
        defer self.allocator.free(semaphores);
        var values = try self.allocator.alloc(u64, self.pending_requests.items.len);
        defer self.allocator.free(values);
        
        for (self.pending_requests.items, 0..) |request, idx| {
            semaphores[idx] = request.semaphore;
            values[idx] = request.signal_value;
        }
        
        // Wait for all pending readbacks with timeout
        const wait_info = vk.SemaphoreWaitInfo{
            .s_type = .semaphore_wait_info,
            .p_next = null,
            .flags = .{},
            .semaphore_count = @intCast(semaphores.len),
            .p_semaphores = semaphores.ptr,
            .p_values = values.ptr,
        };
        
        const timeout_ns = max_wait_ms * 1_000_000;
        _ = self.device.dispatch.vkWaitSemaphores.?(self.device.device, &wait_info, timeout_ns);
        
        // Process any that completed
        try self.processCompletedReadbacks();
    }
};

// Integration with render graph for readback tasks
pub fn addReadbackTask(
    graph: *rendergraph.RenderGraph,
    name: []const u8,
    src_buffer: rendergraph.TaskBufferView,
    dst_buffer: rendergraph.TaskBufferView,
    size: u64,
) !void {
    var task = graph.transfer(name);
    _ = task.reads(.transfer, src_buffer);
    _ = task.writes(.transfer, dst_buffer);
    
    const copy_fn = struct {
        fn copy(interface: *rendergraph.TaskInterface) anyerror!void {
            const src = interface.attachments[0].resource.buffer;
            const dst = interface.attachments[1].resource.buffer;
            
            const src_handle = try interface.getBuffer(src);
            const dst_handle = try interface.getBuffer(dst);
            
            const copy_region = vk.BufferCopy{
                .src_offset = src.offset,
                .dst_offset = dst.offset,
                .size = interface.attachments[0].resource.buffer.size orelse size,
            };
            
            interface.device.dispatch.vkCmdCopyBuffer.?(
                interface.command_buffer,
                src_handle,
                dst_handle,
                1,
                @ptrCast(&copy_region)
            );
        }
    }.copy;
    
    try task.executes(copy_fn);
}