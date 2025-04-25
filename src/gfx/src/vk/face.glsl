#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_atomic_float : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_debug_printf : enable
#extension GL_EXT_shader_atomic_int64 : require

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
    uint64_t data[];  // Face data: minX, minY, minZ, maxX, maxY, maxZ, axis, material
};

// Output to fragment shader
layout(location = 0) out vec3 fragColor;
layout(location = 1) out vec3 fragNormal;
layout(location = 2) out vec2 fragTexCoord;

// Constants for face data
const int QUAD_SIZEOF = 8;  // Number of uint64_t values per face

// Define quad vertices (standard order for 2 triangles forming a quad)
const vec2 QUAD_UVS[6] = vec2[](
    vec2(0.0, 0.0), // Bottom-left
    vec2(1.0, 0.0), // Bottom-right
    vec2(0.0, 1.0), // Top-left
    vec2(1.0, 0.0), // Bottom-right
    vec2(1.0, 1.0), // Top-right
    vec2(0.0, 1.0)  // Top-left
);

// Function to get face data from the mesh buffer
void getFaceData(MeshRef meshRef, uint faceIndex, out vec3 min, out vec3 max, out uint axis, out uint material) {
    uint64_t slot = faceIndex * QUAD_SIZEOF;
    
    min = vec3(
        float(meshRef.data[uint(slot)]),
        float(meshRef.data[uint(slot + 1)]),
        float(meshRef.data[uint(slot + 2)])
    );
    
    max = vec3(
        float(meshRef.data[uint(slot + 3)]),
        float(meshRef.data[uint(slot + 4)]),
        float(meshRef.data[uint(slot + 5)])
    );
    
    axis = uint(meshRef.data[uint(slot + 6)]);
    material = uint(meshRef.data[uint(slot + 7)]);
}

// Function to generate vertex position based on UV coordinates for a specific face
vec3 generateVertexPosition(vec3 min, vec3 max, uint axis, vec2 uv) {
    vec3 position;
    
    // Determine which face of the cube we're drawing and calculate position
    if (axis < 6) { // Cube faces (0-5)
        // Get the primary axis (0=X, 1=Y, 2=Z)
        uint primaryAxis = axis / 2;
        // Get the direction (0=positive, 1=negative)
        bool isNegative = (axis % 2) == 1;
        
        // Set the position on the primary axis (either min or max)
        position = min;
        
        if (isNegative) {
            // For negative faces (left, bottom, back)
            position[primaryAxis] = min[primaryAxis];
        } else {
            // For positive faces (right, top, front)
            position[primaryAxis] = max[primaryAxis];
        }
        
        // Get the other two axes for the plane
        uint uAxis = (primaryAxis + 1) % 3;
        uint vAxis = (primaryAxis + 2) % 3;
        
        // Adjust the winding order for negative faces to ensure correct orientation
        if (isNegative && primaryAxis != 1) { // Except for Y-axis where we keep normal winding
            // Flip U for negative faces to maintain correct orientation
            position[uAxis] = mix(max[uAxis], min[uAxis], uv.x);
            position[vAxis] = mix(min[vAxis], max[vAxis], uv.y);
        } else {
            // Normal mapping for positive faces
            position[uAxis] = mix(min[uAxis], max[uAxis], uv.x);
            position[vAxis] = mix(min[vAxis], max[vAxis], uv.y);
        }
    }
    
    return position;
}

// Function to calculate normal based on face axis
vec3 calculateNormal(uint axis) {
    // Calculate primary axis (0=X, 1=Y, 2=Z)
    uint primaryAxis = axis / 2;
    // Calculate direction (0=positive, 1=negative)
    bool isNegative = (axis % 2) == 1;
    
    vec3 normal = vec3(0.0);
    normal[primaryAxis] = isNegative ? -1.0 : 1.0;
    
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
    vec3 min, max;
    uint axis, material;
    getFaceData(meshData, faceIndex, min, max, axis, material);
    
    // Get UV coordinates for this vertex
    vec2 uv = QUAD_UVS[vertexInFace];
    
    // Generate position and normal
    vec3 worldPos = generateVertexPosition(min, max, axis, uv);
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
