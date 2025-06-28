const std = @import("std");

// Constants for Win32 API
const WS_OVERLAPPED = 0x00000000;
const WS_CAPTION = 0x00C00000;
const WS_SYSMENU = 0x00080000;
const WS_THICKFRAME = 0x00040000;
const WS_MINIMIZEBOX = 0x00020000;
const WS_MAXIMIZEBOX = 0x00010000;
const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
const WS_VISIBLE = 0x10000000;

const CS_OWNDC = 0x0020;
const CS_HREDRAW = 0x0002;
const CS_VREDRAW = 0x0001;

const CW_USEDEFAULT = -2147483648; // 0x80000000 in signed form

const SW_HIDE = 0;
const SW_SHOW = 5;

const SWP_NOMOVE = 0x0002;
const SWP_NOSIZE = 0x0001;

const GWLP_USERDATA = -21;

const PM_REMOVE = 0x0001;

// WM_ACTIVATE constants
const WA_INACTIVE = 0;
const WA_ACTIVE = 1;
const WA_CLICKACTIVE = 2;

// Window messages
const WM_CREATE = 0x0001;
const WM_DESTROY = 0x0002;
const WM_SIZE = 0x0005;
const WM_ACTIVATE = 0x0006;
const WM_SETFOCUS = 0x0007;
const WM_KILLFOCUS = 0x0008;
const WM_CLOSE = 0x0010;
const WM_SYSCOMMAND = 0x0112;

// Input messages
const WM_KEYDOWN = 0x0100;
const WM_KEYUP = 0x0101;
const WM_SYSKEYDOWN = 0x0104;
const WM_SYSKEYUP = 0x0105;
const WM_MOUSEMOVE = 0x0200;
const WM_LBUTTONDOWN = 0x0201;
const WM_LBUTTONUP = 0x0202;
const WM_RBUTTONDOWN = 0x0204;
const WM_RBUTTONUP = 0x0205;
const WM_MBUTTONDOWN = 0x0207;
const WM_MBUTTONUP = 0x0208;
const WM_MOUSEWHEEL = 0x020A;
const WM_MOUSEHWHEEL = 0x020E;

// Virtual key codes
const VK_ESCAPE = 0x1B;
const VK_SPACE = 0x20;
const VK_RETURN = 0x0D;
const VK_LEFT = 0x25;
const VK_UP = 0x26;
const VK_RIGHT = 0x27;
const VK_DOWN = 0x28;
const VK_W = 0x57;
const VK_A = 0x41;
const VK_S = 0x53;
const VK_D = 0x44;

// DPI awareness context
const DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2: ?*anyopaque = @ptrFromInt(@as(usize, @bitCast(@as(isize, -4))));

// Basic Windows types
const HWND = ?*anyopaque;
const HINSTANCE = ?*anyopaque;
const HICON = ?*anyopaque;
const HCURSOR = ?*anyopaque;
const HBRUSH = ?*anyopaque;
const HMENU = ?*anyopaque;

const WPARAM = usize;
const LPARAM = isize;
const LRESULT = isize;
const BOOL = i32;
const DWORD = u32;
const UINT = u32;
const WORD = u16;
const ATOM = WORD;
const LONG = i32;

// Structs
const POINT = extern struct {
    x: LONG,
    y: LONG,
};

const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

const MSG = extern struct {
    hwnd: HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

const WNDCLASSEXA = extern struct {
    cbSize: UINT,
    style: UINT,
    lpfnWndProc: *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.C) LRESULT,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: HINSTANCE,
    hIcon: HICON,
    hCursor: HCURSOR,
    hbrBackground: HBRUSH,
    lpszMenuName: ?[*:0]const u8,
    lpszClassName: [*:0]const u8,
    hIconSm: HICON,
};

const CREATESTRUCTA = extern struct {
    lpCreateParams: ?*anyopaque,
    hInstance: HINSTANCE,
    hMenu: HMENU,
    hwndParent: HWND,
    cy: i32,
    cx: i32,
    y: i32,
    x: i32,
    style: LONG,
    lpszName: [*:0]const u8,
    lpszClass: [*:0]const u8,
    dwExStyle: DWORD,
};

