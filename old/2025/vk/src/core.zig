const std = @import("std");
const raw = @import("raw.zig");
const errors = @import("errors.zig");
const instance_mod = @import("instance.zig");
const device_mod = @import("device.zig");
const swapchain_mod = @import("swapchain.zig");
const commands_mod = @import("commands.zig");
const sync_mod = @import("sync.zig");

/// Context that holds all Vulkan resources needed for an application
pub const Context = struct {
    // Main Vulkan objects
    instance: instance_mod.Instance,
    surface: raw.Surface,
    physical_device: device_mod.PhysicalDevice,
    device: device_mod.Device,
    swapchain: ?swapchain_mod.Swapchain,

    // Command pools
    graphics_command_pool: commands_mod.CommandPool,

    // Sync objects
    sync_objects: ?sync_mod.SyncObjectsPool,
    current_frame: usize,

    // Application state
    width: u32,
    height: u32,
    vsync: bool,
    max_frames_in_flight: u32,
    allocator: std.mem.Allocator,

    /// Configuration options for creating a Vulkan context
    pub const CreateInfo = struct {
        app_name: []const u8,
        width: u32,
        height: u32,
        enable_validation: bool = true,
        vsync: bool = true,
        max_frames_in_flight: u32 = 2,
        required_device_extensions: []const [*:0]const u8 = &[_][*:0]const u8{},
        platform_specific_info: raw.PlatformSpecificInfo,
    };

    /// Create a new Vulkan context with the given configuration
    pub fn create(allocator: std.mem.Allocator, create_info: CreateInfo) errors.Error!Context {
        // Create instance
        const instance_create_info = instance_mod.Instance.CreateInfo{
            .application_name = create_info.app_name,
            .application_version = 1,
            .enable_validation = create_info.enable_validation,
        };

        var instance = try instance_mod.Instance.create(allocator, instance_create_info);
        errdefer instance.destroy();

        // Create surface
        const surface = try instance.createSurface(create_info.platform_specific_info);
        errdefer raw.destroySurfaceKHR(instance.handle, surface, null);

        // Find physical device
        var physical_devices = try instance.enumeratePhysicalDevices();
        defer allocator.free(physical_devices);

        var physical_device: ?device_mod.PhysicalDevice = null;
        var best_score: u32 = 0;

        for (physical_devices) |pd| {
            var phys_dev = try device_mod.PhysicalDevice.init(allocator, pd);
            errdefer phys_dev.deinit();

            // Check presentation support
            try phys_dev.checkPresentationSupport(surface);

            // Check if device is suitable
            if (try phys_dev.isSuitable(surface)) {
                // Score the device - prefer discrete GPUs
                var score: u32 = 0;

                if (phys_dev.properties.deviceType == raw.PHYSICAL_DEVICE_TYPE_DISCRETE_GPU) {
                    score += 1000;
                } else if (phys_dev.properties.deviceType == raw.PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU) {
                    score += 500;
                }

                if (score > best_score) {
                    if (physical_device != null) {
                        physical_device.?.deinit();
                    }
                    physical_device = phys_dev;
                    best_score = score;
                } else {
                    phys_dev.deinit();
                }
            } else {
                phys_dev.deinit();
            }
        }

        if (physical_device == null) {
            raw.destroySurfaceKHR(instance.handle, surface, null);
            instance.destroy();
            return errors.Error.NoSuitableDevice;
        }

        // Create logical device
        const device_create_info = device_mod.Device.CreateInfo{
            .physical_device = physical_device.?,
            .surface = surface,
            .required_extensions = create_info.required_device_extensions,
        };

        var device = try device_mod.Device.create(allocator, device_create_info);
        errdefer device.destroy();

        // Create command pools
        var graphics_command_pool = try commands_mod.CommandPool.create(device.handle, device.graphics_queue_family);
        errdefer graphics_command_pool.destroy();

        return Context{
            .instance = instance,
            .surface = surface,
            .physical_device = physical_device.?,
            .device = device,
            .swapchain = null,
            .graphics_command_pool = graphics_command_pool,
            .sync_objects = null,
            .current_frame = 0,
            .width = create_info.width,
            .height = create_info.height,
            .vsync = create_info.vsync,
            .max_frames_in_flight = create_info.max_frames_in_flight,
            .allocator = allocator,
        };
    }

    /// Create or recreate the swapchain
    pub fn createSwapchain(self: *Context) errors.Error!void {
        // Wait for device to be idle before recreating swapchain
        try self.device.waitIdle();

        // Destroy old swapchain if it exists
        if (self.swapchain != null) {
            self.swapchain.?.destroy();
        }

        // Create swapchain
        const swapchain_create_info = swapchain_mod.Swapchain.CreateInfo{
            .surface = self.surface,
            .device = self.device,
            .extent = .{ .width = self.width, .height = self.height },
            .present_mode = if (self.vsync) raw.PRESENT_MODE_FIFO_KHR else raw.PRESENT_MODE_IMMEDIATE_KHR,
            .min_image_count = self.max_frames_in_flight,
        };

        self.swapchain = try swapchain_mod.Swapchain.create(self.allocator, swapchain_create_info);

        // Create synchronization objects if not already created
        if (self.sync_objects == null) {
            self.sync_objects = try sync_mod.SyncObjectsPool.create(self.allocator, self.device.handle, self.max_frames_in_flight);
        }
    }

    /// Acquire the next image from the swapchain
    pub fn acquireNextImage(self: *Context) errors.Error!struct { image_index: u32, result: raw.Result } {
        if (self.swapchain == null) {
            return errors.Error.InitializationFailed;
        }

        // Get sync objects for the current frame
        const sync = self.sync_objects.?.getSyncObjectsForFrame(self.current_frame);

        // Wait for the previous frame to complete
        try sync.in_flight.wait(std.math.maxInt(u64));
        try sync.in_flight.reset();

        // Acquire the next image
        var image_index: u32 = 0;
        const result = raw.acquireNextImageKHR(self.device.handle, self.swapchain.?.handle, std.math.maxInt(u64), sync.image_available.handle, raw.NULL, &image_index);

        // Check if swapchain is still valid
        if (result == raw.OUT_OF_DATE) {
            try self.createSwapchain();
            return .{ .image_index = 0, .result = result };
        } else if (result != raw.SUCCESS and result != raw.SUBOPTIMAL_KHR) {
            try errors.checkResult(result);
        }

        return .{ .image_index = image_index, .result = result };
    }

    /// Present the rendered image to the screen
    pub fn presentImage(self: *Context, image_index: u32) errors.Error!bool {
        if (self.swapchain == null) {
            return errors.Error.InitializationFailed;
        }

        // Get sync objects for the current frame
        const sync = self.sync_objects.?.getSyncObjectsForFrame(self.current_frame);

        // Set up present info
        const present_info = raw.PresentInfoKHR{
            .sType = raw.sTy(.PresentInfoKHR),
            .pNext = null,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &sync.render_finished.handle,
            .swapchainCount = 1,
            .pSwapchains = &self.swapchain.?.handle,
            .pImageIndices = &image_index,
            .pResults = null,
        };

        // Present the image
        const result = raw.queuePresentKHR(self.device.getPresentQueue(), &present_info);

        // Check if swapchain needs to be recreated
        if (result == raw.OUT_OF_DATE or result == raw.SUBOPTIMAL_KHR) {
            try self.createSwapchain();
            return true;
        } else {
            try errors.checkResult(result);
        }

        // Advance to the next frame
        self.current_frame = (self.current_frame + 1) % self.max_frames_in_flight;

        return false;
    }

    /// Resize the swapchain
    pub fn resize(self: *Context, width: u32, height: u32) errors.Error!void {
        self.width = width;
        self.height = height;
        try self.createSwapchain();
    }

    /// Destroy the Vulkan context and free resources
    pub fn destroy(self: *Context) void {
        _ = self.device.waitIdle() catch {};

        if (self.sync_objects) |*sync_objects| {
            sync_objects.destroy();
        }

        if (self.swapchain) |*swapchain| {
            swapchain.destroy();
        }

        self.graphics_command_pool.destroy();
        self.device.destroy();
        raw.destroySurfaceKHR(self.instance.handle, self.surface, null);
        self.physical_device.deinit();
        self.instance.destroy();
    }

    /// Get the width of the swapchain
    pub fn getWidth(self: Context) u32 {
        return self.width;
    }

    /// Get the height of the swapchain
    pub fn getHeight(self: Context) u32 {
        return self.height;
    }

    /// Get the current frame index
    pub fn getCurrentFrame(self: Context) usize {
        return self.current_frame;
    }

    /// Get the max frames in flight
    pub fn getMaxFramesInFlight(self: Context) u32 {
        return self.max_frames_in_flight;
    }

    /// Get the graphics command pool
    pub fn getGraphicsCommandPool(self: Context) commands_mod.CommandPool {
        return self.graphics_command_pool;
    }

    /// Get the sync objects for the current frame
    pub fn getCurrentSyncObjects(self: Context) struct {
        image_available: *sync_mod.Semaphore,
        render_finished: *sync_mod.Semaphore,
        in_flight: *sync_mod.Fence,
    } {
        return self.sync_objects.?.getSyncObjectsForFrame(self.current_frame);
    }
};

