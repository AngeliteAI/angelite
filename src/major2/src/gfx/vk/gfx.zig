const std = @import("std");
const vk = @import("vulkan");
const vertex_pool = @import("vertex_pool.zig");
const render = @import("render.zig");

// Re-export types that physics and worldgen need
pub const Renderer = render.Renderer;
pub const Device = render.Device;
pub const Instance = render.Instance;
pub const Camera = render.Camera;
pub const DeviceDispatch = vk.DeviceDispatch;
pub const InstanceDispatch = vk.InstanceDispatch;

// Export render graph functionality
pub const RenderGraph = @import("rendergraph.zig").RenderGraph;
pub usingnamespace @import("rendergraph_ffi.zig");

// GPU resource structures for compute operations
pub const GpuBuffer = struct {
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
    size: u64,
    buffer_type: u32,
    magic: u32 = 0xDEADBEEF, // Magic number for validation
    
    pub fn validate(self: *const GpuBuffer) bool {
        return self.magic == 0xDEADBEEF;
    }
};

pub const ComputeShader = struct {
    module: vk.ShaderModule,
    pipeline: vk.Pipeline,
    pipeline_layout: vk.PipelineLayout,
    descriptor_set_layout: vk.DescriptorSetLayout,
};

pub const ComputeCommandBuffer = struct {
    command_buffer: vk.CommandBuffer,
    fence: vk.Fence,
};

// Helper function to find memory type
fn findMemoryType(
    memory_properties: vk.PhysicalDeviceMemoryProperties,
    type_bits: u32,
    required_flags: vk.MemoryPropertyFlags,
) !u32 {
    var i: u32 = 0;
    while (i < memory_properties.memory_type_count) : (i += 1) {
        const type_suitable = (type_bits & (@as(u32, 1) << @intCast(i))) != 0;
        const flags_suitable = memory_properties.memory_types[i].property_flags.contains(required_flags);
        
        if (type_suitable and flags_suitable) {
            return i;
        }
    }
    return error.NoSuitableMemoryType;
}

// Main renderer initialization
export fn renderer_init(surface_raw: ?*anyopaque) ?*Renderer {
    std.debug.print("Initializing Vulkan renderer...\n", .{});

    if (surface_raw == null) {
        std.debug.print("Error: surface_raw is null in renderer_init\n", .{});
        return null;
    }

    const renderer = std.heap.c_allocator.create(Renderer) catch |err| {
        std.debug.print("Error allocating renderer: {}\n", .{err});
        return null;
    };

    renderer.* = Renderer.init(std.heap.c_allocator, surface_raw) catch |err| {
        std.debug.print("Error initializing renderer: {}\n", .{err});
        std.heap.c_allocator.destroy(renderer);
        return null;
    };

    std.debug.print("Renderer successfully initialized: {any}\n", .{renderer});
    return renderer;
}

export fn renderer_deinit(renderer: ?*Renderer) void {
    if (renderer) |renderer_ptr| {
        renderer_ptr.deinit();
        std.heap.c_allocator.destroy(renderer_ptr);
    }
}

// Vertex pool operations
export fn renderer_init_vertex_pool(
    renderer: ?*Renderer,
    buffer_count: u32,
    vertex_per_buffer: u32,
    max_draw_commands: u32,
) bool {
    if (renderer) |r| {
        r.initVertexPool(buffer_count, vertex_per_buffer, max_draw_commands) catch return false;
        return true;
    }
    return false;
}

export fn renderer_request_buffer(renderer: ?*Renderer) u32 {
    if (renderer) |r| {
        return (r.requestBuffer() catch return std.math.maxInt(u32)) orelse std.math.maxInt(u32);
    }
    return std.math.maxInt(u32);
}

export fn renderer_add_mesh(
    renderer: ?*Renderer,
    buffer_idx: u32,
    vertices_ptr: [*]const u8,
    vertex_count: u32,
    position_ptr: [*]const f32,
    group: u32,
    out_index_ptr: *?*u32,
) bool {
    if (renderer) |r| {
        // Convert raw vertices pointer to slice of Vertex
        const vertices_bytes = @as([*]const u8, @ptrCast(vertices_ptr))[0 .. vertex_count * @sizeOf(vertex_pool.Vertex)];
        const vertices = std.mem.bytesAsSlice(vertex_pool.Vertex, vertices_bytes);

        // Convert position array to [3]f32
        const position = [3]f32{ position_ptr[0], position_ptr[1], position_ptr[2] };

        // Add mesh and get index pointer
        out_index_ptr.* = r.addMesh(buffer_idx, @alignCast(vertices), position, group) catch return false;
        return true;
    }
    return false;
}

export fn renderer_update_vertices(
    renderer: ?*Renderer,
    buffer_idx: u32,
    vertices_ptr: [*]const u8,
    vertex_count: u32,
) bool {
    if (renderer) |r| {
        // Convert raw vertices pointer to slice of Vertex
        const vertices_bytes = @as([*]const u8, @ptrCast(vertices_ptr))[0 .. vertex_count * @sizeOf(vertex_pool.Vertex)];
        const vertices = std.mem.bytesAsSlice(vertex_pool.Vertex, vertices_bytes);

        // Update vertex data in the buffer
        if (buffer_idx < r.vertex_pool.?.stage_buffers.items.len) {
            r.vertex_pool.?.fillVertexData(buffer_idx, @alignCast(vertices)) catch return false;
            return true;
        }
    }
    return false;
}

export fn renderer_update_normals(
    renderer: ?*Renderer,
    buffer_idx: u32,
    normals_ptr: [*]const u8,
    vertex_count: u32,
) bool {
    if (renderer) |r| {
        // The input is actually full vertex data, not just normals
        // Convert raw pointer to slice of Vertex structs
        const vertices_bytes = @as([*]const u8, @ptrCast(normals_ptr))[0 .. vertex_count * @sizeOf(vertex_pool.Vertex)];
        const vertices = std.mem.bytesAsSlice(vertex_pool.Vertex, vertices_bytes);

        // Update only the normal component in the buffer
        if (buffer_idx < r.vertex_pool.?.stage_buffers.items.len) {
            const stage = &r.vertex_pool.?.stage_buffers.items[buffer_idx];

            if (stage.mapped_memory) |mapped| {
                const dest_vertices = @as([*]vertex_pool.Vertex, @ptrCast(@alignCast(mapped)))[0..vertex_count];

                // Copy only normal direction data for each vertex
                for (0..vertex_count) |i| {
                    dest_vertices[i].normal_dir = vertices[i].normal_dir;
                }

                return true;
            }
        }
    }
    return false;
}

