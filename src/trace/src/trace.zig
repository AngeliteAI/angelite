const std = @import("std");

pub export fn log(message: [*:0]const u8) void {
    std.debug.print("{s}\n", .{message});
}