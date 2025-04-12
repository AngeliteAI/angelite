const std = @import("std");
const Allocator = std.mem.Allocator;
const surface_module = @import("surface");
const surface = surface_module.include.surface;
const win32 = surface_module.win32;
const mapping = @import("mapping.zig");
const Control = mapping.Control;
const Binding = mapping.Binding;
const Action = mapping.Action;
const ButtonBinding = mapping.ButtonBinding;
const AxisBinding = mapping.AxisBinding;

pub const Input = struct {
    threshold: Control,
    last_state: Control,
    user: *anyopaque,
};

const InputState = struct {
    surface: *surface.Surface,
    actionMapping: std.AutoHashMap(Binding, std.ArrayList(Input)),
};

var global_input_state: ?std.AutoHashMap(win32.HWND, InputState) = null;
var active_actions = std.ArrayList(Action).init(std.heap.page_allocator);

// Store previous gamepad state to detect changes
var prev_gamepad_states: [win32.XINPUT_MAX_CONTROLLERS]win32.XINPUT_STATE = [_]win32.XINPUT_STATE{undefined} ** win32.XINPUT_MAX_CONTROLLERS;
var gamepad_initialized = false;

pub export fn inputInit(forSurface: *surface.Surface) void {
    const win_surfaces = surface_module.win_surfaces;
    const win_surface = win_surfaces.get(forSurface.*.id) orelse unreachable;

    const hwnd = win_surface.hwnd;

    if (global_input_state == null) {
        global_input_state = std.AutoHashMap(win32.HWND, InputState).init(std.heap.page_allocator);
        
        // Initialize gamepad state if this is the first time
        if (!gamepad_initialized) {
            // Clear gamepad states
            for (0..win32.XINPUT_MAX_CONTROLLERS) |i| {
                prev_gamepad_states[i].dwPacketNumber = 0;
                prev_gamepad_states[i].Gamepad.wButtons = 0;
                prev_gamepad_states[i].Gamepad.bLeftTrigger = 0;
                prev_gamepad_states[i].Gamepad.bRightTrigger = 0;
                prev_gamepad_states[i].Gamepad.sThumbLX = 0;
                prev_gamepad_states[i].Gamepad.sThumbLY = 0;
                prev_gamepad_states[i].Gamepad.sThumbRX = 0;
                prev_gamepad_states[i].Gamepad.sThumbRY = 0;
            }
            gamepad_initialized = true;
        }
    }

    global_input_state.?.put(hwnd, InputState {
        surface = forSurface,
        actionMapping = std.AutoHashMap(Binding, std.ArrayList(Input)).init(std.heap.page_allocator),
    }) catch unreachable;
}

pub export fn inputSetAction(binding: Binding, control: Control, user: *anyopaque) void {
    for (global_input_state.?.values()) |*input_state| {
        // Check if this binding already exists
        if (input_state.actionMapping.getEntry(binding)) |entry| {
            // Add the new control to the existing binding
            var last_state = control;
            if (control.ty == .Axis) {
                last_state.data.Axis.movement = 0.0; // Initialize axis to zero
            } else if (control.ty == .Button) {
                last_state.data.Button.action = .Deactivate; // Initialize buttons to released
            }
            
            const input = Input{
                .threshold = control,
                .last_state = last_state,
                .user = user,
            };
            entry.value_ptr.append(input) catch |err| {
                std.debug.print("Failed to append input: {s}\n", .{@errorName(err)});
                return;
            };
        } else {
            // Create a new binding
            var input_list = std.ArrayList(Input).init(std.heap.page_allocator);
            
            var last_state = control;
            if (control.ty == .Axis) {
                last_state.data.Axis.movement = 0.0; // Initialize axis to zero
            } else if (control.ty == .Button) {
                last_state.data.Button.action = .Deactivate; // Initialize buttons to released
            }
            
            const input = Input{
                .threshold = control,
                .last_state = last_state,
                .user = user,
            };
            input_list.append(input) catch |err| {
                std.debug.print("Failed to append input: {s}\n", .{@errorName(err)});
                return;
            };
            input_state.actionMapping.put(binding, input_list) catch |err| {
                std.debug.print("Failed to put input mapping: {s}\n", .{@errorName(err)});
                return;
            };
        }
    }
}