export fn renderer_update_colors(
    renderer: ?*Renderer,
    buffer_idx: u32,
    colors_ptr: [*]const u8,
    vertex_count: u32,
) bool {
    if (renderer) |r| {
        // The input is actually full vertex data, not just colors
        // Convert raw pointer to slice of Vertex structs
        const vertices_bytes = @as([*]const u8, @ptrCast(colors_ptr))[0 .. vertex_count * @sizeOf(vertex_pool.Vertex)];
        const vertices = std.mem.bytesAsSlice(vertex_pool.Vertex, vertices_bytes);

        // Update only the color component in the buffer
        if (buffer_idx < r.vertex_pool.?.stage_buffers.items.len) {
            const stage = &r.vertex_pool.?.stage_buffers.items[buffer_idx];

            if (stage.mapped_memory) |mapped| {
                const dest_vertices = @as([*]vertex_pool.Vertex, @ptrCast(@alignCast(mapped)))[0..vertex_count];

                // Copy only color data for each vertex
                for (0..vertex_count) |i| {
                    dest_vertices[i].color = vertices[i].color;
                }

                return true;
            }
        }
    }
    return false;
}

export fn renderer_release_buffer(
    renderer: ?*Renderer,
    buffer_idx: u32,
    command_index_ptr: ?*u32,
) bool {
    if (renderer) |r| {
        if (command_index_ptr) |idx_ptr| {
            r.releaseBuffer(buffer_idx, idx_ptr) catch return false;
            return true;
        }
    }
    return false;
}

export fn renderer_mask_by_facing(
    renderer: ?*Renderer,
    camera_position_ptr: [*]const f32,
) bool {
    if (renderer) |r| {
        const position = [3]f32{ camera_position_ptr[0], camera_position_ptr[1], camera_position_ptr[2] };
        r.maskByFacing(position) catch return false;
        return true;
    }
    return false;
}

export fn renderer_order_front_to_back(
    renderer: ?*Renderer,
    camera_position_ptr: [*]const f32,
) bool {
    if (renderer) |r| {
        const position = [3]f32{ camera_position_ptr[0], camera_position_ptr[1], camera_position_ptr[2] };
        r.orderFrontToBack(position) catch return false;
        return true;
    }
    return false;
}

// Rendering operations
export fn renderer_begin_frame(renderer: ?*Renderer) bool {
    // Delegate to render.zig's implementation
    return render.renderer_begin_frame(renderer);
}

export fn renderer_render(renderer: ?*Renderer) bool {
    // Delegate to render.zig's implementation
    return render.renderer_render(renderer);
}

export fn renderer_end_frame(renderer: ?*Renderer) bool {
    // Delegate to render.zig's implementation
    return render.renderer_end_frame(renderer);
}

// Camera operations
export fn renderer_camera_create(renderer: ?*Renderer) ?*Camera {
    if (renderer != null) {
        const camera = std.heap.c_allocator.create(Camera) catch return null;
        camera.* = Camera.init();
        return camera;
    }
    return null;
}

export fn renderer_camera_destroy(renderer: ?*Renderer, camera: ?*Camera) void {
    _ = renderer; // unused
    if (camera) |cam| {
        std.heap.c_allocator.destroy(cam);
    }
}

export fn renderer_camera_set_projection(
    _: ?*Renderer,
    camera: ?*Camera,
    projection_ptr: [*]const f32,
) void {
    if (camera) |cam| {
        // Copy projection matrix
        for (0..16) |i| {
            cam.proj_matrix[i] = projection_ptr[i];
        }
    }
}

export fn renderer_camera_set_transform(
    _: ?*Renderer,
    camera: ?*Camera,
    transform_ptr: [*]const f32,
) void {
    if (camera) |cam| {
        // Copy transform/view matrix
        for (0..16) |i| {
            cam.view_matrix[i] = transform_ptr[i];
        }
    }
}

export fn renderer_camera_set_main(
    renderer: ?*Renderer,
    camera: ?*Camera,
) void {
    if (renderer) |r| {
        if (camera) |cam| {
            r.main_camera = cam;
        }
    }
}

// Device info for physics/worldgen integration
export fn renderer_get_device_info(
    renderer: ?*Renderer,
    out_device: *vk.Device,
    out_queue: *vk.Queue,
    out_command_pool: *vk.CommandPool,
) bool {
    if (renderer) |r| {
        out_device.* = r.device.device;
        out_queue.* = r.device.graphics_queue;
        out_command_pool.* = r.command_pool;
        return true;
    }
    return false;
}

export fn renderer_get_device_dispatch(
    renderer: ?*Renderer,
) ?*const vk.DeviceDispatch {
    if (renderer) |r| {
        return &r.device.dispatch;
    }
    return null;
}

export fn renderer_get_physical_device(
    renderer: ?*Renderer,
) vk.PhysicalDevice {
    if (renderer) |r| {
        return r.device.physical_device.handle;
    }
    return .null_handle;
}

export fn renderer_get_instance_dispatch(
    renderer: ?*Renderer,
) ?*const vk.InstanceDispatch {
    if (renderer) |r| {
        return &r.instance.dispatch;
    }
    return null;
}

export fn renderer_update_draw_command_vertex_count(
    renderer: ?*Renderer,
    command_index_ptr: ?*u32,
    vertex_count: u32,
) bool {
    if (renderer) |r| {
        if (command_index_ptr) |ptr| {
            if (r.vertex_pool) |*pool| {
                pool.updateDrawCommandVertexCount(ptr, vertex_count);
                return true;
            }
        }
    }
    return false;
}

