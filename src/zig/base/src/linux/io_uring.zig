const ctx = @import("ctx");
const std = @import("std");
const util = @import("util");
const mem = std.mem;
const os = std.os;
const linux = os.linux;

const Context = struct {
    fd: os.fd_t,
    params: linux.io_uring_params,
    mappings: RingMappings,
    sq: QueuePointers,
    cq: QueuePointers,
    pending_ops: usize,
};

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
};

pub fn map(fd: os.fd_t, params: linux.io_uring_params) void {
    const sq_size = params.sq_off.array + params.sq_entries * @sizeOf(u32);
    const cq_size = params.cq_off.cqes + params.cq_entries * @sizeOf(linux.io_uring_cqe);
    const sqes_size = params.sq_entries * @sizeOf(linux.io_uring_sqe);

    ctx.current().io_uring = Context{
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
    var context = ctx.current();
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
