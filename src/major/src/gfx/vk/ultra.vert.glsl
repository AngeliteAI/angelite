#version 450

// Vertex shader inputs (from vertex buffer) - one vertex per voxel face
layout(location = 0) in vec3 inPosition;    // Voxel center position
layout(location = 1) in uint inNormalDir;   // Face direction: 0=+X, 1=-X, 2=+Y, 3=-Y, 4=+Z, 5=-Z
layout(location = 2) in vec4 inColor;       // Face color

// Outputs to geometry shader
layout(location = 0) out vec3 voxelCenter;
layout(location = 1) out uint faceDir;
layout(location = 2) out vec4 voxelColor;

// Push constants for view and projection matrices
layout(push_constant) uniform PushConstants {
    mat4 viewMatrix;
    mat4 projMatrix;
} pushConstants;

void main() {
    // Pass data to geometry shader
    voxelCenter = inPosition;
    faceDir = inNormalDir;
    voxelColor = inColor;
    
    // Pass position through (geometry shader will generate quad)
    gl_Position = vec4(inPosition, 1.0);
}