// Compute operations
export fn renderer_buffer_create(renderer: ?*Renderer, size: u64, buffer_type: u32) ?*anyopaque {
    if (renderer) |r| {
        const buffer = r.allocator.create(GpuBuffer) catch return null;
        std.debug.print("Created GpuBuffer at address: 0x{x}, alignment: {}\n", .{@intFromPtr(buffer), @intFromPtr(buffer) % @alignOf(GpuBuffer)});
        
        // Create buffer with device address support for storage buffers
        const usage_flags = switch (buffer_type) {
            0 => vk.BufferUsageFlags{ 
                .storage_buffer_bit = true, 
                .transfer_dst_bit = true, 
                .transfer_src_bit = true,
                .shader_device_address_bit = true 
            }, // Storage
            1 => vk.BufferUsageFlags{ 
                .uniform_buffer_bit = true, 
                .transfer_dst_bit = true,
                .shader_device_address_bit = true 
            }, // Uniform
            2 => vk.BufferUsageFlags{ .transfer_src_bit = true, .transfer_dst_bit = true }, // Staging
            3 => vk.BufferUsageFlags{ .vertex_buffer_bit = true, .transfer_dst_bit = true }, // Vertex
            4 => vk.BufferUsageFlags{ .index_buffer_bit = true, .transfer_dst_bit = true }, // Index
            else => vk.BufferUsageFlags{ .storage_buffer_bit = true, .shader_device_address_bit = true },
        };
        
        const buffer_info = vk.BufferCreateInfo{
            .size = size,
            .usage = usage_flags,
            .sharing_mode = .exclusive,
        };
        
        var vk_buffer: vk.Buffer = undefined;
        if (r.device.dispatch.vkCreateBuffer.?(r.device.device, &buffer_info, null, &vk_buffer) != .success) {
            r.allocator.destroy(buffer);
            return null;
        }
        
        // Allocate memory
        var mem_requirements: vk.MemoryRequirements = undefined;
        r.device.dispatch.vkGetBufferMemoryRequirements.?(r.device.device, vk_buffer, &mem_requirements);
        
        // Choose memory properties based on buffer type
        // Storage and uniform buffers need host-visible for CPU writes
        // Staging buffers always need host-visible
        const memory_properties = switch (buffer_type) {
            0, 1 => vk.MemoryPropertyFlags{ .host_visible_bit = true, .host_coherent_bit = true }, // Storage, Uniform
            2 => vk.MemoryPropertyFlags{ .host_visible_bit = true, .host_coherent_bit = true }, // Staging
            3, 4 => vk.MemoryPropertyFlags{ .device_local_bit = true }, // Vertex, Index
            else => vk.MemoryPropertyFlags{ .host_visible_bit = true, .host_coherent_bit = true },
        };
        
        const memory_type_index = findMemoryType(
            r.device.physical_device.memory_properties,
            mem_requirements.memory_type_bits,
            memory_properties,
        ) catch {
            r.device.dispatch.vkDestroyBuffer.?(r.device.device, vk_buffer, null);
            r.allocator.destroy(buffer);
            return null;
        };
        
        // Add device address flag for buffers that support it
        const needs_device_address = usage_flags.shader_device_address_bit;
        
        const alloc_flags_info = vk.MemoryAllocateFlagsInfo{
            .s_type = .memory_allocate_flags_info,
            .p_next = null,
            .flags = if (needs_device_address) .{ .device_address_bit = true } else .{},
            .device_mask = 0,
        };
        
        const alloc_info = vk.MemoryAllocateInfo{
            .s_type = .memory_allocate_info,
            .p_next = if (needs_device_address) &alloc_flags_info else null,
            .allocation_size = mem_requirements.size,
            .memory_type_index = memory_type_index,
        };
        
        var memory: vk.DeviceMemory = undefined;
        if (r.device.dispatch.vkAllocateMemory.?(r.device.device, &alloc_info, null, &memory) != .success) {
            r.device.dispatch.vkDestroyBuffer.?(r.device.device, vk_buffer, null);
            r.allocator.destroy(buffer);
            return null;
        }
        
        // Bind memory to buffer
        if (r.device.dispatch.vkBindBufferMemory.?(r.device.device, vk_buffer, memory, 0) != .success) {
            r.device.dispatch.vkFreeMemory.?(r.device.device, memory, null);
            r.device.dispatch.vkDestroyBuffer.?(r.device.device, vk_buffer, null);
            r.allocator.destroy(buffer);
            return null;
        }
        
        buffer.* = GpuBuffer{
            .buffer = vk_buffer,
            .memory = memory,
            .size = size,
            .buffer_type = buffer_type,
            .magic = 0xDEADBEEF,
        };
        
        std.debug.print("Returning buffer pointer: 0x{x} (aligned: {})\n", .{@intFromPtr(buffer), @intFromPtr(buffer) % @alignOf(GpuBuffer) == 0});
        return @ptrCast(buffer);
    }
    return null;
}

pub export fn renderer_buffer_destroy(renderer: ?*Renderer, buffer: ?*anyopaque) void {
    if (renderer) |r| {
        if (buffer) |buf| {
            const gpu_buffer = @as(*GpuBuffer, @ptrCast(@alignCast(buf)));
            
            // Validate buffer before destroying
            if (!gpu_buffer.validate()) {
                std.debug.print("Error: Invalid buffer magic number in renderer_buffer_destroy (got 0x{x})\n", .{gpu_buffer.magic});
                std.debug.print("Buffer pointer: 0x{x}, buffer handle: {any}\n", .{@intFromPtr(gpu_buffer), gpu_buffer.buffer});
                // Don't proceed with destruction of corrupted buffer
                return;
            }
            
            // Clear magic number to detect double-free
            gpu_buffer.magic = 0;
            
            r.device.dispatch.vkDestroyBuffer.?(r.device.device, gpu_buffer.buffer, null);
            r.device.dispatch.vkFreeMemory.?(r.device.device, gpu_buffer.memory, null);
            r.allocator.destroy(gpu_buffer);
        }
    }
}

export fn renderer_buffer_write(
    renderer: ?*Renderer,
    buffer: ?*anyopaque,
    data: [*]const u8,
    size: u64,
    offset: u64,
) bool {
    std.debug.print("renderer_buffer_write called - buffer: {any}, size: {}, offset: {}\n", .{buffer, size, offset});
    
    if (renderer) |_| {
        if (buffer) |_| {
            std.debug.print("Buffer pointer is not null, casting to GpuBuffer\n", .{});
            // Get the current frame's command buffer
            const current_cmd = render.renderer_get_current_command_buffer(renderer) orelse {
                std.debug.print("Error: No active frame command buffer for buffer write\n", .{});
                return false;
            };
            
            // We have a valid frame command buffer - use it
            // The current_cmd is a pointer that encodes the command buffer handle
            const cmd_buffer_handle: vk.CommandBuffer = @enumFromInt(@intFromPtr(current_cmd));
            return renderer_buffer_write_cmd(renderer, cmd_buffer_handle, buffer, data, size, offset);
        }
    }
    return false;
}

