use crate::ffi::gfx::surface::Surface;
use core::ffi::c_void;

// Key enumerations
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Key {
    A = 0,
    B = 1,
    C = 2,
    D = 3,
    E = 4,
    F = 5,
    G = 6,
    H = 7,
    I = 8,
    J = 9,
    K = 10,
    L = 11,
    M = 12,
    N = 13,
    O = 14,
    P = 15,
    Q = 16,
    R = 17,
    S = 18,
    T = 19,
    U = 20,
    V = 21,
    W = 22,
    X = 23,
    Y = 24,
    Z = 25,
    Space = 26,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum MouseButton {
    Left = 0,
    Right = 1,
    Middle = 2,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum GamepadButton {
    A = 0,
    B = 1,
    X = 2,
    Y = 3,
    LeftShoulder = 4,
    RightShoulder = 5,
    LeftStick = 6,
    RightStick = 7,
    DPadUp = 8,
    DPadDown = 9,
    DPadLeft = 10,
    DPadRight = 11,
    Start = 12,
    Back = 13,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Axis {
    X = 0,
    Y = 1,
    Z = 2,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Side {
    Left = 0,
    Right = 1,
    None = 2,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum InputType {
    Keyboard = 0,
    Mouse = 1,
    Gamepad = 2,
    Joystick = 3,
    Trigger = 4,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ButtonAction {
    Activate = 0,
    Deactivate = 1,
    Continuous = 2,
}

// Binding types
#[repr(C)]
#[derive(Copy, Clone)]
pub struct ButtonBinding {
    pub ty: InputType,
    pub code: ButtonCode,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub union ButtonCode {
    pub keyboard: KeyboardCode,
    pub mouse: MouseCode,
    pub gamepad: GamepadCode,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct KeyboardCode {
    pub key: Key,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct MouseCode {
    pub button: MouseButton,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct GamepadCode {
    pub button: GamepadButton,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct AxisBinding {
    pub axis: Axis,
    pub ty: InputType,
    pub side: Side,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub enum BindingType {
    Button = 0,
    Axis = 1,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub union BindingData {
    pub button: ButtonBindingData,
    pub axis: AxisBindingData,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct ButtonBindingData {
    pub binding: ButtonBinding,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct AxisBindingData {
    pub binding: AxisBinding,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct Binding {
    pub ty: BindingType,
    pub data: BindingData,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub enum ControlType {
    Button = 0,
    Axis = 1,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub union ControlData {
    pub button: ButtonControlData,
    pub axis: AxisControlData,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct ButtonControlData {
    pub action: ButtonAction,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct AxisControlData {
    pub movement: f32,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct Control {
    pub ty: ControlType,
    pub data: ControlData,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct Action {
    pub control: Control,
    pub binding: Binding,
    pub user: *mut c_void,
}

#[link(name = "input", kind = "static")]
unsafe extern "C" {
    // Core input functions
    pub fn inputInit(surface: *mut Surface);
    pub fn inputPollActiveActions(actionBuffer: *mut Action, maxActions: usize) -> usize;
}

// Rust-friendly wrappers
pub struct InputState {
    pub initialized: bool,
}

impl InputState {
    pub fn new(surface: *mut Surface) -> Self {
        unsafe {
            inputInit(surface);
        }
        Self { initialized: true }
    }

    pub fn poll_actions(&self, action_buffer: &mut [Action]) -> usize {
        unsafe { inputPollActiveActions(action_buffer.as_mut_ptr(), action_buffer.len()) }
    }
}

// Conversion functions to help create common bindings
pub fn create_keyboard_binding(key: Key) -> Binding {
    let key_code = KeyboardCode { key };
    let code = ButtonCode { keyboard: key_code };
    let button_binding = ButtonBinding {
        ty: InputType::Keyboard,
        code,
    };
    let button_data = ButtonBindingData {
        binding: button_binding,
    };
    Binding {
        ty: BindingType::Button,
        data: BindingData {
            button: button_data,
        },
    }
}

pub fn create_mouse_binding(button: MouseButton) -> Binding {
    let mouse_code = MouseCode { button };
    let code = ButtonCode { mouse: mouse_code };
    let button_binding = ButtonBinding {
        ty: InputType::Mouse,
        code,
    };
    let button_data = ButtonBindingData {
        binding: button_binding,
    };
    Binding {
        ty: BindingType::Button,
        data: BindingData {
            button: button_data,
        },
    }
}

pub fn create_gamepad_binding(button: GamepadButton) -> Binding {
    let gamepad_code = GamepadCode { button };
    let code = ButtonCode {
        gamepad: gamepad_code,
    };
    let button_binding = ButtonBinding {
        ty: InputType::Gamepad,
        code,
    };
    let button_data = ButtonBindingData {
        binding: button_binding,
    };
    Binding {
        ty: BindingType::Button,
        data: BindingData {
            button: button_data,
        },
    }
}

pub fn create_button_control(action: ButtonAction) -> Control {
    let button_data = ButtonControlData { action };
    Control {
        ty: ControlType::Button,
        data: ControlData {
            button: button_data,
        },
    }
}

pub fn create_axis_control(movement: f32) -> Control {
    let axis_data = AxisControlData { movement };
    Control {
        ty: ControlType::Axis,
        data: ControlData { axis: axis_data },
    }
}
