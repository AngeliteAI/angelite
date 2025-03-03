const io = @import("io");
const cpu = @import("cpu");
const ctx = @import("ctx");
const iou = @import("io_uring");
const std = @import("std");
const util = @import("util");
const mem = std.mem;
const os = std.os;
const linux = os.linux;

pub const IORING_OP_READ = iou.IoUringOp.IORING_OP_READ;
pub const IORING_OP_WRITE = iou.IoUringOp.IORING_OP_WRITE;
pub const IORING_OP_FSYNC = iou.IoUringOp.IORING_OP_FSYNC;
pub const IORING_OP_CLOSE = iou.IoUringOp.IORING_OP_CLOSE;
pub const IORING_OP_LSEEK = iou.IoUringOp.IORING_OP_LSEEK;

const IoError = io.Error;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub const File = struct {
    fd: os.fd_t,
    path: [*:0]const u8,
    mode: i32,
    user_data: ?*anyopaque,
    opened: bool,

    pub fn create(user_data: ?*anyopaque) IoError!*File {
        var self = allocator.create(File) orelse IoError.OutOfMemory;

        self.user_data = user_data;

        return self;
    }

    pub fn release(self: *File) void {
        allocator.destroy(self);
    }
    pub fn open(self: *File, path: [*:0]const u8, mode: i32) IoError!void {
        const context = ctx.current().?;

        self.* = File{ .fd = 0, .opened = true, .user_data = self.user_data, .path = path, .mode = mode };

        const slot = try iou.next();

        linux.io_uring_prep_openat(slot.sqe, linux.AT_FDCWD, path, mode, 0);

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.OPEN,
            .user_data = self.user_data,
            .handle = self,
        };

        linux.io_uring_sqe_set_data(slot.sqe, @ptrCast(op));

        context.ioUring.pendingOps += 1;
    }

    pub fn read(self: *File, buffer: *cpu.Buffer, offset: isize) IoError!void {
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
            .addr = buffer.data,
            .len = buffer.cap,
            .user_data = &op,
        };
    }

    pub fn write(self: *File, buffer: *cpu.Buffer, offset: isize) IoError!void {
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
            .addr = buffer.data,
            .len = buffer.len,
            .user_data = &op,
        };
    }

    pub fn seek(self: *File, offset: i64, origin: io.SeekOrigin) IoError!void {
        const whence: u32 = switch (origin) {
            .BEGIN => std.os.SEEK.SET,
            .CURRENT => std.os.SEEK.CUR,
            .END => std.os.SEEK.END,
        };
        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.WRITE,
            .user_data = self.user_data,
            .handle = self,
        };
        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_LSEEK,
            .flags = 0,
            .fd = self.fd,
            .off = offset,
            .len = whence,
            .user_data = &op,
        };
    }

    pub fn flush(self: *File) IoError!void {
        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.WRITE,
            .user_data = self.user_data,
            .handle = self,
        };
        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_FSYNC,
            .flags = 0,
            .fd = self.fd,
            .user_data = &op,
        };
    }

    pub fn close(self: *File) u64 {
        const slot = try iou.next();

        const op = io.Operation{
            .id = slot.op,
            .type = io.OperationType.WRITE,
            .user_data = self.user_data,
            .handle = self,
        };
        slot.sqe.* = linux.io_uring_sqe{
            .opcode = IORING_OP_CLOSE,
            .flags = 0,
            .fd = self.fd,
            .user_data = &op,
        };
    }

    pub fn size(self: *File, size_out: *usize) IoError!void {
        var stat: std.os.Stat = undefined;
        std.os.fstat(self.fd, &stat) catch return IoError.Unknown;
        size_out.* = @as(usize, @intCast(stat.size));
    }
};