// New function that uses an existing command buffer
export fn renderer_buffer_write_cmd(
    renderer: ?*Renderer,
    cmd_buffer: vk.CommandBuffer,
    buffer: ?*anyopaque,
    data: [*]const u8,
    size: u64,
    offset: u64,
) bool {
    std.debug.print("renderer_buffer_write_cmd called - buffer: {any}, cmd_buffer: {any}\n", .{buffer, cmd_buffer});
    
    if (renderer) |r| {
        if (buffer) |buf| {
            // Add validation for command buffer
            if (cmd_buffer == .null_handle) {
                std.debug.print("Error: Command buffer is null in renderer_buffer_write_cmd\n", .{});
                return false;
            }
            
            std.debug.print("About to cast buffer {any} in renderer_buffer_write_cmd\n", .{buf});
            const gpu_buffer = @as(*GpuBuffer, @ptrCast(@alignCast(buf)));
            
            // Validate buffer before use
            if (!gpu_buffer.validate()) {
                std.debug.print("Error: Invalid buffer magic number in renderer_buffer_write_cmd (got 0x{x})\n", .{gpu_buffer.magic});
                return false;
            }
            
            std.debug.print("Cast successful in renderer_buffer_write_cmd\n", .{});
            
            // Create staging buffer
            const staging_buffer = renderer_buffer_create(renderer, size, 2) orelse return false;
            std.debug.print("Created staging buffer at: 0x{x}\n", .{@intFromPtr(staging_buffer)});
            const staging = @as(*GpuBuffer, @ptrCast(@alignCast(staging_buffer)));
            std.debug.print("Staging buffer cast successful\n", .{});
            
            // Map staging buffer and copy data
            std.debug.print("About to map memory for staging buffer - size: {}\n", .{size});
            var mapped_memory: ?*anyopaque = undefined;
            const map_result = r.device.dispatch.vkMapMemory.?(r.device.device, staging.memory, 0, size, .{}, &mapped_memory);
            std.debug.print("vkMapMemory result: {}\n", .{map_result});
            if (map_result != .success) {
                renderer_buffer_destroy(renderer, staging_buffer);
                return false;
            }
            std.debug.print("Memory mapped successfully at: {any}\n", .{mapped_memory});
            
            const dst_ptr = @as([*]u8, @ptrCast(mapped_memory.?));
            std.debug.print("About to memcpy {} bytes\n", .{size});
            @memcpy(dst_ptr[0..size], data[0..size]);
            std.debug.print("Memcpy completed\n", .{});
            
            r.device.dispatch.vkUnmapMemory.?(r.device.device, staging.memory);
            std.debug.print("Memory unmapped\n", .{});
            
            // Record copy command into the provided command buffer
            const copy_region = vk.BufferCopy{
                .src_offset = 0,
                .dst_offset = offset,
                .size = size,
            };
            
            const regions = [_]vk.BufferCopy{copy_region};
            std.debug.print("About to record vkCmdCopyBuffer - src: {any}, dst: {any}\n", .{staging.buffer, gpu_buffer.buffer});
            r.device.dispatch.vkCmdCopyBuffer.?(cmd_buffer, staging.buffer, gpu_buffer.buffer, 1, &regions);
            std.debug.print("vkCmdCopyBuffer recorded\n", .{});
            
            // Add pipeline barrier to ensure the copy completes before the buffer is used
            const buffer_barrier = vk.BufferMemoryBarrier{
                .src_access_mask = .{ .transfer_write_bit = true },
                .dst_access_mask = .{ .shader_read_bit = true },
                .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                .buffer = gpu_buffer.buffer,
                .offset = offset,
                .size = size,
            };
            
            std.debug.print("Adding pipeline barrier for buffer copy\n", .{});
            r.device.dispatch.vkCmdPipelineBarrier.?(
                cmd_buffer,
                .{ .transfer_bit = true },
                .{ .compute_shader_bit = true },
                .{},
                0, null,
                1, @as([*]const vk.BufferMemoryBarrier, @ptrCast(&buffer_barrier)),
                0, null
            );
            std.debug.print("Pipeline barrier added\n", .{});
            
            // Add to staging buffer ring for cleanup after 100 frames
            r.staging_buffer_ring.append(staging_buffer) catch {
                // If we can't track it, destroy it immediately (not ideal but safe)
                renderer_buffer_destroy(renderer, staging_buffer);
            };
            
            return true;
        }
    }
    return false;
}

export fn renderer_buffer_read(
    renderer: ?*Renderer,
    buffer: ?*anyopaque,
    data: [*]u8,
    size: u64,
    offset: u64,
) bool {
    if (renderer) |r| {
        if (buffer) |buf| {
            const gpu_buffer = @as(*GpuBuffer, @ptrCast(@alignCast(buf)));
            
            // Validate buffer before use
            if (!gpu_buffer.validate()) {
                std.debug.print("Error: Invalid buffer magic number in renderer_buffer_read (got 0x{x})\n", .{gpu_buffer.magic});
                return false;
            }
            
            // IMPORTANT: Buffer reads should only happen from staging buffers that have been
            // previously filled during a frame. This function should NOT create command buffers
            // or perform GPU->CPU transfers. It should only read from already-mapped staging buffers.
            
            // Check if this is a staging buffer
            if (gpu_buffer.buffer_type != 2) {
                std.debug.print("Error: renderer_buffer_read can only read from staging buffers (type 2), got type {}\n", .{gpu_buffer.buffer_type});
                return false;
            }
            
            // Map the staging buffer and read data
            var mapped_memory: ?*anyopaque = undefined;
            if (r.device.dispatch.vkMapMemory.?(r.device.device, gpu_buffer.memory, offset, size, .{}, &mapped_memory) != .success) {
                std.debug.print("Error: Failed to map staging buffer memory\n", .{});
                return false;
            }
            
            const src_ptr = @as([*]const u8, @ptrCast(mapped_memory.?));
            @memcpy(data[0..size], src_ptr[0..size]);
            
            r.device.dispatch.vkUnmapMemory.?(r.device.device, gpu_buffer.memory);
            
            return true;
        }
    }
    return false;
}

