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
const ctx = @import("ctx.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var renderAllocator: std.mem.Allocator = gpa.allocator();
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

pub const Context = struct {
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

    // Initialize Vulkan context
    pub fn init(surface: *Surface) !?*Context {
        logger.info("Initializing Vulkan context for surface ID: {}", .{surface.id});

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
        const instance = Context.createInstance(&InstanceExtensions);
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
                const vkSurface = Context.createSurface(instance, platform_info) orelse {
                    logger.err("Failed to create Vulkan surface", .{});
                    return null;
                };
                logger.info("Vulkan surface created successfully: {*}", .{vkSurface});
                break :set vkSurface;
            } else {
                logger.info("Running in Headless mode, surface extension not supported", .{});
                break :set undefined;
            }
        };

        logger.info("Selecting physical device...", .{});
        const physicalDevice = Context.determineBestPhysicalDevice(instance);
        if (physicalDevice == null) {
            logger.err("Failed to select suitable physical device", .{});
            return null;
        }
        logger.info("Selected physical device: {*}", .{physicalDevice});

        logger.info("Finding compatible queue family...", .{});
        const qfi = Context.getQueueFamilyIndex(physicalDevice, activeVkSurface) catch |err| {
            logger.err("Failed to get queue family index: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Selected queue family index: {}", .{qfi});

        // Check device extensions
        logger.info("Checking available device extensions...", .{});
        const device_extensions = Context.getAvailableDeviceExtensions(physicalDevice) catch {
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
            logger.err("Required device extensions not supported, context cannot be initialized", .{});
            return null;
        }
        logger.info("All required device extensions are supported", .{});

        logger.info("Creating logical device...", .{});
        const device: vk.Device = Context.createLogicalDevice(physicalDevice, qfi, sync2_extension_supported);
        if (device == null) {
            logger.err("Failed to create logical device", .{});
            return null;
        }
        logger.info("Logical device created successfully: {*}", .{device});

        logger.info("Loading device extension functions...", .{});
        vk.loadDeviceExtensionFunctions(device);
        logger.info("Device extension functions loaded", .{});

        logger.info("Getting device queue...", .{});
        const queue: vk.Queue = Context.getDeviceQueue(device, qfi);
        logger.info("Device queue obtained: {*}", .{queue});

        logger.info("Creating swapchain...", .{});
        const swapchain: vk.Swapchain = Context.createSwapchain(device, physicalDevice, activeVkSurface, null) catch |err| {
            logger.err("Failed to create swapchain: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Swapchain created successfully: {*}", .{swapchain});

        logger.info("Getting swapchain images...", .{});
        const swapchainImages: []vk.ImageView = Context.getSwapchainImages(device, swapchain) catch |err| {
            logger.err("Failed to get swapchain image views: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Retrieved {} swapchain images", .{swapchainImages.len});

        logger.info("Creating command pool...", .{});
        const command_pool = Context.createCommandPool(device, qfi) catch |err| {
            logger.err("Failed to create command pool: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Command pool created successfully: {*}", .{command_pool});

        // Allocate arrays
        const command_buffers = try renderAllocator.alloc(vk.CommandBuffer, MAX_FRAMES_IN_FLIGHT);
        const image_available_semaphores = try renderAllocator.alloc(vk.Semaphore, MAX_FRAMES_IN_FLIGHT);
        const render_finished_semaphores = try renderAllocator.alloc(vk.Semaphore, MAX_FRAMES_IN_FLIGHT);
        const in_flight_fences = try renderAllocator.alloc(vk.Fence, MAX_FRAMES_IN_FLIGHT);

        // Create objects for each frame
        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            command_buffers[i] = try Context.allocCommandBuffer(device, command_pool);
            image_available_semaphores[i] = try Context.createSemaphore(device);
            render_finished_semaphores[i] = try Context.createSemaphore(device);
            in_flight_fences[i] = try Context.createFence(device);
        }

        // Create array to track which images are in use
        var images_in_flight = try renderAllocator.alloc(vk.Fence, swapchainImages.len);
        // Initialize all entries to null/invalid
        for (0..swapchainImages.len) |i| {
            images_in_flight[i] = null;
        }

        // Allocate context structure
        var context = renderAllocator.create(Context) catch |err| {
            logger.err("Failed to allocate memory for context: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Context structure allocated: {*}", .{context});

        // Initialize context fields
        context.instance = instance;
        context.physicalDevice = physicalDevice;
        context.device = device;
        context.queue = queue;
        context.queue_family_index = qfi;
        context.surface = activeVkSurface;
        context.swapchain = swapchain;
        context.swapchainImages = swapchainImages;
        context.command_pool = command_pool;
        context.command_buffers = command_buffers;
        context.image_available_semaphores = image_available_semaphores;
        context.render_finished_semaphores = render_finished_semaphores;
        context.in_flight_fences = in_flight_fences;
        context.images_in_flight = images_in_flight;

        logger.info("Vulkan context initialization complete. Returning context: {*}", .{context});
        return context;
    }

    // Clean up Vulkan resources
    pub fn deinit(self: *Context) void {
        // Wait for the device to be idle before destroying resources
        _ = vk.deviceWaitIdle(self.device);

        // Clean up synchronization objects
        for (0..MAX_FRAMES_IN_FLIGHT) |i| {
            vk.destroySemaphore(self.device, self.image_available_semaphores[i], null);
            vk.destroySemaphore(self.device, self.render_finished_semaphores[i], null);
            vk.destroyFence(self.device, self.in_flight_fences[i], null);
        }

        // Free allocated memory
        renderAllocator.free(self.image_available_semaphores);
        renderAllocator.free(self.render_finished_semaphores);
        renderAllocator.free(self.in_flight_fences);
        renderAllocator.free(self.images_in_flight);
        renderAllocator.free(self.command_buffers);

        // Destroy Vulkan objects
        vk.destroyCommandPool(self.device, self.command_pool);
        vk.destroySwapchainKHR(self.device, self.swapchain, null);
        vk.destroyDevice(self.device, null);

        if (self.surface != null) {
            vk.destroySurfaceKHR(self.instance, self.surface.?, null);
        }

        vk.destroyInstance(self.instance, null);

        renderAllocator.destroy(self);
        logger.info("Vulkan context destroyed.", .{});
    }

    pub fn maximumReasonableDispatchSize(self: *Context) math.UVec3 {
        var device_properties: vk.PhysicalDeviceProperties = undefined;
        vk.getPhysicalDeviceProperties(self.physicalDevice, &device_properties);

        const max_x = (device_properties.limits.maxComputeWorkGroupSize[0] * 8) / 10;
        const max_y = (device_properties.limits.maxComputeWorkGroupSize[1] * 8) / 10;
        const max_z = (device_properties.limits.maxComputeWorkGroupSize[2] * 8) / 10;

        var workgroup_size_x: u32 = 1;
        while (workgroup_size_x * 2 <= max_x) : (workgroup_size_x *= 2) {}

        var workgroup_size_y: u32 = 1;
        while (workgroup_size_y * 2 <= max_y) : (workgroup_size_y *= 2) {}

        var workgroup_size_z: u32 = 1;
        while (workgroup_size_z * 2 <= max_z) : (workgroup_size_z *= 2) {}

        return math.UVec3.fromArray(&[_]u32{ workgroup_size_x, workgroup_size_y, workgroup_size_z });
    }

    // Recreate swapchain when surface dimensions change
    pub fn recreateSwapchain(self: *Context) !void {
        // get current surface capabilities to determine the proper swapchain size
        var capabilities: vk.SurfaceCapabilitiesKHR = undefined;
        _ = vk.getPhysicalDeviceSurfaceCapabilitiesKHR(self.physicalDevice, self.surface.?, &capabilities);
        // Use the current extent from surface capabilities
        const width = capabilities.currentExtent.width;
        const height = capabilities.currentExtent.height;
        std.debug.print("Recreating swapchain with dimensions: {}x{}\n", .{ width, height });

        // Wait for all operations to complete before recreating swapchain
        std.debug.print("Waiting for device idle before recreating swapchain...\n", .{});
        _ = vk.deviceWaitIdle(self.device);

        // Store the old swapchain to properly clean up later
        const oldSwapchain = self.swapchain;

        // Recreate swapchain
        self.swapchain = Context.createSwapchain(self.device, self.physicalDevice, self.surface.?, oldSwapchain) catch |err| {
            std.debug.print("Failed to recreate swapchain: {s}\n", .{@errorName(err)});
            return err;
        };

        // Clean up old swapchain images before getting new ones
        renderAllocator.free(self.swapchainImages);

        self.swapchainImages = Context.getSwapchainImages(self.device, self.swapchain) catch |err| {
            std.debug.print("Failed to recreate swapchain image views: {s}\n", .{@errorName(err)});
            return err;
        };

        // Update images_in_flight array to match the new swapchain image count
        renderAllocator.free(self.images_in_flight);
        self.images_in_flight = renderAllocator.alloc(vk.Fence, self.swapchainImages.len) catch |err| {
            std.debug.print("Failed to allocate memory for images_in_flight: {s}\n", .{@errorName(err)});
            return err;
        };

        // Initialize all entries to null/invalid
        for (0..self.swapchainImages.len) |i| {
            self.images_in_flight[i] = null;
        }

        std.debug.print("Swapchain recreated successfully.\n", .{});
    }

    // Acquire next image from swapchain
    pub fn acquireNextImage(self: *Context, frameIndex: u32) !u32 {
        // Wait for this frame's fence
        std.debug.print("[RENDER] SYNC: Waiting for frame {} fence {any}...\n", .{ frameIndex, self.in_flight_fences[frameIndex] });
        const wait_result = vk.waitForFences(self.device, 1, &self.in_flight_fences[frameIndex], vk.TRUE, std.math.maxInt(u64));
        std.debug.print("[RENDER] SYNC: Wait result: {any}\n", .{wait_result});

        // Acquire next image using this frame's semaphore
        std.debug.print("[RENDER] SYNC: Acquiring next image with semaphore {any}...\n", .{self.image_available_semaphores[frameIndex]});
        var imageIndex: u32 = undefined;
        const result = vk.acquireNextImageKHR(self.device, self.swapchain, std.math.maxInt(u64), // Wait indefinitely
            self.image_available_semaphores[frameIndex], null, &imageIndex);
        std.debug.print("[RENDER] SYNC: Acquire result: {any}, image index: {}\n", .{ result, imageIndex });

        // If image is being used by another frame, wait for that frame's fence
        if (result == vk.SUCCESS) {
            if (self.images_in_flight[imageIndex] != null) {
                std.debug.print("[RENDER] SYNC: Image {} is in use by another frame, waiting for fence {any}...\n", .{ imageIndex, self.images_in_flight[imageIndex] });
                const img_wait_result = vk.waitForFences(self.device, 1, &self.images_in_flight[imageIndex], vk.TRUE, std.math.maxInt(u64));
                std.debug.print("[RENDER] SYNC: Image wait result: {any}\n", .{img_wait_result});
            } else {
                std.debug.print("[RENDER] SYNC: Image {} is not in use by another frame\n", .{imageIndex});
            }

            // Mark this image as being used by the current frame
            std.debug.print("[RENDER] SYNC: Marking image {} as used by frame {} (fence {any})\n", .{ imageIndex, frameIndex, self.in_flight_fences[frameIndex] });
            self.images_in_flight[imageIndex] = self.in_flight_fences[frameIndex];

            // Only reset the fence now after we've verified the image is available
            _ = vk.resetFences(self.device, 1, &self.in_flight_fences[frameIndex]);
        }

        if (result == vk.NOT_READY) {
            return error.NotReady;
        }
        if (result == vk.OUT_OF_DATE or result == vk.SUBOPTIMAL_KHR) {
            try self.recreateSwapchain();
            return error.OutOfDate;
        }

        return imageIndex;
    }

    // Helper functions for Vulkan operations
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

    // Additional Vulkan helper functions would be moved here from render.zig
    // Including createInstance, createSurface, determineBestPhysicalDevice, etc.

    // Create a Vulkan instance with the required extensions
    fn createInstance(required_extensions: []const [*:0]const u8) vk.Instance {
        const app_info = vk.ApplicationInfo{
            .sType = vk.sTy(vk.StructureType.AppInfo),
            .pNext = null,
            .pApplicationName = "Angelite",
            .applicationVersion = vk.MAKE_VERSION(1, 0, 0),
            .pEngineName = "Angelite Engine",
            .engineVersion = vk.MAKE_VERSION(1, 0, 0),
            .apiVersion = vk.API_VERSION_1_3,
        };

        const create_info = vk.InstanceCreateInfo{
            .sType = vk.sTy(vk.StructureType.InstanceInfo),
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = @as(u32, @intCast(required_extensions.len)),
            .ppEnabledExtensionNames = required_extensions.ptr,
        };

        var instance: vk.Instance = undefined;
        const result = vk.createInstance(&create_info, null, &instance);
        if (result != vk.SUCCESS) {
            logger.err("Failed to create instance: {}", .{result});
            return null;
        }
        return instance.?;
    }

    // Create a platform-specific surface
    fn createSurface(instance: vk.Instance, platform_info: vk.PlatformSpecificInfo) vk.Surface {
        const surface = vk.createSurface(instance, platform_info);
        if (surface == null) {
            logger.err("Failed to create surface", .{});
            return null;
        }
        return surface.?;
    }

    // Determine the best physical device based on device properties
    fn determineBestPhysicalDevice(instance: vk.Instance) vk.PhysicalDevice {
        var device_count: u32 = 0;
        _ = vk.enumeratePhysicalDevices(instance, &device_count, null);
        if (device_count == 0) {
            logger.err("Failed to find GPUs with Vulkan support", .{});
            return null;
        }

        const devices = renderAllocator.alloc(vk.PhysicalDevice, device_count) catch {
            logger.err("Failed to allocate memory for physical devices", .{});
            return null;
        };
        defer renderAllocator.free(devices);

        _ = vk.enumeratePhysicalDevices(instance, &device_count, devices.ptr);

        // Score each device and pick the best one
        var best_score: u32 = 0;
        var best_device: vk.PhysicalDevice = null;

        for (devices) |device| {
            const score = Context.rateDeviceSuitability(device);
            if (score > best_score) {
                best_score = score;
                best_device = device;
            }
        }

        if (best_device == null) {
            logger.err("Failed to find a suitable GPU", .{});
            return null;
        }

        return best_device;
    }

    // Rate a physical device based on its properties
    fn rateDeviceSuitability(device: vk.PhysicalDevice) u32 {
        var device_properties: vk.PhysicalDeviceProperties = undefined;
        var device_features: vk.PhysicalDeviceFeatures = undefined;
        vk.getPhysicalDeviceProperties(device, &device_properties);
        vk.getPhysicalDeviceFeatures(device, &device_features);

        var score: u32 = 0;

        // Discrete GPUs have a significant performance advantage
        if (device_properties.deviceType == vk.PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
            score += 1000;
        }

        // Maximum possible size of textures affects graphics quality
        score += device_properties.limits.maxImageDimension2D;

        // Check for required queue families
        var queue_family_count = Context.getQueueFamilyCount(device);
        var has_graphics_queue = false;
        var has_compute_queue = false;

        const queue_family_properties = renderAllocator.alloc(vk.QueueFamilyProperties, queue_family_count) catch {
            logger.err("Failed to allocate memory for queue family properties", .{});
            return 0;
        };
        defer renderAllocator.free(queue_family_properties);

        vk.getPhysicalDeviceQueueFamilyProperties(device, &queue_family_count, queue_family_properties.ptr);

        for (0..queue_family_count) |i| {
            const queue_props = queue_family_properties[i];

            if ((queue_props.queueFlags & vk.QUEUE_GRAPHICS_BIT) != 0) {
                has_graphics_queue = true;
            }
            if ((queue_props.queueFlags & vk.QUEUE_COMPUTE_BIT) != 0) {
                has_compute_queue = true;
            }
        }

        if (!has_graphics_queue or !has_compute_queue) {
            return 0;
        }

        return score;
    }

    // get the number of queue families for a physical device
    fn getQueueFamilyCount(device: vk.PhysicalDevice) u32 {
        var count: u32 = 0;
        vk.getPhysicalDeviceQueueFamilyProperties(device, &count, null);
        return count;
    }

    // Find a queue family that supports graphics operations
    fn getQueueFamilyIndex(physical_device: vk.PhysicalDevice, surface: vk.Surface) !u32 {
        var queue_family_count = Context.getQueueFamilyCount(physical_device);
        const queue_family_properties = try renderAllocator.alloc(vk.QueueFamilyProperties, queue_family_count);
        defer renderAllocator.free(queue_family_properties);

        vk.getPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_family_properties.ptr);

        // Find a queue family that supports both graphics and present
        for (0..queue_family_count) |i| {
            var present_support: vk.Bool32 = undefined;
            _ = vk.getPhysicalDeviceSurfaceSupportKHR(physical_device, @as(u32, @intCast(i)), surface, &present_support);

            if (present_support == vk.TRUE and (queue_family_properties[i].queueFlags & vk.QUEUE_GRAPHICS_BIT) != 0) {
                return @as(u32, @intCast(i));
            }
        }

        return error.NoSuitableQueueFamily;
    }

    // Create a logical device with the required extensions
    fn createLogicalDevice(physical_device: vk.PhysicalDevice, queue_family_index: u32, sync2_supported: bool) vk.Device {
        const queue_priorities = [_]f32{1.0};
        const queue_create_info = vk.DeviceQueueCreateInfo{
            .sType = vk.sTy(vk.StructureType.DeviceQueueCreateInfo),
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = queue_family_index,
            .queueCount = 1,
            .pQueuePriorities = &queue_priorities,
        };

        // Enable device features
        var device_features = vk.PhysicalDeviceFeatures{};
        device_features.samplerAnisotropy = vk.TRUE;
        device_features.shaderInt64 = vk.TRUE;

        // Enable dynamic rendering features
        var dynamic_rendering_features = vk.PhysicalDeviceDynamicRenderingFeatures{
            .sType = vk.sTy(vk.StructureType.PhysicalDeviceDynamicRenderingFeatures),
            .pNext = null,
            .dynamicRendering = vk.TRUE,
        };

        // Enable buffer device address features
        var buffer_device_address_features = vk.PhysicalDeviceBufferDeviceAddressFeatures{
            .sType = vk.sTy(vk.StructureType.PhysicalDeviceBufferDeviceAddressFeatures),
            .pNext = &dynamic_rendering_features,
            .bufferDeviceAddress = vk.TRUE,
            .bufferDeviceAddressCaptureReplay = vk.TRUE,
            .bufferDeviceAddressMultiDevice = vk.FALSE,
        };

        // Enable descriptor indexing features
        var descriptor_indexing_features = vk.PhysicalDeviceDescriptorIndexingFeatures{
            .sType = vk.sTy(vk.StructureType.PhysicalDeviceDescriptorIndexingFeatures),
            .pNext = &buffer_device_address_features,
            .shaderInputAttachmentArrayDynamicIndexing = vk.TRUE,
            .shaderUniformTexelBufferArrayDynamicIndexing = vk.TRUE,
            .shaderStorageTexelBufferArrayDynamicIndexing = vk.TRUE,
            .shaderUniformBufferArrayNonUniformIndexing = vk.TRUE,
            .shaderStorageBufferArrayNonUniformIndexing = vk.TRUE,
            .shaderSampledImageArrayNonUniformIndexing = vk.TRUE,
            .shaderStorageImageArrayNonUniformIndexing = vk.TRUE,
            .shaderInputAttachmentArrayNonUniformIndexing = vk.TRUE,
            .shaderUniformTexelBufferArrayNonUniformIndexing = vk.TRUE,
            .shaderStorageTexelBufferArrayNonUniformIndexing = vk.TRUE,
            .descriptorBindingUniformBufferUpdateAfterBind = vk.TRUE,
            .descriptorBindingSampledImageUpdateAfterBind = vk.TRUE,
            .descriptorBindingStorageImageUpdateAfterBind = vk.TRUE,
            .descriptorBindingStorageBufferUpdateAfterBind = vk.TRUE,
            .descriptorBindingUniformTexelBufferUpdateAfterBind = vk.TRUE,
            .descriptorBindingStorageTexelBufferUpdateAfterBind = vk.TRUE,
            .descriptorBindingUpdateUnusedWhilePending = vk.TRUE,
            .descriptorBindingPartiallyBound = vk.TRUE,
            .descriptorBindingVariableDescriptorCount = vk.TRUE,
            .runtimeDescriptorArray = vk.TRUE,
        };

        // Enable synchronization2 if supported
        var sync2_features = vk.PhysicalDeviceSynchronization2Features{
            .sType = vk.sTy(vk.StructureType.PhysicalDeviceSynchronization2FeaturesKHR),
            .pNext = &descriptor_indexing_features,
            .synchronization2 = vk.TRUE,
        };

        const create_info = vk.DeviceCreateInfo{
            .sType = vk.sTy(vk.StructureType.DeviceCreateInfo),
            .pNext = if (sync2_supported) &sync2_features else &descriptor_indexing_features,
            .flags = 0,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_create_info,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = DeviceExtensions.len,
            .ppEnabledExtensionNames = &DeviceExtensions,
            .pEnabledFeatures = &device_features,
        };

        var device: vk.Device = undefined;
        const result = vk.createDevice(physical_device, &create_info, null, &device);
        if (result != vk.SUCCESS) {
            logger.err("Failed to create logical device: {}", .{result});
            return null;
        }
        return device;
    }

    // get a device queue
    fn getDeviceQueue(device: vk.Device, queue_family_index: u32) vk.Queue {
        var queue: vk.Queue = undefined;
        vk.getDeviceQueue(device, queue_family_index, 0, &queue);
        return queue;
    }

    // Create a swapchain
    fn createSwapchain(device: vk.Device, physical_device: vk.PhysicalDevice, surface: vk.Surface, old_swapchain: ?vk.Swapchain) !vk.Swapchain {
        // get surface capabilities
        var surface_capabilities: vk.SurfaceCapabilitiesKHR = undefined;
        _ = vk.getPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &surface_capabilities);

        // get surface formats
        var format_count: u32 = 0;
        _ = vk.getPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, null);
        const formats = try renderAllocator.alloc(vk.SurfaceFormatKHR, format_count);
        defer renderAllocator.free(formats);
        _ = vk.getPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, formats.ptr);

        // get present modes
        var present_mode_count: u32 = 0;
        _ = vk.getPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, null);
        const present_modes = try renderAllocator.alloc(vk.PresentModeKHR, present_mode_count);
        defer renderAllocator.free(present_modes);
        _ = vk.getPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, present_modes.ptr);

        // Choose surface format
        var surface_format = formats[0];
        if (format_count == 1 and formats[0].format == @intFromEnum(vk.Format.Undefined)) {
            surface_format = vk.SurfaceFormatKHR{
                .format = @intFromEnum(vk.Format.B8G8R8A8Srgb),
                .colorSpace = vk.COLOR_SPACE_SRGB_NONLINEAR_KHR,
            };
        } else {
            for (formats) |format| {
                if (format.format == @intFromEnum(vk.Format.B8G8R8A8Unorm) and format.colorSpace == vk.COLOR_SPACE_SRGB_NONLINEAR_KHR) {
                    surface_format = format;
                    break;
                }
            }
        }

        // Choose present mode
        var present_mode = vk.PRESENT_MODE_FIFO_KHR;
        for (present_modes) |mode| {
            if (mode == vk.PRESENT_MODE_MAILBOX_KHR) {
                present_mode = mode;
                break;
            }
        }

        // Choose swap extent
        var extent = surface_capabilities.currentExtent;
        if (surface_capabilities.currentExtent.width == std.math.maxInt(u32)) {
            // If the surface size is undefined, the size is set to the size of the images requested
            extent.width = 800; // Default width
            extent.height = 600; // Default height
        }

        // Choose image count
        var image_count = surface_capabilities.minImageCount + 1;
        if (surface_capabilities.maxImageCount > 0 and image_count > surface_capabilities.maxImageCount) {
            image_count = surface_capabilities.maxImageCount;
        }

        // Create swapchain
        const create_info = vk.SwapchainCreateInfoKHR{
            .sType = vk.sTy(vk.StructureType.SwapchainCreateInfoKHR),
            .pNext = null,
            .flags = 0,
            .surface = surface,
            .minImageCount = image_count,
            .imageFormat = surface_format.format,
            .imageColorSpace = surface_format.colorSpace,
            .imageExtent = extent,
            .imageArrayLayers = 1,
            .imageUsage = vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = vk.SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
            .preTransform = surface_capabilities.currentTransform,
            .compositeAlpha = vk.COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = present_mode,
            .clipped = vk.TRUE,
            .oldSwapchain = old_swapchain orelse null,
        };

        var swapchain: vk.Swapchain = undefined;
        const result = vk.createSwapchainKHR(device, &create_info, null, &swapchain);
        if (result != vk.SUCCESS) {
            logger.err("Failed to create swapchain: {}", .{result});
            return error.SwapchainCreationFailed;
        }

        return swapchain;
    }

    // get swapchain images
    fn getSwapchainImages(device: vk.Device, swapchain: vk.Swapchain) ![]vk.Image {
        var image_count: u32 = 0;
        _ = vk.getSwapchainImagesKHR(device, swapchain, &image_count, null);

        const images = try renderAllocator.alloc(vk.Image, image_count);
        _ = vk.getSwapchainImagesKHR(device, swapchain, &image_count, images.ptr);

        return images;
    }

    // Create command pool
    fn createCommandPool(device: vk.Device, queue_family_index: u32) !vk.CommandPool {
        return vk.createCommandPool(device, queue_family_index) orelse error.CommandPoolCreationFailed;
    }

    // Allocate command buffer
    fn allocCommandBuffer(device: vk.Device, command_pool: vk.CommandPool) !vk.CommandBuffer {
        const result = vk.allocateCommandBuffers(device, command_pool, vk.COMMAND_BUFFER_LEVEL_PRIMARY, 1);
        if (result == null) {
            logger.err("Failed to allocate command buffer", .{});
            return error.CommandBufferAllocationFailed;
        }

        return result.?[0];
    }
};
