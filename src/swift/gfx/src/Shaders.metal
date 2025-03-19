#include <metal_stdlib>
using namespace metal;

struct Generator {
    uint3 size;
};

struct Mesher {
    uint3 size;
};

struct Mesh {
    atomic_uint faceCount;
    atomic_uint indexCount;
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


// Positions for the 8 corners of a cube
constant int3 cornerOffsets[8] = {
    int3(0, 0, 0), int3(1, 0, 0), int3(1, 0, 1), int3(0, 0, 1),
    int3(0, 1, 0), int3(1, 1, 0), int3(1, 1, 1), int3(0, 1, 1)
};

// Faces of a cube: 6 faces, each with 4 indices into the cornerOffsets array
constant int faceCornerIndices[6][4] = {
    {0, 1, 2, 3}, // Bottom face
    {4, 5, 6, 7}, // Top face
    {0, 1, 5, 4}, // Front face
    {3, 2, 6, 7}, // Back face
    {0, 3, 7, 4}, // Left face
    {1, 2, 6, 5}  // Right face
};

// Direction vectors for the 6 faces (used for neighbor checks)
constant int3 faceDirections[6] = {
    int3(0, -1, 0), // Bottom
    int3(0, 1, 0),  // Top
    int3(0, 0, -1), // Front
    int3(0, 0, 1),  // Back
    int3(-1, 0, 0), // Left
    int3(1, 0, 0)   // Right
};

bool isSolid(device const char* chunk, uint3 pos, uint3 size) {
    // Out of bounds checks
    if (pos.x >= size.x || pos.y >= size.y || pos.z >= size.z) {
        return false;
    }
    
    uint index = posToIndex(pos, size);
    return chunk[index] != 0;
}

struct Face {
    uint3 position[4];
    char normal;
};

kernel void generateMesh(
    device const Mesher* mesher [[buffer(0)]],
    device const char* chunk [[buffer(1)]],
    device Mesh* mesh [[buffer(2)]],
    device Face* faces [[buffer(3)]],
    uint3 position [[ thread_position_in_grid ]])
{
    const uint3 size = mesher->size;
    
    // Skip positions outside the chunk bounds
    if (position.x >= size.x || position.y >= size.y || position.z >= size.z) {
        return;
    }
    
    // Check if this voxel is solid
    uint voxelIndex = posToIndex(position, size);
    bool currentVoxelSolid = chunk[voxelIndex] != 0;
    
    // Skip empty voxels - no need to generate faces for them
    if (!currentVoxelSolid) {
        return;
    }
    
    // For each face of the cube
    for (int face = 0; face < 6; face++) {
        // Check the neighboring voxel in the face direction
        int3 neighborPos = int3(position) + faceDirections[face];
        
        // If the neighbor is outside the chunk or is empty (air), we need to create a face
        if (neighborPos.x < 0 || neighborPos.x >= size.x ||
            neighborPos.y < 0 || neighborPos.y >= size.y ||
            neighborPos.z < 0 || neighborPos.z >= size.z ||
            !isSolid(chunk, uint3(neighborPos), size)) {
            
            // Get the current face count, then increment it by 4 (for a quad)
            uint faceOffset = atomic_fetch_add_explicit(&mesh->vertexCount, 1, memory_order_relaxed);

            faces[faceOffset] = Face {
                position,
                normal: char(face)
            };
        }
    }
}