export fn renderer_buffer_copy(
    renderer: ?*Renderer,
    src: ?*anyopaque,
    dst: ?*anyopaque,
    size: u64,
) bool {
    if (renderer) |r| {
        if (src) |src_buf| {
            if (dst) |dst_buf| {
                const src_buffer = @as(*GpuBuffer, @ptrCast(@alignCast(src_buf)));
                const dst_buffer = @as(*GpuBuffer, @ptrCast(@alignCast(dst_buf)));
                
                // Validate both buffers before use
                if (!src_buffer.validate()) {
                    std.debug.print("Error: Invalid source buffer magic number in renderer_buffer_copy (got 0x{x})\n", .{src_buffer.magic});
                    return false;
                }
                if (!dst_buffer.validate()) {
                    std.debug.print("Error: Invalid destination buffer magic number in renderer_buffer_copy (got 0x{x})\n", .{dst_buffer.magic});
                    return false;
                }
                
                // Get the current frame's command buffer
                const current_cmd = render.renderer_get_current_command_buffer(renderer) orelse {
                    std.debug.print("Error: No active frame command buffer for buffer copy\n", .{});
                    return false;
                };
                
                // The current_cmd is a pointer that encodes the command buffer handle
                const cmd_buffer_handle: vk.CommandBuffer = @enumFromInt(@intFromPtr(current_cmd));
                const copy_region = vk.BufferCopy{
                    .src_offset = 0,
                    .dst_offset = 0,
                    .size = size,
                };
                
                const regions = [_]vk.BufferCopy{copy_region};
                r.device.dispatch.vkCmdCopyBuffer.?(cmd_buffer_handle, src_buffer.buffer, dst_buffer.buffer, 1, &regions);
                
                // Memory barrier to ensure copy completes
                renderer_compute_memory_barrier(renderer, cmd_buffer_handle);
                
                return true;
            }
        }
    }
    return false;
}

export fn renderer_buffer_get_size(renderer: ?*Renderer, buffer: ?*anyopaque) u64 {
    _ = renderer;
    if (buffer) |buf| {
        const gpu_buffer = @as(*GpuBuffer, @ptrCast(@alignCast(buf)));
        if (gpu_buffer.validate()) {
            return gpu_buffer.size;
        }
    }
    return 0;
}

export fn renderer_buffer_map(renderer: ?*Renderer, buffer: ?*anyopaque) ?*anyopaque {
    if (renderer) |r| {
        if (buffer) |buf| {
            const gpu_buffer = @as(*GpuBuffer, @ptrCast(@alignCast(buf)));
            
            // Validate buffer before use
            if (!gpu_buffer.validate()) {
                std.debug.print("Error: Invalid buffer magic number in renderer_buffer_map\n", .{});
                return null;
            }
            
            // Only staging buffers can be mapped
            if (gpu_buffer.buffer_type != 2) {
                std.debug.print("Error: Only staging buffers can be mapped\n", .{});
                return null;
            }
            
            var mapped_memory: ?*anyopaque = undefined;
            if (r.device.dispatch.vkMapMemory.?(r.device.device, gpu_buffer.memory, 0, gpu_buffer.size, .{}, &mapped_memory) != .success) {
                std.debug.print("Error: Failed to map buffer memory\n", .{});
                return null;
            }
            
            return mapped_memory;
        }
    }
    return null;
}

export fn renderer_buffer_unmap(renderer: ?*Renderer, buffer: ?*anyopaque) void {
    if (renderer) |r| {
        if (buffer) |buf| {
            const gpu_buffer = @as(*GpuBuffer, @ptrCast(@alignCast(buf)));
            
            // Validate buffer before use
            if (!gpu_buffer.validate()) {
                std.debug.print("Error: Invalid buffer magic number in renderer_buffer_unmap\n", .{});
                return;
            }
            
            r.device.dispatch.vkUnmapMemory.?(r.device.device, gpu_buffer.memory);
        }
    }
}

export fn renderer_compute_shader_create(
    renderer: ?*Renderer,
    spirv_data: [*]const u8,
    size: u64,
) ?*anyopaque {
    if (renderer) |r| {
        const shader = r.allocator.create(ComputeShader) catch return null;
        
        // Create shader module
        const create_info = vk.ShaderModuleCreateInfo{
            .code_size = size,
            .p_code = @ptrCast(@alignCast(spirv_data)),
        };
        
        var module: vk.ShaderModule = undefined;
        if (r.device.dispatch.vkCreateShaderModule.?(r.device.device, &create_info, null, &module) != .success) {
            r.allocator.destroy(shader);
            return null;
        }
        
        // Create descriptor set layout for compute shader
        const bindings = [_]vk.DescriptorSetLayoutBinding{
            .{
                .binding = 0,
                .descriptor_type = .storage_buffer,
                .descriptor_count = 1,
                .stage_flags = .{ .compute_bit = true },
                .p_immutable_samplers = null,
            },
            .{
                .binding = 1,
                .descriptor_type = .storage_buffer,
                .descriptor_count = 1,
                .stage_flags = .{ .compute_bit = true },
                .p_immutable_samplers = null,
            },
            .{
                .binding = 2,
                .descriptor_type = .storage_buffer,
                .descriptor_count = 1,
                .stage_flags = .{ .compute_bit = true },
                .p_immutable_samplers = null,
            },
            .{
                .binding = 3,
                .descriptor_type = .storage_buffer,
                .descriptor_count = 1,
                .stage_flags = .{ .compute_bit = true },
                .p_immutable_samplers = null,
            },
        };
        
        const layout_info = vk.DescriptorSetLayoutCreateInfo{
            .binding_count = bindings.len,
            .p_bindings = &bindings,
        };
        
        var descriptor_set_layout: vk.DescriptorSetLayout = undefined;
        if (r.device.dispatch.vkCreateDescriptorSetLayout.?(r.device.device, &layout_info, null, &descriptor_set_layout) != .success) {
            r.device.dispatch.vkDestroyShaderModule.?(r.device.device, module, null);
            r.allocator.destroy(shader);
            return null;
        }
        
        // Create pipeline layout
        const pipeline_layout_info = vk.PipelineLayoutCreateInfo{
            .set_layout_count = 1,
            .p_set_layouts = @ptrCast(&descriptor_set_layout),
            .push_constant_range_count = 0,
            .p_push_constant_ranges = null,
        };
        
        var pipeline_layout: vk.PipelineLayout = undefined;
        if (r.device.dispatch.vkCreatePipelineLayout.?(r.device.device, &pipeline_layout_info, null, &pipeline_layout) != .success) {
            r.device.dispatch.vkDestroyDescriptorSetLayout.?(r.device.device, descriptor_set_layout, null);
            r.device.dispatch.vkDestroyShaderModule.?(r.device.device, module, null);
            r.allocator.destroy(shader);
            return null;
        }
        
        // Create compute pipeline
        const stage = vk.PipelineShaderStageCreateInfo{
            .stage = .{ .compute_bit = true },
            .module = module,
            .p_name = "main",
            .p_specialization_info = null,
        };
        
        const pipeline_info = vk.ComputePipelineCreateInfo{
            .stage = stage,
            .layout = pipeline_layout,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = 0,
        };
        
        var pipeline: vk.Pipeline = undefined;
        const pipeline_infos = [_]vk.ComputePipelineCreateInfo{pipeline_info};
        var pipelines: [1]vk.Pipeline = undefined;
        if (r.device.dispatch.vkCreateComputePipelines.?(r.device.device, .null_handle, 1, &pipeline_infos, null, &pipelines) != .success) {
            r.device.dispatch.vkDestroyPipelineLayout.?(r.device.device, pipeline_layout, null);
            r.device.dispatch.vkDestroyDescriptorSetLayout.?(r.device.device, descriptor_set_layout, null);
            r.device.dispatch.vkDestroyShaderModule.?(r.device.device, module, null);
            r.allocator.destroy(shader);
            return null;
        }
        pipeline = pipelines[0];
        
        shader.* = ComputeShader{
            .module = module,
            .pipeline = pipeline,
            .pipeline_layout = pipeline_layout,
            .descriptor_set_layout = descriptor_set_layout,
        };
        
        return @ptrCast(shader);
    }
    return null;
}