pub export fn inputPollActiveActions(actionBuffer: *Action, maxActions: usize) usize {
    // Clear active actions list
    active_actions.clearRetainingCapacity();
    
    // Poll all surfaces for input
    if (global_input_state) |*input_states| {
        var state_it = input_states.iterator();
        while (state_it.next()) |entry| {
            const hwnd = entry.key_ptr.*;
            var input_state = entry.value_ptr;
            
            // Poll the window for messages
            var msg: win32.MSG = undefined;
            while (win32.PeekMessageW(&msg, hwnd, 0, 0, win32.PM_REMOVE) != 0) {
                _ = win32.TranslateMessage(&msg);
                _ = win32.DispatchMessageW(&msg);
                
                // Process this message for input
                processInputMessage(input_state, msg);
            }
            
            // Poll for gamepad input
            pollGamepads(input_state);
        }
    }
    
    // Copy active actions to the output buffer
    const action_count = @min(active_actions.items.len, maxActions);
    for (0..action_count) |i| {
        actionBuffer[i] = active_actions.items[i];
    }
    
    return action_count;
}

// Process a Windows message for input
fn processInputMessage(input_state: *InputState, msg: win32.MSG) void {
    const wm = @as(u32, @intCast(msg.message));
    
    // Handle keyboard input
    if (wm == win32.WM_KEYDOWN or wm == win32.WM_KEYUP) {
        const key_code = @as(u32, @intCast(msg.wParam));
        const is_down = (wm == win32.WM_KEYDOWN);
        
        // Map Windows key code to our key enum
        if (mapWin32KeyToKey(key_code)) |key| {
            const button_binding = ButtonBinding{
                .ty = .Keyboard,
                .code = .{ .Keyboard = .{ .key = key } },
            };
            
            const binding = Binding{
                .ty = .Button,
                .data = .{ .Button = .{ .binding = button_binding } },
            };
            
            triggerBinding(input_state, binding, is_down);
        }
    }
    // Handle mouse button input
    else if (wm == win32.WM_LBUTTONDOWN or wm == win32.WM_LBUTTONUP) {
        const is_down = (wm == win32.WM_LBUTTONDOWN);
        const button_binding = ButtonBinding{
            .ty = .Mouse,
            .code = .{ .Mouse = .{ .button = .Left } },
        };
        
        const binding = Binding{
            .ty = .Button,
            .data = .{ .Button = .{ .binding = button_binding } },
        };
        
        triggerBinding(input_state, binding, is_down);
    }
    else if (wm == win32.WM_RBUTTONDOWN or wm == win32.WM_RBUTTONUP) {
        const is_down = (wm == win32.WM_RBUTTONDOWN);
        const button_binding = ButtonBinding{
            .ty = .Mouse,
            .code = .{ .Mouse = .{ .button = .Right } },
        };
        
        const binding = Binding{
            .ty = .Button,
            .data = .{ .Button = .{ .binding = button_binding } },
        };
        
        triggerBinding(input_state, binding, is_down);
    }
    else if (wm == win32.WM_MBUTTONDOWN or wm == win32.WM_MBUTTONUP) {
        const is_down = (wm == win32.WM_MBUTTONDOWN);
        const button_binding = ButtonBinding{
            .ty = .Mouse,
            .code = .{ .Mouse = .{ .button = .Middle } },
        };
        
        const binding = Binding{
            .ty = .Button,
            .data = .{ .Button = .{ .binding = button_binding } },
        };
        
        triggerBinding(input_state, binding, is_down);
    }
    // Handle mouse movement
    else if (wm == win32.WM_MOUSEMOVE) {
        const x = @as(i16, @intCast(msg.lParam & 0xFFFF));
        const y = @as(i16, @intCast((msg.lParam >> 16) & 0xFFFF));
        
        // Store previous position or use current if none
        static var prev_x: i16 = x;
        static var prev_y: i16 = y;
        
        // Calculate delta
        const delta_x = x - prev_x;
        const delta_y = y - prev_y;
        
        // Update previous position
        prev_x = x;
        prev_y = y;
        
        // Only trigger if there's movement
        if (delta_x != 0) {
            const axis_binding = AxisBinding{
                .axis = .X,
                .ty = .Mouse,
                .side = null,
            };
            
            const binding = Binding{
                .ty = .Axis,
                .data = .{ .Axis = .{ .binding = axis_binding } },
            };
            
            triggerAxisMovement(input_state, binding, @as(f32, @floatFromInt(delta_x)));
        }
        
        if (delta_y != 0) {
            const axis_binding = AxisBinding{
                .axis = .Y,
                .ty = .Mouse,
                .side = null,
            };
            
            const binding = Binding{
                .ty = .Axis,
                .data = .{ .Axis = .{ .binding = axis_binding } },
            };
            
            triggerAxisMovement(input_state, binding, @as(f32, @floatFromInt(delta_y)));
        }
    }
}

