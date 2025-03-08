const cpu = @import("cpu");
const io = @import("io")

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

pub const Option = enum(i32) {
    REUSEADDR = 2,
    RCVTIMEO = 3,
    SNDTIMEO = 4,
    KEEPALIVE = 5,
    LINGER = 6,
    BUFFER_SIZE = 7,
    NODELAY = 8,
};

// Socket extern forward declarations
pub extern fn create(ipv6: bool, sock_type: io.SockType, user_data: ?*anyopaque) ?*Socket;
pub extern fn bind(sock: *Socket, address: *const IpAddress, op_id: ?*u64) bool;
pub extern fn listen(sock: *Socket, backlog: i32, op_id: ?*u64) bool;
pub extern fn accept(sock: *Socket, op_id: ?*u64) bool;
pub extern fn connect(sock: *Socket, address: *const IpAddress, op_id: ?*u64) bool;
pub extern fn recv(sock: *Socket, buffer: *cpu.Buffer, op_id: ?*u64) bool;
pub extern fn send(sock: *Socket, buffer: *cpu.Buffer, op_id: ?*u64) bool;
pub extern fn close(sock: *Socket) bool;
pub extern fn release(sock: *Socket) bool;
pub extern fn setOption(sock: *Socket, option: Option, value: *const anyopaque, len: u32) bool;
