#version 450

// Input from vertex shader
layout(location = 0) in vec3 fragColor;
layout(location = 1) in vec3 fragNormal;

// Output to framebuffer
layout(location = 0) out vec4 outColor;

// Simple lighting calculation
void main() {
    // Light direction (from above)
    vec3 lightDir = normalize(vec3(0.5, 1.0, 0.3));
    
    // Calculate diffuse lighting
    float diffuse = max(dot(normalize(fragNormal), lightDir), 0.0);
    
    // Ambient light
    float ambient = 0.3;
    
    // Combine lighting with color
    vec3 litColor = fragColor * (diffuse + ambient);
    
    // Output final color
    outColor = vec4(litColor, 1.0);
}