// Trigger a button binding
fn triggerBinding(input_state: *InputState, binding: Binding, is_down: bool) void {
    if (input_state.actionMapping.getEntry(binding)) |entry| {
        for (entry.value_ptr.items) |*input| {
            if (input.threshold.ty == .Button) {
                // Create a new control state based on the threshold
                var new_control = input.threshold;
                
                // Set the button action based on state
                if (is_down) {
                    new_control.data.Button.action = .Activate;
                } else {
                    new_control.data.Button.action = .Deactivate;
                }
                
                // Only add to active actions if state changed
                if (new_control.data.Button.action != input.last_state.data.Button.action) {
                    const action = Action{
                        .control = new_control,
                        .binding = binding,
                        .user = input.user,
                    };
                    
                    active_actions.append(action) catch {};
                    
                    // Update the last state
                    input.last_state = new_control;
                }
                
                // If continuous action is requested, always add it
                if (is_down and input.threshold.data.Button.action == .Continuous) {
                    const action = Action{
                        .control = input.threshold,
                        .binding = binding,
                        .user = input.user,
                    };
                    
                    active_actions.append(action) catch {};
                }
            }
        }
    }
}

// Trigger an axis movement
fn triggerAxisMovement(input_state: *InputState, binding: Binding, movement: f32) void {
    if (input_state.actionMapping.getEntry(binding)) |entry| {
        for (entry.value_ptr.items) |*input| {
            if (input.threshold.ty == .Axis) {
                // Create a new control with the movement
                var new_control = input.threshold;
                new_control.data.Axis.movement = movement;
                
                // Only trigger if movement exceeds threshold (absolute value comparison)
                if (@abs(movement) >= @abs(input.threshold.data.Axis.movement)) {
                    const action = Action{
                        .control = new_control,
                        .binding = binding,
                        .user = input.user,
                    };
                    
                    active_actions.append(action) catch {};
                    
                    // Update the last state
                    input.last_state = new_control;
                }
            }
        }
    }
}

// Poll for gamepad input
fn pollGamepads(input_state: *InputState) void {
    const XINPUT_ERROR_SUCCESS: u32 = 0;
    const XINPUT_ERROR_DEVICE_NOT_CONNECTED: u32 = 1167;
    
    // Poll each controller
    for (0..win32.XINPUT_MAX_CONTROLLERS) |controller_idx| {
        var state: win32.XINPUT_STATE = undefined;
        const result = win32.XInputGetState(@intCast(controller_idx), &state);
        
        if (result == XINPUT_ERROR_SUCCESS) {
            // Controller is connected - check if state changed
            if (state.dwPacketNumber != prev_gamepad_states[controller_idx].dwPacketNumber) {
                // Process button changes
                const curr_buttons = state.Gamepad.wButtons;
                const prev_buttons = prev_gamepad_states[controller_idx].Gamepad.wButtons;
                
                // Process individual buttons
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_A, curr_buttons, prev_buttons, .A);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_B, curr_buttons, prev_buttons, .B);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_X, curr_buttons, prev_buttons, .X);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_Y, curr_buttons, prev_buttons, .Y);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_LEFT_SHOULDER, curr_buttons, prev_buttons, .LeftShoulder);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_RIGHT_SHOULDER, curr_buttons, prev_buttons, .RightShoulder);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_BACK, curr_buttons, prev_buttons, .Back);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_START, curr_buttons, prev_buttons, .Start);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_LEFT_THUMB, curr_buttons, prev_buttons, .LeftStick);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_RIGHT_THUMB, curr_buttons, prev_buttons, .RightStick);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_DPAD_UP, curr_buttons, prev_buttons, .DPadUp);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_DPAD_DOWN, curr_buttons, prev_buttons, .DPadDown);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_DPAD_LEFT, curr_buttons, prev_buttons, .DPadLeft);
                processGamepadButton(input_state, controller_idx, win32.XINPUT_GAMEPAD_DPAD_RIGHT, curr_buttons, prev_buttons, .DPadRight);
                
                // Process stick movement
                const deadzone: i16 = 3500; // ~10% of max value (32767)
                
                // Left stick X axis
                if (@abs(state.Gamepad.sThumbLX) > deadzone) {
                    const axis_binding = AxisBinding{
                        .axis = .X,
                        .ty = .Joystick,
                        .side = .Left,
                    };
                    
                    const binding = Binding{
                        .ty = .Axis,
                        .data = .{ .Axis = .{ .binding = axis_binding } },
                    };
                    
                    const normalized_value = @as(f32, @floatFromInt(state.Gamepad.sThumbLX)) / 32767.0;
                    triggerAxisMovement(input_state, binding, normalized_value);
                }
                
                // Left stick Y axis (inverted as up is negative in XInput)
                if (@abs(state.Gamepad.sThumbLY) > deadzone) {
                    const axis_binding = AxisBinding{
                        .axis = .Y,
                        .ty = .Joystick,
                        .side = .Left,
                    };
                    
                    const binding = Binding{
                        .ty = .Axis,
                        .data = .{ .Axis = .{ .binding = axis_binding } },
                    };
                    
                    // Invert Y axis so positive is up
                    const normalized_value = -(@as(f32, @floatFromInt(state.Gamepad.sThumbLY)) / 32767.0);
                    triggerAxisMovement(input_state, binding, normalized_value);
                }
                
                // Right stick X axis
                if (@abs(state.Gamepad.sThumbRX) > deadzone) {
                    const axis_binding = AxisBinding{
                        .axis = .X,
                        .ty = .Joystick,
                        .side = .Right,
                    };
                    
                    const binding = Binding{
                        .ty = .Axis,
                        .data = .{ .Axis = .{ .binding = axis_binding } },
                    };
                    
                    const normalized_value = @as(f32, @floatFromInt(state.Gamepad.sThumbRX)) / 32767.0;
                    triggerAxisMovement(input_state, binding, normalized_value);
                }
                
                // Right stick Y axis (inverted)
                if (@abs(state.Gamepad.sThumbRY) > deadzone) {
                    const axis_binding = AxisBinding{
                        .axis = .Y,
                        .ty = .Joystick,
                        .side = .Right,
                    };
                    
                    const binding = Binding{
                        .ty = .Axis,
                        .data = .{ .Axis = .{ .binding = axis_binding } },
                    };
                    
                    // Invert Y axis so positive is up
                    const normalized_value = -(@as(f32, @floatFromInt(state.Gamepad.sThumbRY)) / 32767.0);
                    triggerAxisMovement(input_state, binding, normalized_value);
                }
                
                // Left trigger
                if (state.Gamepad.bLeftTrigger > 0) {
                    const axis_binding = AxisBinding{
                        .axis = .Z,
                        .ty = .Trigger,
                        .side = .Left,
                    };
                    
                    const binding = Binding{
                        .ty = .Axis,
                        .data = .{ .Axis = .{ .binding = axis_binding } },
                    };
                    
                    const normalized_value = @as(f32, @floatFromInt(state.Gamepad.bLeftTrigger)) / 255.0;
                    triggerAxisMovement(input_state, binding, normalized_value);
                }
                
                // Right trigger
                if (state.Gamepad.bRightTrigger > 0) {
                    const axis_binding = AxisBinding{
                        .axis = .Z,
                        .ty = .Trigger,
                        .side = .Right,
                    };
                    
                    const binding = Binding{
                        .ty = .Axis,
                        .data = .{ .Axis = .{ .binding = axis_binding } },
                    };
                    
                    const normalized_value = @as(f32, @floatFromInt(state.Gamepad.bRightTrigger)) / 255.0;
                    triggerAxisMovement(input_state, binding, normalized_value);
                }
            }
            
            // Save current state for next comparison
            prev_gamepad_states[controller_idx] = state;
        }
    }
}

