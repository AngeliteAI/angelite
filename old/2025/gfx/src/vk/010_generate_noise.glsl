#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_atomic_float : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_debug_printf : enable

// Print the size of the NoiseParams struct for debugging
layout(push_constant) uniform PushConstants {
    uint64_t heap_address;
    uint64_t noise_context_offset;
} pc;

// Print the size of the NoiseContext struct for debugging

layout(buffer_reference, scalar) buffer F32Ref {
    float data;
};

layout(buffer_reference, scalar) buffer NoiseContextRef {
    uint64_t noiseParamOffset;
    uint64_t noiseDataOffset;
};

// Buffer reference for the noise parameters
layout(buffer_reference, scalar) buffer NoiseParamsRef {
    float seed;
    float scale;
    float frequency;
    float lacunarity;
    float persistence;
    ivec3 offset;
    uvec3 size;
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

// Main compute shader function
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
void main() {
    // Get the global invocation ID
    ivec3 pos = ivec3(gl_GlobalInvocationID);
    
    // Calculate the index in the noise data array
    
    // Get the noise context from the heap
    uint64_t contextAddress = pc.heap_address + pc.noise_context_offset;
    NoiseContextRef noiseContext = NoiseContextRef(contextAddress);
    
    
    // Get the noise parameters from the heap - ensure we're using byte addressing
    uint64_t paramAddress = pc.heap_address + noiseContext.noiseParamOffset;
    NoiseParamsRef noiseParams = NoiseParamsRef(paramAddress);
    uint index = pos.z * noiseParams.size.x * noiseParams.size.y + pos.y * noiseParams.size.x + pos.x;
    
    
    // Debug print the size field components
    
    // Get the noise data pointer from the heap
    uint64_t noiseDataPtr = pc.heap_address + noiseContext.noiseDataOffset;

    // Skip computation if outside the noise dimensions
    if (false && any(greaterThanEqual(pos, noiseParams.size))) {
        return;
    }

    // Calculate normalized coordinates
    vec3 normalizedPos = vec3(pos) / vec3(noiseParams.size);

    // Apply frequency scaling
    vec3 noiseInput = normalizedPos * noiseParams.frequency;

    // Apply offset
    noiseInput += vec3(noiseParams.offset);

    // Generate fractional Brownian motion noise
    float fbm = 0.0;
    float currentAmplitude = noiseParams.scale;
    float currentFrequency = 1.0;
    float normalizer = 0.0;

    // Use uint so we can add seed for each octave
    uint seedValue = uint(noiseParams.seed);

    // Accumulate noise from multiple octaves
    for (int octave = 0; octave < 8; octave++) { // Using 8 as max octaves
        vec3 noisePos = noiseInput * currentFrequency;
        fbm += currentAmplitude * perlinNoise3D(noisePos, seedValue + uint(octave));
        normalizer += currentAmplitude;

        currentAmplitude *= noiseParams.persistence;
        currentFrequency *= noiseParams.lacunarity;

        // Stop if amplitude becomes negligible
        if (currentAmplitude < 0.001) break;
    }

    // Normalize the result
    fbm /= normalizer;

    // Generate noise value
    float noiseValue = fbm;
    
    debugPrintfEXT("Generated noise value: %f at position (%d, %d, %d)", noiseValue, pos.x, pos.y, pos.z);
    
    // Write the noise value to the noise data array
    F32Ref(noiseDataPtr + index * 4).data = noiseValue;
}
