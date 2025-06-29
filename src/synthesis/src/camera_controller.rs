use major::math::{Vec3f, Quat, Mat4f, Mat3f};
use major::engine::{Engine, Binding};
use major::physx::{Physx, Rigidbody};

// Helper trait to add Euler conversion to Quaternion
trait QuatEulerExt {
    fn to_euler_zyx(&self) -> (f32, f32, f32);
}

impl QuatEulerExt for Quat {
    fn to_euler_zyx(&self) -> (f32, f32, f32) {
        // Extract quaternion components
        let x = self.x();
        let y = self.y();
        let z = self.z();
        let w = self.1; // scalar part
        
        // Convert to Euler angles (Z-Y-X order: yaw, pitch, roll)
        let sinr_cosp = 2.0 * (w * x + y * z);
        let cosr_cosp = 1.0 - 2.0 * (x * x + y * y);
        let roll = sinr_cosp.atan2(cosr_cosp);
        
        let sinp = 2.0 * (w * y - z * x);
        let pitch = if sinp.abs() >= 1.0 {
            std::f32::consts::FRAC_PI_2.copysign(sinp)
        } else {
            sinp.asin()
        };
        
        let siny_cosp = 2.0 * (w * z + x * y);
        let cosy_cosp = 1.0 - 2.0 * (y * y + z * z);
        let yaw = siny_cosp.atan2(cosy_cosp);
        
        (yaw, pitch, roll)
    }
}

// PID Controller trait for vectors
trait PIDVec: Sized + Copy {
    fn zero() -> Self;
    fn scale(self, s: f32) -> Self;
    fn add(self, other: Self) -> Self;
    fn sub(self, other: Self) -> Self;
    fn clamp_magnitude(self, max: f32) -> Self;
}

impl PIDVec for Vec3f {
    fn zero() -> Self { Vec3f::ZERO }
    fn scale(self, s: f32) -> Self { self * s }
    fn add(self, other: Self) -> Self { self + other }
    fn sub(self, other: Self) -> Self { self - other }
    fn clamp_magnitude(self, max: f32) -> Self {
        let mag = self.length();
        if mag > max { self.normalize() * max } else { self }
    }
}

// Generic PID Controller for any vector type
#[derive(Clone, Copy)]
struct PIDController<T: PIDVec> {
    kp: f32,  // Proportional gain
    ki: f32,  // Integral gain
    kd: f32,  // Derivative gain
    integral: T,
    last_error: T,
    max_integral_magnitude: f32,
}

impl<T: PIDVec> PIDController<T> {
    fn new(kp: f32, ki: f32, kd: f32) -> Self {
        Self {
            kp,
            ki,
            kd,
            integral: T::zero(),
            last_error: T::zero(),
            max_integral_magnitude: 5.0,  // Increased for better steady-state response
        }
    }
    
    fn update(&mut self, error: T, dt: f32) -> T {
        // Proportional term
        let p = error.scale(self.kp);
        
        // Integral term with anti-windup
        self.integral = self.integral.add(error.scale(dt));
        self.integral = self.integral.clamp_magnitude(self.max_integral_magnitude);
        let i = self.integral.scale(self.ki);
        
        // Derivative term (using error change, not last_error - error)
        let d = if dt > 0.0 {
            error.sub(self.last_error).scale(self.kd / dt)
        } else {
            T::zero()
        };
        
        self.last_error = error;
        
        p.add(i).add(d)
    }
    
    fn reset(&mut self) {
        self.integral = T::zero();
        self.last_error = T::zero();
    }
}

pub struct CameraController {
    position: Vec3f,
    rotation: Quat,
    velocity: Vec3f,
    angular_velocity: Vec3f,
    
    // Target state for PID control
    target_velocity: Vec3f,
    target_angular_velocity: Vec3f,
    
    // PID controllers
    linear_pid: PIDController<Vec3f>,
    angular_pid: PIDController<Vec3f>,
    
    // Movement settings
    move_acceleration: f32,
    max_speed: f32,
    boost_multiplier: f32,
    precision_multiplier: f32,
    rotate_speed: f32,
    
    // Physics
    linear_damping: f32,
    angular_damping: f32,
    physics_body: Option<*mut Rigidbody>,
    
