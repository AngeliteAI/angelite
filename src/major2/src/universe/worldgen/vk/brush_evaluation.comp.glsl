#version 460
#extension GL_GOOGLE_include_directive : enable
#extension GL_KHR_shader_subgroup_arithmetic : enable
#extension GL_EXT_scalar_block_layout : enable
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_ARB_gpu_shader_int64 : require

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

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
    uint padding1[3];  // Padding to align params to 16 bytes
    vec4 params[2];    // Parameters (must be 16-byte aligned)
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

// Buffer reference types
layout(buffer_reference, scalar, buffer_reference_align = 16) readonly buffer BrushProgramBuffer {
    BrushInstruction instructions[];
};

layout(buffer_reference, scalar, buffer_reference_align = 4) readonly buffer BrushLayersBuffer {
    BrushLayer layers[];
};

layout(buffer_reference, scalar, buffer_reference_align = 16) readonly buffer SdfFieldBuffer {
    float distances[];
};

layout(buffer_reference, scalar, buffer_reference_align = 16) readonly buffer BrushParams {
    vec4 bounds_min;
    vec4 bounds_max;
    uvec4 resolution;
    uvec4 layer_count;  // x = layer count
};

layout(buffer_reference, scalar, buffer_reference_align = 16) buffer NoiseTexturesInfo {
    uint64_t sampler_handle;
    uint64_t image_views[4];
};

layout(buffer_reference, scalar, buffer_reference_align = 16) readonly buffer WorldParamsBuffer {
    vec4 world_center;
    vec4 world_scale;
    uint64_t noise_textures_info_address;
};

// Minichunk parameters - one per workgroup when processing multiple minichunks
layout(buffer_reference, scalar, buffer_reference_align = 16) readonly buffer MinichunkParamsBuffer {
    vec4 bounds_min;
    vec4 bounds_max;
    vec4 voxel_size_and_padding;  // x = voxel_size, yzw = padding
    vec4 resolution;  // xyz = resolution, w = padding
};

layout(buffer_reference, scalar, buffer_reference_align = 4) buffer OutputVoxelsBuffer {
    uint voxels[];
};

// Push constants with buffer addresses
layout(push_constant) uniform PushConstants {
    uint64_t sdf_tree_address;         // Not used in brush evaluation
    uint64_t params_address;           // Brush params
    uint64_t sdf_field_address;        // Input SDF field
    uint64_t world_params_address;     // World parameters
    uint64_t output_voxels_address;    // Output voxels
    uint64_t brush_program_address;    // Brush instructions
    uint64_t brush_layers_address;     // Brush layers
    uint workgroup_offset;             // Starting workgroup index for this dispatch
    uint total_workgroups;             // Total workgroups in the full volume
} push;

// 3D noise functions
float hash(vec3 p) {
    p = fract(p * vec3(443.8975, 397.2973, 491.1871));
    p += dot(p, p.yxz + 19.19);
    return fract((p.x + p.y) * p.z);
}

float noise3d(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    return mix(
        mix(
            mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
            mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x),
            f.y
        ),
        mix(
            mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
            mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x),
            f.y
        ),
        f.z
    );
}

float turbulence(vec3 p, int octaves) {
    float result = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        result += amplitude * abs(noise3d(p * frequency));
        amplitude *= 0.5;
        frequency *= 2.0;
    }
    
    return result;
}

float voronoiCell(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    
    float minDist = 1e10;
    
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 neighbor = vec3(x, y, z);
                vec3 point = neighbor + hash(i + neighbor) - f;
                float dist = length(point);
                minDist = min(minDist, dist);
            }
        }
    }
    
    return minDist;
}

