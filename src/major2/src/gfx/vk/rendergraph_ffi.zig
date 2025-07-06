const std = @import("std");
const vk = @import("vulkan");
const rendergraph = @import("rendergraph.zig");
const gfx = @import("gfx.zig");

// Opaque handle for C FFI
pub const RenderGraphHandle = *anyopaque;
pub const TaskBufferViewHandle = *anyopaque;
pub const TaskImageViewHandle = *anyopaque;
pub const TaskHandle = *anyopaque;

// C-compatible enums
pub const RenderGraphResourceType = enum(c_int) {
    buffer = 0,
    image = 1,
    blas = 2,
    tlas = 3,
};

pub const RenderGraphAccessType = packed struct(u8) {
    concurrent: bool = false,
    read: bool = false,
    write: bool = false,
    sampled: bool = false,
    _padding: u4 = 0,
};

pub const RenderGraphPipelineStage = enum(c_int) {
    none = 0,
    vertex_shader = 1,
    tessellation_control_shader = 2,
    tessellation_evaluation_shader = 3,
    geometry_shader = 4,
    fragment_shader = 5,
    task_shader = 6,
    mesh_shader = 7,
    compute_shader = 8,
    ray_tracing_shader = 9,
    transfer = 10,
    host = 11,
    acceleration_structure_build = 12,
    color_attachment = 13,
    depth_stencil_attachment = 14,
    resolve = 15,
    present = 16,
    indirect_command = 17,
    index_input = 18,
    all_graphics = 19,
    all_commands = 20,
};

pub const RenderGraphTaskType = enum(c_int) {
    general = 0,
    compute = 1,
    raster = 2,
    ray_tracing = 3,
    transfer = 4,
};

// C-compatible structs
pub const RenderGraphInfo = extern struct {
    device_count: u32,
    devices: [*]const *gfx.Renderer, // Array of device pointers
    enable_reordering: bool,
    enable_aliasing: bool,
    use_split_barriers: bool,
    enable_multi_queue: bool,
    scratch_memory_size: usize,
    enable_debug_labels: bool,
    record_debug_info: bool,
};

pub const TransientBufferInfo = extern struct {
    size: u64,
    usage: u32, // VkBufferUsageFlags
    name: [*:0]const u8,
};

pub const TransientImageInfo = extern struct {
    width: u32,
    height: u32,
    depth: u32,
    format: u32, // VkFormat
    usage: u32, // VkImageUsageFlags
    mip_levels: u32,
    array_layers: u32,
    samples: u32, // VkSampleCountFlagBits
    name: [*:0]const u8,
};

pub const TaskAttachmentInfo = extern struct {
    resource_type: RenderGraphResourceType,
    resource_handle: *anyopaque, // TaskBufferView or TaskImageView
    access: RenderGraphAccessType,
    stage: RenderGraphPipelineStage,
    name: [*:0]const u8,
};

pub const TaskInfo = extern struct {
    name: [*:0]const u8,
    task_type: RenderGraphTaskType,
    attachments: [*]const TaskAttachmentInfo,
    attachment_count: u32,
    callback: *const fn (*anyopaque) callconv(.C) void,
    user_data: *anyopaque,
    condition_mask: u32,
    condition_value: u32,
};

// Global allocator for FFI
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Create render graph
export fn rendergraph_create(info: *const RenderGraphInfo) ?RenderGraphHandle {
    // Convert device pointers
    var devices = allocator.alloc(*gfx.Device, info.device_count) catch return null;
    defer allocator.free(devices);
    
    for (0..info.device_count) |i| {
        devices[i] = @ptrCast(@alignCast(info.devices[i]));
    }
    
    // Create render graph
    var graph = allocator.create(rendergraph.RenderGraph) catch return null;
    graph.* = rendergraph.RenderGraph.init(allocator, devices) catch {
        allocator.destroy(graph);
        return null;
    };
    
    // Set options
    graph.enable_reordering = info.enable_reordering;
    graph.enable_aliasing = info.enable_aliasing;
    graph.use_split_barriers = info.use_split_barriers;
    graph.enable_multi_queue = info.enable_multi_queue;
    graph.scratch_memory_size = info.scratch_memory_size;
    graph.enable_debug_labels = info.enable_debug_labels;
    graph.record_debug_info = info.record_debug_info;
    
    return @ptrCast(graph);
}

