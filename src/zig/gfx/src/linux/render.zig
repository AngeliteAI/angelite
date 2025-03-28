const render = @import("../../include/render.zig");
const vk = @import("vk.zig");
const sf = @import("surface.zig");
const std = @import("std");

const SurfaceId = sf.Id;
const Surface = sf.Surface;
const PlatformRenderer = render.Renderer;

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

    fn init(surface: *Surface) ?*Renderer {
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
        };

        const instance = create: {
            var instance: vk.Instance = undefined;
            const result = vk.createInstance(&instance_info, null, @ptrCast(&instance));
            std.debug.print("{}", .{result});
            break :create instance;
        };

        const physical_device = determine: {
            var device_count: u32 = 0;
            _ = vk.enumeratePhysicalDevices(instance, &device_count, null);
            if (device_count == 0) {
                std.debug.print("Failed to find GPUs with Vulkan support\n", .{});
                return null;
            }
            const physical_devices = renderAllocator.alloc(vk.PhysicalDevice, device_count) catch |err| {
                std.debug.print("Failed to allocate memory for physical devices\n {s}", .{@errorName(err)});
                return null;
            };
            _ = vk.enumeratePhysicalDevices(instance, &device_count, @ptrCast(physical_devices));

            var best_device: ?vk.PhysicalDevice = null;
            var max_memory: u64 = 0;

            for (physical_devices[0..device_count]) |device| {
                var properties: vk.PhysicalDeviceProperties = undefined;
                var memory_properties: vk.PhysicalDeviceMemoryProperties = undefined;

                vk.getPhysicalDeviceProperties(device, &properties);
                vk.getPhysicalDeviceMemoryProperties(device, &memory_properties);

                var total_memory: u64 = 0;
                for (memory_properties.memoryHeaps[0..memory_properties.memoryHeapCount]) |heap| {
                    if ((heap.flags & vk.MEMORY_HEAP_DEVICE_LOCAL_BIT) != 0) {
                        total_memory += heap.size;
                    }
                }

                if (total_memory > max_memory or (best_device == null and total_memory == max_memory)) {
                    max_memory = total_memory;
                    best_device = device;
                }
            }

            if (best_device == null) {
                std.debug.print("No suitable GPU found.\n", .{});
                return null;
            }

            break :determine best_device.?;
        };

        const queue_priority: f32 = 1.0;
        const queue_create_info = vk.DeviceQueueCreateInfo{
            .sType = vk.sTy(vk.StructureType.DeviceQueueCreateInfo),
            .queueFamilyIndex = 0, // Replace with the actual graphics queue family index
            .queueCount = 1,
            .pQueuePriorities = &queue_priority,
        };

        // Required extensions for XCB surface support
        const headExtensions = [_][*:0]const u8{
            vk.KHR_SWAPCHAIN_EXTENSION_NAME,
            vk.KHR_SURFACE_EXTENSION_NAME,
            vk.KHR_XCB_SURFACE_EXTENSION_NAME,
        };

        //Check for extensions before creating the device
        var extension_count: u32 = 0;
        const result = vk.enumerateDeviceExtensionProperties(physical_device, null, &extension_count, null);
        if (result != vk.SUCCESS) {
            std.debug.print("Failed to enumerate device extensions: {}\n", .{result});
            return null;
        }
        const extensions = renderAllocator.alloc(vk.ExtensionProperties, extension_count) catch |err| {
            std.debug.print("Failed to allocate memory for device extensions\n {s}", .{@errorName(err)});
            return null;
        };
        const result_enum = vk.enumerateDeviceExtensionProperties(physical_device, null, &extension_count, @ptrCast(extensions));
        if (result_enum != vk.SUCCESS) {
            std.debug.print("Failed to enumerate device extensions: {}\n", .{result_enum});
            return null;
        }
        for (extensions[0..extension_count]) |extension| {
            std.debug.print("Extension: {s}\n", .{extension.extensionName});
        }
        // Check if required extensions are supported
        var allExtensionsFound = true;
        for (headExtensions) |required_extension| {
            var found = false;
            for (extensions[0..extension_count]) |extension| {
                const ext_name = std.mem.sliceTo(&extension.extensionName, 0);
                const req_name = std.mem.span(required_extension);
                if (std.mem.eql(u8, ext_name, req_name)) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                std.debug.print("Required extension not supported: {s}\n", .{required_extension});
                allExtensionsFound = false;
            }
        }
        var deviceExtensionsLen: u32 = 0;
        const deviceExtensions: ?*const [*:0]const u8 = found: {
            if (allExtensionsFound) {
                std.debug.print("All required extensions are supported.\n", .{});
                deviceExtensionsLen = @intCast(headExtensions.len);
                break :found @ptrCast(&headExtensions);
            } else {
                std.debug.print("Not all required extensions are supported. Running in headless mode.\n", .{});
                deviceExtensionsLen = 0;
                break :found undefined;
            }
        };
        const device_create_info = vk.DeviceCreateInfo{
            .sType = vk.sTy(vk.StructureType.DeviceCreateInfo),
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_create_info,
            .enabledExtensionCount = deviceExtensionsLen,
            .ppEnabledExtensionNames = deviceExtensions orelse null,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .pEnabledFeatures = null,
        };

        var device: vk.Device = undefined;
        const deviceResult = vk.createDevice(physical_device, &device_create_info, null, &device);
        if (deviceResult != vk.SUCCESS) {
            std.debug.print("Failed to create logical device: {}\n", .{result});
            return null;
        }
        std.debug.print("Logical device created successfully.\n", .{});

        const activeVkSurface = set: {
            if (allExtensionsFound) {
                // Create Vulkan surface from the platform surface
                var vk_surface: vk.Surface = undefined;

                // Access surface internals to create Vulkan surface using XCB
                // Get the XcbSurface data from our surface
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
