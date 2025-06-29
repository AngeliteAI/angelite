#version 460
#extension GL_EXT_shader_atomic_float : enable
#extension GL_KHR_shader_subgroup_arithmetic : enable
#extension GL_EXT_scalar_block_layout : enable

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
    vec4 params[4];    // Parameters based on type
    uvec2 children;    // Child indices for operations
    // No padding needed with scalar layout
};

// Input buffers
layout(scalar, binding = 0) readonly buffer SdfTree {
    SdfNode nodes[];
} sdf_tree;

layout(scalar, binding = 1) readonly buffer SdfParams {
    vec4 bounds_min;
    vec4 bounds_max;
    uvec4 resolution;  // xyz = resolution, w = root node index
} params;

// Output buffer
layout(scalar, binding = 2) writeonly buffer OutputField {
    float distances[];
} output_field;

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
    return dot(p, normal) + distance;
}

float sdCylinder(vec3 p, vec3 base, float height, float radius) {
    vec3 pa = p - base;
    float d = length(pa.xz) - radius;
    float h = max(abs(pa.y) - height * 0.5, 0.0);
    return sqrt(max(d, 0.0) * max(d, 0.0) + h * h) + min(max(d, -h), 0.0);
}

float sdTorus(vec3 p, vec3 center, float major_radius, float minor_radius) {
    vec3 pa = p - center;
    vec2 q = vec2(length(pa.xz) - major_radius, pa.y);
    return length(q) - minor_radius;
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float radius) {
    vec3 pa = p - a;
    vec3 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - radius;
}

float sdCone(vec3 p, vec3 tip, vec3 base, float radius) {
    vec3 ba = base - tip;
    vec3 pa = p - tip;
    float baba = dot(ba, ba);
    float paba = dot(pa, ba) / baba;
    float x = length(pa - ba * paba);
    float cax = max(0.0, radius - radius * paba);
    float cay = (paba < 0.5 ? -1.0 : 1.0) * sqrt(baba) * paba * (1.0 - paba);
    float k = sqrt(cax * cax + cay * cay);
    float f = x - cax * radius / k;
    float g = min(length(vec2(x, p.z - length(ba))), length(vec2(x, p.z)));
    return (paba < 0.0 || paba > 1.0) ? g : min(max(f, 0.0), g);
}

float sdHexPrism(vec3 p, vec3 center, float radius, float height) {
    vec3 pa = abs(p - center);
    const vec3 k = vec3(-0.8660254, 0.5, 0.57735);
    vec2 pxy = pa.xy;
    pxy -= 2.0 * min(dot(k.xy, pxy), 0.0) * k.xy;
    float d1 = length(pxy) - radius;
    float d2 = pa.z - height * 0.5;
    return max(d1, abs(d2));
}

// CSG operations
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

// Transformations
vec3 applyTransform(vec3 p, mat4 transform) {
    return (inverse(transform) * vec4(p, 1.0)).xyz;
}

vec3 opTwist(vec3 p, float amount) {
    float k = amount * p.y;
    float c = cos(k);
    float s = sin(k);
    mat2 m = mat2(c, -s, s, c);
    return vec3(m * p.xz, p.y);
}

vec3 opBend(vec3 p, float amount) {
    float k = amount * p.x;
    float c = cos(k);
    float s = sin(k);
    mat2 m = mat2(c, -s, s, c);
    return vec3(p.x, m * p.yz);
}

// Evaluate SDF tree
float evaluateSdf(vec3 position) {
    // Stack for iterative traversal
    uint stack[MAX_STACK_SIZE];
    float values[MAX_STACK_SIZE];
    int stack_ptr = 0;
    
    // Start with root node
    stack[0] = params.resolution.w;
    stack_ptr = 1;
    
    while (stack_ptr > 0) {
        uint node_idx = stack[--stack_ptr];
        SdfNode node = sdf_tree.nodes[node_idx];
        
        float result = 0.0;
        
        // Evaluate based on node type
        if (node.type < 100) {
            // Primitive
            switch (node.type) {
                case SDF_SPHERE:
                    result = sdSphere(position, node.params[0].xyz, node.params[0].w);
                    break;
                case SDF_BOX:
                    result = sdBox(position, node.params[0].xyz, node.params[1].xyz);
                    break;
                case SDF_PLANE:
                    result = sdPlane(position, node.params[0].xyz, node.params[0].w);
                    break;
                case SDF_CYLINDER:
                    result = sdCylinder(position, node.params[0].xyz, node.params[1].x, node.params[1].y);
                    break;
                case SDF_TORUS:
                    result = sdTorus(position, node.params[0].xyz, node.params[1].x, node.params[1].y);
                    break;
                case SDF_CAPSULE:
                    result = sdCapsule(position, node.params[0].xyz, node.params[1].xyz, node.params[2].x);
                    break;
                case SDF_CONE:
                    result = sdCone(position, node.params[0].xyz, node.params[1].xyz, node.params[2].x);
                    break;
                case SDF_HEX_PRISM:
                    result = sdHexPrism(position, node.params[0].xyz, node.params[1].x, node.params[1].y);
                    break;
            }
        } else if (node.type < 200) {
            // Binary operation - need to evaluate children first
            if (node.children.x != 0 && node.children.y != 0) {
                // This is a placeholder - in a real implementation we'd need to handle this properly
                float d1 = 0.0; // evaluateSdf for child 1
                float d2 = 0.0; // evaluateSdf for child 2
                
                switch (node.type) {
                    case SDF_UNION:
                        result = opUnion(d1, d2);
                        break;
                    case SDF_INTERSECTION:
                        result = opIntersection(d1, d2);
                        break;
                    case SDF_DIFFERENCE:
                        result = opDifference(d1, d2);
                        break;
                    case SDF_SMOOTH_UNION:
                        result = opSmoothUnion(d1, d2, node.params[0].x);
                        break;
                    case SDF_SMOOTH_INTERSECTION:
                        result = opSmoothIntersection(d1, d2, node.params[0].x);
                        break;
                    case SDF_SMOOTH_DIFFERENCE:
                        result = opSmoothDifference(d1, d2, node.params[0].x);
                        break;
                }
            }
        }
        
        values[stack_ptr] = result;
    }
    
    return values[0];
}

void main() {
    uvec3 id = gl_GlobalInvocationID;
    
    if (id.x >= params.resolution.x || 
        id.y >= params.resolution.y || 
        id.z >= params.resolution.z) {
        return;
    }
    
    // Calculate world position with better precision
    // Avoid division by very large numbers which can cause precision loss
    vec3 grid_size = vec3(params.resolution.xyz);
    vec3 bounds_size = params.bounds_max.xyz - params.bounds_min.xyz;
    vec3 voxel_size = bounds_size / grid_size;
    vec3 position = params.bounds_min.xyz + vec3(id) * voxel_size;
    
    // Evaluate SDF at this position
    float distance = evaluateSdf(position);
    
    // Write to output buffer
    uint index = id.z * params.resolution.x * params.resolution.y + 
                 id.y * params.resolution.x + 
                 id.x;
    output_field.distances[index] = distance;
    
    // Use subgroup operations for better performance
    if (gl_SubgroupInvocationID == 0) {
        // Prefetch next data
        float next_dist = subgroupMin(distance);
        // Can use this for adaptive sampling in future
    }
}