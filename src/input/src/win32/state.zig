const std = @import("std");
const Allocator = std.mem.Allocator;
const surface_module = @import("surface");
const surface = surface_module.include.surface;
const mapping = @import("include").mapping;
const Control = mapping.Control;
const action = @import("action_manager.zig");
const Binding = mapping.Binding;
const Action = mapping.Action;
const ButtonBinding = mapping.ButtonBinding;
const AxisBinding = mapping.AxisBinding;
const GamepadBinding = mapping.GamepadBinding;

fn array_contains(comptime T: type, haystack: []T, needle: T) bool {
    for (haystack) |element| {
        if (mapping.binding_eql(element, needle))
            return true;
    }
    return false;
}

// Platform-agnostic types to replace Win32 dependencies
pub const WindowHandle = usize;

// Message types and constants
pub const MessageType = enum(u32) {
    KeyDown = 0x0100,
    KeyUp = 0x0101,
    MouseMove = 0x0200,
    LButtonDown = 0x0201,
    LButtonUp = 0x0202,
    RButtonDown = 0x0204,
    RButtonUp = 0x0205,
    MButtonDown = 0x0207,
    MButtonUp = 0x0208,
};

pub const Message = struct {
    message: MessageType,
    wParam: usize, // Key code or other data
    lParam: usize, // Position or other data
    window: WindowHandle,
};

// Gamepad constants and types
pub const XINPUT_MAX_CONTROLLERS = 4;

pub const GamepadButtons = struct {
    const DPAD_UP: u16 = 0x0001;
    const DPAD_DOWN: u16 = 0x0002;
    const DPAD_LEFT: u16 = 0x0004;
    const DPAD_RIGHT: u16 = 0x0008;
    const START: u16 = 0x0010;
    const BACK: u16 = 0x0020;
    const LEFT_THUMB: u16 = 0x0040;
    const RIGHT_THUMB: u16 = 0x0080;
    const LEFT_SHOULDER: u16 = 0x0100;
    const RIGHT_SHOULDER: u16 = 0x0200;
    const A: u16 = 0x1000;
    const B: u16 = 0x2000;
    const X: u16 = 0x4000;
    const Y: u16 = 0x8000;
};

pub const GamepadState = extern struct {
    wButtons: u16,
    bLeftTrigger: u8,
    bRightTrigger: u8,
    sThumbLX: i16,
    sThumbLY: i16,
    sThumbRX: i16,
    sThumbRY: i16,
};

pub const InputState = extern struct {
    dwPacketNumber: u32,
    Gamepad: GamepadState,
};

var prev_x: i16 = 0;
var prev_y: i16 = 0;

pub const Input = struct {
    threshold: Control,
    last_state: Control,
    user: *anyopaque,
};

// Custom hash map context for Binding type
const BindingContext = struct {
    pub fn hash(self: @This(), key: Binding) u64 {
        _ = self;
        return mapping.binding_hash(key);
    }

    pub fn eql(self: @This(), a: Binding, b: Binding) bool {
        _ = self;
        return mapping.binding_eql(a, b);
    }
};

pub const InputStateMap = struct {
    surface: *surface.Surface,
    actionManager: *action.ActionManager,
};

pub var global_input_state: ?std.AutoHashMap(WindowHandle, InputStateMap) = null;
var active_actions = std.ArrayList(Action).init(std.heap.page_allocator);

// Store previous gamepad state to detect changes
var prev_gamepad_states: [XINPUT_MAX_CONTROLLERS]InputState = undefined;
var gamepad_initialized = false;

// Platform-agnostic message queue implementation
pub fn peekMessage(msg: *Message, window: WindowHandle) bool {
    std.debug.print("DEBUG: peekMessage called for window {d}\n", .{window});
    _ = msg;
    // In a real implementation, this would check for platform-specific messages
    // Here we just return false to indicate no messages
    return false;
}

// XInput constants for error codes
pub const XINPUT_ERROR_SUCCESS: u32 = 0;
pub const XINPUT_ERROR_DEVICE_NOT_CONNECTED: u32 = 1167;

// External XInput function declaration
pub extern "xinput1_4" fn XInputGetState(dwUserIndex: u32, pState: *InputState) u32;

