const std = @import("std");
const raw = @import("raw.zig");
const errors = @import("errors.zig");

/// Queue family information
pub const QueueFamily = struct {
    index: u32,
    queue_count: u32,
    supports_graphics: bool,
    supports_compute: bool,
    supports_transfer: bool,
    supports_presentation: bool,
};

/// Physical device wrapper with additional utility functions
pub const PhysicalDevice = struct {
    handle: raw.PhysicalDevice,
    properties: raw.PhysicalDeviceProperties,
    memory_properties: raw.PhysicalDeviceMemoryProperties,
    queue_families: []QueueFamily,
    allocator: std.mem.Allocator,

    /// Create a new physical device wrapper
    pub fn init(allocator: std.mem.Allocator, handle: raw.PhysicalDevice) errors.Error!PhysicalDevice {
        var properties: raw.PhysicalDeviceProperties = undefined;
        raw.getPhysicalDeviceProperties(handle, &properties);

        var memory_properties: raw.PhysicalDeviceMemoryProperties = undefined;
        raw.getPhysicalDeviceMemoryProperties(handle, &memory_properties);

        // Get queue family properties
        var queue_family_count: u32 = 0;
        raw.getPhysicalDeviceQueueFamilyProperties(handle, &queue_family_count, null);

        const raw_queue_families = try allocator.alloc(raw.QueueFamilyProperties, queue_family_count);
        defer allocator.free(raw_queue_families);

        raw.getPhysicalDeviceQueueFamilyProperties(handle, &queue_family_count, raw_queue_families.ptr);

        // Create queue family information
        const queue_families = try allocator.alloc(QueueFamily, queue_family_count);
        errdefer allocator.free(queue_families);

        for (raw_queue_families, 0..) |family, i| {
            queue_families[i] = QueueFamily{
                .index = @intCast(i),
                .queue_count = family.queueCount,
                .supports_graphics = (family.queueFlags & raw.QUEUE_GRAPHICS_BIT) != 0,
                .supports_compute = (family.queueFlags & raw.QUEUE_COMPUTE_BIT) != 0,
                .supports_transfer = (family.queueFlags & raw.QUEUE_TRANSFER_BIT) != 0,
                .supports_presentation = false, // Will be set later when checking surface support
            };
        }

        return PhysicalDevice{
            .handle = handle,
            .properties = properties,
            .memory_properties = memory_properties,
            .queue_families = queue_families,
            .allocator = allocator,
        };
    }

    /// Deinitialize the physical device and free resources
    pub fn deinit(self: *PhysicalDevice) void {
        self.allocator.free(self.queue_families);
        self.* = undefined;
    }

    /// Check if the physical device supports presentation to the given surface
    pub fn checkPresentationSupport(self: *PhysicalDevice, surface: raw.Surface) errors.Error!void {
        for (self.queue_families) |*family| {
            var supported: raw.Bool32 = raw.FALSE;
            const result = raw.getPhysicalDeviceSurfaceSupportKHR(self.handle, family.index, surface, &supported);
            try errors.checkResult(result);

            if (supported == raw.TRUE) {
                family.supports_presentation = true;
            }
        }
    }

    /// Find a queue family that supports the specified capabilities
    pub fn findQueueFamily(self: PhysicalDevice, graphics: bool, compute: bool, transfer: bool, presentation: bool) ?u32 {
        // First, try to find a queue family that supports all requested features
        for (self.queue_families) |family| {
            const g = !graphics or family.supports_graphics;
            const c = !compute or family.supports_compute;
            const t = !transfer or family.supports_transfer;
            const p = !presentation or family.supports_presentation;

            if (g and c and t and p) {
                return family.index;
            }
        }

        // If not found, prioritize the most important capability
        if (graphics) {
            for (self.queue_families) |family| {
                if (family.supports_graphics) {
                    return family.index;
                }
            }
        } else if (compute) {
            for (self.queue_families) |family| {
                if (family.supports_compute) {
                    return family.index;
                }
            }
        } else if (presentation) {
            for (self.queue_families) |family| {
                if (family.supports_presentation) {
                    return family.index;
                }
            }
        } else if (transfer) {
            for (self.queue_families) |family| {
                if (family.supports_transfer) {
                    return family.index;
                }
            }
        }

        return null;
    }

    /// Check if a device extension is supported
    pub fn supportsExtension(self: PhysicalDevice, extension_name: [*:0]const u8) errors.Error!bool {
        var extension_count: u32 = 0;
        var result = raw.enumerateDeviceExtensionProperties(self.handle, null, &extension_count, null);
        try errors.checkResult(result);

        const extensions = try self.allocator.alloc(raw.ExtensionProperties, extension_count);
        defer self.allocator.free(extensions);

        result = raw.enumerateDeviceExtensionProperties(self.handle, null, &extension_count, extensions.ptr);
        try errors.checkResult(result);

        for (extensions) |extension| {
            // Compare extension names
            var i: usize = 0;
            while (extension.extensionName[i] != 0 and extension_name[i] != 0) : (i += 1) {
                if (extension.extensionName[i] != extension_name[i]) {
                    break;
                }
            }

            if (extension.extensionName[i] == 0 and extension_name[i] == 0) {
                return true;
            }
        }

        return false;
    }

    /// Find a suitable memory type for the given requirements and properties
    pub fn findMemoryType(self: PhysicalDevice, type_filter: u32, properties: raw.MemoryPropertyFlags) errors.Error!u32 {
        const mem_properties = self.memory_properties;

        for (0..mem_properties.memoryTypeCount) |i| {
            const type_matches = (type_filter & (@as(u32, 1) << @truncate(i))) != 0;
            const property_matches = (mem_properties.memoryTypes[i].propertyFlags & properties) == properties;

            if (type_matches and property_matches) {
                return @truncate(i);
            }
        }

        return errors.Error.NoSuitableMemoryType;
    }

    /// Get the raw handle to the physical device
    pub fn getHandle(self: PhysicalDevice) raw.PhysicalDevice {
        return self.handle;
    }

    /// Check if this device is suitable for our application
    pub fn isSuitable(self: PhysicalDevice, surface: raw.Surface) errors.Error!bool {
        // Check if the device has a queue family that supports graphics
        var has_graphics_queue = false;
        var has_presentation_queue = false;

        for (self.queue_families) |family| {
            if (family.supports_graphics) {
                has_graphics_queue = true;
            }
            if (family.supports_presentation) {
                has_presentation_queue = true;
            }
        }

        if (!has_graphics_queue or !has_presentation_queue) {
            return false;
        }

        // Check for swapchain extension support
        const swapchain_support = try self.supportsExtension(raw.KHR_SWAPCHAIN_EXTENSION_NAME);
        if (!swapchain_support) {
            return false;
        }

        // Check for synchronization2 extension support
        const sync2_support = try self.supportsExtension(raw.KHR_SYNCHRONIZATION_2_EXTENSION_NAME);
        if (!sync2_support) {
            return false;
        }

        // Check for dynamic rendering extension support
        const dynamic_rendering_support = try self.supportsExtension(raw.KHR_DYNAMIC_RENDERING_EXTENSION_NAME);
        if (!dynamic_rendering_support) {
            return false;
        }

        // Check swapchain details
        var format_count: u32 = 0;
        var result = raw.getPhysicalDeviceSurfaceFormatsKHR(self.handle, surface, &format_count, null);
        try errors.checkResult(result);

        if (format_count == 0) {
            return false;
        }

        var present_mode_count: u32 = 0;
        result = raw.getPhysicalDeviceSurfacePresentModesKHR(self.handle, surface, &present_mode_count, null);
        try errors.checkResult(result);

        if (present_mode_count == 0) {
            return false;
        }

        return true;
    }
};

