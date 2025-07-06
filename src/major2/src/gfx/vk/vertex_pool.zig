const std = @import("std");
const vk =
    @import("vulkan");

/// DrawCommand represents a single draw call for the indirect drawing command buffer
/// This is similar to the DAIC (Draw Arrays Indirect Command) from the article
pub const DrawCommand = struct {
    // Base properties required by Vulkan
    index_count: u32, // Number of indices to draw
    instance_count: u32 = 1, // Number of instances (typically 1)
    first_index: u32, // First index in index buffer
    vertex_offset: i32, // Offset into vertex buffer
    first_instance: u32 = 0, // First instance (typically 0)

    // Additional properties for sorting/masking
    position: [3]f32 = .{ 0, 0, 0 }, // Position for distance sorting
    group: u32 = 0, // For group-based masking (e.g., face orientation)
    index_ptr: *u32 = undefined, // Pointer to this command's index in the array

    pub fn init(index_count: u32, first_index: u32, vertex_offset: i32, index_ptr: *u32) DrawCommand {
        return .{
            .index_count = index_count,
            .first_index = first_index,
            .vertex_offset = vertex_offset,
            .index_ptr = index_ptr,
        };
    }

    /// Create a VkDrawIndexedIndirectCommand from this DrawCommand
    pub fn toVkCommand(self: DrawCommand) vk.DrawIndexedIndirectCommand {
        return .{
            .index_count = self.index_count,
            .instance_count = self.instance_count,
            .first_index = self.first_index,
            .vertex_offset = self.vertex_offset,
            .first_instance = self.first_instance,
        };
    }
};

/// Vertex definition for greedy meshed voxel faces
/// Must match the Rust VoxelVertex struct exactly
pub const Vertex = extern struct {
    position: [3]f32,     // Bottom-left corner of face - 12 bytes
    size: [2]f32,         // Width and height of face (in voxels) - 8 bytes
    normal_dir: u32,      // Face direction: 0=+X, 1=-X, 2=+Y, 3=-Y, 4=+Z, 5=-Z - 4 bytes
    color: [4]f32,        // Face color - 16 bytes
    // Total: 40 bytes

    pub fn init(pos: [3]f32, face_size: [2]f32, normal_direction: u32, col: [4]f32) Vertex {
        return .{
            .position = pos,
            .size = face_size,
            .normal_dir = normal_direction,
            .color = col,
        };
    }

    pub fn initWithRgb(pos: [3]f32, face_size: [2]f32, normal_direction: u32, col: [3]f32) Vertex {
        return .{
            .position = pos,
            .size = face_size,
            .normal_dir = normal_direction,
            .color = .{ col[0], col[1], col[2], 1.0 },
        };
    }

    /// Create the vertex input binding description
    pub fn getBindingDescription() vk.VertexInputBindingDescription {
        return .{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .input_rate = .vertex,
        };
    }

    /// Create the vertex attribute descriptions
    pub fn getAttributeDescriptions() [4]vk.VertexInputAttributeDescription {
        // Debug: Print actual offsets
        std.debug.print("Vertex layout offsets: position={}, size={}, normal_dir={}, color={}, total_size={}\n", .{
            @offsetOf(Vertex, "position"),
            @offsetOf(Vertex, "size"),
            @offsetOf(Vertex, "normal_dir"),
            @offsetOf(Vertex, "color"),
            @sizeOf(Vertex),
        });
        
        return .{
            // Position (bottom-left corner of face) - offset 0
            .{
                .binding = 0,
                .location = 0,
                .format = .r32g32b32_sfloat,
                .offset = @offsetOf(Vertex, "position"),
            },
            // Size (width and height) - offset 12
            .{
                .binding = 0,
                .location = 1,
                .format = .r32g32_sfloat,
                .offset = @offsetOf(Vertex, "size"),
            },
            // Normal direction (integer) - offset 20
            .{
                .binding = 0,
                .location = 2,
                .format = .r32_uint,
                .offset = @offsetOf(Vertex, "normal_dir"),
            },
            // Color - offset 24
            .{
                .binding = 0,
                .location = 3,
                .format = .r32g32b32a32_sfloat,
                .offset = @offsetOf(Vertex, "color"),
            },
        };
    }
};

