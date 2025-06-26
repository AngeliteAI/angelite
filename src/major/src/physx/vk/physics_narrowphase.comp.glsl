#version 450

// Narrow phase collision detection for rotated AABBs using SAT (Separating Axis Theorem)

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
    CollisionPair pairs[];
} collision_pairs;

layout(std430, binding = 2) restrict buffer ContactBuffer {
    uint contact_count;
    ContactInfo contacts[];
} contact_buffer;

layout(push_constant) uniform PushConstants {
    uint pair_count;
} constants;

// Rotate a vector by quaternion
vec3 quat_rotate(vec4 q, vec3 v) {
    vec3 u = q.xyz;
    float s = q.w;
    return 2.0 * dot(u, v) * u + (s * s - dot(u, u)) * v + 2.0 * s * cross(u, v);
}

// Get the support point of an OBB in a given direction
vec3 get_support(vec3 position, vec4 orientation, vec3 half_extents, vec3 direction) {
    // Transform direction to local space
    vec3 local_dir = quat_rotate(vec4(-orientation.xyz, orientation.w), direction);
    
    // Get support in local space
    vec3 support = half_extents * sign(local_dir);
    
    // Transform back to world space
    return position + quat_rotate(orientation, support);
}

// Project OBB onto axis and get min/max
vec2 project_obb(vec3 position, vec4 orientation, vec3 half_extents, vec3 axis) {
    // Get box corners in local space
    vec3 corners[8] = {
        vec3(-1, -1, -1), vec3(1, -1, -1), vec3(-1, 1, -1), vec3(1, 1, -1),
        vec3(-1, -1, 1), vec3(1, -1, 1), vec3(-1, 1, 1), vec3(1, 1, 1)
    };
    
    float min_proj = 1e10;
    float max_proj = -1e10;
    
    for (int i = 0; i < 8; i++) {
        vec3 world_corner = position + quat_rotate(orientation, corners[i] * half_extents);
        float proj = dot(world_corner, axis);
        min_proj = min(min_proj, proj);
        max_proj = max(max_proj, proj);
    }
    
    return vec2(min_proj, max_proj);
}

// SAT test for two OBBs
bool test_sat_axis(vec3 pos_a, vec4 orient_a, vec3 half_a,
                   vec3 pos_b, vec4 orient_b, vec3 half_b,
                   vec3 axis, inout float min_penetration, inout vec3 min_axis) {
    vec2 proj_a = project_obb(pos_a, orient_a, half_a, axis);
    vec2 proj_b = project_obb(pos_b, orient_b, half_b, axis);
    
    // Check for separation
    if (proj_a.y < proj_b.x || proj_b.y < proj_a.x) {
        return false; // Separated
    }
    
    // Calculate penetration
    float penetration = min(proj_a.y - proj_b.x, proj_b.y - proj_a.x);
    
    if (penetration < min_penetration) {
        min_penetration = penetration;
        min_axis = axis;
    }
    
    return true;
}

// Full SAT collision test between two OBBs
bool collide_obbs(RigidBody body_a, RigidBody body_b, out ContactInfo contact) {
    float min_penetration = 1e10;
    vec3 min_axis = vec3(0);
    
    // Get axes for both boxes
    vec3 axes_a[3] = {
        quat_rotate(body_a.orientation, vec3(1, 0, 0)),
        quat_rotate(body_a.orientation, vec3(0, 1, 0)),
        quat_rotate(body_a.orientation, vec3(0, 0, 1))
    };
    
    vec3 axes_b[3] = {
        quat_rotate(body_b.orientation, vec3(1, 0, 0)),
        quat_rotate(body_b.orientation, vec3(0, 1, 0)),
        quat_rotate(body_b.orientation, vec3(0, 0, 1))
    };
    
    // Test face normals of A
    for (int i = 0; i < 3; i++) {
        if (!test_sat_axis(body_a.position, body_a.orientation, body_a.half_extents,
                          body_b.position, body_b.orientation, body_b.half_extents,
                          axes_a[i], min_penetration, min_axis)) {
            return false;
        }
    }
    
    // Test face normals of B
    for (int i = 0; i < 3; i++) {
        if (!test_sat_axis(body_a.position, body_a.orientation, body_a.half_extents,
                          body_b.position, body_b.orientation, body_b.half_extents,
                          axes_b[i], min_penetration, min_axis)) {
            return false;
        }
    }
    
    // Test cross products of edges
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            vec3 axis = cross(axes_a[i], axes_b[j]);
            if (length(axis) > 0.0001) {
                axis = normalize(axis);
                if (!test_sat_axis(body_a.position, body_a.orientation, body_a.half_extents,
                                  body_b.position, body_b.orientation, body_b.half_extents,
                                  axis, min_penetration, min_axis)) {
                    return false;
                }
            }
        }
    }
    
    // Ensure normal points from A to B
    vec3 center_diff = body_b.position - body_a.position;
    if (dot(min_axis, center_diff) < 0) {
        min_axis = -min_axis;
    }
    
    // Find contact point (simplified - use center of overlap)
    vec3 contact_point = (body_a.position + body_b.position) * 0.5;
    
    contact.position = contact_point;
    contact.normal = normalize(min_axis);
    contact.penetration = min_penetration;
    
    return true;
}

void main() {
    uint idx = gl_GlobalInvocationID.x;
    if (idx >= constants.pair_count) return;
    
    CollisionPair pair = collision_pairs.pairs[idx];
    RigidBody body_a = rigidbody_buffer.bodies[pair.body_a];
    RigidBody body_b = rigidbody_buffer.bodies[pair.body_b];
    
    ContactInfo contact;
    if (collide_obbs(body_a, body_b, contact)) {
        // Store contact for resolution
        uint contact_idx = atomicAdd(contact_buffer.contact_count, 1);
        if (contact_idx < contact_buffer.contacts.length()) {
            contact_buffer.contacts[contact_idx] = contact;
        }
    }
}