    // Dead zones
    stick_deadzone: f32,
    
    // Mouse state
    last_mouse_pos: Option<(f32, f32)>,
    mouse_sensitivity: f32,
    
    // Control mode
    is_boosting: bool,
    is_precision: bool,
}

impl CameraController {
    pub fn new() -> Self {
        // Position camera at (5, -5, 5) looking at origin
        // In our coordinate system: X=East, Y=North, Z=Up
        Self::new_look_at(Vec3f::xyz(0.0, -5.0, 5.0), Vec3f::ZERO, Vec3f::Z)
    }
    
    pub fn new_look_at(position: Vec3f, target: Vec3f, up: Vec3f) -> Self {
        // Create look-at rotation
        let rotation = Quat::look_at(position, target, up);
        
        println!("Initial camera at [{:.1}, {:.1}, {:.1}] looking at [{:.1}, {:.1}, {:.1}]", 
                 position[0], position[1], position[2], target[0], target[1], target[2]);
        
        // Calculate expected direction
        let expected_forward = (target - position).normalize();
        println!("Expected forward direction: [{:.3}, {:.3}, {:.3}]", expected_forward[0], expected_forward[1], expected_forward[2]);
        
        // Verify the rotation (X+ right, Y+ forward, Z+ up)
        let forward = rotation * Vec3f::Y;
        let right = rotation * Vec3f::X;
        let up_dir = rotation * Vec3f::Z;
        println!("Camera forward: [{:.3}, {:.3}, {:.3}]", forward[0], forward[1], forward[2]);
        println!("Camera right: [{:.3}, {:.3}, {:.3}]", right[0], right[1], right[2]);
        println!("Camera up: [{:.3}, {:.3}, {:.3}]", up_dir[0], up_dir[1], up_dir[2]);
        
        // Log initial Euler angles
        let euler = rotation.to_euler_zyx();
        println!("Initial rotation (Euler ZYX): [Yaw: {:.1}°, Pitch: {:.1}°, Roll: {:.1}°]",
                 euler.0.to_degrees(), euler.1.to_degrees(), euler.2.to_degrees());
        
        // Test view matrix application
        let view_forward = (position - target);
        let view_result = rotation * view_forward;
        println!("Test: rotating view vector [{:.3}, {:.3}, {:.3}] -> [{:.3}, {:.3}, {:.3}]", 
                 view_forward[0], view_forward[1], view_forward[2],
                 view_result[0], view_result[1], view_result[2]);
        
        Self {
            position,
            rotation,
            velocity: Vec3f::ZERO,
            angular_velocity: Vec3f::ZERO,
            
            target_velocity: Vec3f::ZERO,
            target_angular_velocity: Vec3f::ZERO,
            
            // PID controllers tuned for space suit behavior
            // Linear: Much higher P gain for responsive feel, small I for drift compensation, negative D for damping
            linear_pid: PIDController::new(8.0, 0.05, -0.3),
            // Angular: Very high P gain for snappy rotation, negative D for smooth stops
            angular_pid: PIDController::new(50.0, 0.1, -1.5),
            
            // Space Engineers-like settings
            move_acceleration: 50.0,   // m/s² - reduced for smoother acceleration
            max_speed: 10.0,          // m/s - much more reasonable max speed
            boost_multiplier: 3.0,
            precision_multiplier: 0.25,
            rotate_speed: 2.0,        // rad/s - reasonable rotation speed
            
            // Physics damping (higher = more drag)
            linear_damping: 10.0,
            angular_damping: 5.0,  // Moderate damping for smooth rotation
            physics_body: None,
            
            // Dead zones
            stick_deadzone: 0.15,
            
            last_mouse_pos: None,
            mouse_sensitivity: 10.0,  // Balanced sensitivity  // Increased for normalized coords
            
            is_boosting: false,
            is_precision: false,
        }
    }
    
