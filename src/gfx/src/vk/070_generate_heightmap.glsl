#version 450
#include "000_chunk.glsl"
#extension GL_EXT_buffer_reference : require

#define MAX_GEN 8
#define HEAP_BITS 32
#define CHUNK_SIZE 8
#define MAX_PALETTE_SIZE 256

struct Quad {
    uvec3 a;
    uvec3 b;
    uvec3 c;
    uvec3 d;
};

layout(push_constant) uniform PushConstants {
    uint64_t heapAddress; // Device address of the heap
    //block memory with 1 Region at the beginning and then 512 Chunks corresponding to the region
    uint64_t regionChunkMetadataOffset; // Offset to chunk metadata
} pushConstants;
// Buffer reference for noise parameters
layout(buffer_reference, std430) buffer RegionRef {
    Region regionRef;
};
layout(buffer_reference, std430) buffer ChunkRef {
    Chunk chunkRef;
};

// Use a specialization constant to determine which phase we're in
layout(constant_id = 0) const uint PHASE = 0; // 0 = palette creation, 1 = data compression

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

void main() {
    if (PHASE == 0) {
        maskHeightmapColumns();
    } else {
        tessellateHeightmap();
    }
}

shared uint heights[64];

void tessellateHeightmap() {
    RegionRef regionRef = RegionRef(pushConstants.heapAddress + pushConstants.regionChunkMetadataOffset);
    //If there are 8 chunks in a region
    //and 8 blocks in a chunk
    //There is 64 blocks in a region
    //heightMapResolution is therefore a divisor of 64
    //However, we need to ensure that work is distributed across each thread
    //So that the MSB is calculated distributed-ly

    // Get thread identification
    uvec2 threadId = gl_LocalInvocationID.xy;
    uint threadIndex = threadId.x + threadId.y * gl_WorkGroupSize.x;

    // Calculate grid parameters
    uint resolution = regionRef.heightMapResolutionInChunks;
    uint numPoints = resolution * resolution;
    uint stride = REGION_SIZE / resolution;

    // Step 1: Load height data for all sample points
    barrier();
    if (threadIndex < numPoints) {
        // Calculate position in heightmap grid
        uint gridX = threadIndex % resolution;
        uint gridY = threadIndex / resolution;

        // Calculate actual position in region space
        uint regionX = gridX * stride;
        uint regionY = gridY * stride;

        // Convert to heightmap index
        uint heightMapIndex = regionX + regionY * REGION_SIZE;

        // Load the height mask from the heightmap data
        uint heightMask = uint(pushConstants.heapAddress + regionRef.heightMapOffset + heightMapIndex * sizeof(uint));

        // Find the highest non-air block (position of most significant bit)
        uint height = 0;
        if (heightMask != 0) {
            // Alternative to findMSB function
            height = findMSB(heightMask);
        }

        // Store in shared memory for quick access
        heights[threadIndex] = height;
    }

    // Ensure all heights are loaded before proceeding to create quads
    barrier();

    // Step 2: Create quads from height data
    // We need (resolution-1)^2 quads
    uint numQuads = (resolution - 1) * (resolution - 1);

    if (threadIndex < numQuads) {
        // Calculate quad position in grid
        uint quadX = threadIndex % (resolution - 1);
        uint quadY = threadIndex / (resolution - 1);

        // Calculate indices of the four corners of this quad
        uint indexA = quadX + quadY * resolution;
        uint indexB = indexA + 1;
        uint indexC = indexA + resolution;
        uint indexD = indexC + 1;

        // Get heights for the four corners
        uint heightA = heights[indexA];
        uint heightB = heights[indexB];
        uint heightC = heights[indexC];
        uint heightD = heights[indexD];

        // Calculate actual positions in region space
        uint regionX = quadX * stride;
        uint regionY = quadY * stride;

        // Create the quad with correct positions and heights
        Quad quad;
        quad.a = uvec3(regionX, regionY, heightA);
        quad.b = uvec3(regionX + stride, regionY, heightB);
        quad.c = uvec3(regionX, regionY + stride, heightC);
        quad.d = uvec3(regionX + stride, regionY + stride, heightD);

        // Write the quad to memory
        Quad quadPtr = Quad(pushConstants.heapAddress + regionRef.heightMapMeshOffset + threadIndex * sizeof(Quad));
        quadPtr = quad;
    }
}

void maskHeightmapColumns()
{
    //first get the metadata
    //first check if the pallete is entirely air
    RegionRef regionRef = RegionRef(pushConstants.heapAddress + pushConstants.regionChunkMetadataOffset);
    bool airChunk[REGION_HEIGHT];
    for (uint i = 0; i < REGION_HEIGHT; i++) {
        airChunk[i] = false;
    }
    for (uint i = 0; i < REGION_HEIGHT; i++) {
        uvec3 position = uvec3(gl_GlobalInvocationID.xy, i);
        uint index2d = position.x + position.y * REGION_SIZE;
        uint index3d = position.x + position.y * REGION_SIZE + position.z * REGION_SIZE * REGION_SIZE;
        ChunkRef chunkRef = ChunkRef(regionRef.heapAddress + sizeof(RegionRef) + index3d * sizeof(ChunkRef));

        //Now we need to see if the chunk is only air
        //Were looking for chunks with only one palette entry
        if (chunkRef.paletteCount != 1) {
            continue;
        }

        //There is only one palette entry, so we can just use that
        uint chunkPalette = uint(pushConstants.heapAddress + chunkRef.paletteDataOffset);

        if (chunkPalette != 0) {
            continue;
        }

        airChunk[i] = true;
    }
    //Now that we know which chunks are air, we can turn it into one number by representing each air chunk as a 0 and the rest of the chunks as a 1
    uint mask = 0;
    for (uint i = 0; i < REGION_HEIGHT; i++) {
        mask |= airChunk[i] ? 0 : (1 << i);
    }

    //Now write the mask to the heightmap. Remember to write the mask directly
    uint heightMapIndex = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * gl_NumWorkGroups.x;
    uint heightMapAddress = pushConstants.heapAddress + regionRef.heightMapOffset + heightMapIndex * sizeof(uint);
    atomicExchange(uint(heightMapAddress), mask);
}
