#include <metal_stdlib>
using namespace metal;
struct Generator {
    uint3 size;
};

struct Mesher {
    uint3 size;
};

uint posToIndex(uint3 pos, uint3 size) {
    return pos.x + pos.y * size.x + pos.z * size.x * size.y;
}

struct Mesh {
    atomic_uint faceCount;
    atomic_uint indexCount;
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

// Constants
constant float3 CUBE_SCALE = float3(1.0, 1.0, 1.0);
// Face definitions
struct Face {
    uint3 position;  // Base position of the face
    uchar normal;    // Normal direction (0-5)
};
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

// The 8 corners of a cube
constant float3 cubeVertices[8] = {
    float3(0, 0, 0),  // 0: bottom southwest (---)
    float3(1, 0, 0),  // 1: bottom southeast (+--) 
    float3(1, 1, 0),  // 2: bottom northeast (++-)
    float3(0, 1, 0),  // 3: bottom northwest (-+-)
    float3(0, 0, 1),  // 4: top southwest (--+)
    float3(1, 0, 1),  // 5: top southeast (+-+)
    float3(1, 1, 1),  // 6: top northeast (+++)
    float3(0, 1, 1)   // 7: top northwest (-++)
};

// Indices into cube vertices for each face
// Adjusted to work with triangulation pattern: 0,1,2,0,2,3
constant uint faceIndices[6][4] = {
    {0, 4, 7, 3},  // -X face (west/left): 0→4→7→3
    {1, 2, 6, 5},  // +X face (east/right): 1→2→6→5
    {0, 1, 5, 4},  // -Y face (south/front): 0→1→5→4
    {3, 7, 6, 2},  // +Y face (north/back): 3→7→6→2
    {0, 3, 2, 1},  // -Z face (bottom): 0→3→2→1
    {4, 5, 6, 7}   // +Z face (top): 4→5→6→7
};

// Direction vectors for the 6 face normals
constant float3 faceNormals[6] = {
    float3(-1, 0, 0),  // -X (0)
    float3(1, 0, 0),   // +X (1)
    float3(0, -1, 0),  // -Y (2)
    float3(0, 1, 0),   // +Y (3)
    float3(0, 0, -1),  // -Z (4)
    float3(0, 0, 1)    // +Z (5)
};

// Colors for each face direction
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

// Map from triangle index to face vertex index (for triangulation)
constant uint triToQuadVertexIndex[6] = {0, 1, 2, 0, 2, 3};

vertex VertexOutput vertexFaceShader(
    uint vertexID [[vertex_id]],
    device const Face* faces [[buffer(0)]],
    constant CameraData& camera [[buffer(1)]],
    uint baseVertex [[base_vertex]]
) {
    VertexOutput out;
    
    // Get face index from base vertex (each face has 4 vertices)
    uint faceIndex = baseVertex / 4;
    
    // Get vertex index within the face (0-3)
    uint vertexInFace = vertexID;
    
    // Get the face data
    Face face = faces[faceIndex];
    uint normalDirection = face.normal % 6;
    
    // Get the correct vertex for this face direction
    uint cubeVertexIndex = faceIndices[normalDirection][vertexInFace];
    
    // Get the base position and vertex offset
    float3 basePosition = float3(face.position);
    float3 vertexOffset = cubeVertices[cubeVertexIndex];
    
    // Calculate world position
    float3 worldPosition = basePosition + vertexOffset;
    
    // Transform to clip space
    out.position = camera.viewProjection * float4(worldPosition, 1.0);
    
    // Pass attributes to fragment shader
    out.worldPos = worldPosition;
    out.normal = faceNormals[normalDirection];
    out.color = faceColors[normalDirection];
    
    return out;
}

fragment float4 fragmentFaceShader(
    VertexOutput in [[stage_in]],
    constant CameraData& camera [[buffer(1)]]
) {
    // Simple diffuse lighting
    float3 lightDir = normalize(float3(0.5, 0.8, 0.3));
    float diffuse = max(0.0, dot(in.normal, lightDir));
    
    // Add ambient lighting
    float ambient = 0.3;
    float lighting = ambient + diffuse * 0.7;
    
    // Final color with better minecraft-style lighting
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