    pub fn init_physics(&mut self, physx: &dyn Physx) {
        // Create physics body for camera
        let body = physx.rigidbody_create();
        if !body.is_null() {
            // Set camera as dynamic body with small mass
            physx.rigidbody_mass(body, 10.0);
            physx.rigidbody_friction(body, 0.5);
            physx.rigidbody_restitution(body, 0.1);
            physx.rigidbody_linear_damping(body, 0.98);
            physx.rigidbody_angular_damping(body, 0.9);  // Higher angular damping to prevent spinning
            physx.rigidbody_set_half_extents(body, Vec3f::xyz(0.25, 0.25, 0.5)); // Small capsule-like shape
            physx.rigidbody_angular_moment(body, Vec3f::xyz(0.5, 0.5, 0.5)); // Moderate moment of inertia
            physx.rigidbody_center_of_mass(body, Vec3f::ZERO); // Center of mass at body origin
            
            // Set initial position and orientation
            physx.rigidbody_reposition(body, self.position);
            physx.rigidbody_orient(body, self.rotation);
            
            self.physics_body = Some(body);
            let euler = self.rotation.to_euler_zyx();
            println!("Camera physics body initialized:");
            println!("  Position: [{:.2}, {:.2}, {:.2}]", self.position[0], self.position[1], self.position[2]);
            println!("  Rotation: [Yaw: {:.1}°, Pitch: {:.1}°, Roll: {:.1}°]", 
                     euler.0.to_degrees(), euler.1.to_degrees(), euler.2.to_degrees());
        }
    }
    
