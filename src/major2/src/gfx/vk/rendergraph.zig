const std = @import("std");
const vk = @import("vulkan");
const gfx = @import("gfx.zig");

// Core types for the render graph system

pub const ResourceType = enum(u8) {
    buffer,
    image,
    blas,
    tlas,
};

pub const AccessType = packed struct(u8) {
    concurrent: bool = false,
    read: bool = false,
    write: bool = false,
    sampled: bool = false,
    _padding: u4 = 0,

    pub const NONE = AccessType{};
    pub const READ = AccessType{ .read = true, .concurrent = true };
    pub const WRITE = AccessType{ .write = true };
    pub const READ_WRITE = AccessType{ .read = true, .write = true };
    pub const WRITE_CONCURRENT = AccessType{ .write = true, .concurrent = true };
    pub const READ_WRITE_CONCURRENT = AccessType{ .read = true, .write = true, .concurrent = true };
    pub const SAMPLED = AccessType{ .sampled = true, .concurrent = true };
};

pub const PipelineStage = enum(u16) {
    none,
    top_of_pipe,
    vertex_shader,
    tessellation_control_shader,
    tessellation_evaluation_shader,
    geometry_shader,
    fragment_shader,
    task_shader,
    mesh_shader,
    compute_shader,
    ray_tracing_shader,
    transfer,
    host,
    acceleration_structure_build,
    color_attachment,
    color_attachment_output,
    depth_stencil_attachment,
    resolve,
    present,
    indirect_command,
    index_input,
    all_graphics,
    all_commands,
    bottom_of_pipe,
};

pub const TaskType = enum(u8) {
    general,
    compute,
    raster,
    ray_tracing,
    transfer,
};

// Resource handle types - using tagged unions for type safety
pub const BufferId = packed struct(u32) {
    index: u24,
    generation: u8,
};

pub const ImageId = packed struct(u32) {
    index: u24,
    generation: u8,
};

pub const BlasId = packed struct(u32) {
    index: u24,
    generation: u8,
};

pub const TlasId = packed struct(u32) {
    index: u24,
    generation: u8,
};

// Task resource views - these are what tasks use to reference resources
pub const TaskBufferView = struct {
    id: BufferId,
    offset: u64 = 0,
    size: u64 = std.math.maxInt(u64),
};

pub const TaskImageView = struct {
    id: ImageId,
    base_mip_level: u32 = 0,
    mip_level_count: u32 = std.math.maxInt(u32),
    base_array_layer: u32 = 0,
    array_layer_count: u32 = std.math.maxInt(u32),
    view_type: vk.ImageViewType = .@"2d",
};

pub const TaskBlasView = struct {
    id: BlasId,
};

pub const TaskTlasView = struct {
    id: TlasId,
};

// Attachment info for tasks
pub const TaskAttachment = struct {
    name: []const u8,
    access: AccessType,
    stage: PipelineStage,
    resource: union(ResourceType) {
        buffer: TaskBufferView,
        image: TaskImageView,
        blas: TaskBlasView,
        tlas: TaskTlasView,
    },
};

// Task interface provided to task callbacks
pub const TaskInterface = struct {
    allocator: std.mem.Allocator,
    device: *gfx.Device,
    command_buffer: vk.CommandBuffer,
    attachments: []const TaskAttachment,
    scratch_memory: []u8,
    frame_index: u32,
    gpu_index: u32, // For multi-GPU support
    
    // Helper functions for resource access
    pub fn getBuffer(self: *const TaskInterface, view: TaskBufferView) !vk.Buffer {
        return self.device.rendergraph.getBufferHandle(view.id);
    }
    
    pub fn getImage(self: *const TaskInterface, view: TaskImageView) !vk.Image {
        return self.device.rendergraph.getImageHandle(view.id);
    }
    
    pub fn getBufferAddress(self: *const TaskInterface, view: TaskBufferView) !vk.DeviceAddress {
        const buffer = try self.getBuffer(view);
        return self.device.dispatch.vkGetBufferDeviceAddress(self.device.device, &.{
            .buffer = buffer,
        });
    }
};

// Task definition
pub const Task = struct {
    name: []const u8,
    type: TaskType,
    attachments: []TaskAttachment,
    callback: *const fn (*TaskInterface) anyerror!void,
    
    // For permutation support
    condition_mask: u32 = 0,
    condition_value: u32 = 0,
};

// Transient resource info
pub const TransientBufferInfo = struct {
    size: u64,
    usage: vk.BufferUsageFlags,
    name: []const u8,
};

pub const TransientImageInfo = struct {
    extent: vk.Extent3D,
    format: vk.Format,
    usage: vk.ImageUsageFlags,
    mip_levels: u32 = 1,
    array_layers: u32 = 1,
    samples: vk.SampleCountFlags = .{ .@"1_bit" = true },
    name: []const u8,
};

// Resource lifetime tracking
const ResourceLifetime = struct {
    first_use_batch: u32 = std.math.maxInt(u32),
    last_use_batch: u32 = 0,
    first_use_queue: u32 = 0,
    last_use_queue: u32 = 0,
};

// Task batch for execution
const TaskBatch = struct {
    tasks: std.ArrayList(usize), // Indices into task array
    barriers: std.ArrayList(MemoryBarrier), // Pre-batch barriers
    post_barriers: std.ArrayList(MemoryBarrier), // Post-batch barriers (for split barriers)
    queue_index: u32,
    
    fn init(allocator: std.mem.Allocator, queue_index: u32) TaskBatch {
        return .{
            .tasks = std.ArrayList(usize).init(allocator),
            .barriers = std.ArrayList(MemoryBarrier).init(allocator),
            .post_barriers = std.ArrayList(MemoryBarrier).init(allocator),
            .queue_index = queue_index,
        };
    }
    
    fn deinit(self: *TaskBatch) void {
        self.tasks.deinit();
        self.barriers.deinit();
        self.post_barriers.deinit();
    }
};

// Barrier types
const MemoryBarrier = struct {
    src_stage_mask: PipelineStage,
    dst_stage_mask: PipelineStage,
    src_access_mask: vk.AccessFlags2,
    dst_access_mask: vk.AccessFlags2,
    
    resource: union(enum) {
        buffer: struct {
            buffer: vk.Buffer,
            offset: vk.DeviceSize,
            size: vk.DeviceSize,
        },
        image: struct {
            image: vk.Image,
            old_layout: vk.ImageLayout,
            new_layout: vk.ImageLayout,
            subresource_range: vk.ImageSubresourceRange,
        },
    },
    
    // For split barriers
    is_release: bool = false,
    is_acquire: bool = false,
};

const Barrier = struct {
    src_stage: vk.PipelineStageFlags2,
    dst_stage: vk.PipelineStageFlags2,
    src_access: vk.AccessFlags2,
    dst_access: vk.AccessFlags2,
    
    // Optional for image barriers
    image: ?struct {
        handle: vk.Image,
        old_layout: vk.ImageLayout,
        new_layout: vk.ImageLayout,
        subresource_range: vk.ImageSubresourceRange,
    } = null,
    
    // Optional for buffer barriers
    buffer: ?struct {
        handle: vk.Buffer,
        offset: vk.DeviceSize,
        size: vk.DeviceSize,
    } = null,
};

const SplitBarrier = struct {
    barrier: Barrier,
    event: vk.Event,
    signal_batch: u32,
    wait_batch: u32,
};

// Multi-GPU support
pub const GpuMask = packed struct(u32) {
    gpus: u32,
    
    pub fn single(gpu_index: u5) GpuMask {
        return .{ .gpus = @as(u32, 1) << gpu_index };
    }
    
    pub fn all() GpuMask {
        return .{ .gpus = std.math.maxInt(u32) };
    }
    
    pub fn contains(self: GpuMask, gpu_index: u5) bool {
        return (self.gpus & (@as(u32, 1) << gpu_index)) != 0;
    }
};

