#version 450

// Broad phase collision detection using spatial hashing for rotated AABBs

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

layout(std430, binding = 0) restrict readonly buffer RigidBodyBuffer {
    RigidBody bodies[];
} rigidbody_buffer;

layout(std430, binding = 1) restrict buffer CollisionPairBuffer {
    uint pair_count;
    CollisionPair pairs[];
} collision_pairs;

layout(push_constant) uniform PushConstants {
    uint body_count;
    float cell_size; // Size of spatial hash grid cells
} constants;

// Rotate a vector by quaternion
vec3 quat_rotate(vec4 q, vec3 v) {
    vec3 u = q.xyz;
    float s = q.w;
    return 2.0 * dot(u, v) * u + (s * s - dot(u, u)) * v + 2.0 * s * cross(u, v);
}

// Get world-space AABB for rotated box
void get_world_aabb(vec3 position, vec4 orientation, vec3 half_extents, out vec3 aabb_min, out vec3 aabb_max) {
    // Get absolute values of rotated axes scaled by half extents
    vec3 abs_x = abs(quat_rotate(orientation, vec3(1, 0, 0))) * half_extents.x;
    vec3 abs_y = abs(quat_rotate(orientation, vec3(0, 1, 0))) * half_extents.y;
    vec3 abs_z = abs(quat_rotate(orientation, vec3(0, 0, 1))) * half_extents.z;
    
    // Sum to get the maximum extent in each world axis
    vec3 world_half_extents = abs_x + abs_y + abs_z;
    
    aabb_min = position - world_half_extents;
    aabb_max = position + world_half_extents;
}

// Check if two AABBs overlap
bool aabb_overlap(vec3 min_a, vec3 max_a, vec3 min_b, vec3 max_b) {
    return all(lessThanEqual(min_a, max_b)) && all(lessThanEqual(min_b, max_a));
}

// Simple spatial hash function
uint hash_position(ivec3 grid_pos) {
    const uint p1 = 73856093u;
    const uint p2 = 19349663u;
    const uint p3 = 83492791u;
    return (uint(grid_pos.x) * p1) ^ (uint(grid_pos.y) * p2) ^ (uint(grid_pos.z) * p3);
}

void main() {
    uint idx_a = gl_GlobalInvocationID.x;
    if (idx_a >= constants.body_count) return;
    
    RigidBody body_a = rigidbody_buffer.bodies[idx_a];
    if (body_a.is_active == 0) return;
    
    // Get world AABB for body A
    vec3 aabb_min_a, aabb_max_a;
    get_world_aabb(body_a.position, body_a.orientation, body_a.half_extents, aabb_min_a, aabb_max_a);
    
    // Check against all other bodies (simple O(n²) for now)
    // TODO: Implement spatial hashing for better performance
    for (uint idx_b = idx_a + 1; idx_b < constants.body_count; idx_b++) {
        RigidBody body_b = rigidbody_buffer.bodies[idx_b];
        if (body_b.is_active == 0) continue;
        
        // Skip if both are static
        if (body_a.is_static == 1 && body_b.is_static == 1) continue;
        
        // Get world AABB for body B
        vec3 aabb_min_b, aabb_max_b;
        get_world_aabb(body_b.position, body_b.orientation, body_b.half_extents, aabb_min_b, aabb_max_b);
        
        // Check AABB overlap
        if (aabb_overlap(aabb_min_a, aabb_max_a, aabb_min_b, aabb_max_b)) {
            // Add collision pair
            uint pair_idx = atomicAdd(collision_pairs.pair_count, 1);
            if (pair_idx < collision_pairs.pairs.length()) {
                collision_pairs.pairs[pair_idx].body_a = idx_a;
                collision_pairs.pairs[pair_idx].body_b = idx_b;
            }
        }
    }
}