// Process a gamepad button state change
fn processGamepadButton(input_state: *InputState, controller_idx: usize, button_flag: u16, curr_buttons: u16, prev_buttons: u16, gamepad_button: mapping.GamepadButton) void {
    const curr_state = (curr_buttons & button_flag) != 0;
    const prev_state = (prev_buttons & button_flag) != 0;
    
    // If state changed, trigger the binding
    if (curr_state != prev_state) {
        const button_binding = ButtonBinding{
            .ty = .Gamepad,
            .code = .{ .Gamepad = .{ .button = gamepad_button } },
        };
        
        const binding = Binding{
            .ty = .Button,
            .data = .{ .Button = .{ .binding = button_binding } },
        };
        
        triggerBinding(input_state, binding, curr_state);
    }
}

// Map Windows key codes to our key enum
fn mapWin32KeyToKey(key_code: u32) ?mapping.Key {
    return switch (key_code) {
        0x51 => .Q,  // Q
        0x57 => .W,  // W
        0x45 => .E,  // E
        0x52 => .R,  // R
        0x54 => .T,  // T
        0x59 => .Y,  // Y
        0x55 => .U,  // U
        0x49 => .I,  // I
        0x4F => .O,  // O
        0x50 => .P,  // P
        0x41 => .A,  // A
        0x53 => .S,  // S
        0x44 => .D,  // D
        0x46 => .F,  // F
        0x47 => .G,  // G
        0x48 => .H,  // H
        0x4A => .J,  // J
        0x4B => .K,  // K
        0x4C => .L,  // L
        0x5A => .Z,  // Z
        0x58 => .X,  // X
        0x43 => .C,  // C
        0x56 => .V,  // V
        0x42 => .B,  // B
        0x4E => .N,  // N
        0x4D => .M,  // M
        0x20 => .Space, // Space
        else => null,
    };
}
