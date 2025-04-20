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
    uint64_t heightmapOffset;  // Offset to heightmap data
} pushConstants;

// Define the camera data structure as it appears in memory
layout(buffer_reference, scalar, align = 4) readonly buffer CameraBuffer {
    mat4 viewProjection;
};

// Define the heightmap data structure
layout(buffer_reference, scalar, align = 4) readonly buffer HeightmapBuffer {
    double heights[4096];  // Total heightmap points (64x64)
};

// Grid parameters for the heightmap plane
const int GRID_SIZE = 64;  // 64x64 grid
const int TOTAL_HEIGHTMAP_POINTS = 4096;  // 64x64 points

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

// Function to safely sample height from heightmap
float sampleHeight(HeightmapBuffer heightmap, int x, int z) {
    // Clamp coordinates to valid range
    x = clamp(x, 0, GRID_SIZE - 1);
    z = clamp(z, 0, GRID_SIZE - 1);
    
    int index = x + z * GRID_SIZE;
    double heightBits = heightmap.heights[index];
    return float(heightBits);
}

// Function to perform bilinear interpolation between four height values
float interpolateHeight(HeightmapBuffer heightmap, float x, float z) {
    // Get integer coordinates
    int x0 = int(floor(x));
    int z0 = int(floor(z));
    int x1 = x0 + 1;
    int z1 = z0 + 1;
    
    // Get fractional parts for interpolation
    float fx = x - float(x0);
    float fz = z - float(z0);
    
    // Sample the four surrounding points
    float h00 = sampleHeight(heightmap, x0, z0);
    float h10 = sampleHeight(heightmap, x1, z0);
    float h01 = sampleHeight(heightmap, x0, z1);
    float h11 = sampleHeight(heightmap, x1, z1);
    
    // Bilinear interpolation
    float h0 = mix(h00, h10, fx);
    float h1 = mix(h01, h11, fx);
    return mix(h0, h1, fz);
}

void main() {
    // Get the heap address from push constants
    uint64_t heapAddr = pushConstants.heapAddress;
    uint64_t cameraOffset = pushConstants.cameraOffset;
    uint64_t heightmapOffset = pushConstants.heightmapOffset;
    
    // Create camera buffer reference
    uint64_t cameraAddr = heapAddr + cameraOffset;
    CameraBuffer cameraData = CameraBuffer(cameraAddr);
    
    // Create heightmap buffer reference
    uint64_t heightmapAddr = heapAddr + heightmapOffset;
    HeightmapBuffer heightmapData = HeightmapBuffer(heightmapAddr);
    
    // Calculate which triangle we're in (each square has 2 triangles)
    int squareIndex = gl_VertexIndex / 6;  // 6 vertices per square (2 triangles)
    int vertexInSquare = gl_VertexIndex % 6;
    
    // Calculate grid position for this square
    int gridX = squareIndex % GRID_SIZE;
    int gridZ = squareIndex / GRID_SIZE;
    
    // Get the point for this vertex in the square
    vec2 point = points[indices[vertexInSquare]];
    
    // Calculate world position
    float worldX = float(gridX) + point.x;
    float worldZ = float(gridZ) + point.y;
    
    // Interpolate height from surrounding points
    float height = interpolateHeight(heightmapData, worldX, worldZ);
    
    // Create world position with interpolated height
    vec4 worldPos = vec4(worldX, height, worldZ, 1.0);
    
    // Apply view-projection matrix
    gl_Position = cameraData.viewProjection * worldPos;
    
    // Simple color based on height
    float heightColor = height / 64.0;  // Normalize height for color (assuming max height is 64)
    fragColor = vec3(heightColor, heightColor * 0.8, heightColor * 0.6);
}
