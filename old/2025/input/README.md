# Angelite Input Library

A cross-platform input handling library that provides a simple, ergonomic API for managing user inputs from keyboards, mice, and game controllers.

## Features

- Multi-platform support (Windows, macOS, Linux)
- Keyboard, mouse, and Xbox controller support
- High-level action manager API for intuitive input mapping
- Low-level access to raw input events when needed
- Threshold-based filtering for smooth control

## Quick Start

```zig
// Initialize with a surface
const surface = createSurface();
input.init(surface);

// Create an action manager
var manager = input.createActionManager();
defer manager.deinit();

// Create a "move" action
const move_id = try manager.createAction("move");
const move = manager.getAction(move_id).?;

// Set up player state
var player = try allocator.create(PlayerState);
move.setUserData(player);

// Add multiple bindings to the same action
try move.addKeyboardBinding(.W, .Continuous);     // Keyboard forward
try move.addKeyboardBinding(.S, .Continuous);     // Keyboard backward
try move.addJoystickBinding(.Y, .Left, 0.1);      // Left stick Y-axis

// Register all actions
manager.registerAllActions();

// In game loop:
var actions: [32]Action = undefined;
const count = input.pollEvents(&actions[0], actions.len);
```

## Action Manager API

The Action Manager provides a convenient way to bind multiple inputs to the same logical action:

```zig
// Create actions
const jump_id = try manager.createAction("jump");
const jump = manager.getAction(jump_id).?;

// Configure with multiple bindings
try jump.addKeyboardBinding(.Space, .Activate);    // Keyboard Space
try jump.addGamepadButtonBinding(.A, .Activate);   // Gamepad A button
```

## Supported Input Types

- **Keyboard**: All standard keys with press/release events
- **Mouse**: Button clicks and cursor movement
- **Xbox Controller**: Face buttons, shoulders, triggers, sticks

## Platform Support

- **Windows**: Full support via Win32 API and XInput
- **macOS**: Supported via Swift/Metal bindings
- **Linux**: Supported via XCB

## License

See the LICENSE file for details.