// Evaluate a condition
float evaluateCondition(BrushInstruction inst, vec3 world_pos, float sdf_value, vec3 gradient) {
    float value = 0.0;
    
    switch (inst.opcode) {
        case COND_HEIGHT:
            value = world_pos.z;  // Z-up coordinate system
            break;
            
        case COND_DEPTH:
            value = -world_pos.z; // Depth below surface (Z-up)
            break;
            
        case COND_DISTANCE:
            // Check if using SDF distance (when point is all zeros)
            if (inst.params[0].x == 0.0 && inst.params[0].y == 0.0 && inst.params[0].z == 0.0) {
                value = sdf_value;  // Use SDF distance directly
            } else {
                // Distance from specific point
                vec3 point = inst.params[0].xyz;
                value = length(world_pos - point);
            }
            break;
            
        case COND_SLOPE:
            value = 1.0 - abs(gradient.z); // 1 = horizontal, 0 = vertical (Z-up)
            break;
            
        case COND_CURVATURE:
            // Simple curvature approximation based on gradient change
            value = length(gradient);
            break;
            
        case COND_NOISE_3D:
            value = noise3d(world_pos * inst.params[0].x);
            break;
            
        case COND_VORONOI_CELL:
            value = voronoiCell(world_pos * inst.params[0].x);
            break;
            
        case COND_TURBULENCE:
            value = turbulence(world_pos * inst.params[0].x, int(inst.params[0].y));
            break;
            
        case COND_CHECKERBOARD:
            vec3 checker = floor(world_pos * inst.params[0].x);
            value = mod(checker.x + checker.y + checker.z, 2.0);
            break;
            
        case COND_STRIPES:
            value = 0.5 + 0.5 * sin(dot(world_pos, inst.params[0].xyz) * inst.params[0].w);
            break;
            
        case COND_INSIDE_SDF:
            value = sdf_value < 0.0 ? 1.0 : 0.0;
            break;
    }
    
    // Apply range mapping
    float min_val = inst.params[1].x;
    float max_val = inst.params[1].y;
    return smoothstep(min_val, max_val, value);
}

// Calculate gradient for slope calculation
vec3 calculateGradient(uint idx, uvec3 resolution, SdfFieldBuffer sdf_field) {
    uint x = idx % resolution.x;
    uint y = (idx / resolution.x) % resolution.y;
    uint z = idx / (resolution.x * resolution.y);
    
    vec3 gradient = vec3(0);
    
    // Central differences
    if (x > 0 && x < resolution.x - 1) {
        uint idx_left = idx - 1;
        uint idx_right = idx + 1;
        gradient.x = sdf_field.distances[idx_right] - sdf_field.distances[idx_left];
    }
    
    if (y > 0 && y < resolution.y - 1) {
        uint idx_down = idx - resolution.x;
        uint idx_up = idx + resolution.x;
        gradient.y = sdf_field.distances[idx_up] - sdf_field.distances[idx_down];
    }
    
    if (z > 0 && z < resolution.z - 1) {
        uint idx_back = idx - resolution.x * resolution.y;
        uint idx_front = idx + resolution.x * resolution.y;
        gradient.z = sdf_field.distances[idx_front] - sdf_field.distances[idx_back];
    }
    
    return normalize(gradient);
}

