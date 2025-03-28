const std = @import("std");
const c = @cImport({
    @cInclude("xcb/xcb.h");
});

// Types
pub const Connection = c.xcb_connection_t;
pub const Atom = c.xcb_atom_t;
pub const Window = c.xcb_window_t;
pub const Screen = c.xcb_screen_t;
pub const Setup = c.xcb_setup_t;
pub const ScreenIterator = c.xcb_screen_iterator_t;
pub const GenericEvent = c.xcb_generic_event_t;
pub const GenericError = c.xcb_generic_error_t;
pub const Visualid = c.xcb_visualid_t;
pub const Keycode = c.xcb_keycode_t;

// Constants
pub const COPY_FROM_PARENT = c.XCB_COPY_FROM_PARENT;
pub const WINDOW_CLASS_INPUT_OUTPUT = c.XCB_WINDOW_CLASS_INPUT_OUTPUT;
pub const WINDOW_CLASS_INPUT_ONLY = c.XCB_WINDOW_CLASS_INPUT_ONLY;
pub const CW_BACK_PIXEL = c.XCB_CW_BACK_PIXEL;
pub const CW_EVENT_MASK = c.XCB_CW_EVENT_MASK;
pub const EVENT_MASK_EXPOSURE = c.XCB_EVENT_MASK_EXPOSURE;
pub const EVENT_MASK_KEY_PRESS = c.XCB_EVENT_MASK_KEY_PRESS;
pub const PROP_MODE_REPLACE = c.XCB_PROP_MODE_REPLACE;
pub const ATOM_WM_NAME = c.XCB_ATOM_WM_NAME;
pub const ATOM_STRING = c.XCB_ATOM_STRING;

// Event Types
pub const EXPOSE = c.XCB_EXPOSE;
pub const KEY_PRESS = c.XCB_KEY_PRESS;

// Function wrappers
pub fn connect(displayname: ?[*:0]const u8, screenp: ?*c_int) ?*Connection {
    return c.xcb_connect(displayname, screenp);
}

pub fn disconnect(c_conn: *Connection) void {
    c.xcb_disconnect(c_conn);
}

pub fn get_setup(c_conn: *Connection) *const Setup {
    return @ptrCast(c.xcb_get_setup(c_conn));
}

pub fn setup_roots_iterator(setup: *const Setup) ScreenIterator {
    return c.xcb_setup_roots_iterator(setup);
}

pub fn generate_id(c_conn: *Connection) Window {
    return c.xcb_generate_id(c_conn);
}

pub fn create_window(
    c_conn: *Connection,
    depth: u8,
    wid: Window,
    parent: Window,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    border_width: u16,
    class: u16,
    visual: Visualid,
    value_mask: u32,
    value_list: [*]const u32,
) c.xcb_void_cookie_t {
    return c.xcb_create_window(
        c_conn,
        depth,
        wid,
        parent,
        x,
        y,
        width,
        height,
        border_width,
        class,
        visual,
        value_mask,
        value_list,
    );
}

pub fn change_property(
    c_conn: *Connection,
    mode: u8,
    window: Window,
    property: c.xcb_atom_t,
    type_: c.xcb_atom_t,
    format: u8,
    data_len: u32,
    data: *const anyopaque,
) c.xcb_void_cookie_t {
    return c.xcb_change_property(
        c_conn,
        mode,
        window,
        property,
        type_,
        format,
        data_len,
        data,
    );
}

pub fn map_window(c_conn: *Connection, window: Window) c.xcb_void_cookie_t {
    return c.xcb_map_window(c_conn, window);
}

pub fn destroy_window(c_conn: *Connection, window: Window) c.xcb_void_cookie_t {
    return c.xcb_destroy_window(c_conn, window);
}

pub fn flush(c_conn: *Connection) c_int {
    return c.xcb_flush(c_conn);
}

pub fn poll_for_event(c_conn: *Connection) ?*GenericEvent {
    return c.xcb_poll_for_event(c_conn);
}

pub fn wait_for_event(c_conn: *Connection) ?*GenericEvent {
    return c.xcb_wait_for_event(c_conn);
}

pub fn get_geometry(c_conn: *Connection, drawable: c.xcb_drawable_t) c.xcb_get_geometry_cookie_t {
    return c.xcb_get_geometry(c_conn, drawable);
}

pub fn get_geometry_reply(
    c_conn: *Connection,
    cookie: c.xcb_get_geometry_cookie_t,
    e: ?*?*GenericError,
) ?*c.xcb_get_geometry_reply_t {
    return c.xcb_get_geometry_reply(c_conn, cookie, e);
}

