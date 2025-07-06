use std::ffi::c_void;
use crate::math::{Vec3f, Quat};

// FFI bindings to Zig physics engine
unsafe extern "C" {
    fn physics_engine_create() -> *mut c_void;
    fn physics_engine_destroy(engine: *mut c_void);
    fn physics_engine_init_gpu(engine: *mut c_void, device: *mut c_void, command_pool: *mut c_void, queue: *mut c_void);
    fn physics_engine_step(engine: *mut c_void, delta_time: f32);
    
    fn rigidbody_create(engine: *mut c_void) -> u64;
    fn rigidbody_destroy(engine: *mut c_void, handle: u64);
    fn rigidbody_set_mass(engine: *mut c_void, handle: u64, mass: f32);
    fn rigidbody_set_friction(engine: *mut c_void, handle: u64, friction: f32);
    fn rigidbody_set_restitution(engine: *mut c_void, handle: u64, restitution: f32);
    fn rigidbody_set_linear_damping(engine: *mut c_void, handle: u64, damping: f32);
    fn rigidbody_set_angular_damping(engine: *mut c_void, handle: u64, damping: f32);
    fn rigidbody_set_angular_moment(engine: *mut c_void, handle: u64, moment: Vec3f);
    fn rigidbody_set_center_of_mass(engine: *mut c_void, handle: u64, com: Vec3f);
    fn rigidbody_set_half_extents(engine: *mut c_void, handle: u64, half_extents: Vec3f);
    fn rigidbody_reposition(engine: *mut c_void, handle: u64, position: Vec3f);
    fn rigidbody_orient(engine: *mut c_void, handle: u64, x: f32, y: f32, z: f32, w: f32);
    fn rigidbody_move(engine: *mut c_void, handle: u64, position: Vec3f);
    fn rigidbody_accelerate(engine: *mut c_void, handle: u64, acceleration: Vec3f);
    fn rigidbody_impulse(engine: *mut c_void, handle: u64, impulse: Vec3f);
    fn rigidbody_angular_impulse(engine: *mut c_void, handle: u64, angular_impulse: Vec3f);
    fn rigidbody_get_position(engine: *mut c_void, handle: u64) -> Vec3f;
    fn rigidbody_get_orientation(engine: *mut c_void, handle: u64, out_x: *mut f32, out_y: *mut f32, out_z: *mut f32, out_w: *mut f32);
    fn rigidbody_get_linear_velocity(engine: *mut c_void, handle: u64) -> Vec3f;
    fn rigidbody_get_angular_velocity(engine: *mut c_void, handle: u64) -> Vec3f;
    fn rigidbody_apply_force_at_point(engine: *mut c_void, handle: u64, force: Vec3f, point: Vec3f);
    fn rigidbody_apply_impulse_at_point(engine: *mut c_void, handle: u64, impulse: Vec3f, point: Vec3f);
}

pub mod physics_rendergraph;

pub struct VulkanAccel {
    engine: *mut c_void,
}

impl VulkanAccel {
    pub fn new() -> Option<Self> {
        let engine = unsafe { physics_engine_create() };
        if engine.is_null() {
            None
        } else {
            Some(Self { engine })
        }
    }
    
    pub fn init_gpu(&self, device: *mut c_void, command_pool: *mut c_void, queue: *mut c_void) {
        unsafe {
            physics_engine_init_gpu(self.engine, device, command_pool, queue);
        }
    }
    
    pub fn init_from_renderer(&self, renderer_ptr: *mut c_void) {
        // Import the renderer FFI functions
        unsafe extern "C" {
            fn renderer_get_device_info(
                renderer: *mut c_void,
                out_device: *mut c_void,
                out_queue: *mut c_void,  
                out_command_pool: *mut c_void,
            ) -> bool;
            
            fn renderer_get_device_dispatch(renderer: *mut c_void) -> *const c_void;
            fn renderer_get_physical_device(renderer: *mut c_void) -> *mut c_void;
            fn renderer_get_instance_dispatch(renderer: *mut c_void) -> *const c_void;
            
            fn physics_engine_set_dispatch_tables(
                engine: *mut c_void,
                device_dispatch: *const c_void,
                physical_device: *mut c_void,
                instance_dispatch: *const c_void,
            );
        }
        
        unsafe {
            let mut device: *mut c_void = std::ptr::null_mut();
            let mut queue: *mut c_void = std::ptr::null_mut();
            let mut command_pool: *mut c_void = std::ptr::null_mut();
            
            if renderer_get_device_info(
                renderer_ptr,
                &mut device as *mut *mut c_void as *mut c_void,
                &mut queue as *mut *mut c_void as *mut c_void,
                &mut command_pool as *mut *mut c_void as *mut c_void
            ) {
                // Get dispatch tables
                let device_dispatch = renderer_get_device_dispatch(renderer_ptr);
                let physical_device = renderer_get_physical_device(renderer_ptr);
                let instance_dispatch = renderer_get_instance_dispatch(renderer_ptr);
                
                // Set dispatch tables in physics engine
                physics_engine_set_dispatch_tables(
                    self.engine,
                    device_dispatch,
                    physical_device,
                    instance_dispatch
                );
                
                // Initialize GPU physics
                self.init_gpu(
                    device,
                    command_pool,
                    queue
                );
                println!("[DEBUG] Physics GPU acceleration initialized");
            } else {
                println!("[DEBUG] Failed to get device info for physics GPU acceleration");
            }
        }
    }
}

