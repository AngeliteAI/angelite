#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_atomic_float : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_debug_printf : enable
#extension GL_EXT_shader_atomic_int64 : require

// Constants for quad data
const uint QUAD_SIZEOF = 6;  // Number of 64-bit values per quad
const vec2 QUAD_UVS[6] = vec2[](
    vec2(0.0, 0.0),  // Bottom-left
    vec2(1.0, 0.0),  // Bottom-right
    vec2(1.0, 1.0),  // Top-right
    vec2(0.0, 0.0),  // Bottom-left
    vec2(1.0, 1.0),  // Top-right
    vec2(0.0, 1.0)   // Top-left
);

// Push constant for the heap address
layout(push_constant, scalar) uniform PushConstants {
    uint64_t heapAddress;  // Device address of the heap
    uint64_t cameraOffset;
    uint64_t regionOffset;
} pushConstants;

// Define the camera data structure as it appears in memory
layout(buffer_reference, scalar) readonly buffer CameraBuffer {
    mat4 viewProjection;
};

// Define the region data structure
layout(buffer_reference, scalar) buffer RegionRef {
    uint64_t offsetBitmap;  // Heightmap offset
    uint64_t offsetMesh;    // Mesh data offset
    uint64_t faceCount;     // Number of faces
    uint64_t chunkOffsets[512];
};

// Define the mesh data structure
layout(buffer_reference, scalar) readonly buffer MeshRef {
    uint64_t data[];  // Face data: posX, posY, sizeX, sizeY, axis, material
};

// Output to fragment shader
layout(location = 0) out vec3 fragColor;
layout(location = 1) out vec3 fragNormal;
layout(location = 2) out vec2 fragTexCoord;

struct Quad {
    uvec2 size;
    uvec2 position;
    uint axis;     // Axis normal 0 = -X, 1 = +X, 2 = -Y, 3 = +Y, 4 = -Z, 5 = +Z
    uint material; // Material ID
};

// Function to get face data from the mesh buffer
void getFaceData(MeshRef meshRef, uint faceIndex, out vec2 pos, out vec2 size, out uint axis, out uint material) {
    uint64_t slot = faceIndex * QUAD_SIZEOF;
    
    // Read position (posX, posY)
    pos = vec2(
        float(meshRef.data[uint(slot)]),     // posX
        float(meshRef.data[uint(slot + 1)])  // posY
    );
    
    // Read size (sizeX, sizeY)
    size = vec2(
        float(meshRef.data[uint(slot + 2)]), // sizeX
        float(meshRef.data[uint(slot + 3)])  // sizeY
    );
    
    // Read axis and material
    axis = uint(meshRef.data[uint(slot + 4)]);
    material = uint(meshRef.data[uint(slot + 5)]);
}

// Function to generate vertex position based on UV coordinates for a specific face
vec3 generateVertexPosition(vec2 pos, vec2 size, uint axis, vec2 uv) {
    vec3 position = vec3(0.0);
    uint axisNormal = axis % 3; // Get the axis normal (0=X, 1=Y, 2=Z)
    uint uAxis = (axisNormal + 1) % 3; // U axis is perpendicular to normal
    uint vAxis = (axisNormal + 2) % 3; // V axis is perpendicular to normal and u
    
    // Set the 2D position components based on the face orientation
    position[uAxis] = pos.x + size.x * uv.x;
    position[vAxis] = pos.y + size.y * uv.y;
    
    // Set the position along the normal axis based on whether this is a positive or negative face
    // For axis 0,2,4 (negative faces), use 0; for axis 1,3,5 (positive faces), use 1
    position[axisNormal] = (axis >= 3) ? 1.0 : 0.0;
    
    return position;
}

// Function to calculate normal based on face axis
vec3 calculateNormal(uint axis) {
    vec3 normal = vec3(0.0);
    uint axisNormal = axis % 3; // Get base axis (0=X, 1=Y, 2=Z)
    float direction = (axis >= 3) ? 1.0 : -1.0; // Positive or negative direction
    
    normal[axisNormal] = direction;
    return normal;
}

void main() {
    // Get the heap address from push constants
    uint64_t heapAddr = pushConstants.heapAddress;
    uint64_t cameraOffset = pushConstants.cameraOffset;
    uint64_t regionOffset = pushConstants.regionOffset;
    
    // Create camera buffer reference
    uint64_t cameraAddr = heapAddr + cameraOffset;
    CameraBuffer cameraData = CameraBuffer(cameraAddr);
    
    // Create region reference
    uint64_t regionAddr = heapAddr + regionOffset;
    RegionRef regionData = RegionRef(regionAddr);
    
    // Create mesh reference
    uint64_t meshAddr = heapAddr + regionData.offsetMesh;
    MeshRef meshData = MeshRef(meshAddr);
    
    // Calculate which face we're rendering
    int faceIndex = gl_VertexIndex / 6;
    int vertexInFace = gl_VertexIndex % 6;
    
    // Get face data
    vec2 pos, size;
    uint axis, material;
    getFaceData(meshData, faceIndex, pos, size, axis, material);
    
    // Get UV coordinates for this vertex
    vec2 uv = QUAD_UVS[vertexInFace];
    
    // Generate position and normal
    vec3 worldPos = generateVertexPosition(pos, size, axis, uv);
    vec3 normal = calculateNormal(axis);
    
    // Transform position to clip space
    gl_Position = cameraData.viewProjection * vec4(worldPos, 1.0);
    
    // Output to fragment shader
    fragColor = vec3(
        float(material & 0xFF) / 255.0,
        float((material >> 8) & 0xFF) / 255.0,
        float((material >> 16) & 0xFF) / 255.0
    );
    fragNormal = normal;
    fragTexCoord = uv; // Pass texture coordinates to fragment shader
}
