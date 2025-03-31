const inc = @import("include/render.zig");
const vk = @import("vk.zig");
const sf = @import("surface.zig");
const std = @import("std");
const pipelines = @import("pipeline.zig");

const SurfaceId = sf.Id;
const Surface = sf.Surface;
const PlatformRenderer = inc.Renderer;
const PipelineCompiler = pipelines.PipelineCompiler;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const renderAllocator = gpa.allocator();

var platformRenderers = std.AutoHashMap(PlatformRenderer, *Renderer).init(gpa.allocator());
var surfaceRenderers = std.AutoHashMap(Surface, PlatformRenderer).init(gpa.allocator());
var platformRendererActive = PlatformRenderer{
    .id = 0,
};

const Renderer = struct {
    instance: vk.Instance,
    physicalDevice: vk.PhysicalDevice,
    device: vk.Device,
    queue: vk.Queue,
    surface: ?vk.Surface,
    swapchain: vk.Swapchain,
    command_pool: vk.CommandPool,
    command_buffer: vk.CommandBuffer,

    pipeline: *PipelineCompiler,

    const InstanceExtensions = [_][*:0]const u8{
        vk.KHR_SURFACE_EXTENSION_NAME,
        vk.KHR_XCB_SURFACE_EXTENSION_NAME,
    };

    const DeviceExtensions = [_][*:0]const u8{
        vk.KHR_SWAPCHAIN_EXTENSION_NAME,
        vk.KHR_DYNAMIC_RENDERING_EXTENSION_NAME,
        vk.KHR_PUSH_DESCRIPTOR_EXTENSION_NAME,
        vk.EXT_DESCRIPTOR_INDEXING_EXTENSION_NAME,
    };

    fn checkExtensionsSupport(
        required_extensions: []const [*:0]const u8,
        available_extensions: []const vk.ExtensionProperties,
    ) !bool {
        for (required_extensions) |required_ext| {
            const req_name = std.mem.span(required_ext);
            var found = false;

            for (available_extensions) |available_ext| {
                const ext_name = std.mem.sliceTo(&available_ext.extensionName, 0);
                if (std.mem.eql(u8, ext_name, req_name)) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                std.debug.print("Required extension not supported: {s}\n", .{req_name});
                return false;
            }
        }
        return true;
    }

    fn getAvailableInstanceExtensions() ![]vk.ExtensionProperties {
        var extension_count: u32 = 0;
        _ = vk.enumerateInstanceExtensionProperties(null, &extension_count, null);

        const extensions = try renderAllocator.alloc(vk.ExtensionProperties, extension_count);
        const result = vk.enumerateInstanceExtensionProperties(null, &extension_count, @ptrCast(extensions));

        if (result != vk.SUCCESS) {
            std.debug.print("Failed to enumerate instance extensions: {}\n", .{result});
            return error.EnumerationFailed;
        }
        return extensions[0..extension_count];
    }

    fn getAvailableDeviceExtensions(physical_device: vk.PhysicalDevice) ![]vk.ExtensionProperties {
        var extension_count: u32 = 0;
        _ = vk.enumerateDeviceExtensionProperties(physical_device, null, &extension_count, null);

        const extensions = try renderAllocator.alloc(vk.ExtensionProperties, extension_count);
        const result = vk.enumerateDeviceExtensionProperties(physical_device, null, &extension_count, @ptrCast(extensions));

        if (result != vk.SUCCESS) {
            std.debug.print("Failed to enumerate device extensions: {}\n", .{result});
            return error.EnumerationFailed;
        }

        return extensions[0..extension_count];
    }

    fn createInstance(head: bool) vk.Instance {
        // Create app and instance info with appropriate extensions
        const app_info = vk.AppInfo{
            .sType = vk.sTy(vk.StructureType.AppInfo),
            .pApplicationName = "Hello Vulkan",
            .applicationVersion = vk.MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = vk.MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.API_VERSION_1_3,
        };

        const instance_info = vk.InstanceInfo{
            .sType = vk.sTy(vk.StructureType.InstanceInfo),
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = if (head) InstanceExtensions.len else 0,
            .ppEnabledExtensionNames = if (head) &InstanceExtensions else null,
        };

        var instance: vk.Instance = undefined;
        const result = vk.createInstance(&instance_info, null, @ptrCast(&instance));
        if (result != vk.SUCCESS) {
            std.debug.print("Failed to create instance: {}\n", .{result});
            return null;
        }
        std.debug.print("Vulkan instance created successfully\n", .{});

        return instance;
    }

    fn createSurface(instance: vk.Instance, surface: *Surface) vk.Surface {
        // Create Vulkan surface from the platform surface
        var vk_surface: vk.Surface = undefined;

        std.debug.print("Surface ID: {}\n", .{surface.*.id});
        const xcb_surface = sf.xcb_surfaces.get(SurfaceId{ .id = surface.*.id }) orelse {
            std.debug.print("Failed to find XCB surface data\n", .{});
            return null;
        };

        const create_info = vk.XcbSurfaceCreateInfoKHR{
            .sType = vk.sTy(vk.StructureType.XcbSurfaceCreateInfoKHR),
            .connection = @ptrCast(xcb_surface.connection),
            .window = xcb_surface.window,
            .flags = 0,
        };

        const result_surface = vk.createXcbSurfaceKHR(instance, &create_info, null, &vk_surface);
        if (result_surface != vk.SUCCESS) {
            std.debug.print("Failed to create Vulkan surface: {}\n", .{result_surface});
            return null;
        }

        std.debug.print("Vulkan surface created successfully.\n", .{});
        return vk_surface;
    }

    fn determineBestPhysicalDevice(instance: vk.Instance) vk.PhysicalDevice {
        var device_count: u32 = 0;
        _ = vk.enumeratePhysicalDevices(instance, &device_count, null);
        if (device_count == 0) {
            std.debug.print("Failed to find GPUs with Vulkan support\n", .{});
            return null;
        }
        std.debug.print("Found {} GPU(s) with Vulkan support\n", .{device_count});

        const physical_devices = renderAllocator.alloc(vk.PhysicalDevice, device_count) catch |err| {
            std.debug.print("Failed to allocate memory for physical devices\n {s}", .{@errorName(err)});
            return null;
        };
        defer renderAllocator.free(physical_devices);

        _ = vk.enumeratePhysicalDevices(instance, &device_count, @ptrCast(physical_devices));

        var best_device: ?vk.PhysicalDevice = null;
        var best_score: i32 = -1;

        for (physical_devices[0..device_count]) |device| {
            var properties: vk.PhysicalDeviceProperties = undefined;
            var memory_properties: vk.PhysicalDeviceMemoryProperties = undefined;

            vk.getPhysicalDeviceProperties(device, &properties);
            vk.getPhysicalDeviceMemoryProperties(device, &memory_properties);

            const device_name = std.mem.sliceTo(&properties.deviceName, 0);

            // Calculate device score
            var score: i32 = 0;

            // Device type is most important factor
            const deviceScore: i32 = switch (properties.deviceType) {
                vk.PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => 10000, // Strongly prefer dedicated GPUs
                vk.PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU => 1000,
                vk.PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => 500,
                vk.PHYSICAL_DEVICE_TYPE_CPU => 100,
                vk.PHYSICAL_DEVICE_TYPE_OTHER => 0,
                else => 0,
            };

            score += deviceScore;

            // Device type name for logging
            const device_type_str = switch (properties.deviceType) {
                vk.PHYSICAL_DEVICE_TYPE_OTHER => "Other",
                vk.PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU => "Integrated GPU",
                vk.PHYSICAL_DEVICE_TYPE_DISCRETE_GPU => "Discrete GPU",
                vk.PHYSICAL_DEVICE_TYPE_VIRTUAL_GPU => "Virtual GPU",
                vk.PHYSICAL_DEVICE_TYPE_CPU => "CPU",
                else => "Unknown",
            };

            // Add memory as secondary factor
            var total_memory: u64 = 0;
            for (memory_properties.memoryHeaps[0..memory_properties.memoryHeapCount]) |heap| {
                if ((heap.flags & vk.MEMORY_HEAP_DEVICE_LOCAL_BIT) != 0) {
                    total_memory += heap.size;
                }
            }
            // Add 1 point per 64MB of memory
            score += @intCast(@divFloor(total_memory, 1024 * 1024 * 64));

            // Add points for newer devices based on API version
            // Extract major/minor from API version
            const major_version = vk.API_VERSION_MAJOR(properties.apiVersion);
            const minor_version = vk.API_VERSION_MINOR(properties.apiVersion);
            score += @intCast(major_version * 100 + minor_version * 10);

            // Log the device information and scoring
            std.debug.print("GPU: {s}\n", .{device_name});
            std.debug.print("  - Type: {s} (+{})\n", .{ device_type_str, deviceScore });
            std.debug.print("  - Device Local Memory: {} MB (+{})\n", .{ total_memory / (1024 * 1024), @divFloor(total_memory, 1024 * 1024 * 64) });
            std.debug.print("  - API Version: {}.{} (+{})\n", .{ major_version, minor_version, major_version * 100 + minor_version * 10 });
            std.debug.print("  - Total Score: {}\n", .{score});

            if (score > best_score) {
                std.debug.print("  - SELECTED: This GPU scores higher than previous best ({} vs {})\n", .{ score, best_score });
                best_score = score;
                best_device = device;
            } else {
                std.debug.print("  - SKIPPED: This GPU scores lower than current best ({} vs {})\n", .{ score, best_score });
            }
        }
        return best_device.?;
    }

    fn getQueueFamilyIndex(physical_device: vk.PhysicalDevice, activeVkSurface: vk.Surface) !u32 {
        var count: u32 = 0;
        vk.getPhysicalDeviceQueueFamilyProperties(physical_device, &count, null);

        const queueFamilies = try renderAllocator.alloc(vk.QueueFamilyProperties, count);
        defer renderAllocator.free(queueFamilies);

        vk.getPhysicalDeviceQueueFamilyProperties(physical_device, &count, @ptrCast(queueFamilies));

        var queueFamilyIndex: u32 = 0;
        while (queueFamilyIndex < count) : (queueFamilyIndex += 1) {
            if (queueFamilies[queueFamilyIndex].queueFlags & vk.QUEUE_GRAPHICS_BIT == 0) {
                continue;
            }
            var present_support = vk.TRUE;
            _ = vk.GetPhysicalDeviceSurfaceSupportKHR(physical_device, queueFamilyIndex, activeVkSurface, &present_support);

            if (present_support == vk.FALSE) {
                continue;
            }

            return queueFamilyIndex;
        }
        return error.NoSupportedQueue;
    }

    fn createLogicalDevice(physical_device: vk.PhysicalDevice, qfi: u32) vk.Device {
        // Use device extensions
        var dynamic_rendering_features = vk.PhysicalDeviceDynamicRenderingFeatures{
            .sType = vk.sTy(vk.StructureType.PhysicalDeviceDynamicRenderingFeatures),
            .dynamicRendering = vk.TRUE,
        };

        var descriptor_indexing_features = vk.PhysicalDeviceDescriptorIndexingFeatures{
            .sType = vk.sTy(vk.StructureType.PhysicalDeviceDescriptorIndexingFeatures),
            .pNext = &dynamic_rendering_features,
            .descriptorBindingPartiallyBound = vk.TRUE,
            .runtimeDescriptorArray = vk.TRUE,
            .descriptorBindingVariableDescriptorCount = vk.TRUE,
            .descriptorBindingUpdateUnusedWhilePending = vk.TRUE,
            .descriptorBindingSampledImageUpdateAfterBind = vk.TRUE,
            .descriptorBindingStorageBufferUpdateAfterBind = vk.TRUE,
        };

        // Queue creation
        const queue_priority: f32 = 1.0;
        const queue_create_info = vk.DeviceQueueCreateInfo{
            .sType = vk.sTy(vk.StructureType.DeviceQueueCreateInfo),
            .queueFamilyIndex = qfi, // Replace with the actual graphics queue family index
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        };

        // Create device with supported extensions
        const device_create_info = vk.DeviceCreateInfo{
            .sType = vk.sTy(vk.StructureType.DeviceCreateInfo),
            .pNext = &descriptor_indexing_features,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_create_info,
            //todo maybe make a renderer-lite version
            .enabledExtensionCount = DeviceExtensions.len,
            .ppEnabledExtensionNames = &DeviceExtensions,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .pEnabledFeatures = null,
        };

        var device: vk.Device = undefined;
        const deviceResult = vk.createDevice(physical_device, &device_create_info, null, &device);
        if (deviceResult != vk.SUCCESS) {
            std.debug.print("Failed to create logical device: {}\n", .{deviceResult});
            return undefined;
        }
        std.debug.print("Logical device created successfully.\n", .{});

        return device;
    }

    fn getDeviceQueue(device: vk.Device, qfi: u32) vk.Queue {
        var queue: vk.Queue = undefined;
        vk.getDeviceQueue(device, qfi, 0, &queue);
        return queue;
    }

    fn createSwapchain(device: vk.Device, physical_device: vk.PhysicalDevice, surface: vk.Surface, width: u32, height: u32, oldSwapchain: vk.Swapchain) !vk.Swapchain {
        // Query surface capabilities
        var capabilities: vk.SurfaceCapabilitiesKHR = undefined;
        _ = vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &capabilities);

        // Choose format
        var format_count: u32 = 0;
        _ = vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, null);

        const formats = try renderAllocator.alloc(vk.SurfaceFormatKHR, format_count);
        defer renderAllocator.free(formats);
        _ = vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, formats.ptr);

        // Prefer SRGB format
        var surface_format = formats[0];
        for (formats) |format| {
            if (format.format == vk.FORMAT_B8G8R8A8_SRGB and
                format.colorSpace == vk.COLOR_SPACE_SRGB_NONLINEAR_KHR)
            {
                surface_format = format;
                break;
            }
        }

        // Create swapchain
        const swapchain_info = vk.SwapchainCreateInfoKHR{
            .sType = vk.sTy(vk.StructureType.SwapchainCreateInfoKHR),
            .surface = surface,
            .minImageCount = capabilities.minImageCount + 1,
            .imageFormat = surface_format.format,
            .imageColorSpace = surface_format.colorSpace,
            .imageExtent = .{ .width = width, .height = height },
            .imageArrayLayers = 1,
            .imageUsage = vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = vk.SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
            .preTransform = capabilities.currentTransform,
            .compositeAlpha = vk.COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = vk.PRESENT_MODE_FIFO_KHR,
            .clipped = vk.TRUE,
            .oldSwapchain = oldSwapchain,
        };

        var swapchain: vk.Swapchain = undefined;
        const result = vk.CreateSwapchainKHR(device, &swapchain_info, null, &swapchain);
        if (result != vk.SUCCESS) {
            return error.SwapchainCreationFailed;
        }

        return swapchain;
    }

    fn createCommandPool(device: vk.Device, qfi: u32) !vk.CommandPool {
        const result = vk.createCommandPool(device, qfi);
        if (result == null) {
            std.debug.print("Failed to create command pool: {any}\n", .{result});
            return error.CommandPoolCreationFailed;
        }

        return result.?;
    }

    fn allocCommandBuffer(device: vk.Device, command_pool: vk.CommandPool) !vk.CommandBuffer {
        const buffers = vk.allocateCommandBuffers(device, command_pool, vk.COMMAND_BUFFER_LEVEL_PRIMARY, 1);
        if (buffers == null) {
            std.debug.print("Failed to allocate command buffer: {any}\n", .{buffers});
            return error.CommandBufferAllocationFailed;
        }

        return buffers.?[0];
    }

    fn init(surface: *Surface) ?*Renderer {
        // Check instance extensions
        const instance_extensions = getAvailableInstanceExtensions() catch {
            std.debug.print("Failed to get available instance extensions\n", .{});
            return null;
        };
        defer renderAllocator.free(instance_extensions);

        const instance_extensions_supported = checkExtensionsSupport(&InstanceExtensions, instance_extensions) catch |err| {
            std.debug.print("Error checking instance extensions: {s}\n", .{@errorName(err)});
            return null;
        };

        const instance = Renderer.createInstance(instance_extensions_supported);

        const activeVkSurface = set: {
            if (instance_extensions_supported) {
                break :set Renderer.createSurface(instance, surface);
            } else {
                std.debug.print("Running in Headless mode, surface extension not supported.", .{});
                break :set undefined;
            }
        };

        const physicalDevice = Renderer.determineBestPhysicalDevice(instance);

        const qfi = Renderer.getQueueFamilyIndex(physicalDevice, activeVkSurface) catch |err| {
            std.debug.print("Failed to get qfi {s}", .{@errorName(err)});
            return null;
        };

        // Check device extensions
        const device_extensions = getAvailableDeviceExtensions(physicalDevice) catch {
            std.debug.print("Failed to get available device extensions\n", .{});
            return null;
        };
        defer renderAllocator.free(device_extensions);

        const device_extensions_supported = checkExtensionsSupport(&DeviceExtensions, device_extensions) catch |err| {
            std.debug.print("Error checking device extensions: {s}\n", .{@errorName(err)});
            return null;
        };

        if (!device_extensions_supported) {
            std.debug.print("Device extensions not supported, renderer cannot be initialized", .{});
            return null;
        }

        const device: vk.Device = Renderer.createLogicalDevice(physicalDevice, qfi);
        vk.loadDeviceExtensionFunctions(device);
        const queue: vk.Queue = Renderer.getDeviceQueue(device, qfi);

        const swapchain: vk.Swapchain = Renderer.createSwapchain(device, physicalDevice, activeVkSurface, 800, 600, null) catch |err| {
            std.debug.print("Failed to create swapchain: {s}\n", .{@errorName(err)});
            return null;
        };

        const command_pool = Renderer.createCommandPool(device, qfi) catch |err| {
            std.debug.print("Failed to create command pool: {s}\n", .{@errorName(err)});
            return null;
        };

        const command_buffer = Renderer.allocCommandBuffer(device, command_pool) catch |err| {
            std.debug.print("Failed to allocate command buffer: {s}\n", .{@errorName(err)});
            return null;
        };

        const pipelineCompiler = PipelineCompiler.init(renderAllocator, device) catch |err| {
            std.debug.print("Failed to initialize pipeline compiler: {s}\n", .{@errorName(err)});
            return null;
        };

        _ = pipelineCompiler.createGraphicsPipeline("triangle", .{
            .vertex_shader = .{ .path = "../gfx/src/linux/hellotriangle.glsl", .shader_type = .Vertex },
            .fragment_shader = .{ .path = "../gfx/src/linux/hellotrianglef.glsl", .shader_type = .Fragment },
            .color_attachment_formats = &[_]vk.Format{vk.Format.B8G8R8A8Srgb},
        }) catch |err| {
            std.debug.print("Failed to create graphics pipeline: {s}\n", .{@errorName(err)});
            return null;
        };

        var renderer = renderAllocator.create(Renderer) catch |err| {
            std.debug.print("Failed to allocate memory for renderer\n {s}", .{@errorName(err)});
            return null;
        };

        renderer.instance = instance;
        renderer.physicalDevice = physicalDevice;
        renderer.device = device;
        renderer.queue = queue;
        renderer.surface = activeVkSurface;
        renderer.pipeline = pipelineCompiler;
        renderer.swapchain = swapchain;
        renderer.command_buffer = command_buffer;
        renderer.command_pool = command_pool;

        return renderer;
    }
};