// Main render graph structure
pub const RenderGraph = struct {
    allocator: std.mem.Allocator,
    devices: []const *gfx.Device, // Multiple devices for multi-GPU
    
    // Resource pools
    buffers: std.ArrayList(BufferResource),
    images: std.ArrayList(ImageResource),
    blas_resources: std.ArrayList(BlasResource),
    tlas_resources: std.ArrayList(TlasResource),
    
    // Transient resource info
    transient_buffers: std.ArrayList(TransientBufferInfo),
    transient_images: std.ArrayList(TransientImageInfo),
    
    // Task management
    tasks: std.ArrayList(Task),
    task_batches: std.ArrayList(TaskBatch),
    
    // Permutation support
    condition_count: u32 = 0,
    condition_values: u32 = 0,
    
    // Options
    enable_reordering: bool = true,
    enable_aliasing: bool = true,
    use_split_barriers: bool = true,
    enable_multi_queue: bool = true,
    
    // Scratch memory for tasks
    scratch_memory_size: usize = 128 * 1024, // 128KB default
    
    // Debug info
    enable_debug_labels: bool = true,
    record_debug_info: bool = false,
    debug_info: std.ArrayList(u8),
    
    // Command pools for each device
    command_pools: []vk.CommandPool,
    
    const BufferResource = struct {
        handle: vk.Buffer,
        memory: vk.DeviceMemory,
        size: vk.DeviceSize,
        usage: vk.BufferUsageFlags,
        gpu_mask: GpuMask,
        is_transient: bool,
        lifetime: ResourceLifetime,
        generation: u8,
    };
    
    const ImageResource = struct {
        handle: vk.Image,
        memory: vk.DeviceMemory,
        extent: vk.Extent3D,
        format: vk.Format,
        usage: vk.ImageUsageFlags,
        gpu_mask: GpuMask,
        is_transient: bool,
        lifetime: ResourceLifetime,
        generation: u8,
        current_layout: vk.ImageLayout,
    };
    
    const BlasResource = struct {
        handle: vk.AccelerationStructureKHR,
        buffer: vk.Buffer,
        memory: vk.DeviceMemory,
        gpu_mask: GpuMask,
        generation: u8,
    };
    
    const TlasResource = struct {
        handle: vk.AccelerationStructureKHR,
        buffer: vk.Buffer,
        memory: vk.DeviceMemory,
        gpu_mask: GpuMask,
        is_transient: bool,
        lifetime: ResourceLifetime,
        generation: u8,
    };
    
    pub fn init(allocator: std.mem.Allocator, devices: []const *gfx.Device) !RenderGraph {
        // Create command pools for each device
        var command_pools = try allocator.alloc(vk.CommandPool, devices.len);
        errdefer allocator.free(command_pools);
        
        for (devices, 0..) |device, i| {
            const pool_info = vk.CommandPoolCreateInfo{
                .flags = .{ .reset_command_buffer_bit = true },
                .queue_family_index = device.graphics_queue_family,
            };
            const result = device.dispatch.vkCreateCommandPool.?(device.device, &pool_info, null, &command_pools[i]);
            if (result != .success) return error.VulkanError;
        }
        
        return RenderGraph{
            .allocator = allocator,
            .devices = devices,
            .buffers = std.ArrayList(BufferResource).init(allocator),
            .images = std.ArrayList(ImageResource).init(allocator),
            .blas_resources = std.ArrayList(BlasResource).init(allocator),
            .tlas_resources = std.ArrayList(TlasResource).init(allocator),
            .transient_buffers = std.ArrayList(TransientBufferInfo).init(allocator),
            .transient_images = std.ArrayList(TransientImageInfo).init(allocator),
            .tasks = std.ArrayList(Task).init(allocator),
            .task_batches = std.ArrayList(TaskBatch).init(allocator),
            .debug_info = std.ArrayList(u8).init(allocator),
            .command_pools = command_pools,
        };
    }
    
    pub fn deinit(self: *RenderGraph) void {
        // Clean up all resources
        for (self.buffers.items) |buffer| {
            if (buffer.handle != .null_handle) {
                for (self.devices, 0..) |device, gpu_index| {
                    if (buffer.gpu_mask.contains(@intCast(gpu_index))) {
                        device.dispatch.vkDestroyBuffer.?(device.device, buffer.handle, null);
                        device.dispatch.vkFreeMemory.?(device.device, buffer.memory, null);
                    }
                }
            }
        }
        
        for (self.images.items) |image| {
            if (image.handle != .null_handle) {
                for (self.devices, 0..) |device, gpu_index| {
                    if (image.gpu_mask.contains(@intCast(gpu_index))) {
                        device.dispatch.vkDestroyImage.?(device.device, image.handle, null);
                        device.dispatch.vkFreeMemory.?(device.device, image.memory, null);
                    }
                }
            }
        }
        
        self.buffers.deinit();
        self.images.deinit();
        self.blas_resources.deinit();
        self.tlas_resources.deinit();
        self.transient_buffers.deinit();
        self.transient_images.deinit();
        self.tasks.deinit();
        
        for (self.task_batches.items) |*batch| {
            batch.deinit();
        }
        self.task_batches.deinit();
        
        self.debug_info.deinit();
        
        // Destroy command pools
        for (self.command_pools, 0..) |pool, i| {
            self.devices[i].dispatch.vkDestroyCommandPool.?(self.devices[i].device, pool, null);
        }
        self.allocator.free(self.command_pools);
    }
    
    // Create transient resources
    pub fn createTransientBuffer(self: *RenderGraph, info: TransientBufferInfo) !TaskBufferView {
        const index = self.transient_buffers.items.len;
        try self.transient_buffers.append(info);
        
        // Add placeholder to buffers array
        try self.buffers.append(.{
            .handle = .null_handle,
            .memory = .null_handle,
            .size = info.size,
            .usage = info.usage,
            .gpu_mask = GpuMask.all(), // Will be determined during compilation
            .is_transient = true,
            .lifetime = .{},
            .generation = 0,
        });
        
        return TaskBufferView{
            .id = .{ .index = @intCast(index), .generation = 0 },
        };
    }
    
    pub fn createTransientImage(self: *RenderGraph, info: TransientImageInfo) !TaskImageView {
        const index = self.transient_images.items.len;
        try self.transient_images.append(info);
        
        // Add placeholder to images array
        try self.images.append(.{
            .handle = .null_handle,
            .memory = .null_handle,
            .extent = info.extent,
            .format = info.format,
            .usage = info.usage,
            .gpu_mask = GpuMask.all(),
            .is_transient = true,
            .lifetime = .{},
            .generation = 0,
            .current_layout = .undefined,
        });
        
        return TaskImageView{
            .id = .{ .index = @intCast(index), .generation = 0 },
        };
    }
    
    // Add persistent resources
    pub fn usePersistentBuffer(self: *RenderGraph, buffer: vk.Buffer, size: vk.DeviceSize, usage: vk.BufferUsageFlags, gpu_mask: GpuMask) !TaskBufferView {
        const index = self.buffers.items.len;
        try self.buffers.append(.{
            .handle = buffer,
            .memory = .null_handle, // Managed externally
            .size = size,
            .usage = usage,
            .gpu_mask = gpu_mask,
            .is_transient = false,
            .lifetime = .{},
            .generation = 0,
        });
        
        return TaskBufferView{
            .id = .{ .index = @intCast(index), .generation = 0 },
        };
    }
    
    pub fn usePersistentImage(self: *RenderGraph, image: vk.Image, extent: vk.Extent3D, format: vk.Format, usage: vk.ImageUsageFlags, gpu_mask: GpuMask) !TaskImageView {
        const index = self.images.items.len;
        try self.images.append(.{
            .handle = image,
            .memory = .null_handle,
            .extent = extent,
            .format = format,
            .usage = usage,
            .gpu_mask = gpu_mask,
            .is_transient = false,
            .lifetime = .{},
            .generation = 0,
            .current_layout = .undefined,
        });
        
        return TaskImageView{
            .id = .{ .index = @intCast(index), .generation = 0 },
        };
    }
    
    // Add tasks
    pub fn addTask(self: *RenderGraph, task: Task) !void {
        try self.tasks.append(task);
    }
    
    // Inline task builder pattern
    pub const InlineTask = struct {
        graph: *RenderGraph,
        task: Task,
        attachments: std.ArrayList(TaskAttachment),
        
        pub fn init(graph: *RenderGraph, name: []const u8, task_type: TaskType) InlineTask {
            return .{
                .graph = graph,
                .task = .{
                    .name = name,
                    .type = task_type,
                    .attachments = &.{},
                    .callback = undefined,
                },
                .attachments = std.ArrayList(TaskAttachment).init(graph.allocator),
            };
        }
        
        pub fn reads(self: *InlineTask, stage: PipelineStage, view: anytype) *InlineTask {
            const T = @TypeOf(view);
            const resource = switch (T) {
                TaskBufferView => blk: {
                    break :blk @unionInit(@TypeOf(TaskAttachment.resource), "buffer", view);
                },
                TaskImageView => blk: {
                    break :blk @unionInit(@TypeOf(TaskAttachment.resource), "image", view);
                },
                TaskBlasView => blk: {
                    break :blk @unionInit(@TypeOf(TaskAttachment.resource), "blas", view);
                },
                TaskTlasView => blk: {
                    break :blk @unionInit(@TypeOf(TaskAttachment.resource), "tlas", view);
                },
                else => blk: {
                    // Handle anonymous struct literals from FFI
                    const ResourceUnion = @TypeOf(@as(TaskAttachment, undefined).resource);
                    if (@hasField(T, "buffer")) {
                        break :blk @unionInit(ResourceUnion, "buffer", view.buffer);
                    } else if (@hasField(T, "image")) {
                        break :blk @unionInit(ResourceUnion, "image", view.image);
                    } else if (@hasField(T, "blas")) {
                        break :blk @unionInit(ResourceUnion, "blas", view.blas);
                    } else if (@hasField(T, "tlas")) {
                        break :blk @unionInit(ResourceUnion, "tlas", view.tlas);
                    } else {
                        // If it's already the resource union type, use it directly
                        break :blk view;
                    }
                },
            };
            
            const attachment = TaskAttachment{
                .name = "read_attachment",
                .access = .{ .read = true },
                .stage = stage,
                .resource = resource,
            };
            self.attachments.append(attachment) catch @panic("Failed to append attachment");
            return self;
        }
        
        pub fn writes(self: *InlineTask, stage: PipelineStage, view: anytype) *InlineTask {
            const T = @TypeOf(view);
            const resource = switch (T) {
                TaskBufferView => blk: {
                    break :blk @unionInit(@TypeOf(TaskAttachment.resource), "buffer", view);
                },
                TaskImageView => blk: {
                    break :blk @unionInit(@TypeOf(TaskAttachment.resource), "image", view);
                },
                TaskBlasView => blk: {
                    break :blk @unionInit(@TypeOf(TaskAttachment.resource), "blas", view);
                },
                TaskTlasView => blk: {
                    break :blk @unionInit(@TypeOf(TaskAttachment.resource), "tlas", view);
                },
                else => blk: {
                    // Handle anonymous struct literals from FFI
                    const ResourceUnion = @TypeOf(@as(TaskAttachment, undefined).resource);
                    if (@hasField(T, "buffer")) {
                        break :blk @unionInit(ResourceUnion, "buffer", view.buffer);
                    } else if (@hasField(T, "image")) {
                        break :blk @unionInit(ResourceUnion, "image", view.image);
                    } else if (@hasField(T, "blas")) {
                        break :blk @unionInit(ResourceUnion, "blas", view.blas);
                    } else if (@hasField(T, "tlas")) {
                        break :blk @unionInit(ResourceUnion, "tlas", view.tlas);
                    } else {
                        // If it's already the resource union type, use it directly
                        break :blk view;
                    }
                },
            };
            
            const attachment = TaskAttachment{
                .name = "write_attachment",
                .access = .{ .write = true },
                .stage = stage,
                .resource = resource,
            };
            self.attachments.append(attachment) catch @panic("Failed to append attachment");
            return self;
        }
        
        pub fn samples(self: *InlineTask, stage: PipelineStage, view: TaskImageView) *InlineTask {
            const attachment = TaskAttachment{
                .name = "sample_attachment",
                .access = .{ .read = true },
                .stage = stage,
                .resource = .{ .image = view },
            };
            self.attachments.append(attachment) catch @panic("Failed to append attachment");
            return self;
        }
        
        pub fn executes(self: *InlineTask, callback: *const fn (*TaskInterface) anyerror!void) !void {
            self.task.callback = callback;
            self.task.attachments = try self.attachments.toOwnedSlice();
            try self.graph.addTask(self.task);
        }
    };
    
    pub fn compute(self: *RenderGraph, name: []const u8) InlineTask {
        return InlineTask.init(self, name, .compute);
    }
    
    pub fn raster(self: *RenderGraph, name: []const u8) InlineTask {
        return InlineTask.init(self, name, .raster);
    }
    
    pub fn transfer(self: *RenderGraph, name: []const u8) InlineTask {
        return InlineTask.init(self, name, .transfer);
    }
    
    // Compile the render graph
    pub fn compile(self: *RenderGraph) !void {
        // 1. Analyze resource lifetimes
        try self.analyzeResourceLifetimes();
        
        // 2. Create task batches with automatic synchronization
        try self.createTaskBatches();
        
        // 3. Allocate transient resources with aliasing
        if (self.enable_aliasing) {
            try self.allocateTransientResourcesWithAliasing();
        } else {
            try self.allocateTransientResources();
        }
        
        // 4. Insert barriers between batches
        try self.insertBarriers();
        
        // 5. Optimize task order within batches
        if (self.enable_reordering) {
            try self.optimizeTaskOrder();
        }
    }
    
    fn analyzeResourceLifetimes(self: *RenderGraph) !void {
        // Reset lifetimes
        for (self.buffers.items) |*buffer| {
            buffer.lifetime = .{};
        }
        for (self.images.items) |*image| {
            image.lifetime = .{};
        }
        
        // Analyze each task
        for (self.tasks.items, 0..) |task, task_idx| {
            for (task.attachments) |attachment| {
                switch (attachment.resource) {
                    .buffer => |view| {
                        var buffer = &self.buffers.items[view.id.index];
                        buffer.lifetime.first_use_batch = @min(buffer.lifetime.first_use_batch, @as(u32, @intCast(task_idx)));
                        buffer.lifetime.last_use_batch = @max(buffer.lifetime.last_use_batch, @as(u32, @intCast(task_idx)));
                    },
                    .image => |view| {
                        var image = &self.images.items[view.id.index];
                        image.lifetime.first_use_batch = @min(image.lifetime.first_use_batch, @as(u32, @intCast(task_idx)));
                        image.lifetime.last_use_batch = @max(image.lifetime.last_use_batch, @as(u32, @intCast(task_idx)));
                    },
                    .blas, .tlas => {}, // TODO: Handle acceleration structures
                }
            }
        }
    }
    
    fn createTaskBatches(self: *RenderGraph) !void {
        var current_batch = TaskBatch.init(self.allocator, 0);
        var batch_writes = std.AutoHashMap(usize, void).init(self.allocator);
        defer batch_writes.deinit();
        
        for (self.tasks.items, 0..) |task, idx| {
            // Check if task can be added to current batch
            var can_batch = true;
            
            // Check for resource conflicts
            for (task.attachments) |attachment| {
                const resource_idx = switch (attachment.resource) {
                    .buffer => |view| view.id.index,
                    .image => |view| view.id.index + self.buffers.items.len,
                    .blas => |view| view.id.index + self.buffers.items.len + self.images.items.len,
                    .tlas => |view| view.id.index + self.buffers.items.len + self.images.items.len + self.blas_resources.items.len,
                };
                
                if (attachment.access.write) {
                    // Check if resource is already being written in this batch
                    if (batch_writes.contains(resource_idx)) {
                        can_batch = false;
                        break;
                    }
                } else if (attachment.access.read) {
                    // Check if resource is being written in this batch
                    if (batch_writes.contains(resource_idx)) {
                        can_batch = false;
                        break;
                    }
                }
            }
            
            // Check if tasks are on different queues
            if (current_batch.tasks.items.len > 0) {
                const first_task_type = self.tasks.items[current_batch.tasks.items[0]].type;
                if (task.type != first_task_type) {
                    can_batch = false;
                }
            }
            
            if (can_batch) {
                try current_batch.tasks.append(idx);
                // Track writes in this batch
                for (task.attachments) |attachment| {
                    if (attachment.access.write) {
                        const resource_idx = switch (attachment.resource) {
                            .buffer => |view| view.id.index,
                            .image => |view| view.id.index + self.buffers.items.len,
                            .blas => |view| view.id.index + self.buffers.items.len + self.images.items.len,
                            .tlas => |view| view.id.index + self.buffers.items.len + self.images.items.len + self.blas_resources.items.len,
                        };
                        try batch_writes.put(resource_idx, {});
                    }
                }
            } else {
                try self.task_batches.append(current_batch);
                current_batch = TaskBatch.init(self.allocator, 0);
                batch_writes.clearRetainingCapacity();
                try current_batch.tasks.append(idx);
                // Track writes in new batch
                for (task.attachments) |attachment| {
                    if (attachment.access.write) {
                        const resource_idx = switch (attachment.resource) {
                            .buffer => |view| view.id.index,
                            .image => |view| view.id.index + self.buffers.items.len,
                            .blas => |view| view.id.index + self.buffers.items.len + self.images.items.len,
                            .tlas => |view| view.id.index + self.buffers.items.len + self.images.items.len + self.blas_resources.items.len,
                        };
                        try batch_writes.put(resource_idx, {});
                    }
                }
            }
        }
        
        if (current_batch.tasks.items.len > 0) {
            try self.task_batches.append(current_batch);
        }
    }
    
    fn allocateTransientResources(self: *RenderGraph) !void {
        // Simple allocation without aliasing
        for (self.transient_buffers.items, 0..) |info, idx| {
            var buffer = &self.buffers.items[idx];
            
            // Create buffer for each GPU that needs it
            for (self.devices, 0..) |device, gpu_idx| {
                if (!buffer.gpu_mask.contains(@intCast(gpu_idx))) continue;
                
                const create_info = vk.BufferCreateInfo{
                    .size = info.size,
                    .usage = info.usage,
                    .sharing_mode = .exclusive,
                };
                
                const result = device.dispatch.vkCreateBuffer.?(device.device, &create_info, null, &buffer.handle);
                if (result != .success) return error.VulkanError;
                
                // Allocate memory
                var mem_reqs: vk.MemoryRequirements = undefined;
                device.dispatch.vkGetBufferMemoryRequirements.?(device.device, buffer.handle, &mem_reqs);
                const alloc_info = vk.MemoryAllocateInfo{
                    .allocation_size = mem_reqs.size,
                    .memory_type_index = try findMemoryType(device, mem_reqs.memory_type_bits, .{ .device_local_bit = true }),
                };
                
                const alloc_result = device.dispatch.vkAllocateMemory.?(device.device, &alloc_info, null, &buffer.memory);
                if (alloc_result != .success) return error.VulkanError;
                const bind_result = device.dispatch.vkBindBufferMemory.?(device.device, buffer.handle, buffer.memory, 0);
                if (bind_result != .success) return error.VulkanError;
            }
        }
    }
    
    fn allocateTransientResourcesWithAliasing(self: *RenderGraph) !void {
        // Group resources by non-overlapping lifetimes for memory aliasing
        const MemoryPool = struct {
            size: vk.DeviceSize,
            usage: vk.BufferUsageFlags,
            resources: std.ArrayList(usize),
        };
        var memory_pools = std.ArrayList(MemoryPool).init(self.allocator);
        defer {
            for (memory_pools.items) |*pool| {
                pool.resources.deinit();
            }
            memory_pools.deinit();
        }
        
        // Sort resources by lifetime for optimal packing
        const LocalResourceLifetime = struct {
            idx: usize,
            first_use: u32,
            last_use: u32,
            size: vk.DeviceSize,
            usage: vk.BufferUsageFlags,
            is_buffer: bool,
        };
        
        var lifetimes = std.ArrayList(LocalResourceLifetime).init(self.allocator);
        defer lifetimes.deinit();
        
        // Collect buffer lifetimes
        for (self.transient_buffers.items, 0..) |info, idx| {
            const buffer = &self.buffers.items[idx];
            try lifetimes.append(.{
                .idx = idx,
                .first_use = buffer.lifetime.first_use_batch,
                .last_use = buffer.lifetime.last_use_batch,
                .size = info.size,
                .usage = info.usage,
                .is_buffer = true,
            });
        }
        
        // Sort by first use time
        std.mem.sort(LocalResourceLifetime, lifetimes.items, {}, struct {
            fn lessThan(_: void, a: LocalResourceLifetime, b: LocalResourceLifetime) bool {
                return a.first_use < b.first_use;
            }
        }.lessThan);
        
        // Assign resources to memory pools based on non-overlapping lifetimes
        for (lifetimes.items) |lifetime| {
            var assigned = false;
            
            // Try to find an existing pool where this resource can be aliased
            for (memory_pools.items) |*pool| {
                // Check if usage is compatible
                if (pool.usage.toInt() != lifetime.usage.toInt()) continue;
                
                // Check if lifetime doesn't overlap with any resource in this pool
                var can_alias = true;
                for (pool.resources.items) |other_idx| {
                    // Get the lifetime info for the other resource
                    const other_first_use = if (lifetime.is_buffer)
                        self.buffers.items[other_idx].lifetime.first_use_batch
                    else
                        self.images.items[other_idx].lifetime.first_use_batch;
                    
                    const other_last_use = if (lifetime.is_buffer)
                        self.buffers.items[other_idx].lifetime.last_use_batch
                    else
                        self.images.items[other_idx].lifetime.last_use_batch;
                    
                    // Check for overlap
                    if (!(lifetime.last_use < other_first_use or 
                          lifetime.first_use > other_last_use)) {
                        can_alias = false;
                        break;
                    }
                }
                
                if (can_alias) {
                    pool.size = @max(pool.size, lifetime.size);
                    try pool.resources.append(lifetime.idx);
                    assigned = true;
                    break;
                }
            }
            
            // Create new pool if couldn't alias
            if (!assigned) {
                var new_pool = MemoryPool{
                    .size = lifetime.size,
                    .usage = lifetime.usage,
                    .resources = std.ArrayList(usize).init(self.allocator),
                };
                try new_pool.resources.append(lifetime.idx);
                try memory_pools.append(new_pool);
            }
        }
        
        // Allocate memory for each pool and assign to resources
        for (memory_pools.items) |pool| {
            // Create a single buffer for the entire pool
            for (self.devices, 0..) |device, gpu_idx| {
                const create_info = vk.BufferCreateInfo{
                    .size = pool.size,
                    .usage = pool.usage,
                    .sharing_mode = .exclusive,
                };
                
                var pool_buffer: vk.Buffer = undefined;
                const result = device.dispatch.vkCreateBuffer.?(device.device, &create_info, null, &pool_buffer);
                if (result != .success) return error.VulkanError;
                
                // Allocate memory for the pool
                var mem_reqs: vk.MemoryRequirements = undefined;
                device.dispatch.vkGetBufferMemoryRequirements.?(device.device, pool_buffer, &mem_reqs);
                const alloc_info = vk.MemoryAllocateInfo{
                    .allocation_size = mem_reqs.size,
                    .memory_type_index = try findMemoryType(device, mem_reqs.memory_type_bits, .{ .device_local_bit = true }),
                };
                
                var pool_memory: vk.DeviceMemory = undefined;
                const alloc_result = device.dispatch.vkAllocateMemory.?(device.device, &alloc_info, null, &pool_memory);
                if (alloc_result != .success) return error.VulkanError;
                
                // Bind and share memory among aliased resources
                const bind_result = device.dispatch.vkBindBufferMemory.?(device.device, pool_buffer, pool_memory, 0);
                if (bind_result != .success) return error.VulkanError;
                
                // Assign the same buffer/memory to all resources in this pool
                for (pool.resources.items) |resource_idx| {
                    var buffer = &self.buffers.items[resource_idx];
                    if (buffer.gpu_mask.contains(@intCast(gpu_idx))) {
                        buffer.handle = pool_buffer;
                        buffer.memory = pool_memory;
                    }
                }
            }
        }
    }
    
    fn insertBarriers(self: *RenderGraph) !void {
        // Track resource states across batches
        const ResourceState = struct {
            stage: PipelineStage = .none,
            access: vk.AccessFlags2 = .{},
            layout: vk.ImageLayout = .undefined,
        };
        
        const buffer_states = try self.allocator.alloc(ResourceState, self.buffers.items.len);
        defer self.allocator.free(buffer_states);
        const image_states = try self.allocator.alloc(ResourceState, self.images.items.len);
        defer self.allocator.free(image_states);
        
        // Initialize states
        for (buffer_states) |*state| {
            state.* = .{};
        }
        for (image_states) |*state| {
            state.* = .{};
        }
        
        // Process each batch and determine required barriers
        for (self.task_batches.items) |*batch| {
            // Collect all resource accesses in this batch
            var batch_buffer_states = try self.allocator.alloc(ResourceState, self.buffers.items.len);
            defer self.allocator.free(batch_buffer_states);
            var batch_image_states = try self.allocator.alloc(ResourceState, self.images.items.len);
            defer self.allocator.free(batch_image_states);
            
            // Initialize batch states
            for (batch_buffer_states) |*state| {
                state.* = .{};
            }
            for (batch_image_states) |*state| {
                state.* = .{};
            }
            
            // Analyze all tasks in the batch
            for (batch.tasks.items) |task_idx| {
                const task = self.tasks.items[task_idx];
                
                for (task.attachments) |attachment| {
                    switch (attachment.resource) {
                        .buffer => |view| {
                            var state = &batch_buffer_states[view.id.index];
                            // Combine stages and accesses
                            state.stage = combinePipelineStages(state.stage, attachment.stage);
                            if (attachment.access.read) {
                                state.access.shader_read_bit = true;
                                state.access.uniform_read_bit = true;
                                state.access.transfer_read_bit = true;
                            }
                            if (attachment.access.write) {
                                state.access.shader_write_bit = true;
                                state.access.transfer_write_bit = true;
                            }
                        },
                        .image => |view| {
                            var state = &batch_image_states[view.id.index];
                            state.stage = combinePipelineStages(state.stage, attachment.stage);
                            if (attachment.access.read) {
                                state.access.shader_read_bit = true;
                                state.access.input_attachment_read_bit = true;
                                state.access.transfer_read_bit = true;
                                // Determine layout based on usage
                                if (attachment.stage == .fragment_shader) {
                                    state.layout = .shader_read_only_optimal;
                                } else if (attachment.stage == .color_attachment_output) {
                                    state.layout = .color_attachment_optimal;
                                } else if (attachment.stage == .depth_stencil_attachment) {
                                    state.layout = .depth_stencil_attachment_optimal;
                                }
                            }
                            if (attachment.access.write) {
                                state.access.shader_write_bit = true;
                                state.access.color_attachment_write_bit = true;
                                state.access.depth_stencil_attachment_write_bit = true;
                                state.access.transfer_write_bit = true;
                                if (attachment.stage == .color_attachment_output) {
                                    state.layout = .color_attachment_optimal;
                                } else if (attachment.stage == .depth_stencil_attachment) {
                                    state.layout = .depth_stencil_attachment_optimal;
                                } else if (attachment.stage == .transfer) {
                                    state.layout = .transfer_dst_optimal;
                                } else {
                                    state.layout = .general;
                                }
                            }
                        },
                        .blas, .tlas => {
                            // Handle acceleration structures if needed
                        },
                    }
                }
            }
            
            // Generate barriers for state transitions
            for (buffer_states, batch_buffer_states, 0..) |*old_state, new_state, idx| {
                if (new_state.stage == .none) continue;
                
                // Check if we need a barrier
                var needs_barrier = false;
                var use_split_barrier = false;
                
                if (old_state.stage != .none) {
                    // Write-after-write, write-after-read, or read-after-write hazards
                    const old_has_write = old_state.access.shader_write_bit or 
                        old_state.access.color_attachment_write_bit or 
                        old_state.access.depth_stencil_attachment_write_bit or 
                        old_state.access.transfer_write_bit;
                    const new_has_write = new_state.access.shader_write_bit or 
                        new_state.access.color_attachment_write_bit or 
                        new_state.access.depth_stencil_attachment_write_bit or 
                        new_state.access.transfer_write_bit;
                    
                    if (old_has_write or new_has_write) {
                        needs_barrier = true;
                        
                        // Use split barrier if there's a significant gap between stages
                        // This allows other work to execute between the release and acquire
                        const stage_distance = getStageDistance(old_state.stage, new_state.stage);
                        if (stage_distance > 3) {
                            use_split_barrier = true;
                        }
                    }
                }
                
                if (needs_barrier) {
                    const buffer = &self.buffers.items[idx];
                    
                    if (use_split_barrier) {
                        // Release barrier at the end of the previous batch
                        if (batch.tasks.items.len > 0) {
                            const release_barrier = MemoryBarrier{
                                .src_stage_mask = old_state.stage,
                                .dst_stage_mask = .bottom_of_pipe,
                                .src_access_mask = old_state.access,
                                .dst_access_mask = .{},
                                .resource = .{ .buffer = .{
                                    .buffer = buffer.handle,
                                    .offset = 0,
                                    .size = vk.WHOLE_SIZE,
                                }},
                                .is_release = true,
                            };
                            // Add to previous batch if possible
                            if (self.task_batches.items.len > 0) {
                                const prev_batch_idx = self.task_batches.items.len - 1;
                                try self.task_batches.items[prev_batch_idx].post_barriers.append(release_barrier);
                            }
                        }
                        
                        // Acquire barrier at the beginning of this batch
                        const acquire_barrier = MemoryBarrier{
                            .src_stage_mask = .top_of_pipe,
                            .dst_stage_mask = new_state.stage,
                            .src_access_mask = .{},
                            .dst_access_mask = new_state.access,
                            .resource = .{ .buffer = .{
                                .buffer = buffer.handle,
                                .offset = 0,
                                .size = vk.WHOLE_SIZE,
                            }},
                            .is_acquire = true,
                        };
                        try batch.barriers.append(acquire_barrier);
                    } else {
                        // Single barrier
                        const barrier = MemoryBarrier{
                            .src_stage_mask = old_state.stage,
                            .dst_stage_mask = new_state.stage,
                            .src_access_mask = old_state.access,
                            .dst_access_mask = new_state.access,
                            .resource = .{ .buffer = .{
                                .buffer = buffer.handle,
                                .offset = 0,
                                .size = vk.WHOLE_SIZE,
                            }},
                        };
                        try batch.barriers.append(barrier);
                    }
                }
                
                // Update state
                old_state.* = new_state;
            }
            
            // Generate image barriers with split barrier support
            for (image_states, batch_image_states, 0..) |*old_state, new_state, idx| {
                if (new_state.stage == .none) continue;
                
                var needs_barrier = false;
                var use_split_barrier = false;
                var old_layout = old_state.layout;
                const new_layout = new_state.layout;
                
                if (old_state.stage != .none) {
                    // Layout transition or access hazard
                    const old_has_write = old_state.access.shader_write_bit or 
                        old_state.access.color_attachment_write_bit or 
                        old_state.access.depth_stencil_attachment_write_bit or 
                        old_state.access.transfer_write_bit;
                    const new_has_write = new_state.access.shader_write_bit or 
                        new_state.access.color_attachment_write_bit or 
                        new_state.access.depth_stencil_attachment_write_bit or 
                        new_state.access.transfer_write_bit;
                    
                    if (old_layout != new_layout or old_has_write or new_has_write) {
                        needs_barrier = true;
                        
                        // Use split barriers for expensive layout transitions
                        // Following Daxa's approach for optimal GPU utilization
                        if (old_layout != new_layout and old_layout != .undefined) {
                            const stage_distance = getStageDistance(old_state.stage, new_state.stage);
                            if (stage_distance > 2 or isExpensiveTransition(old_layout, new_layout)) {
                                use_split_barrier = true;
                            }
                        }
                    }
                } else {
                    // First use - transition from undefined
                    needs_barrier = true;
                    old_layout = .undefined;
                }
                
                if (needs_barrier) {
                    const image = &self.images.items[idx];
                    const aspect_mask = determineAspectMask(image.format);
                    
                    if (use_split_barrier) {
                        // Release barrier - make writes available
                        if (old_state.stage != .none) {
                            const release_barrier = MemoryBarrier{
                                .src_stage_mask = old_state.stage,
                                .dst_stage_mask = .bottom_of_pipe,
                                .src_access_mask = old_state.access,
                                .dst_access_mask = .{},
                                .resource = .{ .image = .{
                                    .image = image.handle,
                                    .old_layout = old_layout,
                                    .new_layout = old_layout, // Keep same layout for release
                                    .subresource_range = .{
                                        .aspect_mask = aspect_mask,
                                        .base_mip_level = 0,
                                        .level_count = vk.REMAINING_MIP_LEVELS,
                                        .base_array_layer = 0,
                                        .layer_count = vk.REMAINING_ARRAY_LAYERS,
                                    },
                                }},
                                .is_release = true,
                            };
                            
                            if (self.task_batches.items.len > 0) {
                                const prev_batch_idx = self.task_batches.items.len - 1;
                                try self.task_batches.items[prev_batch_idx].post_barriers.append(release_barrier);
                            }
                        }
                        
                        // Acquire barrier - make writes visible and transition layout
                        const acquire_barrier = MemoryBarrier{
                            .src_stage_mask = .top_of_pipe,
                            .dst_stage_mask = new_state.stage,
                            .src_access_mask = .{},
                            .dst_access_mask = new_state.access,
                            .resource = .{ .image = .{
                                .image = image.handle,
                                .old_layout = old_layout,
                                .new_layout = new_layout,
                                .subresource_range = .{
                                    .aspect_mask = aspect_mask,
                                    .base_mip_level = 0,
                                    .level_count = vk.REMAINING_MIP_LEVELS,
                                    .base_array_layer = 0,
                                    .layer_count = vk.REMAINING_ARRAY_LAYERS,
                                },
                            }},
                            .is_acquire = true,
                        };
                        try batch.barriers.append(acquire_barrier);
                    } else {
                        // Single barrier for simple transitions
                        const barrier = MemoryBarrier{
                            .src_stage_mask = if (old_state.stage == .none) .top_of_pipe else old_state.stage,
                            .dst_stage_mask = new_state.stage,
                            .src_access_mask = old_state.access,
                            .dst_access_mask = new_state.access,
                            .resource = .{ .image = .{
                                .image = image.handle,
                                .old_layout = old_layout,
                                .new_layout = new_layout,
                                .subresource_range = .{
                                    .aspect_mask = aspect_mask,
                                    .base_mip_level = 0,
                                    .level_count = vk.REMAINING_MIP_LEVELS,
                                    .base_array_layer = 0,
                                    .layer_count = vk.REMAINING_ARRAY_LAYERS,
                                },
                            }},
                        };
                        try batch.barriers.append(barrier);
                    }
                }
                
                // Update state
                old_state.* = new_state;
            }
        }
    }
    
    fn combinePipelineStages(a: PipelineStage, b: PipelineStage) PipelineStage {
        if (a == .none) return b;
        if (b == .none) return a;
        
        // Properly combine pipeline stages based on logical OR of stage flags
        // This ensures we wait for all necessary stages
        return switch (a) {
            .top_of_pipe => b,
            .bottom_of_pipe => .bottom_of_pipe,
            .all_commands => .all_commands,
            .all_graphics => if (b == .all_commands or b == .compute_shader or b == .transfer) .all_commands else .all_graphics,
            else => switch (b) {
                .top_of_pipe => a,
                .bottom_of_pipe => .bottom_of_pipe,
                .all_commands => .all_commands,
                .all_graphics => if (a == .compute_shader or a == .transfer) .all_commands else .all_graphics,
                else => {
                    // Combine specific stages
                    const a_order = getStageOrder(a);
                    const b_order = getStageOrder(b);
                    return if (a_order > b_order) a else b;
                },
            },
        };
    }
    
    fn getStageOrder(stage: PipelineStage) u32 {
        // Return the ordering of pipeline stages
        return switch (stage) {
            .none => 0,
            .top_of_pipe => 1,
            .indirect_command => 2,
            .index_input => 3,
            .vertex_shader => 4,
            .tessellation_control_shader => 5,
            .tessellation_evaluation_shader => 6,
            .geometry_shader => 7,
            .task_shader => 8,
            .mesh_shader => 9,
            .fragment_shader => 10,
            .depth_stencil_attachment => 11,
            .color_attachment => 12,
            .color_attachment_output => 13,
            .compute_shader => 14,
            .ray_tracing_shader => 15,
            .transfer => 16,
            .resolve => 17,
            .present => 18,
            .host => 19,
            .acceleration_structure_build => 20,
            .bottom_of_pipe => 21,
            .all_graphics => 22,
            .all_commands => 23,
        };
    }
    
    fn getStageDistance(src: PipelineStage, dst: PipelineStage) u32 {
        // Approximate pipeline stage ordering for split barrier decisions
        // Based on typical GPU pipeline ordering
        const stage_order = std.enums.directEnumArray(PipelineStage, u32, 0, .{
            .none = 0,
            .top_of_pipe = 1,
            .indirect_command = 2,
            .index_input = 3,
            .vertex_shader = 4,
            .tessellation_control_shader = 5,
            .tessellation_evaluation_shader = 6,
            .geometry_shader = 7,
            .task_shader = 8,
            .mesh_shader = 9,
            .fragment_shader = 10,
            .depth_stencil_attachment = 11,
            .color_attachment = 12,
            .color_attachment_output = 13,
            .compute_shader = 14,
            .ray_tracing_shader = 15,
            .transfer = 16,
            .resolve = 17,
            .present = 18,
            .host = 19,
            .acceleration_structure_build = 20,
            .bottom_of_pipe = 21,
            .all_graphics = 22,
            .all_commands = 23,
        });
        
        const src_order = stage_order[@intFromEnum(src)];
        const dst_order = stage_order[@intFromEnum(dst)];
        
        if (dst_order >= src_order) {
            return dst_order - src_order;
        } else {
            // Wrap around for cross-frame dependencies
            return 16 - src_order + dst_order;
        }
    }
    
    fn isExpensiveTransition(old_layout: vk.ImageLayout, new_layout: vk.ImageLayout) bool {
        // Transitions that benefit from split barriers
        // Based on Daxa's approach to expensive layout transitions
        const expensive_transitions = [_]struct { from: vk.ImageLayout, to: vk.ImageLayout }{
            .{ .from = .color_attachment_optimal, .to = .shader_read_only_optimal },
            .{ .from = .depth_stencil_attachment_optimal, .to = .shader_read_only_optimal },
            .{ .from = .transfer_dst_optimal, .to = .shader_read_only_optimal },
            .{ .from = .general, .to = .shader_read_only_optimal },
        };
        
        for (expensive_transitions) |transition| {
            if (old_layout == transition.from and new_layout == transition.to) {
                return true;
            }
        }
        
        return false;
    }
    
    fn determineAspectMask(format: vk.Format) vk.ImageAspectFlags {
        // Determine aspect mask based on format
        switch (format) {
            .d16_unorm, .d32_sfloat => return .{ .depth_bit = true },
            .d16_unorm_s8_uint, .d24_unorm_s8_uint, .d32_sfloat_s8_uint => {
                return .{ .depth_bit = true, .stencil_bit = true };
            },
            .s8_uint => return .{ .stencil_bit = true },
            else => return .{ .color_bit = true },
        }
    }
    
    fn convertPipelineStageToFlags2(stage: PipelineStage) vk.PipelineStageFlags2 {
        return switch (stage) {
            .none => .{},
            .top_of_pipe => .{ .top_of_pipe_bit = true },
            .vertex_shader => .{ .vertex_shader_bit = true },
            .tessellation_control_shader => .{ .tessellation_control_shader_bit = true },
            .tessellation_evaluation_shader => .{ .tessellation_evaluation_shader_bit = true },
            .geometry_shader => .{ .geometry_shader_bit = true },
            .fragment_shader => .{ .fragment_shader_bit = true },
            .task_shader => .{ .task_shader_bit_ext = true },
            .mesh_shader => .{ .mesh_shader_bit_ext = true },
            .compute_shader => .{ .compute_shader_bit = true },
            .ray_tracing_shader => .{ .ray_tracing_shader_bit_khr = true },
            .transfer => .{ .all_transfer_bit = true },
            .host => .{ .host_bit = true },
            .acceleration_structure_build => .{ .acceleration_structure_build_bit_khr = true },
            .color_attachment => .{ .color_attachment_output_bit = true },
            .color_attachment_output => .{ .color_attachment_output_bit = true },
            .depth_stencil_attachment => .{ .early_fragment_tests_bit = true, .late_fragment_tests_bit = true },
            .resolve => .{ .resolve_bit = true },
            .present => .{ .all_graphics_bit = true }, // Present doesn't have a specific bit, use all_graphics
            .indirect_command => .{ .draw_indirect_bit = true },
            .index_input => .{ .vertex_input_bit = true },
            .all_graphics => .{ .all_graphics_bit = true },
            .all_commands => .{ .all_commands_bit = true },
            .bottom_of_pipe => .{ .bottom_of_pipe_bit = true },
        };
    }
    
    fn convertAccessTypeToFlags2(access: AccessType) vk.AccessFlags2 {
        var result = vk.AccessFlags2{};
        if (access.read) {
            result.shader_read_bit = true;
            result.uniform_read_bit = true;
            result.transfer_read_bit = true;
            result.color_attachment_read_bit = true;
            result.depth_stencil_attachment_read_bit = true;
        }
        if (access.write) {
            result.shader_write_bit = true;
            result.transfer_write_bit = true;
            result.color_attachment_write_bit = true;
            result.depth_stencil_attachment_write_bit = true;
        }
        if (access.sampled) {
            result.shader_sampled_read_bit = true;
        }
        return result;
    }
    
    fn optimizeTaskOrder(self: *RenderGraph) !void {
        // Reorder tasks within batches to minimize state changes and improve cache efficiency
        // Based on Daxa's task graph optimization strategies
        
        for (self.task_batches.items) |*batch| {
            if (batch.tasks.items.len <= 1) continue;
            
            // Build dependency graph for tasks in this batch
            var dependencies = try self.allocator.alloc(std.DynamicBitSet, batch.tasks.items.len);
            defer {
                for (dependencies) |*dep| dep.deinit();
                self.allocator.free(dependencies);
            }
            
            for (dependencies) |*dep| {
                dep.* = try std.DynamicBitSet.initEmpty(self.allocator, batch.tasks.items.len);
            }
            
            // Analyze dependencies within the batch
            for (batch.tasks.items, 0..) |task_idx_a, local_idx_a| {
                const task_a = self.tasks.items[task_idx_a];
                
                for (batch.tasks.items, 0..) |task_idx_b, local_idx_b| {
                    if (local_idx_a == local_idx_b) continue;
                    
                    const task_b = self.tasks.items[task_idx_b];
                    
                    // Check if task_b depends on task_a
                    for (task_a.attachments) |attach_a| {
                        if (!attach_a.access.write) continue;
                        
                        for (task_b.attachments) |attach_b| {
                            const same_resource = switch (attach_a.resource) {
                                .buffer => |buf_a| switch (attach_b.resource) {
                                    .buffer => |buf_b| buf_a.id.index == buf_b.id.index,
                                    else => false,
                                },
                                .image => |img_a| switch (attach_b.resource) {
                                    .image => |img_b| img_a.id.index == img_b.id.index,
                                    else => false,
                                },
                                .blas => |blas_a| switch (attach_b.resource) {
                                    .blas => |blas_b| blas_a.id.index == blas_b.id.index,
                                    else => false,
                                },
                                .tlas => |tlas_a| switch (attach_b.resource) {
                                    .tlas => |tlas_b| tlas_a.id.index == tlas_b.id.index,
                                    else => false,
                                },
                            };
                            
                            if (same_resource) {
                                // task_b depends on task_a
                                dependencies[local_idx_b].set(local_idx_a);
                            }
                        }
                    }
                }
            }
            
            // Topological sort with cache optimization
            var sorted_indices = try std.ArrayList(usize).initCapacity(self.allocator, batch.tasks.items.len);
            defer sorted_indices.deinit();
            
            var visited = try std.DynamicBitSet.initEmpty(self.allocator, batch.tasks.items.len);
            defer visited.deinit();
            
            var visit_stack = std.ArrayList(usize).init(self.allocator);
            defer visit_stack.deinit();
            
            // Visit nodes in order that minimizes resource transitions
            for (0..batch.tasks.items.len) |start_idx| {
                if (visited.isSet(start_idx)) continue;
                
                try visit_stack.append(start_idx);
                
                while (visit_stack.items.len > 0) {
                    const current = visit_stack.items[visit_stack.items.len - 1];
                    
                    // Check if all dependencies are visited
                    var all_deps_visited = true;
                    var dep_iter = dependencies[current].iterator(.{});
                    while (dep_iter.next()) |dep_idx| {
                        if (!visited.isSet(dep_idx)) {
                            all_deps_visited = false;
                            try visit_stack.append(dep_idx);
                            break;
                        }
                    }
                    
                    if (all_deps_visited) {
                        _ = visit_stack.pop();
                        if (!visited.isSet(current)) {
                            visited.set(current);
                            try sorted_indices.append(current);
                        }
                    }
                }
            }
            
            // Reorder tasks based on sorted indices
            var new_task_indices = try self.allocator.alloc(usize, batch.tasks.items.len);
            defer self.allocator.free(new_task_indices);
            
            for (sorted_indices.items, 0..) |sorted_idx, new_idx| {
                new_task_indices[new_idx] = batch.tasks.items[sorted_idx];
            }
            
            @memcpy(batch.tasks.items, new_task_indices);
        }
    }
    
    // Execute the compiled graph
    pub fn execute(self: *RenderGraph, gpu_index: u32) !void {
        const device = self.devices[gpu_index];
        
        // Allocate command buffer from our pool
        const cmd_alloc_info = vk.CommandBufferAllocateInfo{
            .command_pool = self.command_pools[gpu_index],
            .level = .primary,
            .command_buffer_count = 1,
        };
        
        var cmd_buffer: vk.CommandBuffer = undefined;
        const alloc_result = device.dispatch.vkAllocateCommandBuffers.?(device.device, &cmd_alloc_info, @ptrCast(&cmd_buffer));
        if (alloc_result != .success) return error.VulkanError;
        defer device.dispatch.vkFreeCommandBuffers.?(device.device, self.command_pools[gpu_index], 1, @ptrCast(&cmd_buffer));
        
        // Begin command buffer
        const begin_result = device.dispatch.vkBeginCommandBuffer.?(cmd_buffer, &.{
            .flags = .{ .one_time_submit_bit = true },
        });
        if (begin_result != .success) return error.VulkanError;
        
        // Execute batches
        for (self.task_batches.items) |batch| {
            // Insert pre-batch barriers
            if (batch.barriers.items.len > 0) {
                try self.insertPipelineBarriers(device, cmd_buffer, batch.barriers.items);
            }
            
            // Execute tasks in batch
            for (batch.tasks.items) |task_idx| {
                const task = self.tasks.items[task_idx];
                
                // Check permutation conditions
                if (task.condition_mask != 0) {
                    if ((self.condition_values & task.condition_mask) != task.condition_value) {
                        continue; // Skip this task
                    }
                }
                
                // Create task interface
                const scratch_memory = try self.allocator.alloc(u8, self.scratch_memory_size);
                defer self.allocator.free(scratch_memory);
                
                var task_interface = TaskInterface{
                    .allocator = self.allocator,
                    .device = device,
                    .command_buffer = cmd_buffer,
                    .attachments = task.attachments,
                    .scratch_memory = scratch_memory,
                    .frame_index = 0, // TODO: Track frame index
                    .gpu_index = gpu_index,
                };
                
                // Debug label
                if (self.enable_debug_labels) {
                    try self.beginDebugLabel(device, cmd_buffer, task.name);
                }
                
                // Execute task
                try task.callback(&task_interface);
                
                if (self.enable_debug_labels) {
                    try self.endDebugLabel(device, cmd_buffer);
                }
            }
        }
        
        // End command buffer
        const end_result = device.dispatch.vkEndCommandBuffer.?(cmd_buffer);
        if (end_result != .success) return error.VulkanError;
        
        // Submit to queue
        const submit_info = vk.SubmitInfo{
            .command_buffer_count = 1,
            .p_command_buffers = @ptrCast(&cmd_buffer),
        };
        
        const submit_result = device.dispatch.vkQueueSubmit.?(device.graphics_queue, 1, @ptrCast(&submit_info), .null_handle);
        if (submit_result != .success) return error.VulkanError;
    }
    
    fn insertPipelineBarriers(self: *RenderGraph, device: *gfx.Device, cmd_buffer: vk.CommandBuffer, barriers: []const MemoryBarrier) !void {
        var memory_barriers = std.ArrayList(vk.MemoryBarrier2).init(self.allocator);
        var buffer_barriers = std.ArrayList(vk.BufferMemoryBarrier2).init(self.allocator);
        var image_barriers = std.ArrayList(vk.ImageMemoryBarrier2).init(self.allocator);
        defer memory_barriers.deinit();
        defer buffer_barriers.deinit();
        defer image_barriers.deinit();
        
        for (barriers) |barrier| {
            const src_stage_flags = convertPipelineStageToFlags2(barrier.src_stage_mask);
            const dst_stage_flags = convertPipelineStageToFlags2(barrier.dst_stage_mask);
            const src_access_flags = barrier.src_access_mask;
            const dst_access_flags = barrier.dst_access_mask;
            
            switch (barrier.resource) {
                .buffer => |buffer_info| {
                    try buffer_barriers.append(.{
                        .src_stage_mask = src_stage_flags,
                        .src_access_mask = src_access_flags,
                        .dst_stage_mask = dst_stage_flags,
                        .dst_access_mask = dst_access_flags,
                        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                        .buffer = buffer_info.buffer,
                        .offset = buffer_info.offset,
                        .size = buffer_info.size,
                    });
                },
                .image => |image_info| {
                    try image_barriers.append(.{
                        .src_stage_mask = src_stage_flags,
                        .src_access_mask = src_access_flags,
                        .dst_stage_mask = dst_stage_flags,
                        .dst_access_mask = dst_access_flags,
                        .old_layout = image_info.old_layout,
                        .new_layout = image_info.new_layout,
                        .src_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                        .dst_queue_family_index = vk.QUEUE_FAMILY_IGNORED,
                        .image = image_info.image,
                        .subresource_range = image_info.subresource_range,
                    });
                },
            }
        }
        
        const dependency_info = vk.DependencyInfo{
            .memory_barrier_count = @intCast(memory_barriers.items.len),
            .p_memory_barriers = memory_barriers.items.ptr,
            .buffer_memory_barrier_count = @intCast(buffer_barriers.items.len),
            .p_buffer_memory_barriers = buffer_barriers.items.ptr,
            .image_memory_barrier_count = @intCast(image_barriers.items.len),
            .p_image_memory_barriers = image_barriers.items.ptr,
        };
        
        device.dispatch.vkCmdPipelineBarrier2.?(cmd_buffer, &dependency_info);
    }
    
    fn beginDebugLabel(self: *RenderGraph, device: *gfx.Device, cmd_buffer: vk.CommandBuffer, name: []const u8) !void {
        _ = self;
        if (device.dispatch.vkCmdBeginDebugUtilsLabelEXT) |beginLabel| {
            // Create a null-terminated string
            var name_buf: [256]u8 = undefined;
            const name_z = try std.fmt.bufPrintZ(&name_buf, "{s}", .{name});
            
            const label = vk.DebugUtilsLabelEXT{
                .p_label_name = name_z,
                .color = .{ 0.5, 0.5, 1.0, 1.0 },
            };
            beginLabel(cmd_buffer, &label);
        }
    }
    
    fn endDebugLabel(self: *RenderGraph, device: *gfx.Device, cmd_buffer: vk.CommandBuffer) !void {
        _ = self;
        if (device.dispatch.vkCmdEndDebugUtilsLabelEXT) |endLabel| {
            endLabel(cmd_buffer);
        }
    }
    
    fn getBufferHandle(self: *RenderGraph, id: BufferId) !vk.Buffer {
        if (id.index >= self.buffers.items.len) return error.InvalidBufferId;
        const buffer = &self.buffers.items[id.index];
        if (buffer.generation != id.generation) return error.StaleBufferId;
        return buffer.handle;
    }
    
    fn getImageHandle(self: *RenderGraph, id: ImageId) !vk.Image {
        if (id.index >= self.images.items.len) return error.InvalidImageId;
        const image = &self.images.items[id.index];
        if (image.generation != id.generation) return error.StaleImageId;
        return image.handle;
    }
    
    fn findMemoryType(device_param: *gfx.Device, type_filter: u32, properties: vk.MemoryPropertyFlags) !u32 {
        _ = device_param;
        // Get memory properties from the physical device
        // We need to store these during initialization or get them from a parent context
        // For now, we'll implement a basic version that searches common memory types
        
        // Common memory type indices based on typical GPU configurations
        const common_mappings = [_]struct {
            properties: vk.MemoryPropertyFlags,
            typical_index: u32,
        }{
            // Device local memory for GPU-only resources
            .{ .properties = .{ .device_local_bit = true }, .typical_index = 1 },
            // Host visible + coherent for staging buffers
            .{ .properties = .{ .host_visible_bit = true, .host_coherent_bit = true }, .typical_index = 2 },
            // Host visible + device local for frequently updated GPU resources
            .{ .properties = .{ .device_local_bit = true, .host_visible_bit = true }, .typical_index = 3 },
        };
        
        // Try to find a matching memory type
        for (common_mappings) |mapping| {
            // Check if this type matches our requirements
            var matches = true;
            if (properties.device_local_bit and !mapping.properties.device_local_bit) matches = false;
            if (properties.host_visible_bit and !mapping.properties.host_visible_bit) matches = false;
            if (properties.host_coherent_bit and !mapping.properties.host_coherent_bit) matches = false;
            
            if (matches) {
                // Check if this type is in the filter
                if ((type_filter & (@as(u32, 1) << @intCast(mapping.typical_index))) != 0) {
                    return mapping.typical_index;
                }
            }
        }
        
        // Fallback: find first type in the filter that has the required properties
        // This is a simplified approach - in production, you'd query actual memory properties
        var i: u5 = 0;
        while (i < 32) : (i += 1) {
            if ((type_filter & (@as(u32, 1) << i)) != 0) {
                // For device local memory, prefer lower indices (typically GPU memory)
                if (properties.device_local_bit and i < 4) {
                    return i;
                }
                // For host visible memory, prefer middle indices
                if (properties.host_visible_bit and i >= 4 and i < 8) {
                    return i;
                }
            }
        }
        
        // Last resort: return first available type
        i = 0;
        while (i < 32) : (i += 1) {
            if ((type_filter & (@as(u32, 1) << i)) != 0) {
                return i;
            }
        }
        
        return error.NoSuitableMemoryType;
    }
};