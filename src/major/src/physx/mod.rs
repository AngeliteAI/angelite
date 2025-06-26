pub mod vk;

#[cfg(test)]
mod test_angular;

// Newtype wrapper around u64 handle
#[repr(transparent)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Rigidbody(u64);

pub trait Physx {
    fn as_any(&self) -> &dyn std::any::Any;
    
    fn rigidbody_create(&self) -> *mut Rigidbody;
    fn rigidbody_destroy(&self, rigidbody: *mut Rigidbody);
    fn rigidbody_mass(&self, rigidbody: *mut Rigidbody, mass: f32);
    fn rigidbody_friction(&self, rigidbody: *mut Rigidbody, friction: f32);
    fn rigidbody_restitution(&self, rigidbody: *mut Rigidbody, restitution: f32);
    fn rigidbody_linear_damping(&self, rigidbody: *mut Rigidbody, linear_damping: f32);
    fn rigidbody_angular_damping(&self, rigidbody: *mut Rigidbody, angular_damping: f32);
    fn rigidbody_angular_moment(
        &self,
        rigidbody: *mut Rigidbody,
        angular_moment: crate::math::Vec3f,
    ); 
    fn rigidbody_center_of_mass(
        &self,
        rigidbody: *mut Rigidbody,
        center_of_mass: crate::math::Vec3f,
    );
    fn rigidbody_set_half_extents(
        &self,
        rigidbody: *mut Rigidbody,
        half_extents: crate::math::Vec3f,
    );
    fn rigidbody_reposition(
        &self,
        rigidbody: *mut Rigidbody,
        position: crate::math::Vec3f,
    );
    fn rigidbody_orient(
        &self,
        rigidbody: *mut Rigidbody,
        orientation: crate::math::Quat,
    );
    fn rigidbody_move(&self, rigidbody: *mut Rigidbody, velocity: crate::math::Vec3f);
    fn rigidbody_accelerate(&self, rigidbody: *mut Rigidbody, acceleration: crate::math::Vec3f);
    fn rigidbody_impulse(&self, rigidbody: *mut Rigidbody, impulse: crate::math::Vec3f);
    fn rigidbody_angular_impulse(&self, rigidbody: *mut Rigidbody, angular_impulse: crate::math::Vec3f);
    fn rigidbody_apply_force_at_point(&self, rigidbody: *mut Rigidbody, force: crate::math::Vec3f, point: crate::math::Vec3f);
    fn rigidbody_apply_impulse_at_point(&self, rigidbody: *mut Rigidbody, impulse: crate::math::Vec3f, point: crate::math::Vec3f);
    
    // Get current state
    fn rigidbody_get_position(&self, rigidbody: *mut Rigidbody) -> crate::math::Vec3f;
    fn rigidbody_get_orientation(&self, rigidbody: *mut Rigidbody) -> crate::math::Quat;
    fn rigidbody_get_linear_velocity(&self, rigidbody: *mut Rigidbody) -> crate::math::Vec3f;
    fn rigidbody_get_angular_velocity(&self, rigidbody: *mut Rigidbody) -> crate::math::Vec3f;
    
    // Physics engine lifecycle
    fn step(&self, delta_time: f32);
}