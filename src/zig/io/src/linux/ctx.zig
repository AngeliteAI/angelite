// src/zig/base/src/linux/ctx.zig
const io = @import("io");
const iou = @import("io_uring");
const std = @import("std");
const util = @import("util");
const err = @import("err");
const mem = std.mem;
const os = std.os;
const linux = os.linux;

pub const Context = extern struct {
    ioUring: iou.Context,
    lastErrorCode: err.Error,
};

var context = mem.zeroes(Context);

pub fn current() ?*Context {
    return &context;
}

pub fn init(desired_concurrency: usize) ?*Context {
    const ioUring = iou.init(desired_concurrency) catch |e| {
        context.lastErrorCode = err.Error.fromError(e);
        return null;
    };

    context = Context{ .ioUring = ioUring, .lastErrorCode = .OK };

    return &context;
}

pub fn shutdown() void {
    iou.unmap();

    if (context.fd != -1) {
        os.close(context.fd);
    }
}

pub fn submit() usize {
    if (iou.submit()) |submitted| {
        return submitted;
    } else |e| {
        context.lastErrorCode = err.Error.fromError(e);
        return 0;
    }
}

pub fn poll(completions: *io.Complete, max_completions: usize) usize {
    if (iou.poll(completions, max_completions)) |completed| {
        return completed;
    } else |e| {
        context.lastErrorCode = err.Error.fromError(e);
        return 0;
    }
}

pub fn lastError() ?*err.Error {
    if (context.lastErrorCode != err.Error.OK) {
        return &context.lastErrorCode;
    } else {
        return null;
    }
}

// Helper to set the last error
fn setLastError(errorCode: err.Error) void {
    context.lastErrorCode = errorCode;
}