void main() {
    // Get buffer references from push constants
    BrushParams params = BrushParams(push.params_address);
    SdfFieldBuffer sdf_field = SdfFieldBuffer(push.sdf_field_address);
    OutputVoxelsBuffer output_voxels = OutputVoxelsBuffer(push.output_voxels_address);
    BrushProgramBuffer brush_program = BrushProgramBuffer(push.brush_program_address);
    BrushLayersBuffer brush_layers = BrushLayersBuffer(push.brush_layers_address);
    
    // When processing multiple minichunks, each workgroup handles one minichunk
    // The world_params buffer contains parameters for each minichunk
    uint minichunk_index = gl_WorkGroupID.x + gl_WorkGroupID.y * gl_NumWorkGroups.x + 
                          gl_WorkGroupID.z * gl_NumWorkGroups.x * gl_NumWorkGroups.y;
    
    // Load minichunk parameters from world params buffer
    MinichunkParamsBuffer minichunk_params = MinichunkParamsBuffer(push.world_params_address + minichunk_index * 64); // 64 bytes per minichunk params
    
    // Each workgroup processes one 8x8x8 minichunk
    uvec3 local_pos = gl_LocalInvocationID.xyz;
    
    // Minichunk resolution is always 8x8x8
    const uvec3 minichunk_resolution = uvec3(8, 8, 8);
    uvec3 resolution = minichunk_resolution; // For compatibility with existing code
    
    // Calculate position within the minichunk
    uvec3 coord = local_pos;
    
    // Check bounds
    if (any(greaterThanEqual(coord, resolution))) {
        return;
    }
    
    // Calculate linear index for this minichunk's output buffer
    // Each minichunk gets 512 voxels (8*8*8) in the output buffer
    uint minichunk_offset = minichunk_index * 512;
    uint local_index = coord.x + coord.y * 8u + coord.z * 64u;
    uint gid = minichunk_offset + local_index;
    
    // Convert to world space using minichunk bounds
    vec3 bounds_min = minichunk_params.bounds_min.xyz;
    vec3 bounds_max = minichunk_params.bounds_max.xyz;
    vec3 bounds_size = bounds_max - bounds_min;
    vec3 grid_pos = vec3(coord) / vec3(resolution - 1u);
    vec3 world_pos = bounds_min + grid_pos * bounds_size;
    
    // Get SDF value and gradient
    // For minichunks, we need to sample from the appropriate region of the SDF field
    // The SDF field is still at chunk resolution, so we need to map minichunk coords to chunk coords
    vec3 chunk_coord = (world_pos - params.bounds_min.xyz) / (params.bounds_max.xyz - params.bounds_min.xyz);
    chunk_coord = clamp(chunk_coord, vec3(0.0), vec3(1.0));
    uvec3 sdf_resolution = params.resolution.xyz;
    uvec3 sdf_coord = uvec3(chunk_coord * vec3(sdf_resolution - 1u));
    uint sdf_index = sdf_coord.x + sdf_coord.y * sdf_resolution.x + sdf_coord.z * sdf_resolution.x * sdf_resolution.y;
    
    float sdf_value = sdf_field.distances[sdf_index];
    vec3 gradient = calculateGradient(sdf_index, sdf_resolution, sdf_field);
    
    // Evaluate layers
    uint final_voxel_id = 0;
    int highest_priority = -1;
    float total_weight = 0.0;
    
    uint layer_count = params.layer_count.x;
    
    // If no layers, fail - synthesis must provide valid brush layers
    if (layer_count == 0) {
        // Write error marker voxel type to indicate configuration error
        output_voxels.voxels[gid] = 0xDEADBEEF; // Error marker
        return;
    }
    
    for (uint layer_idx = 0; layer_idx < layer_count; layer_idx++) {
        BrushLayer layer = brush_layers.layers[layer_idx];
        
        // Evaluate all conditions for this layer
        float condition_result = 1.0;
        bool use_and = true; // Default to AND operation
        
        for (uint i = 0; i < layer.condition_count; i++) {
            BrushInstruction inst = brush_program.instructions[layer.condition_start + i];
            
            if (inst.opcode == COND_AND) {
                use_and = true;
                continue;
            } else if (inst.opcode == COND_OR) {
                use_and = false;
                continue;
            } else if (inst.opcode == COND_NOT) {
                // Next condition will be inverted
                i++;
                if (i < layer.condition_count) {
                    BrushInstruction next_inst = brush_program.instructions[layer.condition_start + i];
                    float value = evaluateCondition(next_inst, world_pos, sdf_value, gradient);
                    value = 1.0 - value; // Invert
                    
                    if (use_and) {
                        condition_result *= value;
                    } else {
                        condition_result = max(condition_result, value);
                    }
                }
            } else {
                // Regular condition
                float value = evaluateCondition(inst, world_pos, sdf_value, gradient);
                
                if (use_and) {
                    condition_result *= value;
                } else {
                    condition_result = max(condition_result, value);
                }
            }
        }
        
        // Apply layer based on priority and weight
        float weighted_result = condition_result * layer.blend_weight;
        
        if (weighted_result > 0.0) {
            if (layer.priority > highest_priority || 
                (layer.priority == highest_priority && weighted_result > total_weight)) {
                highest_priority = layer.priority;
                total_weight = weighted_result;
                final_voxel_id = layer.voxel_id;
            }
        }
    }
    
    // Write result
    output_voxels.voxels[gid] = final_voxel_id;
}