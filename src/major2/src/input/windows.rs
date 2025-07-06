use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::ffi::c_void;
use std::mem;
use std::ptr;

use crate::engine::{Button, Axis, Binding, Data};
use crate::input::{ButtonState, AxisState, InputHandler};

// Virtual key code mappings
const VK_ESCAPE: u32 = 0x1B;
const VK_SPACE: u32 = 0x20;
const VK_RETURN: u32 = 0x0D;
const VK_W: u32 = 0x57;
const VK_A: u32 = 0x41;
const VK_S: u32 = 0x53;
const VK_D: u32 = 0x44;
const VK_Q: u32 = 0x51;
const VK_E: u32 = 0x45;
const VK_SHIFT: u32 = 0x10;
const VK_CONTROL: u32 = 0x11;
const VK_TAB: u32 = 0x09;
const VK_I: u32 = 0x49;
const VK_F: u32 = 0x46;
const VK_G: u32 = 0x47;

// Mouse button constants
const MOUSE_LEFT: u32 = 0;
const MOUSE_RIGHT: u32 = 1;
const MOUSE_MIDDLE: u32 = 2;

// XInput constants
const XINPUT_GAMEPAD_DPAD_UP: u16 = 0x0001;
const XINPUT_GAMEPAD_DPAD_DOWN: u16 = 0x0002;
const XINPUT_GAMEPAD_DPAD_LEFT: u16 = 0x0004;
const XINPUT_GAMEPAD_DPAD_RIGHT: u16 = 0x0008;
const XINPUT_GAMEPAD_START: u16 = 0x0010;
const XINPUT_GAMEPAD_BACK: u16 = 0x0020;
const XINPUT_GAMEPAD_LEFT_THUMB: u16 = 0x0040;
const XINPUT_GAMEPAD_RIGHT_THUMB: u16 = 0x0080;
const XINPUT_GAMEPAD_LEFT_SHOULDER: u16 = 0x0100;
const XINPUT_GAMEPAD_RIGHT_SHOULDER: u16 = 0x0200;
const XINPUT_GAMEPAD_A: u16 = 0x1000;
const XINPUT_GAMEPAD_B: u16 = 0x2000;
const XINPUT_GAMEPAD_X: u16 = 0x4000;
const XINPUT_GAMEPAD_Y: u16 = 0x8000;

const XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE: i16 = 7849;
const XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE: i16 = 8689;
const XINPUT_GAMEPAD_TRIGGER_THRESHOLD: u8 = 30;

#[repr(C)]
#[derive(Copy, Clone)]
struct XInputGamepad {
    buttons: u16,
    left_trigger: u8,
    right_trigger: u8,
    thumb_lx: i16,
    thumb_ly: i16,
    thumb_rx: i16,
    thumb_ry: i16,
}

#[repr(C)]
#[derive(Copy, Clone)]
struct XInputState {
    packet_number: u32,
    gamepad: XInputGamepad,
}

#[repr(C)]
#[derive(Copy, Clone)]
struct XInputVibration {
    left_motor_speed: u16,
    right_motor_speed: u16,
}

type XInputGetState = unsafe extern "system" fn(u32, *mut XInputState) -> u32;
type XInputSetState = unsafe extern "system" fn(u32, *mut XInputVibration) -> u32;

struct XInput {
    get_state: Option<XInputGetState>,
    set_state: Option<XInputSetState>,
    loaded: bool,
}

impl XInput {
    fn new() -> Self {
        let mut xinput = Self {
            get_state: None,
            set_state: None,
            loaded: false,
        };
        xinput.load();
        xinput
    }
    
    fn load(&mut self) {
        unsafe {
            // Try to load XInput 1.4 first (Windows 8+)
            let lib = LoadLibraryA(b"xinput1_4.dll\0".as_ptr() as *const i8);
            let lib = if lib.is_null() {
                // Fall back to XInput 1.3 (Windows 7)
                LoadLibraryA(b"xinput1_3.dll\0".as_ptr() as *const i8)
            } else {
                lib
            };
            
            if !lib.is_null() {
                self.get_state = mem::transmute(GetProcAddress(lib, b"XInputGetState\0".as_ptr() as *const i8));
                self.set_state = mem::transmute(GetProcAddress(lib, b"XInputSetState\0".as_ptr() as *const i8));
                self.loaded = self.get_state.is_some() && self.set_state.is_some();
                
                if self.loaded {
                    println!("[DEBUG] XInput loaded successfully");
                }
            }
        }
    }
    
