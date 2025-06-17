const std = @import("std");
const win32 = @import("win32.zig");
pub const Surface = @import("include").surface.Surface;

// Windows-specific surface data
pub const WinSurface = struct {
    id: u64,
    hwnd: win32.HWND,
    hinstance: win32.HINSTANCE,
    is_resizable: bool = true,
    is_fullscreen: bool = false,
    is_vsync: bool = true,
    name_buffer: [256]u8 = [_]u8{0} ** 256,
    name_len: usize = 0,
};

var next_surface_id: u64 = 1;
var gpa: std.heap.GeneralPurposeAllocator(.{}) = undefined;
var win_allocator: std.mem.Allocator = undefined;
// Make sure win_surfaces is properly exported for Vulkan to use
pub var win_surfaces: std.AutoHashMap(u64, WinSurface) = undefined;
var initialized: bool = false;

// Window procedure callback function
fn windowProc(hwnd: win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) callconv(.C) win32.LRESULT {
    switch (msg) {
        win32.WM_DESTROY => {
            // Post quit message when window is destroyed
            return 0;
        },
        else => return win32.DefWindowProcW(hwnd, msg, wparam, lparam),
    }
}

// Initialize the module if not already done
fn init() bool {
    if (initialized) return true;

    gpa = std.heap.GeneralPurposeAllocator(.{}){};
    win_allocator = gpa.allocator();
    win_surfaces = std.AutoHashMap(u64, WinSurface).init(win_allocator);
    initialized = true;
    return true;
}

// Create a Windows surface
pub export fn createSurface() ?*Surface {
    if (!init()) return null;

    // Get module handle
    const hinstance = win32.GetModuleHandleW(null) orelse {
        std.debug.print("Failed to get module handle\n", .{});
        return null;
    };

    // Register window class
    const class_name = [_:0]u16{ 'Z', 'i', 'g', 'S', 'u', 'r', 'f', 'a', 'c', 'e', 0 };
    const wc = win32.WNDCLASSEXW{
        .cbSize = @sizeOf(win32.WNDCLASSEXW),
        .style = 0,
        .lpfnWndProc = windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = hinstance,
        .hIcon = null,
        .hCursor = null,
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = &class_name,
        .hIconSm = null,
    };

    _ = win32.RegisterClassExW(&wc);

    // Create window
    const window_name = [_:0]u16{ 'S', 'u', 'r', 'f', 'a', 'c', 'e', 0 };
    const hwnd = win32.CreateWindowExW(0, &class_name, &window_name, win32.WS_OVERLAPPEDWINDOW, 100, 100, 800, 600, null, null, hinstance, null) orelse {
        std.debug.print("Failed to create window\n", .{});
        return null;
    };

    // Show window
    _ = win32.ShowWindow(hwnd, win32.SW_SHOW);

    // Create surface ID and structure
    const surface_id = next_surface_id;
    next_surface_id += 1;

    // Store initial window name
    var win_surface = WinSurface{
        .id = surface_id,
        .hwnd = hwnd,
        .hinstance = hinstance,
    };

    const initial_name = "Surface";
    // Use a safer way to copy memory
    for (initial_name, 0..) |char, i| {
        win_surface.name_buffer[i] = char;
    }
    win_surface.name_len = initial_name.len;

    // Store in hashmap
    win_surfaces.put(surface_id, win_surface) catch {
        std.debug.print("Failed to store surface\n", .{});
        _ = win32.DestroyWindow(hwnd);
        return null;
    };

    // Allocate Surface struct to return
    const surface_ptr = win_allocator.create(Surface) catch {
        std.debug.print("Failed to allocate Surface\n", .{});
        _ = win_surfaces.remove(surface_id);
        _ = win32.DestroyWindow(hwnd);
        return null;
    };

    surface_ptr.* = Surface{ .id = surface_id };
    return surface_ptr;
}

pub export fn destroySurface(s: ?*Surface) void {
    if (s) |surface| {
        const surface_id = surface.id;
        if (win_surfaces.getEntry(surface_id)) |entry| {
            const win_surface = entry.value_ptr.*;
            _ = win32.DestroyWindow(win_surface.hwnd);
            _ = win_surfaces.remove(surface_id);
            win_allocator.destroy(surface);
        }
    }
}

pub export fn supportsMultipleSurfaces() bool {
    return true; // Windows supports multiple windows
}

pub export fn pollSurface() void {
    var msg: win32.MSG = undefined;
    while (win32.PeekMessageW(&msg, null, 0, 0, win32.PM_REMOVE) != 0) {
        _ = win32.TranslateMessage(&msg);
        _ = win32.DispatchMessageW(&msg);
    }
}

// Use C-compatible types for exported functions with strings
pub export fn setName(s: ?*Surface, name_ptr: [*c]const u8, name_len: usize) void {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            var win_surface = entry.value_ptr;

            // Store name in our buffer
            const copy_len = @min(name_len, 255);
            for (0..copy_len) |i| {
                win_surface.name_buffer[i] = name_ptr[i];
            }
            win_surface.name_buffer[copy_len] = 0; // Null terminate
            win_surface.name_len = copy_len;

            // Convert to UTF-16 for Windows API
            var wide_name: [256:0]u16 = [_:0]u16{0} ** 256; // Use sentinel-terminated array
            var i: usize = 0;
            while (i < copy_len) : (i += 1) {
                wide_name[i] = @intCast(name_ptr[i]);
            }

            _ = win32.SetWindowTextW(win_surface.hwnd, &wide_name);
        }
    }
}

