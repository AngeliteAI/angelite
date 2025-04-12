pub mod state;
pub mod action;

// Re-exports for more convenient access
pub use state::ButtonAction;
pub use state::Key;
pub use state::MouseButton;
pub use state::GamepadButton;
pub use state::Axis;
pub use state::Side;
pub use action::ActionManager;
pub use action::Action;
pub use action::ActionId;