    pub fn update(&mut self, engine: &dyn Engine, delta_time: f32) {
        // Clamp delta time to prevent division by zero and extreme values
        let delta_time = delta_time.max(0.0001).min(0.1);
        // Get raw input values
        let raw_move_h = unsafe { engine.input_binding_data(Binding::MoveHorizontal).scalar };
        let raw_move_v = unsafe { engine.input_binding_data(Binding::MoveVertical).scalar };
        let cursor_pos = unsafe { engine.input_binding_data(Binding::Cursor).pos };
        
        // Apply dead zone to stick input
        let move_h = self.apply_deadzone(raw_move_h);
        let move_v = self.apply_deadzone(raw_move_v);
        
        // Debug output for input values
        if raw_move_h.abs() > 0.001 || raw_move_v.abs() > 0.001 {
            println!("\nInput: h={:.3}, v={:.3} (after deadzone: h={:.3}, v={:.3})", 
                     raw_move_h, raw_move_v, move_h, move_v);
            // In our coordinate system: X=right, Y=forward, Z=up
            let forward = self.rotation * Vec3f::Y;
            let right = self.rotation * Vec3f::X;
            let up = self.rotation * Vec3f::Z;
            println!("Camera axes - Forward: [{:.2}, {:.2}, {:.2}] Right: [{:.2}, {:.2}, {:.2}] Up: [{:.2}, {:.2}, {:.2}]",
                     forward[0], forward[1], forward[2],
                     right[0], right[1], right[2],
                     up[0], up[1], up[2]);
            
            // Show which direction we're trying to move
            if move_v.abs() > 0.001 {
                let move_dir = forward * move_v;
                println!("  Moving forward/back: [{:.2}, {:.2}, {:.2}] * {:.2}", 
                         move_dir[0], move_dir[1], move_dir[2], move_v);
            }
            if move_h.abs() > 0.001 {
                let move_dir = right * move_h;
                println!("  Moving left/right: [{:.2}, {:.2}, {:.2}] * {:.2}", 
                         move_dir[0], move_dir[1], move_dir[2], move_h);
            }
            
            // Show the quaternion for debugging
            println!("  Quaternion: [{:.3}, {:.3}, {:.3}, {:.3}]", 
                     self.rotation.x(), self.rotation.y(), self.rotation.z(), self.rotation.1);
        }
        
        // Button states
        let select_pressed = unsafe { engine.input_binding_data(Binding::Select).activate };
        let escape_pressed = unsafe { engine.input_binding_data(Binding::Escape).activate };
        
        // TODO: Map these to proper buttons when available
        self.is_boosting = false;  // Should be Shift or LB
        self.is_precision = false; // Should be Ctrl or RB
        
        // Calculate acceleration multiplier
        let accel_mult = if self.is_precision {
            self.precision_multiplier
        } else if self.is_boosting {
            self.boost_multiplier
        } else {
            1.0
        };
        
        // Calculate desired velocity in camera space
        let mut desired_velocity = Vec3f::ZERO;
        
        // Check if right bumper is held for vertical movement mode
        let right_bumper_held = unsafe { engine.input_binding_data(Binding::MoveUpDown).scalar }.abs() > 0.001;
        
        if right_bumper_held {
            // Right bumper held: left stick Y controls vertical, X still controls strafe
            let vertical_input = unsafe { engine.input_binding_data(Binding::MoveUpDown).scalar };
            if vertical_input.abs() > 0.001 {
                // Move up/down in world space
                desired_velocity += Vec3f::Z * (vertical_input * self.max_speed * accel_mult);
            }
            
            // Left/right strafe still works
            if move_h.abs() > 0.001 {
                let right = self.rotation * Vec3f::X;
                desired_velocity += right * (move_h * self.max_speed * accel_mult);
            }
        } else {
            // Normal movement mode
            // Forward/backward (W/S or left stick Y)
            if move_v.abs() > 0.001 {
                // Get forward vector (Y axis in our coordinate system)
                // Negate move_v because positive Y on controller is typically up/forward
                let forward = self.rotation * Vec3f::Y;
                desired_velocity += forward * (-move_v * self.max_speed * accel_mult);
            }
            
            // Left/right (A/D or left stick X)
            if move_h.abs() > 0.001 {
                // Get right vector (X axis)
                let right = self.rotation * Vec3f::X;
                desired_velocity += right * (move_h * self.max_speed * accel_mult);
            }
        }
        
        // Update target velocity
        self.target_velocity = desired_velocity;
        
        // Debug velocity if moving
        if self.velocity.length_squared() > 0.1 || self.target_velocity.length_squared() > 0.1 {
            println!("Velocity: [{:.2}, {:.2}, {:.2}] speed={:.2} | Target: [{:.2}, {:.2}, {:.2}] speed={:.2}", 
                     self.velocity[0], self.velocity[1], self.velocity[2], self.velocity.length(),
                     self.target_velocity[0], self.target_velocity[1], self.target_velocity[2], self.target_velocity.length());
        }
        
        // Camera rotation - Calculate desired angular velocity in WORLD space
        let mut desired_angular_velocity = Vec3f::ZERO;
        
        // Get camera's local axes in world space
        let camera_right = self.rotation * Vec3f::X;   // X axis (right)
        let camera_forward = self.rotation * Vec3f::Y; // Y axis (forward)
        let camera_up = self.rotation * Vec3f::Z;      // Z axis (up)
        
        // Mouse look
        if let Some(last_pos) = self.last_mouse_pos {
            let delta_x = cursor_pos.0 - last_pos.0;
            let delta_y = cursor_pos.1 - last_pos.1;
            
            // Ignore very large deltas (likely from initial mouse position or window refocus)
            if delta_x.abs() > 0.1 || delta_y.abs() > 0.1 {
                println!("Ignoring large mouse delta: ({:.3}, {:.3})", delta_x, delta_y);
            } else if delta_x.abs() > 0.0001 || delta_y.abs() > 0.0001 {
                // Yaw (around camera's local up axis)
                desired_angular_velocity += camera_up * (-delta_x * self.mouse_sensitivity);
                
                // Pitch (around camera's local right axis)
                desired_angular_velocity += camera_right * (-delta_y * self.mouse_sensitivity);
            }
        }
        self.last_mouse_pos = Some(cursor_pos);
        
        // Controller right stick rotation
        let raw_look_h = unsafe { engine.input_binding_data(Binding::LookHorizontal).scalar };
        let raw_look_v = unsafe { engine.input_binding_data(Binding::LookVertical).scalar };
        
        // Debug right stick input
        if raw_look_h.abs() > 0.001 || raw_look_v.abs() > 0.001 {
            println!("Right stick raw: h={:.3}, v={:.3}", raw_look_h, raw_look_v);
        }
        
        let look_h = self.apply_deadzone(raw_look_h);
        let look_v = self.apply_deadzone(raw_look_v);
        
        if look_h.abs() > 0.001 || look_v.abs() > 0.001 {
            // Yaw (around camera's local up axis) - negate for correct direction
            desired_angular_velocity += camera_up * (-look_h * self.rotate_speed);
            
            // Pitch (around camera's local right axis) - negate for correct direction
            desired_angular_velocity += camera_right * (-look_v * self.rotate_speed);
            
            println!("Right stick after deadzone: h={:.3}, v={:.3}", look_h, look_v);
            println!("  Camera axes - Right: [{:.2}, {:.2}, {:.2}] Up: [{:.2}, {:.2}, {:.2}]",
                     camera_right[0], camera_right[1], camera_right[2],
                     camera_up[0], camera_up[1], camera_up[2]);
        }
        
        // Roll control (left bumper + right stick X or Q/E keys)
        let roll_input = unsafe { engine.input_binding_data(Binding::Roll).scalar };
        if roll_input.abs() > 0.001 {
            // Roll around camera's forward axis
            desired_angular_velocity += camera_forward * (roll_input * self.rotate_speed);
        }
        
        // Update target angular velocity (already in world space)
        self.target_angular_velocity = desired_angular_velocity;
        
        // Apply physics-based control through PID
        let old_position = self.position;
        
        if let Some(physx) = engine.physx() {
            if let Some(body) = self.physics_body {
                // Get current velocities from physics for PID feedback
                // IMPORTANT: Physics returns position/orientation differences, we need to divide by dt
                let raw_linear_vel = physx.rigidbody_get_linear_velocity(body);
                let raw_angular_vel = physx.rigidbody_get_angular_velocity(body);
                
                // Only divide by delta_time if the velocities are non-zero
                let current_velocity = if raw_linear_vel.length_squared() > 0.0 {
                    raw_linear_vel / delta_time
                } else {
                    Vec3f::ZERO
                };
                
                let current_angular_velocity = if raw_angular_vel.length_squared() > 0.0 {
                    raw_angular_vel / delta_time
                } else {
                    Vec3f::ZERO
                };
                
                // Update our cached velocities
                self.velocity = current_velocity;
                self.angular_velocity = current_angular_velocity;
                
                // Calculate velocity error and apply PID control forces
                let velocity_error = self.target_velocity - current_velocity;
                let linear_force = self.linear_pid.update(velocity_error, delta_time);
                
                // Calculate angular velocity error and apply PID control torques
                let angular_error = self.target_angular_velocity - current_angular_velocity;
                let angular_torque = self.angular_pid.update(angular_error, delta_time);
                
                // Debug PID output
                if linear_force.length() > 0.1 || angular_torque.length() > 0.01 {
                    println!("PID Force: [{:.2}, {:.2}, {:.2}] | Torque: [{:.3}, {:.3}, {:.3}]",
                             linear_force[0], linear_force[1], linear_force[2],
                             angular_torque[0], angular_torque[1], angular_torque[2]);
                    
                    // Also log current vs target angular velocity
                    println!("  Angular vel: current=[{:.3}, {:.3}, {:.3}] target=[{:.3}, {:.3}, {:.3}]",
                             current_angular_velocity[0], current_angular_velocity[1], current_angular_velocity[2],
                             self.target_angular_velocity[0], self.target_angular_velocity[1], self.target_angular_velocity[2]);
                    
                    // Log which axis we're rotating around
                    if self.target_angular_velocity[2].abs() > 0.01 {
                        println!("  Yawing around Z axis (world up)");
                    }
                    if self.target_angular_velocity[0].abs() > 0.01 {
                        println!("  Pitching around X axis");
                    }
                    if self.target_angular_velocity[1].abs() > 0.01 {
                        println!("  Rolling around Y axis");
                    }
                }
                
                // Apply forces and torques through physics
                physx.rigidbody_accelerate(body, linear_force);
                physx.rigidbody_angular_impulse(body, angular_torque * delta_time);
                
                // Apply upward force to counteract gravity for floating camera
                // Gravity is -9.81 m/s² in Z, mass is 10.0 kg, so we need 98.1 N upward
                physx.rigidbody_accelerate(body, Vec3f::xyz(0.0, 0.0, 9.81));
                
                // Step physics simulation
                physx.step(delta_time);
                
                // Read back state from physics
                let position_before_physics = self.position;
                self.position = physx.rigidbody_get_position(body);
                self.rotation = physx.rigidbody_get_orientation(body);
                
                // Check if position changed during rotation
                if self.target_angular_velocity.length() > 0.01 && self.target_velocity.length() < 0.01 {
                    let position_drift = (self.position - position_before_physics).length();
                    if position_drift > 0.001 {
                        println!("WARNING: Camera position drifted during pure rotation!");
                        println!("  Pre-step pos: [{:.3}, {:.3}, {:.3}]", position_before_physics[0], position_before_physics[1], position_before_physics[2]);
                        println!("  Post-step pos: [{:.3}, {:.3}, {:.3}]", self.position[0], self.position[1], self.position[2]);
                        println!("  Drift: {:.3} units", position_drift);
                        
                        // Check if we're orbiting around origin
                        let pre_angle = position_before_physics[1].atan2(position_before_physics[0]);
                        let post_angle = self.position[1].atan2(self.position[0]);
                        let angle_diff = (post_angle - pre_angle).to_degrees();
                        if angle_diff.abs() > 0.1 {
                            println!("  ORBITING: Angle around Z axis changed by {:.2}°", angle_diff);
                        }
                        
                        // WORKAROUND: Correct the position drift
                        self.position = position_before_physics;
                        physx.rigidbody_reposition(body, self.position);
                        println!("  Corrected position back to: [{:.3}, {:.3}, {:.3}]", self.position[0], self.position[1], self.position[2]);
                    }
                }
                
                // Update velocities from physics (divide by dt as per physics engine API)
                let raw_linear_vel = physx.rigidbody_get_linear_velocity(body);
                let raw_angular_vel = physx.rigidbody_get_angular_velocity(body);
                
                self.velocity = if raw_linear_vel.length_squared() > 0.0 {
                    raw_linear_vel / delta_time
                } else {
                    Vec3f::ZERO
                };
                
                self.angular_velocity = if raw_angular_vel.length_squared() > 0.0 {
                    raw_angular_vel / delta_time
                } else {
                    Vec3f::ZERO
                };
                
                // Log collisions
                let expected_position = old_position + self.target_velocity * delta_time;
                let position_diff = (self.position - expected_position).length();
                if position_diff > 0.1 {
                    println!("Collision detected! Position corrected by {:.3} units", position_diff);
                    println!("  Expected: [{:.2}, {:.2}, {:.2}] -> Physics: [{:.2}, {:.2}, {:.2}]",
                             expected_position[0], expected_position[1], expected_position[2],
                             self.position[0], self.position[1], self.position[2]);
                }
            } else {
                // No physics body, use direct integration with damping
                self.velocity = self.velocity * (1.0 - self.linear_damping * delta_time) + self.target_velocity * delta_time;
                self.angular_velocity = self.angular_velocity * (1.0 - self.angular_damping * delta_time) + self.target_angular_velocity * delta_time;
                self.position += self.velocity * delta_time;
                
                // Apply rotation
                if self.angular_velocity.length_squared() > 0.0001 {
                    let rotation_delta = Quat::from_scaled_axis(self.angular_velocity * delta_time);
                    self.rotation = rotation_delta * self.rotation;
                    self.rotation = self.rotation.normalize();
                }
            }
        } else {
            // No physics system, use direct integration with damping
            self.velocity = self.velocity * (1.0 - self.linear_damping * delta_time) + self.target_velocity * delta_time;
            self.angular_velocity = self.angular_velocity * (1.0 - self.angular_damping * delta_time) + self.target_angular_velocity * delta_time;
            self.position += self.velocity * delta_time;
            
            // Apply rotation
            if self.angular_velocity.length_squared() > 0.0001 {
                let rotation_delta = Quat::from_scaled_axis(self.angular_velocity * delta_time);
                self.rotation = rotation_delta * self.rotation;
                self.rotation = self.rotation.normalize();
            }
        }
        
        // Log position changes
        let movement = (self.position - old_position).length();
        if movement > 0.001 {
            println!("Camera moved {:.3} units: [{:.2}, {:.2}, {:.2}] -> [{:.2}, {:.2}, {:.2}]",
                     movement,
                     old_position[0], old_position[1], old_position[2],
                     self.position[0], self.position[1], self.position[2]);
        }
        
        // Log rotation changes
        if self.angular_velocity.length_squared() > 0.0001 || self.target_angular_velocity.length_squared() > 0.0001 {
            let euler = self.rotation.to_euler_zyx();
            println!("Camera rotation: [Yaw: {:.1}°, Pitch: {:.1}°, Roll: {:.1}°] angular_vel: [{:.2}, {:.2}, {:.2}] target: [{:.2}, {:.2}, {:.2}]",
                     euler.0.to_degrees(), euler.1.to_degrees(), euler.2.to_degrees(),
                     self.angular_velocity[0], self.angular_velocity[1], self.angular_velocity[2],
                     self.target_angular_velocity[0], self.target_angular_velocity[1], self.target_angular_velocity[2]);
        }
    }
    