/// Logical device wrapper with additional utility functions
pub const Device = struct {
    handle: raw.Device,
    physical_device: PhysicalDevice,
    graphics_queue: raw.Queue,
    present_queue: raw.Queue,
    graphics_queue_family: u32,
    present_queue_family: u32,
    allocator: std.mem.Allocator,

    /// Configuration options for creating a logical device
    pub const CreateInfo = struct {
        physical_device: PhysicalDevice,
        surface: raw.Surface,
        required_extensions: []const [*:0]const u8 = &[_][*:0]const u8{},
    };

    /// Create a new logical device with the given configuration
    pub fn create(allocator: std.mem.Allocator, create_info: CreateInfo) errors.Error!Device {
        const physical_device = create_info.physical_device;

        // Find appropriate queue families
        const graphics_family = physical_device.findQueueFamily(true, false, false, false) orelse
            return errors.Error.NoSuitableQueue;
        const present_family = physical_device.findQueueFamily(false, false, false, true) orelse
            return errors.Error.NoSuitableQueue;

        // Set up queue create infos
        var queue_create_infos = std.ArrayList(raw.DeviceQueueCreateInfo).init(allocator);
        defer queue_create_infos.deinit();

        const queue_priorities = [_]f32{1.0};

        // Add graphics queue create info
        try queue_create_infos.append(raw.DeviceQueueCreateInfo{
            .sType = raw.sTy(.DeviceQueueCreateInfo),
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = graphics_family,
            .queueCount = 1,
            .pQueuePriorities = &queue_priorities,
        });

        // Add present queue create info if different from graphics queue
        if (graphics_family != present_family) {
            try queue_create_infos.append(raw.DeviceQueueCreateInfo{
                .sType = raw.sTy(.DeviceQueueCreateInfo),
                .pNext = null,
                .flags = 0,
                .queueFamilyIndex = present_family,
                .queueCount = 1,
                .pQueuePriorities = &queue_priorities,
            });
        }

        // Set up required device extensions
        var extensions = std.ArrayList([*:0]const u8).init(allocator);
        defer extensions.deinit();

        // Add swapchain extension
        try extensions.append(raw.KHR_SWAPCHAIN_EXTENSION_NAME);

        // Add synchronization2 extension
        try extensions.append(raw.KHR_SYNCHRONIZATION_2_EXTENSION_NAME);

        // Add dynamic rendering extension
        try extensions.append(raw.KHR_DYNAMIC_RENDERING_EXTENSION_NAME);

        // Add custom extensions
        for (create_info.required_extensions) |ext| {
            try extensions.append(ext);
        }

        // Set up features
        var features = std.mem.zeroes(raw.PhysicalDeviceFeatures);

        // Set up dynamic rendering features
        var dynamic_rendering_features = std.mem.zeroes(raw.PhysicalDeviceDynamicRenderingFeatures);
        dynamic_rendering_features.sType = raw.sTy(.PhysicalDeviceDynamicRenderingFeatures);
        dynamic_rendering_features.dynamicRendering = raw.TRUE;

        // Set up synchronization2 features
        var sync2_features = std.mem.zeroes(raw.PhysicalDeviceSynchronization2Features);
        sync2_features.sType = raw.sTy(.PhysicalDeviceSynchronization2FeaturesKHR);
        sync2_features.pNext = &dynamic_rendering_features;
        sync2_features.synchronization2 = raw.TRUE;

        // Create device
        const device_create_info = raw.DeviceCreateInfo{
            .sType = raw.sTy(.DeviceCreateInfo),
            .pNext = &sync2_features,
            .flags = 0,
            .queueCreateInfoCount = @intCast(queue_create_infos.items.len),
            .pQueueCreateInfos = queue_create_infos.items.ptr,
            .enabledLayerCount = 0,
            .ppEnabledLayerNames = null,
            .enabledExtensionCount = @intCast(extensions.items.len),
            .ppEnabledExtensionNames = extensions.items.ptr,
            .pEnabledFeatures = &features,
        };

        var handle: raw.Device = undefined;
        const result = raw.createDevice(physical_device.handle, &device_create_info, null, &handle);
        try errors.checkResult(result);

        // Get queue handles
        var graphics_queue: raw.Queue = undefined;
        var present_queue: raw.Queue = undefined;

        raw.getDeviceQueue(handle, graphics_family, 0, &graphics_queue);
        raw.getDeviceQueue(handle, present_family, 0, &present_queue);

        // Load device extension functions
        raw.loadDeviceExtensionFunctions(handle);

        return Device{
            .handle = handle,
            .physical_device = physical_device,
            .graphics_queue = graphics_queue,
            .present_queue = present_queue,
            .graphics_queue_family = graphics_family,
            .present_queue_family = present_family,
            .allocator = allocator,
        };
    }

    /// Destroy the logical device
    pub fn destroy(self: *Device) void {
        raw.destroyDevice(self.handle, null);
        self.* = undefined;
    }

    /// Wait for the device to finish all pending operations
    pub fn waitIdle(self: Device) errors.Error!void {
        const result = raw.deviceWaitIdle(self.handle);
        try errors.checkResult(result);
    }

    /// Get the raw device handle
    pub fn getHandle(self: Device) raw.Device {
        return self.handle;
    }

    /// Get the graphics queue
    pub fn getGraphicsQueue(self: Device) raw.Queue {
        return self.graphics_queue;
    }

    /// Get the presentation queue
    pub fn getPresentQueue(self: Device) raw.Queue {
        return self.present_queue;
    }

    /// Get the graphics queue family index
    pub fn getGraphicsQueueFamily(self: Device) u32 {
        return self.graphics_queue_family;
    }
};