    fn get_controller_state(&self, index: u32) -> Option<XInputState> {
        if let Some(get_state) = self.get_state {
            let mut state = unsafe { mem::zeroed() };
            let result = unsafe { get_state(index, &mut state) };
            if result == 0 { // ERROR_SUCCESS
                Some(state)
            } else {
                None
            }
        } else {
            None
        }
    }
    
    fn set_vibration(&self, index: u32, left_motor: u16, right_motor: u16) -> bool {
        if let Some(set_state) = self.set_state {
            let mut vibration = XInputVibration {
                left_motor_speed: left_motor,
                right_motor_speed: right_motor,
            };
            let result = unsafe { set_state(index, &mut vibration) };
            result == 0 // ERROR_SUCCESS
        } else {
            false
        }
    }
}

// Windows API functions for XInput
unsafe extern "system" {
    fn LoadLibraryA(filename: *const i8) -> *mut c_void;
    fn GetProcAddress(module: *mut c_void, proc_name: *const i8) -> *mut c_void;
}

pub struct InputState {
    buttons: HashMap<Button, ButtonState>,
    axes: HashMap<Axis, AxisState>,
    bindings: HashMap<Binding, Vec<Button>>,
    axis_bindings: HashMap<Binding, Axis>,
    
    // Raw input state
    key_states: HashMap<u32, bool>,
    mouse_position: (i32, i32),
    mouse_delta: (f32, f32),
    last_mouse_position: Option<(i32, i32)>,
    window_size: (i32, i32),
    
    // Controller state
    xinput: XInput,
    last_gamepad_state: Option<XInputGamepad>,
}

impl InputState {
    pub fn new() -> Self {
        let mut bindings = HashMap::new();
        let mut axis_bindings = HashMap::new();
        
        // Space Engineers-style bindings
        bindings.insert(Binding::Select, vec![Button::ButtonA, Button::KeyEnter]);
        bindings.insert(Binding::Escape, vec![Button::ButtonMenu, Button::ButtonB, Button::KeyEscape]);
        bindings.insert(Binding::Jump, vec![Button::ButtonA, Button::KeySpace]);  // A button or Space for jump/jetpack
        bindings.insert(Binding::Sprint, vec![Button::ButtonLTrigger, Button::KeyShift]);  // Left trigger or Shift for sprint
        bindings.insert(Binding::Use, vec![Button::ButtonX, Button::KeyF, Button::MouseLeft]);  // X button, F or left click for use/interact
        bindings.insert(Binding::Build, vec![Button::ButtonB, Button::KeyG, Button::MouseRight]);  // B button, G or right click for build mode
        bindings.insert(Binding::Crouch, vec![Button::ButtonRJoystick, Button::KeyControl]);  // Right stick click or Ctrl for crouch
        bindings.insert(Binding::Inventory, vec![Button::ButtonY, Button::KeyI, Button::KeyTab]);  // Y button, I or Tab for inventory
        
        // D-pad can be used for UI navigation or quick slots
        // These bindings can be customized based on game needs
        
        axis_bindings.insert(Binding::MoveHorizontal, Axis::LeftJoystick);
        axis_bindings.insert(Binding::MoveVertical, Axis::LeftJoystick);
        axis_bindings.insert(Binding::Cursor, Axis::Mouse);
        axis_bindings.insert(Binding::LookHorizontal, Axis::RightJoystick);
        axis_bindings.insert(Binding::LookVertical, Axis::RightJoystick);
        axis_bindings.insert(Binding::Zoom, Axis::MouseWheel);
        
        Self {
            buttons: HashMap::new(),
            axes: HashMap::new(),
            bindings,
            axis_bindings,
            key_states: HashMap::new(),
            mouse_position: (0, 0),
            mouse_delta: (0.0, 0.0),
            last_mouse_position: None,
            window_size: (800, 600),
            xinput: XInput::new(),
            last_gamepad_state: None,
        }
    }
    
    pub fn update(&mut self) {
        // Update button states (pressed -> held)
        for (_, state) in self.buttons.iter_mut() {
            if *state == ButtonState::Pressed {
                *state = ButtonState::Held;
            }
        }
        
        // Reset mouse delta and wheel
        self.mouse_delta = (0.0, 0.0);
        
        // Reset mouse wheel after processing
        if let Some(wheel) = self.axes.get_mut(&Axis::MouseWheel) {
            wheel.x = 0.0;
            wheel.y = 0.0;
        }
        
        // Update controller state
        self.update_controller();
    }
    
