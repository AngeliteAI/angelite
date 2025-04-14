use crate::ffi::gfx::surface::Surface;
use core::ffi::c_void;

// Key enumerations
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Key {
    Q,
    W,
    E,
    R,
    T,
    Y,
    U,
    I,
    O,
    P,
    A,
    S,
    D,
    F,
    G,
    H,
    J,
    K,
    L,
    Z,
    X,
    C,
    V,
    B,
    N,
    M,
    Space,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum MouseButton {
    Left,
    Right,
    Middle,
    X1,
    X2,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum GamepadButton {
    A,
    B,
    X,
    Y,
    LeftShoulder,
    RightShoulder,
    Back,
    Start,
    Guide,
    LeftStick,
    RightStick,
    DPadUp,
    DPadDown,
    DPadLeft,
    DPadRight,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Axis {
    X,
    Y,
    Z,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum AxisDevice {
    Mouse,
    Scroll,
    Joystick,
    Trigger,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Side {
    Left,
    Right,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ButtonAction {
    Deactivate, // Button was released
    Activate,   // Button was pressed
    Continuous, // Triggered every frame while button is held
}

// Legacy binding types
#[repr(C)]
#[derive(Copy, Clone)]
pub struct ButtonBinding {
    pub ty: ButtonBindingType,
    pub code: ButtonBindingCode,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub enum ButtonBindingType {
    Keyboard,
    Mouse,
    Gamepad,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub union ButtonBindingCode {
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
    pub ty: AxisDevice,
    pub side: Option<Side>,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub enum BindingType {
    Button,
    Axis,
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
    Button,
    Axis,
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
    pub fn inputSetAction(binding: Binding, control: Control, user: *mut c_void);
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

    pub fn register_action(&self, binding: Binding, control: Control, user_data: *mut c_void) {
        unsafe {
            inputSetAction(binding, control, user_data);
        }
    }

    pub fn poll_actions(&self, action_buffer: &mut [Action]) -> usize {
        unsafe { inputPollActiveActions(action_buffer.as_mut_ptr(), action_buffer.len()) }
    }
}

// Conversion functions to help create common bindings
pub fn create_keyboard_binding(key: Key) -> Binding {
    let key_code = KeyboardCode { key };
    let code = ButtonBindingCode { keyboard: key_code };
    let button_binding = ButtonBinding {
        ty: ButtonBindingType::Keyboard,
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
    let code = ButtonBindingCode { mouse: mouse_code };
    let button_binding = ButtonBinding {
        ty: ButtonBindingType::Mouse,
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
    let code = ButtonBindingCode {
        gamepad: gamepad_code,
    };
    let button_binding = ButtonBinding {
        ty: ButtonBindingType::Gamepad,
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
