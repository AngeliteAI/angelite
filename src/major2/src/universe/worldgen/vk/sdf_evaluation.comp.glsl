#version 460
#extension GL_EXT_shader_atomic_float : enable
#extension GL_KHR_shader_subgroup_arithmetic : enable
#extension GL_EXT_scalar_block_layout : enable
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_ARB_gpu_shader_int64 : require

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// SDF node types
const uint SDF_SPHERE = 0;
const uint SDF_BOX = 1;
const uint SDF_PLANE = 2;
const uint SDF_CYLINDER = 3;
const uint SDF_TORUS = 4;
const uint SDF_CAPSULE = 5;
const uint SDF_CONE = 6;
const uint SDF_HEX_PRISM = 7;

// SDF operations
const uint SDF_UNION = 100;
const uint SDF_INTERSECTION = 101;
const uint SDF_DIFFERENCE = 102;
const uint SDF_SMOOTH_UNION = 103;
const uint SDF_SMOOTH_INTERSECTION = 104;
const uint SDF_SMOOTH_DIFFERENCE = 105;

// SDF transformations
const uint SDF_TRANSFORM = 200;
const uint SDF_TWIST = 201;
const uint SDF_BEND = 202;
const uint SDF_DISPLACEMENT = 203;
const uint SDF_REPETITION = 204;

// SDF tree node structure
struct SdfNode {
    uint type;
    uint padding1[3];  // Padding to align params to 16 bytes
    vec4 params[4];    // Parameters based on type (must be 16-byte aligned)
    uvec2 children;    // Child indices for operations
    uint padding2[2];  // Padding to ensure 16-byte alignment (80 bytes total)
};

// Buffer reference types
layout(buffer_reference, scalar, buffer_reference_align = 16) readonly buffer SdfTreeBuffer {
    SdfNode nodes[];
};

layout(buffer_reference, scalar, buffer_reference_align = 16) readonly buffer SdfParamsBuffer {
    vec4 bounds_min;
    vec4 bounds_max;
    uvec4 resolution;  // xyz = resolution, w = root node index
};

layout(buffer_reference, scalar, buffer_reference_align = 4) writeonly buffer OutputFieldBuffer {
    float distances[];
};

// Push constants with buffer addresses
layout(push_constant) uniform PushConstants {
    uint64_t sdf_tree_address;
    uint64_t params_address;
    uint64_t output_field_address;
    uint64_t world_params_address;    // For binding 4
    uint64_t output_voxels_address;   // For binding 5
    uint64_t brush_program_address;   // Not used in SDF evaluation
    uint64_t brush_layers_address;    // Not used in SDF evaluation
    uint workgroup_offset;            // Not used in SDF evaluation  
    uint total_workgroups;            // Not used in SDF evaluation
} push;

// Stack for tree traversal
const int MAX_STACK_SIZE = 64;

// Primitive distance functions
float sdSphere(vec3 p, vec3 center, float radius) {
    return length(p - center) - radius;
}