    pub fn handle_key(&mut self, vk: u32, pressed: bool) {
        println!("[DEBUG] InputState::handle_key: vk={}, pressed={}", vk, pressed);
        self.key_states.insert(vk, pressed);
        
        // Map virtual key to button
        let button = match vk {
            VK_W => Some(Button::KeyW),
            VK_A => Some(Button::KeyA),
            VK_S => Some(Button::KeyS),
            VK_D => Some(Button::KeyD),
            VK_Q => Some(Button::KeyQ),
            VK_E => Some(Button::KeyE),
            VK_SPACE => Some(Button::KeySpace),
            VK_RETURN => Some(Button::KeyEnter),
            VK_ESCAPE => Some(Button::KeyEscape),
            VK_SHIFT => Some(Button::KeyShift),
            VK_CONTROL => Some(Button::KeyControl),
            VK_TAB => Some(Button::KeyTab),
            VK_I => Some(Button::KeyI),
            VK_F => Some(Button::KeyF),
            VK_G => Some(Button::KeyG),
            _ => None,
        };
        
        if let Some(button) = button {
            println!("[DEBUG] Mapped vk {} to button {:?}", vk, button);
            let state = if pressed {
                match self.buttons.get(&button) {
                    Some(ButtonState::Pressed) | Some(ButtonState::Held) => ButtonState::Held,
                    _ => ButtonState::Pressed,
                }
            } else {
                ButtonState::Released
            };
            println!("[DEBUG] Setting button {:?} to state {:?}", button, state);
            self.buttons.insert(button, state);
        } else {
            println!("[DEBUG] No button mapping for vk {}", vk);
        }
        
        // Update movement axes from keyboard
        self.update_keyboard_axes();
    }
    
    pub fn handle_mouse_move(&mut self, x: i32, y: i32) {
        let new_pos = (x, y);
        
        if let Some(last_pos) = self.last_mouse_position {
            self.mouse_delta.0 += (x - last_pos.0) as f32;
            self.mouse_delta.1 += (y - last_pos.1) as f32;
        }
        
        self.mouse_position = new_pos;
        self.last_mouse_position = Some(new_pos);
        
        // Update mouse axis
        let mouse_axis = self.axes.entry(Axis::Mouse).or_default();
        mouse_axis.x = x as f32 / self.window_size.0 as f32;
        mouse_axis.y = y as f32 / self.window_size.1 as f32;
    }
    
    pub fn handle_mouse_button(&mut self, button: u32, pressed: bool) {
        println!("[DEBUG] Mouse button {} {}", button, if pressed { "pressed" } else { "released" });
        
        let game_button = match button {
            MOUSE_LEFT => Some(Button::MouseLeft),
            MOUSE_RIGHT => Some(Button::MouseRight),
            MOUSE_MIDDLE => Some(Button::MouseMiddle),
            _ => None,
        };
        
        if let Some(button) = game_button {
            let state = if pressed {
                match self.buttons.get(&button) {
                    Some(ButtonState::Pressed) | Some(ButtonState::Held) => ButtonState::Held,
                    _ => ButtonState::Pressed,
                }
            } else {
                ButtonState::Released
            };
            self.buttons.insert(button, state);
        }
    }
    
    pub fn handle_mouse_wheel(&mut self, x: f32, y: f32) {
        println!("[DEBUG] Mouse wheel: x={}, y={}", x, y);
        
        // Store mouse wheel state for zoom
        let wheel_axis = self.axes.entry(Axis::MouseWheel).or_default();
        wheel_axis.x = x;
        wheel_axis.y = y;
    }
    
    pub fn set_window_size(&mut self, width: i32, height: i32) {
        self.window_size = (width, height);
    }
    
    fn update_keyboard_axes(&mut self) {
        // WASD movement
        let left = self.key_states.get(&VK_A).copied().unwrap_or(false);
        let right = self.key_states.get(&VK_D).copied().unwrap_or(false);
        let up = self.key_states.get(&VK_W).copied().unwrap_or(false);
        let down = self.key_states.get(&VK_S).copied().unwrap_or(false);
        
        let x: f32 = if right { 1.0 } else { 0.0 } - if left { 1.0 } else { 0.0 };
        let y: f32 = if down { 1.0 } else { 0.0 } - if up { 1.0 } else { 0.0 };

        // Normalize diagonal movement
        let (x, y) = if x != 0.0 && y != 0.0 {
            let len = (x * x + y * y).sqrt();
            (x / len, y / len)
        } else {
            (x, y)
        };
        
        let left_stick = self.axes.entry(Axis::LeftJoystick).or_default();
        left_stick.x = x;
        left_stick.y = y;
    }
    
