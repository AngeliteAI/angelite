const io = @import("io");
const cpu = @import("cpu");
const socket = @import("socket");
const ctx = @import("ctx");
const iou = @import("io_uring");
const std = @import("std");
const util = @import("util");
const err = @import("err");
const mem = std.mem;
const os = std.os;
const linux = os.linux;

pub const IORING_OP_CLOSE = iou.IoUringOp.IORING_OP_CLOSE;
pub const IORING_OP_ACCEPT = iou.IoUringOp.IORING_OP_ACCEPT;
pub const IORING_OP_CONNECT = iou.IoUringOp.IORING_OP_CONNECT;
pub const IORING_OP_RECV = iou.IoUringOp.IORING_OP_RECV;
pub const IORING_OP_SEND = iou.IoUringOp.IORING_OP_SEND;
pub const IORING_OP_BIND = iou.IoUringOp.IORING_OP_BIND;
pub const IORING_OP_LISTEN = iou.IoUringOp.IORING_OP_LISTEN;

const IpAddress = socket.IpAddress;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub const Socket = struct {
    ty: io.HandleType,
    fd: os.fd_t,
    ipv6: bool,
    user_data: ?*anyopaque,
    connected: bool,
    bound: bool,
    listening: bool,

    fn bind(self: *Socket, address: *const IpAddress) !void {
        if (self.bound) {
            return error.AddressInUse;
        }

        if (self.ipv6 != address.is_ipv6) {
            return error.InvalidArgument;
        }

        var sock_addr: union {
            ipv4: os.sockaddr.in,
            ipv6: os.sockaddr.in6,
        } = undefined;

        var addr_len: os.socklen_t = undefined;

        if (address.is_ipv6) {
            var addr = &sock_addr.ipv6;
            addr.* = mem.zeroes(os.sockaddr.in6);
            addr.family = os.AF.INET6;
            addr.port = mem.nativeToBig(u16, address.addr.ipv6.port);
            mem.copy(u8, &addr.addr, &address.addr.ipv6.addr);
            addr_len = @sizeOf(os.sockaddr.in6);
        } else {
            var addr = &sock_addr.ipv4;
            addr.* = mem.zeroes(os.sockaddr.in);
            addr.family = os.AF.INET;
            addr.port = mem.nativeToBig(u16, address.addr.ipv4.port);
            mem.copy(u8, &addr.addr, &address.addr.ipv4.addr);
            addr_len = @sizeOf(os.sockaddr.in);
        }

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
            .addr = @intFromPtr(&sock_addr),
            .len = addr_len,
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };

        self.bound = true;
    }

    fn listen(self: *Socket, backlog: i32) !void {
        if (!self.bound) {
            return error.InvalidArgument;
        }

        if (self.listening) {
            return error.InvalidArgument;
        }

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
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };

        self.listening = true;
    }

    fn accept(self: *Socket) !void {
        if (!self.listening) {
            return error.InvalidArgument;
        }

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
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };
    }

    fn connect(self: *Socket, address: *const IpAddress) !void {
        if (self.connected) {
            return error.ConnectionRefused;
        }

        if (self.ipv6 != address.is_ipv6) {
            return error.InvalidArgument;
        }

        var sock_addr: union {
            ipv4: os.sockaddr.in,
            ipv6: os.sockaddr.in6,
        } = undefined;

        var addr_len: os.socklen_t = undefined;

        if (address.is_ipv6) {
            var addr = &sock_addr.ipv6;
            addr.* = mem.zeroes(os.sockaddr.in6);
            addr.family = os.AF.INET6;
            addr.port = mem.nativeToBig(u16, address.addr.ipv6.port);
            mem.copy(u8, &addr.addr, &address.addr.ipv6.addr);
            addr_len = @sizeOf(os.sockaddr.in6);
        } else {
            var addr = &sock_addr.ipv4;
            addr.* = mem.zeroes(os.sockaddr.in);
            addr.family = os.AF.INET;
            addr.port = mem.nativeToBig(u16, address.addr.ipv4.port);
            mem.copy(u8, &addr.addr, &address.addr.ipv4.addr);
            addr_len = @sizeOf(os.sockaddr.in);
        }

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
            .addr = @intFromPtr(&sock_addr),
            .len = addr_len,
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };

        self.connected = true;
    }

    fn recv(self: *Socket, buffer: *cpu.Buffer) !void {
        if (!self.connected) {
            return error.BadSocketDescriptor;
        }

        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.READ,
            .user_data = self.user_data,
            .handle = self,
        };

        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_RECV,
            .fd = self.fd,
            .addr = @intFromPtr(buffer.data),
            .len = buffer.cap,
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };
    }

    fn send(self: *Socket, buffer: *cpu.Buffer) !void {
        if (!self.connected) {
            return error.BadSocketDescriptor;
        }

        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.WRITE,
            .user_data = self.user_data,
            .handle = self,
        };

        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_SEND,
            .fd = self.fd,
            .addr = @intFromPtr(buffer.data),
            .len = buffer.len,
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };
    }

    fn close(self: *Socket) !void {
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
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };

        self.connected = false;
        self.bound = false;
        self.listening = false;
    }

    fn setOption(self: *Socket, option: socket.Option, value: *const anyopaque, len: u32) !void {
        const level = switch (option) {
            .REUSEADDR => os.SOL.SOCKET,
            .RCVTIMEO, .SNDTIMEO => os.SOL.SOCKET,
            .KEEPALIVE => os.SOL.SOCKET,
            .LINGER => os.SOL.SOCKET,
            .BUFFER_SIZE => os.SOL.SOCKET,
            .NODELAY => os.IPPROTO.TCP,
            else => return error.InvalidArgument,
        };

        const optname = switch (option) {
            .REUSEADDR => os.SO.REUSEADDR,
            .RCVTIMEO => os.SO.RCVTIMEO,
            .SNDTIMEO => os.SO.SNDTIMEO,
            .KEEPALIVE => os.SO.KEEPALIVE,
            .LINGER => os.SO.LINGER,
            .BUFFER_SIZE => os.SO.RCVBUF,
            .NODELAY => os.TCP.NODELAY,
            else => return error.InvalidArgument,
        };

        try os.setsockopt(self.fd, level, optname, value, len);
    }
};

