use std::ffi::{c_char, c_float, c_int, c_void};

use crate::engine::Surface;

unsafe extern "C" {

    fn surface_create(width: c_int, height: c_int, title: *const c_char) -> *mut c_void;
    fn surface_destroy(surface: *mut c_void);
    fn surface_process_events(surface: *mut c_void);

    fn surface_width(surface: *mut c_void) -> c_int;
    fn surface_height(surface: *mut c_void) -> c_int;
    fn surface_position_x(surface: *mut c_void) -> c_int;
    fn surface_position_y(surface: *mut c_void) -> c_int;
    fn surface_content_scale(surface: *mut c_void) -> c_float;

    fn surface_resize(surface: *mut c_void, width: c_int, height: c_int);
    fn surface_reposition(surface: *mut c_void, x: c_int, y: c_int);
    fn surface_title(surface: *mut c_void, title: *const c_char);
    fn surface_visibility(surface: *mut c_void, visible: bool);

    fn surface_focused(surface: *mut c_void) -> bool;
    fn surface_visible(surface: *mut c_void) -> bool;
    fn surface_minimized(surface: *mut c_void) -> bool;

    fn surface_on_resize(surface: *mut c_void, callback: extern "C" fn(*mut c_void, c_int, c_int));
    fn surface_on_focus(surface: *mut c_void, callback: extern "C" fn(*mut c_void, bool));
    fn surface_on_close(surface: *mut c_void, callback: extern "C" fn(*mut c_void) -> bool);

}

pub struct Desktop {
    surface: *mut c_void,
}

impl Surface for Desktop {
    fn poll(&self) {
        unsafe { surface_process_events(self.surface) };
    }

    fn raw(&self) -> *mut c_void {
        return self.surface as *mut c_void;
    }
}

impl Desktop {
    pub fn open() -> Self {
        let surface = unsafe { surface_create(800, 600, b"Major\0".as_ptr() as *const _) };
        Desktop { surface }
    }

    pub fn close(&self) {
        unsafe { surface_destroy(self.surface) };
    }

    pub fn position(&self) -> (c_int, c_int) {
        let x = unsafe { surface_position_x(self.surface) };
        let y = unsafe { surface_position_y(self.surface) };
        (x, y)
    }

    pub fn size(&self) -> (c_int, c_int) {
        let width = unsafe { surface_width(self.surface) };
        let height = unsafe { surface_height(self.surface) };
        (width, height)
    }

    pub fn content_scale(&self) -> c_float {
        unsafe { surface_content_scale(self.surface) }
    }

    pub fn move_to(&self, x: c_int, y: c_int) {
        unsafe { surface_reposition(self.surface, x, y) };
    }

    pub fn resize(&self, width: c_int, height: c_int) {
        unsafe { surface_resize(self.surface, width, height) };
    }

    pub fn move_and_resize(&self, x: c_int, y: c_int, width: c_int, height: c_int) {
        self.move_to(x, y);
        self.resize(width, height);
    }

    pub fn is_focused(&self) -> bool {
        unsafe { surface_focused(self.surface) }
    }

    pub fn is_minimized(&self) -> bool {
        unsafe { surface_minimized(self.surface) }
    }
}
