const inc = @import("include").render;

const vk = @import("vk.zig");
const sf = blk: {
    if (@import("builtin").os.tag == .windows) {
        break :blk @import("../windows/surface.zig");
    } else {
        break :blk @import("../linux/surface.zig");
    }
};
const std = @import("std");
const pipelines = @import("pipeline.zig");
const task = @import("task.zig");
const frame = @import("frame.zig");

const SurfaceId = sf.Id;
const Surface = sf.Surface;
const PlatformRenderer = inc.Renderer;
const PipelineCompiler = pipelines.PipelineCompiler;
const Graph = task.Graph;
const Pass = task.Pass;
const PassContext = task.PassContext;
const ResourceState = task.ResourceState;
const Frame = frame.Frame;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const renderAllocator = gpa.allocator();

var platformRenderers = std.AutoHashMap(PlatformRenderer, *Renderer).init(gpa.allocator());
var surfaceRenderers = std.AutoHashMap(Surface, PlatformRenderer).init(gpa.allocator());
var platformRendererActive = PlatformRenderer{
    .id = 0,
};

const Renderer = struct {
    const MAX_FRAMES_IN_FLIGHT = 3;
    instance: vk.Instance,
    physicalDevice: vk.PhysicalDevice,
    device: vk.Device,
    queue: vk.Queue,
    surface: ?vk.Surface,
    swapchain: vk.Swapchain,
    swapchainImages: []vk.Image,
    command_pool: vk.CommandPool,
    command_buffers: []vk.CommandBuffer,
    image_available_semaphores: []vk.Semaphore,
    render_finished_semaphores: []vk.Semaphore,
    in_flight_fences: []vk.Fence,
    images_in_flight: []vk.Fence,

    graph: *Graph,
    swapchainImageResource: *task.Resource,
    pipeline: *PipelineCompiler,

    frame: Frame,

    const InstanceExtensions = [_][*:0]const u8{ vk.GENERIC_SURFACE_EXTENSION_NAME, vk.PLATFORM_SURFACE_EXTENSION_NAME };

    const DeviceExtensions = [_][*:0]const u8{
        vk.KHR_SWAPCHAIN_EXTENSION_NAME,
        vk.KHR_DYNAMIC_RENDERING_EXTENSION_NAME,
        vk.KHR_PUSH_DESCRIPTOR_EXTENSION_NAME,
        vk.EXT_DESCRIPTOR_INDEXING_EXTENSION_NAME,
    };

    const Sync2Extensions = [_][*:0]const u8{
        vk.KHR_SYNCHRONIZATION_2_EXTENSION_NAME,
    };

    fn createSemaphore(device: vk.Device) !vk.Semaphore {
        const semaphore_info = vk.SemaphoreCreateInfo{
            .sType = vk.sTy(vk.StructureType.SemaphoreCreateInfo),
            .pNext = null,
            .flags = 0,
        };

        var semaphore: vk.Semaphore = undefined;
        const result = vk.createSemaphore(device, &semaphore_info, null, &semaphore);
        if (result != vk.SUCCESS) {
            return error.SemaphoreCreationFailed;
        }
        return semaphore;
    }

    fn createFence(device: vk.Device) !vk.Fence {
        const fence_info = vk.FenceCreateInfo{
            .sType = vk.sTy(vk.StructureType.FenceCreateInfo),
            .pNext = null,
            .flags = vk.SIGNALED, // Start signaled so first wait succeeds
        };

        var fence: vk.Fence = undefined;
        const result = vk.createFence(device, &fence_info, null, &fence);
        if (result != vk.SUCCESS) {
            return error.FenceCreationFailed;
        }
        return fence;
    }

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
        // Define validation layers to use
        const ValidationLayers = [_][*:0]const u8{
            "VK_LAYER_KHRONOS_validation",
        };

        // Check validation layer support
        var layerCount: u32 = 0;
        _ = vk.enumerateInstanceLayerProperties(&layerCount, null);

        const availableLayers = renderAllocator.alloc(vk.LayerProperties, layerCount) catch {
            std.debug.print("Failed to allocate memory for layer properties\n", .{});
            return null;
        };
        defer renderAllocator.free(availableLayers);

        _ = vk.enumerateInstanceLayerProperties(&layerCount, @ptrCast(availableLayers));

        // Check if all requested validation layers are available
        var validationLayersSupported = true;
        for (ValidationLayers) |layerName| {
            var layerFound = false;
            const layerNameStr = std.mem.span(layerName);

            for (availableLayers) |layerProperties| {
                const availableLayerName = std.mem.sliceTo(&layerProperties.layerName, 0);
                if (std.mem.eql(u8, availableLayerName, layerNameStr)) {
                    layerFound = true;
                    break;
                }
            }

            if (!layerFound) {
                validationLayersSupported = false;
                std.debug.print("Validation layer not found: {s}\n", .{layerNameStr});
                break;
            }
        }

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
            .enabledLayerCount = if (validationLayersSupported) ValidationLayers.len else 0,
            .ppEnabledLayerNames = if (validationLayersSupported) &ValidationLayers else null,
        };

        var instance: vk.Instance = undefined;
        const result = vk.createInstance(&instance_info, null, @ptrCast(&instance));
        if (result != vk.SUCCESS) {
            std.debug.print("Failed to create instance: {}\n", .{result});
            return null;
        }
        std.debug.print("Vulkan instance created successfully\n", .{});

        if (validationLayersSupported) {
            std.debug.print("Validation layers enabled\n", .{});
        } else {
            std.debug.print("Validation layers requested but not available\n", .{});
        }

        return instance;
    }
    fn createSurface(instance: vk.Instance, surface: *Surface, platform_info: vk.PlatformSpecificInfo) vk.Surface {
        // Create Vulkan surface from the platform surface
        std.debug.print("Surface ID: {}\n", .{surface.*.id});

        // Construct platform-specific info

        // Call the generalized createSurface function
        const result = vk.createSurface(instance, platform_info);
        if (result == null) {
            std.debug.print("Failed to create Vulkan surface.\n", .{});
            return null;
        }

        std.debug.print("Vulkan surface created successfully.\n", .{});
        return result.?;
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

    fn createSwapchain(device: vk.Device, physical_device: vk.PhysicalDevice, surface: vk.Surface, oldSwapchain: vk.Swapchain) !vk.Swapchain {
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
        const surface_format = vk.FORMAT_B8G8R8A8_SRGB;
        const colorSpace = vk.COLOR_SPACE_SRGB_NONLINEAR_KHR;

        // Use the current extent from surface capabilities
        const extent = capabilities.currentExtent;

        // Create swapchain
        const swapchain_info = vk.SwapchainCreateInfoKHR{
            .sType = vk.sTy(vk.StructureType.SwapchainCreateInfoKHR),
            .surface = surface,
            .minImageCount = 3,
            .imageFormat = surface_format,
            .imageColorSpace = colorSpace,
            .imageExtent = extent,
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

    fn getSwapchainImages(device: vk.Device, swapchain: vk.Swapchain) ![]vk.Image {
        var image_count: u32 = 0;
        _ = vk.getSwapchainImages(device, swapchain, &image_count, null);
        const swapchain_images = renderAllocator.alloc(vk.Image, image_count) catch {
            std.debug.print("Failed to allocate memory for swapchain images\n", .{});
            return error.OutOfMemory;
        };
        _ = vk.getSwapchainImages(device, swapchain, &image_count, swapchain_images.ptr);
        return swapchain_images;
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
    fn init(surface: *Surface) !?*Renderer {
        std.debug.print("Initializing Vulkan renderer for surface ID: {}\n", .{surface.id});

        // Check instance extensions
        std.debug.print("Checking available instance extensions...\n", .{});
        const instance_extensions = getAvailableInstanceExtensions() catch {
            std.debug.print("ERROR: Failed to get available instance extensions\n", .{});
            return null;
        };
        defer renderAllocator.free(instance_extensions);
        std.debug.print("Found {} instance extensions\n", .{instance_extensions.len});

        const instance_extensions_supported = checkExtensionsSupport(&InstanceExtensions, instance_extensions) catch |err| {
            std.debug.print("ERROR: Error checking instance extensions: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Instance extensions supported: {}\n", .{instance_extensions_supported});

        std.debug.print("Creating Vulkan instance...\n", .{});
        const instance = Renderer.createInstance(instance_extensions_supported);
        if (instance == null) {
            std.debug.print("ERROR: Failed to create Vulkan instance\n", .{});
            return null;
        }
        std.debug.print("Vulkan instance created successfully: {*}\n", .{instance});

        std.debug.print("Setting up Vulkan surface...\n", .{});
        const activeVkSurface = set: {
            if (instance_extensions_supported) {
                std.debug.print("Creating platform-specific surface for OS: {s}\n", .{@tagName(@import("builtin").os.tag)});
                const platform_info = switch (@import("builtin").os.tag) {
                    .windows => vk.PlatformSpecificInfo{ .PlatformWindows = .{
                        .hinstance = sf.win_surfaces.get(surface.*.id).?.hinstance,
                        .hwnd = sf.win_surfaces.get(surface.*.id).?.hwnd,
                    } },
                    .linux => vk.PlatformSpecificInfo{ .PlatformXcb = .{
                        .connection = sf.xcb_surfaces.get(sf.Id{ .id = surface.*.id }).?.connection,
                        .window = sf.xcb_surfaces.get(sf.Id{ .id = surface.*.id }).?.window,
                    } },
                    else => {
                        std.debug.print("ERROR: Unsupported platform: {s}\n", .{@tagName(@import("builtin").os.tag)});
                        return null; // Unsupported platform
                    },
                };
                const vkSurface = Renderer.createSurface(instance, surface, platform_info);
                if (vkSurface == null) {
                    std.debug.print("ERROR: Failed to create Vulkan surface\n", .{});
                    return null;
                }
                std.debug.print("Vulkan surface created successfully: {*}\n", .{vkSurface});
                break :set vkSurface;
            } else {
                std.debug.print("Running in Headless mode, surface extension not supported\n", .{});
                break :set undefined;
            }
        };

        std.debug.print("Selecting physical device...\n", .{});
        const physicalDevice = Renderer.determineBestPhysicalDevice(instance);
        if (physicalDevice == null) {
            std.debug.print("ERROR: Failed to select suitable physical device\n", .{});
            return null;
        }
        std.debug.print("Selected physical device: {*}\n", .{physicalDevice});

        std.debug.print("Finding compatible queue family...\n", .{});
        const qfi = Renderer.getQueueFamilyIndex(physicalDevice, activeVkSurface) catch |err| {
            std.debug.print("ERROR: Failed to get queue family index: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Selected queue family index: {}\n", .{qfi});

        // Check device extensions
        std.debug.print("Checking available device extensions...\n", .{});
        const device_extensions = getAvailableDeviceExtensions(physicalDevice) catch {
            std.debug.print("ERROR: Failed to get available device extensions\n", .{});
            return null;
        };
        defer renderAllocator.free(device_extensions);
        std.debug.print("Found {} device extensions\n", .{device_extensions.len});

        const device_extensions_supported = checkExtensionsSupport(&DeviceExtensions, device_extensions) catch |err| {
            std.debug.print("ERROR: Error checking device extensions: {s}\n", .{@errorName(err)});
            return null;
        };

        const sync2_extension_supported = checkExtensionsSupport(&Sync2Extensions, device_extensions) catch |err| {
            std.debug.print("ERROR: Error checking device extensions: {s}\n", .{@errorName(err)});
            return null;
        };
        if (!device_extensions_supported) {
            std.debug.print("ERROR: Required device extensions not supported, renderer cannot be initialized\n", .{});
            return null;
        }
        std.debug.print("All required device extensions are supported\n", .{});

        std.debug.print("Creating logical device...\n", .{});
        const device: vk.Device = Renderer.createLogicalDevice(physicalDevice, qfi);
        if (device == null) {
            std.debug.print("ERROR: Failed to create logical device\n", .{});
            return null;
        }
        std.debug.print("Logical device created successfully: {*}\n", .{device});

        std.debug.print("Loading device extension functions...\n", .{});
        vk.loadDeviceExtensionFunctions(device);
        std.debug.print("Device extension functions loaded\n", .{});

        std.debug.print("Getting device queue...\n", .{});
        const queue: vk.Queue = Renderer.getDeviceQueue(device, qfi);
        std.debug.print("Device queue obtained: {*}\n", .{queue});

        std.debug.print("Creating swapchain...\n", .{});
        const swapchain: vk.Swapchain = Renderer.createSwapchain(device, physicalDevice, activeVkSurface, null) catch |err| {
            std.debug.print("ERROR: Failed to create swapchain: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Swapchain created successfully: {*}\n", .{swapchain});

        std.debug.print("Getting swapchain images...\n", .{});
        const swapchainImages: []vk.ImageView = Renderer.getSwapchainImages(device, swapchain) catch |err| {
            std.debug.print("ERROR: Failed to get swapchain image views: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Retrieved {} swapchain images\n", .{swapchainImages.len});

        std.debug.print("Creating command pool...\n", .{});
        const command_pool = Renderer.createCommandPool(device, qfi) catch |err| {
            std.debug.print("ERROR: Failed to create command pool: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Command pool created successfully: {*}\n", .{command_pool});

        // In your Renderer.init function:
        std.debug.print("Creating synchronization primitives for multiple frames in flight...\n", .{});

        // Allocate arrays
        const command_buffers = try renderAllocator.alloc(vk.CommandBuffer, Renderer.MAX_FRAMES_IN_FLIGHT);
        const image_available_semaphores = try renderAllocator.alloc(vk.Semaphore, Renderer.MAX_FRAMES_IN_FLIGHT);
        const render_finished_semaphores = try renderAllocator.alloc(vk.Semaphore, Renderer.MAX_FRAMES_IN_FLIGHT);
        const in_flight_fences = try renderAllocator.alloc(vk.Fence, Renderer.MAX_FRAMES_IN_FLIGHT);

        // Create objects for each frame
        for (0..Renderer.MAX_FRAMES_IN_FLIGHT) |i| {
            command_buffers[i] = try Renderer.allocCommandBuffer(device, command_pool);
            image_available_semaphores[i] = try Renderer.createSemaphore(device);
            render_finished_semaphores[i] = try Renderer.createSemaphore(device);
            in_flight_fences[i] = try Renderer.createFence(device);
        }

        // Create array to track which images are in use
        var images_in_flight = try renderAllocator.alloc(vk.Fence, swapchainImages.len);
        // Initialize all entries to null/invalid
        for (0..swapchainImages.len) |i| {
            images_in_flight[i] = null;
        }

        std.debug.print("Initializing pipeline compiler...\n", .{});
        const pipelineCompiler = PipelineCompiler.init(device) catch |err| {
            std.debug.print("ERROR: Failed to initialize pipeline compiler: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Pipeline compiler initialized\n", .{});

        std.debug.print("Creating triangle graphics pipeline...\n", .{});
        _ = pipelineCompiler.createGraphicsPipeline("triangle", .{
            .vertex_shader = .{ .path = "src/gfx/src/vk/hellotriangle.glsl", .shader_type = .Vertex },
            .fragment_shader = .{ .path = "src/gfx/src/vk/hellotrianglef.glsl", .shader_type = .Fragment },
            .color_attachment_formats = &[_]vk.Format{vk.Format.B8G8R8A8Srgb},
        }) catch |err| {
            std.debug.print("ERROR: Failed to create graphics pipeline: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Triangle graphics pipeline created successfully\n", .{});

        std.debug.print("Creating synchronization primitives...\n", .{});
        const image_available_semaphore = Renderer.createSemaphore(device) catch |err| {
            std.debug.print("ERROR: Failed to create image available semaphore: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Image available semaphore created: {*}\n", .{image_available_semaphore});

        const render_finished_semaphore = Renderer.createSemaphore(device) catch |err| {
            std.debug.print("ERROR: Failed to create render finished semaphore: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Render finished semaphore created: {*}\n", .{render_finished_semaphore});

        const in_flight_fence = Renderer.createFence(device) catch |err| {
            std.debug.print("ERROR: Failed to create in-flight fence: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("In-flight fence created: {*}\n", .{in_flight_fence});

        std.debug.print("Allocating renderer structure...\n", .{});
        var renderer = renderAllocator.create(Renderer) catch |err| {
            std.debug.print("ERROR: Failed to allocate memory for renderer: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Renderer structure allocated: {*}\n", .{renderer});

        std.debug.print("Initializing render graph...\n", .{});
        const graph = Graph.init(renderAllocator, renderer, swapchain, render_finished_semaphore, image_available_semaphore, in_flight_fence, queue, sync2_extension_supported) catch |err| {
            std.debug.print("ERROR: Failed to initialize graph: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Render graph initialized: {*}\n", .{graph});

        std.debug.print("Setting up triangle rendering pass...\n", .{});
        const trianglePassFn = struct {
            fn execute(ctx: PassContext) void {
                std.debug.print("Executing triangle pass...\n", .{});
                const taskRenderer = @as(*Renderer, @ptrCast(@alignCast(ctx.userData)));
                if (ctx.pass.inputs.items.len == 0 or ctx.pass.inputs.items[0].resource.view == null) {
                    std.debug.print("ERROR: No inputs for triangle pass\n", .{});
                    return;
                }
                std.debug.print("Setting up color attachment for frame {}x{}\n", .{ ctx.frame.*.width, ctx.frame.*.height });
                const color_attachment = vk.RenderingAttachmentInfoKHR{
                    .sType = vk.sTy(vk.StructureType.RenderingAttachmentInfoKHR),
                    .imageView = ctx.pass.inputs.items[0].resource.view.?.imageView,
                    .imageLayout = vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                    .resolveMode = vk.RESOLVE_MODE_NONE_KHR,
                    .resolveImageView = null,
                    .resolveImageLayout = vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                    .loadOp = vk.RENDER_PASS_LOAD_OP_CLEAR,
                    .storeOp = vk.RENDER_PASS_STORE_OP_STORE,
                    .clearValue = vk.ClearValue{
                        .color = vk.ClearColorValue{
                            .float32 = [_]f32{ 1.0, 0.0, 1.0, 1.0 },
                        },
                    },
                };

                const rendering_info = vk.RenderingInfoKHR{
                    .sType = vk.sTy(vk.StructureType.RenderingInfoKHR),
                    .renderArea = vk.Rect2D{
                        .offset = vk.Offset2D{ .x = 0, .y = 0 },
                        .extent = vk.Extent2D{ .width = ctx.frame.*.width, .height = ctx.frame.*.height },
                    },
                    .layerCount = 1,
                    .colorAttachmentCount = 1,
                    .pColorAttachments = &color_attachment,
                };

                std.debug.print("Beginning dynamic rendering\n", .{});
                vk.cmdBeginRenderingKHR(ctx.cmd, &rendering_info);
                std.debug.print("Color attachment: {any}\n", .{rendering_info});
                const pipeline = taskRenderer.pipeline.getPipeline("triangle") catch |err| {
                    std.debug.print("ERROR: Failed to get pipeline: {s}\n", .{@errorName(err)});
                    return;
                };
                std.debug.print("Binding pipeline\n", .{});
                vk.CmdBindPipeline(ctx.cmd, vk.PIPELINE_BIND_POINT_GRAPHICS, pipeline.asGraphics().?.getHandle().?);

                const viewport = vk.Viewport{
                    .x = 0.0,
                    .y = 0.0,
                    .width = @floatFromInt(ctx.frame.*.width),
                    .height = @floatFromInt(ctx.frame.*.height),
                    .minDepth = 0.0,
                    .maxDepth = 1.0,
                };

                std.debug.print("Setting viewport: {}x{}\n", .{ viewport.width, viewport.height });
                vk.CmdSetViewport(ctx.cmd, 0, 1, &viewport);

                const scissor = vk.Rect2D{
                    .offset = vk.Offset2D{ .x = 0, .y = 0 },
                    .extent = vk.Extent2D{ .width = ctx.frame.*.width, .height = ctx.frame.*.height },
                };

                std.debug.print("Setting scissor: {}x{}\n", .{ scissor.extent.width, scissor.extent.height });
                vk.CmdSetScissor(ctx.cmd, 0, 1, &scissor);

                std.debug.print("Drawing triangle (3 vertices)\n", .{});
                vk.CmdDraw(ctx.cmd, 3, 1, 0, 0);

                std.debug.print("Ending dynamic rendering\n", .{});
                vk.cmdEndRenderingKHR(ctx.cmd);
                std.debug.print("Triangle pass execution complete\n", .{});
            }
        }.execute;

        const trianglePass = Pass.init(renderAllocator, "triangle", trianglePassFn) catch |err| {
            std.debug.print("ERROR: Failed to initialize triangle pass: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Triangle pass initialized\n", .{});

        std.debug.print("Creating swapchain image resource...\n", .{});
        renderer.swapchainImageResource = renderAllocator.create(task.Resource) catch |err| {
            std.debug.print("ERROR: Failed to allocate memory for swapchain image resource: {s}\n", .{@errorName(err)});
            return null;
        };
        renderer.swapchainImageResource.* = task.Resource{
            .ty = task.ResourceType.Image,
            .name = "SwapchainImageResource",
            .handle = null,
            .view = null,
        };
        std.debug.print("Swapchain image resource created: {*}\n", .{renderer.swapchainImageResource});

        std.debug.print("Adding swapchain as input to triangle pass...\n", .{});
        trianglePass.addInput(renderer.swapchainImageResource, task.ResourceState{
            .accessMask = vk.ACCESS_COLOR_ATTACHMENT_WRITE,
            .stageMask = vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT,
            .layout = vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        }) catch |err| {
            std.debug.print("ERROR: Failed to add input to triangle pass: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Input added successfully\n", .{});

        std.debug.print("Adding passes to render graph...\n", .{});
        graph.addPass(trianglePass) catch |err| {
            std.debug.print("ERROR: Failed to add triangle pass to graph: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Triangle pass added to graph\n", .{});

        graph.addPass(&task.pass_submit) catch |err| {
            std.debug.print("ERROR: Failed to add submit pass to graph: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Submit pass added to graph\n", .{});

        graph.addPass(task.pass_present(renderer.swapchainImageResource)) catch |err| {
            std.debug.print("ERROR: Failed to add present pass to graph: {s}\n", .{@errorName(err)});
            return null;
        };
        std.debug.print("Present pass added to graph\n", .{});

        std.debug.print("Finalizing renderer setup...\n", .{});
        renderer.frame = Frame{
            .width = 800,
            .index = 0,
            .height = 600,
            .count = 0,
        };
        renderer.instance = instance;
        renderer.physicalDevice = physicalDevice;
        renderer.device = device;
        renderer.queue = queue;
        renderer.surface = activeVkSurface;
        renderer.pipeline = pipelineCompiler;
        renderer.swapchain = swapchain;
        // Store in renderer
        renderer.command_buffers = command_buffers;
        renderer.image_available_semaphores = image_available_semaphores;
        renderer.render_finished_semaphores = render_finished_semaphores;
        renderer.in_flight_fences = in_flight_fences;
        renderer.images_in_flight = images_in_flight;
        renderer.command_pool = command_pool;
        renderer.swapchainImages = swapchainImages;
        renderer.graph = graph;

        std.debug.print("Renderer initialization complete. Returning renderer: {*}\n", .{renderer});
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

    const renderer = Renderer.init(surface.?) catch |err| {
        std.debug.print("Renderer initialization failed: {s}\n", .{@errorName(err)});
        return null;
    };
    if (renderer == null) {
        std.debug.print("Renderer initialization failed.\n", .{});
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
    // Cleanup code herepub export fn destroy() void {

    defer std.debug.print("Vulkan instance destroyed.\n", .{}); // Cleanup code here
    defer std.debug.print("Vulkan instance destroyed.\n", .{});
}
pub export fn render(handle: ?*PlatformRenderer) void {
    // Get renderer...
    var renderer = platformRenderers.get(handle.?.*) orelse {
        return;
    };

    const activeFrame = &renderer.frame;
    const frameIndex = activeFrame.index;

    // Wait for this frame's fence
    std.debug.print("Waiting for frame {} fence\n", .{frameIndex});
    _ = vk.waitForFences(renderer.device, 1, &renderer.in_flight_fences[frameIndex], vk.TRUE, std.math.maxInt(u64));

    // Acquire next image using this frame's semaphore
    const result = vk.acquireNextImageKHR(renderer.device, renderer.swapchain, std.math.maxInt(u64), // Wait indefinitely
        renderer.image_available_semaphores[frameIndex], null, &activeFrame.index);

    // If image is being used by another frame, wait for that frame's fence
    if (renderer.images_in_flight[activeFrame.index] != null) {
        _ = vk.waitForFences(renderer.device, 1, &renderer.images_in_flight[activeFrame.index], vk.TRUE, std.math.maxInt(u64));
    }

    // Mark this image as being used by the current frame
    renderer.images_in_flight[activeFrame.index] = renderer.in_flight_fences[frameIndex];

    // Only reset the fence now after we've verified the image is available
    _ = vk.resetFences(renderer.device, 1, &renderer.in_flight_fences[frameIndex]);

    if (result == vk.NOT_READY) {
        return;
    }
    if (result == vk.OUT_OF_DATE) {
        // Get current surface capabilities to determine the proper swapchain size    if (result == vk.OUT_OF_DATE) {
        var capabilities: vk.SurfaceCapabilitiesKHR = undefined;
        _ = vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(renderer.physicalDevice, renderer.surface.?, &capabilities);
        // Use the current extent from surface capabilities
        const width = capabilities.currentExtent.width;
        const height = capabilities.currentExtent.height;
        std.debug.print("Recreating swapchain with dimensions: {}x{}\n", .{ width, height });
        renderer.swapchain = Renderer.createSwapchain(renderer.device, renderer.physicalDevice, renderer.surface.?, renderer.swapchain) catch |err| {
            std.debug.print("Failed to recreate swapchain: {s}\n", .{@errorName(err)});
            return;
        };
        renderer.swapchainImages = Renderer.getSwapchainImages(renderer.device, renderer.swapchain) catch |err| {
            std.debug.print("Failed to recreate swapchain image views: {s}\n", .{@errorName(err)});
            return;
        };
        renderer.frame.width = width;
        renderer.frame.height = height;
        renderer.frame.width = width;
        std.debug.print("Swapchain recreated successfully.\n", .{});
    }

    // Process swapchain image for current frame...
    renderer.swapchainImageResource.handle = task.ResourceHandle{ .image = renderer.swapchainImages[activeFrame.index] };

    // Create view...

    std.debug.print("Acquired image index: {}\n", .{activeFrame.index});
    std.debug.print("Swapchain image length: {}\n", .{renderer.swapchainImages.len});
    std.debug.print("Swapchain image: {any}\n", .{renderer.swapchainImages[0]});

    std.debug.print(
        "Swapchain image resource: {any}\n",
        .{renderer.swapchainImageResource},
    );
    renderer.swapchainImageResource.handle = task.ResourceHandle{ .image = renderer.swapchainImages[activeFrame.index] };
    renderer.swapchainImageResource.createView(renderer.device, vk.IMAGE_VIEW_TYPE_2D, vk.Format.B8G8R8A8Srgb) catch |err| {
        std.debug.print("Failed to create image view: {s}\n", .{@errorName(err)});
        return;
    };

    std.debug.print("execute", .{});
    // Execute the graph with the CURRENT frame's command buffer and synchronization objects
    const passContext = PassContext{
        .cmd = renderer.command_buffers[frameIndex],
        .queue = renderer.queue,
        .swapchain = renderer.swapchain,
        .render_finished_semaphore = renderer.render_finished_semaphores[frameIndex],
        .image_available_semaphore = renderer.image_available_semaphores[frameIndex],
        .in_flight_fence = renderer.in_flight_fences[frameIndex],
        .frame = activeFrame,
        .userData = renderer,
    };
    renderer.graph.execute(renderer.command_buffers[frameIndex], // Use frame-specific command buffer
        &renderer.frame, passContext // Pass frame index to the execute function
    ) catch |err| {
        std.debug.print("Failed to execute render graph: {s}\n", .{@errorName(err)});
        return;
    };
    // Advance to next frame
}