pub export fn init(surface: ?*Surface) ?*PlatformRenderer {
    if (surface == null) {
        std.debug.print("Surface is null.\n", .{});
        return null;
    }
    if (surfaceRenderers.contains(surface.?.*)) {
        std.debug.print("Renderer already exists for this surface.\n", .{});
        return null;
    }

    const renderer = Renderer.init(surface.?);
    if (renderer == null) {
        std.debug.print("Failed to initialize renderer.\n", .{});
        return null;
    }
    const id = platformRendererActive;
    platformRendererActive.id += 1;
    platformRenderers.put(id, renderer.?) catch |err| {
        std.debug.print("Failed to allocate memory for renderer\n {s}", .{@errorName(err)});
        return null;
    };
    surfaceRenderers.put(surface.?.*, id) catch |err| {
        std.debug.print("Failed to allocate memory for renderer\n {s}", .{@errorName(err)});
        return null;
    };
    std.debug.print("Renderer initialized successfully.\n", .{});
    std.debug.print("Renderer ID: {}\n", .{id});
    std.debug.print("Renderer pointer: {}\n", .{renderer.?.*});
    std.debug.print("Surface pointer: {}\n", .{surface.?.*});
    std.debug.print("Surface ID: {}\n", .{surface.?.*});

    const platform_renderer = renderAllocator.create(PlatformRenderer) catch |err| {
        std.debug.print("Failed to allocate memory for platform renderer\n {s}", .{@errorName(err)});
        return null;
    };
    platform_renderer.* = id;
    return platform_renderer;
}

