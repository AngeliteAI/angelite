const io = @import("io");

const Error = extern struct {
    msg: [*:0]const u8,
    trace: [*:0]const u8,

    fn from(err: anyerror) *Error {
        return Error{
            .msg = @errorName(err),
            .trace = @errorReturnTrace(),
        };
    }
};

// Core context functions
pub const Context = opaque {};

pub extern fn current() ?*Context;

pub extern fn init(desired_concurrency: usize) ?*Context;
pub extern fn shutdown() void;

// Queue operations
pub extern fn submit() usize;
pub extern fn poll(completions: *io.Complete, max_completions: usize) usize;

// Error handling
pub extern fn lastError() ?*Error;