// Win32 API function declarations
extern "user32" fn GetModuleHandleA(?[*:0]const u8) HINSTANCE;
extern "user32" fn LoadCursorA(hInstance: HINSTANCE, lpCursorName: ?*const anyopaque) HCURSOR;
extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) ATOM;
extern "user32" fn CreateWindowExA(DWORD, [*:0]const u8, [*:0]const u8, DWORD, i32, i32, i32, i32, HWND, HMENU, HINSTANCE, ?*anyopaque) HWND;
extern "user32" fn DestroyWindow(HWND) BOOL;
extern "user32" fn ShowWindow(HWND, i32) BOOL;
extern "user32" fn UpdateWindow(HWND) BOOL;
extern "user32" fn SetForegroundWindow(HWND) BOOL;
extern "user32" fn SetFocus(HWND) HWND;
extern "user32" fn PeekMessageA(*MSG, HWND, UINT, UINT, UINT) BOOL;
extern "user32" fn TranslateMessage(*const MSG) BOOL;
extern "user32" fn DispatchMessageA(*const MSG) LRESULT;
extern "user32" fn DefWindowProcA(HWND, UINT, WPARAM, LPARAM) LRESULT;
extern "user32" fn GetClientRect(HWND, *RECT) BOOL;
extern "user32" fn GetWindowRect(HWND, *RECT) BOOL;
extern "user32" fn AdjustWindowRectEx(*RECT, DWORD, BOOL, DWORD) BOOL;
extern "user32" fn SetWindowPos(HWND, HWND, i32, i32, i32, i32, UINT) BOOL;
extern "user32" fn MoveWindow(HWND, i32, i32, i32, i32, BOOL) BOOL;
extern "user32" fn SetWindowTextA(HWND, [*:0]const u8) BOOL;
extern "user32" fn GetWindowLongPtrA(HWND, i32) isize;
extern "user32" fn SetWindowLongPtrA(HWND, i32, isize) isize;
extern "user32" fn IsWindow(HWND) BOOL;
extern "user32" fn IsWindowVisible(HWND) BOOL;
extern "user32" fn IsIconic(HWND) BOOL;
extern "user32" fn GetDpiForWindow(HWND) UINT;
extern "user32" fn SetProcessDpiAwarenessContext(?*anyopaque) BOOL;
extern "user32" fn SetCapture(HWND) HWND;
extern "user32" fn ReleaseCapture() BOOL;
extern "user32" fn GetCapture() HWND;

// Callback function types
pub const ResizeCallbackFn = *const fn (*anyopaque, i32, i32) callconv(.C) void;
pub const FocusCallbackFn = *const fn (*anyopaque, bool) callconv(.C) void;
pub const CloseCallbackFn = *const fn (*anyopaque) callconv(.C) bool;
pub const KeyCallbackFn = *const fn (*anyopaque, u32, bool) callconv(.C) void;
pub const MouseMoveCallbackFn = *const fn (*anyopaque, i32, i32) callconv(.C) void;
pub const MouseButtonCallbackFn = *const fn (*anyopaque, u32, bool) callconv(.C) void;
pub const MouseWheelCallbackFn = *const fn (*anyopaque, f32, f32) callconv(.C) void;

// WindowData structure to store window state
const WindowData = struct {
    hwnd: HWND,
    width: i32,
    height: i32,
    position_x: i32,
    position_y: i32,
    content_scale: f32,
    visible: bool,
    focused: bool,
    minimized: bool,
    user_data: ?*anyopaque,
    input_user_data: ?*anyopaque,  // Separate user data for input callbacks
    resize_callback: ?ResizeCallbackFn,
    focus_callback: ?FocusCallbackFn,
    close_callback: ?CloseCallbackFn,
    key_callback: ?KeyCallbackFn,
    mouse_move_callback: ?MouseMoveCallbackFn,
    mouse_button_callback: ?MouseButtonCallbackFn,
    mouse_wheel_callback: ?MouseWheelCallbackFn,
};

// Global state
var window_class_registered = false;
var window_class_name: [32:0]u8 = undefined;
var module_instance: HINSTANCE = undefined;