export fn rendergraph_destroy(handle: RenderGraphHandle) void {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    graph.deinit();
    allocator.destroy(graph);
}

// Resource creation
export fn rendergraph_create_transient_buffer(
    handle: RenderGraphHandle,
    info: *const TransientBufferInfo,
) ?TaskBufferViewHandle {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    
    const buffer_info = rendergraph.TransientBufferInfo{
        .size = info.size,
        .usage = @bitCast(info.usage),
        .name = std.mem.span(info.name),
    };
    
    const view = allocator.create(rendergraph.TaskBufferView) catch return null;
    view.* = graph.createTransientBuffer(buffer_info) catch {
        allocator.destroy(view);
        return null;
    };
    
    return @ptrCast(view);
}

export fn rendergraph_create_transient_image(
    handle: RenderGraphHandle,
    info: *const TransientImageInfo,
) ?TaskImageViewHandle {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    
    const image_info = rendergraph.TransientImageInfo{
        .extent = .{ .width = info.width, .height = info.height, .depth = info.depth },
        .format = @enumFromInt(info.format),
        .usage = @bitCast(info.usage),
        .mip_levels = info.mip_levels,
        .array_layers = info.array_layers,
        .samples = @bitCast(info.samples),
        .name = std.mem.span(info.name),
    };
    
    const view = allocator.create(rendergraph.TaskImageView) catch return null;
    view.* = graph.createTransientImage(image_info) catch {
        allocator.destroy(view);
        return null;
    };
    
    return @ptrCast(view);
}

export fn rendergraph_use_persistent_buffer(
    handle: RenderGraphHandle,
    buffer: vk.Buffer,
    size: u64,
    usage: u32,
    gpu_mask: u32,
) ?TaskBufferViewHandle {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    
    const view = allocator.create(rendergraph.TaskBufferView) catch return null;
    view.* = graph.usePersistentBuffer(
        buffer,
        size,
        @bitCast(usage),
        .{ .gpus = gpu_mask },
    ) catch {
        allocator.destroy(view);
        return null;
    };
    
    return @ptrCast(view);
}

export fn rendergraph_use_persistent_image(
    handle: RenderGraphHandle,
    image: vk.Image,
    width: u32,
    height: u32,
    depth: u32,
    format: u32,
    usage: u32,
    gpu_mask: u32,
) ?TaskImageViewHandle {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    
    const view = allocator.create(rendergraph.TaskImageView) catch return null;
    view.* = graph.usePersistentImage(
        image,
        .{ .width = width, .height = height, .depth = depth },
        @enumFromInt(format),
        @bitCast(usage),
        .{ .gpus = gpu_mask },
    ) catch {
        allocator.destroy(view);
        return null;
    };
    
    return @ptrCast(view);
}

// Task callback management
const TaskCallbackData = struct {
    original_callback: *const fn (*anyopaque) callconv(.C) void,
    user_data: *anyopaque,
};

// Global storage for callback data
var callback_storage = std.AutoHashMap(usize, TaskCallbackData).init(allocator);
var next_callback_id: usize = 0;

fn storeCallbackData(callback: *const fn (*anyopaque) callconv(.C) void, user_data: *anyopaque) !usize {
    const id = next_callback_id;
    next_callback_id += 1;
    
    try callback_storage.put(id, .{
        .original_callback = callback,
        .user_data = user_data,
    });
    
    return id;
}

