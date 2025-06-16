const cpu = @import("cpu");
const io = @import("io");

pub const File = opaque {};

pub extern fn create(user_data: ?*anyopaque) ?*File;
pub extern fn open(file: *File, path: [*:0]const u8, mode: i32) bool;
pub extern fn read(file: *File, buffer: *cpu.Buffer, offset: i64) bool;
pub extern fn write(file: *File, buffer: *cpu.Buffer, offset: i64) bool;
pub extern fn seek(file: *File, offset: i64, origin: io.SeekOrigin) bool;
pub extern fn flush(file: *File) bool;
pub extern fn close(file: *File) bool;
pub extern fn release(sock: *Socket) bool;
pub extern fn size(file: *File, size_out: *u64) bool;
