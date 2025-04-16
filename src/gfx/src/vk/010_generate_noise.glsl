#version 450
#extension GL_EXT_buffer_reference : require
#include "000_noise.glsl"

// Push constant for the heap address
layout(push_constant) uniform PushConstants {
    uint64_t heapAddress;  // Device address of the heap
    uint64_t noiseContextOffset;
} pushConstants;

// Buffer reference for the noise parameters
layout(buffer_reference, std430) buffer NoiseParamsRef {
    NoiseParams params;
};

// Buffer reference for the noise data output
layout(buffer_reference, std430) buffer NoiseDataRef {
    float data[];
};

// Hash function for generating random values
uint hash(uint x) {
    x += (x << 10u);
    x ^= (x >> 6u);
    x += (x << 3u);
    x ^= (x >> 11u);
    x += (x << 15u);
    return x;
}

uint hash(uvec2 v) { return hash(v.x ^ hash(v.y)); }
uint hash(uvec3 v) { return hash(v.x ^ hash(v.y) ^ hash(v.z)); }

// Hash with seed
uint hashWithSeed(uvec3 v, uint seed) {
    return hash(v.x ^ seed) ^ hash(v.y ^ seed) ^ hash(v.z ^ seed);
}

// Generate a vector for gradient calculation
vec3 gradientVector(uint hash, vec3 p) {
    // Use hash to select one of 12 gradient directions
    switch(hash & 15) {
        case 0:  return vec3(1, 1, 0);
        case 1:  return vec3(-1, 1, 0);
        case 2:  return vec3(1, -1, 0);
        case 3:  return vec3(-1, -1, 0);
        case 4:  return vec3(1, 0, 1);
        case 5:  return vec3(-1, 0, 1);
        case 6:  return vec3(1, 0, -1);
        case 7:  return vec3(-1, 0, -1);
        case 8:  return vec3(0, 1, 1);
        case 9:  return vec3(0, -1, 1);
        case 10: return vec3(0, 1, -1);
        case 11: return vec3(0, -1, -1);
        case 12: return vec3(1, 1, 0);
        case 13: return vec3(-1, 1, 0);
        case 14: return vec3(0, -1, 1);
        case 15: return vec3(0, -1, -1);
    }
    return vec3(0);
}

// Fade function for smooth interpolation
float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Perlin noise 3D implementation
float perlinNoise3D(vec3 p, uint seed) {
    vec3 i = floor(p);
    vec3 f = fract(p);

    // Improved fade function
    vec3 u = vec3(fade(f.x), fade(f.y), fade(f.z));

    // Get hash values for the 8 cube corners
    uint h000 = hashWithSeed(uvec3(i) + uvec3(0,0,0), seed);
    uint h100 = hashWithSeed(uvec3(i) + uvec3(1,0,0), seed);
    uint h010 = hashWithSeed(uvec3(i) + uvec3(0,1,0), seed);
    uint h110 = hashWithSeed(uvec3(i) + uvec3(1,1,0), seed);
    uint h001 = hashWithSeed(uvec3(i) + uvec3(0,0,1), seed);
    uint h101 = hashWithSeed(uvec3(i) + uvec3(1,0,1), seed);
    uint h011 = hashWithSeed(uvec3(i) + uvec3(0,1,1), seed);
    uint h111 = hashWithSeed(uvec3(i) + uvec3(1,1,1), seed);

    // Get gradient vectors and calculate dot products with distance vectors
    float n000 = dot(gradientVector(h000, f - vec3(0,0,0)), f - vec3(0,0,0));
    float n100 = dot(gradientVector(h100, f - vec3(1,0,0)), f - vec3(1,0,0));
    float n010 = dot(gradientVector(h010, f - vec3(0,1,0)), f - vec3(0,1,0));
    float n110 = dot(gradientVector(h110, f - vec3(1,1,0)), f - vec3(1,1,0));
    float n001 = dot(gradientVector(h001, f - vec3(0,0,1)), f - vec3(0,0,1));
    float n101 = dot(gradientVector(h101, f - vec3(1,0,1)), f - vec3(1,0,1));
    float n011 = dot(gradientVector(h011, f - vec3(0,1,1)), f - vec3(0,1,1));
    float n111 = dot(gradientVector(h111, f - vec3(1,1,1)), f - vec3(1,1,1));

    // Trilinear interpolation
    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);

    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);

    // Scale to [0, 1] range
    return 0.5 * mix(nxy0, nxy1, u.z) + 0.5;
}

// Compute shader for generating 3D noise
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
void main() {
    // Get noise context from push constants
    NoiseContext noiseContext = NoiseContext(pushConstants.heapAddress + pushConstants.noiseContextOffset);

    // Get noise parameters and output buffer
    NoiseParamsRef noiseParamsRef = NoiseParamsRef(pushConstants.heapAddress + noiseContext.noiseParamOffset);
    NoiseDataRef noiseDataRef = NoiseDataRef(pushConstants.heapAddress + noiseContext.noiseDataOffset);

    // Get local thread position
    uvec3 localPos = gl_GlobalInvocationID.xyz;

    // Skip computation if outside the noise dimensions
    if (any(greaterThanEqual(localPos, noiseParamsRef.params.size))) {
        return;
    }

    // Calculate normalized coordinates
    vec3 normalizedPos = vec3(localPos) / vec3(noiseParamsRef.params.size);

    // Apply frequency scaling
    vec3 noiseInput = normalizedPos * noiseParamsRef.params.frequency;

    // Apply offset
    noiseInput += vec3(noiseParamsRef.params.offset);

    // Generate fractional Brownian motion noise
    float fbm = 0.0;
    float currentAmplitude = noiseParamsRef.params.scale;
    float currentFrequency = 1.0;
    float normalizer = 0.0;

    // Use uint so we can add seed for each octave
    uint seedValue = uint(noiseParamsRef.params.seed);

    // Accumulate noise from multiple octaves
    for (int octave = 0; octave < 8; octave++) { // Using 8 as max octaves
        vec3 noisePos = noiseInput * currentFrequency;
        fbm += currentAmplitude * perlinNoise3D(noisePos, seedValue + uint(octave));
        normalizer += currentAmplitude;

        currentAmplitude *= noiseParamsRef.params.persistence;
        currentFrequency *= noiseParamsRef.params.lacunarity;

        // Stop if amplitude becomes negligible
        if (currentAmplitude < 0.001) break;
    }

    // Normalize the result
    fbm /= normalizer;

    // Calculate 1D index from 3D position
    uint index = localPos.x + noiseParamsRef.params.size.x *
               (localPos.y + noiseParamsRef.params.size.y * localPos.z);

    // Write the noise value to the output buffer
    noiseDataRef.data[index] = fbm;
}
