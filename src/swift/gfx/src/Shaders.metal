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
// Direction vectors for the 6 faces (used for neighbor checks)
constant int3 faceDirections[6] = {
    int3(0, -1, 0), // Bottom
    int3(0, 1, 0),  // Top
    int3(0, 0, -1), // Front
    int3(0, 0, 1),  // Back
    int3(-1, 0, 0), // Left
    int3(1, 0, 0)   // Right
};

// Constants
constant float3 CUBE_SCALE = float3(1.0, 1.0, 1.0);
// Face definitions
struct Face {
    uint3 position;  // Base position of the face
    uchar normal;    // Normal direction (0-5)
};

// Vertex shader input
// Vertex shader output
struct VertexOutput {
    float4 position [[position]];
    float3 worldPos;
    float3 normal;
    float3 color;
};

// Camera data
struct CameraData {
    float3 position;
    float4x4 viewProjection;
};

// Direction vectors for the 6 face normals
constant float3 faceNormals[6] = {
    float3(-1, 0, 0),  // -X
    float3(1, 0, 0),   // +X
    float3(0, -1, 0),  // -Y
    float3(0, 1, 0),   // +Y
    float3(0, 0, -1),  // -Z
    float3(0, 0, 1)    // +Z
};

// Offsets for each vertex in a face
// Each face has 4 vertices arranged in a quad
constant float3 vertexOffsets[6][4] = {
    // -X face (0)
    {float3(0, 0, 0), float3(0, 0, 1), float3(0, 1, 1), float3(0, 1, 0)},
    // +X face (1)
    {float3(1, 0, 0), float3(1, 1, 0), float3(1, 1, 1), float3(1, 0, 1)},
    // -Y face (2)
    {float3(0, 0, 0), float3(1, 0, 0), float3(1, 0, 1), float3(0, 0, 1)},
    // +Y face (3)
    {float3(0, 1, 0), float3(0, 1, 1), float3(1, 1, 1), float3(1, 1, 0)},
    // -Z face (4)
    {float3(0, 0, 0), float3(0, 1, 0), float3(1, 1, 0), float3(1, 0, 0)},
    // +Z face (5)
    {float3(0, 0, 1), float3(1, 0, 1), float3(1, 1, 1), float3(0, 1, 1)}
};

// Colors for debugging (a different color for each face direction)
constant float3 faceColors[6] = {
    float3(1.0, 0.0, 0.0),  // -X: Red
    float3(0.0, 1.0, 0.0),  // +X: Green
    float3(0.0, 0.0, 1.0),  // -Y: Blue
    float3(1.0, 1.0, 0.0),  // +Y: Yellow
    float3(1.0, 0.0, 1.0),  // -Z: Magenta
    float3(0.0, 1.0, 1.0)   // +Z: Cyan
};

// AO factor for each vertex in a face
constant float aoFactors[4] = {
    0.8, 0.9, 1.0, 0.85
};

bool isSolid(device const char* chunk, uint3 pos, uint3 size) {
    // Out of bounds checks
    if (pos.x >= size.x || pos.y >= size.y || pos.z >= size.z) {
        return false;
    }
    
    uint index = posToIndex(pos, size);
    return chunk[index] != 0;
}
// Fixed vertex function - moved attributes to the function parameter
vertex VertexOutput vertexFaceShader(
    uint vertexID [[vertex_id]],
    uint instanceID [[instance_id]],
    device const Face* faces [[buffer(0)]],
    constant CameraData& camera [[buffer(1)]]
) {
    VertexOutput out;
    
    // Each face has 4 vertices
    uint vertexInFace = vertexID % 4;
    uint faceIndex = vertexID / 4;
    
    // Get face data from the buffer
    Face face = faces[faceIndex];
    
    // Get normal direction
    uint normalIndex = face.normal % 6;
    float3 normal = faceNormals[normalIndex];
    
    // Calculate world position by adding the vertex offset to the face position
    float3 basePosition = float3(face.position);
    float3 vertexOffset = vertexOffsets[normalIndex][vertexInFace];
    float3 worldPosition = basePosition + vertexOffset * CUBE_SCALE;
    
    // Transform to clip space
    out.position = camera.viewProjection * float4(worldPosition, 1.0);
    
    // Pass attributes to fragment shader
    out.worldPos = worldPosition;
    out.normal = normal;
    
    // Set color based on face normal (for debugging) with simple ambient occlusion
    out.color = faceColors[normalIndex] * aoFactors[vertexInFace];
    
    return out;
}

fragment float4 fragmentFaceShader(
    VertexOutput in [[stage_in]],
    constant CameraData& camera [[buffer(1)]]
) {
    // Simple diffuse lighting
    float3 lightDir = normalize(float3(0.5, 1.0, 0.3));
    float diffuse = max(0.0, dot(in.normal, lightDir));
    
    // Add ambient lighting
    float ambient = 0.2;
    float lighting = ambient + diffuse * 0.8;
    
    // Final color
    float3 color = in.color * lighting;
    
    return float4(color, 1.0);
}


// Mesh generation kernel
kernel void generateMesh(
    device const Mesher* mesher [[buffer(0)]],
    device const char* chunk [[buffer(1)]],
    device atomic_uint* faceCount [[buffer(2)]],
    device Face* faces [[buffer(3)]],
    uint3 position [[thread_position_in_grid]]
) {
    const uint3 size = mesher->size;
    
    // Skip positions outside the chunk bounds
    if (position.x >= size.x || position.y >= size.y || position.z >= size.z) {
        return;
    }
    
    // Check if this voxel is solid
    uint voxelIndex = position.x + position.y * size.x + position.z * size.x * size.y;
    bool currentVoxelSolid = chunk[voxelIndex] != 0;
    
    // Skip empty voxels
    if (!currentVoxelSolid) {
        return;
    }
    
    // For each face of the cube
    for (int faceDir = 0; faceDir < 6; faceDir++) {
        // Check the neighboring voxel in the face direction
        int3 neighborPos = int3(position) + faceDirections[faceDir];
        
        // If the neighbor is outside the chunk or is empty, we need to create a face
        if (neighborPos.x < 0 || neighborPos.x >= size.x ||
            neighborPos.y < 0 || neighborPos.y >= size.y ||
            neighborPos.z < 0 || neighborPos.z >= size.z ||
            !isSolid(chunk, uint3(neighborPos), size)) {
            
            // Get the current face count, then increment it
            uint faceIndex = atomic_fetch_add_explicit(faceCount, 1, memory_order_relaxed);
            
            // Create the face
            faces[faceIndex].position = position;
            faces[faceIndex].normal = uchar(faceDir);
        }
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

// Offsets for each vertex in a face
// Each face has 4 vertices arranged in a quad

// Colors for debugging (a different color for each face direction)


// Utility functions for terrain generation
kernel void baseTerrain(
    device const Generator* generator [[buffer(0)]],
    device char* chunk [[buffer(1)]],
    uint3 position [[thread_position_in_grid]]
) {
    const uint3 size = generator->size;
    if (position.x >= size.x || position.y >= size.y || position.z >= size.z) {
        return;
    }
    
    // Simple terrain generation - solid below certain height
    if (position.y < 8) {
        // Get the 1D index for this position
        uint index = position.x + position.y * size.x + position.z * size.x * size.y;
        
        // Mark this position as solid
        chunk[index] = 1;
    }
}

// Face calculation for mesh generation
// Mesh generation kernel