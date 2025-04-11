use std::os::raw::{c_char, c_uchar};
use std::slice;

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

// Safe wrappers
impl Surface {
    pub fn new() -> Option<*mut Surface> {
        unsafe { createSurface().as_mut().map(|s| s as *mut _) }
    }

    pub fn set_name(&mut self, name: &str) {
        unsafe {
            setName(self, name.as_ptr() as *const c_char, name.len());
        }
    }

    pub fn get_name(&self) -> String {
        unsafe {
            let mut len = 0;
            let ptr = getName(self as *const _ as *mut _, &mut len);
            let slice = slice::from_raw_parts(ptr as *const u8, len);
            String::from_utf8_lossy(slice).into_owned()
        }
    }
}
