/// Generic PID Controller for control systems
#[derive(Clone, Copy, Debug)]
pub struct PIDController {
    kp: f32,  // Proportional gain
    ki: f32,  // Integral gain
    kd: f32,  // Derivative gain
    integral: f32,
    last_error: f32,
    max_integral: f32,
    output_min: f32,
    output_max: f32,
}

impl PIDController {
    /// Create a new PID controller with specified gains
    pub fn new(kp: f32, ki: f32, kd: f32) -> Self {
        Self {
            kp,
            ki,
            kd,
            integral: 0.0,
            last_error: 0.0,
            max_integral: 1000.0,
            output_min: f32::NEG_INFINITY,
            output_max: f32::INFINITY,
        }
    }
    
    /// Set output limits
    pub fn with_limits(mut self, min: f32, max: f32) -> Self {
        self.output_min = min;
        self.output_max = max;
        self
    }
    
    /// Set integral windup limit
    pub fn with_integral_limit(mut self, limit: f32) -> Self {
        self.max_integral = limit;
        self
    }
    
    /// Update the controller with new error value
    pub fn update(&mut self, setpoint: f32, current: f32, dt: f32) -> f32 {
        let error = setpoint - current;
        
        // Proportional term
        let p = error * self.kp;
        
        // Integral term with anti-windup
        self.integral += error * dt;
        self.integral = self.integral.clamp(-self.max_integral, self.max_integral);
        let i = self.integral * self.ki;
        
        // Derivative term
        let d = if dt > 0.0 {
            (error - self.last_error) * self.kd / dt
        } else {
            0.0
        };
        
        self.last_error = error;
        
        // Calculate output and clamp
        let output = p + i + d;
        output.clamp(self.output_min, self.output_max)
    }
    
    /// Reset the controller state
    pub fn reset(&mut self) {
        self.integral = 0.0;
        self.last_error = 0.0;
    }
}

/// PID Controller specifically for workgroup scheduling
pub struct WorkgroupPIDController {
    pid: PIDController,
    initial_value: f32,
    ramp_up_frames: u32,
    current_frame: u32,
}

impl WorkgroupPIDController {
    /// Create a new workgroup PID controller
    /// Starts at minimum capacity and ramps up
    pub fn new(min_workgroups: f32, max_workgroups: f32) -> Self {
        // More aggressive gains for 100 FPS target
        // Note: Using negative gains because we want inverse control
        // (high frame time -> fewer workgroups)
        let pid = PIDController::new(-0.5, -0.1, -0.2)
            .with_limits(min_workgroups, max_workgroups)
            .with_integral_limit(max_workgroups * 0.3);
            
        Self {
            pid,
            initial_value: min_workgroups + 1.0, // Start very conservatively for 100 FPS
            ramp_up_frames: 100, // Ramp up over 100 frames (1 second at 100 FPS)
            current_frame: 0,
        }
    }
    
    /// Update workgroup count based on frame time
    /// target_frame_time_ms: Target frame time in milliseconds
    /// current_frame_time_ms: Current frame time in milliseconds
    /// Returns: Number of workgroups to dispatch
    pub fn update(&mut self, target_frame_time_ms: f32, current_frame_time_ms: f32, dt: f32) -> u32 {
        self.current_frame += 1;
        
        // During ramp-up phase, gradually increase from initial value
        let ramp_factor = (self.current_frame as f32 / self.ramp_up_frames as f32).min(1.0);
        
        // Get PID output (already inverted due to negative gains)
        let pid_output = self.pid.update(target_frame_time_ms, current_frame_time_ms, dt);
        
        // During ramp-up, limit the maximum workgroups
        let max_during_ramp = self.initial_value + (self.pid.output_max - self.initial_value) * ramp_factor;
        
        let target_workgroups = if ramp_factor < 1.0 {
            pid_output.min(max_during_ramp)
        } else {
            pid_output
        };
        
        // Ensure we always return at least 1 workgroup
        target_workgroups.round().max(1.0) as u32
    }
    
    /// Reset the controller
    pub fn reset(&mut self) {
        self.pid.reset();
        self.current_frame = 0;
    }
}