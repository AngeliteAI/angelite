const std = @import("std");
const mapping = @import("mapping.zig");
const state = @import("state.zig");
const Allocator = std.mem.Allocator;

// An Action is a collection of bindings that all trigger the same callback
pub const ActionId = u32;

// Action manager that stores all actions
pub const ActionManager = struct {
    allocator: Allocator,
    actions: std.AutoHashMap(ActionId, *Action),
    next_id: ActionId,

    // Initialize the action manager
    pub fn init(allocator: Allocator) ActionManager {
        return ActionManager{
            .allocator = allocator,
            .actions = std.AutoHashMap(ActionId, *Action).init(allocator),
            .next_id = 1,
        };
    }

    // Clean up resources
    pub fn deinit(self: *ActionManager) void {
        var it = self.actions.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.actions.deinit();
    }

    // Create a new action and return its ID
    pub fn createAction(self: *ActionManager, name: []const u8) !ActionId {
        const id = self.next_id;
        self.next_id += 1;

        const action = try self.allocator.create(Action);
        action.* = Action.init(self.allocator, id, name);

        try self.actions.put(id, action);
        return id;
    }

    // Get an action by ID
    pub fn getAction(self: *ActionManager, id: ActionId) ?*Action {
        return self.actions.get(id);
    }

    // Delete an action
    pub fn deleteAction(self: *ActionManager, id: ActionId) void {
        if (self.actions.get(id)) |action| {
            action.deinit();
            self.allocator.destroy(action);
            _ = self.actions.remove(id);
        }
    }

    // Register all actions with the input system
    pub fn registerAllActions(self: *ActionManager) void {
        var it = self.actions.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.registerBindings();
        }
    }
};

// The Action struct that holds bindings and callbacks
pub const Action = struct {
    id: ActionId,
    name: []const u8,
    bindings: std.ArrayList(ActionBinding),
    user_data: ?*anyopaque,
    allocator: Allocator,

    // Initialize a new action
    pub fn init(allocator: Allocator, id: ActionId, name: []const u8) Action {
        return Action{
            .id = id,
            .name = allocator.dupe(u8, name) catch unreachable,
            .bindings = std.ArrayList(ActionBinding).init(allocator),
            .user_data = null,
            .allocator = allocator,
        };
    }

    // Clean up resources
    pub fn deinit(self: *Action) void {
        self.allocator.free(self.name);
        self.bindings.deinit();
    }

    // Set the user data for this action
    pub fn setUserData(self: *Action, user_data: *anyopaque) void {
        self.user_data = user_data;
    }

    // Add a keyboard binding
    pub fn addKeyboardBinding(self: *Action, key: mapping.Key, action: mapping.ButtonAction) !void {
        try self.bindings.append(ActionBinding{
            .binding = mapping.InputBinding{ .key = .{ .key = key } },
            .threshold = mapping.InputThreshold{ .button = action },
        });
    }

    // Add a mouse button binding
    pub fn addMouseButtonBinding(self: *Action, button: mapping.MouseButton, action: mapping.ButtonAction) !void {
        try self.bindings.append(ActionBinding{
            .binding = mapping.InputBinding{ .mouse_button = .{ .button = button } },
            .threshold = mapping.InputThreshold{ .button = action },
        });
    }

    // Add a gamepad button binding
    pub fn addGamepadButtonBinding(self: *Action, button: mapping.GamepadButton, action: mapping.ButtonAction) !void {
        try self.bindings.append(ActionBinding{
            .binding = mapping.InputBinding{ .gamepad_button = .{ .button = button } },
            .threshold = mapping.InputThreshold{ .button = action },
        });
    }

    // Add a mouse axis binding
    pub fn addMouseAxisBinding(self: *Action, axis: mapping.Axis, threshold: f32) !void {
        try self.bindings.append(ActionBinding{
            .binding = mapping.InputBinding{ .mouse_axis = .{ .axis = axis } },
            .threshold = mapping.InputThreshold{ .axis = threshold },
        });
    }

    // Add a joystick binding
    pub fn addJoystickBinding(self: *Action, axis: mapping.Axis, side: mapping.Side, threshold: f32) !void {
        try self.bindings.append(ActionBinding{
            .binding = mapping.InputBinding{ .joystick = .{ .axis = axis, .side = side } },
            .threshold = mapping.InputThreshold{ .axis = threshold },
        });
    }

    // Add a trigger binding
    pub fn addTriggerBinding(self: *Action, side: mapping.Side, threshold: f32) !void {
        try self.bindings.append(ActionBinding{
            .binding = mapping.InputBinding{ .trigger = .{ .side = side } },
            .threshold = mapping.InputThreshold{ .axis = threshold },
        });
    }

    // Add a scroll binding
    pub fn addScrollBinding(self: *Action, axis: mapping.Axis, threshold: f32) !void {
        try self.bindings.append(ActionBinding{
            .binding = mapping.InputBinding{ .scroll = .{ .axis = axis } },
            .threshold = mapping.InputThreshold{ .axis = threshold },
        });
    }

    // Register all bindings with the input system
    pub fn registerBindings(self: *Action) void {
        if (self.user_data == null) return;

        for (self.bindings.items) |binding| {
            const legacy_binding = mapping.convertToLegacyBinding(binding.binding);
            const legacy_control = mapping.convertToLegacyControl(binding.threshold);
            state.inputSetAction(legacy_binding, legacy_control, self.user_data.?);
        }
    }
};

// Structure to hold a binding and its threshold
const ActionBinding = struct {
    binding: mapping.InputBinding,
    threshold: mapping.InputThreshold,
};

// Helper functions to convert between ergonomic and legacy types
fn convertToLegacyBinding(binding: mapping.InputBinding) mapping.Binding {
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

fn convertToLegacyControl(threshold: mapping.InputThreshold) mapping.Control {
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
