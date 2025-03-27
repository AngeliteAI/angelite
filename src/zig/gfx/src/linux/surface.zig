const xcb = @import("xcb.zig");
const surface = @import("../../include/surface.zig");
const std = @import("std");

const Surface = surface.Surface;

pub const XcbSurface = struct {
    id: u64,
    connection: *xcb.Connection,
    window: xcb.Window,
    screen: *xcb.Screen,
};

var next_surface_id: u64 = 1;
var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var xcb_surface_allocator: std.mem.Allocator = undefined;
var xcb_surfaces: std.AutoHashMap(u64, XcbSurface) = undefined;
var init: bool = false;

pub export fn create() ?*Surface {
    if (!init) {
        init = true;
        gpa = std.heap.GeneralPurposeAllocator(.{}){};
        xcb_surface_allocator = gpa.allocator();
        xcb_surfaces = std.AutoHashMap(u64, XcbSurface).init(gpa.allocator());
    }

    // Connect to the X server
    const connection = xcb.connect(null, null) orelse return null;

    // Get the first screen
    const setup = xcb.get_setup(connection);
    const iter = xcb.setup_roots_iterator(setup);
    const screen = iter.data;

    // Calculate window dimensions (center on screen at half-size)
    // Use the C accessor functions instead of direct field access
    const screen_width = xcb.get_screen_width(screen);
    const screen_height = xcb.get_screen_height(screen);
    const calc_width = screen_width / 2;
    const calc_height = screen_height / 2;
    const pos_x = @as(i16, @intCast(screen_width / 4));
    const pos_y = @as(i16, @intCast(screen_height / 4));

    // Create the window
    const window = xcb.generate_id(connection);
    const value_mask = xcb.CW_BACK_PIXEL | xcb.CW_EVENT_MASK;
    const value_list = [_]u32{
        xcb.get_screen_white_pixel(screen), // background color
        xcb.EVENT_MASK_EXPOSURE | xcb.EVENT_MASK_KEY_PRESS, // event mask
    };

    _ = xcb.create_window(connection, // connection
        xcb.COPY_FROM_PARENT, // depth
        window, // window id
        xcb.get_screen_root(screen), // parent window
        pos_x, pos_y, // x, y position
        @intCast(calc_width), // width
        @intCast(calc_height), // height
        1, // border width
        xcb.WINDOW_CLASS_INPUT_OUTPUT, // class
        xcb.get_screen_root_visual(screen), // visual
        value_mask, // value mask
        &value_list // value list
    );

    // Set window title
    const title = "Hello, XCB Surface!";
    _ = xcb.change_property(connection, xcb.PROP_MODE_REPLACE, window, xcb.ATOM_WM_NAME, xcb.ATOM_STRING, 8, // 8-bit format
        title.len, title.ptr);

    // Map the window
    _ = xcb.map_window(connection, window);
    _ = xcb.flush(connection);

    const surface_id = next_surface_id;
    next_surface_id += 1;

    const xcb_surface = XcbSurface{ .id = surface_id, .connection = connection, .window = window, .screen = screen };

    xcb_surfaces.put(surface_id, xcb_surface) catch {
        return null;
    };

    const memory = xcb_surface_allocator.alloc(Surface, 1) catch {
        return null;
    };

    return @as(*Surface, @ptrCast(memory));
}

pub export fn poll() void {
    var xcb_surface_iter = xcb_surfaces.valueIterator();
    while (xcb_surface_iter.next()) |xcb_surface| {
        var event = xcb.poll_for_event(xcb_surface.connection);

        // Fixed event handling loop
        while (event != null) {
            const event_type = event.?.response_type & ~@as(u8, 0x80);
            switch (event_type) {
                xcb.EXPOSE => {
                    // Handle expose events if needed
                },
                xcb.KEY_PRESS => {
                    // Handle key press events if needed
                },
                else => {},
            }

            // Free event using proper allocation approach
            std.c.free(event);
            event = xcb.poll_for_event(xcb_surface.connection);
        }
    }
}

pub export fn destroy(surface_ptr: *Surface) void {
    const id = surface_ptr.id;
    if (xcb_surfaces.get(id)) |xcb_surface| {
        // Destroy the window
        _ = xcb.destroy_window(xcb_surface.connection, xcb_surface.window);
        // Disconnect from the X server
        xcb.disconnect(xcb_surface.connection);

        // Remove from hash map
        _ = xcb_surfaces.remove(id);
    }
    // Free the memory
    xcb_surface_allocator.free(@as([*]Surface, @ptrCast(surface_ptr))[0..1]);
}
