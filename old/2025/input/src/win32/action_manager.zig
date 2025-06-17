const std = @import("std");
const c = @cImport({
    @cInclude("stdint.h");
});
const stateMod = @import("state.zig");
const mapping = @import("include").mapping;
// Import types from mapping to ensure consistency with state.zig
const Key = mapping.Key;
const ButtonAction = mapping.ButtonAction;
const MouseButton = mapping.MouseButton;
const GamepadButton = mapping.GamepadButton;
const Axis = mapping.Axis;
const Side = mapping.Side;
const Control = mapping.Control;
const Binding = mapping.Binding;
const Action = mapping.Action;
const AxisBinding = mapping.AxisBinding;
const ButtonBinding = mapping.ButtonBinding;

// C-compatible structures
pub const ActionId = extern struct {
    id: u32,
};

pub const InputAction = struct {
    id: u32,
    name: [64]u8,
    bindings: std.ArrayList(Binding),
    user_data: ?*anyopaque,
};

// ActionManager is not directly exposed to C, so we keep its Zig implementation
pub const ActionManager = struct {
    actions: std.StringHashMap(*InputAction),
    next_id: u32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) *ActionManager {
        const manager = allocator.create(ActionManager) catch unreachable;
        manager.* = ActionManager{
            .actions = std.StringHashMap(*InputAction).init(allocator),
            .next_id = 1, // Start IDs at 1
            .allocator = allocator,
        };
        return manager;
    }

    pub fn createAction(self: *ActionManager, name: [*:0]const u8, name_len: usize) ActionId {
        const id = self.next_id;
        self.next_id += 1;

        var action = self.allocator.create(InputAction) catch unreachable;
        action.* = InputAction{
            .id = id,
            .name = undefined,
            .bindings = std.ArrayList(Binding).init(self.allocator),
            .user_data = null,
        };

        // Copy name to action (limited by name_len and max size)
        const copy_len = @min(name_len, 63);
        var i: usize = 0;
        while (i < copy_len and name[i] != 0) : (i += 1) {
            action.name[i] = name[i];
        }
        action.name[i] = 0; // Null terminate

        // Store action in hashmap using its ID as key
        const name_slice = std.mem.span(name);
        self.actions.put(name_slice, action) catch unreachable;

        return ActionId{ .id = id };
    }

    pub fn getAction(self: *ActionManager, id: ActionId) ?*InputAction {
        var it = self.actions.valueIterator();
        while (it.next()) |action_ptr| {
            if (action_ptr.*.id == id.id) {
                return action_ptr.*;
            }
        }
        return null;
    }

    pub fn getActionByName(self: *ActionManager, name: []const u8) ?*InputAction {
        return self.actions.get(name);
    }

    pub fn deleteAction(self: *ActionManager, id: ActionId) void {
        var it = self.actions.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.*.id == id.id) {
                // Free bindings
                entry.value_ptr.*.bindings.deinit();
                // Free the memory for the action
                self.allocator.destroy(entry.value_ptr.*);
                // Remove from the hashmap
                _ = self.actions.remove(entry.key_ptr.*);
                return;
            }
        }
    }

    pub fn addBindingToAction(self: *ActionManager, id: ActionId, binding: Binding) bool {
        if (self.getAction(id)) |action| {
            // Check if binding already exists
            for (action.bindings.items) |existing_binding| {
                if (mapping.binding_eql(existing_binding, binding)) {
                    return false; // Binding already exists
                }
            }

            // Add the new binding
            action.bindings.append(binding) catch {
                return false;
            };
            return true;
        }
        return false;
    }

    pub fn removeBindingFromAction(self: *ActionManager, id: ActionId, binding: Binding) bool {
        if (self.getAction(id)) |action| {
            for (action.bindings.items, 0..) |existing_binding, index| {
                if (mapping.binding_eql(existing_binding, binding)) {
                    _ = action.bindings.orderedRemove(index);
                    return true;
                }
            }
        }
        return false;
    }

    pub fn clearBindings(self: *ActionManager, id: ActionId) bool {
        if (self.getAction(id)) |action| {
            action.bindings.clearRetainingCapacity();
            return true;
        }
        return false;
    }
};

// Export C-compatible functions with explicit C calling convention
export fn createActionManager() callconv(.C) *anyopaque {
    const actionManager = ActionManager.init(std.heap.c_allocator);
    stateMod.global_input_state.?.put(stateMod.windowHandle, stateMod.InputStateMap{
        .surface = stateMod.windowSurface,
        .actionManager = actionManager,
    }) catch |err| {
        std.debug.print("ERROR: Failed to put input state map: {s}\n", .{@errorName(err)});
        unreachable;
    };
    return @ptrCast(actionManager);
}

