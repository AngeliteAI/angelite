//! Minimal Windows API definitions for Vulkan integration
//! This file provides the necessary Windows types and functions
//! without requiring direct inclusion of windows.h

// Basic Windows types
pub const HANDLE = *anyopaque;
pub const HINSTANCE = HANDLE;
pub const HWND = HANDLE;
pub const HMODULE = HANDLE;
pub const HICON = HANDLE;
pub const HCURSOR = HANDLE;
pub const HBRUSH = HANDLE;
pub const HMENU = HANDLE;

pub const LPVOID = ?*anyopaque;
pub const LPCVOID = ?*const anyopaque;

pub const BOOL = i32;
pub const WORD = u16;
pub const DWORD = u32;
pub const UINT = u32;
pub const LONG = i32;
pub const ULONG = u32;
pub const CHAR = u8;
pub const WCHAR = u16;
pub const BYTE = u8;
pub const FLOAT = f32;

pub const WPARAM = usize;
pub const LPARAM = isize;
pub const LRESULT = isize;

pub const INT = i32;
pub const UINT_PTR = usize;

// Function pointer types
pub const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.C) LRESULT;

// Window class styles
pub const CS_VREDRAW = 0x0001;
pub const CS_HREDRAW = 0x0002;
pub const CS_OWNDC = 0x0020;

// Window styles
pub const WS_OVERLAPPED = 0x00000000;
pub const WS_CAPTION = 0x00C00000;
pub const WS_SYSMENU = 0x00080000;
pub const WS_THICKFRAME = 0x00040000;
pub const WS_MINIMIZEBOX = 0x00020000;
pub const WS_MAXIMIZEBOX = 0x00010000;
pub const WS_OVERLAPPEDWINDOW = WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX;

// Window messages
pub const WM_DESTROY = 0x0002;
pub const WM_SIZE = 0x0005;
pub const WM_PAINT = 0x000F;
pub const WM_CLOSE = 0x0010;

// ShowWindow commands
pub const SW_SHOW = 5;
pub const SW_HIDE = 0;

// PeekMessage options
pub const PM_REMOVE = 0x0001;

// SetWindowPos flags
pub const SWP_NOMOVE = 0x0002;
pub const SWP_NOSIZE = 0x0001;
pub const SWP_NOZORDER = 0x0004;
pub const SWP_FRAMECHANGED = 0x0020;

// Window long indexes for GetWindowLong/SetWindowLong
pub const GWL_STYLE = -16;
pub const GWL_EXSTYLE = -20;

// RECT structure
pub const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

// POINT structure
pub const POINT = extern struct {
    x: LONG,
    y: LONG,
};

// MSG structure
pub const MSG = extern struct {
    hwnd: HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    private: DWORD,
};

// WNDCLASSEXW structure
pub const WNDCLASSEXW = extern struct {
    cbSize: UINT,
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: INT,
    cbWndExtra: INT,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const WCHAR,
    lpszClassName: [*:0]const WCHAR,
    hIconSm: ?HICON,
};

// Common Windows functions
pub extern "user32" fn CreateWindowExW(
    dwExStyle: DWORD,
    lpClassName: [*:0]const WCHAR,
    lpWindowName: [*:0]const WCHAR,
    dwStyle: DWORD,
    x: INT,
    y: INT,
    nWidth: INT,
    nHeight: INT,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: HINSTANCE,
    lpParam: ?LPVOID,
) callconv(.C) ?HWND;

pub extern "user32" fn DefWindowProcW(
    hWnd: HWND,
    Msg: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
) callconv(.C) LRESULT;

pub extern "user32" fn RegisterClassExW(
    lpwcx: *const WNDCLASSEXW,
) callconv(.C) WORD;

pub extern "user32" fn ShowWindow(
    hWnd: HWND,
    nCmdShow: INT,
) callconv(.C) BOOL;

pub extern "user32" fn DestroyWindow(
    hWnd: HWND,
) callconv(.C) BOOL;

pub extern "user32" fn PeekMessageW(
    lpMsg: *MSG,
    hWnd: ?HWND,
    wMsgFilterMin: UINT,
    wMsgFilterMax: UINT,
    wRemoveMsg: UINT,
) callconv(.C) BOOL;

pub extern "user32" fn TranslateMessage(
    lpMsg: *const MSG,
) callconv(.C) BOOL;

pub extern "user32" fn DispatchMessageW(
    lpMsg: *const MSG,
) callconv(.C) LRESULT;

pub extern "user32" fn GetClientRect(
    hWnd: HWND,
    lpRect: *RECT,
) callconv(.C) BOOL;

pub extern "user32" fn SetWindowPos(
    hWnd: HWND,
    hWndInsertAfter: ?HWND,
    X: INT,
    Y: INT,
    cx: INT,
    cy: INT,
    uFlags: UINT,
) callconv(.C) BOOL;

pub extern "user32" fn ShowCursor(
    bShow: BOOL,
) callconv(.C) INT;

pub extern "user32" fn ClipCursor(
    lpRect: ?*const RECT,
) callconv(.C) BOOL;

pub extern "user32" fn SetWindowTextW(
    hWnd: HWND,
    lpString: [*:0]const WCHAR,
) callconv(.C) BOOL;

pub extern "user32" fn GetWindowLongW(
    hWnd: HWND,
    nIndex: INT,
) callconv(.C) LONG;

pub extern "user32" fn SetWindowLongW(
    hWnd: HWND,
    nIndex: INT,
    dwNewLong: LONG,
) callconv(.C) LONG;

pub extern "user32" fn GetForegroundWindow() callconv(.C) HWND;

pub extern "user32" fn SetForegroundWindow(
    hWnd: HWND,
) callconv(.C) BOOL;

pub extern "kernel32" fn GetModuleHandleW(
    lpModuleName: ?[*:0]const WCHAR,
) callconv(.C) ?HINSTANCE;
