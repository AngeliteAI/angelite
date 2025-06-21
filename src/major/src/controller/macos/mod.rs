use std::ffi::{CStr, c_char};
use std::os::raw::{c_float, c_int, c_uint};

use crate::engine::{Axis, Button};

// FFI function declarations
unsafe extern "C" {
    fn controller_get_shared_instance() -> *mut std::ffi::c_void;
    fn controller_release_instance(instance: *mut std::ffi::c_void);
    fn controller_set_button_callback(callback: extern "C" fn(c_uint, bool));
    fn controller_set_analog_callback(callback: extern "C" fn(c_uint, c_float, c_float));
    fn controller_start_discovery();
    fn controller_is_button_pressed(button_id: c_uint) -> bool;
    fn controller_get_connected_count() -> c_int;
    fn controller_get_controller_name(index: c_int) -> *mut c_char;
}

pub const BUTTON_A: u32 = 0;
pub const BUTTON_B: u32 = 1;
pub const BUTTON_X: u32 = 2;
pub const BUTTON_Y: u32 = 3;
pub const LEFT_SHOULDER: u32 = 4;
pub const RIGHT_SHOULDER: u32 = 5;
pub const LEFT_TRIGGER: u32 = 6;
pub const RIGHT_TRIGGER: u32 = 7;
pub const DPAD_UP: u32 = 8;
pub const DPAD_DOWN: u32 = 9;
pub const DPAD_LEFT: u32 = 10;
pub const DPAD_RIGHT: u32 = 11;
pub const LEFT_THUMBSTICK: u32 = 12;
pub const RIGHT_THUMBSTICK: u32 = 13;
pub const LEFT_THUMBSTICK_BUTTON: u32 = 14;
pub const RIGHT_THUMBSTICK_BUTTON: u32 = 15;
pub const BUTTON_MENU: u32 = 16;
pub const BUTTON_OPTIONS: u32 = 17;
pub const BUTTON_HOME: u32 = 18;

pub struct Controllers {
    instance: *mut std::ffi::c_void,
}

impl Controllers {
    pub fn new() -> Self {
        let instance = unsafe { controller_get_shared_instance() };
        Controllers { instance }
    }
}

impl Controllers {
    pub fn set_button_callback(&self, callback: extern "C" fn(c_uint, bool)) {
        unsafe { controller_set_button_callback(callback) };
    }

    pub fn set_analog_callback(&self, callback: extern "C" fn(c_uint, c_float, c_float)) {
        unsafe { controller_set_analog_callback(callback) };
    }

    pub fn start_discovery(&self) {
        unsafe { controller_start_discovery() };
    }

    pub fn is_button_pressed(&self, button_id: usize) -> bool {
        unsafe { controller_is_button_pressed(button_id as c_uint) }
    }

    pub fn get_connected_count(&self) -> usize {
        unsafe { controller_get_connected_count() as usize }
    }

    pub fn get_controller_name(&self, index: usize) -> String {
        unsafe {
            let name_ptr = controller_get_controller_name(index as c_int);
            let name = CStr::from_ptr(name_ptr).to_string_lossy().into_owned();
            name
        }
    }
}

pub fn button_binding(button: u32) -> Button {
    match button {
        x if x == BUTTON_A => Button::ButtonA,
        x if x == BUTTON_B => Button::ButtonB,
        x if x == BUTTON_X => Button::ButtonX,
        x if x == BUTTON_Y => Button::ButtonY,
        x if x == BUTTON_MENU => Button::ButtonMenu,
        _ => todo!(),
    }
}

pub fn axis_binding(axis: u32) -> Axis {
    match axis {
        x if x == LEFT_THUMBSTICK => Axis::LeftJoystick,
        _ => todo!(),
    }
}

impl Drop for Controllers {
    fn drop(&mut self) {
        unsafe { controller_release_instance(self.instance) };
    }
}
