#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_atomic_float : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_debug_printf : enable
#extension GL_EXT_shader_atomic_int64 : require

// Constants for quad data
const uint QUAD_SIZEOF = 7;  // Number of 64-bit values per quad
const uint REGION_SIZE = 64;
const vec2 QUAD_UVS[4] = vec2[](
    vec2(0.0, 0.0),  // Bottom-left
    vec2(1.0, 0.0),  // Bottom-right
    vec2(1.0, 1.0),  // Top-right
    vec2(0.0, 1.0)   // Top-left
);
const uint QUAD_UVS_INDEX[12] = uint[](
    0,1,2,0,2,3,
    2,1,0,3,2,0
);

layout(buffer_reference, scalar) buffer BitmapRef {
    uint64_t data[3][4096];  // 64x64 grid of floats, each column bit represents presense of a block
};
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

// Define the chunk data structure
layout(buffer_reference, scalar) buffer ChunkRef {
    uint64_t countPalette;      // Number of palette entries
    uint64_t offsetPalette;     // Palette data offset
    uint64_t offsetCompressed;  // Compressed voxel data offset
};

// Define a generic heap buffer reference for accessing data
layout(buffer_reference, scalar) buffer HeapBufferRef {
    uint64_t data[];
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
    uvec3 position;
    uint axis;     // Axis normal 0 = -X, 1 = +X, 2 = -Y, 3 = +Y, 4 = -Z, 5 = +Z
    uint material; // Material ID
};

// Function to get face data from the mesh buffer
void getFaceData(MeshRef meshRef,  out uvec3 pos, out uvec2 size, out uint axis, out uint material) {
    int faceIndex = gl_VertexIndex / 6;
    uint64_t slot = faceIndex * QUAD_SIZEOF;
    
    // Read position (posX, posY, posZ)
    pos = uvec3(
        (meshRef.data[uint(slot)]),      // posX
        (meshRef.data[uint(slot + 1)]),  // posY
        (meshRef.data[uint(slot + 2)])   // posZ (no adjustment)
    );
    
    // Read size (sizeX, sizeY)
    size = uvec2(
        (meshRef.data[uint(slot + 3)]), // sizeX
        (meshRef.data[uint(slot + 4)])  // sizeY
    );
    
    // Read axis and material
    axis = uint(meshRef.data[uint(slot + 5)]);
    material = uint(meshRef.data[uint(slot + 6)]);
}


uvec3 posFromUVW(uint axis, uvec3 uvw) {
    uvec3 position = uvec3(0);
    uint axisNormal = axis / 2;
    
    // Set the position values based on the axis normal
    if (axisNormal == 0) { // X normal
        // X = Z (depth), Y = Y, Z = X (corresponds to uv.y, uv.x)
        position.x = uvw.y;        // Depth along X-axis
        position.y = uvw.z;        // Y position
        position.z = uvw.x;        // X position (was U in bitmap)
    } 
    else if (axisNormal == 1) { // Y normal
        // X = X, Y = Z (depth), Z = Y (corresponds to uv.x, uv.y)
        position.x = uvw.z;        // X position (was U in bitmap)
        position.y = uvw.x;        // Depth along Y-axis
        position.z = uvw.y;        // Y position
    }
    else { // Z normal (axisNormal == 2)
        // X = X, Y = Y, Z = Z (depth) (corresponds to uv.x, uv.y)
        position.x = uvw.x;        // X position (was U in bitmap)
        position.y = uvw.y;        // Y position
        position.z = uvw.z;        // Depth along Z-axis
    }
    
    // Add 1 to the position along normal axis for positive faces (odd axis values)
    
    return position;
}
// Function to generate vertex position based on UV coordinates for a specific face
vec3 generateVertexPosition(uvec3 pos, uvec2 size, uint axis, bool flipFace) {
    int faceIndex = gl_VertexIndex / 6;
    int vertexInFace = gl_VertexIndex % 6;

    
    vec2 uv = QUAD_UVS[QUAD_UVS_INDEX[(flipFace ? 6 : 0) + vertexInFace]];
    return vec3(posFromUVW( axis, uvec3(pos) + uvec3(uv * size, 0)));
}

ivec3 axisNormal(uint axis) {
    for(uint d = 0; d < 3; d++) {
        for(int i = -1; i <= 1; i += 2) {
            if(axis / 2 == d && axis % 2 == i) {
                ivec3 normal = ivec3(0);
                normal[d] = i;
                return normal;
            }
        }
    }
    return ivec3(0, 0, 0);
}

