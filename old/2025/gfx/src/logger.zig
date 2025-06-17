const std = @import("std");
const trace = @import("trace");

/// Logger utility to convert formatted strings to a null-terminated string
/// for use with trace.log.
pub fn log(comptime fmt: []const u8, args: anytype) void {
    // Create a buffer to hold the formatted message (with some reasonable limit)
    var buffer: [4096]u8 = undefined;

    // Format the string into the buffer
    const message = std.fmt.bufPrintZ(&buffer, fmt, args) catch {
        // If we hit an error during formatting, log a simpler message
        trace.log("[GFX LOG ERROR] Failed to format log message");
        return;
    };

    // Pass the null-terminated message to trace.log
    trace.log(message.ptr);
}

// Pre-formatted log levels for consistency
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    log("[DEBUG] " ++ fmt, args);
}

pub fn info(comptime fmt: []const u8, args: anytype) void {
    log("[INFO] " ++ fmt, args);
}

pub fn warn(comptime fmt: []const u8, args: anytype) void {
    log("[WARN] " ++ fmt, args);
}

pub fn err(comptime fmt: []const u8, args: anytype) void {
    log("[ERROR] " ++ fmt, args);
}

pub fn critical(comptime fmt: []const u8, args: anytype) void {
    log("[CRITICAL] " ++ fmt, args);
}
