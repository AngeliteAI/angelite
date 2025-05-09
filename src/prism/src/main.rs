#![no_std]
#![no_main]
use crate::ffi::{
    gfx::{render, surface},
    input::{
        action::ActionManager,
        state::{Action, Axis, ButtonAction, GamepadButton, InputState, Side},
    },
    math::{
        mat, quat,
        vec::{self, Vec3},
    },
};
use core::{f32::consts::PI, ptr};

mod ffi;

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    loop {}
}

// Configuration constants for flight controls
const MOVE_SPEED: f32 = 1.6; // Base movement speed
const ROTATION_SPEED: f32 = PI / 6.0; // Base rotation speed
const DEADZONE: f32 = 0.15; // Joystick deadzone

#[unsafe(no_mangle)]
fn main() {
    // Create a surface
    let surface_ptr = unsafe { surface::createSurface() };
    if surface_ptr.is_null() {
        return;
    }

    // Initialize the renderer with our surface
    let renderer_ptr = unsafe { render::init(surface_ptr) };
    let mut camera = render::Camera {
        position: unsafe { vec::v3(0.0, 0.1, -5.0) },
        rotation: unsafe { quat::qId() },
        projection: unsafe { mat::m4Persp(PI / 2.0, 1.0, 0.1, 100.0) },
    };
    if renderer_ptr.is_null() {
        unsafe {
            render::shutdown(renderer_ptr);
            surface::destroySurface(surface_ptr);
        };
        return;
    }

    // Initialize input system
    let input_state = InputState::new(surface_ptr);

    // Set up action manager for controller input
    let action_manager = ActionManager::new().unwrap();

    let left_trigger_id = action_manager.create_action("left_trigger").unwrap();
    let left_trigger = action_manager.get_action(left_trigger_id).unwrap();
    left_trigger
        .add_joystick_binding(Axis::Z, Side::Left, DEADZONE)
        .unwrap();

    let left_shoulder_id = action_manager.create_action("left_shoulder").unwrap();
    let left_shoulder = action_manager.get_action(left_shoulder_id).unwrap();
    left_shoulder
        .add_gamepad_button_with_side_binding(GamepadButton::Shoulder, Side::Left, ButtonAction::Activate)
        .unwrap();

    let right_trigger_id = action_manager.create_action("right_trigger").unwrap();
    let right_trigger = action_manager.get_action(right_trigger_id).unwrap();
    right_trigger
        .add_joystick_binding(Axis::Z, Side::Right, DEADZONE)
        .unwrap();
        
        

    // Define navigation actions (Space Engineers style)
    let move_forward_id = action_manager.create_action("move_forward").unwrap();
    let move_forward = action_manager.get_action(move_forward_id).unwrap();
    move_forward
        .add_joystick_binding(Axis::Y, Side::Left, DEADZONE)
        .unwrap(); // Left joystick Y-axis for forward/backward

    let move_backward_id = action_manager.create_action("move_backward").unwrap();
    let move_backward = action_manager.get_action(move_backward_id).unwrap();
    move_backward
        .add_gamepad_button_with_side_binding(GamepadButton::Stick, Side::Left, ButtonAction::Activate).unwrap();

    let move_right_id = action_manager.create_action("move_right").unwrap();
    let move_right = action_manager.get_action(move_right_id).unwrap();
    move_right
        .add_joystick_binding(Axis::X, Side::Left, DEADZONE)
        .unwrap(); // Left joystick X-axis for left/right

    let move_up_id = action_manager.create_action("move_up").unwrap();
    let move_up = action_manager.get_action(move_up_id).unwrap();
    move_up
        .add_gamepad_button_with_side_binding(GamepadButton::Shoulder, Side::Right, ButtonAction::Activate)
        .unwrap(); // Right shoulder to move up

    let move_down_id = action_manager.create_action("move_down").unwrap();
    let move_down = action_manager.get_action(move_down_id).unwrap();
    move_down
        .add_gamepad_button_with_side_binding(GamepadButton::Shoulder, Side::Left, ButtonAction::Activate)
        .unwrap(); // Left shoulder to move down

    let look_right_id = action_manager.create_action("look_right").unwrap();
    let look_right = action_manager.get_action(look_right_id).unwrap();
    look_right
        .add_joystick_binding(Axis::X, Side::Right, DEADZONE)
        .unwrap(); // Right joystick X-axis to look left/right

    let look_up_id = action_manager.create_action("look_up").unwrap();
    let look_up = action_manager.get_action(look_up_id).unwrap();
    look_up
        .add_joystick_binding(Axis::Y, Side::Right, DEADZONE)
        .unwrap(); // Right joystick Y-axis to look up/down

    let devmode_id = action_manager.create_action("devmode").unwrap();
    let devmode = action_manager.get_action(devmode_id).unwrap();
    devmode
        .add_gamepad_button_binding(GamepadButton::A, ButtonAction::Activate)
        .unwrap();

    // Also add keyboard bindings (WASD + arrows)
    move_forward
        .add_keyboard_binding(crate::ffi::input::state::Key::W, ButtonAction::Activate)
        .unwrap();
    move_right
        .add_keyboard_binding(crate::ffi::input::state::Key::D, ButtonAction::Activate)
        .unwrap();
    action_manager
        .get_action(move_forward_id)
        .unwrap()
        .add_keyboard_binding(crate::ffi::input::state::Key::S, ButtonAction::Activate)
        .unwrap();
    action_manager
        .get_action(move_right_id)
        .unwrap()
        .add_keyboard_binding(crate::ffi::input::state::Key::A, ButtonAction::Activate)
        .unwrap();

    // Register all actions with the input system

    // Prepare buffer for collecting input actions each frame
    const MAX_ACTIONS: usize = 32;
    let mut action_buffer = [unsafe { core::mem::zeroed::<Action>() }; MAX_ACTIONS];

    // Main game loop
    loop {
        // Poll for window events
        unsafe { surface::pollSurface() };

        // Get window size for aspect ratio
        let mut width = 0;
        let mut height = 0;
        unsafe {
            surface::getSize(surface_ptr, &mut width, &mut height);
        }

        // Update camera projection with current aspect ratio
        camera.projection =
            unsafe { mat::m4Persp(PI / 2.0, (width as f32) / (height as f32), 0.1, 100.0) };

        // Poll for input actions
        let action_count = input_state.poll_actions(&mut action_buffer);

        // Process input actions for camera movement
        let mut movement = unsafe { vec::v3Zero() };
        let mut rotation = unsafe { vec::v3Zero() };

        for i in 0..action_count {
            let action = action_buffer[i];
            let user_ptr = action.user;

            // Pattern match on the action's binding type and data
            unsafe {
                match action.binding.ty {
                    crate::ffi::input::state::BindingType::Button => {
                        // Handle button actions
                        let button_data = action.binding.data.button;
                        match button_data.binding.ty {
                            crate::ffi::input::state::InputType::Gamepad => {
                                let button = button_data.binding.code.gamepad.button;
                                if button == GamepadButton::A {
                                    panic!("");
                                }
                            }
                            crate::ffi::input::state::InputType::Keyboard => {
                                let key = button_data.binding.code.keyboard.key;
                                // You could handle keyboard controls here too
                            }
                            _ => {}
                        }
                    }
                    crate::ffi::input::state::BindingType::Gamepad => {
                        // Handle gamepad buttons using the new binding type
                        let gamepad_data = action.binding.data.gamepad;
                        let button = gamepad_data.binding.button;
                        let side = gamepad_data.binding.side;
                        
                        if button == GamepadButton::A {
                            unsafe { render::hotReload(renderer_ptr) };
                        } else if button == GamepadButton::Stick {
                            if side == Side::Left {
                                movement.y -= 1.0;
                            }
                        } else if button == GamepadButton::Shoulder {
                            if side == Side::Right {
                                // Right shoulder button
                                rotation.z -= 0.1;
                            } else if side == Side::Left {
                                // Left shoulder button
                                rotation.z += 0.1;
                            }
                        }
                    }
                    crate::ffi::input::state::BindingType::Axis => {
                        // Handle axis actions
                        let axis_data = action.binding.data.axis;
                        let axis_movement = action.control.data.axis.movement;

                        if axis_data.binding.ty == crate::ffi::input::state::InputType::Gamepad {
                            match axis_data.binding.side {
                                Side::Left => {
                                    // Left joystick controls movement
                                    if axis_data.binding.axis == Axis::X {
                                        // Strafe left/right
                                        movement.x += axis_movement * MOVE_SPEED;
                                    } else if axis_data.binding.axis == Axis::Y {
                                        // Move forward/backward
                                        movement.y -= axis_movement * MOVE_SPEED;
                                    } else if axis_data.binding.axis == Axis::Z {
                                        // Move up/down
                                        movement.z += axis_movement * MOVE_SPEED;
                                    }
                                }
                                Side::Right => {
                                    // Right joystick controls rotation
                                    if axis_data.binding.axis == Axis::X {
                                        // Rotate left/right (yaw)
                                        rotation.y += axis_movement * ROTATION_SPEED;
                                    } else if axis_data.binding.axis == Axis::Y {
                                        // Rotate up/down (pitch)
                                        rotation.x -= axis_movement * ROTATION_SPEED;
                                    }
                                }
                                _ => {}
                            }
                        }
                    }
                }
            }
        }

        // Apply rotation (create rotation quaternion from euler angles)
        if rotation.x != 0.0 || rotation.y != 0.0 || rotation.z != 0.0 {
            // Create rotation quaternion from our input
            let rot_quat = unsafe { quat::qEuler(rotation.x, rotation.y, rotation.z) };
            // Combine with existing rotation
            camera.rotation = unsafe { quat::qMul(camera.rotation, rot_quat) };
            // Normalize to prevent drift
            camera.rotation = unsafe { quat::qNorm(camera.rotation) };
        }

        // Apply movement in world space by transforming with the camera's rotation
        if movement.x != 0.0 || movement.y != 0.0 || movement.z != 0.0 {
            // Transform the movement vector using the camera's rotation to get world-space movement
            let rotated_movement = unsafe { quat::qRotV3(camera.rotation, movement) };
            // Apply the movement to the camera's position
            camera.position = unsafe { vec::v3Add(camera.position, rotated_movement) };
        }

        // Set the updated camera
        unsafe {
            render::setCamera(renderer_ptr, &camera);
        }

        // Render the frame
        unsafe { render::render(renderer_ptr) };
    }

    // // Cleanup (in a real app, we'd need to handle Ctrl+C/signal interruption)
    // unsafe {
    //     render::shutdown(renderer_ptr);
    //     surface::destroySurface(surface_ptr);
    // }
}
