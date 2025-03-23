const x = @import("x11.zig");
const surface = @import("../../include/surface.zig");
const std = @import("std");

const Surface = surface.Surface;

pub const X11Surface = struct {
    id: u64,
    display: *x.Display,
    window: x.Window,
};

var next_surface_id: u64 = 1;
var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined; // Declare gpa as var and undefined initially
var x11_surface_allocator: std.mem.Allocator = undefined; // Declare x11_surface_allocator as var and undefined
var x11_surfaces: std.AutoHashMap(u64, X11Surface) = undefined; // Declare x11_surfaces as var and undefined
var init: bool = false;

pub export fn create() ?*Surface {
    if (!init) {
        init = true;
        gpa = std.heap.GeneralPurposeAllocator(.{}){}; // Initialize gpa in init
        x11_surface_allocator = gpa.allocator(); // Initialize x11_surface_allocator using gpa after gpa is initialized
        x11_surfaces = std.AutoHashMap(u64, X11Surface).init(gpa.allocator());
    }

    const display = x.OpenDisplay(null).?;

    @import("std").debug.print("yo", .{});

    const screen = x.DefaultScreen(display);
    @import("std").debug.print("yo", .{});

    const screenWidth = @as(u32, @intCast(x.DisplayWidth(display, screen))); // Get display width
    const screenHeight = @as(u32, @intCast(x.DisplayHeight(display, screen))); // Get display height

    const calcWidth = screenWidth / 2;
    const calcHeight = screenHeight / 2;
    const posX = @as(c_int, @intCast(screenWidth / 4));
    const posY = @as(c_int, @intCast(screenHeight / 4));

    @import("std").debug.print("yo", .{});
    const borderWidth = 1;

    const root = x.RootWindow(display, screen);

    const black = x.BlackPixel(display, screen);
    const white = x.WhitePixel(display, screen);

    @import("std").debug.print("yo", .{});
    const window = x.CreateSimpleWindow(display, root, posX, posY, calcWidth, calcHeight, borderWidth, black, white);

    @import("std").debug.print("yo", .{});
    if (window == 0) {
        _ = x.CloseDisplay(display);
        return null;
    }

    @import("std").debug.print("yo", .{});
    const surface_id = next_surface_id;
    next_surface_id += 1;

    const x11_surface = X11Surface{ .id = surface_id, .display = display, .window = window };

    @import("std").debug.print("yo", .{});
    x11_surfaces.put(surface_id, x11_surface) catch {
        return null;
    };

    _ = x.SelectInput(display, window, x.ExposureMask);
    _ = x.StoreName(display, window, "Hello, Surface!");

    _ = x.MapWindow(display, window);
    _ = x.Flush(display);

    @import("std").debug.print("yo", .{});
    const memory = x11_surface_allocator.alloc(Surface, 1) catch {
        return null;
    };

    return @as(*Surface, @ptrCast(memory));
}

pub export fn poll() void {
    var x11_surface_iter = x11_surfaces.valueIterator();
    while (x11_surface_iter.next()) |x11_surface| {
        var event: x.Event = undefined;
        @import("std").debug.print("yo", .{});
        while (x.pending(x11_surface.display) > 0) {
            _ = x.nextEvent(x11_surface.display, &event);
        }
    }
}
