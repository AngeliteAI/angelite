pub extern fn inputInit(surface: *surface.Surface) void;
pub extern fn inputSetAction(binding: Binding, control: Control, user: *anyopaque) void;
pub extern fn inputPollActiveActions(actionBuffer: *Action, maxActions: usize) usize;