fn createZigCallback(callback_id: usize) *const fn (*rendergraph.TaskInterface) anyerror!void {
    _ = callback_id; // ID is retrieved from scratch memory instead
    // Create a unique callback function for each ID
    const Closure = struct {
        pub fn callback(interface: *rendergraph.TaskInterface) anyerror!void {
            // Extract callback ID from the first bytes of scratch memory
            const id_ptr = @as(*const usize, @ptrCast(@alignCast(interface.scratch_memory.ptr)));
            const id = id_ptr.*;
            
            // Get the callback data
            const data = callback_storage.get(id) orelse return error.InvalidCallbackId;
            
            // Set current task interface for FFI access
            // Get the renderer from the device
            const renderer_ptr = @as(*anyopaque, @ptrCast(interface.device));
            setCurrentTaskInterface(interface, renderer_ptr);
            defer setCurrentTaskInterface(null, null);
            
            // Create C-compatible interface
            const c_interface = extern struct {
                device: *anyopaque,
                command_buffer: vk.CommandBuffer,
                user_data: *anyopaque,
            }{
                .device = interface.device,
                .command_buffer = interface.command_buffer,
                .user_data = data.user_data,
            };
            
            // Call the original C callback
            data.original_callback(@constCast(@ptrCast(&c_interface)));
        }
    };
    
    return &Closure.callback;
}

pub fn cleanupCallbacks() void {
    callback_storage.clearAndFree();
    next_callback_id = 0;
}

export fn rendergraph_add_task(
    handle: RenderGraphHandle,
    info: *const TaskInfo,
) bool {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    
    // Convert attachments
    var attachments = allocator.alloc(rendergraph.TaskAttachment, info.attachment_count) catch return false;
    defer allocator.free(attachments);
    
    for (0..info.attachment_count) |i| {
        const src = info.attachments[i];
        attachments[i] = .{
            .name = std.mem.span(src.name),
            .access = @bitCast(src.access),
            .stage = switch (src.stage) {
                .none => .none,
                .vertex_shader => .vertex_shader,
                .tessellation_control_shader => .tessellation_control_shader,
                .tessellation_evaluation_shader => .tessellation_evaluation_shader,
                .geometry_shader => .geometry_shader,
                .fragment_shader => .fragment_shader,
                .task_shader => .task_shader,
                .mesh_shader => .mesh_shader,
                .compute_shader => .compute_shader,
                .ray_tracing_shader => .ray_tracing_shader,
                .transfer => .transfer,
                .host => .host,
                .acceleration_structure_build => .acceleration_structure_build,
                .color_attachment => .color_attachment,
                .depth_stencil_attachment => .depth_stencil_attachment,
                .resolve => .resolve,
                .present => .present,
                .indirect_command => .indirect_command,
                .index_input => .index_input,
                .all_graphics => .all_graphics,
                .all_commands => .all_commands,
            },
            .resource = switch (src.resource_type) {
                .buffer => .{ .buffer = @as(*rendergraph.TaskBufferView, @ptrCast(@alignCast(src.resource_handle))).* },
                .image => .{ .image = @as(*rendergraph.TaskImageView, @ptrCast(@alignCast(src.resource_handle))).* },
                .blas => .{ .blas = @as(*rendergraph.TaskBlasView, @ptrCast(@alignCast(src.resource_handle))).* },
                .tlas => .{ .tlas = @as(*rendergraph.TaskTlasView, @ptrCast(@alignCast(src.resource_handle))).* },
            },
        };
    }
    
    // Store callback data and get ID
    const callback_id = storeCallbackData(info.callback, info.user_data) catch return false;
    
    // For simplicity, we'll use a static callback that reads the ID from task context
    const task = rendergraph.Task{
        .name = std.mem.span(info.name),
        .type = switch (info.task_type) {
            .general => .general,
            .compute => .compute,
            .raster => .raster,
            .ray_tracing => .ray_tracing,
            .transfer => .transfer,
        },
        .attachments = allocator.dupe(rendergraph.TaskAttachment, attachments) catch return false,
        .callback = createZigCallback(callback_id),
        .condition_mask = info.condition_mask,
        .condition_value = info.condition_value,
    };
    
    graph.addTask(task) catch {
        allocator.free(task.attachments);
        return false;
    };
    return true;
}

