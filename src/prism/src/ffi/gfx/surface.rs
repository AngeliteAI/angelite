use core::ffi::{c_char, c_uchar};
use core::slice;

#[repr(C)]
pub struct Surface {
    id: u64,
}

// Surface creation/destruction
#[link(name = "gfx", kind = "static")] // CHANGED to static
unsafe extern "C" {
    pub fn createSurface() -> *mut Surface;
    pub fn destroySurface(s: *mut Surface);
    pub fn supportsMultipleSurfaces() -> bool;

    // Surface updates
    pub fn pollSurface();

    // Surface properties
    pub fn setName(s: *mut Surface, name: *const c_char, len: usize);
    pub fn getName(s: *mut Surface, out_len: *mut usize) -> *const c_char;
    pub fn setSize(s: *mut Surface, width: u32, height: u32);
    pub fn getSize(s: *mut Surface, out_width: *mut u32, out_height: *mut u32);
    pub fn setResizable(s: *mut Surface, resizable: bool);
    pub fn isResizable(s: *mut Surface) -> bool;
    pub fn setFullscreen(s: *mut Surface, fullscreen: bool);
    pub fn isFullscreen(s: *mut Surface) -> bool;
    pub fn setVSync(s: *mut Surface, vsync: bool);
    pub fn isVSync(s: *mut Surface) -> bool;
    pub fn showCursor(s: *mut Surface, show: bool);
    pub fn confineCursor(s: *mut Surface, confine: bool);
}
