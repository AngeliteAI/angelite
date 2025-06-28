// Top-level input module that consolidates all input handling

// Controller module placeholder (to be implemented per platform)
pub mod controller {
    // Platform-specific controller implementations go here
}

// Platform-specific input modules
#[cfg(any(target_os = "windows", target_os = "linux"))]
pub mod windows;

#[cfg(target_os = "macos")]
pub mod macos;

// Common input types and traits
use crate::engine::{Button, Axis, Binding, Data};
use std::collections::HashMap;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ButtonState {
    Released,
    Pressed,
    Held,
}

#[derive(Debug, Clone, Copy)]
pub struct AxisState {
    pub x: f32,
    pub y: f32,
    pub deadzone: f32,
    pub sensitivity: f32,
}

impl Default for AxisState {
    fn default() -> Self {
        Self {
            x: 0.0,
            y: 0.0,
            deadzone: 0.1,
            sensitivity: 1.0,
        }
    }
}

// Common input trait that all platform implementations should implement
pub trait InputHandler {
    fn update(&mut self);
    fn get_binding_data(&self, binding: Binding) -> Data;
    fn set_button_state(&mut self, button: Button, activate: bool);
    fn set_axis_state(&mut self, axis: Axis, x: f32, y: f32);
    
    // Controller vibration support (optional, platforms can provide empty impl)
    fn set_controller_vibration(&mut self, controller_index: u32, left_motor: f32, right_motor: f32) {
        // Default empty implementation for platforms without vibration support
    }
    
    fn stop_all_vibration(&mut self) {
        // Default empty implementation
    }
}

// Re-export platform-specific implementations
#[cfg(any(target_os = "windows", target_os = "linux"))]
pub use windows::{InputSystem, InputState};

#[cfg(target_os = "macos")]
pub use macos::{InputSystem, InputState};