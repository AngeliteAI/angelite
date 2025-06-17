const mapping = @import("ergonomic_mapping.zig");
const state = @import("state.zig");

// Re-export the ergonomic types
pub const Key = mapping.Key;
pub const MouseButton = mapping.MouseButton;
pub const GamepadButton = mapping.GamepadButton;
pub const Axis = mapping.Axis;
pub const Side = mapping.Side;
pub const ButtonAction = mapping.ButtonAction;
pub const InputBinding = mapping.InputBinding;
pub const InputThreshold = mapping.InputThreshold;
pub const Action = mapping.Action;

// Re-export the helper functions
pub const keyboardBinding = mapping.keyboardBinding;
pub const mouseButtonBinding = mapping.mouseButtonBinding;
pub const gamepadButtonBinding = mapping.gamepadButtonBinding;
pub const mouseAxisBinding = mapping.mouseAxisBinding;
pub const joystickBinding = mapping.joystickBinding;
pub const triggerBinding = mapping.triggerBinding;
pub const scrollBinding = mapping.scrollBinding;

// Re-export the core input functions with the original signatures
pub const init = state.inputInit;
pub const pollActions = state.inputPollActiveActions;

// New ergonomic register action function
pub fn registerAction(binding: InputBinding, threshold: InputThreshold, user: *anyopaque) void {
    // Convert from ergonomic types to legacy types
    var mappedBinding = convertToLegacyBinding(binding);
    var mappedThreshold = convertToLegacyControl(threshold);
    
    // Call the legacy function
    state.inputSetAction(mappedBinding, mappedThreshold, user);
}

// Conversion functions
fn convertToLegacyBinding(binding: InputBinding) mapping.Binding {
    return switch (binding) {
        .key => |kb| mapping.Binding {
            .ty = .Button,
            .data = .{
                .Button = .{
                    .binding = mapping.ButtonBinding{
                        .ty = .Keyboard,
                        .code = .{
                            .Keyboard = .{
                                .key = kb.key,
                            },
                        },
                    },
                },
            },
        },
        .mouse_button => |mb| mapping.Binding {
            .ty = .Button,
            .data = .{
                .Button = .{
                    .binding = mapping.ButtonBinding{
                        .ty = .Mouse,
                        .code = .{
                            .Mouse = .{
                                .button = mb.button,
                            },
                        },
                    },
                },
            },
        },
        .gamepad_button => |gb| mapping.Binding {
            .ty = .Button,
            .data = .{
                .Button = .{
                    .binding = mapping.ButtonBinding{
                        .ty = .Gamepad,
                        .code = .{
                            .Gamepad = .{
                                .button = gb.button,
                            },
                        },
                    },
                },
            },
        },
        .mouse_axis => |ma| mapping.Binding {
            .ty = .Axis,
            .data = .{
                .Axis = .{
                    .binding = mapping.AxisBinding{
                        .axis = ma.axis,
                        .ty = .Mouse,
                        .side = null,
                    },
                },
            },
        },
        .joystick => |js| mapping.Binding {
            .ty = .Axis,
            .data = .{
                .Axis = .{
                    .binding = mapping.AxisBinding{
                        .axis = js.axis,
                        .ty = .Joystick,
                        .side = js.side,
                    },
                },
            },
        },
        .trigger => |tr| mapping.Binding {
            .ty = .Axis,
            .data = .{
                .Axis = .{
                    .binding = mapping.AxisBinding{
                        .axis = .Z,  // Triggers use Z axis
                        .ty = .Trigger,
                        .side = tr.side,
                    },
                },
            },
        },
        .scroll => |sc| mapping.Binding {
            .ty = .Axis,
            .data = .{
                .Axis = .{
                    .binding = mapping.AxisBinding{
                        .axis = sc.axis,
                        .ty = .Scroll,
                        .side = null,
                    },
                },
            },
        },
    };
}

fn convertToLegacyControl(threshold: InputThreshold) mapping.Control {
    return switch (threshold) {
        .button => |action| mapping.Control {
            .ty = .Button,
            .data = .{
                .Button = .{
                    .action = action,
                },
            },
        },
        .axis => |value| mapping.Control {
            .ty = .Axis,
            .data = .{
                .Axis = .{
                    .movement = value,
                },
            },
        },
    };
}

// Threshold creation helpers
pub fn buttonThreshold(action: ButtonAction) InputThreshold {
    return .{ .button = action };
}

pub fn axisThreshold(value: f32) InputThreshold {
    return .{ .axis = value };
}