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
}