bool occluded(vec3 pos, ivec3 lightSource, uint axis) {
    RegionRef regionData = RegionRef(pushConstants.heapAddress + pushConstants.regionOffset);
    BitmapRef bitmapRef = BitmapRef(pushConstants.heapAddress + regionData.offsetBitmap);

    // Starting position (voxel space)
    ivec3 mapPos = ivec3(floor(pos));
    
    // Ray direction (needs to be float for proper DDA)
    vec3 rayDir = normalize(vec3(lightSource) - pos);
    
    // Calculate distance from starting point to light source
    float lightDistance = length(vec3(lightSource) - pos);
    
    // Calculate step direction for each axis
    ivec3 step = ivec3(sign(rayDir));
    
    // Calculate distance between voxel boundaries
    vec3 deltaDist = abs(vec3(length(rayDir)) / rayDir);
    
    // Calculate distance to first boundary crossing for each axis
    vec3 sideDist = (sign(rayDir) * (vec3(mapPos) - pos) + (sign(rayDir) * 0.5) + 0.5) * deltaDist;
    
    // Initialize DDA parameters
    vec3 mask = vec3(0.0);
    const int MAX_RAY_STEPS = 64; // Limit ray steps for performance
    
    for (int i = 0; i < MAX_RAY_STEPS; i++) {
        // Check if current voxel is solid
        if (all(greaterThanEqual(mapPos, ivec3(0))) && all(lessThan(mapPos, ivec3(REGION_SIZE)))) {
            // Get the column bitmap
            uint bitmapIndex = uint(mapPos.x + mapPos.y * REGION_SIZE);
            uint64_t columnBits = bitmapRef.data[0][bitmapIndex];
            
            // Check if this voxel is solid
            uint64_t bitMask = uint64_t(1) << uint64_t(mapPos.z);
            
            if ((columnBits & bitMask) != 0) {
                return true; // Occluded
            }
        }
        
        // Find axis with smallest sideDist
        bvec3 boolMask = lessThanEqual(sideDist.xyz, min(sideDist.yzx, sideDist.zxy));
        mask = vec3(boolMask.x ? 1.0 : 0.0, boolMask.y ? 1.0 : 0.0, boolMask.z ? 1.0 : 0.0);
        
        // Advance to next voxel boundary
        sideDist += mask * deltaDist;
        mapPos += ivec3(mask) * step;
        
        // Check if we've gone past the light source (early exit)
        if (distance(vec3(mapPos), pos) > lightDistance) {
            return false;
        }
    }
    
    return false; // No occlusion found after max steps
}

// Function to calculate normal based on face axis
vec3 calculateNormal(uint axis) {
    vec3 normal = vec3(0.0);
    uint axisNormal = axis / 2; // Get base axis (0=X, 1=Y, 2=Z)
    
    // CORRECTED: Based on the codebase convention:
    // axis 0: -X, axis 1: +X, axis 2: -Y, axis 3: +Y, axis 4: -Z, axis 5: +Z
    // axis % 2 == 0 means negative direction, axis % 2 == 1 means positive direction
    float direction = (axis % 2 == 0) ? 1.0 : -1.0;
    
    normal[axisNormal] = direction;
    return normal;
}

void fixUVW(inout uvec3 uvw, uint axis) {
    if(axis / 2 == 0) {
        uvw[(axis / 2 + 2) % 3] += 1;
    if(axis % 2 == 1) {
        uvw.z -= 1;
    }
    }
    if(axis / 2 == 1) {
        if(axis % 2 == 0) {

        uvw.z += 1;
        }
    }
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
    // Get face data
    uvec3 pos;
    uvec2 size;
    uint axis, material;
    getFaceData(meshData, pos, size, axis, material);
    fixUVW(pos, axis);
    
    // Get UV coordinates for this vertex
    bool flipFace = false;
    if(axis % 2 == 1) {
        flipFace = true;
    }

    // Generate position and normal
    vec3 worldPos = generateVertexPosition(pos, size, axis, flipFace);
    if (axis / 2 != 2) {
        worldPos.z -= 1;
    }
    vec3 normal = calculateNormal(axis);
    
    // Transform position to clip space
    gl_Position = cameraData.viewProjection * vec4(worldPos, 1.0);
    
    // Output to fragment shader
    vec3 color = vec3(
        axis / 2 == 0 ? 1.0 : 0.0,
        axis / 2 == 1 ? 1.0 : 0.0,
        axis / 2 == 2 ? 1.0 : 0.0
    );
    
    // Check if this vertex should be shadowed
    // Use a more extreme light source position to ensure shadows work
    ivec3 lightSource = ivec3(1, 1, 300);
    
    // Use world position for the shadow test, with a small offset to avoid self-shadowing
    vec3 shadowPos = worldPos + vec3(normal)  + vec3(0, 0, 0.2);
    
    // Check for shadow
    bool isOccluded =  occluded(shadowPos, lightSource, axis);
    
    // Apply shadow if occluded
    if (isOccluded) {
        color *= 0.3; // Darker shadow for better visibility
    }
    
    fragColor = color;
    fragNormal = normal;
}
