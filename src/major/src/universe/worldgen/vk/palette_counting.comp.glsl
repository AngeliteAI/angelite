#version 460
#extension GL_KHR_shader_subgroup_arithmetic : enable
#extension GL_KHR_shader_subgroup_ballot : enable

layout(local_size_x = 256) in;

// Constants
const uint MAX_PALETTE_SIZE = 256;
const uint HISTOGRAM_BINS = 4096; // Support up to 12-bit voxel IDs

// Input buffer
layout(std430, binding = 0) readonly buffer InputVoxels {
    uint voxels[];
} input_voxels;

// Shared memory for local histogram
shared uint local_histogram[HISTOGRAM_BINS];
shared uint unique_count;
shared uint unique_list[MAX_PALETTE_SIZE];

// Output buffers
layout(std430, binding = 1) coherent buffer GlobalHistogram {
    uint counts[];
} global_histogram;

layout(std430, binding = 2) coherent buffer UniqueList {
    uint count;
    uint voxels[MAX_PALETTE_SIZE];
} unique_list_output;

layout(std430, binding = 3) readonly buffer WorkParams {
    uint total_voxels;
    uint work_group_count;
} params;

void main() {
    uint tid = gl_LocalInvocationID.x;
    uint gid = gl_GlobalInvocationID.x;
    uint work_group_id = gl_WorkGroupID.x;
    
    // Initialize shared memory
    if (tid == 0) {
        unique_count = 0;
    }
    
    // Initialize local histogram (each thread handles multiple bins)
    for (uint i = tid; i < HISTOGRAM_BINS; i += gl_WorkGroupSize.x) {
        local_histogram[i] = 0;
    }
    
    barrier();
    
    // Phase 1: Build local histogram
    uint voxels_per_thread = (params.total_voxels + gl_NumWorkGroups.x * gl_WorkGroupSize.x - 1) / 
                            (gl_NumWorkGroups.x * gl_WorkGroupSize.x);
    
    uint start_idx = gid * voxels_per_thread;
    uint end_idx = min(start_idx + voxels_per_thread, params.total_voxels);
    
    for (uint i = start_idx; i < end_idx; i++) {
        uint voxel = input_voxels.voxels[i];
        if (voxel < HISTOGRAM_BINS) {
            atomicAdd(local_histogram[voxel], 1);
        }
    }
    
    barrier();
    
    // Phase 2: Merge to global histogram
    for (uint i = tid; i < HISTOGRAM_BINS; i += gl_WorkGroupSize.x) {
        if (local_histogram[i] > 0) {
            atomicAdd(global_histogram.counts[i], local_histogram[i]);
            
            // Track unique voxels
            uint idx = atomicAdd(unique_count, 1);
            if (idx < MAX_PALETTE_SIZE) {
                unique_list[idx] = i;
            }
        }
    }
    
    barrier();
    
    // Phase 3: Update global unique list (only by thread 0 of each work group)
    if (tid == 0) {
        uint base_idx = atomicAdd(unique_list_output.count, unique_count);
        
        for (uint i = 0; i < unique_count && base_idx + i < MAX_PALETTE_SIZE; i++) {
            unique_list_output.voxels[base_idx + i] = unique_list[i];
        }
    }
    
    // Use subgroup operations for efficiency
    if (gl_SubgroupInvocationID == 0) {
        uint subgroup_sum = subgroupAdd(unique_count);
        // Can use for optimization
    }
}