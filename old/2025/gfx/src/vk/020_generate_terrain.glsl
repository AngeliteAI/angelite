#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_atomic_float : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_shader_atomic_int64 : require
#extension GL_EXT_debug_printf : enable

// Push constant for the heap address
layout(push_constant, scalar) uniform PushConstants {
    uint64_t heapAddress;        // Device address of the heap
    uint64_t noiseContextOffset; // Offset to noise context
    uint64_t terrainContextOffset; // Offset to terrain context
    uint64_t workspaceOffset; // Offset to workspace
} pushConstants;

// Constants matching the Metal shader
#define CHUNK_SIZE 8

// Buffer reference for the noise data
layout(buffer_reference, scalar) buffer NoiseContextRef {
    uint64_t noiseParamOffset;
    uint64_t noiseDataOffset;
};

// Buffer reference for the noise parameters
layout(buffer_reference, scalar) buffer NoiseParamsRef {
    float seed;
    float scale;
    float frequency;
    float lacunarity;
    float persistence;
    ivec3 offset;
    uvec3 size;
};

// Buffer reference for terrain parameters
layout(buffer_reference, scalar) buffer TerrainParamsRef {
    float heightScale;
    float heightOffset;
    float squishingFactor;
    uvec3 size;
};

layout(buffer_reference, scalar) buffer WorkspaceRef {
    uint64_t offsetRaw;
    uvec3 size;
};

layout(buffer_reference, scalar) buffer HeapBufferRef {
    uint64_t data[];
};
layout(buffer_reference, scalar) buffer Heap32BufferRef {
    uint data[];
};

// Compute shader for generating terrain from noise
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
void main() {
    // Get noise context from push constants
    NoiseContextRef noiseContext = NoiseContextRef(pushConstants.heapAddress + pushConstants.noiseContextOffset);

    // Get references to all necessary data
    NoiseParamsRef noiseParamsRef = NoiseParamsRef(pushConstants.heapAddress + noiseContext.noiseParamOffset);
    TerrainParamsRef terrainParamsRef = TerrainParamsRef(pushConstants.heapAddress + pushConstants.terrainContextOffset);
    WorkspaceRef workspaceRef = WorkspaceRef(pushConstants.heapAddress + pushConstants.workspaceOffset);

    // Get raw data buffer for writing voxel data
    uint64_t offsetRaw = workspaceRef.offsetRaw;
    uint64_t addressRaw = pushConstants.heapAddress + offsetRaw;

    // Get local thread position (voxel coordinates)
    uvec3 localPos = gl_GlobalInvocationID.xyz % 8;
    uvec3 globalPos = gl_GlobalInvocationID.xyz;

    // Skip computation if outside the chunk dimensions
    if (any(greaterThanEqual(localPos, uvec3(CHUNK_SIZE)))) {
        return;
    }

    // Get noise dimensions
    uvec3 textureDimensions = noiseParamsRef.size;

    // Calculate normalized coordinates for noise lookup
    vec3 normalizedPos = vec3(globalPos) / vec3(textureDimensions);

    // Calculate 1D index from 3D position to get the noise value
    uint index = globalPos.x + textureDimensions.x *
               (globalPos.y + textureDimensions.y * globalPos.z);

    const uint64_t addressNoise = pushConstants.heapAddress + noiseContext.noiseDataOffset;

    Heap32BufferRef noiseDataRef = Heap32BufferRef(addressNoise);

    // Get the noise value for this position
    float noiseValue = noiseDataRef.data[index]; 

    // Calculate terrain height using parameters
    float terrainHeight = terrainParamsRef.heightOffset;

    // Apply squishing factor to Z coordinate to compress terrain vertically
    float density = noiseValue;

    float density_mod = terrainParamsRef.squishingFactor * (terrainHeight - globalPos.z); 

    // Create a more uniform terrain pattern
    // Use a combination of sine waves with different frequencies and phases
    // This should create a more varied terrain with non-air blocks at all positions
    
    // Determine if this voxel should be solid based on the combined wave height
    float wave1 = sin(globalPos.y * 0.05) * sin(globalPos.x * 0.05) * 10.0;
    float wave2 = sin(globalPos.y * 0.1 + 1.5) * sin(globalPos.x * 0.1 + 0.7) * 5.0;
    float wave3 = sin(globalPos.y * 0.02 + 0.3) * sin(globalPos.x * 0.02 + 1.2) * 3.0;
    
    // Combine the waves with different weights
    float combinedWave = wave1 + wave2 + wave3 + 12.0;
    
    // Determine if this voxel should be solid based on the combined wave height
    bool solid = globalPos.z < combinedWave;

    // Set voxel value (1 for solid, 0 for air)
    uint64_t terrainValue = solid ? uint64_t(1u) : uint64_t(0u);

    #define REGION_BLOCKS 64
    uint rawIndex = globalPos.x + REGION_BLOCKS * (globalPos.y + REGION_BLOCKS * globalPos.z);
    // If solid, write to the raw voxel data
    if (solid) {
        // Calculate index in the raw data buffer
        HeapBufferRef rawDataRef = HeapBufferRef(addressRaw);
        // Write the terrain value to raw data
        rawDataRef.data[rawIndex] = terrainValue;
    }
    debugPrintfEXT("Writing terrain value to raw data at index %d: %llu", rawIndex, terrainValue );
}
