const render = @import("src/linux/render.zig");
const surface = @import("src/linux/surface.zig");

pub fn main() void {
    _ = surface.create();

    while(true){
        surface.poll();
    }
    if (render.init()) {
        @import("std").debug.print("success!", .{});
    }
}
