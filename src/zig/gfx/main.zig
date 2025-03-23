const render = @import("src/linux/render.zig");
pub fn main() void {
    if (render.init()) {
        @import("std").debug.print("success!", .{});
    }
}
