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

const INET = os.INET;
const INET6 = os.INET6;
const SOCK_STREAM = os.SOCK.STREAM;

pub const IORING_OP_CLOSE = iou.IoUringOp.IORING_OP_CLOSE;
pub const IORING_OP_ACCEPT = iou.IoUringOp.IORING_OP_ACCEPT;
pub const IORING_OP_CONNECT = iou.IoUringOp.IORING_OP_CONNECT;
pub const IORING_OP_RECV = iou.IoUringOp.IORING_OP_RECV;
pub const IORING_OP_SEND = iou.IoUringOp.IORING_OP_SEND;
pub const IORING_OP_BIND = iou.IoUringOp.IORING_OP_BIND;
pub const IORING_OP_LISTEN = iou.IoUringOp.IORING_OP_LISTEN;

const IpAddress = socket.IpAddress;

const IoError = io.Error;

const Error = ctx.Error;

const lastError = ctx.lastError;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub const Socket = struct {
    fd: os.fd_t,
    ipv6: bool,
    address: *IpAddress,
    user_data: ?*anyopaque,

    pub fn create(ipv6: bool, user_data: ?*anyopaque) !*Socket {
        const sock = gpa.allocate(Socket) orelse return null;
        const domain = if (ipv6) INET6 orelse INET;
        const fd = os.self(domain, SOCK_STREAM, 0);

        sock.* = Socket{ .fd = fd, .user_data = user_data };

        sock;
    }

    pub fn bind(self: *Socket, address: *const IpAddress) !void {
        if (self.ipv6 != address.is_ipv6)
            return IoError.InvalidArgument;

        const sock_addr = try prepareAddress(address);

        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.BIND,
            .user_data = self.user_data,
            .handle = self,
        };
        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_BIND,
            .fd = self.fd,
            .addr = @ptrCast(&sock_addr.addr),
            .len = sock_addr.len,
            .user_data = @ptrCast(&op),
        };
    }

    pub fn listen(self: *Socket, backlog: i32) !void {
        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.LISTEN,
            .user_data = self.user_data,
            .handle = self,
        };
        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_LISTEN,
            .fd = self.fd,
            .len = @intCast(backlog),
            .user_data = @ptrCast(&op),
        };
    }

    pub fn accept(self: *Socket) !void {
        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.ACCEPT,
            .user_data = self.user_data,
            .handle = self,
        };
        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_ACCEPT,
            .fd = self.fd,
            .user_data = @ptrCast(&op),
        };
    }
    pub fn connect(self: *Socket, address: *const IpAddress) !void {
        if (self.ipv6 != address.is_ipv6)
            return IoError.InvalidArgument;

        const sock_addr = try prepareAddress(address);

        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.CONNECT,
            .user_data = self.user_data,
            .handle = self,
        };

        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_CONNECT,
            .fd = self.fd,
            .addr = @ptrCast(&sock_addr.addr),
            .len = sock_addr.len,
            .user_data = @ptrCast(&op),
        };
    }
    pub fn recv(self: *Socket, buffer: *cpu.Buffer) !void {
        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.RECV,
            .user_data = self.user_data,
            .handle = self,
        };

        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_RECV,
            .fd = self.fd,
            .addr = @ptrCast(buffer.data),
            .len = buffer.capacity,
            .user_data = @ptrCast(&op),
        };
    }
    pub fn send(self: *Socket, buffer: *cpu.Buffer) !void {
        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.RECV,
            .user_data = self.user_data,
            .handle = self,
        };

        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_RECV,
            .fd = self.fd,
            .addr = @ptrCast(buffer.data),
            .len = buffer.len,
            .user_data = @ptrCast(&op),
        };
    }
    pub fn close(self: *Socket) !void {
        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.CLOSE,
            .user_data = self.user_data,
            .handle = self,
        };

        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_CLOSE,
            .fd = self.fd,
            .user_data = @ptrCast(&op),
        };
    }
    pub fn setOption(self: *Socket, option: socket.Option, value: *const anyopaque, len: u32) !void {
        const level = switch (option.level) {
            .Socket => os.SOL_SOCKET,
            .Tcp => os.IPPROTO_TCP,
            .Ipv4 => os.IPPROTO_IP,
            .Ipv6 => os.IPPROTO_IPV6,
            else => return IoError.InvalidArgument,
        };

        try os.setsockopt(self.fd, level, @intFromEnum(option.name), @ptrCast(value), len);
    }
};

fn prepareAddress(comptime T: type, address: socket.IpAddress) !T {
    switch (T) {
        os.sockaddr.in6 => {
            var addr: os.sockaddr.in6 = mem.zeroes(os.sockaddr.in6);
            addr.family = INET6;
            addr.port = mem.nativeToBig(u16, address.addr.ipv6.port);
            mem.copy(u8, &addr.addr, &address.addr.ipv6.addr);
            return addr;
        },
        os.sockaddr.in => {
            var addr: os.sockaddr.in = std.mem.zeroes(os.sockaddr.in);
            addr.family = INET;
            addr.port = std.mem.nativeToBig(u16, address.addr.ipv4.port);
            std.mem.copy(u8, &addr.addr, &address.addr.ipv4.addr);
            return addr;
        },
    }
}

pub fn create(ipv6: bool, user_data: ?*anyopaque) ?*Socket {
    return Socket.create(ipv6, user_data) catch |err| {
        lastError().* = Error.from(err);
        return null;
    };
}
pub fn bind(sock: *Socket, address: *const IpAddress) bool {
    sock.bind(address) catch |err| {
        lastError().* = Error.from(err);
        return false;
    };
    return true;
}
pub fn listen(sock: *Socket, backlog: i32) bool {
    sock.listen(backlog) catch |err| {
        lastError().* = Error.from(err);
        return false;
    };
    return true;
}
pub fn accept(sock: *Socket) bool {
    sock.accept() catch |err| {
        lastError().* = Error.from(err);
        return false;
    };
    return true;
}
pub fn connect(sock: *Socket, address: *const IpAddress) bool {
    sock.connect(address) catch |err| {
        lastError().* = Error.from(err);
        return false;
    };
    return true;
}
pub fn recv(sock: *Socket, buffer: *cpu.Buffer) bool {
    sock.recv(buffer) catch |err| {
        lastError().* = Error.from(err);
        return false;
    };
    return true;
}
pub fn send(sock: *Socket, buffer: *cpu.Buffer) bool {
    sock.send(buffer) catch |err| {
        lastError().* = Error.from(err);
        return false;
    };
    return true;
}
pub fn close(sock: *Socket) bool {
    sock.close() catch |err| {
        lastError().* = Error.from(err);
        return false;
    };
    return true;
}
pub fn setOption(sock: *Socket, option: socket.Option, value: *const anyopaque, len: u32) bool {
    sock.setOption(option, value, len) catch |err| {
        lastError().* = Error.from(err);
        return false;
    };
    return true;
}
