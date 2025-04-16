#version 450
#extension GL_EXT_buffer_reference : require
#include "000_chunk.glsl"
#include "000_noise.glsl"

// Push constant for the heap address
layout(push_constant) uniform PushConstants {
    uint64_t heapAddress;        // Device address of the heap
    uint64_t noiseContextOffset; // Offset to noise context
    uint64_t terrainContextOffset; // Offset to terrain context
    uint64_t metadataOffset;    // Offset to chunk metadata
} pushConstants;

// Constants matching the Metal shader
#define CHUNK_SIZE 8

// Terrain parameters matching Metal shader
struct TerrainParams {
    float heightScale;
    float heightOffset;
    float squishingFactor;
    uint seed;
    uvec2 worldOffset;
};


// Buffer reference for the noise data
layout(buffer_reference, std430) buffer NoiseDataRef {
    float data[];
};

// Buffer reference for noise parameters
layout(buffer_reference, std430) buffer NoiseParamsRef {
    NoiseParams params;
};

// Buffer reference for terrain parameters
layout(buffer_reference, std430) buffer TerrainParamsRef {
    TerrainParams params;
};

// Buffer reference for chunk metadata
layout(buffer_reference, std430) buffer MetadataRef {
    Metadata data;
};

// Buffer reference for raw voxel data
layout(buffer_reference, std430) buffer RawDataRef {
    uint data[];
};

// Compute shader for generating terrain from noise
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
void main() {
    // Get noise context from push constants
    NoiseContext noiseContext = NoiseContext(pushConstants.heapAddress + pushConstants.noiseContextOffset);

    // Get references to all necessary data
    NoiseParamsRef noiseParamsRef = NoiseParamsRef(pushConstants.heapAddress + noiseContext.noiseParamOffset);
    NoiseDataRef noiseDataRef = NoiseDataRef(pushConstants.heapAddress + noiseContext.noiseDataOffset);
    TerrainParamsRef terrainParamsRef = TerrainParamsRef(pushConstants.heapAddress + pushConstants.terrainContextOffset);
    MetadataRef metadataRef = MetadataRef(pushConstants.heapAddress + pushConstants.metadataOffset);

    // Get raw data buffer for writing voxel data
    uint offsetRaw = metadataRef.data.offsetRaw;
    RawDataRef rawDataRef = RawDataRef(pushConstants.heapAddress + offsetRaw);

    // Get local thread position (voxel coordinates)
    uvec3 localPos = gl_GlobalInvocationID.xyz;

    // Skip computation if outside the chunk dimensions
    if (any(greaterThanEqual(localPos, uvec3(CHUNK_SIZE)))) {
        return;
    }

    // Get noise dimensions
    uvec3 textureDimensions = noiseParamsRef.params.size;

    // Calculate normalized coordinates for noise lookup
    vec3 normalizedPos = vec3(localPos) / vec3(textureDimensions);

    // Calculate 1D index from 3D position to get the noise value
    uint index = localPos.x + textureDimensions.x *
               (localPos.y + textureDimensions.y * localPos.z);

    // Get the noise value for this position
    float noiseValue = noiseDataRef.data[index];

    // Calculate terrain height using parameters
    float terrainHeight = terrainParamsRef.params.heightScale * noiseValue +
                          terrainParamsRef.params.heightOffset;

    // Apply squishing factor to Z coordinate to compress terrain vertically
    float squashedZ = float(localPos.z) * terrainParamsRef.params.squishingFactor;

    // Determine if this voxel should be solid based on height
    bool solid = squashedZ < terrainHeight;

    // Set voxel value (1 for solid, 0 for air)
    uint terrainValue = solid ? 1u : 0u;

    // If solid, write to the raw voxel data
    if (solid) {
        // Calculate index in the raw data buffer
        uint rawIndex = localPos.x + CHUNK_SIZE * (localPos.y + CHUNK_SIZE * localPos.z);

        // Write the terrain value to raw data
        rawDataRef.data[rawIndex] = terrainValue;
    }
}
