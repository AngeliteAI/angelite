const cpu = @import("cpu");
const io = @import("io");

pub const File = opaque {};

pub extern fn create(user_data: ?*anyopaque) ?*File;
pub extern fn open(file: *File, path: [*:0]const u8, mode: i32) u64;
pub extern fn read(file: *File, buffer: *cpu.Buffer, offset: i64) u64;
pub extern fn write(file: *File, buffer: *cpu.Buffer, offset: i64) u64;
pub extern fn seek(file: *File, offset: i64, origin: io.SeekOrigin) u64;
pub extern fn flush(file: *File) u64;
pub extern fn close(file: *File) u64;
pub extern fn size(file: *File, size: *u64) bool;
