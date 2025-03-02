const io = @import("io");
const iou = @import("io_uring");
const std = @import("std");
const util = @import("util");
const mem = std.mem;
const os = std.os;
const linux = os.linux;

const Error = @import("ctx").Error;

pub const Context = extern struct {
    ioUring: iou.Context,
    lastError: ?*Error,
};

var context = mem.zeroes(Context);

pub fn current() ?*Context {
    return context;
}

pub fn init(desired_concurrency: u32) ?*Context {
    const ret = init: {
        var ioUring = 
            iou.init(desired_concurrency) catch break :init error.IoUringInit;

        context.* = Context{ .ioUring = ioUring, .lastError = null };

        break :init context;
    };

    if (ret) |ctx| {
        return ctx;
    } else |err| {
        lastError = Error { .msg = @errorName(err) }; 
        return null;
    }
}
pub fn shutdown() void {
    iou.unmap();

    if (context.fd != -1) {
        os.close(context.fd);
    }

    if (context.allocator) |allocator| {
        allocator.destroy(context);
    }
}

pub fn submit() i32 {}
pub fn poll(completions: *io.Complete, max_completions: u32, timeout_ms: i32) i32 {}

pub fn lastError() ?*Error {
    return &context.lastError;
}

