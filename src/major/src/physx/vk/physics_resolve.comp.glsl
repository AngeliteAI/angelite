#version 450

// Collision resolution compute shader

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

struct RigidBody {
    vec3 position;
    float padding0;
    vec4 orientation;
    vec3 prev_position;
    float padding1;
    vec4 prev_orientation;
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
    vec3 half_extents;
    float padding4;
    vec3 force_accumulator;
    float padding5;
    vec3 torque_accumulator;
    float padding6;
    vec3 collision_normal;
    float collision_depth;
    uint is_static;
    uint is_active;
    uint padding7;
    uint padding8;
};

struct CollisionPair {
    uint body_a;
    uint body_b;
    uint padding0;
    uint padding1;
};

struct ContactInfo {
    vec3 position;
    float penetration;
    vec3 normal;
    float padding;
};

layout(std430, binding = 0) restrict buffer RigidBodyBuffer {
    RigidBody bodies[];
} rigidbody_buffer;

layout(std430, binding = 1) restrict readonly buffer CollisionPairBuffer {
    uint pair_count;
    CollisionPair pairs[];
} collision_pairs;

layout(std430, binding = 2) restrict readonly buffer ContactBuffer {
    uint contact_count;
    ContactInfo contacts[];
} contact_buffer;

layout(push_constant) uniform PushConstants {
    float delta_time;
} constants;

void main() {
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= collision_pairs.pair_count) return;
    
    CollisionPair pair = collision_pairs.pairs[idx];
    RigidBody body_a = rigidbody_buffer.bodies[pair.body_a];
    RigidBody body_b = rigidbody_buffer.bodies[pair.body_b];
    
    // Skip if both are static
    if (body_a.is_static == 1 && body_b.is_static == 1) return;
    
    // Simple position-based collision resolution
    // Calculate center-to-center vector
    vec3 delta = body_b.position - body_a.position;
    float distance = length(delta);
    
    if (distance < 0.001) {
        // Bodies are at same position, push apart arbitrarily
        delta = vec3(1, 0, 0);
        distance = 1.0;
    }
    
    vec3 normal = delta / distance;
    
    // Calculate penetration depth (sum of radii minus distance)
    float radius_a = length(body_a.half_extents);
    float radius_b = length(body_b.half_extents);
    float penetration = radius_a + radius_b - distance;
    
    if (penetration > 0) {
        // Resolve penetration
        if (body_a.is_static == 0 && body_b.is_static == 1) {
            // Move only body A
            rigidbody_buffer.bodies[pair.body_a].position -= normal * penetration;
        } else if (body_a.is_static == 1 && body_b.is_static == 0) {
            // Move only body B
            rigidbody_buffer.bodies[pair.body_b].position += normal * penetration;
        } else {
            // Move both bodies
            float total_inv_mass = body_a.inv_mass + body_b.inv_mass;
            if (total_inv_mass > 0) {
                float weight_a = body_a.inv_mass / total_inv_mass;
                float weight_b = body_b.inv_mass / total_inv_mass;
                
                rigidbody_buffer.bodies[pair.body_a].position -= normal * penetration * weight_a;
                rigidbody_buffer.bodies[pair.body_b].position += normal * penetration * weight_b;
            }
        }
        
        // Apply restitution (bounce)
        vec3 relative_velocity = (body_b.position - body_b.prev_position) - (body_a.position - body_a.prev_position);
        float velocity_along_normal = dot(relative_velocity, normal);
        
        if (velocity_along_normal < 0) {
            float restitution = min(body_a.restitution, body_b.restitution);
            float impulse_magnitude = -(1.0 + restitution) * velocity_along_normal;
            
            if (body_a.is_static == 0 && body_b.is_static == 0) {
                float total_inv_mass = body_a.inv_mass + body_b.inv_mass;
                if (total_inv_mass > 0) {
                    impulse_magnitude /= total_inv_mass;
                    vec3 impulse = normal * impulse_magnitude;
                    
                    // Apply impulse to velocities (by modifying previous positions for Verlet)
                    rigidbody_buffer.bodies[pair.body_a].prev_position += impulse * body_a.inv_mass * constants.delta_time;
                    rigidbody_buffer.bodies[pair.body_b].prev_position -= impulse * body_b.inv_mass * constants.delta_time;
                }
            }
        }
    }
}