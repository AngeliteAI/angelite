// Windows API bindings for Zig

// Basic types
pub const HWND = *opaque {};
pub const HINSTANCE = *opaque {};
pub const HMENU = *opaque {};
pub const HICON = *opaque {};
pub const HCURSOR = *opaque {};
pub const HBRUSH = *opaque {};

pub const UINT = c_uint;
pub const WPARAM = usize;
pub const LPARAM = isize;
pub const LRESULT = isize;
pub const DWORD = c_ulong;
pub const BOOL = c_int;
pub const LONG = c_long;
pub const ATOM = u16;

// Structs
pub const RECT = extern struct {
    left: c_long,
    top: c_long,
    right: c_long,
    bottom: c_long,
};

pub const POINT = extern struct {
    x: LONG,
    y: LONG,
};

pub const MSG = extern struct {
    hwnd: ?HWND,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM,
    time: DWORD,
    pt: POINT,
    lPrivate: DWORD,
};

pub const WNDPROC = *const fn (HWND, UINT, WPARAM, LPARAM) callconv(.C) LRESULT;

pub const WNDCLASSEXW = extern struct {
    cbSize: UINT,
    style: UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: c_int,
    cbWndExtra: c_int,
    hInstance: HINSTANCE,
    hIcon: ?HICON,
    hCursor: ?HCURSOR,
    hbrBackground: ?HBRUSH,
    lpszMenuName: ?[*:0]const u16,
    lpszClassName: [*:0]const u16,
    hIconSm: ?HICON,
};

// Constants
pub const WS_OVERLAPPEDWINDOW = 0x00CF0000;
pub const WS_THICKFRAME = 0x00040000;
pub const WS_MAXIMIZEBOX = 0x00010000;

// Window messages
pub const WM_DESTROY = 0x0002;
pub const WM_KEYDOWN = 0x0100;
pub const WM_KEYUP = 0x0101;
pub const WM_MOUSEMOVE = 0x0200;
pub const WM_LBUTTONDOWN = 0x0201;
pub const WM_LBUTTONUP = 0x0202;
pub const WM_RBUTTONDOWN = 0x0204;
pub const WM_RBUTTONUP = 0x0205;
pub const WM_MBUTTONDOWN = 0x0207;
pub const WM_MBUTTONUP = 0x0208;

pub const SW_SHOW = 5;
pub const GWL_STYLE = -16;
pub const SWP_NOMOVE = 0x0002;
pub const SWP_NOSIZE = 0x0001;
pub const SWP_NOZORDER = 0x0004;
pub const SWP_FRAMECHANGED = 0x0020;
pub const PM_REMOVE = 0x0001;

// XInput constants and structures
pub const XINPUT_MAX_CONTROLLERS = 4;

// XInput controller state
pub const XINPUT_GAMEPAD = extern struct {
    wButtons: u16,
    bLeftTrigger: u8,
    bRightTrigger: u8,
    sThumbLX: i16,
    sThumbLY: i16,
    sThumbRX: i16,
    sThumbRY: i16,
    dwReserved: u32,
};

pub const XINPUT_STATE = extern struct {
    dwPacketNumber: u32,
    Gamepad: XINPUT_GAMEPAD,
};

// XInput button constants
pub const XINPUT_GAMEPAD_DPAD_UP = 0x0001;
pub const XINPUT_GAMEPAD_DPAD_DOWN = 0x0002;
pub const XINPUT_GAMEPAD_DPAD_LEFT = 0x0004;
pub const XINPUT_GAMEPAD_DPAD_RIGHT = 0x0008;
pub const XINPUT_GAMEPAD_START = 0x0010;
pub const XINPUT_GAMEPAD_BACK = 0x0020;
pub const XINPUT_GAMEPAD_LEFT_THUMB = 0x0040;
pub const XINPUT_GAMEPAD_RIGHT_THUMB = 0x0080;
pub const XINPUT_GAMEPAD_LEFT_SHOULDER = 0x0100;
pub const XINPUT_GAMEPAD_RIGHT_SHOULDER = 0x0200;
pub const XINPUT_GAMEPAD_A = 0x1000;
pub const XINPUT_GAMEPAD_B = 0x2000;
pub const XINPUT_GAMEPAD_X = 0x4000;
pub const XINPUT_GAMEPAD_Y = 0x8000;

// XInput function declarations
pub extern "xinput1_4" fn XInputGetState(dwUserIndex: u32, pState: *XINPUT_STATE) u32;

// Function declarations
pub extern "user32" fn CreateWindowExW(
    dwExStyle: DWORD,
    lpClassName: [*:0]const u16,
    lpWindowName: [*:0]const u16,
    dwStyle: DWORD,
    x: c_int,
    y: c_int,
    nWidth: c_int,
    nHeight: c_int,
    hWndParent: ?HWND,
    hMenu: ?HMENU,
    hInstance: HINSTANCE,
    lpParam: ?*anyopaque,
) ?HWND;

pub extern "user32" fn DestroyWindow(hWnd: HWND) BOOL;
pub extern "user32" fn ShowWindow(hWnd: HWND, nCmdShow: c_int) BOOL;
pub extern "user32" fn GetClientRect(hWnd: HWND, lpRect: *RECT) BOOL;
pub extern "user32" fn SetWindowTextW(hWnd: HWND, lpString: [*:0]const u16) BOOL;
pub extern "user32" fn GetWindowTextW(hWnd: HWND, lpString: [*]u16, nMaxCount: c_int) c_int;
pub extern "user32" fn ShowCursor(bShow: BOOL) c_int;
pub extern "user32" fn ClipCursor(lpRect: ?*const RECT) BOOL;
pub extern "user32" fn SetForegroundWindow(hWnd: HWND) BOOL;
pub extern "user32" fn GetForegroundWindow() ?HWND;
pub extern "user32" fn PeekMessageW(lpMsg: *MSG, hWnd: ?HWND, wMsgFilterMin: UINT, wMsgFilterMax: UINT, wRemoveMsg: UINT) BOOL;
pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) BOOL;
pub extern "user32" fn DispatchMessageW(lpMsg: *const MSG) LRESULT;
pub extern "user32" fn DefWindowProcW(hWnd: HWND, Msg: UINT, wParam: WPARAM, lParam: LPARAM) LRESULT;
pub extern "user32" fn RegisterClassExW(lpwcx: *const WNDCLASSEXW) ATOM;
pub extern "user32" fn GetWindowLongW(hWnd: HWND, nIndex: c_int) LONG;
pub extern "user32" fn SetWindowLongW(hWnd: HWND, nIndex: c_int, dwNewLong: LONG) LONG;
pub extern "user32" fn SetWindowPos(
    hWnd: HWND,
    hWndInsertAfter: ?HWND,
    X: c_int,
    Y: c_int,
    cx: c_int,
    cy: c_int,
    uFlags: UINT,
) BOOL;

pub extern "kernel32" fn GetModuleHandleW(lpModuleName: ?[*:0]const u16) ?HINSTANCE;