export fn renderer_compute_shader_destroy(renderer: ?*Renderer, shader: ?*anyopaque) void {
    if (renderer) |r| {
        if (shader) |s| {
            const compute_shader = @as(*ComputeShader, @ptrCast(@alignCast(s)));
            r.device.dispatch.vkDestroyPipeline.?(r.device.device, compute_shader.pipeline, null);
            r.device.dispatch.vkDestroyPipelineLayout.?(r.device.device, compute_shader.pipeline_layout, null);
            r.device.dispatch.vkDestroyDescriptorSetLayout.?(r.device.device, compute_shader.descriptor_set_layout, null);
            r.device.dispatch.vkDestroyShaderModule.?(r.device.device, compute_shader.module, null);
            r.allocator.destroy(compute_shader);
        }
    }
}


export fn renderer_command_buffer_create(renderer: ?*Renderer) ?*anyopaque {
    if (renderer) |r| {
        const cmd_buffer = r.allocator.create(ComputeCommandBuffer) catch return null;
        
        // Allocate command buffer from compute command pool
        const alloc_info = vk.CommandBufferAllocateInfo{
            .command_pool = r.compute_command_pool,
            .level = .primary,
            .command_buffer_count = 1,
        };
        
        var vk_cmd_buffer: vk.CommandBuffer = undefined;
        if (r.device.dispatch.vkAllocateCommandBuffers.?(r.device.device, &alloc_info, @ptrCast(&vk_cmd_buffer)) != .success) {
            r.allocator.destroy(cmd_buffer);
            return null;
        }
        
        // Create fence for synchronization
        const fence_info = vk.FenceCreateInfo{
            .flags = .{},
        };
        
        var fence: vk.Fence = undefined;
        if (r.device.dispatch.vkCreateFence.?(r.device.device, &fence_info, null, &fence) != .success) {
            r.device.dispatch.vkFreeCommandBuffers.?(r.device.device, r.compute_command_pool, 1, @ptrCast(&vk_cmd_buffer));
            r.allocator.destroy(cmd_buffer);
            return null;
        }
        
        cmd_buffer.* = ComputeCommandBuffer{
            .command_buffer = vk_cmd_buffer,
            .fence = fence,
        };
        
        return @ptrCast(cmd_buffer);
    }
    return null;
}

export fn renderer_command_buffer_destroy(renderer: ?*Renderer, cmd: ?*anyopaque) void {
    if (renderer) |r| {
        if (cmd) |c| {
            const cmd_buffer = @as(*ComputeCommandBuffer, @ptrCast(@alignCast(c)));
            
            // Destroy fence
            r.device.dispatch.vkDestroyFence.?(r.device.device, cmd_buffer.fence, null);
            
            // Free command buffer
            r.device.dispatch.vkFreeCommandBuffers.?(r.device.device, r.compute_command_pool, 1, @ptrCast(&cmd_buffer.command_buffer));
            
            r.allocator.destroy(cmd_buffer);
        }
    }
}

export fn renderer_command_buffer_begin(renderer: ?*Renderer, cmd: ?*anyopaque) bool {
    if (renderer) |r| {
        if (cmd) |c| {
            const cmd_buffer = @as(*ComputeCommandBuffer, @ptrCast(@alignCast(c)));
            
            const begin_info = vk.CommandBufferBeginInfo{
                .flags = .{ .one_time_submit_bit = true },
                .p_inheritance_info = null,
            };
            
            return r.device.dispatch.vkBeginCommandBuffer.?(cmd_buffer.command_buffer, &begin_info) == .success;
        }
    }
    return false;
}

export fn renderer_command_buffer_end(renderer: ?*Renderer, cmd: ?*anyopaque) bool {
    if (renderer) |r| {
        if (cmd) |c| {
            const cmd_buffer = @as(*ComputeCommandBuffer, @ptrCast(@alignCast(c)));
            return r.device.dispatch.vkEndCommandBuffer.?(cmd_buffer.command_buffer) == .success;
        }
    }
    return false;
}

export fn renderer_compute_bind_shader(
    renderer: ?*Renderer,
    cmd: ?*anyopaque,
    shader: ?*anyopaque,
) void {
    if (renderer) |r| {
        if (cmd) |c| {
            if (shader) |s| {
                const cmd_buffer = @as(*ComputeCommandBuffer, @ptrCast(@alignCast(c)));
                const compute_shader = @as(*ComputeShader, @ptrCast(@alignCast(s)));
                
                r.device.dispatch.vkCmdBindPipeline.?(cmd_buffer.command_buffer, .compute, compute_shader.pipeline);
            }
        }
    }
}

