const render = @import("../../include/render.zig");
const vk = @import("vk.zig");
const sf = @import("surface.zig");
const std = @import("std");
const pipelines = @import("pipeline.zig");

const SurfaceId = sf.Id;
const Surface = sf.Surface;
const PlatformRenderer = render.Renderer;
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
    device: vk.Device,
    surface: ?vk.Surface,
    swapchain: vk.Swapchain,
    command_pool: vk.CommandPool,
    command_buffer: vk.CommandBuffer,
    graphics_queue: vk.Queue,

    pipeline: *PipelineCompiler,

    const InstanceExtensions = [_][*:0]const u8{
        vk.KHR_SURFACE_EXTENSION_NAME,
        vk.KHR_XCB_SURFACE_EXTENSION_NAME,
    };

    const DeviceExtensions = [_][*:0]const u8{
        vk.KHR_SWAPCHAIN_EXTENSION_NAME,
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

        // Create app and instance info with appropriate extensions
        const app_info = vk.AppInfo{
            .sType = vk.sTy(vk.StructureType.AppInfo),
            .pApplicationName = "Hello Vulkan",
            .applicationVersion = vk.MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = vk.MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.API_VERSION_1_0,
        };

        const instance_info = vk.InstanceInfo{
            .sType = vk.sTy(vk.StructureType.InstanceInfo),
            .pApplicationInfo = &app_info,
            .enabledExtensionCount = if (instance_extensions_supported) InstanceExtensions.len else 0,
            .ppEnabledExtensionNames = if (instance_extensions_supported) &InstanceExtensions else null,
        };

        const instance = create: {
            var instance: vk.Instance = undefined;
            const result = vk.createInstance(&instance_info, null, @ptrCast(&instance));
            if (result != vk.SUCCESS) {
                std.debug.print("Failed to create instance: {}\n", .{result});
                return null;
            }
            std.debug.print("Vulkan instance created successfully\n", .{});
            break :create instance;
        };

        const physical_device = determine: {
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

            if (best_device) |device| {
                var properties: vk.PhysicalDeviceProperties = undefined;
                vk.getPhysicalDeviceProperties(device, &properties);
                const device_name = std.mem.sliceTo(&properties.deviceName, 0);
                std.debug.print("Selected GPU: {s} with score {}\n", .{ device_name, best_score });
            } else {
                std.debug.print("No suitable GPU found.\n", .{});
                return null;
            }

            break :determine best_device.?;
        };

        // Check device extensions
        const device_extensions = getAvailableDeviceExtensions(physical_device) catch {
            std.debug.print("Failed to get available device extensions\n", .{});
            return null;
        };
        defer renderAllocator.free(device_extensions);

        const device_extensions_supported = checkExtensionsSupport(&DeviceExtensions, device_extensions) catch |err| {
            std.debug.print("Error checking device extensions: {s}\n", .{@errorName(err)});
            return null;
        };

        // Queue creation
        const queue_priority: f32 = 1.0;
        const queue_create_info = vk.DeviceQueueCreateInfo{
            .sType = vk.sTy(vk.StructureType.DeviceQueueCreateInfo),
            .queueFamilyIndex = 0, // Replace with the actual graphics queue family index
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        };

        // Create device with supported extensions
        const device_create_info = vk.DeviceCreateInfo{
            .sType = vk.sTy(vk.StructureType.DeviceCreateInfo),
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_create_info,
            .enabledExtensionCount = if (device_extensions_supported) DeviceExtensions.len else 0,
            .ppEnabledExtensionNames = if (device_extensions_supported) &DeviceExtensions else null,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .pEnabledFeatures = null,
        };

        var device: vk.Device = undefined;
        const deviceResult = vk.createDevice(physical_device, &device_create_info, null, &device);
        if (deviceResult != vk.SUCCESS) {
            std.debug.print("Failed to create logical device: {}\n", .{deviceResult});
            return null;
        }
        std.debug.print("Logical device created successfully.\n", .{});

        const pipelineCompiler = PipelineCompiler.init(renderAllocator, device) catch |err| {
            std.debug.print("Failed to initialize pipeline compiler: {s}\n", .{@errorName(err)});
            return null;
        };

        const activeVkSurface = set: {
            if (instance_extensions_supported) {
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
                break :set vk_surface;
            } else {
                std.debug.print("Headless mode: No Vulkan surface created.\n", .{});
                break :set null;
            }
        };

        var renderer = renderAllocator.create(Renderer) catch |err| {
            std.debug.print("Failed to allocate memory for renderer\n {s}", .{@errorName(err)});
            return null;
        };
        renderer.instance = instance;
        renderer.device = device;
        renderer.surface = activeVkSurface;
        renderer.pipeline = pipelineCompiler;

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

pub export fn destroy() void {
    // Cleanup code here
    defer std.debug.print("Vulkan instance destroyed.\n", .{});
}
