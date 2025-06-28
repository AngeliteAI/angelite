#version 460
#extension GL_KHR_shader_subgroup_shuffle : enable

layout(local_size_x = 64) in;

// Input buffers
layout(std430, binding = 0) readonly buffer InputVoxels {
    uint voxels[];
} input_voxels;

layout(std430, binding = 1) readonly buffer Palette {
    uint size;
    uint voxels[];
} palette;

layout(std430, binding = 2) readonly buffer PaletteLUT {
    uint lookup[];  // Maps voxel ID to palette index
} palette_lut;

// Output buffer
layout(std430, binding = 3) writeonly buffer BitpackedOutput {
    uint data[];
} bitpacked_output;

// Parameters
layout(std430, binding = 4) readonly buffer CompressionParams {
    uint total_voxels;
    uint bits_per_index;
    uint indices_per_uint;
    uint padding;
} params;

// Shared memory for coalesced writes
shared uint write_buffer[64];

void main() {
    uint tid = gl_LocalInvocationID.x;
    uint gid = gl_GlobalInvocationID.x;
    
    // Calculate how many voxels this thread processes
    uint voxels_per_thread = (params.total_voxels + gl_NumWorkGroups.x * gl_WorkGroupSize.x - 1) / 
                            (gl_NumWorkGroups.x * gl_WorkGroupSize.x);
    
    uint start_idx = gid * voxels_per_thread;
    uint end_idx = min(start_idx + voxels_per_thread, params.total_voxels);
    
    // Process voxels and pack into uint32
    uint packed_data = 0;
    uint bit_offset = 0;
    uint output_idx = start_idx / params.indices_per_uint;
    
    for (uint i = start_idx; i < end_idx; i++) {
        // Get voxel and find palette index
        uint voxel = input_voxels.voxels[i];
        uint palette_idx = palette_lut.lookup[voxel];
        
        // Pack into current uint32
        uint local_bit_offset = (i % params.indices_per_uint) * params.bits_per_index;
        
        if (local_bit_offset == 0 && i > start_idx) {
            // Write completed uint32
            bitpacked_output.data[output_idx++] = packed_data;
            packed_data = 0;
        }
        
        // Add bits to packed data
        packed_data |= (palette_idx & ((1u << params.bits_per_index) - 1)) << local_bit_offset;
    }
    
    // Write final packed data if needed
    if (end_idx > start_idx && (end_idx - 1) % params.indices_per_uint != params.indices_per_uint - 1) {
        bitpacked_output.data[output_idx] = packed_data;
    }
    
    // Alternative optimized version using shared memory for better coalescing
    barrier();
    
    // Load data into shared memory in coalesced fashion
    if (tid < 64) {
        uint work_group_start = gl_WorkGroupID.x * gl_WorkGroupSize.x * voxels_per_thread;
        uint shared_idx = work_group_start / params.indices_per_uint + tid;
        
        if (shared_idx * params.indices_per_uint < params.total_voxels) {
            uint packed = 0;
            for (uint j = 0; j < params.indices_per_uint; j++) {
                uint voxel_idx = shared_idx * params.indices_per_uint + j;
                if (voxel_idx < params.total_voxels) {
                    uint voxel = input_voxels.voxels[voxel_idx];
                    uint palette_idx = palette_lut.lookup[voxel];
                    packed |= (palette_idx & ((1u << params.bits_per_index) - 1)) << (j * params.bits_per_index);
                }
            }
            write_buffer[tid] = packed;
        }
    }
    
    barrier();
    
    // Coalesced write from shared memory
    if (tid < 64) {
        uint work_group_start = gl_WorkGroupID.x * gl_WorkGroupSize.x * voxels_per_thread;
        uint output_idx = work_group_start / params.indices_per_uint + tid;
        
        if (output_idx * params.indices_per_uint < params.total_voxels) {
            bitpacked_output.data[output_idx] = write_buffer[tid];
        }
    }
}