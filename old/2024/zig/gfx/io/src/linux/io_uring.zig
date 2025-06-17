const ctx = @import("ctx");
const io = @import("io");
const std = @import("std");
const util = @import("util");
const osio = @import("os_io");
const mem = std.mem;
const os = std.os;
const linux = os.linux;
const IoError = @import("err").Io;

pub const IoUringOp = enum(u8) {
    NOP = 0,
    READ = 1,
    WRITE = 2,
    FSYNC = 3,
    CLOSE = 4,
    STATX = 5,
    READ_FIXED = 6,
    WRITE_FIXED = 7,
    POLL_ADD = 8,
    POLL_REMOVE = 9,
    SYNC_FILE_RANGE = 10,
    SENDMSG = 11,
    RECVMSG = 12,
    SEND = 13,
    RECV = 14,
    ACCEPT = 15,
    CONNECT = 16,
    EPOLL_CTL = 17,
    SPLICE = 18,
    PROVIDE_BUFFERS = 19,
    REMOVE_BUFFERS = 20,
    TEE = 21,
    SHUTDOWN = 22,
    RENAMEAT = 23,
    UNLINKAT = 24,
    MKDIRAT = 25,
    SYMLINKAT = 26,
    LINKAT = 27,
    MSG_RING = 28,
    FSETXATTR = 29,
    SETXATTR = 30,
    FGETXATTR = 31,
    GETXATTR = 32,
    SOCKET = 33,
    URING_CMD = 34,
    SEND_ZC = 35,
    SENDMSG_ZC = 36,
    WAITID = 37,
    FUTEX_WAIT = 38,
    FUTEX_WAKE = 39,
    FUTEX_WAITV = 40,
    FIXED_FD_INSTALL = 41,
    FADVISE = 42,
    MADVISE = 43,
    OPENAT2 = 44,
    QUOTACTL = 45,
    STATX_TIMESTAMP = 46,
    BINARY = 47,
    FDINFO = 48,
    BIND = 49,
    LISTEN = 50,
    SETSOCKOPT = 51,
    GETSOCKOPT = 52,
    FSYNC_FILE_RANGE = 53,
    LSEEK = 54,
    PREAD = 55,
    PWRITE = 56,

    // Helper function to get integer value
    pub fn value(self: IoUringOp) u8 {
        return @intFromEnum(self);
    }

    // Helper to check if operation is available in current kernel
    pub fn isAvailable(self: IoUringOp, kernel_version: struct { major: u32, minor: u32 }) bool {
        return switch (self) {
            .BIND, .LISTEN, .SETSOCKOPT, .GETSOCKOPT => (kernel_version.major > 6) or
                (kernel_version.major == 6 and kernel_version.minor >= 0),
            .FSYNC_FILE_RANGE, .LSEEK => (kernel_version.major > 6) or
                (kernel_version.major == 6 and kernel_version.minor >= 0),
            .PREAD, .PWRITE => (kernel_version.major > 6) or
                (kernel_version.major == 6 and kernel_version.minor >= 1),
            else => true, // Most operations available since io_uring introduction (5.1)
        };
    }
};

const Context = struct {
    fd: os.fd_t,
    params: linux.io_uring_params,
    mappings: RingMappings,
    sq: QueuePointers,
    cq: QueuePointers,
    pendingOps: usize,
    nextOp: usize,
};

pub fn nextOperation() usize {
    const nextOp = &ctx.current().?.ioUring.nextOp;
    return @atomicRmw(usize, nextOp, .Add, 1, .Acquire);
}

pub fn init(desired_concurrency: usize) !Context {
    var params = mem.zeroes(linux.io_uring_params);
    const fd = linux.io_uring_setup(util.nextPowerOfTwo(desired_concurrency), &params);
    errdefer os.close(fd);

    const mappings = try map();

    return Context{ .fd = fd, .sq = QueuePointers.get(mappings.sq.ptr, params.sq_off, u32), .cq = QueuePointers.get(mappings.cq.ptr, params.cq_off, linux.io_uring_cqe), .params = params, .mappings = mappings, .pending_ops = 0 };
}

const RingMappings = struct { sq: RingMapping, cq: RingMapping, sqes: RingMapping };

const RingMapping = struct {
    ptr: [*]u8,
    len: usize,
};

