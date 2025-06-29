#version 460
#extension GL_GOOGLE_include_directive : enable
#extension GL_KHR_shader_subgroup_arithmetic : enable
#extension GL_EXT_scalar_block_layout : enable

layout(local_size_x = 64) in;

// Condition opcodes
const uint COND_HEIGHT = 0;
const uint COND_DEPTH = 1;
const uint COND_DISTANCE = 2;
const uint COND_SLOPE = 3;
const uint COND_CURVATURE = 4;
const uint COND_AMBIENT_OCCLUSION = 5;
const uint COND_NOISE_3D = 6;
const uint COND_VORONOI_CELL = 7;
const uint COND_TURBULENCE = 8;
const uint COND_CHECKERBOARD = 9;
const uint COND_STRIPES = 10;
const uint COND_AND = 20;
const uint COND_OR = 21;
const uint COND_NOT = 22;
const uint COND_XOR = 23;
const uint COND_INSIDE_SDF = 30;

// Brush instruction
struct BrushInstruction {
    uint opcode;
    vec4 params[2];
};

// Brush layer
struct BrushLayer {
    uint condition_start;
    uint condition_count;
    uint voxel_id;
    float blend_weight;
    int priority;
    // No padding needed with scalar layout
};

// Input buffers
layout(scalar, binding = 0) readonly buffer BrushProgram {
    BrushInstruction instructions[];
} brush_program;

layout(scalar, binding = 1) readonly buffer BrushLayers {
    BrushLayer layers[];
} brush_layers;

layout(scalar, binding = 2) readonly buffer SdfField {
    float distances[];
} sdf_field;

layout(scalar, binding = 3) readonly buffer NoiseTextures {
    float noise_data[];
} noise_textures;

layout(scalar, binding = 4) readonly buffer WorldParams {
    vec4 bounds_min;
    vec4 bounds_max;
    uvec4 dimensions; // xyz = dimensions, w = layer count
    vec4 voxel_size;  // xyz = size, w = time
} world_params;

// Output buffer
layout(scalar, binding = 5) writeonly buffer OutputVoxels {
    uint voxels[];
} output_voxels;

// Shared memory for condition evaluation stack
shared uint condition_stack[64 * 32]; // 32 stack entries per thread
shared float value_stack[64 * 32];

// Hash functions for procedural generation
uint hash(uint x) {
    x = ((x >> 16) ^ x) * 0x45d9f3b;
    x = ((x >> 16) ^ x) * 0x45d9f3b;
    x = (x >> 16) ^ x;
    return x;
}

float hashFloat(uint x) {
    return float(hash(x)) / float(0xFFFFFFFF);
}

vec3 hashVec3(vec3 p, uint seed) {
    uvec3 i = uvec3(p * 73.0) ^ seed;
    return vec3(
        hashFloat(i.x),
        hashFloat(i.y),
        hashFloat(i.z)
    );
}

// Noise functions
float gradientNoise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float n000 = dot(hashVec3(i + vec3(0,0,0), 0), f - vec3(0,0,0));
    float n001 = dot(hashVec3(i + vec3(0,0,1), 0), f - vec3(0,0,1));
    float n010 = dot(hashVec3(i + vec3(0,1,0), 0), f - vec3(0,1,0));
    float n011 = dot(hashVec3(i + vec3(0,1,1), 0), f - vec3(0,1,1));
    float n100 = dot(hashVec3(i + vec3(1,0,0), 0), f - vec3(1,0,0));
    float n101 = dot(hashVec3(i + vec3(1,0,1), 0), f - vec3(1,0,1));
    float n110 = dot(hashVec3(i + vec3(1,1,0), 0), f - vec3(1,1,0));
    float n111 = dot(hashVec3(i + vec3(1,1,1), 0), f - vec3(1,1,1));
    
    float x00 = mix(n000, n100, f.x);
    float x01 = mix(n001, n101, f.x);
    float x10 = mix(n010, n110, f.x);
    float x11 = mix(n011, n111, f.x);
    
    float y0 = mix(x00, x10, f.y);
    float y1 = mix(x01, x11, f.y);
    
    return mix(y0, y1, f.z);
}

