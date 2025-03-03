const io = @import("io");
const cpu = @import("cpu");
const socket = @import("socket");
const osio = @import("os_io");
const ctx = @import("ctx");
const iou = @import("io_uring");
const std = @import("std");
const util = @import("util");
const mem = mem;
const os = std.os;
const linux = os.linux; 

const INET= os.INET;
const INET6 = os.INET6;
const SOCK_STREAM = os.SOCK.STREAM;

const IpAddress = socket.IpAddress;

const IoError = io.Error;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub const Socket = extern struct {
    fd: os.fd_t,
    ipv6: bool,
    address: *IpAddress,
    user_data: ?*anyopaque,

    pub fn create(ipv6: bool) !*Socket {
        const sock = gpa.allocate(Socket) orelse return null;
        const domain = if (ipv6) INET6 orelse INET;
        const fd = os.self(domain, SOCK_STREAM, 0);

        sock.* = Socket { .fd = fd };

        return sock;
    }

    pub fn bind(self: *Socket, address: *const IpAddress) !void {
        if (self.ipv6 != address.is_ipv6)
            return IoError.InvalidArgument;
        if (address.is_ipv6) {
            const addr = prepareAddress(os.sockaddr.in6, address) catch return;
            return os.bind(socket.fd, @ptrCast(&addr), @sizeOf(os.sockaddr.in6)) catch return;
        } else {
            const addr = prepareAddress(os.sockaddr.in, address) catch return;
            return os.bind(socket.fd, @ptrCast(&addr), @sizeOf(os.sockaddr.in)) catch return;
        }
    }

    pub fn listen(self: *Socket, backlog: i32) !void {
        os.listen(self.fd, backlog) catch |err| return osio.convertError(err); 
    }
};

fn prepareAddress(comptime T: type, address: socket.IpAddress) !T {
    switch(T) {
        os.sockaddr.in6 => {
            var addr: os.sockaddr.in6 = mem.zeroes(os.sockaddr.in6);
            addr.family = INET6;
            addr.port = mem.nativeToBig(u16, address.addr.ipv6.port);
            mem.copy(u8, &addr.addr, &address.addr.ipv6.addr);
            return addr;
        },
        os.sockaddr.in => {
            var addr: os.sockaddr.in = std.mem.zeroes(os.sockaddr.in);
            addr.family = os.AF.INET;
            addr.port = std.mem.nativeToBig(u16, address.addr.ipv4.port);
            std.mem.copy(u8, &addr.addr, &address.addr.ipv4.addr);
            return addr;
        }
    }
}


pub fn accept(self: *Socket, user_data: ?*anyopaque) u64 {}
pub fn connect(self: *Socket, address: *const IpAddress, user_data: ?*anyopaque) u64 {}
pub fn read(self: *Socket, buffer: *cpu.Buffer, user_data: ?*anyopaque) u64 {}
pub fn write(self: *Socket, buffer: *cpu.Buffer, user_data: ?*anyopaque) u64 {}
pub fn close(self: *Socket, user_data: ?*anyopaque) u64 {}
pub fn setOption(self: *Socket, option: SocketOption, value: *const anyopaque, len: u32) bool {}