const QueuePointers = struct {
    head: *u32,
    tail: *u32,
    mask: *u32,
    array_ptr: *anyopaque,

    pub fn array(self: *const QueuePointers, comptime T: type) [*]T {
        return @ptrCast(self.array_ptr);
    }

    fn get(
        ring_ptr: [*]u8,
        offsets: anytype,
        array_type: type,
    ) QueuePointers {
        // Calculate head, tail, and mask pointers
        const head = @as([*]align(@alignOf(u32)) u8, @alignCast(ring_ptr + offsets.head));
        const tail = @as([*]align(@alignOf(u32)) u8, @alignCast(ring_ptr + offsets.tail));
        const mask = @as([*]align(@alignOf(u32)) u8, @alignCast(ring_ptr + offsets.ring_mask));
        const array_ptr = @as([*]align(@alignOf(u32)) array_type, @alignCast(ring_ptr + offsets.array));

        return QueuePointers{
            .head = head,
            .tail = tail,
            .mask = mask,
            .array_ptr = array_ptr,
        };
    }
};

pub fn map(fd: os.fd_t, params: linux.io_uring_params) !RingMappings {
    const sq_size = params.sq_offsets.array + params.sq_entries * @sizeOf(u32);
    const cq_size = params.cq_off.cqes + params.cq_entries * @sizeOf(linux.io_uring_cqe);
    const sqes_size = params.sq_entries * @sizeOf(linux.io_uring_sqe);

    return RingMappings{
        .sq = try mapRing(fd, sq_size, linux.IORING_OFF_SQ_RING),
        .cq = try mapRing(fd, cq_size, linux.IORING_OFF_CQ_RING),
        .sqes = try mapRing(fd, sqes_size, linux.IORING_OFF_SQES),
    };
}

fn mapRing(fd: os.fd_t, size: usize, offset: u64) !RingMapping {
    const ptr = try os.mmap(null, size, os.PROT.READ | os.PROT.WRITE, os.MAP.SHARED | os.MAP.POPULATE, fd, offset);

    return RingMapping{
        .ptr = @ptrCast(ptr),
        .len = size,
    };
}

fn unmap() void {
    var context = ctx.current().ioUring;
    if (context.mappings.sq.ptr != null) {
        os.munmap(context.mappings.sq.ptr[0..context.sq.len]);
    }

    if (context.mappings.cq.ptr != null) {
        os.munmap(context.mappings.cq.ptr[0..context.cq.len]);
    }

    if (context.mappings.sqes.ptr != null) {
        os.munmap(context.mappings.sqes.ptr[0..context.sqes.len]);
    }
}

fn submit() !usize {
    const context = ctx.context() orelse return error.IoErrorUringNotInit;

    var ioUring = context.ioUring;
    const pendingOps = &ioUring.pendingOps;

    if (*pendingOps == 0) {
        return 0;
    }

    const submitted = linux.io_uring_enter(ioUring.fd, @intCast(*pendingOps), 0, 0, null);

    if (submitted == *pendingOps) {
        pendingOps.* = 0;
    } else {
        pendingOps.* -= @intCast(submitted);
    }

    return submitted;
}

pub fn poll(completions: *io.Complete, max_completions: usize) !usize {
    const context = ctx.context().?;

    const ioUring = context.ioUring;

    var ts = linux.timespec{
        .tv_sec = 0,

        .tv_nsec = 0,
    };

    const completed = linux.io_uring_enter(ioUring.fd, 0, max_completions, linux.IORING_ENTER_GETEVENTS, &ts);

    if (completed < 0) {
        return osio.convertError(-completed);
    }

    if (completed == 0) {
        return 0;
    }

    var i: usize = 0;
    while (i < completed) : (i += 1) {
        const cqe = completionByIndex(i);

        const op = @as(io.Operation, cqe.user_data);

        completions[i] = io.Completion{
            .op = op,
            .result = cqe.res,
        };
    }
}

fn completionByIndex(index: usize) *linux.io_uring_cqe {
    const context = ctx.current().?;
    const head = context.ioUring.cq.head.* + index;
    const mask = context.ioUring.cq.mask.*;
    const cqe = &context.ioUring.cq.array(linux.io_uring_cqe)[head & mask];
    return cqe;
}

pub fn nextSubmission() !*linux.io_uring_sqe {
    const context = ctx.current().?;
    const iou = context.ioUring;
    const params = iou.params;
    const sqes = iou.mappings.sqes;

    const head = iou.sq.head.*;
    const tail = iou.sq.tail.*;
    const mask = iou.sq.mask.*;

    if (tail - head > params.sq_entries) {
        return IoError.BufferFull;
    }

    const index = tail & mask;

    const sqes_ptr = @as([*]linux.io_uring_sqe, @ptrCast(sqes.ptr));

    const sqe = &sqes_ptr[index];

    iou.sq.tail.* += 1;
    iou.pendingOps += 1;

    const sqe_bytes = @as([*]u8, @ptrCast(sqe))[0..@sizeOf(linux.io_uring_sqe)];
    @memset(sqe_bytes, 0);

    return sqe;
}

pub fn next() !struct { op: usize, sqe: *linux.io_uring_sqe } {
    return .{ .op = try nextOperation(), .sqe = try nextSubmission() };
}
