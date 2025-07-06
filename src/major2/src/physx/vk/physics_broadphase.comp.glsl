#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_ARB_gpu_shader_int64 : require

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

// Buffer references
layout(buffer_reference, std430, buffer_reference_align = 16) restrict readonly buffer RigidBodyBuffer {
    RigidBody bodies[];
};

layout(buffer_reference, std430, buffer_reference_align = 16) restrict buffer CollisionPairBuffer {
    uint pair_count;
    uint padding[3];
    CollisionPair pairs[];
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

// Shared memory for local collision pairs
shared uint local_pairs[256];
shared uint local_pair_count;

// Quaternion to rotation matrix
mat3 quat_to_matrix(vec4 q) {
    float xx = q.x * q.x;
    float yy = q.y * q.y;
    float zz = q.z * q.z;
    float xy = q.x * q.y;
    float xz = q.x * q.z;
    float yz = q.y * q.z;
    float wx = q.w * q.x;
    float wy = q.w * q.y;
    float wz = q.w * q.z;
    
    return mat3(
        1.0 - 2.0 * (yy + zz), 2.0 * (xy - wz), 2.0 * (xz + wy),
        2.0 * (xy + wz), 1.0 - 2.0 * (xx + zz), 2.0 * (yz - wx),
        2.0 * (xz - wy), 2.0 * (yz + wx), 1.0 - 2.0 * (xx + yy)
    );
}

// Get world space AABB for rotated box
void get_world_aabb(RigidBody body, out vec3 aabb_min, out vec3 aabb_max) {
    mat3 rotation = quat_to_matrix(body.orientation);
    
    // Transform the 8 corners of the OBB
    vec3 extent = body.half_extents;
    vec3 corners[8] = vec3[](
        rotation * vec3(-extent.x, -extent.y, -extent.z),
        rotation * vec3( extent.x, -extent.y, -extent.z),
        rotation * vec3(-extent.x,  extent.y, -extent.z),
        rotation * vec3( extent.x,  extent.y, -extent.z),
        rotation * vec3(-extent.x, -extent.y,  extent.z),
        rotation * vec3( extent.x, -extent.y,  extent.z),
        rotation * vec3(-extent.x,  extent.y,  extent.z),
        rotation * vec3( extent.x,  extent.y,  extent.z)
    );
    
    // Find min/max bounds
    aabb_min = body.position + corners[0];
    aabb_max = body.position + corners[0];
    
    for (int i = 1; i < 8; i++) {
        vec3 world_corner = body.position + corners[i];
        aabb_min = min(aabb_min, world_corner);
        aabb_max = max(aabb_max, world_corner);
    }
}

void main() {
    // Get buffer references
    RigidBodyBuffer rigidbody_buffer = RigidBodyBuffer(constants.rigidbodies_address);
    CollisionPairBuffer collision_pairs = CollisionPairBuffer(constants.collision_pairs_address);
    
    uint body_idx = gl_GlobalInvocationID.x;
    
    // Initialize shared memory
    if (gl_LocalInvocationID.x == 0) {
        local_pair_count = 0;
    }
    barrier();
    
    if (body_idx >= constants.body_count) return;
    
    RigidBody body_a = rigidbody_buffer.bodies[body_idx];
    if (body_a.is_active == 0) return;
    
    // Get world AABB for body A
    vec3 aabb_a_min, aabb_a_max;
    get_world_aabb(body_a, aabb_a_min, aabb_a_max);
    
    // Check against all other bodies
    for (uint j = body_idx + 1; j < constants.body_count; j++) {
        RigidBody body_b = rigidbody_buffer.bodies[j];
        if (body_b.is_active == 0) continue;
        if (body_a.is_static != 0 && body_b.is_static != 0) continue;
        
        // Get world AABB for body B
        vec3 aabb_b_min, aabb_b_max;
        get_world_aabb(body_b, aabb_b_min, aabb_b_max);
        
        // AABB vs AABB test
        if (all(lessThanEqual(aabb_a_min, aabb_b_max)) && 
            all(lessThanEqual(aabb_b_min, aabb_a_max))) {
            
            // Add to local pairs
            uint local_idx = atomicAdd(local_pair_count, 1);
            if (local_idx < 128) {  // Store up to 128 pairs per workgroup
                local_pairs[local_idx * 2] = body_idx;
                local_pairs[local_idx * 2 + 1] = j;
            }
        }
    }
    
    barrier();
    
    // Write local pairs to global buffer
    if (gl_LocalInvocationID.x == 0 && local_pair_count > 0) {
        uint base_idx = atomicAdd(collision_pairs.pair_count, local_pair_count);
        
        for (uint i = 0; i < min(local_pair_count, 128); i++) {
            if (base_idx + i < 4096) {  // MAX_COLLISION_PAIRS
                collision_pairs.pairs[base_idx + i].body_a = local_pairs[i * 2];
                collision_pairs.pairs[base_idx + i].body_b = local_pairs[i * 2 + 1];
            }
        }
    }
}