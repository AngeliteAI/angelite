const std = @import("std");
const builtin = std.builtin;
// Import vulkan directly - we know it will be available through the build system
const vk = @import("vulkan");
const os = std.os;

const vertex_pool = @import("vertex_pool.zig");

// Export C interface functions for Rust FFI
pub export fn renderer_init() ?*Renderer {
    const renderer = std.heap.c_allocator.create(Renderer) catch return null;
    renderer.* = Renderer.init(std.heap.c_allocator) catch {
        std.heap.c_allocator.destroy(renderer);
        return null;
    };
    return renderer;
}

pub export fn renderer_deinit(renderer: ?*Renderer) void {
    if (renderer) |renderer_ptr| {
        renderer_ptr.deinit();
        std.heap.c_allocator.destroy(renderer_ptr);
    }
}

pub export fn renderer_init_vertex_pool(
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

pub export fn renderer_request_buffer(renderer: ?*Renderer) u32 {
    if (renderer) |r| {
        return (r.requestBuffer() catch return std.math.maxInt(u32)) orelse std.math.maxInt(u32);
    }
    return std.math.maxInt(u32);
}

pub export fn renderer_add_mesh(
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

pub export fn renderer_update_vertices(
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

pub export fn renderer_update_normals(
    renderer: ?*Renderer,
    buffer_idx: u32,
    normals_ptr: [*]const u8,
    vertex_count: u32,
) bool {
    if (renderer) |r| {
        // Convert raw normals pointer to slice of Vertex (contains position, normal, color)
        const vertices_bytes = @as([*]const u8, @ptrCast(normals_ptr))[0 .. vertex_count * @sizeOf(vertex_pool.Vertex)];
        const vertices = std.mem.bytesAsSlice(vertex_pool.Vertex, vertices_bytes);

        // Update only the normal component in the buffer
        if (buffer_idx < r.vertex_pool.?.stage_buffers.items.len) {
            const stage = &r.vertex_pool.?.stage_buffers.items[buffer_idx];

            if (stage.mapped_memory) |mapped| {
                const dest_vertices = @as([*]vertex_pool.Vertex, @ptrCast(@alignCast(mapped)))[0..vertex_count];

                // Copy only normal data for each vertex
                for (0..vertex_count) |i| {
                    dest_vertices[i].normal = vertices[i].normal;
                }

                return true;
            }
        }
    }
    return false;
}

pub export fn renderer_update_colors(
    renderer: ?*Renderer,
    buffer_idx: u32,
    colors_ptr: [*]const u8,
    vertex_count: u32,
) bool {
    if (renderer) |r| {
        // Convert raw colors pointer to slice of Vertex (contains position, normal, color)
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

pub export fn renderer_release_buffer(
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

pub export fn renderer_mask_by_facing(
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

pub export fn renderer_order_front_to_back(
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

pub export fn renderer_begin_frame(renderer: ?*Renderer) bool {
    if (renderer) |r| {
        // Create a command pool if we don't have one yet
        if (r.command_pool == .null_handle) {
            const command_pool_create_info = vk.CommandPoolCreateInfo{
                .queue_family_index = r.device.graphics_queue_family,
                .flags = .{ .transient_bit = true, .reset_command_buffer_bit = true },
            };

            var pool: vk.CommandPool = undefined;
            if (r.device.dispatch.vkCreateCommandPool.?(r.device.device, &command_pool_create_info, null, &pool) != .success) {
                std.debug.print("Failed to create command pool\n", .{});
                return false;
            }
            r.command_pool = pool;
        }

        // Prepare for rendering
        if (r.device.dispatch.vkQueueWaitIdle.?(r.device.graphics_queue) == .success) {
            // Ready to render
        } else {
            std.debug.print("Failed to wait for queue idle\n", .{});
            return false;
        }
        return true;
    }
    return false;
}

pub export fn renderer_render(renderer: ?*Renderer) bool {
    if (renderer) |r| {
        if (r.vertex_pool) |_| {
            if (r.command_pool == .null_handle) {
                std.debug.print("Command pool not initialized\n", .{});
                return false;
            }

            // Allocate a command buffer
            const command_buffer_allocate_info = vk.CommandBufferAllocateInfo{
                .command_pool = r.command_pool,
                .level = .primary,
                .command_buffer_count = 1,
            };

            var command_buffer: vk.CommandBuffer = undefined;
            _ = r.device.dispatch.vkAllocateCommandBuffers.?(r.device.device, &command_buffer_allocate_info, @ptrCast(&command_buffer));
            // Begin command buffer recording
            const begin_info = vk.CommandBufferBeginInfo{
                .flags = .{ .one_time_submit_bit = true },
                .p_inheritance_info = null,
            };

            _ = r.device.dispatch.vkBeginCommandBuffer.?(command_buffer, &begin_info);
            // Begin a render pass if we have one
            if (r.render_pass != .null_handle) {
                // Skip actual render pass for now since we don't have a framebuffer
                // We'll still proceed with the pipeline binding and drawing
            }

            // Bind the graphics pipeline
            if (r.pipeline != .null_handle) {
                r.device.dispatch.vkCmdBindPipeline.?(command_buffer, .graphics, r.pipeline);
            }

            // Render the vertex pool
            r.renderVertexPool(command_buffer) catch |err| {
                std.debug.print("Failed to render vertex pool: {}\n", .{err});
                return false;
            };

            // No render pass to end since we didn't begin one

            // End command buffer recording
            _ = r.device.dispatch.vkEndCommandBuffer.?(command_buffer);
            const submit_info = vk.SubmitInfo{
                .command_buffer_count = 1,
                .p_command_buffers = @ptrCast(&command_buffer),
                .wait_semaphore_count = 0,
                .p_wait_semaphores = undefined,
                .p_wait_dst_stage_mask = undefined,
                .signal_semaphore_count = 0,
                .p_signal_semaphores = undefined,
            };

            _ = r.device.dispatch.vkQueueSubmit.?(r.device.graphics_queue, 1, @as(?[*]const vk.SubmitInfo, @ptrCast(&submit_info)), .null_handle);

            // Free the command buffer if anything failed
            r.device.dispatch.vkFreeCommandBuffers.?(r.device.device, r.command_pool, 1, @ptrCast(@alignCast(&command_buffer)));
            return true;
        }
    }
    return false;
}

pub export fn renderer_end_frame(renderer: ?*Renderer) bool {
    std.debug.print("Ending frame\n", .{});
    if (renderer) |r| {
        // Wait for rendering to complete
        const wait_result = r.device.dispatch.vkQueueWaitIdle.?(r.device.graphics_queue);
        if (wait_result == .success) {
            return true;
        } else {
            std.debug.print("Failed to wait for queue idle\n", .{});
            return false;
        }
    }
    return false;
}

// Vertex pool module is imported at the top of the file

/// The instance is the connection between the application and the Vulkan library
/// It's the first thing that needs to be created when working with Vulkan
const Instance = struct {
    instance: vk.Instance,
    dispatch: vk.InstanceDispatch,

    // Extension names to enable
    const required_extensions = [_][*:0]const u8{
        // Common extensions
        // Platform-specific extensions can be added here
        "KHR_win32_surface",
        "KHR_surface",
    };

    /// Create a new Vulkan instance
    pub fn init(_: std.mem.Allocator) !Instance {
        // Load the Vulkan library
        std.debug.print("Loading vulkan base dispatch...\n", .{});
        // Initialize a new BaseDispatch - in vulkan-zig we can't use load() directly
        var vkb = vk.BaseDispatch{};

        // Manually load the first function we need
        vkb.vkGetInstanceProcAddr = @as(vk.PfnGetInstanceProcAddr, @ptrCast(getPlatformSpecificProcAddress("vkGetInstanceProcAddr")));

        if (vkb.vkGetInstanceProcAddr == null) {
            return error.FailedToLoadVulkan;
        }

        // Now load the CreateInstance function
        vkb.vkCreateInstance = @as(vk.PfnCreateInstance, @ptrCast(vkb.vkGetInstanceProcAddr.?(vk.Instance.null_handle, "vkCreateInstance")));

        if (vkb.vkCreateInstance == null) {
            return error.FailedToLoadVulkan;
        }

        vkb.vkEnumerateInstanceExtensionProperties = @as(vk.PfnEnumerateInstanceExtensionProperties, @ptrCast(vkb.vkGetInstanceProcAddr.?(vk.Instance.null_handle, "vkEnumerateInstanceExtensionProperties")));
        std.debug.print("Vulkan base dispatch loaded successfully\n", .{});

        // Set up the application info struct
        const app_info = vk.ApplicationInfo{
            .p_application_name = "Angelite",
            .application_version = 1,
            .p_engine_name = "Angelite Engine",
            .engine_version = 1 << 22,
            .api_version = 1 << 22,
        };

        // Create the instance info struct
        const create_info = vk.InstanceCreateInfo{
            .p_application_info = &app_info,
            .enabled_extension_count = @intCast(required_extensions.len),
            .pp_enabled_extension_names = &required_extensions,
            // Enable validation layers in debug mode
            .enabled_layer_count = if (std.debug.runtime_safety) @as(u32, 1) else 0,
            .pp_enabled_layer_names = if (std.debug.runtime_safety)
                &[_][*:0]const u8{"VK_LAYER_KHRONOS_validation"}
            else
                undefined,
        };

        // Create the Vulkan instance
        std.debug.print("Creating vulkan instance...\n", .{});
        var instance: vk.Instance = undefined;
        try checkSuccess(vkb.vkCreateInstance.?(&create_info, null, &instance));
        std.debug.print("Vulkan instance created successfully\n", .{});

        // Load instance-level function pointers
        std.debug.print("Loading instance dispatch...\n", .{});

        // Create a new instance dispatch table
        var dispatch = vk.InstanceDispatch{};

        // Load the required instance functions
        // Start with the essential functions
        dispatch.vkDestroyInstance = @as(vk.PfnDestroyInstance, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkDestroyInstance")));
        dispatch.vkEnumeratePhysicalDevices = @as(vk.PfnEnumeratePhysicalDevices, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkEnumeratePhysicalDevices")));
        dispatch.vkGetPhysicalDeviceProperties = @as(vk.PfnGetPhysicalDeviceProperties, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkGetPhysicalDeviceProperties")));
        dispatch.vkGetPhysicalDeviceFeatures = @as(vk.PfnGetPhysicalDeviceFeatures, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkGetPhysicalDeviceFeatures")));
        dispatch.vkGetPhysicalDeviceMemoryProperties = @as(vk.PfnGetPhysicalDeviceMemoryProperties, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkGetPhysicalDeviceMemoryProperties")));
        dispatch.vkGetPhysicalDeviceQueueFamilyProperties = @as(vk.PfnGetPhysicalDeviceQueueFamilyProperties, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkGetPhysicalDeviceQueueFamilyProperties")));
        dispatch.vkCreateDevice = @as(vk.PfnCreateDevice, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkCreateDevice")));

        // Load surface related functions
        dispatch.vkDestroySurfaceKHR = @as(vk.PfnDestroySurfaceKHR, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkDestroySurfaceKHR")));
        dispatch.vkGetPhysicalDeviceSurfaceSupportKHR = @as(vk.PfnGetPhysicalDeviceSurfaceSupportKHR, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkGetPhysicalDeviceSurfaceSupportKHR")));
        dispatch.vkGetPhysicalDeviceSurfaceCapabilitiesKHR = @as(vk.PfnGetPhysicalDeviceSurfaceCapabilitiesKHR, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkGetPhysicalDeviceSurfaceCapabilitiesKHR")));
        dispatch.vkGetPhysicalDeviceSurfaceFormatsKHR = @as(vk.PfnGetPhysicalDeviceSurfaceFormatsKHR, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkGetPhysicalDeviceSurfaceFormatsKHR")));
        dispatch.vkGetPhysicalDeviceSurfacePresentModesKHR = @as(vk.PfnGetPhysicalDeviceSurfacePresentModesKHR, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkGetPhysicalDeviceSurfacePresentModesKHR")));

        // Windows-specific surface creation function
        dispatch.vkCreateWin32SurfaceKHR = @as(vk.PfnCreateWin32SurfaceKHR, @ptrCast(vkb.vkGetInstanceProcAddr.?(instance, "vkCreateWin32SurfaceKHR")));

        std.debug.print("Instance dispatch loaded successfully\n", .{});

        return Instance{
            .instance = instance,
            .dispatch = dispatch,
        };
    }

    /// Clean up the Vulkan instance
    pub fn deinit(self: Instance) void {
        if (self.dispatch.vkDestroyInstance) |destroyInstance| {
            destroyInstance(self.instance, null);
        }
    }
};

/// A physical device (GPU) available on the system
const PhysicalDevice = struct {
    handle: vk.PhysicalDevice,
    properties: vk.PhysicalDeviceProperties,
    features: vk.PhysicalDeviceFeatures,
    memory_properties: vk.PhysicalDeviceMemoryProperties,
    graphics_queue_family: u32,
};

/// The logical device is our connection to a physical device
/// Device struct for managing logical device functions
pub const Device = struct {
    physical_device: PhysicalDevice,
    device: vk.Device,
    dispatch: vk.DeviceDispatch,
    graphics_queue: vk.Queue,
    graphics_queue_family: u32,

    /// Load device-specific function pointers
    pub fn loadDeviceDispatch(device: vk.Device, instance_dispatch: vk.InstanceDispatch) !vk.DeviceDispatch {
        var dispatch: vk.DeviceDispatch = .{};

        // Load device functions using vkGetDeviceProcAddr
        const DeviceDispatchType = @TypeOf(dispatch);
        inline for (@typeInfo(DeviceDispatchType).@"struct".fields) |field| {
            const name = @as([*:0]const u8, @ptrCast(field.name));
            @field(dispatch, field.name) = @ptrCast(instance_dispatch.vkGetDeviceProcAddr.?(device, name));
        }

        return dispatch;
    }

    /// Create a new logical device
    pub fn init(allocator: std.mem.Allocator, instance: Instance) !Device {
        // Find a suitable physical device
        std.debug.print("Initializing Vulkan renderer...\n", .{});
        const physical_device = try pickPhysicalDevice(allocator, instance);

        // Device queue create info
        const queue_create_info = [_]vk.DeviceQueueCreateInfo{
            .{
                .queue_family_index = physical_device.graphics_queue_family,
                .queue_count = 1,
                .p_queue_priorities = &[_]f32{1.0},
            },
        };

        // Create the logical device
        const device_create_info = vk.DeviceCreateInfo{
            .queue_create_info_count = queue_create_info.len,
            .p_queue_create_infos = &queue_create_info,
            .enabled_extension_count = 0,
            .pp_enabled_extension_names = undefined,
            .p_enabled_features = &physical_device.features,
        };

        var device: vk.Device = undefined;
        std.debug.print("Initializing Vulkan renderer...\n", .{});
        try checkSuccess(instance.dispatch.vkCreateDevice.?(physical_device.handle, &device_create_info, null, &device));

        // Load device-level function pointers
        std.debug.print("Initializing Vulkan renderer...\n", .{});
        const dispatch = try loadDeviceDispatch(device, instance.dispatch);

        // Get the graphics queue
        var graphics_queue: vk.Queue = undefined;
        std.debug.print("Initializing Vulkan renderer...\n", .{});
        dispatch.vkGetDeviceQueue.?(device, physical_device.graphics_queue_family, 0, &graphics_queue);

        return Device{
            .physical_device = physical_device,
            .device = device,
            .dispatch = dispatch,
            .graphics_queue = graphics_queue,
            .graphics_queue_family = physical_device.graphics_queue_family,
        };
    }

    /// Clean up the logical device
    /// Clean up the Device
    pub fn deinit(self: Device) void {
        if (self.dispatch.vkDestroyDevice) |destroyDevice| {
            destroyDevice(self.device, null);
        }
    }
};

/// Helper function to pick a suitable physical device
fn pickPhysicalDevice(allocator: std.mem.Allocator, instance: Instance) !PhysicalDevice {
    // Enumerate physical devices
    var device_count: u32 = 0;
    std.debug.print("Initializing Vulkan renderer...\n", .{});
    std.debug.print("Enumerating physical devices...\n", .{});
    try checkSuccess(instance.dispatch.vkEnumeratePhysicalDevices.?(instance.instance, &device_count, null));
    std.debug.print("Found {} physical devices\n", .{device_count});

    if (device_count == 0) {
        return error.NoVulkanDevices;
    }

    const devices = try allocator.alloc(vk.PhysicalDevice, device_count);
    defer allocator.free(devices);

    std.debug.print("Initializing Vulkan renderer...\n", .{});
    try checkSuccess(instance.dispatch.vkEnumeratePhysicalDevices.?(instance.instance, &device_count, devices.ptr));

    // For now, just pick the first device
    const selected_device = devices[0];

    // Get device properties and features
    var properties: vk.PhysicalDeviceProperties = undefined;
    var features: vk.PhysicalDeviceFeatures = undefined;
    var memory_properties: vk.PhysicalDeviceMemoryProperties = undefined;

    std.debug.print("Initializing Vulkan renderer...\n", .{});
    _ = instance.dispatch.vkGetPhysicalDeviceProperties.?(selected_device, &properties);
    _ = instance.dispatch.vkGetPhysicalDeviceFeatures.?(selected_device, &features);
    _ = instance.dispatch.vkGetPhysicalDeviceMemoryProperties.?(selected_device, &memory_properties);

    // Find graphics queue family
    var queue_family_count: u32 = 0;
    _ = instance.dispatch.vkGetPhysicalDeviceQueueFamilyProperties.?(selected_device, &queue_family_count, null);

    const queue_families = try allocator.alloc(vk.QueueFamilyProperties, queue_family_count);
    defer allocator.free(queue_families);

    std.debug.print("Initializing Vulkan renderer...\n", .{});
    _ = instance.dispatch.vkGetPhysicalDeviceQueueFamilyProperties.?(selected_device, &queue_family_count, queue_families.ptr);

    // Find a queue family that supports graphics
    var graphics_queue_family: ?u32 = null;
    for (queue_families, 0..) |queue_props, i| {
        if (queue_props.queue_flags.graphics_bit) {
            graphics_queue_family = @intCast(i);
            break;
        }
    }

    if (graphics_queue_family == null) {
        return error.NoGraphicsQueue;
    }

    return PhysicalDevice{
        .handle = selected_device,
        .properties = properties,
        .features = features,
        .memory_properties = memory_properties,
        .graphics_queue_family = graphics_queue_family.?,
    };
}

/// Check a Vulkan result and return an error if it's not success
fn checkSuccess(result: anytype) !void {
    if (result != .success) {
        std.debug.print("Vulkan error: {any}\n", .{result});
        return error.VulkanError;
    }
}

/// Function to get Vulkan function pointers
fn getProcAddress(instance: vk.Instance, name: [*:0]const u8) vk.PfnVoidFunction {
    // If we have a valid instance, try to get instance-specific functions
    if (instance != .null_handle) {
        if (@hasDecl(vk, "vkGetInstanceProcAddr")) {
            const func = vk.vkGetInstanceProcAddr(instance, name);
            if (func != null) {
                return func;
            }
        }
    }

    // Otherwise use the platform-specific approach
    return @as(vk.PfnVoidFunction, @ptrCast(getPlatformSpecificProcAddress(name)));
}

// Windows-specific implementation for loading Vulkan functions
fn getPlatformSpecificProcAddress(name: [*:0]const u8) ?*const anyopaque {
    const windows = struct {
        const HMODULE = *opaque {};
        const LPCSTR = [*:0]const u8;
        const FARPROC = *const anyopaque;

        extern "kernel32" fn LoadLibraryA(lpLibFileName: LPCSTR) ?HMODULE;
        extern "kernel32" fn GetProcAddress(hModule: HMODULE, lpProcName: LPCSTR) ?FARPROC;
    };

    // Load the Vulkan library if not already loaded
    const vulkan_dll_name = "vulkan-1.dll";

    // Use thread-local static storage for the handle to avoid reloading
    const vulkan_handle = blk: {
        const ThreadLocal = struct {
            var handle: ?windows.HMODULE = null;
        };

        if (ThreadLocal.handle == null) {
            ThreadLocal.handle = windows.LoadLibraryA(vulkan_dll_name);
            if (ThreadLocal.handle == null) {
                std.debug.print("Failed to load {s}\n", .{vulkan_dll_name});
                return null;
            }
        }

        break :blk ThreadLocal.handle.?;
    };

    // Get the function pointer
    const proc_addr = windows.GetProcAddress(vulkan_handle, name);
    if (proc_addr == null) {
        // This is expected for some functions, so no need to log every time
        // std.debug.print("Failed to get proc address for {s}\n", .{name});
    }

    return proc_addr;
}

/// Main renderer that manages the Vulkan instance and device
pub const Renderer = struct {
    allocator: std.mem.Allocator,
    instance: Instance,
    device: Device,
    vertex_pool: ?vertex_pool.VertexPool = null,

    // Pipeline resources
    render_pass: vk.RenderPass = .null_handle,
    pipeline_layout: vk.PipelineLayout = .null_handle,
    pipeline: vk.Pipeline = .null_handle,
    command_pool: vk.CommandPool = .null_handle,

    // Swapchain resources (would be used in a real implementation)
    surface: vk.SurfaceKHR = .null_handle,
    swapchain: vk.SwapchainKHR = .null_handle,
    swapchain_images: std.ArrayList(vk.Image) = undefined,
    swapchain_image_views: std.ArrayList(vk.ImageView) = undefined,
    swapchain_framebuffers: std.ArrayList(vk.Framebuffer) = undefined,
    swapchain_extent: vk.Extent2D = .{ .width = 0, .height = 0 },

    // Synchronization primitives
    image_available_semaphores: std.ArrayList(vk.Semaphore) = undefined,

    /// Initialize the Vulkan renderer
    pub fn init(allocator: std.mem.Allocator) !Renderer {
        std.debug.print("Initializing Vulkan renderer...\n", .{});
        var instance = try Instance.init(allocator);
        std.debug.print("Initializing Vulkan renderer...\n", .{});
        errdefer instance.deinit();

        std.debug.print("Initializing Vulkan renderer...\n", .{});
        var device = try Device.init(allocator, instance);
        std.debug.print("Initializing Vulkan renderer...\n", .{});
        errdefer device.deinit();

        const renderer = Renderer{
            .allocator = allocator,
            .instance = instance,
            .device = device,
            .swapchain_images = undefined,
            .swapchain_image_views = undefined,
            .swapchain_framebuffers = undefined,
            .image_available_semaphores = undefined,
        };

        return renderer;
    }

    /// Initialize the vertex pool
    pub fn initVertexPool(self: *Renderer, buffer_count: u32, vertex_per_buffer: u32, max_draw_commands: u32) !void {
        if (self.vertex_pool != null) {
            return error.VertexPoolAlreadyInitialized;
        }

        // Create command pool first (needed for buffer operations)
        const command_pool_info = vk.CommandPoolCreateInfo{
            .queue_family_index = self.device.graphics_queue_family,
            .flags = .{},
        };

        var pool: vk.CommandPool = undefined;
        if (self.device.dispatch.vkCreateCommandPool.?(self.device.device, &command_pool_info, null, &pool) != .success) {
            return error.FailedToCreateCommandPool;
        }
        self.command_pool = pool;

        // Create basic rendering resources
        try self.createRenderingResources();

        // Initialize vertex pool
        self.vertex_pool = try vertex_pool.VertexPool.init(self.allocator, self.device.device, self.device.physical_device.handle, self.device.dispatch, self.instance.dispatch, buffer_count, vertex_per_buffer, max_draw_commands);
    }

    fn createRenderingResources(self: *Renderer) !void {
        // Create a basic render pass (would need to be customized for your app)
        const color_attachment = vk.AttachmentDescription{
            .format = .b8g8r8a8_unorm, // Typical swapchain format
            .samples = .{ .@"1_bit" = true },
            .load_op = .clear,
            .store_op = .store,
            .stencil_load_op = .dont_care,
            .stencil_store_op = .dont_care,
            .initial_layout = .undefined,
            .final_layout = .present_src_khr,
        };

        const color_attachment_ref = vk.AttachmentReference{
            .attachment = 0,
            .layout = .color_attachment_optimal,
        };

        const subpass = vk.SubpassDescription{
            .pipeline_bind_point = .graphics,
            .color_attachment_count = 1,
            .p_color_attachments = @ptrCast(&color_attachment_ref),
            .p_depth_stencil_attachment = null,
            .input_attachment_count = 0,
            .p_input_attachments = undefined,
            .p_resolve_attachments = null,
            .preserve_attachment_count = 0,
            .p_preserve_attachments = undefined,
        };

        const render_pass_info = vk.RenderPassCreateInfo{
            .attachment_count = 1,
            .p_attachments = @ptrCast(&color_attachment),
            .subpass_count = 1,
            .p_subpasses = @ptrCast(&subpass),
            .dependency_count = 0,
            .p_dependencies = undefined,
        };

        _ = self.device.dispatch.vkCreateRenderPass.?(self.device.device, &render_pass_info, null, &self.render_pass);

        // Create pipeline layout
        const pipeline_layout_info = vk.PipelineLayoutCreateInfo{
            .set_layout_count = 0,
            .p_set_layouts = undefined,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
        };

        _ = self.device.dispatch.vkCreatePipelineLayout.?(self.device.device, &pipeline_layout_info, null, &self.pipeline_layout);

        // Create a basic graphics pipeline
        // This is a simplified implementation that would need to be expanded with proper
        // shader modules for a real application

        // In a real application, you would load shader modules from files
        // For now, we'll create a very basic vertex shader and fragment shader

        // Vertex input state - describes the format of the vertex data
        const vertex_input_binding_description = vk.VertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(vertex_pool.Vertex),
            .input_rate = .vertex,
        };

        // Position attribute
        const vertex_input_attribute_descriptions = [_]vk.VertexInputAttributeDescription{
            // Position
            .{
                .binding = 0,
                .location = 0,
                .format = .r32g32b32_sfloat,
                .offset = @offsetOf(vertex_pool.Vertex, "position"),
            },
            // Normal
            .{
                .binding = 0,
                .location = 1,
                .format = .r32g32b32_sfloat,
                .offset = @offsetOf(vertex_pool.Vertex, "normal"),
            },
            // Color
            .{
                .binding = 0,
                .location = 2,
                .format = .r32g32b32a32_sfloat,
                .offset = @offsetOf(vertex_pool.Vertex, "color"),
            },
        };

        const vertex_input_state_create_info = vk.PipelineVertexInputStateCreateInfo{
            .vertex_binding_description_count = 1,
            .p_vertex_binding_descriptions = @as(?[*]const vk.VertexInputBindingDescription, @ptrCast(&vertex_input_binding_description)),
            .vertex_attribute_description_count = vertex_input_attribute_descriptions.len,
            .p_vertex_attribute_descriptions = &vertex_input_attribute_descriptions,
        };

        // Input assembly state - describes what kind of primitives to render
        const input_assembly_state_create_info = vk.PipelineInputAssemblyStateCreateInfo{
            .topology = .triangle_list,
            .primitive_restart_enable = vk.FALSE,
        };

        // Viewport state - describes the viewport and scissors
        const viewport = vk.Viewport{
            .x = 0.0,
            .y = 0.0,
            .width = 800.0, // Would use swapchain extent in a real app
            .height = 600.0, // Would use swapchain extent in a real app
            .min_depth = 0.0,
            .max_depth = 1.0,
        };

        const scissor = vk.Rect2D{
            .offset = .{ .x = 0, .y = 0 },
            .extent = .{ .width = 800, .height = 600 }, // Would use swapchain extent in a real app
        };

        const viewport_state_create_info = vk.PipelineViewportStateCreateInfo{
            .viewport_count = 1,
            .p_viewports = @as(?[*]const vk.Viewport, @ptrCast(&viewport)),
            .scissor_count = 1,
            .p_scissors = @as(?[*]const vk.Rect2D, @ptrCast(&scissor)),
        };

        // Rasterization state - describes how to rasterize primitives
        const rasterization_state_create_info = vk.PipelineRasterizationStateCreateInfo{
            .depth_clamp_enable = vk.FALSE,
            .rasterizer_discard_enable = vk.FALSE,
            .polygon_mode = .fill,
            .cull_mode = .{ .back_bit = true },
            .front_face = .counter_clockwise,
            .depth_bias_enable = vk.FALSE,
            .depth_bias_constant_factor = 0.0,
            .depth_bias_clamp = 0.0,
            .depth_bias_slope_factor = 0.0,
            .line_width = 1.0,
        };

        // Multisample state - describes multisampling parameters
        const multisample_state_create_info = vk.PipelineMultisampleStateCreateInfo{
            .rasterization_samples = .{ .@"1_bit" = true },
            .sample_shading_enable = vk.FALSE,
            .min_sample_shading = 1.0,
            .p_sample_mask = null,
            .alpha_to_coverage_enable = vk.FALSE,
            .alpha_to_one_enable = vk.FALSE,
        };

        // Depth and stencil state - describes depth and stencil testing
        const depth_stencil_state_create_info = vk.PipelineDepthStencilStateCreateInfo{
            .depth_test_enable = vk.TRUE,
            .depth_write_enable = vk.TRUE,
            .depth_compare_op = .less,
            .depth_bounds_test_enable = vk.FALSE,
            .stencil_test_enable = vk.FALSE,
            .front = .{
                .fail_op = .keep,
                .pass_op = .keep,
                .depth_fail_op = .keep,
                .compare_op = .always,
                .compare_mask = 0,
                .write_mask = 0,
                .reference = 0,
            },
            .back = .{
                .fail_op = .keep,
                .pass_op = .keep,
                .depth_fail_op = .keep,
                .compare_op = .always,
                .compare_mask = 0,
                .write_mask = 0,
                .reference = 0,
            },
            .min_depth_bounds = 0.0,
            .max_depth_bounds = 1.0,
        };

        // Color blend state - describes how to blend colors
        const color_blend_attachment_state = vk.PipelineColorBlendAttachmentState{
            .blend_enable = vk.TRUE,
            .src_color_blend_factor = .src_alpha,
            .dst_color_blend_factor = .one_minus_src_alpha,
            .color_blend_op = .add,
            .src_alpha_blend_factor = .one,
            .dst_alpha_blend_factor = .zero,
            .alpha_blend_op = .add,
            .color_write_mask = .{ .r_bit = true, .g_bit = true, .b_bit = true, .a_bit = true },
        };

        const color_blend_state_create_info = vk.PipelineColorBlendStateCreateInfo{
            .logic_op_enable = vk.FALSE,
            .logic_op = .copy,
            .attachment_count = 1,
            .p_attachments = @as(?[*]const vk.PipelineColorBlendAttachmentState, @ptrCast(&color_blend_attachment_state)),
            .blend_constants = [4]f32{ 0.0, 0.0, 0.0, 0.0 },
        };

        // In a real application, you would load shader modules from files
        // For now, we'll just create placeholder shaders that would be replaced
        // with actual shader code in a real implementation

        // Create the pipeline
        // Create a minimal pipeline for rendering
        _ = vertex_input_state_create_info;
        _ = input_assembly_state_create_info;
        _ = viewport_state_create_info;
        _ = rasterization_state_create_info;
        _ = multisample_state_create_info;
        _ = depth_stencil_state_create_info;
        _ = color_blend_state_create_info;
        // We don't actually create the pipeline since we have no shader modules

        // We don't actually create the pipeline since we have no shader modules
        // This is one limitation of this implementation

        // Create command pool for rendering commands
        const command_pool_create_info = vk.CommandPoolCreateInfo{
            .queue_family_index = self.device.graphics_queue_family,
            .flags = .{ .reset_command_buffer_bit = true },
        };

        _ = self.device.dispatch.vkCreateCommandPool.?(self.device.device, &command_pool_create_info, null, &self.command_pool);
        // This section would be removed as it's a duplication of the code already present earlier in the file
    }

    /// Request a stage buffer for mesh data
    pub fn requestBuffer(self: *Renderer) !?u32 {
        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        return try self.vertex_pool.?.requestBuffer();
    }

    /// Add mesh data to a buffer and create a draw command
    pub fn addMesh(self: *Renderer, buffer_idx: u32, vertices: []const vertex_pool.Vertex, position: [3]f32, group: u32) !*u32 {
        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        // Fill vertex data
        try self.vertex_pool.?.fillVertexData(buffer_idx, vertices);

        // Add draw command
        return try self.vertex_pool.?.addDrawCommand(buffer_idx, @intCast(vertices.len), position, group);
    }

    /// Release a buffer and its draw command
    pub fn releaseBuffer(self: *Renderer, buffer_idx: u32, command_index_ptr: *u32) !void {
        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        try self.vertex_pool.?.releaseBuffer(buffer_idx, command_index_ptr);
    }

    /// Mask draw commands based on view direction for back-face culling
    pub fn maskByFacing(self: *Renderer, camera_position: [3]f32) !void {
        // Define a simple predicate function for masking
        const PredContext = struct {};
        const predicate = struct {
            pub fn pred(_: PredContext, _: vertex_pool.DrawCommand) bool {
                return true; // Always include all commands
            }
        }.pred;

        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        // Define groups to include based on camera position
        // Determine which face directions are visible based on camera position
        var groups: [6]bool = .{false} ** 6;
        if (camera_position[0] < 0) groups[0] = true; // -X visible
        if (camera_position[0] > 0) groups[1] = true; // +X visible
        if (camera_position[1] < 0) groups[2] = true; // -Y visible
        if (camera_position[1] > 0) groups[3] = true; // +Y visible
        if (camera_position[2] < 0) groups[4] = true; // -Z visible
        if (camera_position[2] > 0) groups[5] = true; // +Z visible

        // Use predicate for masking
        self.vertex_pool.?.mask(PredContext{}, predicate);

        // Update the indirect buffer with masked commands
        try self.vertex_pool.?.updateIndirectBuffer();
    }

    /// Order draw commands from front-to-back for optimization
    pub fn orderFrontToBack(self: *Renderer, _: [3]f32) !void {
        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        // Simple compare function for distance sorting
        // Create a struct that stores the camera position

        //TODO
        // Update the indirect buffer with reordered commands
        try self.vertex_pool.?.updateIndirectBuffer();
    }

    /// Render using the vertex pool
    pub fn renderVertexPool(self: *Renderer, command_buffer: vk.CommandBuffer) !void {
        if (self.vertex_pool == null) {
            return error.VertexPoolNotInitialized;
        }

        try self.vertex_pool.?.render(command_buffer, self.pipeline_layout, self.pipeline);
    }

    /// Clean up all Vulkan resources
    pub fn deinit(self: *Renderer) void {
        if (self.vertex_pool != null) {
            self.vertex_pool.?.deinit();
        }

        if (self.pipeline != .null_handle) {
            if (self.device.dispatch.vkDestroyPipeline) |destroyPipeline| {
                destroyPipeline(self.device.device, self.pipeline, null);
            }
        }

        if (self.pipeline_layout != .null_handle) {
            if (self.device.dispatch.vkDestroyPipelineLayout) |destroyPipelineLayout| {
                destroyPipelineLayout(self.device.device, self.pipeline_layout, null);
            }
        }

        if (self.render_pass != .null_handle) {
            if (self.device.dispatch.vkDestroyRenderPass) |destroyRenderPass| {
                destroyRenderPass(self.device.device, self.render_pass, null);
            }
        }

        if (self.command_pool != .null_handle) {
            if (self.device.dispatch.vkDestroyCommandPool) |destroyCommandPool| {
                destroyCommandPool(self.device.device, self.command_pool, null);
            }
        }

        self.device.deinit();
        self.instance.deinit();
    }
};

/// Export renderer interface
pub const RendererInterface = struct {
    /// Check if Vulkan is available on the system
    pub fn isAvailable() bool {
        return false; // This will be implemented later
    }

    /// Get the name of the renderer
    pub fn getName() []const u8 {
        return "Vulkan";
    }

    /// Get Vertex type
    pub const Vertex = vertex_pool.Vertex;

    /// Get DrawCommand type
    pub const DrawCommand = vertex_pool.DrawCommand;
};
