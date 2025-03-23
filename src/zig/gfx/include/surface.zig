pub const Surface = extern struct {
        id: u64, // Just an identifier for now, details will be platform-specific
    };

// Surface creation/destruction
pub extern fn create() ?*Surface;
pub extern fn destroy(s: *Surface) void; // Renamed parameter to 's'
pub extern fn supportsMultiple() bool;

// Surface updates
pub extern fn poll() void;

// Surface properties
pub extern fn setName(s: *Surface, name: []const u8) void;
pub extern fn getName(s: *Surface) []const u8;
pub extern fn setSize(s: *Surface, width: u32, height: u32) void;
pub extern fn getSize(s: *Surface, out_width: *u32, out_height: *u32) void;
pub extern fn setResizable(s: *Surface, resizable: bool) void;
pub extern fn isResizable(s: *Surface) bool;
pub extern fn setFullscreen(s: *Surface, fullscreen: bool) void;
pub extern fn isFullscreen(s: *Surface) bool;
pub extern fn setVSync(s: *Surface, vsync: bool) void;
pub extern fn isVSync(s: *Surface) bool;
pub extern fn showCursor(s: *Surface, show: bool) void;
pub extern fn confineCursor(s: *Surface, confine: bool) void;
pub extern fn focus(s: *Surface) void;
pub extern fn isFocused(s: *Surface) bool;
