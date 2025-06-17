const std = @import("std");

pub const include = @import("include");

// Import surface module as a dependency
pub const surface = @import("surface");

// Export our logger for internal use
pub const logger = @import("logger.zig");

// Export render functions in a namespace instead of directly into the parent namespace
// This prevents math function symbols from being re-exported
pub usingnamespace @import("vk/render.zig");   // Local scalar.zig in src directory

// Library information
pub const version = "0.1.0";
