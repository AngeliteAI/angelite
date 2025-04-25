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

// Define the heightmap data structure - match the structure in 070_generate_heightmap.glsl
layout(buffer_reference, scalar) readonly buffer BitmapRef {
    // The heightmap is stored as uint64_t values that are reinterpreted as doubles
    uint64_t x[4096];  // 8x8 grid per chunk
    uint64_t y[4096];  // 8x8 grid per chunk
    uint64_t z[4096];  // 8x8 grid per chunk
};

// Define the region data structure
layout(buffer_reference, scalar) buffer RegionRef {
    uint64_t offsetBitmap;  // New field for heightmap offset
    uint64_t chunkOffsets[512];
};

layout(buffer_reference, scalar) buffer ChunkRef {
    uint64_t countPalette;
    uint64_t offsetPalette;
    uint64_t offsetCompressed;
};

// Grid parameters for the heightmap plane
const int CHUNK_SIZE = 8;  // 8x8 grid per chunk
const int REGION_SIZE = 8;  // 8x8 chunks in a region
const int GRID_SIZE = 64;  // 64x64 points total


// Define the 2D points for the square (4 vertices)
const vec2 points[4] = vec2[](
    vec2(0.0, 0.0),    // Bottom left
    vec2(1.0, 0.0),    // Bottom right
    vec2(0.0, 1.0),    // Top left
    vec2(1.0, 1.0)     // Top right
);

// Define indices for the two triangles that make up a square
const int indices[6] = int[](
    0, 1, 2,  // First triangle (bottom left, bottom right, top left)
    1, 3, 2   // Second triangle (bottom right, top right, top left)
);

// Output color to fragment shader
layout(location = 0) out vec3 fragColor;

uint calculateHeightmapIndex(uvec2 threadPos) {
    // Calculate region and chunk indices
    uint x = clamp(threadPos.x, 0, GRID_SIZE - 1);
    uint y = clamp(threadPos.y, 0, GRID_SIZE - 1);
    
    // Use the same index calculation as in 070_generate_heightmap.glsl
    return x + y * GRID_SIZE;
}
uint chunkHeight(RegionRef region, ivec3 pos) {
    BitmapRef bitmapData = BitmapRef(pushConstants.heapAddress + region.offsetBitmap);
   
    uint index = calculateHeightmapIndex(pos.xy);

    uint highBits = uint(bitmapData.z[index] >> 32);
    uint lowBits = uint(bitmapData.z[index] & 0xFFFFFFFF);
    debugPrintfEXT("Heightmap: %llu", bitmapData.x[index]);
    if (highBits != 0) {
        return findMSB(highBits) + 32;
    }
    if (lowBits != 0) {
        return findMSB(lowBits);
    }
    return 0;
}
// Function to safely sample height from heightmap
float sampleHeight(RegionRef region, int x, int y) {
    return chunkHeight(region, ivec3(x, y, 0)); 
}

// Function to perform bilinear interpolation between four height values
float interpolateHeight(RegionRef region, float x, float y) {
    // Get integer coordinates
    int x0 = int(floor(x));
    int y0 = int(floor(y));
    int x1 = x0 + 1;
    int y1 = y0 + 1;
    
    // Get fractional parts for interpolation
    float fx = x - float(x0);
    float fy = y - float(y0);
    
    // Sample the four surrounding heights
    float h00 = sampleHeight(region, x0, y0);
    float h10 = sampleHeight(region, x1, y0);
    float h01 = sampleHeight(region, x0, y1);
    float h11 = sampleHeight(region, x1, y1);
    
    // Perform bilinear interpolation
    float h0 = mix(h00, h10, fx);
    float h1 = mix(h01, h11, fx);
    return mix(h0, h1, fy);
}

void main() {
    // Get the heap address from push constants
    uint64_t heapAddr = pushConstants.heapAddress;
    uint64_t cameraOffset = pushConstants.cameraOffset;
    uint64_t regionOffset = pushConstants.regionOffset;  // This is actually the region offset
    
    // Create camera buffer reference
    uint64_t cameraAddr = heapAddr + cameraOffset;
    CameraBuffer cameraData = CameraBuffer(cameraAddr);
    
    // Create region reference
    uint64_t regionAddr = heapAddr + regionOffset;
    RegionRef regionData = RegionRef(regionAddr);
    
    // Calculate which triangle we're in (each square has 2 triangles)
    int squareIndex = gl_VertexIndex / 6;  // 6 vertices per square (2 triangles)
    int vertexInSquare = gl_VertexIndex % 6;
    
    // Calculate grid position for this square
    int gridX = squareIndex % 64;
    int gridY = squareIndex / 64;
    
    // Get the point for this vertex in the square
    vec2 point = points[indices[vertexInSquare]];
    
    // Calculate world position without scaling
    int worldX = gridX + int(point.x);
    int worldY = gridY + int(point.y);
    
    // Interpolate height from surrounding points
    float height = sampleHeight(regionData, worldX, worldY);
    debugPrintfEXT("Height: %f", height);
    
    // Create world position with proper transformation - Z is up
    vec4 worldPos = vec4(worldX, worldY, height, 1.0);  // X, Y for ground plane, Z for height
    gl_Position = cameraData.viewProjection * worldPos;
    
    // Debug coloring based on position and height
    fragColor = vec3(
        worldX / 64.0,     // Red component based on X position
        worldY / 64.0,     // Green component based on Y position
        height / 64.0      // Blue component based on height (Z)
    );
}
