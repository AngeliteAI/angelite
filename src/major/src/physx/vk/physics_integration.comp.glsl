#version 450

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

layout(std430, binding = 0) restrict buffer RigidBodyBuffer {
    RigidBody bodies[];
} rigidbody_buffer;

layout(push_constant) uniform PushConstants {
    float delta_time;
    vec3 gravity;
    uint body_count;
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
    return vec4(normalize(axis) * s, cos(half_angle));
}

void main() {
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= constants.body_count) return;
    
    RigidBody body = rigidbody_buffer.bodies[idx];
    
    // Skip inactive or static bodies
    if (body.is_active == 0 || body.is_static == 1) return;
    
    // Apply gravity
    vec3 gravity_force = constants.gravity * body.mass;
    body.force_accumulator += gravity_force;
    
    // Verlet integration for position
    vec3 acceleration = body.force_accumulator * body.inv_mass;
    
    // Calculate velocity from position history
    vec3 velocity = (body.position - body.prev_position) / constants.delta_time;
    
    // Apply damping to velocity
    velocity *= body.linear_damping;
    
    // Update position using damped velocity and acceleration
    vec3 new_position = body.position + velocity * constants.delta_time + acceleration * constants.delta_time * constants.delta_time;
    
    // Update positions
    body.prev_position = body.position;
    body.position = new_position;
    
    // Angular Verlet integration
    if (length(body.torque_accumulator) > 0.0) {
        // Convert torque to angular acceleration
        vec3 angular_acceleration = body.torque_accumulator / body.angular_moment;
        
        // Compute angular velocity from orientation difference
        vec4 orientation_diff = quat_multiply(body.orientation, vec4(-body.prev_orientation.xyz, body.prev_orientation.w));
        vec3 angular_velocity = 2.0 * orientation_diff.xyz / constants.delta_time;
        
        // Apply angular acceleration
        angular_velocity += angular_acceleration * constants.delta_time;
        
        // Apply angular damping
        angular_velocity *= body.angular_damping;
        
        // Integrate orientation
        vec4 rotation_delta = quat_from_axis_angle(angular_velocity, length(angular_velocity) * constants.delta_time);
        body.prev_orientation = body.orientation;
        body.orientation = quat_normalize(quat_multiply(rotation_delta, body.orientation));
    }
    
    // Clear force accumulators
    body.force_accumulator = vec3(0.0);
    body.torque_accumulator = vec3(0.0);
    
    // Write back to buffer
    rigidbody_buffer.bodies[idx] = body;
}