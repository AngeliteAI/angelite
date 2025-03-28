const render = @import("src/linux/render.zig");
const surface = @import("src/linux/surface.zig");
const std = @import("std");
pub fn main() void {
    std.debug.print("surface!", .{});
    const activeSurface = surface.create();
    std.debug.print("render!", .{});
    const activeRenderer = render.init(activeSurface);
    if (activeRenderer == null) {
        std.debug.print("Failed to initialize renderer.\n", .{});
        return;
    }

    std.debug.print("Renderer initialized successfully.\n", .{});

    while (true) {
        surface.poll();
    }
}