    fn update_controller(&mut self) {
        if !self.xinput.loaded {
            return;
        }
        
        // Poll controller 0 (first controller)
        if let Some(state) = self.xinput.get_controller_state(0) {
            let gamepad = &state.gamepad;
            
            // Update button states
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_A, Button::ButtonA);
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_B, Button::ButtonB);
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_X, Button::ButtonX);
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_Y, Button::ButtonY);
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_LEFT_SHOULDER, Button::ButtonLShoulder);
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_RIGHT_SHOULDER, Button::ButtonRShoulder);
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_LEFT_THUMB, Button::ButtonLJoystick);
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_RIGHT_THUMB, Button::ButtonRJoystick);
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_START, Button::ButtonMenu);
            
            // Update D-pad buttons
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_DPAD_UP, Button::DPadUp);
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_DPAD_DOWN, Button::DPadDown);
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_DPAD_LEFT, Button::DPadLeft);
            self.update_gamepad_button(gamepad, XINPUT_GAMEPAD_DPAD_RIGHT, Button::DPadRight);
            
            // Update trigger buttons based on analog values (for Space Engineers)
            let left_trigger_pressed = gamepad.left_trigger > XINPUT_GAMEPAD_TRIGGER_THRESHOLD;
            let right_trigger_pressed = gamepad.right_trigger > XINPUT_GAMEPAD_TRIGGER_THRESHOLD;
            
            // In Space Engineers, triggers are analog but we treat them as buttons for sprint/etc
            if left_trigger_pressed != self.is_button_held(Button::ButtonLTrigger) {
                self.set_button_state(Button::ButtonLTrigger, left_trigger_pressed);
            }
            if right_trigger_pressed != self.is_button_held(Button::ButtonRTrigger) {
                self.set_button_state(Button::ButtonRTrigger, right_trigger_pressed);
            }
            
            // Update analog sticks with deadzone
            let left_x = Self::apply_deadzone(gamepad.thumb_lx, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE);
            let left_y = Self::apply_deadzone(gamepad.thumb_ly, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE);
            let right_x = Self::apply_deadzone(gamepad.thumb_rx, XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE);
            let right_y = Self::apply_deadzone(gamepad.thumb_ry, XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE);
            
            // Set axis states (Y axis inverted for standard game controls)
            self.set_axis_state(Axis::LeftJoystick, left_x, -left_y);
            self.set_axis_state(Axis::RightJoystick, right_x, -right_y);
            
            self.last_gamepad_state = Some(*gamepad);
        } else {
            // Controller disconnected, clear gamepad state
            if self.last_gamepad_state.is_some() {
                self.last_gamepad_state = None;
                
                // Clear all gamepad buttons
                self.set_button_state(Button::ButtonA, false);
                self.set_button_state(Button::ButtonB, false);
                self.set_button_state(Button::ButtonX, false);
                self.set_button_state(Button::ButtonY, false);
                self.set_button_state(Button::ButtonLTrigger, false);
                self.set_button_state(Button::ButtonRTrigger, false);
                self.set_button_state(Button::ButtonLShoulder, false);
                self.set_button_state(Button::ButtonRShoulder, false);
                self.set_button_state(Button::ButtonLJoystick, false);
                self.set_button_state(Button::ButtonRJoystick, false);
                self.set_button_state(Button::ButtonMenu, false);
                self.set_button_state(Button::DPadUp, false);
                self.set_button_state(Button::DPadDown, false);
                self.set_button_state(Button::DPadLeft, false);
                self.set_button_state(Button::DPadRight, false);
                
                // Clear analog sticks
                self.set_axis_state(Axis::LeftJoystick, 0.0, 0.0);
                self.set_axis_state(Axis::RightJoystick, 0.0, 0.0);
            }
        }
    }
    
    fn update_gamepad_button(&mut self, gamepad: &XInputGamepad, mask: u16, button: Button) {
        let pressed = (gamepad.buttons & mask) != 0;
        
        if pressed {
            // If button is pressed, set appropriate state
            match self.buttons.get(&button) {
                None | Some(ButtonState::Released) => {
                    self.set_button_state(button, true);
                }
                Some(ButtonState::Pressed) => {
                    // Transition from Pressed to Held
                    self.buttons.insert(button, ButtonState::Held);
                }
                Some(ButtonState::Held) => {
                    // Keep as Held
                }
            }
        } else {
            // Button not pressed, set to Released
            if self.buttons.get(&button) != Some(&ButtonState::Released) {
                self.set_button_state(button, false);
            }
        }
    }
    
    fn apply_deadzone(value: i16, deadzone: i16) -> f32 {
        // Convert to i32 to avoid overflow when getting absolute value
        let value_i32 = value as i32;
        let deadzone_i32 = deadzone as i32;
        
        if value_i32.abs() < deadzone_i32 {
            0.0
        } else {
            // Map to -1.0 to 1.0 range
            let normalized = value as f32 / 32767.0;
            // Apply deadzone
            let deadzone_normalized = deadzone as f32 / 32767.0;
            let sign = normalized.signum();
            let magnitude = normalized.abs();
            
            if magnitude > deadzone_normalized {
                // Rescale to remove deadzone from range
                sign * ((magnitude - deadzone_normalized) / (1.0 - deadzone_normalized))
            } else {
                0.0
            }
        }
    }
    
    pub fn get_binding_data(&self, binding: Binding) -> Data {
        match binding {
            Binding::MoveHorizontal | Binding::MoveVertical | Binding::MoveUpDown | Binding::Cursor | Binding::LookHorizontal | Binding::LookVertical | Binding::Roll | Binding::Zoom => {
                if let Some(axis_type) = self.axis_bindings.get(&binding) {
                    if let Some(axis) = self.axes.get(axis_type) {
                        match binding {
                            Binding::MoveHorizontal | Binding::LookHorizontal => Data { scalar: axis.x },
                            Binding::MoveVertical | Binding::LookVertical => Data { scalar: axis.y },
                            Binding::Cursor => Data { pos: (axis.x, axis.y) },
                            Binding::Zoom => Data { scalar: axis.y },  // Use Y axis for zoom (scroll wheel vertical)
                            _ => Data { scalar: 0.0 },
                        }
                    } else {
                        match binding {
                            Binding::Cursor => Data { pos: (0.0, 0.0) },
                            _ => Data { scalar: 0.0 },
                        }
                    }
                } else {
                    // Handle special cases for vertical movement and roll
                    match binding {
                        Binding::MoveUpDown => {
                            // Right bumper + left stick Y for vertical movement
                            if self.is_button_held(Button::ButtonRShoulder) {
                                if let Some(left_stick) = self.axes.get(&Axis::LeftJoystick) {
                                    // Use left stick Y axis for up/down when right bumper is held
                                    Data { scalar: -left_stick.y }  // Negate because stick up is negative
                                } else {
                                    Data { scalar: 0.0 }
                                }
                            } else {
                                Data { scalar: 0.0 }
                            }
                        }
                        Binding::Roll => {
                            // Use right stick X-axis for roll only when left bumper is held
                            if self.is_button_held(Button::ButtonLShoulder) {
                                if let Some(right_stick) = self.axes.get(&Axis::RightJoystick) {
                                    Data { scalar: right_stick.x }
                                } else {
                                    Data { scalar: 0.0 }
                                }
                            } else {
                                // Q/E for keyboard roll
                                let left = if self.is_button_held(Button::KeyQ) { -1.0 } else { 0.0 };
                                let right = if self.is_button_held(Button::KeyE) { 1.0 } else { 0.0 };
                                Data { scalar: left + right }
                            }
                        }
                        Binding::Cursor => Data { pos: (0.0, 0.0) },
                        _ => Data { scalar: 0.0 },
                    }
                }
            }
            Binding::Select | Binding::Escape | Binding::Jump | Binding::Sprint | Binding::Use | Binding::Build | Binding::Crouch | Binding::Inventory => {
                if let Some(buttons) = self.bindings.get(&binding) {
                    let activated = buttons.iter().any(|button| {
                        matches!(
                            self.buttons.get(button),
                            Some(ButtonState::Pressed) | Some(ButtonState::Held)
                        )
                    });
                    Data { activate: activated }
                } else {
                    Data { activate: false }
                }
            }
        }
    }
    
    fn is_button_held(&self, button: Button) -> bool {
        matches!(
            self.buttons.get(&button),
            Some(ButtonState::Pressed) | Some(ButtonState::Held)
        )
    }
    
    pub fn set_button_state(&mut self, button: Button, activate: bool) {
        let state = if activate {
            ButtonState::Pressed
        } else {
            ButtonState::Released
        };
        self.buttons.insert(button, state);
    }
    
    pub fn set_axis_state(&mut self, axis: Axis, x: f32, y: f32) {
        let axis_state = self.axes.entry(axis).or_default();
        axis_state.x = x;
        axis_state.y = y;
    }
    
    pub fn set_controller_vibration(&mut self, controller_index: u32, left_motor: f32, right_motor: f32) {
        // Clamp values to 0.0-1.0 range and convert to u16 (0-65535)
        let left_speed = (left_motor.clamp(0.0, 1.0) * 65535.0) as u16;
        let right_speed = (right_motor.clamp(0.0, 1.0) * 65535.0) as u16;
        
        if self.xinput.set_vibration(controller_index, left_speed, right_speed) {
            println!("[DEBUG] Set controller {} vibration: left={}, right={}", controller_index, left_motor, right_motor);
        }
    }
    
    pub fn stop_all_vibration(&mut self) {
        // Stop vibration on all possible controllers (0-3)
        for i in 0..4 {
            self.xinput.set_vibration(i, 0, 0);
        }
    }
}

