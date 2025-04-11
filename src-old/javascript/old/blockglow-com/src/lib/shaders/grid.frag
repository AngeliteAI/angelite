uniform vec2 mousePos;
uniform vec3 baseColor;
uniform vec3 activeColor;
uniform float influenceRadius;
uniform vec2 resolution;

varying vec2 vPosition;
varying float vTime;

void main() {
    // Calculate distance from fragment to mouse position
    float dist = length(mousePos - vPosition);

    // Calculate inner and outer radius for the glow effect
    float innerRadius = influenceRadius * 0.5;
    float outerRadius = influenceRadius * 2.0;

    // Smooth influence falloff
    float influence = smoothstep(outerRadius, innerRadius, dist);
    influence *= (1.0 - smoothstep(innerRadius * 0.1, innerRadius, dist));

    // Add subtle pulse animation
    float pulse = sin(vTime * 2.0 + dist * 0.003) * 0.1 + 0.9;
    influence *= pulse;

    // Calculate box vignette
    float maxDim = max(resolution.x, resolution.y);
    vec2 normalizedPos = vPosition / (maxDim * 0.5); // Normalize based on
    vec2 vignettePos = abs(normalizedPos);
    float edgeWidth = 0.2; // Controls the width of the fade
    float edgeSharpness = 2.0; // Controls the sharpness of the fade

    // Create box falloff using max of x and y distances
    float boxDist = max(vignettePos.x, vignettePos.y);
    float vignette = 1.0 - smoothstep(1.0 - edgeWidth, 1.0, pow(boxDist, edgeSharpness));

    // Mix colors based on influence
    vec3 color = mix(baseColor, activeColor, influence);

    // Apply box vignette
    color *= vignette;

    gl_FragColor = vec4(color, 1.0);
}
