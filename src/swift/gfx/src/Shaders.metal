#include <metal_stdlib>
using namespace metal;

struct Generator {
    uint3 size;
};

struct Mesher {
    uint3 size;
};

struct Mesh {
    uint vertexCount;
    uint indexCount;
};

uint posToIndex(uint3 pos, uint3 size) {
    return pos.x + pos.y * size.x + pos.z * size.x * size.y;
}

kernel void baseTerrain(
    device const Generator* generator       [[buffer(0)]],
    device  char* chunk                [[buffer(1)]],
    uint3 position                          [[ thread_position_in_grid ]])
{
    const uint3 size = generator->size;
    if (position.z == 3) {
        // Get the 1D index for this position
        uint index = posToIndex(position, size);
        
        // Mark this position as solid (1) in the chunk data
        // Assuming chunk data stores 1 for solid voxels and 0 for air
        chunk[index] = 1;
    }
}

kernel void generateVertices(
      device const Mesher* mesher   [[buffer(0)]],
      device const char* chunk      [[buffer(1)]],
      device Mesh* mesh             [[buffer(2)]],
      device float3* vertices       [[buffer(3)]],
      device int* indices           [[buffer(4)]],
      uint3 position                [[ thread_position_in_grid ]])
{
    
}

