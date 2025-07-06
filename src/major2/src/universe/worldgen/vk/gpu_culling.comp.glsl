#version 460
#extension GL_KHR_shader_subgroup_ballot : enable

layout(local_size_x = 64) in;

// Chunk data structure
struct ChunkData {
    vec4 bounds_min;  // xyz = min, w = unused
    vec4 bounds_max;  // xyz = max, w = unused
    mat4 transform;
    uint chunk_id;
    uint flags;
    uint padding[2];
};

// View parameters
struct ViewData {
    mat4 view_matrix;
    mat4 projection_matrix;
    mat4 view_projection;
    vec4 frustum_planes[6]; // xyz = normal, w = distance
    vec4 camera_position;   // xyz = position, w = unused
    vec4 lod_distances;     // x,y,z,w = LOD thresholds
};

// Input buffers
layout(std430, binding = 0) readonly buffer ChunkBuffer {
    ChunkData chunks[];
} chunk_buffer;

layout(std140, binding = 1) uniform ViewBuffer {
    ViewData view;
} view_buffer;

layout(std430, binding = 2) readonly buffer OcclusionBuffer {
    uint depth_pyramid[];  // Hierarchical Z-buffer for occlusion culling
} occlusion_buffer;

// Output buffers
layout(std430, binding = 3) writeonly buffer VisibleChunks {
    uint count;
    uint indices[];  // Packed as (chunk_index << 3) | lod_level
} visible_chunks;

layout(std430, binding = 4) coherent buffer DrawCommands {
    uint count;
    uint commands[];  // Indirect draw commands
} draw_commands;

// Shared memory for compaction
shared uint visible_count;
shared uint visible_indices[64];

// Frustum culling
bool frustumCull(vec3 min_bounds, vec3 max_bounds, mat4 transform) {
    // Transform bounds to world space
    vec3 corners[8] = {
        vec3(min_bounds.x, min_bounds.y, min_bounds.z),
        vec3(max_bounds.x, min_bounds.y, min_bounds.z),
        vec3(min_bounds.x, max_bounds.y, min_bounds.z),
        vec3(max_bounds.x, max_bounds.y, min_bounds.z),
        vec3(min_bounds.x, min_bounds.y, max_bounds.z),
        vec3(max_bounds.x, min_bounds.y, max_bounds.z),
        vec3(min_bounds.x, max_bounds.y, max_bounds.z),
        vec3(max_bounds.x, max_bounds.y, max_bounds.z)
    };
    
    // Test against each frustum plane
    for (uint i = 0; i < 6; i++) {
        vec4 plane = view_buffer.view.frustum_planes[i];
        bool all_outside = true;
        
        for (uint j = 0; j < 8; j++) {
            vec4 world_pos = transform * vec4(corners[j], 1.0);
            float distance = dot(plane.xyz, world_pos.xyz) + plane.w;
            
            if (distance > 0.0) {
                all_outside = false;
                break;
            }
        }
        
        if (all_outside) {
            return false;  // Culled by this plane
        }
    }
    
    return true;  // Inside frustum
}

// Occlusion culling using hierarchical Z-buffer
bool occlusionCull(vec3 min_bounds, vec3 max_bounds, mat4 transform) {
    // Transform bounds to clip space
    mat4 mvp = view_buffer.view.view_projection * transform;
    
    vec3 corners[8] = {
        vec3(min_bounds.x, min_bounds.y, min_bounds.z),
        vec3(max_bounds.x, min_bounds.y, min_bounds.z),
        vec3(min_bounds.x, max_bounds.y, min_bounds.z),
        vec3(max_bounds.x, max_bounds.y, min_bounds.z),
        vec3(min_bounds.x, min_bounds.y, max_bounds.z),
        vec3(max_bounds.x, min_bounds.y, max_bounds.z),
        vec3(min_bounds.x, max_bounds.y, max_bounds.z),
        vec3(max_bounds.x, max_bounds.y, max_bounds.z)
    };
    
    // Find screen space bounding box
    vec2 screen_min = vec2(1.0);
    vec2 screen_max = vec2(-1.0);
    float z_min = 1.0;
    
    for (uint i = 0; i < 8; i++) {
        vec4 clip_pos = mvp * vec4(corners[i], 1.0);
        
        if (clip_pos.w > 0.0) {
            vec3 ndc = clip_pos.xyz / clip_pos.w;
            screen_min = min(screen_min, ndc.xy);
            screen_max = max(screen_max, ndc.xy);
            z_min = min(z_min, ndc.z);
        }
    }
    
    // Clamp to screen bounds
    screen_min = clamp(screen_min, vec2(-1.0), vec2(1.0));
    screen_max = clamp(screen_max, vec2(-1.0), vec2(1.0));
    
    // Convert to texture coordinates
    vec2 uv_min = screen_min * 0.5 + 0.5;
    vec2 uv_max = screen_max * 0.5 + 0.5;
    
    // Sample hierarchical Z-buffer at appropriate mip level
    vec2 size = uv_max - uv_min;
    float mip_level = ceil(log2(max(size.x, size.y) * 1024.0)); // Assuming 1024x1024 base resolution
    
    // TODO: Implement actual HiZ buffer sampling
    // For now, assume visible
    return true;
}

// Calculate LOD level based on distance
uint calculateLOD(vec3 chunk_center, mat4 transform) {
    vec4 world_pos = transform * vec4(chunk_center, 1.0);
    float distance = length(world_pos.xyz - view_buffer.view.camera_position.xyz);
    
    // Compare against LOD distances
    if (distance < view_buffer.view.lod_distances.x) return 0;
    if (distance < view_buffer.view.lod_distances.y) return 1;
    if (distance < view_buffer.view.lod_distances.z) return 2;
    if (distance < view_buffer.view.lod_distances.w) return 3;
    return 4;
}

void main() {
    uint tid = gl_LocalInvocationID.x;
    uint gid = gl_GlobalInvocationID.x;
    
    // Initialize shared memory
    if (tid == 0) {
        visible_count = 0;
    }
    
    barrier();
    
    // Process chunk
    if (gid < chunk_buffer.chunks.length()) {
        ChunkData chunk = chunk_buffer.chunks[gid];
        
        // Skip if chunk is disabled
        if ((chunk.flags & 1) == 0) {
            return;
        }
        
        // Frustum culling
        if (!frustumCull(chunk.bounds_min.xyz, chunk.bounds_max.xyz, chunk.transform)) {
            return;
        }
        
        // Occlusion culling
        if (!occlusionCull(chunk.bounds_min.xyz, chunk.bounds_max.xyz, chunk.transform)) {
            return;
        }
        
        // Calculate LOD
        vec3 center = (chunk.bounds_min.xyz + chunk.bounds_max.xyz) * 0.5;
        uint lod = calculateLOD(center, chunk.transform);
        
        // Add to visible list
        uint local_idx = atomicAdd(visible_count, 1);
        if (local_idx < 64) {
            visible_indices[local_idx] = (gid << 3) | lod;
        }
    }
    
    barrier();
    
    // Compact results (only thread 0 in work group)
    if (tid == 0 && visible_count > 0) {
        uint base_idx = atomicAdd(visible_chunks.count, visible_count);
        
        for (uint i = 0; i < visible_count && i < 64; i++) {
            visible_chunks.indices[base_idx + i] = visible_indices[i];
        }
    }
    
    // Use subgroup operations for better efficiency
    uint subgroup_visible = subgroupBallotBitCount(subgroupBallot(visible_count > tid));
    if (subgroupElect()) {
        // Leader can do additional work
    }
}