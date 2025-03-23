const render = @import("render.zig");
const vk = @import("vk.zig");
const std = @import("std");

pub export fn init() bool {
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
    _ = instance;
    std.debug.print("Vulkan instance created successfully\n", .{});
    return true;
}
