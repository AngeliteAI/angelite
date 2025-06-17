const std = @import("std");
const raw = @import("raw.zig");
const errors = @import("errors.zig");

/// Wrapper around Vulkan instance with additional utility functions
pub const Instance = struct {
    handle: raw.Instance,
    debug_messenger: ?DebugMessenger,
    allocator: std.mem.Allocator,

    /// Configuration options for creating a Vulkan instance
    pub const CreateInfo = struct {
        application_name: []const u8,
        application_version: u32 = 1,
        engine_name: []const u8 = "Zig Vulkan",
        engine_version: u32 = 1,
        api_version: u32 = raw.API_VERSION_1_3,
        enable_validation: bool = true,
        required_extensions: []const []const u8 = &[_][]const u8{},
        required_layers: []const []const u8 = &[_][]const u8{},
    };

    /// Create a new Vulkan instance with the given configuration
    pub fn create(allocator: std.mem.Allocator, create_info: CreateInfo) errors.Error!Instance {
        // Prepare application info
        const app_info = raw.ApplicationInfo{
            .sType = raw.sTy(.AppInfo),
            .pNext = null,
            .pApplicationName = create_info.application_name.ptr,
            .applicationVersion = raw.MAKE_VERSION(create_info.application_version, 0, 0),
            .pEngineName = create_info.engine_name.ptr,
            .engineVersion = raw.MAKE_VERSION(create_info.engine_version, 0, 0),
            .apiVersion = create_info.api_version,
        };

        // Combined required and optional extensions
        var extensions = std.ArrayList([*:0]const u8).init(allocator);
        defer extensions.deinit();

        // Add platform-specific surface extension
        try extensions.append(raw.GENERIC_SURFACE_EXTENSION_NAME);
        try extensions.append(raw.PLATFORM_SURFACE_EXTENSION_NAME);

        // Add validation layers if requested
        var layers = std.ArrayList([*:0]const u8).init(allocator);
        defer layers.deinit();

        // Add custom extensions
        for (create_info.required_extensions) |ext| {
            try extensions.append(@ptrCast(ext.ptr));
        }

        // Add validation layers if enabled
        if (create_info.enable_validation) {
            // Add validation layer
            try layers.append("VK_LAYER_KHRONOS_validation");

            // Add debug utils extension
            try extensions.append("VK_EXT_debug_utils");
        }

        // Add custom layers
        for (create_info.required_layers) |layer| {
            try layers.append(@ptrCast(layer.ptr));
        }

        // Create instance create info
        const instance_info = raw.InstanceCreateInfo{
            .sType = raw.sTy(.InstanceInfo),
            .pNext = null,
            .flags = 0,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = @intCast(layers.items.len),
            .ppEnabledLayerNames = if (layers.items.len > 0) layers.items.ptr else null,
            .enabledExtensionCount = @intCast(extensions.items.len),
            .ppEnabledExtensionNames = if (extensions.items.len > 0) extensions.items.ptr else null,
        };

        // Create the instance
        var handle: raw.Instance = undefined;
        const result = raw.createInstance(&instance_info, null, &handle);
        try errors.checkResult(result);

        // Create debug messenger if validation is enabled
        var debug_messenger: ?DebugMessenger = null;
        if (create_info.enable_validation) {
            // Debug messenger would be created here if implemented
        }

        return Instance{
            .handle = handle,
            .debug_messenger = debug_messenger,
            .allocator = allocator,
        };
    }

    /// Destroy the Vulkan instance and cleanup resources
    pub fn destroy(self: *Instance) void {
        if (self.debug_messenger) |*messenger| {
            messenger.destroy();
        }
        raw.destroyInstance(self.handle, null);
        self.* = undefined;
    }

    /// Get a list of physical devices available on this instance
    pub fn enumeratePhysicalDevices(self: Instance) errors.Error![]raw.PhysicalDevice {
        var device_count: u32 = 0;
        var result = raw.enumeratePhysicalDevices(self.handle, &device_count, null);
        try errors.checkResult(result);

        if (device_count == 0) {
            return errors.Error.NoSuitableDevice;
        }

        const devices = try self.allocator.alloc(raw.PhysicalDevice, device_count);
        result = raw.enumeratePhysicalDevices(self.handle, &device_count, devices.ptr);

        if (result != raw.SUCCESS) {
            self.allocator.free(devices);
            return errors.Error.NoSuitableDevice;
        }

        return devices;
    }

    /// Create a Vulkan surface for presentation
    pub fn createSurface(self: Instance, platform_info: raw.PlatformSpecificInfo) errors.Error!raw.Surface {
        const surface = raw.createSurface(self.handle, platform_info) orelse {
            return errors.Error.ResourceCreationFailed;
        };
        return surface;
    }

    /// Get the raw instance handle
    pub fn getHandle(self: Instance) raw.Instance {
        return self.handle;
    }
};

/// Debug messenger for Vulkan validation layers
const DebugMessenger = struct {
    handle: anyopaque, // Placeholder for now
    instance: raw.Instance,

    pub fn destroy(self: *DebugMessenger) void {
        // Would destroy the debug messenger if implemented
        _ = self;
    }
};