// FFI-compatible functions
pub fn create(ipv6: bool, ty: io.SocketType, user_data: ?*anyopaque) ?*Socket {
    const domain = if (ipv6) os.AF.INET6 else os.AF.INET;

    const sock = allocator.create(Socket) catch {
        ctx.setLastError(.OUT_OF_MEMORY);
        return null;
    };

    const os_ty = switch (ty) {
        io.SocketType.STREAM => os.SOCK.STREAM,
        io.SocketType.DGRAM => os.SOCK.DGRAM,
    };

    const fd = os.socket(domain, os_ty, 0) catch {
        ctx.setLastError(.NETWORK_UNREACHABLE);
        allocator.destroy(sock);
        return null;
    };

    sock.* = Socket{
        .ty = io.HandleType.Socket,
        .fd = fd,
        .ipv6 = ipv6,
        .user_data = user_data,
        .connected = false,
        .bound = false,
        .listening = false,
    };

    return sock;
}
pub fn release(socket: *Socket) bool {
    allocator.free(socket) catch return false;
    return true;
}
pub fn bind(sock: *Socket, address: *const IpAddress) bool {
    if (sock == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }
    if (address == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }
    sock.bind(address) catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn listen(sock: *Socket, backlog: i32) bool {
    if (sock == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    sock.listen(backlog) catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn accept(sock: *Socket) bool {
    if (sock == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    sock.accept() catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn connect(sock: *Socket, address: *const IpAddress) bool {
    if (sock == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }
    if (address == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    sock.connect(address) catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn recv(sock: *Socket, buffer: *cpu.Buffer) bool {
    if (sock == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }
    if (buffer == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    sock.recv(buffer) catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn send(sock: *Socket, buffer: *cpu.Buffer) bool {
    if (sock == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    if (buffer == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    sock.send(buffer) catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn close(sock: *Socket) bool {
    if (sock == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    sock.close() catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn setOption(sock: *Socket, option: socket.Option, value: *const anyopaque, len: u32) bool {
    if (sock == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    if (value == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    sock.setOption(option, value, len) catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

// Helper function to destroy a socket object
pub fn destroy(sock: *Socket) void {
    os.close(sock.fd);
    allocator.destroy(sock);
}
