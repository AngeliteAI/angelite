const xcb = @import("xcb.zig");
const surface = @import("include").surface;
const std = @import("std");

pub const Surface = surface.Surface;
pub const Id = struct { id: u64 };
pub const XcbSurface = struct {
    id: Id,
    connection: *xcb.Connection,
    window: xcb.Window,
    screen: *xcb.Screen,
};

var next_surface_id: Id = Id{ .id = 0 };
var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var xcb_surface_allocator: std.mem.Allocator = undefined;
pub var xcb_surfaces: std.AutoHashMap(Id, XcbSurface) = undefined;
var init: bool = false;
pub export fn createSurface() ?*Surface {
    if (!init) {
        init = true;
        gpa = std.heap.GeneralPurposeAllocator(.{}){};
        xcb_surface_allocator = gpa.allocator();
        xcb_surfaces = std.AutoHashMap(Id, XcbSurface).init(gpa.allocator());
    }

    // Connect to the X server
    const connection = xcb.connect(null, null) orelse {
        std.debug.print("Failed to connect to X server\n", .{});
        return null;
    };

    // Get the first screen
    const setup = xcb.get_setup(connection);
    const iter = xcb.setup_roots_iterator(setup);
    const screen = iter.data;
    if (screen == null) {
        std.debug.print("Failed to get screen from X server\n", .{});
        xcb.disconnect(connection);
        return null;
    }
    const screen_width = xcb.get_screen_width(connection).?;
    const screen_height = xcb.get_screen_height(connection).?;

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
        0, 0, // x, y position
        @intCast(screen_width), // width
        @intCast(screen_height), // height
        0, // border width (set to 0 for fullscreen look)
        xcb.WINDOW_CLASS_INPUT_OUTPUT, // class
        xcb.get_screen_root_visual(screen), // visual
        value_mask, // value mask
        &value_list // value list
    );

    // Set fullscreen state using EWMH protocol
    // Set fullscreen state using EWMH protocol
    const wm_state_cookie = xcb.intern_atom(connection, false, "_NET_WM_STATE");
    const wm_fullscreen_cookie = xcb.intern_atom(connection, false, "_NET_WM_STATE_FULLSCREEN");

    const wm_state_reply = xcb.intern_atom_reply(connection, wm_state_cookie, null);
    const wm_fullscreen_reply = xcb.intern_atom_reply(connection, wm_fullscreen_cookie, null);

    if (wm_state_reply == null or wm_fullscreen_reply == null) {
        std.debug.print("Failed to retrieve atoms for EWMH protocol\n", .{});
        _ = xcb.destroy_window(connection, window);
        xcb.disconnect(connection);
        return null;
    }

    _ = xcb.change_property(
        connection,
        xcb.PROP_MODE_REPLACE,
        window,
        wm_state_reply.?.*.atom,
        xcb.ATOM_ATOM,
        32,
        1,
        &wm_fullscreen_reply.?.*.atom,
    );

    xcb.free(wm_state_reply);
    xcb.free(wm_fullscreen_reply);

    _ = xcb.map_window(connection, window);
    _ = xcb.flush(connection);

    const surface_id = next_surface_id;
    next_surface_id.id += 1;

    const memory = xcb_surface_allocator.alloc(Surface, 1) catch {
        std.debug.print("Failed to allocate memory for Surface\n", .{});
        _ = xcb_surfaces.remove(surface_id);
        _ = xcb.destroy_window(connection, window);
        xcb.disconnect(connection);
        return null;
    };

    memory.ptr[0].id = surface_id.id;

    const xcb_surface = XcbSurface{
        .id = surface_id,
        .connection = connection,
        .window = window,
        .screen = screen,
    };

    xcb_surfaces.put(surface_id, xcb_surface) catch |err| {
        std.debug.print("Failed to allocate memory for XcbSurface\n {s}", .{@errorName(err)});
        _ = xcb_surface_allocator.free(memory);
        _ = xcb.destroy_window(connection, window);
        xcb.disconnect(connection);
        return null;
    };

    return @as(*Surface, @ptrCast(memory));
}

pub export fn destroySurface(s: ?*Surface) void {
    if (s) |activeSurface| {
        const surface_id = Id{ .id = activeSurface.id };
        if (xcb_surfaces.getEntry(surface_id)) |entry| {
            const xcb_surface = entry.value_ptr.*;
            _ = xcb.destroy_window(xcb_surface.connection, xcb_surface.window);
            xcb.disconnect(xcb_surface.connection);
            _ = xcb_surfaces.remove(surface_id);
        }
    }
}

pub export fn pollSurface() void {
    var it = xcb_surfaces.iterator();
    while (it.next()) |entry| {
        const event = xcb.poll_for_event(entry.value_ptr.*.connection);
        if (event == null) break;
        std.debug.print("Event\n", .{});
    }
}