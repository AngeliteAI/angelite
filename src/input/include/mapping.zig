const std = @import("std");

// Input types and enums
pub const Key = enum(c_int) { A = 0, B = 1, C = 2, D = 3, E = 4, F = 5, G = 6, H = 7, I = 8, J = 9, K = 10, L = 11, M = 12, N = 13, O = 14, P = 15, Q = 16, R = 17, S = 18, T = 19, U = 20, V = 21, W = 22, X = 23, Y = 24, Z = 25, Space = 26, _ };

pub const MouseButton = enum(c_int) { Left = 0, Right = 1, Middle = 2, _ };

pub const GamepadButton = enum(c_int) { A = 0, B = 1, X = 2, Y = 3, LeftShoulder = 4, RightShoulder = 5, LeftStick = 6, RightStick = 7, DPadUp = 8, DPadDown = 9, DPadLeft = 10, DPadRight = 11, Start = 12, Back = 13, _ };

pub const Axis = enum(c_int) { X = 0, Y = 1, Z = 2, _ };

pub const Side = enum(c_int) { Left = 0, Right = 1, None = 2, _ };

pub const InputType = enum(c_int) { Keyboard = 0, Mouse = 1, Gamepad = 2, Joystick = 3, Trigger = 4, _ };

// Button binding structures
pub const KeyboardCode = extern struct {
    key: Key,
};

pub const MouseCode = extern struct {
    button: MouseButton,
};

pub const GamepadCode = extern struct {
    button: GamepadButton,
};

// NOTE: This must match what state.zig expects - UNTAGGED union
pub const ButtonCode = extern union {
    Keyboard: KeyboardCode,
    Mouse: MouseCode,
    Gamepad: GamepadCode,
    Joystick: u8, // Placeholder
    Trigger: u8, // Placeholder
};

pub const ButtonBinding = extern struct {
    ty: InputType, // This field indicates which union variant is active
    code: ButtonCode,
};

// Axis binding structures
pub const AxisBinding = extern struct {
    axis: Axis,
    ty: InputType,
    side: Side,
};

// Control types
pub const ButtonAction = enum(c_int) { Activate = 0, Deactivate = 1, Continuous = 2, _ };

pub const ButtonControl = extern struct {
    action: ButtonAction,
};

pub const AxisControl = extern struct {
    movement: f32,
};

pub const ControlType = enum(c_int) { Button = 0, Axis = 1, _ };

// NOTE: This must match what state.zig expects - UNTAGGED union
pub const ControlData = extern union {
    Button: ButtonControl,
    Axis: AxisControl,
};

pub const Control = extern struct {
    ty: ControlType, // This field indicates which union variant is active
    data: ControlData,
};

// Binding type
pub const BindingType = enum(c_int) { Button = 0, Axis = 1, _ };

// NOTE: This must match what state.zig expects - UNTAGGED union
pub const BindingData = extern union {
    Button: extern struct { binding: ButtonBinding },
    Axis: extern struct { binding: AxisBinding },
};

pub const Binding = extern struct {
    ty: BindingType, // This field indicates which union variant is active
    data: BindingData,
};

// Action type
pub const Action = extern struct {
    control: Control,
    binding: Binding,
    user: ?*anyopaque,
};

// Standalone hash and equality functions (instead of methods)
pub fn button_binding_hash(binding: ButtonBinding) u64 {
    var hasher = std.hash.Wyhash.init(0);
    const ty_int = @intFromEnum(binding.ty);
    std.hash.autoHash(&hasher, ty_int);

    // Use the struct's ty field to determine which union field to access
    switch (binding.ty) {
        .Keyboard => {
            const key_int = @intFromEnum(binding.code.Keyboard.key);
            std.hash.autoHash(&hasher, key_int);
        },
        .Mouse => {
            const button_int = @intFromEnum(binding.code.Mouse.button);
            std.hash.autoHash(&hasher, button_int);
        },
        .Gamepad => {
            const button_int = @intFromEnum(binding.code.Gamepad.button);
            std.hash.autoHash(&hasher, button_int);
        },
        else => {},
    }

    return hasher.final();
}