pub export fn render(handle: ?*PlatformRenderer) void {
    if (handle == null) {
        std.debug.print("Renderer handle is null.\n", .{});
        return;
    }
    // Render code here
    std.debug.print("Rendering...\n", .{});

    var renderer = platformRenderers.get(handle.?.*) orelse {
        std.debug.print("Failed to get renderer from platform renderers\n", .{});
        return;
    };

    _ = vk.BeginCommandBuffer(renderer.command_buffer, &.{
        .sType = vk.sTy(vk.StructureType.CommandBufferBeginInfo),
        .flags = vk.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
        .pInheritanceInfo = null,
    });

    const color_attachment = vk.RenderingAttachmentInfoKHR{
        .sType = vk.sTy(vk.StructureType.RenderingAttachmentInfoKHR),
        .imageView = null,
        .imageLayout = vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        .resolveMode = vk.RESOLVE_MODE_NONE_KHR,
        .resolveImageView = null,
        .resolveImageLayout = vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        .loadOp = vk.RENDER_PASS_LOAD_OP_CLEAR,
        .storeOp = vk.RENDER_PASS_STORE_OP_STORE,
        .clearValue = vk.ClearValue{
            .color = vk.ClearColorValue{
                .float32 = [_]f32{ 0.0, 0.0, 0.0, 1.0 },
            },
        },
    };

    const rendering_info = vk.RenderingInfoKHR{
        .sType = vk.sTy(vk.StructureType.RenderingInfoKHR),
        .renderArea = vk.Rect2D{
            .offset = vk.Offset2D{ .x = 0, .y = 0 },
            .extent = vk.Extent2D{ .width = 800, .height = 600 },
        },
        .layerCount = 1,
        .colorAttachmentCount = 1,
        .pColorAttachments = &color_attachment,
    };

    vk.cmdBeginRenderingKHR(renderer.command_buffer, &rendering_info);
    const pipeline = renderer.pipeline.getPipeline("triangle") catch |err| {
        std.debug.print("Failed to get pipeline: {s}\n", .{@errorName(err)});
        return;
    };
    vk.CmdBindPipeline(renderer.command_buffer, vk.PIPELINE_BIND_POINT_GRAPHICS, pipeline.asGraphics().?.getHandle().?);

    const viewport = vk.Viewport{
        .x = 0.0,
        .y = 0.0,
        .width = 800.0,
        .height = 600.0,
        .minDepth = 0.0,
        .maxDepth = 1.0,
    };

    vk.CmdSetViewport(renderer.command_buffer, 0, 1, &viewport);

    const scissor = vk.Rect2D{
        .offset = vk.Offset2D{ .x = 0, .y = 0 },
        .extent = vk.Extent2D{ .width = 800, .height = 600 },
    };

    vk.CmdSetScissor(renderer.command_buffer, 0, 1, &scissor);

    vk.CmdDraw(renderer.command_buffer, 3, 1, 0, 0);

    vk.cmdEndRenderingKHR(renderer.command_buffer);

    _ = vk.EndCommandBuffer(renderer.command_buffer);
}

pub export fn destroy() void {
    // Cleanup code here
    defer std.debug.print("Vulkan instance destroyed.\n", .{});
}