export fn destroyActionManager(manager: *anyopaque) callconv(.C) void {
    const mgr = @as(*ActionManager, @ptrCast(@alignCast(manager)));
    var it = mgr.actions.valueIterator();
    while (it.next()) |action_ptr| {
        action_ptr.*.bindings.deinit();
        mgr.allocator.destroy(action_ptr.*);
    }
    mgr.actions.deinit();
    mgr.allocator.destroy(mgr);
}

export fn createAction(manager: *anyopaque, name: [*c]const u8, name_len: usize) callconv(.C) ActionId {
    const mgr = @as(*ActionManager, @ptrCast(@alignCast(manager)));
    return mgr.createAction(@ptrCast(name), name_len);
}

export fn getAction(manager: *anyopaque, id: ActionId) callconv(.C) ?*anyopaque {
    const mgr = @as(*ActionManager, @ptrCast(@alignCast(manager)));
    if (mgr.getAction(id)) |action| {
        return @ptrCast(action);
    }
    return null;
}

export fn getActionByName(manager: *anyopaque, name: [*c]const u8, name_len: usize) callconv(.C) ?*anyopaque {
    const mgr = @as(*ActionManager, @ptrCast(@alignCast(manager)));
    const name_slice = name[0..name_len];
    if (mgr.getActionByName(name_slice)) |action| {
        return @ptrCast(action);
    }
    return null;
}

export fn deleteAction(manager: *anyopaque, id: ActionId) callconv(.C) void {
    const mgr = @as(*ActionManager, @ptrCast(@alignCast(manager)));
    mgr.deleteAction(id);
}

// Action user data
export fn setActionUserData(action: *anyopaque, user_data: ?*anyopaque) callconv(.C) void {
    const act = @as(*InputAction, @ptrCast(@alignCast(action)));
    act.user_data = user_data;
}

// // Action binding functions
export fn addKeyboardBinding(action: *anyopaque, key: Key, action_type: ButtonAction) callconv(.C) bool {
    _ = action;
    _ = key;
    _ = action_type;
    return true;
    //     const act = @as(*InputAction, @ptrCast(@alignCast(action)));

    //     // Create a new keyboard binding
    //     const binding = Binding{ .ty = .Button, .data = .{ .Button = .{
    //         .binding = ButtonBinding{
    //             .button = .{ .Key = key },
    //             .ty = .Keyboard,
    //         },
    //         .action = action_type,
    //     } } };

    //     // Check if binding already exists
    //     for (act.bindings.items) |existing| {
    //         if (mapping.binding_eql(existing, binding)) {
    //             return false;
    //         }
    //     }

    //     // Add the binding
    //     act.bindings.append(binding) catch {
    //         return false;
    //     };

    //     return true;
}

export fn addMouseButtonBinding(action: *anyopaque, button: MouseButton, action_type: ButtonAction) callconv(.C) bool {
    _ = action;
    _ = button;
    _ = action_type;
    return true;
    //     const act = @as(*InputAction, @ptrCast(@alignCast(action)));

    //     // Create a new mouse button binding
    //     const binding = Binding{ .ty = .Button, .data = .{ .Button = .{
    //         .binding = ButtonBinding{
    //             .button = .{ .MouseButton = button },
    //             .ty = .Mouse,
    //         },
    //         .action = action_type,
    //     } } };

    //     // Check if binding already exists
    //     for (act.bindings.items) |existing| {
    //         if (mapping.binding_eql(existing, binding)) {
    //             return false;
    //         }
    //     }

    //     // Add the binding
    //     act.bindings.append(binding) catch {
    //         return false;
    //     };

    //     return true;
}

export fn addGamepadButtonBinding(action: *anyopaque, button: GamepadButton, action_type: ButtonAction) callconv(.C) bool {
    _ = action_type; // Not actually used right now
    const act = @as(*InputAction, @ptrCast(@alignCast(action)));

    // Print what we're about to add
    std.debug.print("Adding gamepad button binding for button: {any}\n", .{button});

    // Create a new gamepad button binding with the correct type
    const binding = Binding{
        .ty = .Gamepad, // MUST match the type we actually use in triggerBinding
        .data = .{
            .Gamepad = .{
                .binding = mapping.GamepadBinding{
                    .button = button,
                    .side = .None,
                },
            },
        },
    };

    // Add the binding
    act.bindings.append(binding) catch {
        return false;
    };

    return true;
}

