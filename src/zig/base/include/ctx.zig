const io = @import("io");

const Error = extern struct {
    internal_msg: [*:0]const u8,
    external_msg: [*:0]const u8,
};

// Core context functions
pub const Context = opaque {};

pub extern fn current() ?*Context;

pub extern fn init(desired_concurrency: u32) ?*Context;
pub extern fn shutdown(ctx: *Context) void;

// Queue operations
pub extern fn submit(context: *Context) i32;
pub extern fn poll(context: *Context, completions: *io.Complete, max_completions: u32, timeout_ms: i32) i32;

// Error handling
pub extern fn lastError() ?*Error;