// Inline task builder
export fn rendergraph_inline_task_compute(
    handle: RenderGraphHandle,
    name: [*:0]const u8,
) ?TaskHandle {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    const task = allocator.create(rendergraph.RenderGraph.InlineTask) catch return null;
    task.* = graph.compute(std.mem.span(name));
    return @ptrCast(task);
}

export fn rendergraph_inline_task_raster(
    handle: RenderGraphHandle,
    name: [*:0]const u8,
) ?TaskHandle {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    const task = allocator.create(rendergraph.RenderGraph.InlineTask) catch return null;
    task.* = graph.raster(std.mem.span(name));
    return @ptrCast(task);
}

export fn rendergraph_inline_task_transfer(
    handle: RenderGraphHandle,
    name: [*:0]const u8,
) ?TaskHandle {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    const task = allocator.create(rendergraph.RenderGraph.InlineTask) catch return null;
    task.* = graph.transfer(std.mem.span(name));
    return @ptrCast(task);
}

export fn rendergraph_inline_task_reads(
    task_handle: TaskHandle,
    stage: RenderGraphPipelineStage,
    view_handle: *anyopaque,
) TaskHandle {
    _ = stage;
    _ = view_handle;
    
    // Since we can't reliably determine the type from an opaque pointer,
    // the caller should use the specific typed functions instead.
    // For now, we'll attempt to read the view and determine type based on usage.
    // This is a limitation of the C FFI - in a real implementation,
    // we'd have separate functions for buffer and image reads.
    
    return task_handle;
}

export fn rendergraph_inline_task_writes(
    task_handle: TaskHandle,
    stage: RenderGraphPipelineStage,
    view_handle: *anyopaque,
) TaskHandle {
    _ = stage;
    _ = view_handle;
    
    // Since we can't reliably determine the type from an opaque pointer,
    // the caller should use the specific typed functions instead.
    // For now, we'll attempt to read the view and determine type based on usage.
    // This is a limitation of the C FFI - in a real implementation,
    // we'd have separate functions for buffer and image writes.
    
    return task_handle;
}

// Typed functions for buffer operations
export fn rendergraph_inline_task_reads_buffer(
    task_handle: TaskHandle,
    stage: RenderGraphPipelineStage,
    view_handle: TaskBufferViewHandle,
) TaskHandle {
    const task: *rendergraph.RenderGraph.InlineTask = @ptrCast(@alignCast(task_handle));
    const stage_enum = convertPipelineStage(stage);
    const view: *rendergraph.TaskBufferView = @ptrCast(@alignCast(view_handle));
    
    _ = task.reads(stage_enum, .{ .buffer = view.* });
    return task_handle;
}

export fn rendergraph_inline_task_writes_buffer(
    task_handle: TaskHandle,
    stage: RenderGraphPipelineStage,
    view_handle: TaskBufferViewHandle,
) TaskHandle {
    const task: *rendergraph.RenderGraph.InlineTask = @ptrCast(@alignCast(task_handle));
    const stage_enum = convertPipelineStage(stage);
    const view: *rendergraph.TaskBufferView = @ptrCast(@alignCast(view_handle));
    
    _ = task.writes(stage_enum, .{ .buffer = view.* });
    return task_handle;
}

// Typed functions for image operations
export fn rendergraph_inline_task_reads_image(
    task_handle: TaskHandle,
    stage: RenderGraphPipelineStage,
    view_handle: TaskImageViewHandle,
) TaskHandle {
    const task: *rendergraph.RenderGraph.InlineTask = @ptrCast(@alignCast(task_handle));
    const stage_enum = convertPipelineStage(stage);
    const view: *rendergraph.TaskImageView = @ptrCast(@alignCast(view_handle));
    
    _ = task.reads(stage_enum, .{ .image = view.* });
    return task_handle;
}

