pub const Buffer = extern struct { data: [*]u8, len: usize, cap: usize, owned: bool };

pub extern fn create(cap: usize) ?*Buffer;
pub extern fn wrap(data: [*]u8, len: usize) *Buffer;
pub extern fn release(buffer: *Buffer) bool;