export fn addMouseAxisBinding(action: *anyopaque, axis: Axis, threshold: f32) callconv(.C) bool {
    _ = threshold;
    const act = @as(*InputAction, @ptrCast(@alignCast(action)));

    // Create a new mouse axis binding
    const binding = Binding{ .ty = .Axis, .data = .{ .Axis = .{
        .binding = AxisBinding{
            .axis = axis,
            .side = .None,
            .ty = .Mouse,
        },
    } } };

    // Check if binding already exists
    for (act.bindings.items) |existing| {
        if (mapping.binding_eql(existing, binding)) {
            return false;
        }
    }

    // Add the binding
    act.bindings.append(binding) catch {
        return false;
    };

    return true;
}

export fn addJoystickBinding(action: *anyopaque, axis: Axis, side: Side, threshold: f32) callconv(.C) bool {
    _ = threshold;
    const act = @as(*InputAction, @ptrCast(@alignCast(action)));

    // Create a new joystick/gamepad axis binding
    const binding = Binding{
        .ty = .Axis,
        .data = .{
            .Axis = .{
                .binding = AxisBinding{
                    .axis = axis,
                    .side = side,
                    .ty = .Gamepad, // We treat joysticks and gamepads the same
                },
            },
        },
    };

    // Check if binding already exists
    for (act.bindings.items) |existing| {
        if (mapping.binding_eql(existing, binding)) {
            return false;
        }
    }

    // Add the binding
    act.bindings.append(binding) catch {
        return false;
    };

    //Now add binding to state

    std.debug.print("successfully added joystick, {any}", .{binding});
    return true;
}

export fn addTriggerBinding(action: *anyopaque, side: Side, threshold: f32) callconv(.C) bool {
    _ = threshold;
    const act = @as(*InputAction, @ptrCast(@alignCast(action)));

    // Create a new trigger binding (treated as special case of joystick/gamepad)
    const binding = Binding{ .ty = .Axis, .data = .{ .Axis = .{
        .binding = AxisBinding{
            .axis = .Z,
            .side = side,
            .ty = .Gamepad,
        },
    } } };

    // Check if binding already exists
    for (act.bindings.items) |existing| {
        if (mapping.binding_eql(existing, binding)) {
            return false;
        }
    }

    // Add the binding
    act.bindings.append(binding) catch {
        return false;
    };

    return true;
}

export fn addScrollBinding(action: *anyopaque, axis: Axis, threshold: f32) callconv(.C) bool {
    _ = threshold;
    const act = @as(*InputAction, @ptrCast(@alignCast(action)));

    // Create a new scroll binding
    const binding = Binding{
        .ty = .Axis,
        .data = .{
            .Axis = .{
                .binding = AxisBinding{
                    .axis = axis,
                    .side = .None,
                    .ty = .Mouse, // Scroll is a special case of mouse input
                },
            },
        },
    };

    // Check if binding already exists
    for (act.bindings.items) |existing| {
        if (mapping.binding_eql(existing, binding)) {
            return false;
        }
    }

    // Add the binding
    act.bindings.append(binding) catch {
        return false;
    };

    return true;
}

// Helper functions for action management
export fn clearBindings(action: *anyopaque) callconv(.C) void {
    const act = @as(*InputAction, @ptrCast(@alignCast(action)));
    act.bindings.clearRetainingCapacity();
}

export fn getBindingCount(action: *anyopaque) callconv(.C) usize {
    const act = @as(*InputAction, @ptrCast(@alignCast(action)));
    return act.bindings.items.len;
}

export fn getActionName(action: *anyopaque, buffer: [*c]u8, buffer_size: usize) callconv(.C) usize {
    const act = @as(*InputAction, @ptrCast(@alignCast(action)));

    var i: usize = 0;
    while (i < buffer_size - 1 and act.name[i] != 0) : (i += 1) {
        buffer[i] = act.name[i];
    }
    buffer[i] = 0;

    return i;
}

export fn addGamepadButtonWithSideBinding(action: *anyopaque, button: GamepadButton, side: Side, action_type: ButtonAction) callconv(.C) bool {
    _ = action_type; // Not actually used right now
    const act = @as(*InputAction, @ptrCast(@alignCast(action)));

    // Print what we're about to add
    std.debug.print("Adding gamepad button binding for button: {any} with side: {any}\n", .{ button, side });

    // Create a new gamepad button binding with side specification
    const binding = Binding{
        .ty = .Gamepad, // MUST match the type we actually use in triggerBinding
        .data = .{
            .Gamepad = .{
                .binding = mapping.GamepadBinding{
                    .button = button,
                    .side = side,
                },
            },
        },
    };

    // Add the binding
    act.bindings.append(binding) catch {
        return false;
    };

    return true;
}