impl InputHandler for InputState {
    fn update(&mut self) {
        self.update();
    }

    fn get_binding_data(&self, binding: Binding) -> Data {
        self.get_binding_data(binding)
    }

    fn set_button_state(&mut self, button: Button, activate: bool) {
        self.set_button_state(button, activate);
    }

    fn set_axis_state(&mut self, axis: Axis, x: f32, y: f32) {
        self.set_axis_state(axis, x, y);
    }
    
    fn set_controller_vibration(&mut self, controller_index: u32, left_motor: f32, right_motor: f32) {
        self.set_controller_vibration(controller_index, left_motor, right_motor);
    }
    
    fn stop_all_vibration(&mut self) {
        self.stop_all_vibration();
    }
}

// Thread-safe wrapper for input state
pub struct InputSystem {
    state: Arc<Mutex<InputState>>,
}

impl InputSystem {
    pub fn new() -> Self {
        Self {
            state: Arc::new(Mutex::new(InputState::new())),
        }
    }
    
    pub fn state(&self) -> Arc<Mutex<InputState>> {
        self.state.clone()
    }
    
    pub fn vibrate(&self, controller_index: u32, left_motor: f32, right_motor: f32) {
        if let Ok(mut state) = self.state.lock() {
            state.set_controller_vibration(controller_index, left_motor, right_motor);
        }
    }
    
