pub const surface = @import("surface");
pub const Binding = @import("mapping").Binding;
pub const Action = @import("mapping").Action;
pub const Control = @import("mapping").Control;

pub extern fn inputInit(surface: *surface.Surface) void;
pub extern fn inputSetAction(binding: Binding, control: Control, user: *anyopaque) void;
pub extern fn inputPollActiveActions(actionBuffer: [*]Action, maxActions: usize) usize;
