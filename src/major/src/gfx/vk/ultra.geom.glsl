#version 450

// Geometry shader: Points -> Triangle strips (quads)
layout(points) in;
layout(triangle_strip, max_vertices = 4) out;

// Inputs from vertex shader
layout(location = 0) in vec3 voxelCenter[];
layout(location = 1) in uint faceDir[];
layout(location = 2) in vec4 voxelColor[];

// Outputs to fragment shader
layout(location = 0) out vec3 fragPosition;
layout(location = 1) out vec3 fragNormal;
layout(location = 2) out vec4 fragColor;

// Push constants for view and projection matrices
layout(push_constant) uniform PushConstants {
    mat4 viewMatrix;
    mat4 projMatrix;
} pushConstants;

void main() {
    vec3 center = voxelCenter[0];
    uint dir = faceDir[0];
    vec4 color = voxelColor[0];
    
    // Define face normals and tangent vectors
    vec3 normal;
    vec3 right;
    vec3 up;
    
    float voxelSize = 0.5; // Half-size of voxel
    
    // Calculate face normal and tangent vectors based on direction
    if (dir == 0u) {        // +X face
        normal = vec3(1.0, 0.0, 0.0);
        right = vec3(0.0, 0.0, 1.0);
        up = vec3(0.0, 1.0, 0.0);
    } else if (dir == 1u) { // -X face
        normal = vec3(-1.0, 0.0, 0.0);
        right = vec3(0.0, 0.0, -1.0);
        up = vec3(0.0, 1.0, 0.0);
    } else if (dir == 2u) { // +Y face
        normal = vec3(0.0, 1.0, 0.0);
        right = vec3(1.0, 0.0, 0.0);
        up = vec3(0.0, 0.0, 1.0);
    } else if (dir == 3u) { // -Y face
        normal = vec3(0.0, -1.0, 0.0);
        right = vec3(1.0, 0.0, 0.0);
        up = vec3(0.0, 0.0, -1.0);
    } else if (dir == 4u) { // +Z face
        normal = vec3(0.0, 0.0, 1.0);
        right = vec3(1.0, 0.0, 0.0);
        up = vec3(0.0, 1.0, 0.0);
    } else {                // -Z face (dir == 5u)
        normal = vec3(0.0, 0.0, -1.0);
        right = vec3(-1.0, 0.0, 0.0);
        up = vec3(0.0, 1.0, 0.0);
    }
    
    // Calculate the face center (offset from voxel center by normal * voxelSize)
    vec3 faceCenter = center + normal * voxelSize;
    
    // Generate 4 vertices for the quad (triangle strip order)
    vec3 positions[4];
    positions[0] = faceCenter - right * voxelSize - up * voxelSize; // Bottom-left
    positions[1] = faceCenter + right * voxelSize - up * voxelSize; // Bottom-right
    positions[2] = faceCenter - right * voxelSize + up * voxelSize; // Top-left
    positions[3] = faceCenter + right * voxelSize + up * voxelSize; // Top-right
    
    // Emit vertices in triangle strip order
    for (int i = 0; i < 4; i++) {
        fragPosition = positions[i];
        fragNormal = normal;
        fragColor = color;
        
        gl_Position = pushConstants.projMatrix * pushConstants.viewMatrix * vec4(positions[i], 1.0);
        EmitVertex();
    }
    
    EndPrimitive();
}