pub fn intern_atom(
    c_conn: *Connection,
    only_if_exists: bool,
    name: [*:0]const u8,
) c.xcb_intern_atom_cookie_t {
    return c.xcb_intern_atom(
        c_conn,
        @intFromBool(only_if_exists),
        @intCast(std.mem.len(name)),
        name,
    );
}

pub fn intern_atom_reply(
    c_conn: *Connection,
    cookie: c.xcb_intern_atom_cookie_t,
    e: ?*?*GenericError,
) ?*c.xcb_intern_atom_reply_t {
    return c.xcb_intern_atom_reply(c_conn, cookie, e);
}
pub fn get_screen_width(c_conn: *Connection) ?u16 {
    const setup = get_setup(c_conn);

    const iter = setup_roots_iterator(setup);
    if (iter.data == null) return null;

    const root_window = iter.data.*.root;
    const geometry_cookie = get_geometry(c_conn, root_window);
    const geometry_reply = get_geometry_reply(c_conn, geometry_cookie, null);
    if (geometry_reply == null) return null;

    return geometry_reply.?.width;
}
pub fn get_screen_height(c_conn: *Connection) ?u16 {
    const setup = get_setup(c_conn);

    const iter = setup_roots_iterator(setup);
    if (iter.data == null) return null;

    const root_window = iter.data.*.root;
    const geometry_cookie = get_geometry(c_conn, root_window);
    const geometry_reply = get_geometry_reply(c_conn, geometry_cookie, null);
    if (geometry_reply == null) return null;

    return geometry_reply.?.height;
}

pub fn get_screen_white_pixel(screen: *Screen) u32 {
    return screen.white_pixel;
}

pub fn get_screen_root(screen: *Screen) Window {
    return screen.root;
}

pub fn get_screen_root_visual(screen: *Screen) Visualid {
    return screen.root_visual;
}
// Size hints structure for WM_NORMAL_HINTS
pub const SizeHints = extern struct {
    flags: c_ulong,
    x: c_int,
    y: c_int,
    width: c_int,
    height: c_int,
    min_width: c_int,
    min_height: c_int,
    max_width: c_int,
    max_height: c_int,
    width_inc: c_int,
    height_inc: c_int,
    min_aspect_num: c_int,
    min_aspect_den: c_int,
    max_aspect_num: c_int,
    max_aspect_den: c_int,
    base_width: c_int,
    base_height: c_int,
    win_gravity: c_int,
};

// SizeHints flags
pub const USPosition = 1 << 0;
pub const USSize = 1 << 1;
pub const PPosition = 1 << 2;
pub const PResizeInc = 1 << 6;
pub const PAspect = 1 << 7;
pub const PBaseSize = 1 << 8;
pub const PWinGravity = 1 << 9;

// Allocate and initialize a SizeHints structure
pub fn alloc_set_wm_normal_hints() *SizeHints {
    const hints = std.c.malloc(@sizeOf(SizeHints)) orelse unreachable;
    @memset(@as([*]u8, @ptrCast(hints))[0..@sizeOf(SizeHints)], 0);
    return @ptrCast(hints);
}

// Set position hints
pub fn set_wm_normal_hints_position(hints: *SizeHints, x: i16, y: i16) void {
    hints.flags |= PPosition;
    hints.x = x;
    hints.y = y;
}
// Set the WM_NORMAL_HINTS property
pub fn set_wm_normal_hints(conn: *Connection, window: Window, hints: *SizeHints) c.xcb_void_cookie_t {
    const atom_cookie = intern_atom(conn, false, "WM_NORMAL_HINTS");
    const atom_reply = intern_atom_reply(conn, atom_cookie, null);
    if (atom_reply == null) return c.xcb_void_cookie_t{};
    const atom_wm_normal_hints = atom_reply.?.atom;
    const result = change_property(
        conn,
        PROP_MODE_REPLACE,
        window,
        atom_wm_normal_hints,
        ATOM_WM_SIZE_HINTS,
        32,
        @divExact(@sizeOf(SizeHints), 4),
        hints,
    );
    std.c.free(hints);
    return result;
}

// Atom for size hints
pub const ATOM_WM_SIZE_HINTS: Atom = 28; // XA_WM_SIZE_HINTS

pub const CONFIG_WINDOW_X = c.XCB_CONFIG_WINDOW_X;
pub const CONFIG_WINDOW_Y = c.XCB_CONFIG_WINDOW_Y;

pub fn configure_window(
    conn: *Connection,
    window: Window,
    value_mask: u16,
    value_list: [*]const u32,
) c.xcb_void_cookie_t {
    return c.xcb_configure_window(conn, window, value_mask, value_list);
}

pub const ATOM_ATOM = c.XCB_ATOM_ATOM;

pub fn free(ptr: ?*anyopaque) void {
    if (ptr) |p| {
        std.c.free(p);
    }
}
