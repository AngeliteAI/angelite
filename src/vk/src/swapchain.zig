const std = @import("std");
const raw = @import("raw.zig");
const errors = @import("errors.zig");
const device_mod = @import("device.zig");

/// Surface format information
pub const SurfaceFormat = struct {
    format: raw.Format,
    color_space: u32,
};

/// Surface capabilities information
pub const SurfaceCapabilities = struct {
    min_image_count: u32,
    max_image_count: u32,
    current_extent: raw.Extent2D,
    min_image_extent: raw.Extent2D,
    max_image_extent: raw.Extent2D,
    max_image_array_layers: u32,
    supported_transforms: u32,
    current_transform: u32,
    supported_composite_alpha: u32,
    supported_usage_flags: u32,
};

/// Swapchain support details
pub const SwapchainSupportDetails = struct {
    capabilities: SurfaceCapabilities,
    formats: []SurfaceFormat,
    present_modes: []raw.PresentMode,
    allocator: std.mem.Allocator,

    /// Free resources used by swapchain support details
    pub fn deinit(self: *SwapchainSupportDetails) void {
        self.allocator.free(self.formats);
        self.allocator.free(self.present_modes);
        self.* = undefined;
    }
};

/// Swapchain abstraction with utility functions
pub const Swapchain = struct {
    handle: raw.Swapchain,
    device: raw.Device,
    images: []raw.Image,
    image_views: []raw.ImageView,
    format: raw.Format,
    extent: raw.Extent2D,
    allocator: std.mem.Allocator,

    /// Configuration options for creating a swapchain
    pub const CreateInfo = struct {
        surface: raw.Surface,
        device: device_mod.Device,
        min_image_count: u32 = 2,
        format: ?SurfaceFormat = null, // If null, will pick the first available format
        present_mode: ?raw.PresentMode = null, // If null, will use FIFO mode
        extent: ?raw.Extent2D = null, // If null, will use surface extent
        old_swapchain: ?raw.Swapchain = null,
    };

    /// Query swapchain support details for a physical device and surface
    pub fn querySwapchainSupport(physical_device: raw.PhysicalDevice, surface: raw.Surface, allocator: std.mem.Allocator) errors.Error!SwapchainSupportDetails {
        // Query surface capabilities
        var capabilities: raw.SurfaceCapabilitiesKHR = undefined;
        var result = raw.getPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &capabilities);
        try errors.checkResult(result);

        // Query surface formats
        var format_count: u32 = 0;
        result = raw.getPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, null);
        try errors.checkResult(result);

        if (format_count == 0) {
            return errors.Error.NoSuitableFormat;
        }

        const raw_formats = try allocator.alloc(raw.SurfaceFormatKHR, format_count);
        defer allocator.free(raw_formats);

        result = raw.getPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, raw_formats.ptr);
        try errors.checkResult(result);

        // Copy formats to our struct
        const formats = try allocator.alloc(SurfaceFormat, format_count);
        errdefer allocator.free(formats);

        for (raw_formats, 0..) |fmt, i| {
            formats[i] = SurfaceFormat{
                .format = @enumFromInt(fmt.format),
                .color_space = fmt.colorSpace,
            };
        }

        // Query present modes
        var present_mode_count: u32 = 0;
        result = raw.getPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, null);
        try errors.checkResult(result);

        if (present_mode_count == 0) {
            allocator.free(formats);
            return errors.Error.NoSuitablePresentMode;
        }

        const present_modes = try allocator.alloc(raw.PresentMode, present_mode_count);
        errdefer allocator.free(present_modes);

        result = raw.getPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, present_modes.ptr);
        try errors.checkResult(result);

        // Convert capabilities to our struct
        const surf_capabilities = SurfaceCapabilities{
            .min_image_count = capabilities.minImageCount,
            .max_image_count = capabilities.maxImageCount,
            .current_extent = capabilities.currentExtent,
            .min_image_extent = capabilities.minImageExtent,
            .max_image_extent = capabilities.maxImageExtent,
            .max_image_array_layers = capabilities.maxImageArrayLayers,
            .supported_transforms = capabilities.supportedTransforms,
            .current_transform = capabilities.currentTransform,
            .supported_composite_alpha = capabilities.supportedCompositeAlpha,
            .supported_usage_flags = capabilities.supportedUsageFlags,
        };

        return SwapchainSupportDetails{
            .capabilities = surf_capabilities,
            .formats = formats,
            .present_modes = present_modes,
            .allocator = allocator,
        };
    }

    /// Choose the best surface format from available formats
    fn chooseSwapSurfaceFormat(available_formats: []SurfaceFormat) SurfaceFormat {
        // Prefer SRGB for color space
        for (available_formats) |format| {
            if (format.format == .B8G8R8A8Srgb and
                format.color_space == raw.COLOR_SPACE_SRGB_NONLINEAR_KHR)
            {
                return format;
            }
        }

        // If not found, just use the first format
        return available_formats[0];
    }

    /// Choose the best present mode from available modes
    fn chooseSwapPresentMode(available_present_modes: []raw.PresentMode, preferred: ?raw.PresentMode) raw.PresentMode {
        if (preferred) |mode| {
            // Check if preferred mode is available
            for (available_present_modes) |available_mode| {
                if (available_mode == mode) {
                    return mode;
                }
            }
        }

        // Check for mailbox mode (triple buffering)
        for (available_present_modes) |mode| {
            if (mode == raw.PRESENT_MODE_MAILBOX_KHR) {
                return mode;
            }
        }

        // FIFO is guaranteed to be available
        return raw.PRESENT_MODE_FIFO_KHR;
    }

    /// Choose the swap extent (resolution) for the swapchain
    fn chooseSwapExtent(capabilities: SurfaceCapabilities, preferred_extent: ?raw.Extent2D) raw.Extent2D {
        if (preferred_extent) |extent| {
            return extent;
        }

        if (capabilities.current_extent.width != std.math.maxInt(u32)) {
            return capabilities.current_extent;
        }

        // Use a reasonable default size
        var actual_extent = raw.Extent2D{
            .width = 800,
            .height = 600,
        };

        actual_extent.width = std.math.clamp(actual_extent.width, capabilities.min_image_extent.width, capabilities.max_image_extent.width);

        actual_extent.height = std.math.clamp(actual_extent.height, capabilities.min_image_extent.height, capabilities.max_image_extent.height);

        return actual_extent;
    }

    /// Create a new swapchain
    pub fn create(allocator: std.mem.Allocator, create_info: CreateInfo) errors.Error!Swapchain {
        const device_handle = create_info.device.getHandle();
        const physical_device = create_info.device.physical_device;

        // Query swapchain support details
        var support_details = try querySwapchainSupport(physical_device.getHandle(), create_info.surface, allocator);
        defer support_details.deinit();

        // Choose surface format
        const surface_format = if (create_info.format) |fmt|
            fmt
        else
            chooseSwapSurfaceFormat(support_details.formats);

        // Choose present mode
        const present_mode = chooseSwapPresentMode(support_details.present_modes, create_info.present_mode);

        // Choose swap extent
        const extent = chooseSwapExtent(support_details.capabilities, create_info.extent);

        // Choose image count
        var image_count = create_info.min_image_count;
        if (support_details.capabilities.max_image_count > 0 and
            image_count > support_details.capabilities.max_image_count)
        {
            image_count = support_details.capabilities.max_image_count;
        }

        if (image_count < support_details.capabilities.min_image_count) {
            image_count = support_details.capabilities.min_image_count;
        }

        // Create swapchain info
        const swapchain_info = raw.SwapchainCreateInfoKHR{
            .sType = raw.sTy(.SwapchainCreateInfoKHR),
            .pNext = null,
            .flags = 0,
            .surface = create_info.surface,
            .minImageCount = image_count,
            .imageFormat = @intFromEnum(surface_format.format),
            .imageColorSpace = surface_format.color_space,
            .imageExtent = extent,
            .imageArrayLayers = 1,
            .imageUsage = raw.IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = raw.SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
            .preTransform = support_details.capabilities.current_transform,
            .compositeAlpha = raw.COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = present_mode,
            .clipped = raw.TRUE,
            .oldSwapchain = create_info.old_swapchain orelse raw.NULL,
        };

        // Create the swapchain
        var swapchain: raw.Swapchain = undefined;
        const result = raw.createSwapchainKHR(device_handle, &swapchain_info, null, &swapchain);
        try errors.checkResult(result);

        // Get swapchain images
        var image_count_final: u32 = 0;
        _ = raw.getSwapchainImagesKHR(device_handle, swapchain, &image_count_final, null);

        const images = try allocator.alloc(raw.Image, image_count_final);
        errdefer allocator.free(images);

        _ = raw.getSwapchainImagesKHR(device_handle, swapchain, &image_count_final, images.ptr);

        // Create image views
        const image_views = try allocator.alloc(raw.ImageView, image_count_final);
        errdefer allocator.free(image_views);

        for (images, 0..) |image, i| {
            // Create image view info
            const view_info = raw.ImageViewCreateInfo{
                .sType = raw.sTy(.ImageViewCreateInfo),
                .pNext = null,
                .flags = 0,
                .image = image,
                .viewType = raw.IMAGE_VIEW_TYPE_2D,
                .format = @intFromEnum(surface_format.format),
                .components = raw.ComponentMapping{
                    .r = raw.COMPONENT_SWIZZLE_IDENTITY,
                    .g = raw.COMPONENT_SWIZZLE_IDENTITY,
                    .b = raw.COMPONENT_SWIZZLE_IDENTITY,
                    .a = raw.COMPONENT_SWIZZLE_IDENTITY,
                },
                .subresourceRange = raw.ImageSubresourceRange{
                    .aspectMask = raw.IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
            };

            const img_result = raw.createImageView(device_handle, &view_info, null, &image_views[i]);

            if (img_result != raw.SUCCESS) {
                // Clean up any already created image views
                for (0..i) |j| {
                    raw.destroyImageView(device_handle, image_views[j], null);
                }

                raw.destroySwapchainKHR(device_handle, swapchain, null);
                allocator.free(images);
                allocator.free(image_views);

                return errors.Error.ResourceCreationFailed;
            }
        }

        return Swapchain{
            .handle = swapchain,
            .device = device_handle,
            .images = images,
            .image_views = image_views,
            .format = surface_format.format,
            .extent = extent,
            .allocator = allocator,
        };
    }

    /// Destroy the swapchain and free resources
    pub fn destroy(self: *Swapchain) void {
        // Destroy all image views
        for (self.image_views) |view| {
            raw.destroyImageView(self.device, view, null);
        }

        // Destroy swapchain
        raw.destroySwapchainKHR(self.device, self.handle, null);

        // Free allocated memory
        self.allocator.free(self.images);
        self.allocator.free(self.image_views);

        self.* = undefined;
    }

    /// Acquire the next image from the swapchain
    pub fn acquireNextImage(self: Swapchain, timeout: u64, semaphore: ?raw.Semaphore, fence: ?raw.Fence) errors.Error!u32 {
        var image_index: u32 = 0;
        const result = raw.acquireNextImageKHR(self.device, self.handle, timeout, semaphore orelse raw.NULL, fence orelse raw.NULL, &image_index);

        if (result == raw.SUBOPTIMAL_KHR) {
            return image_index; // Still usable, but not optimal
        }

        try errors.checkResult(result);
        return image_index;
    }

    /// Get the format of the swapchain images
    pub fn getFormat(self: Swapchain) raw.Format {
        return self.format;
    }

    /// Get the extent of the swapchain images
    pub fn getExtent(self: Swapchain) raw.Extent2D {
        return self.extent;
    }

    /// Get the number of images in the swapchain
    pub fn getImageCount(self: Swapchain) usize {
        return self.images.len;
    }

    /// Get the raw handle to the swapchain
    pub fn getHandle(self: Swapchain) raw.Swapchain {
        return self.handle;
    }
};