// Return name through out parameters instead of slice
pub export fn getName(s: ?*Surface, out_buffer: [*c]u8, max_len: usize) usize {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            const win_surface = entry.value_ptr.*;
            const len = @min(win_surface.name_len, max_len - 1);

            for (0..len) |i| {
                out_buffer[i] = win_surface.name_buffer[i];
            }
            out_buffer[len] = 0; // Null terminate

            return len;
        }
    }

    if (max_len > 0) {
        out_buffer[0] = 0; // Empty string
    }
    return 0;
}

// Fix all other null checks in similar manner
pub export fn setSize(s: ?*Surface, width: u32, height: u32) void {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            const win_surface = entry.value_ptr.*;
            _ = win32.SetWindowPos(win_surface.hwnd, null, 0, 0, @intCast(width), @intCast(height), win32.SWP_NOMOVE | win32.SWP_NOZORDER);
        }
    }
}

pub export fn getSize(s: ?*Surface, out_width: *u32, out_height: *u32) void {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            const win_surface = entry.value_ptr.*;
            var rect: win32.RECT = undefined;
            if (win32.GetClientRect(win_surface.hwnd, &rect) != 0) {
                out_width.* = @intCast(rect.right - rect.left);
                out_height.* = @intCast(rect.bottom - rect.top);
            } else {
                out_width.* = 800;
                out_height.* = 600;
            }
        } else {
            out_width.* = 800;
            out_height.* = 600;
        }
    }
}

pub export fn setResizable(s: ?*Surface, resizable: bool) void {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            var win_surface = entry.value_ptr;
            win_surface.is_resizable = resizable;

            var style = win32.GetWindowLongW(win_surface.hwnd, win32.GWL_STYLE);
            if (resizable) {
                style |= @as(win32.LONG, @intCast(win32.WS_THICKFRAME | win32.WS_MAXIMIZEBOX));
            } else {
                style &= ~@as(win32.LONG, @intCast(win32.WS_THICKFRAME | win32.WS_MAXIMIZEBOX));
            }

            _ = win32.SetWindowLongW(win_surface.hwnd, win32.GWL_STYLE, style);
            _ = win32.SetWindowPos(win_surface.hwnd, null, 0, 0, 0, 0, win32.SWP_NOMOVE | win32.SWP_NOSIZE | win32.SWP_NOZORDER | win32.SWP_FRAMECHANGED);
        }
    }
}

pub export fn isResizable(s: ?*Surface) bool {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            return entry.value_ptr.*.is_resizable;
        }
    }

    return false;
}

pub export fn setFullscreen(s: ?*Surface, fullscreen: bool) void {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            var win_surface = entry.value_ptr;

            if (fullscreen == win_surface.is_fullscreen) return;

            win_surface.is_fullscreen = fullscreen;

            // Implementation would need to use ChangeDisplaySettings for true fullscreen
            // This is a simplified version that just removes window borders
            var style = win32.GetWindowLongW(win_surface.hwnd, win32.GWL_STYLE);

            if (fullscreen) {
                style &= ~@as(win32.LONG, @intCast(win32.WS_OVERLAPPEDWINDOW));
            } else {
                style |= @as(win32.LONG, @intCast(win32.WS_OVERLAPPEDWINDOW));
            }

            _ = win32.SetWindowLongW(win_surface.hwnd, win32.GWL_STYLE, style);
            _ = win32.SetWindowPos(win_surface.hwnd, null, 0, 0, 800, 600, win32.SWP_NOMOVE | win32.SWP_NOSIZE | win32.SWP_NOZORDER | win32.SWP_FRAMECHANGED);
        }
    }
}

pub export fn isFullscreen(s: ?*Surface) bool {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            return entry.value_ptr.*.is_fullscreen;
        }
    }

    return false;
}

pub export fn setVSync(s: ?*Surface, vsync: bool) void {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            var win_surface = entry.value_ptr;
            win_surface.is_vsync = vsync;
            // Actual VSync implementation would require graphics API integration
        }
    }
}

pub export fn isVSync(s: ?*Surface) bool {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            return entry.value_ptr.*.is_vsync;
        }
    }

    return false;
}

pub export fn showCursor(s: ?*Surface, show: bool) void {
    _ = s;
    _ = win32.ShowCursor(@intFromBool(show));
}

pub export fn confineCursor(s: ?*Surface, confine: bool) void {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            const win_surface = entry.value_ptr.*;

            if (confine) {
                var rect: win32.RECT = undefined;
                _ = win32.GetClientRect(win_surface.hwnd, &rect);
                _ = win32.ClipCursor(&rect);
            } else {
                _ = win32.ClipCursor(null);
            }
        }
    }
}

pub export fn focus(s: ?*Surface) void {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            const win_surface = entry.value_ptr.*;
            _ = win32.SetForegroundWindow(win_surface.hwnd);
        }
    }
}

pub export fn isFocused(s: ?*Surface) bool {
    if (s) |surface| {
        if (win_surfaces.getEntry(surface.id)) |entry| {
            const win_surface = entry.value_ptr.*;
            return win32.GetForegroundWindow() == win_surface.hwnd;
        }
    }

    return false;
}
