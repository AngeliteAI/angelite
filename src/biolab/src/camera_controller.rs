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
            max_integral_magnitude: 1.0,
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
        Self::new_look_at(Vec3f::xyz(0.0, -5.0, 0.0), Vec3f::ZERO, Vec3f::Z)
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
            // P-only control for stability
            linear_pid: PIDController::new(1.0, 0.0, 0.0),
            angular_pid: PIDController::new(5.0, 0.0, 0.0),  // Higher gain for responsive rotation
            
            // Space Engineers-like settings
            move_acceleration: 100.0,  // m/s²
            max_speed: 100.0,         // m/s
            boost_multiplier: 3.0,
            precision_multiplier: 0.25,
            rotate_speed: 2.0,        // rad/s
            
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
            physx.rigidbody_angular_damping(body, 0.5);  // Reduce angular damping significantly
            physx.rigidbody_set_half_extents(body, Vec3f::xyz(0.25, 0.25, 0.5)); // Small capsule-like shape
            physx.rigidbody_angular_moment(body, Vec3f::xyz(0.1, 0.1, 0.1)); // Lower moment of inertia for easier rotation
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
        
        // Vertical movement (Space/Ctrl or A/B buttons for now)
        // TODO: Use proper Q/E keys or triggers when available
        if select_pressed {
            // Move up in world space
            desired_velocity += Vec3f::Z * (self.max_speed * accel_mult);
        }
        if escape_pressed {
            // Move down in world space
            desired_velocity -= Vec3f::Z * (self.max_speed * accel_mult);
        }
        
        // Update target velocity
        self.target_velocity = desired_velocity;
        
        // Debug velocity if moving
        if self.velocity.length_squared() > 0.1 || self.target_velocity.length_squared() > 0.1 {
            println!("Velocity: [{:.2}, {:.2}, {:.2}] speed={:.2} | Target: [{:.2}, {:.2}, {:.2}] speed={:.2}", 
                     self.velocity[0], self.velocity[1], self.velocity[2], self.velocity.length(),
                     self.target_velocity[0], self.target_velocity[1], self.target_velocity[2], self.target_velocity.length());
        }
        
        // Camera rotation - Calculate desired angular velocity in LOCAL space
        let mut desired_angular_velocity_local = Vec3f::ZERO;
        
        // Mouse look
        if let Some(last_pos) = self.last_mouse_pos {
            let delta_x = cursor_pos.0 - last_pos.0;
            let delta_y = cursor_pos.1 - last_pos.1;
            
            // Ignore very large deltas (likely from initial mouse position or window refocus)
            if delta_x.abs() > 0.1 || delta_y.abs() > 0.1 {
                println!("Ignoring large mouse delta: ({:.3}, {:.3})", delta_x, delta_y);
            } else if delta_x.abs() > 0.0001 || delta_y.abs() > 0.0001 {
                // Yaw (around local Z axis)
                desired_angular_velocity_local[2] = -delta_x * self.mouse_sensitivity;
                
                // Pitch (around local X axis)
                desired_angular_velocity_local[0] = -delta_y * self.mouse_sensitivity;
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
            // Yaw (around local Z axis)
            desired_angular_velocity_local[2] = look_h * self.rotate_speed;
            
            // Pitch (around local X axis)
            desired_angular_velocity_local[0] = look_v * self.rotate_speed;
            
            println!("Right stick after deadzone: h={:.3}, v={:.3}, angular_vel_local: [{:.3}, {:.3}, {:.3}]", 
                     look_h, look_v, desired_angular_velocity_local[0], desired_angular_velocity_local[1], desired_angular_velocity_local[2]);
        }
        
        // Roll control (Q/E keys - using cursor pos for now as a hack)
        // TODO: Map to proper Q/E keys when available
        if cursor_pos.0 < -0.8 {
            // Roll left
            desired_angular_velocity_local[1] -= self.rotate_speed * 0.5; // Roll around Y (forward) axis
        } else if cursor_pos.0 > 0.8 {
            // Roll right  
            desired_angular_velocity_local[1] += self.rotate_speed * 0.5;
        }
        
        // Convert local angular velocity to world space
        let desired_angular_velocity = self.rotation * desired_angular_velocity_local;
        
        // Update target angular velocity
        self.target_angular_velocity = desired_angular_velocity;
        
        // Apply physics-based control through PID
        let old_position = self.position;
        
        if let Some(physx) = engine.physx() {
            if let Some(body) = self.physics_body {
                // Get current velocities from physics for PID feedback
                let current_velocity = physx.rigidbody_get_linear_velocity(body);
                let current_angular_velocity = physx.rigidbody_get_angular_velocity(body);
                
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
                self.position = physx.rigidbody_get_position(body);
                self.rotation = physx.rigidbody_get_orientation(body);
                
                // Update velocities from physics
                self.velocity = physx.rigidbody_get_linear_velocity(body);
                self.angular_velocity = physx.rigidbody_get_angular_velocity(body);
                
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
        // Our coordinate system:
        // - X+ is East (right)
        // - Y+ is North (forward)
        // - Z+ is Up
        
        // Standard view matrix expects camera to look down -Z
        // But our camera's Y axis is forward, so we need to rotate -90° around X
        // to align Y forward with -Z view direction
        
        // Create view matrix by inverting the camera transform
        let mat = Mat4f::from_rotation_translation(self.rotation, self.position).inverse();
        
        // Apply -90 degree rotation around X to convert from Y-forward to Z-forward view space
        let pitch_neg90_quat = Quat::from_rotation_x(-std::f32::consts::PI / 2.0);
        let pitch_neg90_mat = Mat4f::from_quat(pitch_neg90_quat);
        let final_mat = pitch_neg90_mat * mat;
        
        final_mat.to_cols_array()
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