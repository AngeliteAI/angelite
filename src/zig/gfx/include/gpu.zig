pub const Buffer = *anyopaque;

pub extern fn create(cap: usize) ?*Buffer;
pub extern fn upload(data: [*]u8, len: usize) ?*Buffer;
pub extern fn stage(buffer: *Buffer) bool;
pub extern fn release(buffer: *Buffer) bool;
