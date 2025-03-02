const cpu = @import("cpu");

pub const Socket = opaque {};

pub const IpAddress = extern struct {
    is_ipv6: bool,

    addr: extern union {
        ipv4: extern struct {
            addr: [4]u8,
            port: u16,
        },
        ipv6: extern struct {
            addr: [16]u8,
            port: u16,
        },
    },
};

pub const SocketOption = enum(i32) {
    REUSEADDR = 2,
    RCVTIMEO = 3,
    SNDTIMEO = 4,
    KEEPALIVE = 5,
    LINGER = 6,
    BUFFER_SIZE = 7,
    NODELAY = 8,
};

// Socket operations
pub extern fn create(ipv6: bool) ?*Socket;
pub extern fn bind(socket: *Socket, address: *const IpAddress) bool;
pub extern fn listen(socket: *Socket, backlog: i32) bool;
pub extern fn accept(socket: *Socket, user_data: ?*anyopaque) u64;
pub extern fn connect(socket: *Socket, address: *const IpAddress, user_data: ?*anyopaque) u64;
pub extern fn read(socket: *Socket, buffer: *cpu.Buffer, user_data: ?*anyopaque) u64;
pub extern fn write(socket: *Socket, buffer: *cpu.Buffer, user_data: ?*anyopaque) u64;
pub extern fn close(socket: *Socket, user_data: ?*anyopaque) u64;
pub extern fn setOption(socket: *Socket, option: SocketOption, value: *const anyopaque, len: u32) bool;