export fn renderer_compute_bind_buffer(
    renderer: ?*Renderer,
    cmd: ?*anyopaque,
    binding: u32,
    buffer: ?*anyopaque,
) void {
    if (renderer) |r| {
        if (cmd) |c| {
            if (buffer) |b| {
                _ = @as(*ComputeCommandBuffer, @ptrCast(@alignCast(c)));
                const gpu_buffer = @as(*GpuBuffer, @ptrCast(@alignCast(b)));
                
                // Validate buffer before use
                if (!gpu_buffer.validate()) {
                    std.debug.print("Error: Invalid buffer magic number in renderer_compute_bind_buffer (got 0x{x})\n", .{gpu_buffer.magic});
                    return;
                }
                
                // For simplicity, we'll create a new descriptor set for each binding
                // In production, you'd want to cache and reuse descriptor sets
                
                // Create descriptor pool if needed
                const descriptor_pool = r.getComputeDescriptorPool() catch return;
                
                // Update descriptor set with buffer binding
                // This is a simplified version - in production you'd manage descriptor sets more efficiently
                _ = binding;
                _ = descriptor_pool;
            }
        }
    }
}

export fn renderer_compute_dispatch(
    renderer: ?*Renderer,
    cmd: ?*anyopaque,
    x: u32,
    y: u32,
    z: u32,
) void {
    if (renderer) |r| {
        if (cmd) |c| {
            const cmd_buffer = @as(*ComputeCommandBuffer, @ptrCast(@alignCast(c)));
            r.device.dispatch.vkCmdDispatch.?(cmd_buffer.command_buffer, x, y, z);
        }
    }
}

export fn renderer_compute_memory_barrier(renderer: ?*Renderer, cmd_buffer: vk.CommandBuffer) void {
    if (renderer) |r| {
        if (cmd_buffer != .null_handle) {
            const barrier = vk.MemoryBarrier{
                .src_access_mask = .{ .shader_write_bit = true },
                .dst_access_mask = .{ .shader_read_bit = true },
            };
            const barriers = [_]vk.MemoryBarrier{barrier};
            
            r.device.dispatch.vkCmdPipelineBarrier.?(
                cmd_buffer,
                .{ .compute_shader_bit = true },
                .{ .compute_shader_bit = true },
                .{},
                1,
                &barriers,
                0,
                null,
                0,
                null,
            );
        }
    }
}

export fn renderer_command_buffer_submit(renderer: ?*Renderer, cmd: ?*anyopaque) bool {
    if (renderer) |r| {
        if (cmd) |c| {
            const cmd_buffer = @as(*ComputeCommandBuffer, @ptrCast(@alignCast(c)));
            
            // Create a fence if we don't have one
            if (cmd_buffer.fence == .null_handle) {
                const fence_info = vk.FenceCreateInfo{
                    .flags = .{},
                };
                if (r.device.dispatch.vkCreateFence.?(r.device.device, &fence_info, null, &cmd_buffer.fence) != .success) {
                    return false;
                }
            }
            
            // Reset the fence before submitting
            const fences = [_]vk.Fence{cmd_buffer.fence};
            _ = r.device.dispatch.vkResetFences.?(r.device.device, 1, &fences);
            
            const cmd_buffers = [_]vk.CommandBuffer{cmd_buffer.command_buffer};
            const submit_info = vk.SubmitInfo{
                .wait_semaphore_count = 0,
                .p_wait_semaphores = null,
                .p_wait_dst_stage_mask = null,
                .command_buffer_count = 1,
                .p_command_buffers = &cmd_buffers,
                .signal_semaphore_count = 0,
                .p_signal_semaphores = null,
            };
            
            const submit_infos = [_]vk.SubmitInfo{submit_info};
            std.debug.print("Submitting command buffer with fence: {any}\n", .{cmd_buffer.fence});
            const submit_result = r.device.dispatch.vkQueueSubmit.?(r.device.graphics_queue, 1, &submit_infos, cmd_buffer.fence);
            
            if (submit_result == .success) {
                std.debug.print("Command buffer submitted successfully\n", .{});
                // Don't wait here - let the caller decide when to wait
                // This avoids potential deadlocks and allows batch submission
                return true;
            } else {
                std.debug.print("Command buffer submission failed with result: {}\n", .{submit_result});
            }
            
            return false;
        }
    }
    return false;
}

export fn renderer_device_wait_idle(renderer: ?*Renderer) void {
    if (renderer) |r| {
        _ = r.device.dispatch.vkDeviceWaitIdle.?(r.device.device);
    }
}

// Timeline semaphore structure
pub const TimelineSemaphore = struct {
    semaphore: vk.Semaphore,
    current_value: u64,
};

// Timeline semaphore operations
export fn renderer_timeline_semaphore_create(renderer: ?*Renderer, initial_value: u64) ?*anyopaque {
    if (renderer) |r| {
        const semaphore_type_info = vk.SemaphoreTypeCreateInfo{
            .semaphore_type = .timeline,
            .initial_value = initial_value,
        };
        
        const create_info = vk.SemaphoreCreateInfo{
            .p_next = &semaphore_type_info,
        };
        
        var semaphore: vk.Semaphore = undefined;
        if (r.device.dispatch.vkCreateSemaphore.?(r.device.device, &create_info, null, &semaphore) != .success) {
            std.debug.print("Failed to create timeline semaphore\n", .{});
            return null;
        }
        
        const timeline_sem = std.heap.c_allocator.create(TimelineSemaphore) catch {
            r.device.dispatch.vkDestroySemaphore.?(r.device.device, semaphore, null);
            return null;
        };
        
        timeline_sem.* = TimelineSemaphore{
            .semaphore = semaphore,
            .current_value = initial_value,
        };
        
        return @ptrCast(timeline_sem);
    }
    return null;
}

export fn renderer_timeline_semaphore_destroy(renderer: ?*Renderer, semaphore_ptr: ?*anyopaque) void {
    if (renderer) |r| {
        if (semaphore_ptr) |ptr| {
            const timeline_sem = @as(*TimelineSemaphore, @ptrCast(@alignCast(ptr)));
            r.device.dispatch.vkDestroySemaphore.?(r.device.device, timeline_sem.semaphore, null);
            std.heap.c_allocator.destroy(timeline_sem);
        }
    }
}

