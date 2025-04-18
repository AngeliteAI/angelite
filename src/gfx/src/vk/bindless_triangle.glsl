#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_debug_printf : enable

// Push constant for the heap address
layout(push_constant) uniform PushConstants {
    uint64_t heapAddress;  // Device address of the heap
    uint64_t cameraOffset;
} pushConstants;

// Define the camera data structure as it appears in memory
layout(buffer_reference, std430) readonly buffer CameraBuffer {
    mat4 viewProjection;
    vec3 position;
    float padding;
};

// The triangle vertex positions and colors
const vec2 positions[3] = vec2[](
    vec2(0.0, -1.0),   // Bottom center
    vec2(1.0, 1.0),    // Top right
    vec2(-1.0, 1.0)    // Top left
);

// Add offsets to move triangle in front of camera and to the side
// This keeps it visible with Z-up configuration
const float zOffset = -2.0;
const float xOffset = 1.0; // Offset to the right to avoid Z-axis alignment

// Output color to fragment shader
layout(location = 0) out vec3 fragColor;

// Hard-coded colors for vertices
const vec3 colors[3] = vec3[](
    vec3(1.0, 0.0, 0.0),  // Red
    vec3(0.0, 1.0, 0.0),  // Green
    vec3(0.0, 0.0, 1.0)   // Blue
);

void main() {
    // Get the heap address from push constants
    uint64_t heapAddr = pushConstants.heapAddress;
    uint64_t cameraOffset = pushConstants.cameraOffset;
    debugPrintfEXT("Using heap address: 0x%llx, camera offset: 0x%llx", heapAddr, cameraOffset);
    
    // Check if heap address is valid
    if (heapAddr == 0) {
        debugPrintfEXT("ERROR: Heap address is 0, which is invalid!");
        // Use a fallback position to ensure the triangle is still visible
        gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
        fragColor = colors[gl_VertexIndex];
        return;
    }

    // Create camera buffer reference - this gives access to the viewProjection matrix
    uint64_t cameraAddr = heapAddr + cameraOffset;
    debugPrintfEXT("Camera buffer address: 0x%llx", cameraAddr);
    
    // Check if camera offset is valid
    if (cameraOffset == 0) {
        debugPrintfEXT("ERROR: Camera offset is 0, which is invalid!");
        // Use a fallback position to ensure the triangle is still visible
        gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
        fragColor = colors[gl_VertexIndex];
        return;
    }
    
    CameraBuffer cameraData = CameraBuffer(cameraAddr);

    // Get vertex position
    vec2 position = positions[gl_VertexIndex];
    debugPrintfEXT("Vertex %d: Input position = (%f, %f)", gl_VertexIndex, position.x, position.y);

    // STEP 1: Create position with proper offsets and w=1.0 (a point, not a vector)
    vec4 worldPos = vec4(position.x + xOffset, position.y, zOffset, 1.0);
    debugPrintfEXT("Vertex %d: World position = (%f, %f, %f, %f)",
                   gl_VertexIndex, worldPos.x, worldPos.y, worldPos.z, worldPos.w);

    // STEP 2: Apply view-projection matrix from camera data
    gl_Position = cameraData.viewProjection * worldPos;
    debugPrintfEXT("Vertex %d: Transformed position = (%f, %f, %f, %f)",
                   gl_VertexIndex, gl_Position.x, gl_Position.y, gl_Position.z, gl_Position.w);

    // DEBUG: Get first row of viewProjection matrix to verify it's valid
    debugPrintfEXT("First row of viewProj: [%f, %f, %f, %f]",
                  cameraData.viewProjection[0][0], cameraData.viewProjection[0][1],
                  cameraData.viewProjection[0][2], cameraData.viewProjection[0][3]);
                  
    // Check if the viewProjection matrix is valid (not all zeros)
    bool matrixValid = false;
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            if (cameraData.viewProjection[i][j] != 0.0) {
                matrixValid = true;
                break;
            }
        }
        if (matrixValid) break;
    }
    
    if (!matrixValid) {
        debugPrintfEXT("ERROR: View-projection matrix is all zeros!");
        // Use a fallback position to ensure the triangle is still visible
        gl_Position = vec4(position.x, position.y, 0.0, 1.0);
    }

    // Just print a simple debug message to confirm shader execution
    if (gl_VertexIndex == 0) {
        debugPrintfEXT("Simplified triangle shader is running!");
    }

    // Pass color to fragment shader
    fragColor = colors[gl_VertexIndex];
}
