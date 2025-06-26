// Test for angular physics functionality
use crate::math::{Vec3f, Quat};
use crate::physx::{Physx, Rigidbody};

#[test]
fn test_angular_velocity_integration() {
    // Create physics engine
    let physics = crate::physx::vk::VulkanAccel::new().expect("Failed to create physics engine");
    
    // Create a rigid body
    let rb = physics.rigidbody_create();
    assert!(!rb.is_null());
    
    // Set up the rigid body with proper properties
    physics.rigidbody_mass(rb, 1.0);
    physics.rigidbody_angular_moment(rb, Vec3f::new(1.0, 1.0, 1.0)); // Uniform angular moment
    physics.rigidbody_angular_damping(rb, 1.0); // No damping for test
    physics.rigidbody_reposition(rb, Vec3f::ZERO);
    physics.rigidbody_orient(rb, Quat::identity());
    
    // Apply an angular impulse
    let angular_impulse = Vec3f::new(0.0, 0.0, 1.0); // Rotate around Z axis
    physics.rigidbody_angular_impulse(rb, angular_impulse);
    
    // Step the simulation
    let dt = 0.016; // 60 FPS
    physics.step(dt);
    
    // Check that the body has rotated
    let orientation = physics.rigidbody_get_orientation(rb);
    let angular_velocity = physics.rigidbody_get_angular_velocity(rb);
    
    // Angular velocity should be non-zero
    let ang_vel_magnitude = (angular_velocity.x * angular_velocity.x + 
                            angular_velocity.y * angular_velocity.y + 
                            angular_velocity.z * angular_velocity.z).sqrt();
    assert!(ang_vel_magnitude > 0.01, "Angular velocity should be non-zero after impulse");
    
    // Orientation should have changed from identity
    assert!(orientation.x().abs() > 0.0001 || 
            orientation.y().abs() > 0.0001 || 
            orientation.z().abs() > 0.0001, 
            "Orientation should have changed");
    
    // Clean up
    physics.rigidbody_destroy(rb);
}

#[test]
fn test_force_at_point_generates_torque() {
    // Create physics engine
    let physics = crate::physx::vk::VulkanAccel::new().expect("Failed to create physics engine");
    
    // Create a rigid body
    let rb = physics.rigidbody_create();
    assert!(!rb.is_null());
    
    // Set up the rigid body
    physics.rigidbody_mass(rb, 1.0);
    physics.rigidbody_angular_moment(rb, Vec3f::new(1.0, 1.0, 1.0));
    physics.rigidbody_angular_damping(rb, 1.0);
    physics.rigidbody_reposition(rb, Vec3f::ZERO);
    physics.rigidbody_orient(rb, Quat::identity());
    physics.rigidbody_center_of_mass(rb, Vec3f::ZERO); // COM at origin
    
    // Apply force at a point offset from center
    let force = Vec3f::new(1.0, 0.0, 0.0); // Force in +X direction
    let point = Vec3f::new(0.0, 1.0, 0.0); // Applied at +Y offset
    
    // This should generate torque around Z axis
    physics.rigidbody_apply_force_at_point(rb, force, point);
    
    // Step the simulation
    physics.step(0.016);
    
    // Check angular velocity
    let angular_velocity = physics.rigidbody_get_angular_velocity(rb);
    
    // Should have angular velocity mainly around Z axis
    assert!(angular_velocity.z.abs() > 0.01, "Should have angular velocity around Z axis");
    assert!(angular_velocity.x.abs() < 0.01, "Should have minimal angular velocity around X axis");
    assert!(angular_velocity.y.abs() < 0.01, "Should have minimal angular velocity around Y axis");
    
    // Clean up
    physics.rigidbody_destroy(rb);
}