#version 450

// Geometry shader: Points -> Triangle strips (quads)
layout(points) in;
layout(triangle_strip, max_vertices = 4) out;

// Inputs from vertex shader
layout(location = 0) in vec3 facePosition[];   // Bottom-left corner of face
layout(location = 1) in vec2 faceSize[];       // Width and height of face
layout(location = 2) in uint faceDir[];        // Face direction
layout(location = 3) in vec4 faceColor[];      // Face color

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
    vec3 basePos = facePosition[0];
    vec2 size = faceSize[0];
    uint dir = faceDir[0];
    vec4 color = faceColor[0];
    
    // Define face normals and tangent vectors
    vec3 normal;
    vec3 right;
    vec3 up;
    
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
    
    // Generate 4 vertices for the quad based on face size
    vec3 positions[4];
    positions[0] = basePos;                                          // Bottom-left
    positions[1] = basePos + right * size.x;                        // Bottom-right  
    positions[2] = basePos + up * size.y;                           // Top-left
    positions[3] = basePos + right * size.x + up * size.y;          // Top-right
    
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