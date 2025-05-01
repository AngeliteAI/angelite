const std = @import("std");
const raw = @import("raw.zig");

/// Vulkan error type that combines both Zig-style errors and Vulkan result codes
pub const Error = error{
    // Vulkan standard errors
    OutOfHostMemory,
    OutOfDeviceMemory,
    InitializationFailed,
    DeviceLost,
    MemoryMapFailed,
    LayerNotPresent,
    ExtensionNotPresent,
    FeatureNotPresent,
    IncompatibleDriver,
    TooManyObjects,
    FormatNotSupported,
    FragmentedPool,
    SurfaceLost,
    SuboptimalSwapchain,
    OutOfDate,

    // Library-specific errors
    NoSuitableDevice,
    NoSuitableQueue,
    NoSuitableMemoryType,
    NoSuitableFormat,
    NoSuitablePresentMode,
    InvalidShaderCode,
    ResourceCreationFailed,
    InvalidHandle,
};

/// Check a Vulkan result code and convert it to an error if needed
pub fn checkResult(result: raw.Result) Error!void {
    return switch (result) {
        raw.SUCCESS => {},
        raw.ERROR_OUT_OF_HOST_MEMORY => Error.OutOfHostMemory,
        raw.ERROR_OUT_OF_DEVICE_MEMORY => Error.OutOfDeviceMemory,
        raw.ERROR_DEVICE_LOST => Error.DeviceLost,
        raw.OUT_OF_DATE => Error.OutOfDate,
        raw.SUBOPTIMAL_KHR => Error.SuboptimalSwapchain,
        raw.NOT_READY => Error.InitializationFailed,
        else => {
            std.log.err("Unknown Vulkan error code: {d}", .{result});
            return Error.InitializationFailed;
        },
    };
}

/// Wrap a vulkan function call with error checking
pub fn wrap(result: raw.Result) Error!void {
    return checkResult(result);
}

/// Log the details of a Vulkan error
pub fn logError(err: Error) void {
    std.log.err("Vulkan error: {s}", .{@errorName(err)});
}
