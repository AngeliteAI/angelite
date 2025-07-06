#version 460
#extension GL_KHR_shader_subgroup_shuffle : enable
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_ARB_gpu_shader_int64 : require

layout(local_size_x = 64) in;

// Buffer reference types
layout(buffer_reference, std430, buffer_reference_align = 4) readonly buffer InputVoxelsBuffer {
    uint voxels[];
};

layout(buffer_reference, std430, buffer_reference_align = 4) readonly buffer PaletteBuffer {
    uint size;
    uint voxels[];
};

layout(buffer_reference, std430, buffer_reference_align = 4) readonly buffer PaletteLUTBuffer {
    uint lookup[];  // Maps voxel ID to palette index
};

layout(buffer_reference, std430, buffer_reference_align = 4) writeonly buffer BitpackedOutputBuffer {
    uint data[];
};

layout(buffer_reference, std430, buffer_reference_align = 16) readonly buffer CompressionParamsBuffer {
    uint total_voxels;
    uint bits_per_index;
    uint indices_per_uint;
    uint padding;
};

// Push constants with buffer addresses
layout(push_constant) uniform PushConstants {
    uint64_t input_voxels_address;
    uint64_t palette_address;
    uint64_t palette_lut_address;
    uint64_t bitpacked_output_address;
    uint64_t compression_params_address;
    uint64_t padding[3];
} push;

// Shared memory for coalesced writes
shared uint write_buffer[64];

void main() {
    // Get buffer references from push constants
    InputVoxelsBuffer input_voxels = InputVoxelsBuffer(push.input_voxels_address);
    PaletteBuffer palette = PaletteBuffer(push.palette_address);
    PaletteLUTBuffer palette_lut = PaletteLUTBuffer(push.palette_lut_address);
    BitpackedOutputBuffer bitpacked_output = BitpackedOutputBuffer(push.bitpacked_output_address);
    CompressionParamsBuffer params = CompressionParamsBuffer(push.compression_params_address);
    
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
    uint local_bit_offset = (start_idx % params.indices_per_uint) * params.bits_per_index;
    
    for (uint i = start_idx; i < end_idx; i++) {
        // Get voxel and convert to palette index
        uint voxel_id = input_voxels.voxels[i];
        uint palette_idx = palette_lut.lookup[voxel_id];
        
        // Pack into current uint32
        packed_data |= (palette_idx << local_bit_offset);
        local_bit_offset += params.bits_per_index;
        
        // If we've filled a uint32, write it out
        if (local_bit_offset >= 32) {
            bitpacked_output.data[output_idx] = packed_data;
            output_idx++;
            
            // Handle overflow bits
            uint overflow_bits = local_bit_offset - 32;
            if (overflow_bits > 0) {
                packed_data = palette_idx >> (params.bits_per_index - overflow_bits);
                local_bit_offset = overflow_bits;
            } else {
                packed_data = 0;
                local_bit_offset = 0;
            }
        }
    }
    
    // Write any remaining data
    if (local_bit_offset > 0 && output_idx < (params.total_voxels + params.indices_per_uint - 1) / params.indices_per_uint) {
        bitpacked_output.data[output_idx] = packed_data;
    }
}