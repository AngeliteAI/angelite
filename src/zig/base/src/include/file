const cpu = @import("cpu");
const io = @import("io");

pub const File = opaque {};

pub extern fn create() ?*File;
pub extern fn open(file: *File, path: [*:0]const u8, mode: i32, user_data: ?*anyopaque) u64;
pub extern fn read(file: *File, buffer: *cpu.Buffer, offset: i64, user_data: ?*anyopaque) u64;
pub extern fn write(file: *File, buffer: *cpu.Buffer, offset: i64, user_data: ?*anyopaque) u64;
pub extern fn seek(file: *File, offset: i64, origin: io.SeekOrigin, user_data: ?*anyopaque) u64;
pub extern fn flush(file: *File, user_data: ?*anyopaque) u64;
pub extern fn close(file: *File, user_data: ?*anyopaque) u64;
pub extern fn size(file: *File, size: *u64) bool;