    fn apply_deadzone(&self, value: f32) -> f32 {
        if value.abs() < self.stick_deadzone {
            0.0
        } else {
            // Rescale to 0-1 range after deadzone
            let sign = value.signum();
            let magnitude = (value.abs() - self.stick_deadzone) / (1.0 - self.stick_deadzone);
            sign * magnitude
        }
    }
    
    pub fn get_view_matrix(&self) -> [f32; 16] {
        // Build view matrix manually to ensure correct order
        // View matrix transforms from world space to camera space
        
        // Get camera basis vectors in world space
        let right = self.rotation * Vec3f::X;      // Camera X axis
        let forward = self.rotation * Vec3f::Y;    // Camera Y axis (forward)
        let up = self.rotation * Vec3f::Z;         // Camera Z axis (up)
        
        // Standard graphics convention: camera looks down -Z in view space
        // Our camera looks along +Y, so we need to remap:
        // Camera Y (forward) -> View -Z
        // Camera X (right) -> View X
        // Camera Z (up) -> View Y
        
        // Build rotation part of view matrix (transpose of camera orientation)
        let mut view = Mat4f::identity();
        
        // First row: maps world to camera's right (X)
        view[(0, 0)] = right[0];
        view[(0, 1)] = right[1];
        view[(0, 2)] = right[2];
        
        // Second row: maps world to camera's up (Z -> view Y)
        view[(1, 0)] = up[0];
        view[(1, 1)] = up[1];
        view[(1, 2)] = up[2];
        
        // Third row: maps world to -forward (Y -> view -Z)
        view[(2, 0)] = -forward[0];
        view[(2, 1)] = -forward[1];
        view[(2, 2)] = -forward[2];
        
        // Translation part: -R^T * position
        let trans = Vec3f::xyz(
            -right.dot(self.position),
            -up.dot(self.position),
            forward.dot(self.position)  // Positive because we negated forward above
        );
        
        view[(0, 3)] = trans[0];
        view[(1, 3)] = trans[1];
        view[(2, 3)] = trans[2];
        
        // Convert column-major [[f32; 4]; 4] to flat [f32; 16]
        let data = view.0;
        let mut flat = [0.0f32; 16];
        let mut idx = 0;
        for col in 0..4 {
            for row in 0..4 {
                flat[idx] = data[col][row];
                idx += 1;
            }
        }
        flat
    }
    
    pub fn get_position(&self) -> Vec3f {
        self.position
    }
    
    pub fn get_rotation(&self) -> Quat {
        self.rotation
    }
    
    pub fn get_euler_angles(&self) -> (f32, f32, f32) {
        // Return Euler angles in degrees (Z-Y-X order: yaw, pitch, roll)
        let euler = self.rotation.to_euler_zyx();
        (euler.0.to_degrees(), euler.1.to_degrees(), euler.2.to_degrees())
    }
    
    pub fn get_forward_vector(&self) -> Vec3f {
        self.rotation * Vec3f::Y
    }
    
    pub fn set_position(&mut self, position: Vec3f) {
        let old_position = self.position;
        self.position = position;
        // When setting position directly, reset velocity to avoid jumps
        self.velocity = Vec3f::ZERO;
        
        println!("Camera position set: [{:.2}, {:.2}, {:.2}] -> [{:.2}, {:.2}, {:.2}]",
                 old_position[0], old_position[1], old_position[2],
                 position[0], position[1], position[2]);
    }
    
    pub fn destroy_physics(&mut self, physx: &dyn Physx) {
        if let Some(body) = self.physics_body {
            physx.rigidbody_destroy(body);
            self.physics_body = None;
        }
    }
}