float fractalNoise3D(vec3 p, uint octaves, float persistence, float lacunarity, uint seed) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float max_value = 0.0;
    
    for (uint i = 0; i < octaves; i++) {
        value += amplitude * gradientNoise3D(p * frequency + vec3(seed));
        max_value += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }
    
    return value / max_value;
}

// Voronoi noise
vec2 voronoiCell(vec3 p, uint seed) {
    vec3 cell = floor(p);
    vec3 local_p = fract(p);
    
    float min_dist = 999999.0;
    uint cell_id = 0;
    
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 neighbor = vec3(x, y, z);
                vec3 point = neighbor + hashVec3(cell + neighbor, seed);
                float dist = length(local_p - point);
                
                if (dist < min_dist) {
                    min_dist = dist;
                    cell_id = hash(uint(dot(cell + neighbor, vec3(73.0, 131.0, 197.0))));
                }
            }
        }
    }
    
    return vec2(float(cell_id), min_dist);
}

// Calculate surface normal from SDF gradient
vec3 calculateNormal(vec3 position, uint sdf_index) {
    const float h = 0.001;
    
    // Sample neighboring points
    float dx_pos = sdf_field.distances[sdf_index + 1];
    float dx_neg = sdf_field.distances[sdf_index - 1];
    float dy_pos = sdf_field.distances[sdf_index + world_params.dimensions.x];
    float dy_neg = sdf_field.distances[sdf_index - world_params.dimensions.x];
    float dz_pos = sdf_field.distances[sdf_index + world_params.dimensions.x * world_params.dimensions.y];
    float dz_neg = sdf_field.distances[sdf_index - world_params.dimensions.x * world_params.dimensions.y];
    
    vec3 gradient = vec3(
        dx_pos - dx_neg,
        dy_pos - dy_neg,
        dz_pos - dz_neg
    ) / (2.0 * h);
    
    return normalize(gradient);
}

// Evaluate a single condition
bool evaluateCondition(uint instruction_idx, vec3 position, float sdf_value, vec3 normal) {
    BrushInstruction inst = brush_program.instructions[instruction_idx];
    
    switch (inst.opcode) {
        case COND_HEIGHT:
            return position.y >= inst.params[0].x && position.y <= inst.params[0].y;
            
        case COND_DEPTH:
            // Depth is distance below surface (positive values)
            // When sdf_value is negative, we're inside the surface
            float depth = -sdf_value;
            return depth >= inst.params[0].x && depth <= inst.params[0].y;
            
        case COND_DISTANCE:
            float dist = length(position - inst.params[0].xyz);
            return dist >= inst.params[0].w && dist <= inst.params[1].x;
            
        case COND_SLOPE:
            float slope_angle = degrees(acos(normal.y));
            return slope_angle >= inst.params[0].x && slope_angle <= inst.params[0].y;
            
        case COND_NOISE_3D:
            float noise = fractalNoise3D(
                position * inst.params[0].x,  // scale
                uint(inst.params[0].y),        // octaves
                inst.params[0].z,              // persistence
                inst.params[0].w,              // lacunarity
                uint(inst.params[1].x)         // seed
            );
            return noise > inst.params[1].y;  // threshold
            
        case COND_VORONOI_CELL:
            vec2 voronoi = voronoiCell(position * inst.params[0].x, uint(inst.params[0].y));
            return uint(voronoi.x) == uint(inst.params[0].z);
            
        case COND_CHECKERBOARD:
            vec3 p = (position - inst.params[1].xyz) / inst.params[0].x;
            ivec3 i = ivec3(floor(p));
            return ((i.x ^ i.y ^ i.z) & 1) == 1;
            
        case COND_STRIPES:
            float stripe_pos = dot(position - vec3(inst.params[1].x, 0, 0), inst.params[0].xyz);
            return mod(stripe_pos, inst.params[0].w * 2.0) < inst.params[0].w;
    }
    
    return true;
}

