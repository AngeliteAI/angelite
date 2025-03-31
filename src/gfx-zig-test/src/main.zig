const gfx = @import("gfx");
const std = @import("std");
pub fn main() void {
    std.debug.print("surface!", .{});
    const activeSurface = gfx.surface.create();
    std.debug.print("render!", .{});
    const activeRenderer = gfx.render.init(activeSurface);
    if (activeRenderer == null) {
        std.debug.print("Failed to initialize renderer.\n", .{});
        return;
    }

    std.debug.print("Renderer initialized successfully.\n", .{});

    while (true) {
        gfx.surface.poll();
        gfx.render.render(activeRenderer.?);
    }
}