    pub fn stop_vibration(&self) {
        if let Ok(mut state) = self.state.lock() {
            state.stop_all_vibration();
        }
    }
}

// FFI callback functions
pub extern "C" fn key_callback(user_data: *mut c_void, vk: u32, pressed: bool) {
    println!("[DEBUG] key_callback called: user_data={:?}, vk={}, pressed={}", user_data, vk, pressed);
    unsafe {
        if user_data.is_null() {
            println!("[DEBUG] key_callback: user_data is null!");
            return;
        }
        
        let input_system_ptr = user_data as *mut InputSystem;
        println!("[DEBUG] key_callback: input_system_ptr={:?}", input_system_ptr);
        
        if let Some(input_system) = input_system_ptr.as_mut() {
            println!("[DEBUG] key_callback: Got input_system reference");
            if let Ok(mut state) = input_system.state.lock() {
                println!("[DEBUG] key_callback: Successfully locked state, calling handle_key");
                state.handle_key(vk, pressed);
            } else {
                println!("[DEBUG] key_callback: Failed to lock state!");
            }
        } else {
            println!("[DEBUG] key_callback: input_system_ptr.as_mut() returned None!");
        }
    }
}

pub extern "C" fn mouse_move_callback(user_data: *mut c_void, x: i32, y: i32) {
    unsafe {
        if let Some(input_system) = (user_data as *mut InputSystem).as_mut() {
            if let Ok(mut state) = input_system.state.lock() {
                state.handle_mouse_move(x, y);
            }
        }
    }
}

pub extern "C" fn mouse_button_callback(user_data: *mut c_void, button: u32, pressed: bool) {
    unsafe {
        if let Some(input_system) = (user_data as *mut InputSystem).as_mut() {
            if let Ok(mut state) = input_system.state.lock() {
                state.handle_mouse_button(button, pressed);
            }
        }
    }
}

pub extern "C" fn mouse_wheel_callback(user_data: *mut c_void, x: f32, y: f32) {
    unsafe {
        if let Some(input_system) = (user_data as *mut InputSystem).as_mut() {
            if let Ok(mut state) = input_system.state.lock() {
                state.handle_mouse_wheel(x, y);
            }
        }
    }
}