// Windows message procedure
fn windowProc(hwnd: HWND, msg: UINT, wparam: WPARAM, lparam: LPARAM) callconv(.C) LRESULT {
    // Get the window data pointer from window's user data
    const window_data_ptr = @as(?*WindowData, @ptrFromInt(@as(usize, @intCast(GetWindowLongPtrA(hwnd, GWLP_USERDATA)))));

    switch (msg) {
        WM_CREATE => {
            const create_struct = @as(*CREATESTRUCTA, @ptrCast(@alignCast(@as(*anyopaque, @ptrFromInt(@as(usize, @bitCast(lparam)))))));
            const window_data_ptr2 = @as(*WindowData, @ptrCast(@alignCast(create_struct.lpCreateParams.?)));
            window_data_ptr2.hwnd = hwnd;
            _ = SetWindowLongPtrA(hwnd, GWLP_USERDATA, @as(isize, @bitCast(@intFromPtr(window_data_ptr2))));
            return 0;
        },
        WM_SIZE => {
            if (window_data_ptr) |data| {
                const width = @as(i32, @intCast(lparam & 0xFFFF));
                const height = @as(i32, @intCast((lparam >> 16) & 0xFFFF));
                data.width = width;
                data.height = height;
                data.minimized = IsIconic(hwnd) != 0;

                if (data.resize_callback) |callback| {
                    callback(data.user_data.?, width, height);
                }
            }
            return 0;
        },
        WM_ACTIVATE => {
            const low_word = @as(u16, @truncate(wparam & 0xFFFF));
            const is_active = (low_word == WA_ACTIVE or low_word == WA_CLICKACTIVE);
            
            std.debug.print("[WINDOW] WM_ACTIVATE: is_active={}\n", .{is_active});
            
            if (window_data_ptr) |data| {
                data.focused = is_active;
                if (data.focus_callback) |callback| {
                    callback(data.user_data.?, is_active);
                }
            }
            return 0;
        },
        WM_SETFOCUS => {
            std.debug.print("[WINDOW] Got focus\n", .{});
            if (window_data_ptr) |data| {
                data.focused = true;

                if (data.focus_callback) |callback| {
                    callback(data.user_data.?, true);
                }
            }
            return 0;
        },
        WM_KILLFOCUS => {
            if (window_data_ptr) |data| {
                data.focused = false;

                if (data.focus_callback) |callback| {
                    callback(data.user_data.?, false);
                }
            }
            return 0;
        },
        WM_CLOSE => {
            if (window_data_ptr) |data| {
                var should_close = true;

                if (data.close_callback) |callback| {
                    should_close = callback(data.user_data.?);
                }

                if (should_close) {
                    _ = DestroyWindow(hwnd);
                }
            }
            return 0;
        },
        WM_DESTROY => {
            return 0;
        },
        WM_KEYDOWN, WM_SYSKEYDOWN => {
            std.debug.print("[WINDOW] Key pressed: vk={}\n", .{wparam});
            if (window_data_ptr) |data| {
                if (data.key_callback) |callback| {
                    const vk = @as(u32, @intCast(wparam));
                    callback(data.input_user_data.?, vk, true);
                }
            }
            return 0;
        },
        WM_KEYUP, WM_SYSKEYUP => {
            if (window_data_ptr) |data| {
                if (data.key_callback) |callback| {
                    const vk = @as(u32, @intCast(wparam));
                    callback(data.input_user_data.?, vk, false);
                }
            }
            return 0;
        },
        WM_MOUSEMOVE => {
            if (window_data_ptr) |data| {
                if (data.mouse_move_callback) |callback| {
                    const x = @as(i32, @intCast(lparam & 0xFFFF));
                    const y = @as(i32, @intCast((lparam >> 16) & 0xFFFF));
                    callback(data.input_user_data.?, x, y);
                }
            }
            return 0;
        },
        WM_LBUTTONDOWN => {
            if (window_data_ptr) |data| {
                if (data.mouse_button_callback) |callback| {
                    callback(data.input_user_data.?, 0, true); // 0 = left button
                }
            }
            return 0;
        },
        WM_LBUTTONUP => {
            if (window_data_ptr) |data| {
                if (data.mouse_button_callback) |callback| {
                    callback(data.input_user_data.?, 0, false); // 0 = left button
                }
            }
            return 0;
        },
        WM_RBUTTONDOWN => {
            if (window_data_ptr) |data| {
                if (data.mouse_button_callback) |callback| {
                    callback(data.input_user_data.?, 1, true); // 1 = right button
                }
            }
            return 0;
        },
        WM_RBUTTONUP => {
            if (window_data_ptr) |data| {
                if (data.mouse_button_callback) |callback| {
                    callback(data.input_user_data.?, 1, false); // 1 = right button
                }
            }
            return 0;
        },
        WM_MBUTTONDOWN => {
            if (window_data_ptr) |data| {
                if (data.mouse_button_callback) |callback| {
                    callback(data.input_user_data.?, 2, true); // 2 = middle button
                }
            }
            return 0;
        },
        WM_MBUTTONUP => {
            if (window_data_ptr) |data| {
                if (data.mouse_button_callback) |callback| {
                    callback(data.input_user_data.?, 2, false); // 2 = middle button
                }
            }
            return 0;
        },
        WM_MOUSEWHEEL => {
            if (window_data_ptr) |data| {
                if (data.mouse_wheel_callback) |callback| {
                    const wheel_delta = @as(i16, @truncate(@as(i32, @intCast(wparam >> 16))));
                    const delta = @as(f32, @floatFromInt(wheel_delta)) / 120.0;
                    callback(data.input_user_data.?, 0.0, delta);
                }
            }
            return 0;
        },
        WM_MOUSEHWHEEL => {
            if (window_data_ptr) |data| {
                if (data.mouse_wheel_callback) |callback| {
                    const wheel_delta = @as(i16, @truncate(@as(i32, @intCast(wparam >> 16))));
                    const delta = @as(f32, @floatFromInt(wheel_delta)) / 120.0;
                    callback(data.input_user_data.?, delta, 0.0);
                }
            }
            return 0;
        },
        WM_SYSCOMMAND => {
            // Let Windows handle all system commands (minimize, maximize, restore, etc.)
            return DefWindowProcA(hwnd, msg, wparam, lparam);
        },
        else => {
            return DefWindowProcA(hwnd, msg, wparam, lparam);
        },
    }
}

