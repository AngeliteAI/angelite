const render = @import("src/linux/render.zig");
const surface = @import("src/linux/surface.zig");

pub fn main() void {
        @import("std").debug.print("surface!", .{});
    _ = surface.create();
        @import("std").debug.print("render!", .{});
    if (render.init()) {
        @import("std").debug.print("success!", .{});
    }

    while(true){
        surface.poll();
    }
}
