// Import mapping (which now forwards to the consolidated mapping module)
const mapping_types = @import("mapping.zig");
pub const state = @import("state.zig");

// Re-export mapping for backward compatibility
pub const mapping = mapping_types;
pub const Key = mapping_types.Key;
pub const MouseButton = mapping_types.MouseButton;
pub const GamepadButton = mapping_types.GamepadButton;
pub const Axis = mapping_types.Axis;
pub const AxisDevice = mapping_types.AxisDevice;
pub const Side = mapping_types.Side;
pub const ButtonAction = mapping_types.ButtonAction;

// Export the new action manager as the primary API
pub const action = @import("action_manager.zig");
pub const ActionManager = action.ActionManager;
pub const Action = action.Action;
pub const ActionId = action.ActionId;

// Core input functions
pub const init = state.inputInit;
pub const pollEvents = state.inputPollActiveActions;

// Helper function to create an ActionManager with the standard allocator
pub fn createActionManager() ActionManager {
    return ActionManager.init(std.heap.page_allocator);
}

// Helper functions for bindings
pub const keyboardBinding = mapping_types.keyboardBinding;
pub const mouseButtonBinding = mapping_types.mouseButtonBinding;
pub const gamepadButtonBinding = mapping_types.gamepadButtonBinding;
pub const mouseAxisBinding = mapping_types.mouseAxisBinding;
pub const joystickBinding = mapping_types.joystickBinding;
pub const triggerBinding = mapping_types.triggerBinding;
pub const scrollBinding = mapping_types.scrollBinding;

// Helper functions for thresholds
pub const buttonThreshold = mapping_types.buttonThreshold;
pub const axisThreshold = mapping_types.axisThreshold;

// Import standard library for allocators
const std = @import("std");