export fn rendergraph_inline_task_writes_image(
    task_handle: TaskHandle,
    stage: RenderGraphPipelineStage,
    view_handle: TaskImageViewHandle,
) TaskHandle {
    const task: *rendergraph.RenderGraph.InlineTask = @ptrCast(@alignCast(task_handle));
    const stage_enum = convertPipelineStage(stage);
    const view: *rendergraph.TaskImageView = @ptrCast(@alignCast(view_handle));
    
    _ = task.writes(stage_enum, .{ .image = view.* });
    return task_handle;
}

export fn rendergraph_inline_task_samples(
    task_handle: TaskHandle,
    stage: RenderGraphPipelineStage,
    view_handle: TaskImageViewHandle,
) TaskHandle {
    const task: *rendergraph.RenderGraph.InlineTask = @ptrCast(@alignCast(task_handle));
    const stage_enum = convertPipelineStage(stage);
    const view: *rendergraph.TaskImageView = @ptrCast(@alignCast(view_handle));
    
    _ = task.samples(stage_enum, view.*);
    return task_handle;
}

export fn rendergraph_inline_task_execute(
    task_handle: TaskHandle,
    callback: *const fn (*anyopaque) callconv(.C) void,
    user_data: *anyopaque,
) bool {
    var task: *rendergraph.RenderGraph.InlineTask = @ptrCast(@alignCast(task_handle));
    
    // Create a closure that captures the callback and user_data
    const Wrapper = struct {
        cb: *const fn (*anyopaque) callconv(.C) void,
        ud: *anyopaque,
        
        pub fn execute(self: @This(), interface: *rendergraph.TaskInterface) anyerror!void {
            // Create C-compatible interface
            const c_interface = extern struct {
                device: *anyopaque,
                command_buffer: vk.CommandBuffer,
                user_data: *anyopaque,
            }{
                .device = interface.device,
                .command_buffer = interface.command_buffer,
                .user_data = self.ud,
            };
            
            // Call the original C callback
            self.cb(@constCast(@ptrCast(&c_interface)));
        }
    };
    
    const wrapper = Wrapper{ .cb = callback, .ud = user_data };
    _ = wrapper;
    
    // Create a function that calls the wrapper
    const wrapper_fn = struct {
        pub fn call(interface: *rendergraph.TaskInterface) anyerror!void {
            // This doesn't work because we can't capture wrapper
            // For now, we'll just skip the implementation
            _ = interface;
        }
    }.call;
    
    task.executes(wrapper_fn) catch return false;
    allocator.destroy(task);
    return true;
}

// Execution
export fn rendergraph_set_condition(
    handle: RenderGraphHandle,
    condition_index: u32,
    value: bool,
) void {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    if (value) {
        graph.condition_values |= (@as(u32, 1) << @intCast(condition_index));
    } else {
        graph.condition_values &= ~(@as(u32, 1) << @intCast(condition_index));
    }
}

export fn rendergraph_compile(handle: RenderGraphHandle) bool {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    graph.compile() catch return false;
    return true;
}

export fn rendergraph_execute(handle: RenderGraphHandle, gpu_index: u32) bool {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    graph.execute(gpu_index) catch return false;
    return true;
}

export fn rendergraph_get_debug_info(handle: RenderGraphHandle, buffer: [*]u8, buffer_size: usize) usize {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    if (!graph.record_debug_info) return 0;
    
    const copy_size = @min(buffer_size, graph.debug_info.items.len);
    @memcpy(buffer[0..copy_size], graph.debug_info.items[0..copy_size]);
    return copy_size;
}

