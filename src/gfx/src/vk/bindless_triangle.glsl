#version 450
#extension GL_EXT_buffer_reference : require

// Push constant for the heap address
layout(push_constant) uniform PushConstants {
    uint64_t heapAddress;  // Device address of the heap
    mat4 modelMatrix;     // Model matrix
} pushConstants;

// Define the camera data structure as it appears in memory
layout(buffer_reference, std430) readonly buffer CameraBuffer {
    mat4 viewProjection;
    vec3 position;
    float padding;
};

// The triangle vertex positions and colors
const vec2 positions[3] = vec2[](
    vec2(0.0, -0.5),
    vec2(0.5, 0.5),
    vec2(-0.5, 0.5)
);

// Output color to fragment shader
layout(location = 0) out vec3 fragColor;

// Hard-coded colors for vertices
const vec3 colors[3] = vec3[](
    vec3(1.0, 0.0, 0.0),  // Red
    vec3(0.0, 1.0, 0.0),  // Green
    vec3(0.0, 0.0, 1.0)   // Blue
);

void main() {
    // Create a camera buffer reference from the heap address
    CameraBuffer cameraData = CameraBuffer(pushConstants.heapAddress);
    
    // Get vertex position from the hard-coded array
    vec2 position = positions[gl_VertexIndex];
    
    // Apply model matrix from push constants
    vec4 worldPos = pushConstants.modelMatrix * vec4(position, 0.0, 1.0);
    
    // Apply view-projection matrix from the camera data
    gl_Position = cameraData.viewProjection * worldPos;
    
    // Pass color to fragment shader
    fragColor = colors[gl_VertexIndex];
}