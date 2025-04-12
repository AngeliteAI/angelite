const std = @import("std");
const Surface = @import("surface").include.surface.Surface;
const input = @import("input").include;
const ActionManager = input.ActionManager;
const Action = input.Action;

// Example user data structure
const PlayerInput = struct {
    move_x: f32 = 0,
    move_y: f32 = 0,
    is_jumping: bool = false,
    is_attacking: bool = false,
};

// Example of how to use the Action Manager API
pub fn main() !void {
    // Create a general purpose allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Create a surface (window)
    const surface = @import("surface").include.surface.createSurface();
    defer @import("surface").include.surface.destroySurface(surface);
    
    // Initialize input system
    input.state.inputInit(surface);
    
    // Create an action manager
    var manager = ActionManager.init(allocator);
    defer manager.deinit();
    
    // Create player input state
    var player_input = try allocator.create(PlayerInput);
    defer allocator.destroy(player_input);
    player_input.* = PlayerInput{};
    
    // Create actions for movement, jumping, and attacking
    const move_action_id = try manager.createAction("move");
    const jump_action_id = try manager.createAction("jump");
    const attack_action_id = try manager.createAction("attack");
    
    // Get pointers to the actions
    const move_action = manager.getAction(move_action_id).?;
    const jump_action = manager.getAction(jump_action_id).?;
    const attack_action = manager.getAction(attack_action_id).?;
    
    // Set user data for all actions
    move_action.setUserData(player_input);
    jump_action.setUserData(player_input);
    attack_action.setUserData(player_input);
    
    // Configure movement action with multiple bindings
    try move_action.addKeyboardBinding(.W, .Continuous);     // Keyboard W (forward)
    try move_action.addKeyboardBinding(.A, .Continuous);     // Keyboard A (left)
    try move_action.addKeyboardBinding(.S, .Continuous);     // Keyboard S (backward)
    try move_action.addKeyboardBinding(.D, .Continuous);     // Keyboard D (right)
    try move_action.addJoystickBinding(.X, .Left, 0.1);      // Left stick X-axis
    try move_action.addJoystickBinding(.Y, .Left, 0.1);      // Left stick Y-axis
    
    // Configure jump action
    try jump_action.addKeyboardBinding(.Space, .Activate);    // Keyboard Space
    try jump_action.addGamepadButtonBinding(.A, .Activate);   // Gamepad A button
    
    // Configure attack action
    try attack_action.addMouseButtonBinding(.Left, .Activate); // Mouse left button
    try attack_action.addGamepadButtonBinding(.X, .Activate);  // Gamepad X button
    
    // Register all configured actions with the input system
    manager.registerAllActions();
    
    // Main game loop
    const stdout = std.io.getStdOut().writer();
    var run = true;
    while (run) {
        // Reset inputs each frame
        player_input.move_x = 0;
        player_input.move_y = 0;
        player_input.is_jumping = false;
        player_input.is_attacking = false;
        
        // Poll for active actions
        var actions: [32]input.mapping.Action = undefined;
        const action_count = input.pollEvents(&actions[0], actions.len);
        
        // Process active actions
        for (0..action_count) |i| {
            const action = actions[i];
            const user_data = @as(*PlayerInput, @ptrCast(@alignCast(action.user)));
            
            switch (action.binding.ty) {
                .Button => {
                    const button_binding = action.binding.data.Button.binding;
                    const button_action = action.control.data.Button.action;
                    
                    // Handle keyboard WASD
                    if (button_binding.ty == .Keyboard) {
                        const key = button_binding.code.Keyboard.key;
                        if (button_action == .Activate or button_action == .Continuous) {
                            switch (key) {
                                .W => user_data.move_y = 1.0,
                                .A => user_data.move_x = -1.0,
                                .S => user_data.move_y = -1.0,
                                .D => user_data.move_x = 1.0,
                                .Space => user_data.is_jumping = true,
                                else => {},
                            }
                        }
                    } 
                    // Handle mouse buttons
                    else if (button_binding.ty == .Mouse) {
                        const button = button_binding.code.Mouse.button;
                        if (button == .Left and button_action == .Activate) {
                            user_data.is_attacking = true;
                        }
                    }
                    // Handle gamepad buttons
                    else if (button_binding.ty == .Gamepad) {
                        const button = button_binding.code.Gamepad.button;
                        if (button_action == .Activate) {
                            switch (button) {
                                .A => user_data.is_jumping = true,
                                .X => user_data.is_attacking = true,
                                else => {},
                            }
                        }
                    }
                },
                .Axis => {
                    const axis_binding = action.binding.data.Axis.binding;
                    const movement = action.control.data.Axis.movement;
                    
                    // Handle joystick
                    if (axis_binding.ty == .Joystick) {
                        if (axis_binding.axis == .X) {
                            user_data.move_x = movement;
                        } else if (axis_binding.axis == .Y) {
                            user_data.move_y = -movement; // Invert Y axis
                        }
                    }
                }
            }
        }
        
        // Display the current player input state
        try stdout.print("\rMove: ({d:.2}, {d:.2}) Jump: {} Attack: {}    ", .{
            player_input.move_x, 
            player_input.move_y, 
            player_input.is_jumping, 
            player_input.is_attacking
        });

        // Check if ESC was pressed to exit
        // In a real game, you would check for application quit events here
        
        // Sleep a bit to not hog the CPU
        std.time.sleep(16 * std.time.ns_per_ms); // ~60 FPS
    }
}