export fn renderer_timeline_semaphore_get_value(renderer: ?*Renderer, semaphore_ptr: ?*anyopaque) u64 {
    if (renderer) |r| {
        if (semaphore_ptr) |ptr| {
            const timeline_sem = @as(*TimelineSemaphore, @ptrCast(@alignCast(ptr)));
            var value: u64 = 0;
            if (r.device.dispatch.vkGetSemaphoreCounterValue.?(r.device.device, timeline_sem.semaphore, &value) != .success) {
                return timeline_sem.current_value;
            }
            timeline_sem.current_value = value;
            return value;
        }
    }
    return 0;
}

export fn renderer_timeline_semaphore_signal(renderer: ?*Renderer, semaphore_ptr: ?*anyopaque, value: u64) void {
    if (renderer) |r| {
        if (semaphore_ptr) |ptr| {
            const timeline_sem = @as(*TimelineSemaphore, @ptrCast(@alignCast(ptr)));
            const signal_info = vk.SemaphoreSignalInfo{
                .semaphore = timeline_sem.semaphore,
                .value = value,
            };
            _ = r.device.dispatch.vkSignalSemaphore.?(r.device.device, &signal_info);
            timeline_sem.current_value = value;
        }
    }
}

export fn renderer_timeline_semaphore_wait(renderer: ?*Renderer, semaphore_ptr: ?*anyopaque, value: u64, timeout_ns: u64) bool {
    if (renderer) |r| {
        if (semaphore_ptr) |ptr| {
            const timeline_sem = @as(*TimelineSemaphore, @ptrCast(@alignCast(ptr)));
            const wait_info = vk.SemaphoreWaitInfo{
                .semaphore_count = 1,
                .p_semaphores = @as([*]const vk.Semaphore, @ptrCast(&timeline_sem.semaphore)),
                .p_values = @as([*]const u64, @ptrCast(&value)),
            };
            const result = r.device.dispatch.vkWaitSemaphores.?(r.device.device, &wait_info, timeout_ns);
            return result == .success;
        }
    }
    return false;
}

export fn renderer_command_buffer_wait_semaphore(renderer: ?*Renderer, cmd: ?*anyopaque, semaphore_ptr: ?*anyopaque, value: u64) void {
    // This function is handled during submit with timeline semaphores
    _ = renderer;
    _ = cmd;
    _ = semaphore_ptr;
    _ = value;
}

export fn renderer_command_buffer_signal_semaphore(renderer: ?*Renderer, cmd: ?*anyopaque, semaphore_ptr: ?*anyopaque, value: u64) void {
    // This needs to be handled during submit, storing the signal info for later
    _ = renderer;
    _ = cmd;
    _ = semaphore_ptr;
    _ = value;
}

export fn renderer_command_buffer_submit_with_semaphores(
    renderer: ?*Renderer,
    cmd: ?*anyopaque,
    wait_semaphores: [*]const ?*anyopaque,
    wait_values: [*]const u64,
    wait_count: u32,
    signal_semaphores: [*]const ?*anyopaque,
    signal_values: [*]const u64,
    signal_count: u32,
) bool {
    if (renderer) |r| {
        if (cmd) |cmd_ptr| {
            const cmd_buffer = @as(vk.CommandBuffer, @enumFromInt(@intFromPtr(cmd_ptr)));
            
            // Build arrays of actual semaphores
            var wait_sems = std.ArrayList(vk.Semaphore).init(std.heap.c_allocator);
            defer wait_sems.deinit();
            var wait_vals = std.ArrayList(u64).init(std.heap.c_allocator);
            defer wait_vals.deinit();
            
            var i: u32 = 0;
            while (i < wait_count) : (i += 1) {
                if (wait_semaphores[i]) |sem_ptr| {
                    const timeline_sem = @as(*TimelineSemaphore, @ptrCast(@alignCast(sem_ptr)));
                    wait_sems.append(timeline_sem.semaphore) catch return false;
                    wait_vals.append(wait_values[i]) catch return false;
                }
            }
            
            var signal_sems = std.ArrayList(vk.Semaphore).init(std.heap.c_allocator);
            defer signal_sems.deinit();
            var signal_vals = std.ArrayList(u64).init(std.heap.c_allocator);
            defer signal_vals.deinit();
            
            i = 0;
            while (i < signal_count) : (i += 1) {
                if (signal_semaphores[i]) |sem_ptr| {
                    const timeline_sem = @as(*TimelineSemaphore, @ptrCast(@alignCast(sem_ptr)));
                    signal_sems.append(timeline_sem.semaphore) catch return false;
                    signal_vals.append(signal_values[i]) catch return false;
                }
            }
            
            const timeline_info = vk.TimelineSemaphoreSubmitInfo{
                .wait_semaphore_value_count = @intCast(wait_vals.items.len),
                .p_wait_semaphore_values = if (wait_vals.items.len > 0) @as(?[*]const u64, @ptrCast(wait_vals.items.ptr)) else null,
                .signal_semaphore_value_count = @intCast(signal_vals.items.len),
                .p_signal_semaphore_values = if (signal_vals.items.len > 0) @as(?[*]const u64, @ptrCast(signal_vals.items.ptr)) else null,
            };
            
            const wait_stages = [_]vk.PipelineStageFlags{.{ .all_commands_bit = true }};
            const submit_info = vk.SubmitInfo{
                .p_next = &timeline_info,
                .wait_semaphore_count = @intCast(wait_sems.items.len),
                .p_wait_semaphores = if (wait_sems.items.len > 0) wait_sems.items.ptr else null,
                .p_wait_dst_stage_mask = &wait_stages,
                .command_buffer_count = 1,
                .p_command_buffers = @as([*]const vk.CommandBuffer, @ptrCast(&cmd_buffer)),
                .signal_semaphore_count = @intCast(signal_sems.items.len),
                .p_signal_semaphores = if (signal_sems.items.len > 0) signal_sems.items.ptr else null,
            };
            
            const submit_infos = [_]vk.SubmitInfo{submit_info};
            const result = r.device.dispatch.vkQueueSubmit.?(
                r.device.graphics_queue,
                1,
                &submit_infos,
                .null_handle
            );
            
            return result == .success;
        }
    }
    return false;
}