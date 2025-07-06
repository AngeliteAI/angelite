#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_ARB_gpu_shader_int64 : require

// Verlet integration compute shader for voxel physics

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct RigidBody {
    // Current state
    vec3 position;
    float padding0;
    vec4 orientation; // quaternion (x,y,z,w)
    
    // Previous state for Verlet integration
    vec3 prev_position;
    float padding1;
    vec4 prev_orientation;
    
    // Physical properties
    float mass;
    float inv_mass;
    float friction;
    float restitution;
    
    float linear_damping;
    float angular_damping;
    vec3 angular_moment;
    float padding2;
    vec3 center_of_mass;
    float padding3;
    
    // Oriented bounding box
    vec3 half_extents;
    float padding4;
    
    // Forces accumulated this frame
    vec3 force_accumulator;
    float padding5;
    vec3 torque_accumulator;
    float padding6;
    
    // Collision response
    vec3 collision_normal;
    float collision_depth;
    
    // Flags
    uint is_static;
    uint is_active;
    uint padding7;
    uint padding8;
};

// Buffer reference for rigid bodies
layout(buffer_reference, std430, buffer_reference_align = 16) restrict buffer RigidBodyBuffer {
    RigidBody bodies[];
};

// Push constants with buffer addresses
layout(push_constant) uniform PushConstants {
    uint64_t rigidbodies_address;
    uint64_t collision_pairs_address;
    uint64_t contacts_address;
    float delta_time;
    float gravity_x;
    float gravity_y;
    float gravity_z;
    uint body_count;
    uint substeps;
    uint padding0;
    uint padding1;
} constants;

// Quaternion multiplication
vec4 quat_multiply(vec4 a, vec4 b) {
    return vec4(
        a.w * b.xyz + b.w * a.xyz + cross(a.xyz, b.xyz),
        a.w * b.w - dot(a.xyz, b.xyz)
    );
}

// Normalize quaternion
vec4 quat_normalize(vec4 q) {
    float len = length(q);
    return len > 0.0 ? q / len : vec4(0, 0, 0, 1);
}

// Create quaternion from axis and angle
vec4 quat_from_axis_angle(vec3 axis, float angle) {
    float half_angle = angle * 0.5;
    float s = sin(half_angle);
    return vec4(axis * s, cos(half_angle));
}

void main() {
    // Get buffer reference
    RigidBodyBuffer rigidbody_buffer = RigidBodyBuffer(constants.rigidbodies_address);
    
    uint body_idx = gl_GlobalInvocationID.x;
    if (body_idx >= constants.body_count) return;
    
    RigidBody body = rigidbody_buffer.bodies[body_idx];
    
    // Skip inactive or static bodies
    if (body.is_active == 0 || body.is_static != 0) return;
    
    // Apply gravity
    vec3 gravity = vec3(constants.gravity_x, constants.gravity_y, constants.gravity_z);
    vec3 gravity_force = gravity * body.mass;
    body.force_accumulator += gravity_force;
    
    // Verlet integration for linear motion
    vec3 acceleration = body.force_accumulator * body.inv_mass;
    
    // Calculate velocity for damping
    vec3 velocity = (body.position - body.prev_position) / constants.delta_time;
    
    // Apply linear damping
    vec3 damping_force = -velocity * body.linear_damping;
    acceleration += damping_force * body.inv_mass;
    
    // Update position using Verlet integration
    vec3 new_position = body.position + (body.position - body.prev_position) * (1.0 - body.linear_damping * constants.delta_time) + acceleration * constants.delta_time * constants.delta_time;
    
    // Store previous position
    body.prev_position = body.position;
    body.position = new_position;
    
    // Handle angular motion
    if (length(body.torque_accumulator) > 0.0) {
        // Calculate angular acceleration
        vec3 angular_acceleration = body.torque_accumulator / body.angular_moment;
        
        // Estimate angular velocity from previous orientation change
        // This is approximate but works for Verlet-style integration
        vec3 angular_velocity = angular_acceleration * constants.delta_time;
        
        // Apply angular damping
        angular_velocity *= (1.0 - body.angular_damping * constants.delta_time);
        
        // Convert to quaternion rotation
        float angle = length(angular_velocity) * constants.delta_time;
        if (angle > 0.001) {
            vec3 axis = normalize(angular_velocity);
            vec4 rotation_delta = quat_from_axis_angle(axis, angle);
            
            // Update orientation
            body.prev_orientation = body.orientation;
            body.orientation = quat_normalize(quat_multiply(rotation_delta, body.orientation));
        }
    }
    
    // Clear force and torque accumulators
    body.force_accumulator = vec3(0.0);
    body.torque_accumulator = vec3(0.0);
    
    // Write back to buffer
    rigidbody_buffer.bodies[body_idx] = body;
}