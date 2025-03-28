const io = @import("io");
const cpu = @import("cpu");
const ctx = @import("ctx");
const iou = @import("io_uring");
const std = @import("std");
const util = @import("util");
const err = @import("err");
const mem = std.mem;
const os = std.os;
const linux = os.linux;

pub const IORING_OP_READ = iou.IoUringOp.IORING_OP_READ;
pub const IORING_OP_WRITE = iou.IoUringOp.IORING_OP_WRITE;
pub const IORING_OP_FSYNC = iou.IoUringOp.IORING_OP_FSYNC;
pub const IORING_OP_CLOSE = iou.IoUringOp.IORING_OP_CLOSE;
pub const IORING_OP_LSEEK = iou.IoUringOp.IORING_OP_LSEEK;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub const File = struct {
    fd: os.fd_t,
    path: [*:0]const u8,
    mode: i32,
    user_data: ?*anyopaque,
    opened: bool,

    fn open(self: *File, path: [*:0]const u8, mode: i32) !void {
        if (self.opened) {
            return error.InvalidArgument;
        }

        self.fd = try std.os.open(path, mode, 0o666);
        self.path = path;
        self.mode = mode;
        self.opened = true;
    }

    fn read(self: *File, buffer: *cpu.Buffer, offset: i64) !void {
        if (!self.opened) {
            return error.BadFileDescriptor;
        }

        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.READ,
            .user_data = self.user_data,
            .handle = self,
        };

        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_READ,
            .flags = 0,
            .fd = self.fd,
            .off = offset,
            .addr = @intFromPtr(buffer.data),
            .len = buffer.cap,
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };
    }

    fn write(self: *File, buffer: *cpu.Buffer, offset: i64) !void {
        if (!self.opened) {
            return error.BadFileDescriptor;
        }

        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.WRITE,
            .user_data = self.user_data,
            .handle = self,
        };

        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_WRITE,
            .flags = 0,
            .fd = self.fd,
            .off = offset,
            .addr = @intFromPtr(buffer.data),
            .len = buffer.len,
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };
    }

    fn seek(self: *File, offset: i64, origin: io.SeekOrigin) !void {
        if (!self.opened) {
            return error.BadFileDescriptor;
        }

        const whence: u32 = switch (origin) {
            .BEGIN => std.os.SEEK.SET,
            .CURRENT => std.os.SEEK.CUR,
            .END => std.os.SEEK.END,
        };

        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.SEEK,
            .user_data = self.user_data,
            .handle = self,
        };

        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_LSEEK,
            .flags = 0,
            .fd = self.fd,
            .off = offset,
            .len = whence,
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };
    }

    fn flush(self: *File) !void {
        if (!self.opened) {
            return error.BadFileDescriptor;
        }

        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.FLUSH,
            .user_data = self.user_data,
            .handle = self,
        };

        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_FSYNC,
            .flags = 0,
            .fd = self.fd,
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };
    }

    fn close(self: *File) !void {
        if (!self.opened) {
            return error.BadFileDescriptor;
        }

        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.CLOSE,
            .user_data = self.user_data,
            .handle = self,
        };

        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_CLOSE,
            .flags = 0,
            .fd = self.fd,
            .user_data = @intFromPtr(&op),
            .buf_index = 0,
            .__pad2 = [2]u64{0} ** 2,
        };

        self.opened = false;
    }

    fn size(self: *File, size_out: *u64) !void {
        if (!self.opened) {
            return error.BadFileDescriptor;
        }

        var stat: std.os.Stat = undefined;
        try std.os.fstat(self.fd, &stat);
        size_out.* = @intCast(stat.size);
    }
};

// FFI-compatible functions
pub fn create(user_data: ?*anyopaque) ?*File {
    const file = allocator.create(File) catch {
        ctx.setLastError(.OUT_OF_MEMORY);
        return null;
    };

    file.* = File{
        .fd = -1,
        .path = undefined,
        .mode = 0,
        .user_data = user_data,
        .opened = false,
    };

    return file;
}

pub fn release(file: *File) bool {
    allocator.free(file) catch return false;
    return true;
}

pub fn open(file: *File, path: [*:0]const u8, mode: i32) bool {
    if (file == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    if (path == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    file.open(path, mode) catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn read(file: *File, buffer: *cpu.Buffer, offset: i64) bool {
    if (file == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    if (buffer == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    file.read(buffer, offset) catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn write(file: *File, buffer: *cpu.Buffer, offset: i64) bool {
    if (file == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    if (buffer == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }
    file.write(buffer, offset) catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn seek(file: *File, offset: i64, origin: io.SeekOrigin) bool {
    if (file == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    file.seek(offset, origin) catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn flush(file: *File) bool {
    if (file == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    file.flush() catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn close(file: *File) bool {
    if (file == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    file.close() catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

pub fn size(file: *File, size_out: *u64) bool {
    if (file == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    if (size_out == null) {
        ctx.setLastError(.INVALID_ARGUMENT);
        return false;
    }

    file.size(size_out) catch |e| {
        ctx.setLastError(err.Error.fromError(e));
        return false;
    };

    return true;
}

// Helper function to destroy a file object
pub fn destroy(file: *File) void {
    if (file.opened) {
        std.os.close(file.fd);
    }
    allocator.destroy(file);
}
