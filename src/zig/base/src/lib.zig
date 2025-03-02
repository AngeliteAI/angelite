pub const cpu = @import("linux/cpu.zig");
pub const ctx = @import("linux/ctx.zig");
pub const file = @import("linux/file.zig");
pub const io = @import("linux/io.zig");
pub const iou = @import("linux/io_uring.zig");
pub const socket = @import("linux/socket.zig");

// Re-export specific functions if needed for a cleaner API
pub const buffer_create = cpu.buffer_create;
pub const buffer_wrap = cpu.buffer_wrap;
pub const buffer_release = cpu.buffer_release;