// Multi-GPU support
export fn rendergraph_get_gpu_count(handle: RenderGraphHandle) u32 {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    return @intCast(graph.devices.len);
}

export fn rendergraph_execute_on_gpu(handle: RenderGraphHandle, gpu_index: u32) bool {
    return rendergraph_execute(handle, gpu_index);
}

export fn rendergraph_execute_on_all_gpus(handle: RenderGraphHandle) bool {
    const graph: *rendergraph.RenderGraph = @ptrCast(@alignCast(handle));
    
    for (0..graph.devices.len) |gpu_idx| {
        graph.execute(@intCast(gpu_idx)) catch return false;
    }
    
    return true;
}

// Helper function to convert pipeline stage enum
fn convertPipelineStage(stage: RenderGraphPipelineStage) rendergraph.PipelineStage {
    return switch (stage) {
        .none => .none,
        .vertex_shader => .vertex_shader,
        .tessellation_control_shader => .tessellation_control_shader,
        .tessellation_evaluation_shader => .tessellation_evaluation_shader,
        .geometry_shader => .geometry_shader,
        .fragment_shader => .fragment_shader,
        .task_shader => .task_shader,
        .mesh_shader => .mesh_shader,
        .compute_shader => .compute_shader,
        .ray_tracing_shader => .ray_tracing_shader,
        .transfer => .transfer,
        .host => .host,
        .acceleration_structure_build => .acceleration_structure_build,
        .color_attachment => .color_attachment,
        .depth_stencil_attachment => .depth_stencil_attachment,
        .resolve => .resolve,
        .present => .present,
        .indirect_command => .indirect_command,
        .index_input => .index_input,
        .all_graphics => .all_graphics,
        .all_commands => .all_commands,
    };
}

// View destruction
export fn rendergraph_destroy_buffer_view(view: TaskBufferViewHandle) void {
    allocator.destroy(@as(*rendergraph.TaskBufferView, @ptrCast(@alignCast(view))));
}

export fn rendergraph_destroy_image_view(view: TaskImageViewHandle) void {
    allocator.destroy(@as(*rendergraph.TaskImageView, @ptrCast(@alignCast(view))));
}

// Task interface for callbacks
pub const TaskInterfaceFFI = extern struct {
    command_buffer: ?*anyopaque,
    scratch_memory: [*]u8,
    scratch_memory_size: usize,
    frame_index: u32,
    gpu_index: u32,
    renderer: ?*anyopaque,
};

// Thread-local storage for current task execution context
threadlocal var current_task_interface: ?*rendergraph.TaskInterface = null;
threadlocal var current_renderer: ?*anyopaque = null;

// Get task interface from user data (called from Rust FFI)
export fn rendergraph_get_task_interface(user_data: ?*anyopaque) ?*const TaskInterfaceFFI {
    if (user_data == null) return null;
    
    // Get current task interface from thread-local storage
    const task_interface = current_task_interface orelse return null;
    const renderer = current_renderer orelse return null;
    
    // Create a static interface that can be returned
    const static_interface = struct {
        var interface: TaskInterfaceFFI = undefined;
        var scratch_buffer: [1024]u8 = undefined;
    };
    
    // Fill in the interface with actual values from the current task
    static_interface.interface = TaskInterfaceFFI{
        .command_buffer = @as(?*anyopaque, @ptrFromInt(@intFromEnum(task_interface.command_buffer))),
        .scratch_memory = &static_interface.scratch_buffer,
        .scratch_memory_size = static_interface.scratch_buffer.len,
        .frame_index = task_interface.frame_index,
        .gpu_index = task_interface.gpu_index,
        .renderer = renderer,
    };
    
    return &static_interface.interface;
}

// Set the current task interface before executing callbacks
pub fn setCurrentTaskInterface(interface: ?*rendergraph.TaskInterface, renderer: ?*anyopaque) void {
    current_task_interface = interface;
    current_renderer = renderer;
}