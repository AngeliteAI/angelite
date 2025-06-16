const err = @import("err");
const std = @import("std");
const os = std.os;

const IoError = err.IoError;

fn convertError(code: usize) IoError {
    return switch (code) {
        os.EINVAL => IoError.InvalidArgument,
        os.EAGAIN => IoError.ResourceUnavailable,
        os.EFAULT => IoError.BadAddress,
        os.ENOMEM => IoError.OutOfMemory,
        os.EBADF => IoError.BadFileDescriptor,
        os.ETIMEDOUT => IoError.Timeout,
        os.EINTR => IoError.Interrupt,
        else => IoError.Unknown,
    };
}