// Get gamepad state using XInput
pub fn getGamepadState(controller_idx: u32, state: *InputState) u32 {
    std.debug.print("DEBUG: getGamepadState called for controller {d}\n", .{controller_idx});

    // Bounds check to prevent accessing invalid controllers
    if (controller_idx >= XINPUT_MAX_CONTROLLERS) {
        std.debug.print("ERROR: Invalid controller index {d}\n", .{controller_idx});
        return XINPUT_ERROR_DEVICE_NOT_CONNECTED;
    }

    // Call the XInput API to get the controller state
    const result = XInputGetState(controller_idx, state);

    if (result == XINPUT_ERROR_SUCCESS) {
        std.debug.print("DEBUG: Successfully got state for controller {d}, packet: {d}\n", .{ controller_idx, state.dwPacketNumber });
    } else if (result == XINPUT_ERROR_DEVICE_NOT_CONNECTED) {
        std.debug.print("DEBUG: Controller {d} not connected\n", .{controller_idx});
    } else {
        std.debug.print("ERROR: Failed to get controller {d} state, error: {d}\n", .{ controller_idx, result });
    }

    return result;
}

pub var windowHandle: WindowHandle = undefined;
pub var windowSurface: *surface.Surface = undefined;

pub export fn inputInit(forSurface: *surface.Surface) void {
    std.debug.print("DEBUG: inputInit called with surface at {*}\n", .{forSurface});

    // Get the surface identifier
    const surface_id = forSurface.*.id;
    const handle = @as(WindowHandle, @intCast(surface_id));
    std.debug.print("DEBUG: Surface ID: {d}, WindowHandle: {d}\n", .{ surface_id, handle });

    if (global_input_state == null) {
        std.debug.print("DEBUG: Initializing global_input_state\n", .{});
        global_input_state = std.AutoHashMap(WindowHandle, InputStateMap).init(std.heap.page_allocator);

        // Initialize gamepad state if this is the first time
        if (!gamepad_initialized) {
            std.debug.print("DEBUG: Initializing gamepad states\n", .{});
            // Clear gamepad states
            for (0..XINPUT_MAX_CONTROLLERS) |i| {
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

    std.debug.print("DEBUG: Creating new InputStateMap for handle {d}\n", .{handle});
    windowHandle = handle;
    windowSurface = forSurface;
    std.debug.print("DEBUG: inputInit completed successfully\n", .{});
}

pub export fn inputPollActiveActions(actionBuffer: [*]Action, maxActions: usize) usize {
    std.debug.print("DEBUG: inputPollActiveActions called for max {d} actions\n", .{maxActions});

    // Clear active actions list
    active_actions.clearRetainingCapacity();
    std.debug.print("DEBUG: Cleared active_actions list\n", .{});

    // Poll all surfaces for input
    if (global_input_state) |*input_states| {
        std.debug.print("DEBUG: global_input_state exists, iterating over {d} entries\n", .{input_states.count()});

        var state_it = input_states.iterator();
        var count: usize = 0;

        while (state_it.next()) |entry| {
            count += 1;
            const window_handle = entry.key_ptr.*;
            const input_state = entry.value_ptr;
            pollGamepads(input_state);
            std.debug.print("DEBUG: Processing state entry {d} for window handle {d}\n", .{ count, window_handle });

            // Poll the window for messages
            var msg: Message = undefined;
            var msg_count: usize = 0;
            while (peekMessage(&msg, window_handle)) {
                msg_count += 1;
                // Process this message for input
                processInputMessage(input_state, msg);
            }
            std.debug.print("DEBUG: Processed {d} messages for this window\n", .{msg_count});

            // Poll for gamepad input
        }

        std.debug.print("DEBUG: Processed {d} state entries in total\n", .{count});
        if (count == 0) {
            std.debug.print("WARNING: No state entries found!\n", .{});
        }
    } else {
        std.debug.print("ERROR: global_input_state is null in inputPollActiveActions!\n", .{});
    }

    // Copy active actions to the output buffer
    const action_count = @min(active_actions.items.len, maxActions);
    std.debug.print("DEBUG: Copying {d} active actions to output buffer\n", .{action_count});

    for (0..action_count) |i| {
        actionBuffer[i] = active_actions.items[i];
    }

    std.debug.print("DEBUG: inputPollActiveActions returning {d} actions\n", .{action_count});
    return action_count;
}

// Process a message for input
fn processInputMessage(input_state: *InputStateMap, msg: Message) void {
    _ = input_state;
    std.debug.print("DEBUG: processInputMessage handling message type {any}\n", .{msg.message});

    switch (msg.message) {
        // Handle keyboard input
        .KeyDown, .KeyUp => {
            const key_code = @as(u32, @intCast(msg.wParam));
            const is_down = (msg.message == .KeyDown);
            std.debug.print("DEBUG: Key {s}: key code {d}\n", .{ if (is_down) "down" else "up", key_code });

            // Map key code to our key enum
            if (mapKeyToKey(key_code)) |key| {
                std.debug.print("DEBUG: Mapped to key {any}\n", .{key});
                // Implementation would create a ButtonBinding and call triggerBinding
            } else {
                std.debug.print("DEBUG: Could not map key code {d}\n", .{key_code});
            }
        },
        // Handle mouse button input
        .LButtonDown, .LButtonUp => {
            const is_down = (msg.message == .LButtonDown);
            std.debug.print("DEBUG: Left mouse button {s}\n", .{if (is_down) "down" else "up"});
            // Implementation would create a ButtonBinding and call triggerBinding
        },
        .RButtonDown, .RButtonUp => {
            const is_down = (msg.message == .RButtonDown);
            std.debug.print("DEBUG: Right mouse button {s}\n", .{if (is_down) "down" else "up"});
            // Implementation would create a ButtonBinding and call triggerBinding
        },
        .MButtonDown, .MButtonUp => {
            const is_down = (msg.message == .MButtonDown);
            std.debug.print("DEBUG: Middle mouse button {s}\n", .{if (is_down) "down" else "up"});
            // Implementation would create a ButtonBinding and call triggerBinding
        },
        // Handle mouse movement
        .MouseMove => {
            const x = @as(i16, @intCast(msg.lParam & 0xFFFF));
            const y = @as(i16, @intCast(msg.lParam >> 16));

            // Calculate delta
            const delta_x = x - prev_x;
            const delta_y = y - prev_y;
            std.debug.print("DEBUG: Mouse moved to ({d},{d}), delta: ({d},{d})\n", .{ x, y, delta_x, delta_y });

            // Update previous position
            prev_x = x;
            prev_y = y;

            // Implementation would create AxisBindings and call triggerAxisMovement
        },
    }
}

// Trigger a button binding
fn triggerBinding(input_state: *InputStateMap, binding: Binding, is_down: bool) void {
    std.debug.print("DEBUG: triggerBinding called for binding type {any}, is_down: {any}\n", .{ binding.ty, is_down });

    var found_match = false;
    var iterator = input_state.actionManager.actions.iterator();
    while (iterator.next()) |entry| {
        std.debug.print("DEBUG: binding {any}\n", .{binding});
        if (!array_contains(Binding, entry.value_ptr.*.bindings.items, binding)) {
            continue;
        }
        found_match = true;
        std.debug.print("DEBUG: Found matching binding\n", .{});

        // Create a new control state based on the threshold
        var new_control = Control{
            .ty = .Button,
            .data = .{
                .Button = .{
                    .action = if (is_down) .Activate else .Deactivate,
                },
            },
        };
        // Set the button action based on state
        if (is_down) {
            new_control.data.Button.action = .Activate;
        } else {
            new_control.data.Button.action = .Deactivate;
        }

        // Only add to active actions if state changed
        std.debug.print("DEBUG: Button state changed, adding to active actions\n", .{});

        const newaction = Action{
            .control = new_control,
            .binding = binding,
            .user = entry.value_ptr.*.user_data,
        };

        active_actions.append(newaction) catch |err| {
            std.debug.print("ERROR: Failed to append action: {s}\n", .{@errorName(err)});
            continue;
        };

        // Update the last state
        // input.last_state = new_control;
        std.debug.print("DEBUG: Updated last state\n", .{});

        // If continuous action is requested, always add it
        std.debug.print("DEBUG: Adding continuous action\n", .{});

        const continuous_action = Action{
            .control = new_control,
            .binding = binding,
            .user = entry.value_ptr.*.user_data,
        };

        active_actions.append(continuous_action) catch |err| {
            std.debug.print("ERROR: Failed to append continuous action: {s}\n", .{@errorName(err)});
        };
    }

    if (!found_match) {
        std.debug.print("DEBUG: No matching binding found\n", .{});
    }
}

// Trigger an axis movement
fn triggerAxisMovement(input_state: *InputStateMap, binding: Binding, movement: f32) void {
    std.debug.print("DEBUG: triggerAxisMovement called for binding type {any}, movement: {d}\n", .{ binding.ty, movement });

    var found_match = false;
    var iterator = input_state.actionManager.actions.iterator();
    while (iterator.next()) |entry| {
        std.debug.print("DEBUG: binding {any}\n", .{entry});
        if (!array_contains(Binding, entry.value_ptr.*.bindings.items, binding)) {
            continue;
        }
        found_match = true;

        // Create a new control with the movement
        const new_control = Control{
            .ty = .Axis,
            .data = .{
                .Axis = .{
                    .movement = movement,
                },
            },
        };

        // Only trigger if movement exceeds threshold (absolute value comparison)
        const threshold = @abs(0.3);
        if (@abs(movement) >= threshold) {
            std.debug.print("DEBUG: Movement {d} exceeds threshold {d}, adding to active actions\n", .{ @abs(movement), threshold });

            const newaction = Action{
                .control = new_control,
                .binding = binding,
                .user = entry.value_ptr.*.user_data,
            };

            active_actions.append(newaction) catch |err| {
                std.debug.print("ERROR: Failed to append action: {s}\n", .{@errorName(err)});
                continue;
            };

            // Update the last state
            std.debug.print("DEBUG: Updated last state\n", .{});
        } else {
            std.debug.print("DEBUG: Movement {d} below threshold {d}\n", .{ @abs(movement), threshold });
        }
    }

    if (!found_match) {
        std.debug.print("DEBUG: No matching binding found\n", .{});
    }
}

// Poll for gamepad input
fn pollGamepads(input_state: *InputStateMap) void {
    std.debug.print("DEBUG: pollGamepads called\n", .{});

    // Poll each controller
    for (0..XINPUT_MAX_CONTROLLERS) |controller_idx| {
        var state: InputState = undefined;
        const result = getGamepadState(@as(u32, @intCast(controller_idx)), &state);

        if (result == XINPUT_ERROR_SUCCESS) {
            // Controller is connected - check if state changed
            std.debug.print("DEBUG: Controller {d} state changed\n", .{controller_idx});

            // Process button changes
            const curr_buttons = state.Gamepad.wButtons;
            const prev_buttons = prev_gamepad_states[controller_idx].Gamepad.wButtons;

            // Check individual buttons
            // Check A button
            if ((curr_buttons & GamepadButtons.A) != (prev_buttons & GamepadButtons.A)) {
                const is_pressed = (curr_buttons & GamepadButtons.A) != 0;
                std.debug.print("DEBUG: Gamepad A button {s}\n", .{if (is_pressed) "pressed" else "released"});
                if (is_pressed) {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .A, .side = .None } } } }, is_pressed);
                } else {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .A, .side = .None } } } }, is_pressed);
                }
            }

            // Check B button
            if ((curr_buttons & GamepadButtons.B) != (prev_buttons & GamepadButtons.B)) {
                const is_pressed = (curr_buttons & GamepadButtons.B) != 0;
                std.debug.print("DEBUG: Gamepad B button {s}\n", .{if (is_pressed) "pressed" else "released"});
                if (is_pressed) {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .B, .side = .None } } } }, is_pressed);
                } else {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .B, .side = .None } } } }, is_pressed);
                }
            }

            // Check X button
            if ((curr_buttons & GamepadButtons.X) != (prev_buttons & GamepadButtons.X)) {
                const is_pressed = (curr_buttons & GamepadButtons.X) != 0;
                std.debug.print("DEBUG: Gamepad X button {s}\n", .{if (is_pressed) "pressed" else "released"});
                if (is_pressed) {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .X, .side = .None } } } }, is_pressed);
                } else {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .X, .side = .None } } } }, is_pressed);
                }
            }

            // Check Y button
            if ((curr_buttons & GamepadButtons.Y) != (prev_buttons & GamepadButtons.Y)) {
                const is_pressed = (curr_buttons & GamepadButtons.Y) != 0;
                std.debug.print("DEBUG: Gamepad Y button {s}\n", .{if (is_pressed) "pressed" else "released"});
                if (is_pressed) {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .Y, .side = .None } } } }, is_pressed);
                } else {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .Y, .side = .None } } } }, is_pressed);
                }
            }

            // Check Left Thumb (Left Stick) button
            if ((curr_buttons & GamepadButtons.LEFT_THUMB) != (prev_buttons & GamepadButtons.LEFT_THUMB)) {
                const is_pressed = (curr_buttons & GamepadButtons.LEFT_THUMB) != 0;
                std.debug.print("DEBUG: Gamepad Left Stick button {s}\n", .{if (is_pressed) "pressed" else "released"});
                if (is_pressed) {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .Stick, .side = .Left } } } }, is_pressed);
                } else {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .Stick, .side = .Left } } } }, is_pressed);
                }
            }

            // Check Right Thumb (Right Stick) button
            if ((curr_buttons & GamepadButtons.RIGHT_THUMB) != (prev_buttons & GamepadButtons.RIGHT_THUMB)) {
                const is_pressed = (curr_buttons & GamepadButtons.RIGHT_THUMB) != 0;
                std.debug.print("DEBUG: Gamepad Right Stick button {s}\n", .{if (is_pressed) "pressed" else "released"});
                if (is_pressed) {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .Stick, .side = .Right } } } }, is_pressed);
                } else {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .Stick, .side = .Right } } } }, is_pressed);
                }
            }

            if ((curr_buttons & GamepadButtons.LEFT_SHOULDER) != (prev_buttons & GamepadButtons.LEFT_SHOULDER)) {
                const is_pressed = (curr_buttons & GamepadButtons.LEFT_SHOULDER) != 0;
                std.debug.print("DEBUG: Gamepad Left Shoulder button {s}\n", .{if (is_pressed) "pressed" else "released"});
                //Implement left shoulder trigger binding
                if (is_pressed) {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .Shoulder, .side = .Left } } } }, is_pressed);
                } else {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .Shoulder, .side = .Left } } } }, is_pressed);
                }
            }

            // Check Right Shoulder button
            if ((curr_buttons & GamepadButtons.RIGHT_SHOULDER) != (prev_buttons & GamepadButtons.RIGHT_SHOULDER)) {
                const is_pressed = (curr_buttons & GamepadButtons.RIGHT_SHOULDER) != 0;
                std.debug.print("DEBUG: Gamepad Right Shoulder button {s}\n", .{if (is_pressed) "pressed" else "released"});
                // Implementation would create a ButtonBinding and call triggerBinding
                if (is_pressed) {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .Shoulder, .side = .Right } } } }, is_pressed);
                } else {
                    triggerBinding(input_state, Binding{ .ty = .Gamepad, .data = .{ .Gamepad = .{ .binding = GamepadBinding{ .button = .Shoulder, .side = .Right } } } }, is_pressed);
                }
            }

            std.debug.print("DEBUG: state {any}\n", .{state});

            if (@abs(state.Gamepad.bLeftTrigger) != 0) {
                std.debug.print("DEBUG: Left trigger: {d}\n", .{state.Gamepad.bLeftTrigger});
                const binding = Binding{ .ty = .Axis, .data = .{ .Axis = .{ .binding = AxisBinding{ .axis = .Z, .side = .Left, .ty = .Gamepad } } } };

                triggerAxisMovement(input_state, binding, @as(f32, @floatFromInt(state.Gamepad.bLeftTrigger)) / 256.0);
            }
            if (@abs(state.Gamepad.bRightTrigger) != 0) {
                std.debug.print("DEBUG: Right trigger: {d}\n", .{state.Gamepad.bRightTrigger});
                const binding = Binding{ .ty = .Axis, .data = .{ .Axis = .{ .binding = AxisBinding{ .axis = .Z, .side = .Right, .ty = .Gamepad } } } };

                triggerAxisMovement(input_state, binding, @as(f32, @floatFromInt(state.Gamepad.bRightTrigger)) / 256.0);
            }
            // Simplified stick movement check for debug
            if (@abs(state.Gamepad.sThumbRX) > 300) {
                std.debug.print("DEBUG: Left stick X: {d}\n", .{state.Gamepad.sThumbRX});
                const binding = Binding{ .ty = .Axis, .data = .{ .Axis = .{ .binding = AxisBinding{ .axis = .X, .side = .Right, .ty = .Gamepad } } } };

                triggerAxisMovement(input_state, binding, @as(f32, @floatFromInt(state.Gamepad.sThumbRX)) / 32768.0);
            }

            if (@abs(state.Gamepad.sThumbRY) > 300) {
                std.debug.print("DEBUG: Left stick Y: {d}\n", .{state.Gamepad.sThumbRY});
                const binding = Binding{ .ty = .Axis, .data = .{ .Axis = .{ .binding = AxisBinding{ .axis = .Y, .side = .Right, .ty = .Gamepad } } } };
                triggerAxisMovement(input_state, binding, @as(f32, @floatFromInt(state.Gamepad.sThumbRY)) / 32768.0);
            }

            if (@abs(state.Gamepad.sThumbLX) > 300) {
                std.debug.print("DEBUG: Right stick X: {d}\n", .{state.Gamepad.sThumbLX});
                const binding = Binding{ .ty = .Axis, .data = .{ .Axis = .{ .binding = AxisBinding{ .axis = .X, .side = .Left, .ty = .Gamepad } } } };
                triggerAxisMovement(input_state, binding, @as(f32, @floatFromInt(state.Gamepad.sThumbLX)) / 32768.0);
            }

            if (@abs(state.Gamepad.sThumbLY) > 300) {
                std.debug.print("DEBUG: Right stick Y: {d}\n", .{state.Gamepad.sThumbLY});
                const binding = Binding{ .ty = .Axis, .data = .{ .Axis = .{ .binding = AxisBinding{ .axis = .Y, .side = .Left, .ty = .Gamepad } } } };
                triggerAxisMovement(input_state, binding, @as(f32, @floatFromInt(state.Gamepad.sThumbLY)) / 32768.0);
            }

            // Save current state for next comparison
            prev_gamepad_states[controller_idx] = state;
        }
    }
}