pub fn button_binding_eql(a: ButtonBinding, b: ButtonBinding) bool {
    if (a.ty != b.ty) return false;

    // Use the struct's ty field for switching
    switch (a.ty) {
        .Keyboard => {
            return a.code.Keyboard.key == b.code.Keyboard.key;
        },
        .Mouse => {
            return a.code.Mouse.button == b.code.Mouse.button;
        },
        .Gamepad => {
            return a.code.Gamepad.button == b.code.Gamepad.button;
        },
        else => return true,
    }
}

pub fn axis_binding_hash(binding: AxisBinding) u64 {
    var hasher = std.hash.Wyhash.init(0);
    const axis_int = @intFromEnum(binding.axis);
    const ty_int = @intFromEnum(binding.ty);
    const side_int = @intFromEnum(binding.side);

    std.hash.autoHash(&hasher, axis_int);
    std.hash.autoHash(&hasher, ty_int);
    std.hash.autoHash(&hasher, side_int);

    return hasher.final();
}

pub fn axis_binding_eql(a: AxisBinding, b: AxisBinding) bool {
    return a.axis == b.axis and
        a.ty == b.ty and
        a.side == b.side;
}

pub fn binding_hash(binding: Binding) u64 {
    var hasher = std.hash.Wyhash.init(0);
    const ty_int = @intFromEnum(binding.ty);
    std.hash.autoHash(&hasher, ty_int);

    switch (binding.ty) {
        .Button => {
            std.hash.autoHash(&hasher, button_binding_hash(binding.data.Button.binding));
        },
        .Axis => {
            std.hash.autoHash(&hasher, axis_binding_hash(binding.data.Axis.binding));
        },
        _ => {},
    }

    return hasher.final();
}

pub fn binding_eql(a: Binding, b: Binding) bool {
    if (a.ty != b.ty) return false;

    switch (a.ty) {
        .Button => {
            return button_binding_eql(a.data.Button.binding, b.data.Button.binding);
        },
        .Axis => {
            return axis_binding_eql(a.data.Axis.binding, b.data.Axis.binding);
        },
        _ => return false,
    }
}

// C-compatible helper functions with simple scalar types
export fn binding_create_button_keyboard_ptr(key: Key, output: *Binding) void {
    const keyboard_code = KeyboardCode{ .key = key };
    const button_code = ButtonCode{ .Keyboard = keyboard_code };
    const button_binding = ButtonBinding{
        .ty = .Keyboard,
        .code = button_code,
    };
    output.ty = .Button;
    output.data = BindingData{ .Button = .{ .binding = button_binding } };
}

export fn binding_create_button_mouse_ptr(button: MouseButton, output: *Binding) void {
    const mouse_code = MouseCode{ .button = button };
    const button_code = ButtonCode{ .Mouse = mouse_code };
    const button_binding = ButtonBinding{
        .ty = .Mouse,
        .code = button_code,
    };
    output.ty = .Button;
    output.data = BindingData{ .Button = .{ .binding = button_binding } };
}

export fn binding_create_button_gamepad_ptr(button: GamepadButton, output: *Binding) void {
    const gamepad_code = GamepadCode{ .button = button };
    const button_code = ButtonCode{ .Gamepad = gamepad_code };
    const button_binding = ButtonBinding{
        .ty = .Gamepad,
        .code = button_code,
    };
    output.ty = .Button;
    output.data = BindingData{ .Button = .{ .binding = button_binding } };
}

export fn binding_create_axis_ptr(axis: Axis, input_type: InputType, side: Side, output: *Binding) void {
    const axis_binding = AxisBinding{
        .axis = axis,
        .ty = input_type,
        .side = side,
    };
    output.ty = .Axis;
    output.data = BindingData{ .Axis = .{ .binding = axis_binding } };
}

export fn control_create_button_ptr(action: ButtonAction, output: *Control) void {
    const button_control = ButtonControl{ .action = action };
    output.ty = .Button;
    output.data = ControlData{ .Button = button_control };
}

export fn control_create_axis_ptr(movement: f32, output: *Control) void {
    const axis_control = AxisControl{ .movement = movement };
    output.ty = .Axis;
    output.data = ControlData{ .Axis = axis_control };
}

export fn action_create_ptr(control: *const Control, binding: *const Binding, user_data: ?*anyopaque, output: *Action) void {
    output.control = control.*;
    output.binding = binding.*;
    output.user = user_data orelse undefined;
}
