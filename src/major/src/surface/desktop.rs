use std::ffi::{c_char, c_float, c_int, c_void};
use std::sync::{Arc, Mutex};

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
    fn surface_on_key(surface: *mut c_void, callback: extern "C" fn(*mut c_void, u32, bool));
    fn surface_on_mouse_move(surface: *mut c_void, callback: extern "C" fn(*mut c_void, c_int, c_int));
    fn surface_on_mouse_button(surface: *mut c_void, callback: extern "C" fn(*mut c_void, u32, bool));
    fn surface_on_mouse_wheel(surface: *mut c_void, callback: extern "C" fn(*mut c_void, c_float, c_float));
    
    fn surface_set_input_user_data(surface: *mut c_void, user_data: *mut c_void);

    fn surface_raw(surface: *mut c_void) -> *mut c_void;
}

pub struct Desktop {
    surface: *mut c_void,
    input_system: Option<*mut c_void>,
}

impl Surface for Desktop {
    fn poll(&self) {
        unsafe { surface_process_events(self.surface) };
    }

    fn raw(&self) -> *mut c_void {
        unsafe { surface_raw(self.surface) as *mut c_void }
    }
}

impl Desktop {
    pub fn open() -> Self {
        let surface = unsafe { surface_create(800, 600, b"Major\0".as_ptr() as *const _) };
        Desktop { 
            surface,
            input_system: None,
        }
    }
    
    pub fn setup_input_callbacks(
        &mut self,
        input_system: *mut c_void,
        key_cb: extern "C" fn(*mut c_void, u32, bool),
        mouse_move_cb: extern "C" fn(*mut c_void, c_int, c_int),
        mouse_button_cb: extern "C" fn(*mut c_void, u32, bool),
        mouse_wheel_cb: extern "C" fn(*mut c_void, c_float, c_float),
    ) {
        println!("[DEBUG] Desktop::setup_input_callbacks called");
        println!("[DEBUG]   input_system: {:?}", input_system);
        println!("[DEBUG]   key_cb: {:?}", key_cb as *const ());
        println!("[DEBUG]   self.surface: {:?}", self.surface);
        
        self.input_system = Some(input_system);
        unsafe {
            surface_set_input_user_data(self.surface, input_system);
            surface_on_key(self.surface, key_cb);
            surface_on_mouse_move(self.surface, mouse_move_cb);
            surface_on_mouse_button(self.surface, mouse_button_cb);
            surface_on_mouse_wheel(self.surface, mouse_wheel_cb);
        }
        
        println!("[DEBUG] Desktop::setup_input_callbacks completed");
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