// Process a gamepad button state change
fn processGamepadButton(input_state: *InputStateMap, controller_idx: usize, button_flag: u16, curr_buttons: u16, prev_buttons: u16, gamepad_button: mapping.GamepadButton) void {
    _ = input_state;
    const curr_state = (curr_buttons & button_flag) != 0;
    const prev_state = (prev_buttons & button_flag) != 0;

    // If state changed, trigger the binding
    if (curr_state != prev_state) {
        std.debug.print("DEBUG: processGamepadButton detected change for button {any} on controller {d}\n", .{ gamepad_button, controller_idx });
        // Implementation would create a ButtonBinding and call triggerBinding
    }
}

// Map key codes to our key enum
fn mapKeyToKey(key_code: u32) ?mapping.Key {
    std.debug.print("DEBUG: mapKeyToKey called for key code {d}\n", .{key_code});
    // Simple mapping table for debugging
    const KeyMapEntry = struct { code: u32, key: mapping.Key };
    const key_map = [_]KeyMapEntry{
        KeyMapEntry{ .code = 0x51, .key = .Q }, // Q
        KeyMapEntry{ .code = 0x57, .key = .W }, // W
        KeyMapEntry{ .code = 0x45, .key = .E }, // E
        KeyMapEntry{ .code = 0x20, .key = .Space }, // Space
    };

    for (key_map) |map| {
        if (map.code == key_code) {
            std.debug.print("DEBUG: Mapped key code {d} to {any}\n", .{ key_code, map.key });
            return map.key;
        }
    }

    std.debug.print("DEBUG: Failed to map key code {d}\n", .{key_code});
    return null;
}
