#version 450

// Vertex shader inputs (from vertex buffer) - one vertex per greedy mesh face
layout(location = 0) in vec3 inPosition;    // Bottom-left corner of face
layout(location = 1) in vec2 inSize;        // Width and height of face
layout(location = 2) in uint inNormalDir;   // Face direction: 0=+X, 1=-X, 2=+Y, 3=-Y, 4=+Z, 5=-Z
layout(location = 3) in vec4 inColor;       // Face color

// Outputs to geometry shader
layout(location = 0) out vec3 facePosition;
layout(location = 1) out vec2 faceSize;
layout(location = 2) out uint faceDir;
layout(location = 3) out vec4 faceColor;

// Push constants for view and projection matrices
layout(push_constant) uniform PushConstants {
    mat4 viewMatrix;
    mat4 projMatrix;
} pushConstants;

void main() {
    // Pass data to geometry shader
    facePosition = inPosition;
    faceSize = inSize;
    faceDir = inNormalDir;
    faceColor = inColor;
    
    // Pass position through (geometry shader will generate quad)
    gl_Position = vec4(inPosition, 1.0);
}