// Register window class if not already registered
fn ensureWindowClassRegistered() bool {
    if (window_class_registered) {
        return true;
    }

    // Create a class name
    const class_name = "MajorWindowClass";
    for (class_name, 0..) |c, i| {
        window_class_name[i] = c;
    }
    // Ensure null termination
    window_class_name[class_name.len] = 0;

    // Get the application instance
    module_instance = GetModuleHandleA(null);
    if (module_instance == null) {
        return false;
    }

    // Define the window class
    const wc = WNDCLASSEXA{
        .cbSize = @sizeOf(WNDCLASSEXA),
        .style = CS_OWNDC | CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = &windowProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = module_instance,
        .hIcon = null,
        .hCursor = LoadCursorA(null, @ptrFromInt(32512)),  // IDC_ARROW
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = @as([*:0]const u8, @ptrCast(&window_class_name)),
        .hIconSm = null,
    };

    // Register the window class
    const atom = RegisterClassExA(&wc);
    window_class_registered = atom != 0;
    return window_class_registered;
}

// Exported C functions for interfacing with Rust

export fn surface_create(width: i32, height: i32, title: [*:0]const u8) callconv(.C) ?*anyopaque {
    if (!ensureWindowClassRegistered()) {
        return null;
    }

    // Enable high DPI awareness
    _ = SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    // Allocate window data
    const window_data = std.heap.c_allocator.create(WindowData) catch {
        return null;
    };

    // Initialize window data
    window_data.* = WindowData{
        .hwnd = undefined,
        .width = width,
        .height = height,
        .position_x = 0,
        .position_y = 0,
        .content_scale = 1.0,
        .visible = true,
        .focused = false,
        .minimized = false,
        .user_data = null,
        .input_user_data = null,
        .resize_callback = null,
        .focus_callback = null,
        .close_callback = null,
        .key_callback = null,
        .mouse_move_callback = null,
        .mouse_button_callback = null,
        .mouse_wheel_callback = null,
    };

    // Create the window
    const hwnd = CreateWindowExA(
        0,
        @as([*:0]const u8, @ptrCast(&window_class_name)),
        title,
        WS_OVERLAPPEDWINDOW,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        width,
        height,
        null,
        null,
        module_instance,
        window_data,
    );

    if (hwnd == null) {
        std.heap.c_allocator.destroy(window_data);
        return null;
    }

    // Calculate the content scale factor from the DPI
    const dpi = GetDpiForWindow(hwnd);
    window_data.content_scale = @as(f32, @floatFromInt(dpi)) / 96.0;

    // Get the actual client size
    var rect: RECT = undefined;
    _ = GetClientRect(hwnd, &rect);
    window_data.width = rect.right;
    window_data.height = rect.bottom;

    // Get the window position
    _ = GetWindowRect(hwnd, &rect);
    window_data.position_x = rect.left;
    window_data.position_y = rect.top;

    // Adjust window size to ensure client area is the requested size
    var adjust_rect = RECT{
        .left = 0,
        .top = 0,
        .right = width,
        .bottom = height,
    };
    _ = AdjustWindowRectEx(&adjust_rect, WS_OVERLAPPEDWINDOW, @as(BOOL, 0), 0);

    // Resize the window to match the requested client size
    const new_width = adjust_rect.right - adjust_rect.left;
    const new_height = adjust_rect.bottom - adjust_rect.top;
    _ = SetWindowPos(hwnd, null, 0, 0, new_width, new_height, SWP_NOMOVE);

    // Show the window
    _ = ShowWindow(hwnd, SW_SHOW);
    _ = UpdateWindow(hwnd);
    _ = SetForegroundWindow(hwnd);
    _ = SetFocus(hwnd);
    // Don't capture mouse by default - let Windows handle cursor normally

    return window_data;
}

