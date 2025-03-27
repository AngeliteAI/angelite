const c = @cImport({
    @cInclude("xcb/xcb.h");
});

// Types
pub const Connection = c.xcb_connection_t;
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

pub fn get_setup(c_conn: *Connection) *Setup {
    return c.xcb_get_setup(c_conn);
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
