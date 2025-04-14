const std = @import("std");
const c = @cImport({
    @cInclude("stdint.h");
});
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

// C-compatible structures
pub const ActionId = extern struct {
    id: u32,
};

pub const InputAction = extern struct {
    id: u32,
    name: [64]u8,
    user_data: ?*anyopaque,
};

// ActionManager is not directly exposed to C, so we keep its Zig implementation
pub const ActionManager = struct {
    actions: std.StringHashMap(*InputAction),
    next_id: u32,
    allocator: std.mem.Allocator,

    pub fn new(allocator: std.mem.Allocator) *ActionManager {
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

    pub fn deleteAction(self: *ActionManager, id: ActionId) void {
        var it = self.actions.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.*.id == id.id) {
                // Free the memory for the action
                self.allocator.destroy(entry.value_ptr.*);
                // Remove from the hashmap
                _ = self.actions.remove(entry.key_ptr.*);
                return;
            }
        }
    }

    pub fn registerAllActions(self: *ActionManager) void {
        _ = self;
        // Implementation to be filled with standard actions if needed
    }
};

// Export C-compatible functions with explicit C calling convention
export fn createActionManager() callconv(.C) *anyopaque {
    return @ptrCast(ActionManager.new(std.heap.c_allocator));
}

export fn destroyActionManager(manager: *anyopaque) callconv(.C) void {
    const mgr = @as(*ActionManager, @ptrCast(@alignCast(manager)));
    var it = mgr.actions.valueIterator();
    while (it.next()) |action_ptr| {
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

export fn deleteAction(manager: *anyopaque, id: ActionId) callconv(.C) void {
    const mgr = @as(*ActionManager, @ptrCast(@alignCast(manager)));
    mgr.deleteAction(id);
}

export fn registerAllActions(manager: *anyopaque) callconv(.C) void {
    const mgr = @as(*ActionManager, @ptrCast(@alignCast(manager)));
    mgr.registerAllActions();
}

// Action user data
export fn setActionUserData(action: *anyopaque, user_data: ?*anyopaque) callconv(.C) void {
    const act = @as(*InputAction, @ptrCast(@alignCast(action)));
    act.user_data = user_data;
}

// Action binding functions
export fn addKeyboardBinding(action: *anyopaque, key: Key, action_type: ButtonAction) callconv(.C) bool {
    _ = action;
    _ = key;
    _ = action_type;
    // Placeholder implementation - return success
    return true;
}

export fn addMouseButtonBinding(action: *anyopaque, button: MouseButton, action_type: ButtonAction) callconv(.C) bool {
    _ = action;
    _ = button;
    _ = action_type;
    // Placeholder implementation - return success
    return true;
}

export fn addGamepadButtonBinding(action: *anyopaque, button: GamepadButton, action_type: ButtonAction) callconv(.C) bool {
    _ = action;
    _ = button;
    _ = action_type;
    // Placeholder implementation - return success
    return true;
}

export fn addMouseAxisBinding(action: *anyopaque, axis: Axis, threshold: f32) callconv(.C) bool {
    _ = action;
    _ = axis;
    _ = threshold;
    // Placeholder implementation - return success
    return true;
}

export fn addJoystickBinding(action: *anyopaque, axis: Axis, side: Side, threshold: f32) callconv(.C) bool {
    _ = action;
    _ = axis;
    _ = side;
    _ = threshold;
    // Placeholder implementation - return success
    return true;
}

export fn addTriggerBinding(action: *anyopaque, side: Side, threshold: f32) callconv(.C) bool {
    _ = action;
    _ = side;
    _ = threshold;
    // Placeholder implementation - return success
    return true;
}

export fn addScrollBinding(action: *anyopaque, axis: Axis, threshold: f32) callconv(.C) bool {
    _ = action;
    _ = axis;
    _ = threshold;
    // Placeholder implementation - return success
    return true;
}