/// Check if Vulkan validation layers are available
pub fn checkValidationLayerSupport(layer_name: [*:0]const u8) bool {
    var layer_count: u32 = 0;
    _ = raw.enumerateInstanceLayerProperties(&layer_count, null);

    if (layer_count == 0) {
        return false;
    }

    var available_layers = std.heap.page_allocator.alloc(raw.LayerProperties, layer_count) catch {
        return false;
    };
    defer std.heap.page_allocator.free(available_layers);

    _ = raw.enumerateInstanceLayerProperties(&layer_count, available_layers.ptr);

    // Check if the requested layer is available
    for (available_layers) |layer| {
        var i: usize = 0;
        while (layer.layerName[i] != 0 and layer_name[i] != 0) : (i += 1) {
            if (layer.layerName[i] != layer_name[i]) {
                break;
            }
        }

        if (layer.layerName[i] == 0 and layer_name[i] == 0) {
            return true;
        }
    }

    return false;
}

/// Get the required extensions for a platform
pub fn getRequiredExtensions(validation_enabled: bool) ![]const [*:0]const u8 {
    const platform_exts = [_][*:0]const u8{
        raw.GENERIC_SURFACE_EXTENSION_NAME,
        raw.PLATFORM_SURFACE_EXTENSION_NAME,
    };

    var extensions = std.ArrayList([*:0]const u8).init(std.heap.page_allocator);
    defer extensions.deinit();

    try extensions.appendSlice(&platform_exts);

    if (validation_enabled) {
        try extensions.append("VK_EXT_debug_utils");
    }

    return extensions.toOwnedSlice();
}