// Evaluate condition tree with stack-based approach
bool evaluateConditionTree(uint start_idx, uint count, vec3 position, float sdf_value, vec3 normal) {
    uint stack_base = gl_LocalInvocationIndex * 32;
    uint stack_ptr = 0;
    
    // Push all instructions in reverse order
    for (uint i = 0; i < count; i++) {
        condition_stack[stack_base + stack_ptr++] = start_idx + count - 1 - i;
    }
    
    uint value_ptr = 0;
    
    while (stack_ptr > 0) {
        uint inst_idx = condition_stack[stack_base + --stack_ptr];
        BrushInstruction inst = brush_program.instructions[inst_idx];
        
        bool result = false;
        
        if (inst.opcode >= COND_AND && inst.opcode <= COND_XOR) {
            // Binary operation
            if (value_ptr >= 2) {
                bool b = value_stack[stack_base + --value_ptr] > 0.5;
                bool a = value_stack[stack_base + --value_ptr] > 0.5;
                
                switch (inst.opcode) {
                    case COND_AND:
                        result = a && b;
                        break;
                    case COND_OR:
                        result = a || b;
                        break;
                    case COND_XOR:
                        result = a != b;
                        break;
                }
            }
        } else if (inst.opcode == COND_NOT) {
            // Unary operation
            if (value_ptr >= 1) {
                bool a = value_stack[stack_base + --value_ptr] > 0.5;
                result = !a;
            }
        } else {
            // Leaf condition
            result = evaluateCondition(inst_idx, position, sdf_value, normal);
        }
        
        value_stack[stack_base + value_ptr++] = result ? 1.0 : 0.0;
    }
    
    return value_ptr > 0 && value_stack[stack_base + 0] > 0.5;
}

void main() {
    uint idx = gl_GlobalInvocationID.x;
    
    if (idx >= world_params.dimensions.x * world_params.dimensions.y * world_params.dimensions.z) {
        return;
    }
    
    // Calculate 3D position from linear index
    uint x = idx % world_params.dimensions.x;
    uint y = (idx / world_params.dimensions.x) % world_params.dimensions.y;
    uint z = idx / (world_params.dimensions.x * world_params.dimensions.y);
    
    // Calculate world position with better precision
    vec3 grid_size = vec3(world_params.dimensions.xyz);
    vec3 bounds_size = world_params.bounds_max.xyz - world_params.bounds_min.xyz;
    vec3 voxel_size = bounds_size / grid_size;
    vec3 position = world_params.bounds_min.xyz + vec3(x, y, z) * voxel_size;
    
    // Get SDF value
    float sdf_value = sdf_field.distances[idx];
    
    // Calculate normal
    vec3 normal = calculateNormal(position, idx);
    
    // Evaluate all brush layers
    uint selected_voxel = 0;
    float max_priority = -999999.0;
    
    for (uint layer_idx = 0; layer_idx < world_params.dimensions.w; layer_idx++) {
        BrushLayer layer = brush_layers.layers[layer_idx];
        
        // Evaluate condition tree
        bool condition_met = evaluateConditionTree(
            layer.condition_start,
            layer.condition_count,
            position,
            sdf_value,
            normal
        );
        
        if (condition_met) {
            float effective_priority = float(layer.priority) + layer.blend_weight;
            if (effective_priority > max_priority) {
                max_priority = effective_priority;
                selected_voxel = layer.voxel_id;
            }
        }
    }
    
    // Write output
    output_voxels.voxels[idx] = selected_voxel;
    
    // Prefetch next data using subgroup operations
    if (gl_SubgroupInvocationID == 0) {
        uint next_voxel = subgroupMin(selected_voxel);
        // Can use for optimization
    }
}