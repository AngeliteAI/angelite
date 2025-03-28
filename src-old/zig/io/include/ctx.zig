// src/zig/base/include/ctx.zig
const io = @import("io");
const err = @import("err");

// Use just the Error enum
pub const Error = err.Error;

// Core context functions
pub const Context = opaque {};

pub extern fn current() ?*Context;
pub extern fn init(desired_concurrency: usize) ?*Context;
pub extern fn shutdown() void;

// Queue operations
pub extern fn submit() usize;
pub extern fn poll(completions: *io.Complete, max_completions: usize) usize;

// Error handling - now returns just the error code
pub extern fn lastError() ?*Error;