export fn surface_raw(surface: ?*anyopaque) ?*anyopaque {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        return window_data.hwnd;
    }
    return null;
}

export fn surface_destroy(surface: ?*anyopaque) callconv(.C) void {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));

        // Check if the window is still valid
        if (IsWindow(window_data.hwnd) != 0) {
            _ = DestroyWindow(window_data.hwnd);
        }

        // Free window data
        std.heap.c_allocator.destroy(window_data);
    }
}

export fn surface_process_events(_: ?*anyopaque) callconv(.C) void {

    // Process Windows messages
    var msg: MSG = undefined;
    while (PeekMessageA(&msg, null, 0, 0, PM_REMOVE) != 0) {
        _ = TranslateMessage(&msg);
        _ = DispatchMessageA(&msg);
    }
}

export fn surface_width(surface: ?*anyopaque) callconv(.C) i32 {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        return window_data.width;
    }
    return 0;
}

export fn surface_height(surface: ?*anyopaque) callconv(.C) i32 {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        return window_data.height;
    }
    return 0;
}

export fn surface_position_x(surface: ?*anyopaque) callconv(.C) i32 {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        return window_data.position_x;
    }
    return 0;
}

export fn surface_position_y(surface: ?*anyopaque) callconv(.C) i32 {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        return window_data.position_y;
    }
    return 0;
}

export fn surface_content_scale(surface: ?*anyopaque) callconv(.C) f32 {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        return window_data.content_scale;
    }
    return 1.0;
}

export fn surface_resize(surface: ?*anyopaque, width: i32, height: i32) callconv(.C) void {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));

        if (IsWindow(window_data.hwnd) == 0) {
            return;
        }

        // Adjust window size to ensure client area is the requested size
        var rect = RECT{
            .left = 0,
            .top = 0,
            .right = width,
            .bottom = height,
        };
        _ = AdjustWindowRectEx(&rect, WS_OVERLAPPEDWINDOW, @as(BOOL, 0), 0);

        // Get current position
        var current_rect: RECT = undefined;
        _ = GetWindowRect(window_data.hwnd, &current_rect);

        // Resize the window to match the requested client size
        const new_width = rect.right - rect.left;
        const new_height = rect.bottom - rect.top;
        _ = MoveWindow(
            window_data.hwnd,
            current_rect.left,
            current_rect.top,
            new_width,
            new_height,
            @as(BOOL, 1),
        );
    }
}

