use std::os::raw::c_void;
use std::os::raw::c_char;
use crate::ffi::input::state::{Key, MouseButton, GamepadButton, Axis, Side, ButtonAction, Action};

#[repr(C)]
pub struct ActionId(pub u32);

impl ActionId {
    pub fn new(id: u32) -> Self {
        ActionId(id)
    }
    
    pub fn value(&self) -> u32 {
        self.0
    }
}

#[repr(C)]
pub struct ActionManager {
    ptr: *mut c_void,
}

#[link(name = "input", kind = "static")]
extern "C" {
    // ActionManager functions
    pub fn createActionManager() -> *mut c_void;
    pub fn destroyActionManager(manager: *mut c_void);
    pub fn createAction(manager: *mut c_void, name: *const c_char, name_len: usize) -> ActionId;
    pub fn getAction(manager: *mut c_void, id: ActionId) -> *mut c_void;
    pub fn deleteAction(manager: *mut c_void, id: ActionId);
    pub fn registerAllActions(manager: *mut c_void);
    
    // Action functions
    pub fn setActionUserData(action: *mut c_void, user_data: *mut c_void);
    pub fn addKeyboardBinding(action: *mut c_void, key: Key, action_type: ButtonAction) -> bool;
    pub fn addMouseButtonBinding(action: *mut c_void, button: MouseButton, action_type: ButtonAction) -> bool;
    pub fn addGamepadButtonBinding(action: *mut c_void, button: GamepadButton, action_type: ButtonAction) -> bool;
    pub fn addMouseAxisBinding(action: *mut c_void, axis: Axis, threshold: f32) -> bool;
    pub fn addJoystickBinding(action: *mut c_void, axis: Axis, side: Side, threshold: f32) -> bool;
    pub fn addTriggerBinding(action: *mut c_void, side: Side, threshold: f32) -> bool;
    pub fn addScrollBinding(action: *mut c_void, axis: Axis, threshold: f32) -> bool;
}

// Safe wrapper for ActionManager
impl ActionManager {
    pub fn new() -> Option<Self> {
        let ptr = unsafe { createActionManager() };
        if ptr.is_null() {
            None
        } else {
            Some(ActionManager { ptr })
        }
    }
    
    pub fn create_action(&self, name: &str) -> Result<ActionId, &'static str> {
        let id = unsafe { 
            createAction(
                self.ptr, 
                name.as_ptr() as *const c_char, 
                name.len()
            )
        };
        Ok(id)
    }
    
    pub fn get_action(&self, id: ActionId) -> Option<InputAction> {
        let action_ptr = unsafe { getAction(self.ptr, id) };
        if action_ptr.is_null() {
            None
        } else {
            Some(InputAction { ptr: action_ptr })
        }
    }
    
    pub fn delete_action(&self, id: ActionId) {
        unsafe { deleteAction(self.ptr, id) };
    }
    
    pub fn register_all_actions(&self) {
        unsafe { registerAllActions(self.ptr) };
    }
}

impl Drop for ActionManager {
    fn drop(&mut self) {
        unsafe { destroyActionManager(self.ptr) };
    }
}

// Safe wrapper for InputAction
pub struct InputAction {
    ptr: *mut c_void,
}

impl InputAction {
    pub fn set_user_data(&self, user_data: *mut c_void) {
        unsafe { setActionUserData(self.ptr, user_data) };
    }
    
    pub fn add_keyboard_binding(&self, key: Key, action_type: ButtonAction) -> Result<(), &'static str> {
        let success = unsafe { addKeyboardBinding(self.ptr, key, action_type) };
        if success {
            Ok(())
        } else {
            Err("Failed to add keyboard binding")
        }
    }
    
    pub fn add_mouse_button_binding(&self, button: MouseButton, action_type: ButtonAction) -> Result<(), &'static str> {
        let success = unsafe { addMouseButtonBinding(self.ptr, button, action_type) };
        if success {
            Ok(())
        } else {
            Err("Failed to add mouse button binding")
        }
    }
    
    pub fn add_gamepad_button_binding(&self, button: GamepadButton, action_type: ButtonAction) -> Result<(), &'static str> {
        let success = unsafe { addGamepadButtonBinding(self.ptr, button, action_type) };
        if success {
            Ok(())
        } else {
            Err("Failed to add gamepad button binding")
        }
    }
    
    pub fn add_mouse_axis_binding(&self, axis: Axis, threshold: f32) -> Result<(), &'static str> {
        let success = unsafe { addMouseAxisBinding(self.ptr, axis, threshold) };
        if success {
            Ok(())
        } else {
            Err("Failed to add mouse axis binding")
        }
    }
    
    pub fn add_joystick_binding(&self, axis: Axis, side: Side, threshold: f32) -> Result<(), &'static str> {
        let success = unsafe { addJoystickBinding(self.ptr, axis, side, threshold) };
        if success {
            Ok(())
        } else {
            Err("Failed to add joystick binding")
        }
    }
    
    pub fn add_trigger_binding(&self, side: Side, threshold: f32) -> Result<(), &'static str> {
        let success = unsafe { addTriggerBinding(self.ptr, side, threshold) };
        if success {
            Ok(())
        } else {
            Err("Failed to add trigger binding")
        }
    }
    
    pub fn add_scroll_binding(&self, axis: Axis, threshold: f32) -> Result<(), &'static str> {
        let success = unsafe { addScrollBinding(self.ptr, axis, threshold) };
        if success {
            Ok(())
        } else {
            Err("Failed to add scroll binding")
        }
    }
}