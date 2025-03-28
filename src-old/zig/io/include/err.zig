// src/zig/base/include/err.zig
pub const Error = enum(i32) {
    // Success (no error)
    OK = 0,

    // Memory errors
    OUT_OF_MEMORY = 1,

    // I/O errors
    IO_ERROR = 10,
    BAD_FILE_DESCRIPTOR = 11,
    BAD_ADDRESS = 12,
    BUFFER_FULL = 13,
    RESOURCE_UNAVAILABLE = 14,

    // Argument errors
    INVALID_ARGUMENT = 20,

    // Operation errors
    OPERATION_TIMEOUT = 30,
    OPERATION_INTERRUPTED = 31,
    OPERATION_NOT_SUPPORTED = 32,

    // Network errors
    NETWORK_UNREACHABLE = 40,
    CONNECTION_REFUSED = 41,
    CONNECTION_RESET = 42,
    ADDRESS_IN_USE = 43,
    ADDRESS_NOT_AVAILABLE = 44,

    // Context errors
    CONTEXT_NOT_INITIALIZED = 50,
    SUBMISSION_QUEUE_FULL = 51,

    // System errors
    SYSTEM_LIMIT_REACHED = 60,

    // Unknown/unexpected errors
    UNKNOWN = 999,

    // Convert from system error codes to this enum
    pub fn fromOsError(code: i32) Error {
        return switch (code) {
            0 => .OK,
            std.os.ENOMEM => .OUT_OF_MEMORY,
            std.os.EINVAL => .INVALID_ARGUMENT,
            std.os.EAGAIN => .RESOURCE_UNAVAILABLE,
            std.os.EFAULT => .BAD_ADDRESS,
            std.os.EBADF => .BAD_FILE_DESCRIPTOR,
            std.os.ETIMEDOUT => .OPERATION_TIMEOUT,
            std.os.EINTR => .OPERATION_INTERRUPTED,
            std.os.ENOTSUP => .OPERATION_NOT_SUPPORTED,
            std.os.ENETUNREACH => .NETWORK_UNREACHABLE,
            std.os.ECONNREFUSED => .CONNECTION_REFUSED,
            std.os.ECONNRESET => .CONNECTION_RESET,
            std.os.EADDRINUSE => .ADDRESS_IN_USE,
            std.os.EADDRNOTAVAIL => .ADDRESS_NOT_AVAILABLE,
            else => .UNKNOWN,
        };
    }

    // Convert from Zig error to this enum
    pub fn fromError(err: anyerror) Error {
        return switch (err) {
            error.OutOfMemory => .OUT_OF_MEMORY,
            error.InvalidArgument => .INVALID_ARGUMENT,
            error.ResourceUnavailable => .RESOURCE_UNAVAILABLE,
            error.BadAddress => .BAD_ADDRESS,
            error.BadFileDescriptor => .BAD_FILE_DESCRIPTOR,
            error.Timeout => .OPERATION_TIMEOUT,
            error.Interrupt => .OPERATION_INTERRUPTED,
            error.OperationNotSupported => .OPERATION_NOT_SUPPORTED,
            error.NetworkUnreachable => .NETWORK_UNREACHABLE,
            error.ConnectionRefused => .CONNECTION_REFUSED,
            error.ConnectionReset => .CONNECTION_RESET,
            error.AddressInUse => .ADDRESS_IN_USE,
            error.AddressNotAvailable => .ADDRESS_NOT_AVAILABLE,
            error.IoUringNotInit => .CONTEXT_NOT_INITIALIZED,
            error.BufferFull => .BUFFER_FULL,
            error.SystemLimitReached => .SYSTEM_LIMIT_REACHED,
            else => .UNKNOWN,
        };
    }
};