/// StageBuffer represents a single buffer in the vertex pool
/// Each stage buffer contains vertex data and can be reused
pub const StageBuffer = struct {
    buffer: vk.Buffer = undefined,
    memory: vk.DeviceMemory = undefined,
    capacity: u32 = 0, // Maximum vertex capacity
    used: u32 = 0, // Current number of vertices in use
    mapped_memory: ?*anyopaque = null, // Mapped memory pointer
    in_use: bool = false, // Whether this buffer is currently in use
};

/// VertexPool manages a collection of stage buffers for efficient vertex memory management
pub const VertexPool = struct {
    allocator: std.mem.Allocator,
    device: vk.Device,
    physical_device: vk.PhysicalDevice,
    dispatch: vk.DeviceDispatch,
    instance: vk.InstanceDispatch,
    command_pool: vk.CommandPool, // Owned by Renderer, don't destroy
    queue: vk.Queue, // Graphics queue for operations

    // Vertex pool state
    stage_buffers: std.ArrayList(StageBuffer),
    free_buffers: std.ArrayList(u32), // Indices of free stage buffers

    // Indirect draw command buffer
    indirect_buffer: vk.Buffer = undefined,
    indirect_memory: vk.DeviceMemory = undefined,
    indirect_mapped: ?*anyopaque = null,

    // Index buffer
    index_buffer: vk.Buffer = undefined,
    index_memory: vk.DeviceMemory = undefined,

    // Draw commands
    draw_commands: std.ArrayList(DrawCommand),
    effective_draws: usize = 0, // Number of active draw commands after masking

    // Pool configuration
    buffer_size: u32,
    vertex_per_buffer: u32,
    max_draw_commands: u32,

    /// Initialize the vertex pool
    pub fn init(
        allocator: std.mem.Allocator,
        device: vk.Device,
        physical_device: vk.PhysicalDevice,
        dispatch: vk.DeviceDispatch,
        instance: vk.InstanceDispatch,
        command_pool: vk.CommandPool,
        queue: vk.Queue,
        buffer_count: u32,
        vertex_per_buffer: u32,
        max_draw_commands: u32,
    ) !VertexPool {
        // Store the renderer's command pool for later use
        std.debug.print("VertexPool initializing with command pool: {any}\n", .{command_pool});

        if (command_pool == .null_handle) {
            return error.InvalidCommandPool;
        }

        var pool = VertexPool{
            .allocator = allocator,
            .device = device,
            .physical_device = physical_device,
            .dispatch = dispatch,
            .instance = instance,
            .command_pool = command_pool, // Using the renderer's command pool
            .queue = queue,
            .stage_buffers = std.ArrayList(StageBuffer).init(allocator),
            .free_buffers = std.ArrayList(u32).init(allocator),
            .draw_commands = std.ArrayList(DrawCommand).init(allocator),
            .buffer_size = @sizeOf(Vertex) * vertex_per_buffer,
            .vertex_per_buffer = vertex_per_buffer,
            .max_draw_commands = max_draw_commands,
        };

        // Pre-allocate stage buffers
        try pool.stage_buffers.ensureTotalCapacity(buffer_count);
        try pool.free_buffers.ensureTotalCapacity(buffer_count);

        for (0..buffer_count) |i| {
            var stage = StageBuffer{
                .capacity = vertex_per_buffer,
            };

            // Create the vertex buffer
            try pool.createBuffer(
                pool.buffer_size,
                .{ .vertex_buffer_bit = true },
                .{ .host_visible_bit = true, .host_coherent_bit = true },
                &stage.buffer,
                &stage.memory,
            );

            // Map the memory
            stage.mapped_memory = try pool.mapMemory(stage.memory, 0, pool.buffer_size);

            try pool.stage_buffers.append(stage);
            try pool.free_buffers.append(@intCast(i));
        }

        // Create the indirect buffer
        const indirect_buffer_size = @sizeOf(vk.DrawIndexedIndirectCommand) * max_draw_commands;
        try pool.createBuffer(
            indirect_buffer_size,
            .{ .indirect_buffer_bit = true, .storage_buffer_bit = true },
            .{ .host_visible_bit = true, .host_coherent_bit = true },
            &pool.indirect_buffer,
            &pool.indirect_memory,
        );

        // Map the indirect buffer
        pool.indirect_mapped = try pool.mapMemory(
            pool.indirect_memory,
            0,
            indirect_buffer_size,
        );

        // Pre-allocate draw commands
        try pool.draw_commands.ensureTotalCapacity(max_draw_commands);

        // Create the index buffer with default indices for quad rendering
        try pool.createIndexBuffer();

        return pool;
    }

    /// Create the index buffer with indices for quads
    fn createIndexBuffer(self: *VertexPool) !void {
        // Calculate how many indices we need for all buffers
        // Each quad has 6 indices (2 triangles), and a buffer can hold vertex_per_buffer / 4 quads
        const quads_per_buffer = self.vertex_per_buffer / 4;
        const indices_per_buffer = quads_per_buffer * 6;
        const total_indices = indices_per_buffer * self.stage_buffers.items.len;

        var indices = try self.allocator.alloc(u32, total_indices);
        defer self.allocator.free(indices);

        var index: u32 = 0;

        // Generate indices for all possible quads across all buffers
        for (0..self.stage_buffers.items.len) |buffer_idx| {
            const vertex_base = buffer_idx * self.vertex_per_buffer;

            for (0..quads_per_buffer) |quad_idx| {
                const quad_base = vertex_base + (quad_idx * 4);

                // First triangle
                indices[index] = @intCast(quad_base);
                indices[index + 1] = @intCast(quad_base + 1);
                indices[index + 2] = @intCast(quad_base + 2);

                // Second triangle
                indices[index + 3] = @intCast(quad_base);
                indices[index + 4] = @intCast(quad_base + 2);
                indices[index + 5] = @intCast(quad_base + 3);

                index += 6;
            }
        }

        // Create the index buffer
        const index_buffer_size = @sizeOf(u32) * total_indices;
        try self.createBuffer(
            index_buffer_size,
            .{ .index_buffer_bit = true, .transfer_dst_bit = true },
            .{ .device_local_bit = true },
            &self.index_buffer,
            &self.index_memory,
        );

        // Upload the index data
        var staging_buffer: vk.Buffer = undefined;
        var staging_memory: vk.DeviceMemory = undefined;

        try self.createBuffer(
            index_buffer_size,
            .{ .transfer_src_bit = true },
            .{ .host_visible_bit = true, .host_coherent_bit = true },
            &staging_buffer,
            &staging_memory,
        );

        // Map and copy to staging buffer
        const data = try self.mapMemory(staging_memory, 0, index_buffer_size);
        @memcpy(@as([*]u8, @ptrCast(data))[0..index_buffer_size], std.mem.sliceAsBytes(indices));
        _ = self.dispatch.vkUnmapMemory.?(self.device, staging_memory);

        // Copy from staging to device local memory
        try self.copyBuffer(staging_buffer, self.index_buffer, index_buffer_size);

        // Clean up staging buffer
        _ = self.dispatch.vkDestroyBuffer.?(self.device, staging_buffer, null);
        _ = self.dispatch.vkFreeMemory.?(self.device, staging_memory, null);
    }

    /// Request a stage buffer for new mesh data
    pub fn requestBuffer(self: *VertexPool) !?u32 {
        if (self.free_buffers.items.len == 0) {
            return null; // No free buffers available
        }

        const buffer_idx = self.free_buffers.pop();
        if (buffer_idx) |idx| {
            self.stage_buffers.items[@intCast(idx)].used = 0;
            self.stage_buffers.items[@intCast(idx)].in_use = true;
        }

        return buffer_idx;
    }

    /// Add a draw command for the given buffer
    pub fn addDrawCommand(
        self: *VertexPool,
        buffer_idx: u32,
        vertex_count: u32,
        position: [3]f32,
        group: u32,
    ) !*u32 {
        std.debug.print("addDrawCommand: buffer_idx={}, vertex_count={}, position=[{:.2},{:.2},{:.2}], group={}\n", 
            .{buffer_idx, vertex_count, position[0], position[1], position[2], group});
        
        if (self.draw_commands.items.len >= self.max_draw_commands) {
            std.debug.print("ERROR: Too many draw commands ({} >= {})\n", .{self.draw_commands.items.len, self.max_draw_commands});
            return error.TooManyDrawCommands;
        }

        const index_ptr = try self.allocator.create(u32);
        index_ptr.* = @intCast(self.draw_commands.items.len);

        // Calculate parameters for draw command
        // Each vertex represents one voxel face, geometry shader generates quads
        const index_count = vertex_count; // Direct vertex count for point rendering
        const first_index = 0;
        const vertex_offset = @as(i32, @intCast(buffer_idx * self.vertex_per_buffer));

        var cmd = DrawCommand.init(index_count, first_index, vertex_offset, index_ptr);
        cmd.position = position;
        cmd.group = group;

        try self.draw_commands.append(cmd);
        self.effective_draws = self.draw_commands.items.len;
        
        std.debug.print("addDrawCommand SUCCESS: created command index {}, effective_draws now = {}\n", 
            .{index_ptr.*, self.effective_draws});

        return index_ptr;
    }

    /// Update the vertex count for an existing draw command
    pub fn updateDrawCommandVertexCount(self: *VertexPool, command_index_ptr: *u32, new_vertex_count: u32) void {
        const command_idx = command_index_ptr.*;
        
        std.debug.print("Updating draw command {} vertex count to {}\n", .{command_idx, new_vertex_count});
        
        if (command_idx < self.draw_commands.items.len) {
            std.debug.print("Old vertex count: {}\n", .{self.draw_commands.items[command_idx].index_count});
            self.draw_commands.items[command_idx].index_count = new_vertex_count;
            std.debug.print("New vertex count: {}\n", .{self.draw_commands.items[command_idx].index_count});
        } else {
            std.debug.print("ERROR: Command index {} out of bounds (max: {})\n", .{command_idx, self.draw_commands.items.len});
        }
    }
    
    /// Release a buffer and its draw command
    pub fn releaseBuffer(self: *VertexPool, buffer_idx: u32, command_index_ptr: *u32) !void {
        const command_idx = command_index_ptr.*;

        // Mark buffer as free
        if (buffer_idx < self.stage_buffers.items.len) {
            self.stage_buffers.items[buffer_idx].in_use = false;
            try self.free_buffers.append(buffer_idx);
        }

        // Remove draw command
        if (command_idx < self.draw_commands.items.len) {
            // Swap with the last item and pop
            if (command_idx < self.draw_commands.items.len - 1) {
                const last_item = self.draw_commands.items[self.draw_commands.items.len - 1];
                self.draw_commands.items[command_idx] = last_item;
                // Update the swapped item's index pointer
                last_item.index_ptr.* = command_idx;
            }

            _ = self.draw_commands.pop();
            self.effective_draws = self.draw_commands.items.len;
        }

        // Free the index pointer
        self.allocator.destroy(command_index_ptr);
    }

    /// Fill vertex data for a specific buffer
    pub fn fillVertexData(self: *VertexPool, buffer_idx: u32, vertices: []align(4) const Vertex) !void {
        if (buffer_idx >= self.stage_buffers.items.len) {
            return error.InvalidBufferIndex;
        }

        var stage = &self.stage_buffers.items[buffer_idx];

        if (vertices.len > stage.capacity) {
            return error.BufferTooSmall;
        }

        // Copy vertex data to the mapped memory
        const data_size = @sizeOf(Vertex) * vertices.len;
        @memcpy(@as([*]u8, @ptrCast(@alignCast(stage.mapped_memory.?)))[0..data_size], std.mem.sliceAsBytes(vertices));
        stage.used = @intCast(vertices.len);
        
        // Flush the memory to ensure GPU sees the updates
        const flush_range = vk.MappedMemoryRange{
            .memory = stage.memory,
            .offset = 0,
            .size = vk.WHOLE_SIZE,
        };
        _ = self.dispatch.vkFlushMappedMemoryRanges.?(self.device, 1, &[_]vk.MappedMemoryRange{flush_range});
    }

    /// Update only position data for a specific buffer
    pub fn updatePositionData(self: *VertexPool, buffer_idx: u32, positions: []const [3]f32) !void {
        if (buffer_idx >= self.stage_buffers.items.len) {
            return error.InvalidBufferIndex;
        }

        const stage = &self.stage_buffers.items[buffer_idx];

        if (positions.len > stage.used) {
            return error.TooManyVertices;
        }

        // Get existing vertices
        const dest_vertices = @as([*]Vertex, @ptrCast(stage.mapped_memory.?))[0..stage.used];

        // Update only position data
        for (positions, 0..) |pos, i| {
            if (i < dest_vertices.len) {
                dest_vertices[i].position = pos;
            }
        }
    }

    /// Update only normal direction data for a specific buffer
    pub fn updateNormalDirData(self: *VertexPool, buffer_idx: u32, normal_dirs: []const u32) !void {
        if (buffer_idx >= self.stage_buffers.items.len) {
            return error.InvalidBufferIndex;
        }

        const stage = &self.stage_buffers.items[buffer_idx];

        if (normal_dirs.len > stage.used) {
            return error.TooManyVertices;
        }

        // Get existing vertices
        const dest_vertices = @as([*]Vertex, @ptrCast(stage.mapped_memory.?))[0..stage.used];

        // Update only normal direction data
        for (normal_dirs, 0..) |dir, i| {
            if (i < dest_vertices.len) {
                dest_vertices[i].normal_dir = dir;
            }
        }
    }

    /// Update only color data for a specific buffer
    pub fn updateColorData(self: *VertexPool, buffer_idx: u32, colors: []const [4]f32) !void {
        if (buffer_idx >= self.stage_buffers.items.len) {
            return error.InvalidBufferIndex;
        }

        const stage = &self.stage_buffers.items[buffer_idx];

        if (colors.len > stage.used) {
            return error.TooManyVertices;
        }

        // Get existing vertices
        const dest_vertices = @as([*]Vertex, @ptrCast(stage.mapped_memory.?))[0..stage.used];

        // Update only color data
        for (colors, 0..) |col, i| {
            if (i < dest_vertices.len) {
                dest_vertices[i].color = col;
            }
        }
    }

    /// Apply masking to the draw commands based on a predicate function
    pub fn mask(self: *VertexPool, context: anytype, comptime predicateFn: fn (ctx: @TypeOf(context), cmd: DrawCommand) bool) void {
        var m: usize = 0;
        var j: usize = self.draw_commands.items.len - 1;

        // Sort items such that all items passing the predicate are at the front
        while (m <= j) {
            while (m <= j and predicateFn(context, self.draw_commands.items[m])) {
                m += 1;
            }

            if (m <= j) {
                while (m <= j and !predicateFn(context, self.draw_commands.items[j])) {
                    j -= 1;
                }

                if (m <= j) {
                    // Swap the commands
                    const temp = self.draw_commands.items[m];
                    self.draw_commands.items[m] = self.draw_commands.items[j];
                    self.draw_commands.items[j] = temp;

                    m += 1;
                    j -= 1;
                }
            }
        }

        self.effective_draws = m;
    }

    /// Sort draw commands using a provided comparison function
    pub fn updateIndirectBuffer(self: *VertexPool) !void {
        // Convert DrawCommands to VkDrawIndexedIndirectCommand and copy to mapped buffer
        var indirect_data = @as([*]vk.DrawIndexedIndirectCommand, @ptrCast(@alignCast(self.indirect_mapped.?)));

        for (self.draw_commands.items[0..self.effective_draws], 0..) |cmd, i| {
            indirect_data[i] = cmd.toVkCommand();
        }
    }

    /// Render all effective draw commands
    pub fn render(
        self: *VertexPool,
        command_buffer: vk.CommandBuffer,
        _: vk.PipelineLayout, // Unused parameter but kept for API compatibility
        pipeline: vk.Pipeline,
    ) !void {
        if (command_buffer == .null_handle) {
            return error.InvalidCommandBuffer;
        }

        std.debug.print("VertexPool render: {} effective draws, {} total commands\n", .{ self.effective_draws, self.draw_commands.items.len });
        
        // Debug: Print all draw commands
        for (self.draw_commands.items, 0..) |cmd, i| {
            std.debug.print("  Draw command {}: vertex_count={}, vertex_offset={}\n", .{i, cmd.index_count, cmd.vertex_offset});
        }

        // Bind the pipeline
        _ = self.dispatch.vkCmdBindPipeline.?(command_buffer, .graphics, pipeline);

        // Issue non-indexed draw commands for each draw command
        if (self.effective_draws > 0) {
            std.debug.print("Issuing draw command with {} draws\n", .{self.effective_draws});

            // For each draw command, bind the appropriate buffer and draw
            for (self.draw_commands.items[0..self.effective_draws]) |cmd| {
                // Calculate which buffer this vertex_offset refers to
                const buffer_idx = @divFloor(@as(u32, @intCast(cmd.vertex_offset)), self.vertex_per_buffer);
                const vertex_offset_in_buffer = @mod(@as(u32, @intCast(cmd.vertex_offset)), self.vertex_per_buffer);

                if (buffer_idx >= self.stage_buffers.items.len) {
                    std.debug.print("Warning: Invalid buffer index {} for draw command\n", .{buffer_idx});
                    continue;
                }

                const stage = &self.stage_buffers.items[buffer_idx];
                const vertex_buffers = [_]vk.Buffer{stage.buffer};
                const offsets = [_]vk.DeviceSize{0};

                _ = self.dispatch.vkCmdBindVertexBuffers.?(command_buffer, 0, 1, &vertex_buffers, &offsets);

                std.debug.print("Drawing {} vertices from buffer {} at offset {}\n", 
                    .{ cmd.index_count, buffer_idx, vertex_offset_in_buffer });

                _ = self.dispatch.vkCmdDraw.?(command_buffer, 
                    cmd.index_count,         // vertex count (points)
                    1,                      // instance count
                    vertex_offset_in_buffer, // first vertex
                    0                       // first instance
                );
            }
        } else {
            std.debug.print("No effective draws to render\n", .{});
        }
    }

    /// Helper function to create a buffer
    fn createBuffer(
        self: *VertexPool,
        size: vk.DeviceSize,
        usage: vk.BufferUsageFlags,
        properties: vk.MemoryPropertyFlags,
        buffer: *vk.Buffer,
        buffer_memory: *vk.DeviceMemory,
    ) !void {
        // Create buffer
        const buffer_info = vk.BufferCreateInfo{
            .size = size,
            .usage = usage,
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        _ = self.dispatch.vkCreateBuffer.?(self.device, &buffer_info, null, &buffer.*);

        // Get memory requirements
        var mem_requirements: vk.MemoryRequirements = undefined;
        _ = self.dispatch.vkGetBufferMemoryRequirements.?(self.device, buffer.*, &mem_requirements);

        // Allocate memory
        const alloc_info = vk.MemoryAllocateInfo{
            .allocation_size = mem_requirements.size,
            .memory_type_index = try self.findMemoryType(mem_requirements.memory_type_bits, properties),
        };

        _ = self.dispatch.vkAllocateMemory.?(self.device, &alloc_info, null, &buffer_memory.*);

        // Bind memory to buffer
        _ = self.dispatch.vkBindBufferMemory.?(self.device, buffer.*, buffer_memory.*, 0);
    }

    /// Helper function to map memory
    fn mapMemory(
        self: *VertexPool,
        memory: vk.DeviceMemory,
        offset: vk.DeviceSize,
        size: vk.DeviceSize,
    ) !*anyopaque {
        var data: ?*anyopaque = null;
        _ = self.dispatch.vkMapMemory.?(self.device, memory, offset, size, .{}, &data);
        return data.?;
    }

    /// Helper function to copy between buffers
    fn copyBuffer(
        self: *VertexPool,
        src_buffer: vk.Buffer,
        dst_buffer: vk.Buffer,
        size: vk.DeviceSize,
    ) !void {
        // Create a temporary command buffer for the transfer
        const alloc_info = vk.CommandBufferAllocateInfo{
            .command_pool = self.command_pool,
            .level = .primary,
            .command_buffer_count = 1,
        };

        var command_buffer: vk.CommandBuffer = undefined;
        _ = self.dispatch.vkAllocateCommandBuffers.?(self.device, &alloc_info, @as([*]vk.CommandBuffer, @ptrCast(&command_buffer)));

        // Begin command buffer
        const begin_info = vk.CommandBufferBeginInfo{
            .flags = .{ .one_time_submit_bit = true },
            .p_inheritance_info = null,
        };

        _ = self.dispatch.vkBeginCommandBuffer.?(command_buffer, &begin_info);

        // Copy command
        const copy_region = vk.BufferCopy{
            .src_offset = 0,
            .dst_offset = 0,
            .size = size,
        };

        _ = self.dispatch.vkCmdCopyBuffer.?(command_buffer, src_buffer, dst_buffer, 1, @as([*]vk.BufferCopy, @ptrCast(@constCast(&copy_region))));

        // End command buffer
        _ = self.dispatch.vkEndCommandBuffer.?(command_buffer);

        // Submit command buffer
        const submit_info = vk.SubmitInfo{
            .wait_semaphore_count = 0,
            .p_wait_semaphores = undefined,
            .p_wait_dst_stage_mask = undefined,
            .command_buffer_count = 1,
            .p_command_buffers = @as([*]vk.CommandBuffer, @ptrCast(&command_buffer)),
            .signal_semaphore_count = 0,
            .p_signal_semaphores = undefined,
        };

        // Use the graphics queue for transfer operations
        _ = self.dispatch.vkQueueSubmit.?(self.queue, 1, @as([*]vk.SubmitInfo, @ptrCast(@constCast(&submit_info))), .null_handle);
        _ = self.dispatch.vkQueueWaitIdle.?(self.queue);

        // Free command buffer - use the same pool it was allocated from
        self.dispatch.vkFreeCommandBuffers.?(self.device, self.command_pool, 1, @as([*]vk.CommandBuffer, @ptrCast(@constCast(&command_buffer))));
    }

    /// Helper function to find memory type
    fn findMemoryType(
        self: *VertexPool,
        type_filter: u32,
        properties: vk.MemoryPropertyFlags,
    ) !u32 {
        var mem_properties: vk.PhysicalDeviceMemoryProperties = undefined;
        self.instance.vkGetPhysicalDeviceMemoryProperties.?(self.physical_device, &mem_properties);

        for (0..mem_properties.memory_type_count) |i| {
            const suitable_type = (type_filter & (@as(u32, 1) << @intCast(i))) != 0;
            const suitable_properties = mem_properties.memory_types[i].property_flags.contains(properties);

            if (suitable_type and suitable_properties) {
                return @intCast(i);
            }
        }

        return error.NoSuitableMemoryType;
    }

    /// Clean up all resources
    pub fn deinit(self: *VertexPool) void {
        // Unmap all buffers
        for (self.stage_buffers.items) |stage| {
            if (stage.mapped_memory != null) {
                _ = self.dispatch.vkUnmapMemory.?(self.device, stage.memory);
            }

            _ = self.dispatch.vkDestroyBuffer.?(self.device, stage.buffer, null);
            _ = self.dispatch.vkFreeMemory.?(self.device, stage.memory, null);
        }

        // Clean up indirect buffer
        if (self.indirect_mapped != null) {
            _ = self.dispatch.vkUnmapMemory.?(self.device, self.indirect_memory);
        }
        _ = self.dispatch.vkDestroyBuffer.?(self.device, self.indirect_buffer, null);
        _ = self.dispatch.vkFreeMemory.?(self.device, self.indirect_memory, null);

        // Clean up index buffer
        _ = self.dispatch.vkDestroyBuffer.?(self.device, self.index_buffer, null);
        _ = self.dispatch.vkFreeMemory.?(self.device, self.index_memory, null);

        // Free draw command index pointers
        for (self.draw_commands.items) |cmd| {
            self.allocator.destroy(cmd.index_ptr);
        }

        // Free lists
        self.stage_buffers.deinit();
        self.free_buffers.deinit();
        self.draw_commands.deinit();
    }
};