impl Drop for VulkanAccel {
    fn drop(&mut self) {
        unsafe {
            physics_engine_destroy(self.engine);
        }
    }
}

impl super::Physx for VulkanAccel {
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
    
    fn rigidbody_create(&self) -> *mut super::Rigidbody {
        let handle = unsafe { rigidbody_create(self.engine) };
        if handle == 0 {
            std::ptr::null_mut()
        } else {
            Box::into_raw(Box::new(super::Rigidbody(handle)))
        }
    }
    
    fn rigidbody_destroy(&self, rigidbody: *mut super::Rigidbody) {
        if rigidbody.is_null() {
            return;
        }
        unsafe {
            let rb = Box::from_raw(rigidbody);
            rigidbody_destroy(self.engine, rb.0);
        }
    }
    
    fn rigidbody_mass(&self, rigidbody: *mut super::Rigidbody, mass: f32) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_set_mass(self.engine, handle, mass);
        }
    }
    
    fn rigidbody_friction(&self, rigidbody: *mut super::Rigidbody, friction: f32) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_set_friction(self.engine, handle, friction);
        }
    }
    
    fn rigidbody_restitution(&self, rigidbody: *mut super::Rigidbody, restitution: f32) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_set_restitution(self.engine, handle, restitution);
        }
    }
    
    fn rigidbody_linear_damping(&self, rigidbody: *mut super::Rigidbody, linear_damping: f32) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_set_linear_damping(self.engine, handle, linear_damping);
        }
    }
    
    fn rigidbody_angular_damping(&self, rigidbody: *mut super::Rigidbody, angular_damping: f32) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_set_angular_damping(self.engine, handle, angular_damping);
        }
    }
    
    fn rigidbody_angular_moment(&self, rigidbody: *mut super::Rigidbody, angular_moment: Vec3f) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_set_angular_moment(self.engine, handle, angular_moment);
        }
    }
    
    fn rigidbody_center_of_mass(&self, rigidbody: *mut super::Rigidbody, center_of_mass: Vec3f) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_set_center_of_mass(self.engine, handle, center_of_mass);
        }
    }
    
    fn rigidbody_set_half_extents(&self, rigidbody: *mut super::Rigidbody, half_extents: Vec3f) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_set_half_extents(self.engine, handle, half_extents);
        }
    }
    
    fn rigidbody_reposition(&self, rigidbody: *mut super::Rigidbody, position: Vec3f) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_reposition(self.engine, handle, position);
        }
    }
    
    fn rigidbody_orient(&self, rigidbody: *mut super::Rigidbody, orientation: Quat) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_orient(self.engine, handle, orientation.x(), orientation.y(), orientation.z(), orientation.1);
        }
    }
    
    fn rigidbody_move(&self, rigidbody: *mut super::Rigidbody, velocity: Vec3f) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_move(self.engine, handle, velocity);
        }
    }
    
    fn rigidbody_accelerate(&self, rigidbody: *mut super::Rigidbody, acceleration: Vec3f) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_accelerate(self.engine, handle, acceleration);
        }
    }
    
    fn rigidbody_impulse(&self, rigidbody: *mut super::Rigidbody, impulse: Vec3f) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_impulse(self.engine, handle, impulse);
        }
    }
    
    fn rigidbody_angular_impulse(&self, rigidbody: *mut super::Rigidbody, angular_impulse: Vec3f) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_angular_impulse(self.engine, handle, angular_impulse);
        }
    }
    
    fn rigidbody_apply_force_at_point(&self, rigidbody: *mut super::Rigidbody, force: Vec3f, point: Vec3f) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_apply_force_at_point(self.engine, handle, force, point);
        }
    }
    
    fn rigidbody_apply_impulse_at_point(&self, rigidbody: *mut super::Rigidbody, impulse: Vec3f, point: Vec3f) {
        if rigidbody.is_null() { return; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_apply_impulse_at_point(self.engine, handle, impulse, point);
        }
    }
    
    fn rigidbody_get_position(&self, rigidbody: *mut super::Rigidbody) -> Vec3f {
        if rigidbody.is_null() { return Vec3f::ZERO; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_get_position(self.engine, handle)
        }
    }
    
    fn rigidbody_get_orientation(&self, rigidbody: *mut super::Rigidbody) -> Quat {
        if rigidbody.is_null() { return Quat::identity(); }
        unsafe {
            let handle = (*rigidbody).0;
            let mut x = 0.0f32;
            let mut y = 0.0f32;
            let mut z = 0.0f32;
            let mut w = 1.0f32;
            rigidbody_get_orientation(self.engine, handle, &mut x, &mut y, &mut z, &mut w);
            Quat::new(x, y, z, w)
        }
    }
    
    fn rigidbody_get_linear_velocity(&self, rigidbody: *mut super::Rigidbody) -> Vec3f {
        if rigidbody.is_null() { return Vec3f::ZERO; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_get_linear_velocity(self.engine, handle)
        }
    }
    
    fn rigidbody_get_angular_velocity(&self, rigidbody: *mut super::Rigidbody) -> Vec3f {
        if rigidbody.is_null() { return Vec3f::ZERO; }
        unsafe {
            let handle = (*rigidbody).0;
            rigidbody_get_angular_velocity(self.engine, handle)
        }
    }
    
    fn step(&self, delta_time: f32) {
        unsafe { physics_engine_step(self.engine, delta_time) };
    }
}