float sdBox(vec3 p, vec3 center, vec3 half_extents) {
    vec3 q = abs(p - center) - half_extents;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdPlane(vec3 p, vec3 normal, float distance) {
    // Plane equation: dot(p, normal) - distance
    // For a plane at z=0 with normal pointing up (0,0,1), points below have negative SDF
    return dot(p, normal) - distance;
}

float sdCylinder(vec3 p, vec3 base, float height, float radius) {
    vec3 pa = p - base;
    float d = length(pa.xz) - radius;
    float h = max(abs(pa.y) - height * 0.5, 0.0);
    return sqrt(max(d, 0.0) * max(d, 0.0) + h * h) + min(max(d, -h), 0.0);
}

float sdTorus(vec3 p, vec3 center, float major_radius, float minor_radius) {
    vec3 q = p - center;
    vec2 t = vec2(length(q.xz) - major_radius, q.y);
    return length(t) - minor_radius;
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float radius) {
    vec3 pa = p - a;
    vec3 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - radius;
}

float sdCone(vec3 p, vec3 base, float height, float radius) {
    vec3 q = p - base;
    float h2 = height * height;
    float r2 = radius * radius;
    float d1 = -q.y - height;
    float d2 = max(dot(vec2(length(q.xz), q.y), vec2(height, radius) / sqrt(h2 + r2)), q.y);
    return length(max(vec2(d1, d2), 0.0)) + min(max(d1, d2), 0.0);
}

float sdHexPrism(vec3 p, vec3 center, float radius, float height) {
    vec3 q = abs(p - center);
    const vec3 k = vec3(-0.8660254, 0.5, 0.57735);
    q = q.xzy;
    q.xy -= 2.0 * min(dot(k.xy, q.xy), 0.0) * k.xy;
    vec2 d = vec2(
        length(q.xy - vec2(clamp(q.x, -k.z * radius, k.z * radius), radius)) * sign(q.y - radius),
        q.z - height
    );
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// Operation functions
float opUnion(float d1, float d2) {
    return min(d1, d2);
}

float opIntersection(float d1, float d2) {
    return max(d1, d2);
}

float opDifference(float d1, float d2) {
    return max(d1, -d2);
}

float opSmoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

float opSmoothIntersection(float d1, float d2, float k) {
    float h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) + k * h * (1.0 - h);
}

float opSmoothDifference(float d1, float d2, float k) {
    float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
    return mix(d1, -d2, h) + k * h * (1.0 - h);
}

// Transform functions
vec3 opTransform(vec3 p, mat4 transform) {
    return (inverse(transform) * vec4(p, 1.0)).xyz;
}

vec3 opTwist(vec3 p, float angle) {
    float c = cos(angle * p.y);
    float s = sin(angle * p.y);
    mat2 m = mat2(c, -s, s, c);
    vec3 q = p;
    q.xz = m * q.xz;
    return q;
}

vec3 opBend(vec3 p, float angle) {
    float c = cos(angle * p.x);
    float s = sin(angle * p.x);
    mat2 m = mat2(c, -s, s, c);
    vec3 q = p;
    q.xy = m * q.xy;
    return q;
}

float opDisplacement(float d, vec3 p, float amplitude, float frequency) {
    return d + amplitude * sin(frequency * p.x) * sin(frequency * p.y) * sin(frequency * p.z);
}

vec3 opRepetition(vec3 p, vec3 period) {
    return mod(p + 0.5 * period, period) - 0.5 * period;
}

// Quaternion operations
vec3 rotateByQuaternion(vec3 v, vec4 q) {
    vec3 u = q.xyz;
    float s = q.w;
    return 2.0 * dot(u, v) * u + (s * s - dot(u, u)) * v + 2.0 * s * cross(u, v);
}

// Stack entry for iterative evaluation
struct StackEntry {
    uint node_idx;
    vec3 position;
    uint state; // 0 = not started, 1 = left child done, 2 = both children done
    float left_result;
};

// Evaluate SDF iteratively
float evaluateSdf(vec3 world_pos, uint root_idx, SdfTreeBuffer sdf_tree) {
    StackEntry stack[MAX_STACK_SIZE];
    int stack_ptr = 0;
    
    // Initialize with root
    stack[0].node_idx = root_idx;
    stack[0].position = world_pos;
    stack[0].state = 0;
    stack[0].left_result = 0.0;
    stack_ptr = 1;
    
    float result = 0.0;
    
    while (stack_ptr > 0) {
        int current = stack_ptr - 1;
        StackEntry entry = stack[current];
        SdfNode node = sdf_tree.nodes[entry.node_idx];
        
        // Handle primitives
        if (node.type < 100) {
            float dist = 1e10;
            
            if (node.type == SDF_SPHERE) {
                dist = sdSphere(entry.position, node.params[0].xyz, node.params[0].w);
            } else if (node.type == SDF_BOX) {
                dist = sdBox(entry.position, node.params[0].xyz, node.params[1].xyz);
            } else if (node.type == SDF_PLANE) {
                dist = sdPlane(entry.position, node.params[0].xyz, node.params[0].w);
            } else if (node.type == SDF_CYLINDER) {
                dist = sdCylinder(entry.position, node.params[0].xyz, node.params[0].w, node.params[1].x);
            } else if (node.type == SDF_TORUS) {
                dist = sdTorus(entry.position, node.params[0].xyz, node.params[0].w, node.params[1].x);
            } else if (node.type == SDF_CAPSULE) {
                dist = sdCapsule(entry.position, node.params[0].xyz, node.params[1].xyz, node.params[0].w);
            } else if (node.type == SDF_CONE) {
                dist = sdCone(entry.position, node.params[0].xyz, node.params[0].w, node.params[1].x);
            } else if (node.type == SDF_HEX_PRISM) {
                dist = sdHexPrism(entry.position, node.params[0].xyz, node.params[0].w, node.params[1].x);
            }
            
            result = dist;
            stack_ptr--;
        }
        // Handle transforms (single child)
        else if (node.type >= 200 && node.type < 300) {
            if (entry.state == 0) {
                // Transform the position and evaluate child
                vec3 transformed_pos = entry.position;
                
                if (node.type == SDF_TRANSFORM) {
                    vec3 position = node.params[0].xyz;
                    vec4 rotation = node.params[1];
                    vec3 scale = node.params[2].xyz;
                    
                    transformed_pos = (transformed_pos - position) / scale;
                    transformed_pos = rotateByQuaternion(transformed_pos, vec4(-rotation.xyz, rotation.w));
                } else if (node.type == SDF_TWIST) {
                    transformed_pos = opTwist(transformed_pos, node.params[0].x);
                } else if (node.type == SDF_BEND) {
                    transformed_pos = opBend(transformed_pos, node.params[0].x);
                }
                
                // Push child with transformed position
                stack[current].state = 1;
                stack[stack_ptr].node_idx = node.children.x;
                stack[stack_ptr].position = transformed_pos;
                stack[stack_ptr].state = 0;
                stack_ptr++;
            } else {
                // Child evaluation complete
                if (node.type == SDF_TRANSFORM) {
                    vec3 scale = node.params[2].xyz;
                    result *= min(min(scale.x, scale.y), scale.z);
                }
                stack_ptr--;
            }
        }
        // Handle CSG operations (two children)
        else if (node.type >= 100 && node.type < 200) {
            if (entry.state == 0) {
                // Evaluate left child
                stack[current].state = 1;
                stack[stack_ptr].node_idx = node.children.x;
                stack[stack_ptr].position = entry.position;
                stack[stack_ptr].state = 0;
                stack_ptr++;
            } else if (entry.state == 1) {
                // Left child done, store result and evaluate right
                stack[current].left_result = result;
                stack[current].state = 2;
                stack[stack_ptr].node_idx = node.children.y;
                stack[stack_ptr].position = entry.position;
                stack[stack_ptr].state = 0;
                stack_ptr++;
            } else {
                // Both children done, combine results
                float d1 = entry.left_result;
                float d2 = result;
                
                if (node.type == SDF_UNION) {
                    result = opUnion(d1, d2);
                } else if (node.type == SDF_INTERSECTION) {
                    result = opIntersection(d1, d2);
                } else if (node.type == SDF_DIFFERENCE) {
                    result = opDifference(d1, d2);
                } else if (node.type == SDF_SMOOTH_UNION) {
                    result = opSmoothUnion(d1, d2, node.params[0].x);
                } else if (node.type == SDF_SMOOTH_INTERSECTION) {
                    result = opSmoothIntersection(d1, d2, node.params[0].x);
                } else if (node.type == SDF_SMOOTH_DIFFERENCE) {
                    result = opSmoothDifference(d1, d2, node.params[0].x);
                }
                
                stack_ptr--;
            }
        } else {
            // Unknown node type
            result = 1e10;
            stack_ptr--;
        }
    }
    
    return result;
}

void main() {
    // Get buffer references from push constants
    SdfTreeBuffer sdf_tree = SdfTreeBuffer(push.sdf_tree_address);
    SdfParamsBuffer params = SdfParamsBuffer(push.params_address);
    OutputFieldBuffer output_field = OutputFieldBuffer(push.output_field_address);
    
    uvec3 gid = gl_GlobalInvocationID;
    uvec3 resolution = params.resolution.xyz;
    
    if (any(greaterThanEqual(gid, resolution))) {
        return;
    }
    
    // Convert grid coordinates to world space
    vec3 bounds_min = params.bounds_min.xyz;
    vec3 bounds_max = params.bounds_max.xyz;
    vec3 bounds_size = bounds_max - bounds_min;
    vec3 grid_pos = vec3(gid) / vec3(resolution - 1u);
    vec3 world_pos = bounds_min + grid_pos * bounds_size;
    
    // Evaluate SDF at this position
    uint root_idx = params.resolution.w;
    float distance = evaluateSdf(world_pos, root_idx, sdf_tree);
    
    // Write result
    uint linear_idx = gid.x + gid.y * resolution.x + gid.z * resolution.x * resolution.y;
    output_field.distances[linear_idx] = distance;
}