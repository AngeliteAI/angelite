#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_atomic_float : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_shader_atomic_int64 : require
#extension GL_EXT_debug_printf : enable

// Push constant for the heap address
layout(push_constant) uniform PushConstants {
    uint64_t heapAddress;        // Device address of the heap
    uint64_t noiseContextOffset; // Offset to noise context
    uint64_t terrainContextOffset; // Offset to terrain context
    uint64_t workspaceOffset; // Offset to workspace
    uint64_t regionOffset;
} pushConstants;

// Constants matching the Metal shader
#define CHUNK_SIZE 8

// Buffer reference for the noise data
layout(buffer_reference, scalar, align = 16) buffer F32Ref {
    float data;
};

layout(buffer_reference, scalar, align = 16) buffer U64Ref {
    uint64_t data;
};

layout(buffer_reference, scalar, align = 16) buffer NoiseContextRef {
    uint64_t noiseParamOffset;
    uint64_t noiseDataOffset;
};

// Buffer reference for the noise parameters
layout(buffer_reference, scalar, align = 16) buffer NoiseParamsRef {
    float seed;
    float scale;
    float frequency;
    float lacunarity;
    float persistence;
    ivec3 offset;
    uvec3 size;
};

// Buffer reference for terrain parameters
layout(buffer_reference, scalar, align = 16) buffer TerrainParamsRef {
    float heightScale;
    float heightOffset;
    float squishingFactor;
    uvec3 size;
};

layout(buffer_reference, scalar, align = 16) buffer WorkspaceRef {
    uint64_t offsetRaw;
    uvec3 size;
};

layout(buffer_reference, scalar, align = 16) buffer RegionRef {
    uint64_t offsetPalette;
    uint64_t offsetCompressed;
    uvec3 size;
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
    uvec3 localPos = gl_GlobalInvocationID.xyz;
    uvec3 globalPos = gl_GlobalInvocationID.xyz;

    // Skip computation if outside the chunk dimensions
    if (any(greaterThanEqual(localPos, uvec3(CHUNK_SIZE)))) {
        return;
    }

    // Get noise dimensions
    uvec3 textureDimensions = noiseParamsRef.size;

    // Calculate normalized coordinates for noise lookup
    vec3 normalizedPos = vec3(localPos) / vec3(textureDimensions);

    // Calculate 1D index from 3D position to get the noise value
    uint index = localPos.x + textureDimensions.x *
               (localPos.y + textureDimensions.y * localPos.z);

    const uint64_t addressNoise = pushConstants.heapAddress + noiseContext.noiseDataOffset;

    F32Ref noiseDataRef = F32Ref(addressNoise + uint(index * 4));

    // Get the noise value for this position
    float noiseValue = noiseDataRef.data; 

    // Calculate terrain height using parameters
    float terrainHeight = terrainParamsRef.heightOffset;

    // Apply squishing factor to Z coordinate to compress terrain vertically
    float density = noiseValue;

    float density_mod = terrainParamsRef.squishingFactor * (terrainHeight - globalPos.z); 

    // Create a 5-unit tall sine wave along the x-axis
    // Amplitude of 2.5 units (5 units total height)
    // Period of 16 units (2π/0.4 ≈ 16)
    float sineWave = 2.5 * sin(globalPos.x * 0.4) + 2.5;
    
    // Determine if this voxel should be solid based on sine wave height
    bool solid = globalPos.z > sineWave;

    // Set voxel value (1 for solid, 0 for air)
    uint64_t terrainValue = solid ? uint64_t(1u) : uint64_t(0u);

    uint rawIndex = localPos.x + CHUNK_SIZE * (localPos.y + CHUNK_SIZE * localPos.z);
    // If solid, write to the raw voxel data
    if (solid) {
        // Calculate index in the raw data buffer
        U64Ref rawDataRef = U64Ref(addressRaw + uint(rawIndex * 8));
        // Write the terrain value to raw data
        rawDataRef.data = terrainValue;
    }
    debugPrintfEXT("Writing terrain value to raw data at index %d: %llu, height: %f", rawIndex, terrainValue, sineWave);
}