export fn surface_reposition(surface: ?*anyopaque, x: i32, y: i32) callconv(.C) void {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));

        if (IsWindow(window_data.hwnd) == 0) {
            return;
        }

        // Get current size
        var current_rect: RECT = undefined;
        _ = GetWindowRect(window_data.hwnd, &current_rect);
        const width = current_rect.right - current_rect.left;
        const height = current_rect.bottom - current_rect.top;

        // Move the window
        _ = MoveWindow(window_data.hwnd, x, y, width, height, @as(BOOL, 1));

        // Update stored position
        window_data.position_x = x;
        window_data.position_y = y;
    }
}

export fn surface_title(surface: ?*anyopaque, title: [*:0]const u8) callconv(.C) void {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));

        if (IsWindow(window_data.hwnd) == 0) {
            return;
        }

        _ = SetWindowTextA(window_data.hwnd, title);
    }
}

export fn surface_visibility(surface: ?*anyopaque, visible: bool) callconv(.C) void {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));

        if (IsWindow(window_data.hwnd) == 0) {
            return;
        }

        _ = ShowWindow(window_data.hwnd, if (visible) SW_SHOW else SW_HIDE);
        window_data.visible = visible;
    }
}

export fn surface_focused(surface: ?*anyopaque) callconv(.C) bool {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        return window_data.focused;
    }
    return false;
}

export fn surface_visible(surface: ?*anyopaque) callconv(.C) bool {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));

        if (IsWindow(window_data.hwnd) == 0) {
            return false;
        }

        return IsWindowVisible(window_data.hwnd) != 0;
    }
    return false;
}

export fn surface_minimized(surface: ?*anyopaque) callconv(.C) bool {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));

        if (IsWindow(window_data.hwnd) == 0) {
            return false;
        }

        return IsIconic(window_data.hwnd) != 0;
    }
    return false;
}

export fn surface_on_resize(surface: ?*anyopaque, callback: ResizeCallbackFn) callconv(.C) void {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        window_data.resize_callback = callback;
        window_data.user_data = surface;
    }
}

export fn surface_on_focus(surface: ?*anyopaque, callback: FocusCallbackFn) callconv(.C) void {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        window_data.focus_callback = callback;
        window_data.user_data = surface;
    }
}

export fn surface_on_close(surface: ?*anyopaque, callback: CloseCallbackFn) callconv(.C) void {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        window_data.close_callback = callback;
        window_data.user_data = surface;
    }
}

export fn surface_on_key(surface: ?*anyopaque, callback: KeyCallbackFn) callconv(.C) void {
    std.debug.print("[DEBUG] surface_on_key called with surface: {?}, callback: {?}\n", .{surface, callback});
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        window_data.key_callback = callback;
        std.debug.print("[DEBUG] Set key_callback to {?} on WindowData at {?}\n", .{callback, ptr});
    } else {
        std.debug.print("[DEBUG] surface_on_key: surface is null!\n", .{});
    }
}

export fn surface_on_mouse_move(surface: ?*anyopaque, callback: MouseMoveCallbackFn) callconv(.C) void {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        window_data.mouse_move_callback = callback;
    }
}

export fn surface_on_mouse_button(surface: ?*anyopaque, callback: MouseButtonCallbackFn) callconv(.C) void {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        window_data.mouse_button_callback = callback;
    }
}

export fn surface_on_mouse_wheel(surface: ?*anyopaque, callback: MouseWheelCallbackFn) callconv(.C) void {
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        window_data.mouse_wheel_callback = callback;
    }
}

export fn surface_set_input_user_data(surface: ?*anyopaque, user_data: ?*anyopaque) callconv(.C) void {
    std.debug.print("[DEBUG] surface_set_input_user_data called with surface: {?}, user_data: {?}\n", .{surface, user_data});
    if (surface) |ptr| {
        const window_data = @as(*WindowData, @ptrCast(@alignCast(ptr)));
        window_data.input_user_data = user_data;
        std.debug.print("[DEBUG] Set input_user_data to {?} on WindowData at {?}\n", .{user_data, ptr});
    } else {
        std.debug.print("[DEBUG] surface_set_input_user_data: surface is null!\n", .{});
    }
}
