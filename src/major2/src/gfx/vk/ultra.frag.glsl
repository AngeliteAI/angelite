#version 450

// Inputs from vertex shader
layout(location = 0) in vec3 fragPosition;
layout(location = 1) in vec3 fragNormal;
layout(location = 2) in vec4 fragColor;

// Output color
layout(location = 0) out vec4 outColor;

void main() {
    // Simple lighting calculation
    vec3 lightDir = normalize(vec3(1.0, 1.0, 1.0));
    vec3 normal = normalize(fragNormal);

    // Calculate diffuse lighting (with ambient component)
    float diffuse = max(dot(normal, lightDir), 0.2);

    // Apply lighting to color
    outColor = vec4(fragColor.rgb * diffuse, fragColor.a);
}
