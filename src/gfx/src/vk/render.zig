const inc = @import("include").render;

const vk = @import("vk.zig");
const logger = @import("../logger.zig");
// Import surface as a dependency
const sf = @import("surface");
const std = @import("std");
const pipelines = @import("pipeline.zig");
const task = @import("task.zig");
const frame = @import("frame.zig");
const math = @import("math");
const include = @import("include");

const Mat4 = math.Mat4;
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

const GpuCamera = struct {
    viewProjection: Mat4,
};

const camera_sys = @import("camera.zig");
const RendererCamera = camera_sys.RendererCamera;
const heap_mod = @import("heap.zig");
const stage_mod = @import("stage.zig");

// Constants for buffer sizes
const RENDERER_STAGING_BUFFER_SIZE = 1024 * 1024 * 8; // 8MB
const RENDERER_HEAP_BUFFER_SIZE = 1024 * 1024 * 1024; // 1GB

const Renderer = struct {
    const MAX_FRAMES_IN_FLIGHT = 3;
    instance: vk.Instance,
    physicalDevice: vk.PhysicalDevice,
    device: vk.Device,
    queue: vk.Queue,
    queue_family_index: u32,
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

    // Large heap and stage buffers for the renderer
    renderer_heap: ?*heap_mod.Heap,
    renderer_stage: ?*stage_mod.Stage,

    camera: ?*RendererCamera,
    camera_pass: ?*task.Pass,

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
                // // std.debug.print("Required extension not supported: {s}\n", .{req_name});
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

    fn createLogicalDevice(physical_device: vk.PhysicalDevice, qfi: u32, sync2_supported: bool) vk.Device {
        // Enable buffer device address feature
        var buffer_device_address_features = vk.PhysicalDeviceBufferDeviceAddressFeatures{
            .sType = vk.sTy(vk.StructureType.PhysicalDeviceBufferDeviceAddressFeatures),
            .pNext = null,
            .bufferDeviceAddress = vk.TRUE,
            .bufferDeviceAddressCaptureReplay = vk.TRUE,
            .bufferDeviceAddressMultiDevice = vk.FALSE,
        };

        // Add Synchronization2 features if supported
        var sync2_features = vk.PhysicalDeviceSynchronization2Features{
            .sType = vk.sTy(vk.StructureType.PhysicalDeviceSynchronization2FeaturesKHR),
            .pNext = &buffer_device_address_features,
            .synchronization2 = if (sync2_supported) vk.TRUE else vk.FALSE,
        };

        // Use device extensions
        var dynamic_rendering_features = vk.PhysicalDeviceDynamicRenderingFeatures{
            .sType = vk.sTy(vk.StructureType.PhysicalDeviceDynamicRenderingFeatures),
            .pNext = if (sync2_supported) &sync2_features else &buffer_device_address_features,
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
        logger.info("Initializing Vulkan renderer for surface ID: {}", .{surface.id});

        // Check instance extensions
        logger.info("Checking available instance extensions...", .{});
        const instance_extensions = getAvailableInstanceExtensions() catch {
            logger.err("Failed to get available instance extensions", .{});
            return null;
        };
        defer renderAllocator.free(instance_extensions);
        logger.info("Found {} instance extensions", .{instance_extensions.len});

        const instance_extensions_supported = checkExtensionsSupport(&InstanceExtensions, instance_extensions) catch |err| {
            logger.err("Error checking instance extensions: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Instance extensions supported: {}", .{instance_extensions_supported});

        logger.info("Creating Vulkan instance...", .{});
        const instance = Renderer.createInstance(instance_extensions_supported);
        if (instance == null) {
            logger.err("Failed to create Vulkan instance", .{});
            return null;
        }
        logger.info("Vulkan instance created successfully: {*}", .{instance});

        logger.info("Setting up Vulkan surface...", .{});
        const activeVkSurface = set: {
            if (instance_extensions_supported) {
                logger.info("Creating platform-specific surface for OS: {s}", .{@tagName(@import("builtin").os.tag)});
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
                        logger.err("Unsupported platform: {s}", .{@tagName(@import("builtin").os.tag)});
                        return null; // Unsupported platform
                    },
                };
                const vkSurface = Renderer.createSurface(instance, surface, platform_info);
                if (vkSurface == null) {
                    logger.err("Failed to create Vulkan surface", .{});
                    return null;
                }
                logger.info("Vulkan surface created successfully: {*}", .{vkSurface});
                break :set vkSurface;
            } else {
                logger.info("Running in Headless mode, surface extension not supported", .{});
                break :set undefined;
            }
        };

        logger.info("Selecting physical device...", .{});
        const physicalDevice = Renderer.determineBestPhysicalDevice(instance);
        if (physicalDevice == null) {
            logger.err("Failed to select suitable physical device", .{});
            return null;
        }
        logger.info("Selected physical device: {*}", .{physicalDevice});

        logger.info("Finding compatible queue family...", .{});
        const qfi = Renderer.getQueueFamilyIndex(physicalDevice, activeVkSurface) catch |err| {
            logger.err("Failed to get queue family index: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Selected queue family index: {}", .{qfi});

        // Check device extensions
        logger.info("Checking available device extensions...", .{});
        const device_extensions = getAvailableDeviceExtensions(physicalDevice) catch {
            logger.err("Failed to get available device extensions", .{});
            return null;
        };
        defer renderAllocator.free(device_extensions);
        logger.info("Found {} device extensions", .{device_extensions.len});

        const device_extensions_supported = checkExtensionsSupport(&DeviceExtensions, device_extensions) catch |err| {
            logger.err("Error checking device extensions: {s}", .{@errorName(err)});
            return null;
        };

        const sync2_extension_supported = checkExtensionsSupport(&Sync2Extensions, device_extensions) catch |err| {
            std.debug.print("ERROR: Error checking device extensions: {s}\n", .{@errorName(err)});
            return null;
        };
        if (!device_extensions_supported) {
            logger.err("Required device extensions not supported, renderer cannot be initialized", .{});
            return null;
        }
        logger.info("All required device extensions are supported", .{});

        logger.info("Creating logical device...", .{});
        const device: vk.Device = Renderer.createLogicalDevice(physicalDevice, qfi, sync2_extension_supported);
        if (device == null) {
            logger.err("Failed to create logical device", .{});
            return null;
        }
        logger.info("Logical device created successfully: {*}", .{device});

        logger.info("Loading device extension functions...", .{});
        vk.loadDeviceExtensionFunctions(device);
        logger.info("Device extension functions loaded", .{});

        logger.info("Getting device queue...", .{});
        const queue: vk.Queue = Renderer.getDeviceQueue(device, qfi);
        logger.info("Device queue obtained: {*}", .{queue});

        logger.info("Creating swapchain...", .{});
        const swapchain: vk.Swapchain = Renderer.createSwapchain(device, physicalDevice, activeVkSurface, null) catch |err| {
            logger.err("Failed to create swapchain: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Swapchain created successfully: {*}", .{swapchain});

        logger.info("Getting swapchain images...", .{});
        const swapchainImages: []vk.ImageView = Renderer.getSwapchainImages(device, swapchain) catch |err| {
            logger.err("Failed to get swapchain image views: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Retrieved {} swapchain images", .{swapchainImages.len});

        logger.info("Creating command pool...", .{});
        const command_pool = Renderer.createCommandPool(device, qfi) catch |err| {
            logger.err("Failed to create command pool: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Command pool created successfully: {*}", .{command_pool});

        // In your Renderer.init function:
        logger.info("Creating synchronization primitives for multiple frames in flight...", .{});

        // Create large heap buffer for the renderer
        logger.info("Creating large renderer heap buffer (1GB)...", .{});
        const renderer_heap = heap_mod.Heap.create(
            device,
            physicalDevice,
            RENDERER_HEAP_BUFFER_SIZE,
            vk.BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            renderAllocator,
        ) catch |err| {
            logger.err("Failed to create renderer heap: {s}", .{@errorName(err)});
            return null;
        };

        // Create large staging buffer for the renderer
        logger.info("Creating large renderer staging buffer (8MB)...", .{});
        const renderer_stage = stage_mod.Stage.createWithBufferTarget(
            device,
            physicalDevice,
            qfi,
            RENDERER_STAGING_BUFFER_SIZE,
            renderer_heap.getBuffer(),
            0, // Target offset 0
            renderAllocator,
        ) catch |err| {
            logger.err("Failed to create renderer stage: {s}", .{@errorName(err)});
            renderer_heap.destroy(device, renderAllocator);
            return null;
        };

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

        logger.info("Initializing pipeline compiler...", .{});
        const pipelineCompiler = PipelineCompiler.init(device) catch |err| {
            logger.err("Failed to initialize pipeline compiler: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Pipeline compiler initialized", .{});

        logger.info("Creating triangle graphics pipeline...", .{});
        _ = pipelineCompiler.createGraphicsPipeline("triangle", .{
            .vertex_shader = .{ .path = "src/gfx/src/vk/hellotriangle.glsl", .shader_type = .Vertex },
            .fragment_shader = .{ .path = "src/gfx/src/vk/hellotrianglef.glsl", .shader_type = .Fragment },
            .color_attachment_formats = &[_]vk.Format{vk.Format.B8G8R8A8Srgb},
        }) catch |err| {
            logger.err("Failed to create graphics pipeline: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Triangle graphics pipeline created successfully", .{});

        logger.info("Creating bindless triangle graphics pipeline...", .{});
        _ = pipelineCompiler.createGraphicsPipeline("bindless_triangle", .{
            .vertex_shader = .{
                .path = "src/gfx/src/vk/bindless_triangle.glsl",
                .shader_type = .Vertex
            },
            .fragment_shader = .{
                .path = "src/gfx/src/vk/bindless_trianglef.glsl",
                .shader_type = .Fragment
            },
            .color_attachment_formats = &[_]vk.Format{vk.Format.B8G8R8A8Srgb},
            // Add push constant range for the camera device address and model matrix
            .push_constant_size = @sizeOf(camera_sys.CameraPushConstants),
        }) catch |err| {
            logger.err("Failed to create bindless graphics pipeline: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Bindless triangle graphics pipeline created successfully", .{});

        logger.info("Creating synchronization primitives...", .{});
        const image_available_semaphore = Renderer.createSemaphore(device) catch |err| {
            logger.err("Failed to create image available semaphore: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Image available semaphore created: {*}", .{image_available_semaphore});

        const render_finished_semaphore = Renderer.createSemaphore(device) catch |err| {
            logger.err("Failed to create render finished semaphore: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Render finished semaphore created: {*}", .{render_finished_semaphore});

        const in_flight_fence = Renderer.createFence(device) catch |err| {
            logger.err("Failed to create in-flight fence: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("In-flight fence created: {*}", .{in_flight_fence});

        logger.info("Allocating renderer structure...", .{});
        var renderer = renderAllocator.create(Renderer) catch |err| {
            logger.err("Failed to allocate memory for renderer: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Renderer structure allocated: {*}", .{renderer});

        logger.info("Initializing render graph...", .{});
        const graph = Graph.init(renderAllocator, renderer, swapchain, render_finished_semaphore, image_available_semaphore, in_flight_fence, queue, sync2_extension_supported) catch |err| {
            logger.err("Failed to initialize graph: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Render graph initialized: {*}", .{graph});

        logger.info("Setting up triangle rendering pass...", .{});
        const trianglePassFn = struct {
            fn execute(ctx: PassContext) void {
                logger.info("Executing triangle pass...", .{});
                const taskRenderer = @as(*Renderer, @ptrCast(@alignCast(ctx.userData)));

                logger.info("Triangle pass context: cmd={*}, frame={}x{}", .{
                    ctx.cmd,
                    ctx.frame.*.width,
                    ctx.frame.*.height
                });

                if (ctx.pass.inputs.items.len == 0 or ctx.pass.inputs.items[0].resource.view == null) {
                    logger.err("No inputs for triangle pass", .{});
                    return;
                }


                // Get heap device address for bindless access
                logger.info("Getting heap device address...", .{});
                if (taskRenderer.renderer_heap == null) {
                    logger.err("Renderer heap is null!", .{});
                    return;
                }

                const heapAddress = taskRenderer.renderer_heap.?.getDeviceAddress() catch |err| {
                    logger.err("Failed to get heap device address: {s}", .{@errorName(err)});
                    return;
                };
                logger.info("Heap device address: 0x{x}", .{heapAddress});

                // Create push constant data with the heap address
                logger.info("Creating push constants...", .{});

                // Check that m4Id returns a valid matrix
                const modelMatrix = math.m4Id();
                logger.info("Model matrix from m4Id: {any}", .{modelMatrix});

                // Print out the data array to verify it's a proper identity matrix
                logger.info("Model matrix data array:", .{});
                for (0..4) |col| {
                    logger.info("Col {}: [{}, {}, {}, {}]", .{
                        col,
                        modelMatrix.data[col*4+0], modelMatrix.data[col*4+1],
                        modelMatrix.data[col*4+2], modelMatrix.data[col*4+3],
                    });
                }

                // Create push constants with the verified model matrix
                const pushConstants = camera_sys.CameraPushConstants{
                    .heap_address = heapAddress,
                    .model_matrix = modelMatrix,
                };
                logger.info("Push constants created with heap_address=0x{x}", .{pushConstants.heap_address});

                logger.info("Setting up color attachment for frame {}x{}", .{ ctx.frame.*.width, ctx.frame.*.height });
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
                            .float32 = [_]f32{ 0.1, 0.1, 0.1, 1.0 },
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

                logger.info("Beginning dynamic rendering", .{});
                vk.cmdBeginRenderingKHR(ctx.cmd, &rendering_info);
                logger.debug("Color attachment: {any}", .{rendering_info});

                // Use the bindless pipeline instead of the regular triangle pipeline
                logger.info("Getting bindless_triangle pipeline...", .{});
                const pipeline = taskRenderer.pipeline.getPipeline("bindless_triangle") catch |err| {
                    logger.err("Failed to get bindless pipeline: {s}", .{@errorName(err)});
                    return;
                };
                logger.info("Pipeline obtained: {*}", .{pipeline});

                logger.info("Binding pipeline", .{});
                vk.CmdBindPipeline(ctx.cmd, vk.PIPELINE_BIND_POINT_GRAPHICS, pipeline.asGraphics().?.getHandle().?);

                const viewport = vk.Viewport{
                    .x = 0.0,
                    .y = 0.0,
                    .width = @floatFromInt(ctx.frame.*.width),
                    .height = @floatFromInt(ctx.frame.*.height),
                    .minDepth = 0.0,
                    .maxDepth = 1.0,
                };

                logger.info("Setting viewport: {}x{}", .{ viewport.width, viewport.height });
                vk.CmdSetViewport(ctx.cmd, 0, 1, &viewport);

                const scissor = vk.Rect2D{
                    .offset = vk.Offset2D{ .x = 0, .y = 0 },
                    .extent = vk.Extent2D{ .width = ctx.frame.*.width, .height = ctx.frame.*.height },
                };

                logger.info("Setting scissor: {}x{}", .{ scissor.extent.width, scissor.extent.height });
                vk.CmdSetScissor(ctx.cmd, 0, 1, &scissor);

                // Push the constants to the shader
                logger.info("Pushing constants with heap address: 0x{x}", .{heapAddress});
                if (pipeline.asGraphics() == null) {
                    logger.err("Pipeline is not a graphics pipeline", .{});
                    return;
                }

                const pipelineLayout = pipeline.asGraphics().?.base.layout;
                logger.info("Pipeline layout: {*}", .{pipelineLayout});

                // Verify the push constant size
                const pushConstantsSize = @sizeOf(camera_sys.CameraPushConstants);
                logger.info("Push constants size: {} bytes", .{pushConstantsSize});
                logger.info("Model matrix in push constants: {any}", .{pushConstants.model_matrix});

                // Calculate raw pointer offset to model matrix for debugging
                const modelMatrixOffset = @offsetOf(camera_sys.CameraPushConstants, "model_matrix");
                logger.info("Model matrix offset in push constants: {} bytes", .{modelMatrixOffset});

                // Verify the first few bytes of push constants to check alignment
                const pushConstantsPtr = @as([*]const u8, @ptrCast(&pushConstants));
                logger.info("First 16 bytes of push constants: {any}", .{pushConstantsPtr[0..16]});

                vk.CmdPushConstants(ctx.cmd,
                    pipelineLayout,
                    vk.SHADER_STAGE_VERTEX_BIT | vk.SHADER_STAGE_FRAGMENT_BIT,
                    0,
                    pushConstantsSize,
                    &pushConstants);

                logger.info("Drawing triangle (3 vertices) with cmd={*}", .{ctx.cmd});
                vk.CmdDraw(ctx.cmd, 3, 1, 0, 0);
                logger.info("Draw call completed", .{});

                logger.info("Ending dynamic rendering", .{});
                vk.cmdEndRenderingKHR(ctx.cmd);
                logger.info("Triangle pass execution complete", .{});
            }
        }.execute;

        const trianglePass = Pass.init(renderAllocator, "triangle", trianglePassFn) catch {
            return null;
        };
        // CRITICAL FIX: Set the renderer as userData for the triangle pass
        // This ensures the triangle pass has access to the renderer during execution
        trianglePass.userData = renderer;
        logger.info("Triangle pass initialized with renderer userData: {*}", .{renderer});

        logger.info("Creating swapchain image resource...", .{});
        renderer.swapchainImageResource = renderAllocator.create(task.Resource) catch |err| {
            logger.err("Failed to allocate memory for swapchain image resource: {s}", .{@errorName(err)});
            return null;
        };
        renderer.swapchainImageResource.* = task.Resource{
            .ty = task.ResourceType.Image,
            .name = "SwapchainImageResource",
            .handle = null,
            .view = null,
        };
        logger.info("Swapchain image resource created: {*}", .{renderer.swapchainImageResource});

        logger.info("Adding swapchain as input to triangle pass...", .{});
        trianglePass.addInput(renderer.swapchainImageResource, task.ResourceState{
            .accessMask = vk.ACCESS_COLOR_ATTACHMENT_WRITE,
            .stageMask = vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT,
            .layout = vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        }) catch |err| {
            logger.err("Failed to add input to triangle pass: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Input added successfully", .{});

        // Initialize camera system using renderer's heap and stage
        logger.info("Initializing camera system with renderer's heap and stage...", .{});
        renderer.camera = RendererCamera.create(
            device,
            renderer_heap,
            renderer_stage,
            renderAllocator
        ) catch |err| {
            logger.err("Failed to initialize camera system: {s}", .{@errorName(err)});
            renderer.camera = null;
            renderer.camera_pass = null;
            return null;
        };

        // Create camera pass and add it to the graph
        logger.info("Creating camera update pass...", .{});
        renderer.camera_pass = renderer.camera.?.createCameraPass("CameraUpdate") catch |err| {
            logger.err("Failed to create camera pass: {s}", .{@errorName(err)});
            renderer.camera_pass = null;
            return null;
        };

        // Set initial camera at position 0,0,5 looking toward the triangle at z=-2
        const initial_position = math.v3(0.0, 0.0, 5.0);
        const look_target = math.v3(0.0, 0.0, -2.0); // Look at where the triangle is positioned
        const initial_view = math.m4LookAt(
            initial_position,
            look_target,
            math.v3Z() // Using Z as up vector as requested
        );
        const initial_projection = math.m4Persp(
            math.rad(45.0),
            @as(f32, @floatFromInt(renderer.frame.width)) / @as(f32, @floatFromInt(renderer.frame.height)),
            0.1,
            1000.0
        );

        _ = renderer.camera.?.update(initial_view, initial_projection) catch |err| {
            logger.warn("Failed to set initial camera: {s}", .{@errorName(err)});
        };

        logger.info("Adding passes to render graph...", .{});

        // Add camera pass to the graph BEFORE triangle pass
        logger.info("Adding camera pass to render graph...", .{});
        graph.addPass(renderer.camera_pass.?) catch |err| {
            logger.err("Failed to add camera pass to graph: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Camera pass added to graph", .{});

        // Now add the triangle pass after the camera pass
        graph.addPass(trianglePass) catch |err| {
            logger.err("Failed to add triangle pass to graph: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Triangle pass added to graph", .{});

        var submitPass = task.getPassSubmit(renderer);
        submitPass.userData = renderer;
        graph.addPass(submitPass) catch |err| {
            logger.err("Failed to add submit pass to graph: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Submit pass added to graph", .{});

        var presentPass = task.pass_present(renderer.swapchainImageResource);
        presentPass.userData = renderer;
        graph.addPass(presentPass) catch |err| {
            logger.err("Failed to add present pass to graph: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Present pass added to graph", .{});

        logger.info("Finalizing renderer setup...", .{});
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
        renderer.queue_family_index = qfi;
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
        renderer.renderer_heap = renderer_heap;
        renderer.renderer_stage = renderer_stage;

        logger.info("Renderer initialization complete. Returning renderer: {*}", .{renderer});
        return renderer;
    }
};

pub export fn init(surface: ?*Surface) ?*PlatformRenderer {
    // Fixed export with name that matches Rust's expectation
    if (surface == null) {
        logger.err("Surface is null.", .{});
        return null;
    }
    if (surfaceRenderers.contains(surface.?.*)) {
        logger.warn("Renderer already exists for this surface.", .{});
        return null;
    }

    const renderer = Renderer.init(surface.?) catch |err| {
        logger.err("Renderer initialization failed: {s}", .{@errorName(err)});
        return null;
    };
    if (renderer == null) {
        logger.err("Renderer initialization failed.", .{});
        return null;
    }

    const id = platformRendererActive;
    platformRendererActive.id += 1;
    platformRenderers.put(id, renderer.?) catch |err| {
        logger.err("Failed to allocate memory for renderer: {s}", .{@errorName(err)});
        return null;
    };
    surfaceRenderers.put(surface.?.*, id) catch |err| {
        logger.err("Failed to allocate memory for renderer: {s}", .{@errorName(err)});
        return null;
    };
    logger.info("Renderer initialized successfully.", .{});
    logger.info("Renderer ID: {}", .{id});
    logger.info("Renderer pointer: {}", .{renderer.?.*});
    logger.info("Surface pointer: {}", .{surface.?.*});
    logger.info("Surface ID: {}", .{surface.?.*});

    const platform_renderer = renderAllocator.create(PlatformRenderer) catch |err| {
        logger.err("Failed to allocate memory for platform renderer: {s}", .{@errorName(err)});
        return null;
    };
    platform_renderer.* = id;
    return platform_renderer;
}

pub export fn shutdown(handle: ?*PlatformRenderer) void {
    if (handle == null) return;

    var renderer = platformRenderers.get(handle.?.*) orelse {
        return;
    };

    // Cleanup camera resources if they exist
    if (renderer.camera != null) {
        renderer.camera.?.destroy();
        renderer.camera = null;
        renderer.camera_pass = null;
    }

    // Cleanup renderer stage and heap
    if (renderer.renderer_stage != null) {
        renderer.renderer_stage.?.destroy();
        renderer.renderer_stage = null;
    }

    if (renderer.renderer_heap != null) {
        renderer.renderer_heap.?.destroy(renderer.device, renderAllocator);
        renderer.renderer_heap = null;
    }

    // Wait for the device to be idle before destroying resources
    _ = vk.deviceWaitIdle(renderer.device);

    // Clean up task graph resources
    renderer.graph.deinit();

    // Clean up synchronization objects
    for (0..Renderer.MAX_FRAMES_IN_FLIGHT) |i| {
        vk.destroySemaphore(renderer.device, renderer.image_available_semaphores[i], null);
        vk.destroySemaphore(renderer.device, renderer.render_finished_semaphores[i], null);
        vk.destroyFence(renderer.device, renderer.in_flight_fences[i], null);
    }

    // Free allocated memory
    renderAllocator.free(renderer.image_available_semaphores);
    renderAllocator.free(renderer.render_finished_semaphores);
    renderAllocator.free(renderer.in_flight_fences);
    renderAllocator.free(renderer.images_in_flight);
    renderAllocator.free(renderer.command_buffers);

    // Destroy Vulkan objects
    vk.destroyCommandPool(renderer.device, renderer.command_pool);
    vk.destroySwapchainKHR(renderer.device, renderer.swapchain, null);
    vk.destroyDevice(renderer.device, null);

    if (renderer.surface != null) {
        vk.destroySurfaceKHR(renderer.instance, renderer.surface.?, null);
    }

    vk.destroyInstance(renderer.instance, null);

    // Remove from maps
    _ = platformRenderers.remove(handle.?.*);

    // Find and remove from surfaceRenderers by value
    var sr_it = surfaceRenderers.iterator();
    while (sr_it.next()) |entry| {
        if (std.meta.eql(entry.value_ptr.*, handle.?.*)) {
            _ = surfaceRenderers.remove(entry.key_ptr.*);
            break;
        }
    }

    renderAllocator.destroy(renderer);
    renderAllocator.destroy(handle.?);

    logger.info("Vulkan renderer destroyed.", .{});
}
pub export fn render(handle: ?*PlatformRenderer) void {
    logger.info("Render function called with handle: {*}", .{handle});

    // Get renderer...
    var renderer = platformRenderers.get(handle.?.*) orelse {
        logger.err("Could not find renderer for handle {*}", .{handle});
        return;
    };
    logger.info("Found renderer: {*}", .{renderer});

    const activeFrame = &renderer.frame;
    const frameIndex = activeFrame.index;
    logger.info("Active frame index: {}, width: {}, height: {}", .{frameIndex, activeFrame.width, activeFrame.height});

    // Wait for this frame's fence
    std.debug.print("[RENDER] SYNC: Waiting for frame {} fence {any}...\n", .{frameIndex, renderer.in_flight_fences[frameIndex]});
    const wait_result = vk.waitForFences(renderer.device, 1, &renderer.in_flight_fences[frameIndex], vk.TRUE, std.math.maxInt(u64));
    std.debug.print("[RENDER] SYNC: Wait result: {any}\n", .{wait_result});

    // Acquire next image using this frame's semaphore
    std.debug.print("[RENDER] SYNC: Acquiring next image with semaphore {any}...\n", .{renderer.image_available_semaphores[frameIndex]});
    const result = vk.acquireNextImageKHR(renderer.device, renderer.swapchain, std.math.maxInt(u64), // Wait indefinitely
        renderer.image_available_semaphores[frameIndex], null, &activeFrame.index);
    std.debug.print("[RENDER] SYNC: Acquire result: {any}, image index: {}\n", .{result, activeFrame.index});

    // If image is being used by another frame, wait for that frame's fence
    if (renderer.images_in_flight[activeFrame.index] != null) {
        std.debug.print("[RENDER] SYNC: Image {} is in use by another frame, waiting for fence {any}...\n",
                     .{activeFrame.index, renderer.images_in_flight[activeFrame.index]});
        const img_wait_result = vk.waitForFences(renderer.device, 1, &renderer.images_in_flight[activeFrame.index], vk.TRUE, std.math.maxInt(u64));
        std.debug.print("[RENDER] SYNC: Image wait result: {any}\n", .{img_wait_result});
    } else {
        std.debug.print("[RENDER] SYNC: Image {} is not in use by another frame\n", .{activeFrame.index});
    }

    // Mark this image as being used by the current frame
    std.debug.print("[RENDER] SYNC: Marking image {} as used by frame {} (fence {any})\n",
                 .{activeFrame.index, frameIndex, renderer.in_flight_fences[frameIndex]});
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
        return;
    }


    logger.debug("Acquired image index: {}", .{activeFrame.index});
    logger.debug("Swapchain image length: {}", .{renderer.swapchainImages.len});
    logger.debug("Swapchain image: {any}", .{renderer.swapchainImages[0]});

    std.debug.print(
        "Swapchain image resource: {any}\n",
        .{renderer.swapchainImageResource},
    );
    renderer.swapchainImageResource.handle = task.ResourceHandle{ .image = renderer.swapchainImages[activeFrame.index] };
    renderer.swapchainImageResource.createView(renderer.device, vk.IMAGE_VIEW_TYPE_2D, vk.Format.B8G8R8A8Srgb) catch |err| {
        std.debug.print("Failed to create image view: {s}\n", .{@errorName(err)});
        return;
    };


    logger.info("Executing render commands for frame {}", .{frameIndex});

    // Log command buffer state
    logger.info("Using command buffer: {*}", .{renderer.command_buffers[frameIndex]});

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

    logger.info("Starting graph execution with context: cmd={*}, queue={*}, fence={*}",
        .{passContext.cmd, passContext.queue, passContext.in_flight_fence});

    // Update the camera pass with the latest upload offset before executing the graph
    if (renderer.camera != null and renderer.camera_pass != null) {
        logger.info("Updating camera pass with latest upload offset", .{});
        renderer.camera.?.updateCameraPass(renderer.camera_pass.?);
    }

    renderer.graph.execute(renderer.command_buffers[frameIndex], // Use frame-specific command buffer
        passContext // Pass context to the execute function
    ) catch |err| {
        logger.err("Failed to execute render graph: {s}", .{@errorName(err)});
        return;
    };

    logger.info("Graph execution completed successfully", .{});
    // Advance to next frame
}

pub export fn setCamera(handle: ?*include.render.Renderer, camera: *const include.render.Camera) void {
        if (handle == null) return;

    var renderer = platformRenderers.get(handle.?.*) orelse {
        return;
    };
    const position = camera.position;
    const rotation = camera.rotation;
    const translationMatrix = math.m4TransV3(position);
    const rotationMatrix = math.qToM4(rotation);
    const transform = math.m4Mul(translationMatrix, rotationMatrix);
    const view = math.m4Inv(transform);
    // If the camera system is available, update it
    if (renderer.camera != null) {
        _ = renderer.camera.?.update(view, camera.projection) catch |err| {
            std.debug.print("Failed to update camera in setCamera: {s}\n", .{@errorName(err)});
            return;
        };
    }
}
