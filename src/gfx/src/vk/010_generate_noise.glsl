#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_atomic_float : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_debug_printf : enable


// Noise context structure
layout(scalar) struct NoiseContext {
    uint64_t noiseParamOffset;
    uint64_t noiseDataOffset;
};

// Noise parameters structure
layout(scalar) struct NoiseParams {
    float seed;
    float scale;
    float frequency;
    float lacunarity;
    float persistence;
    ivec3 offset;
    uvec3 size;
};

// Print the size of the NoiseParams struct for debugging
layout(push_constant) uniform PushConstants {
    uint64_t heap_address;
    uint64_t noise_context_offset;
} pc;

// Print the size of the NoiseContext struct for debugging

layout(buffer_reference, scalar, std430) buffer FloatRef {
    float data;
};

layout(buffer_reference, scalar, std430) buffer NoiseContextRef {
    NoiseContext context;
};

// Buffer reference for the noise parameters
layout(buffer_reference, scalar, std430) buffer NoiseParamsRef {
    NoiseParams params;
};

// Buffer reference for the noise data output
layout(buffer_reference, scalar, std430) buffer NoiseDataRef {
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

// Main compute shader function
layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;
void main() {
    // Get the global invocation ID
    ivec3 pos = ivec3(gl_GlobalInvocationID);
    
    // Calculate the index in the noise data array
    uint index = pos.z * 32 * 32 + pos.y * 32 + pos.x;
    
    // Get the noise context from the heap
    uint64_t contextAddress = pc.heap_address + pc.noise_context_offset;
    debugPrintfEXT("Noise context address: 0x%llx", contextAddress);
    debugPrintfEXT("Heap address: 0x%llx, noise_context_offset: 0x%llx", pc.heap_address, pc.noise_context_offset);
    
    // Check if heap address is valid
    if (pc.heap_address == 0) {
        debugPrintfEXT("ERROR: Heap address is 0, which is invalid!");
        return;
    }
    
    NoiseContextRef noiseContextRef = NoiseContextRef(contextAddress);
    NoiseContext noiseContext = noiseContextRef.context;
    
    debugPrintfEXT("Processing noise at position: (%d, %d, %d), index: %u", pos.x, pos.y, pos.z, index);
    debugPrintfEXT("Noise context - noiseParamOffset: 0x%llx, noiseDataOffset: 0x%llx", 
        noiseContext.noiseParamOffset, noiseContext.noiseDataOffset);
    
    // Check if noise context offsets are valid
    if (noiseContext.noiseParamOffset == 0 || noiseContext.noiseDataOffset == 0) {
        debugPrintfEXT("ERROR: Invalid noise context offsets!");
        return;
    }
    
    // Get the noise parameters from the heap - ensure we're using byte addressing
    uint64_t paramAddress = pc.heap_address + noiseContext.noiseParamOffset;
    debugPrintfEXT("Noise parameters address: 0x%llx", paramAddress);
    NoiseParamsRef noiseParamsRef = NoiseParamsRef(paramAddress);
    
    // Print the raw bytes of the noise parameters for debugging
    debugPrintfEXT("Noise parameters raw bytes: %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u %u", 
        noiseParamsRef.params.seed, noiseParamsRef.params.scale, noiseParamsRef.params.frequency,
        noiseParamsRef.params.lacunarity, noiseParamsRef.params.persistence,
        noiseParamsRef.params.offset.x, noiseParamsRef.params.offset.y, noiseParamsRef.params.offset.z,
        noiseParamsRef.params.size.x, noiseParamsRef.params.size.y, noiseParamsRef.params.size.z);
    
    // Print the memory layout of the noise parameters for debugging
    debugPrintfEXT("Noise parameters memory layout: seed=%f, scale=%f, frequency=%f, lacunarity=%f, persistence=%f, offset=(%d,%d,%d), size=(%u,%u,%u)", 
        noiseParamsRef.params.seed, noiseParamsRef.params.scale, noiseParamsRef.params.frequency,
        noiseParamsRef.params.lacunarity, noiseParamsRef.params.persistence,
        noiseParamsRef.params.offset.x, noiseParamsRef.params.offset.y, noiseParamsRef.params.offset.z,
        noiseParamsRef.params.size.x, noiseParamsRef.params.size.y, noiseParamsRef.params.size.z);
    
    debugPrintfEXT("Noise parameters - Seed: %f, Scale: %f, Frequency: %f", 
        noiseParamsRef.params.seed,
        noiseParamsRef.params.scale,
        noiseParamsRef.params.frequency);
    
    // Get the noise data pointer from the heap
    uint64_t noiseDataPtr = pc.heap_address + noiseContext.noiseDataOffset;
    debugPrintfEXT("Noise data pointer: 0x%llx", noiseDataPtr);
    
    // Skip computation if outside the noise dimensions
    if (any(greaterThanEqual(pos, noiseParamsRef.params.size))) {
        debugPrintfEXT("Skipping out-of-bounds position: (%d, %d, %d)", pos.x, pos.y, pos.z);
        return;
    }

    // Calculate normalized coordinates
    vec3 normalizedPos = vec3(pos) / vec3(noiseParamsRef.params.size);

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

    // Generate noise value
    float noiseValue = fbm;
    
    debugPrintfEXT("Generated noise value: %f at position (%d, %d, %d)", noiseValue, pos.x, pos.y, pos.z);
    
    // Write the noise value to the noise data array
    FloatRef(noiseDataPtr + index * 4).data = noiseValue;
    
    // Add memory barrier to ensure the write is visible to other shaders
    memoryBarrier();
}

// Noise generation functions
float generateNoise(ivec3 pos, NoiseParams params) {
    // Apply offset and scale
    vec3 p = vec3(pos + params.offset) * params.scale;
    
    // Generate base noise
    float noise = 0.0;
    float amplitude = 1.0;
    float frequency = params.frequency;
    
    // Generate octaves of noise
    for (int i = 0; i < 4; i++) {
        noise += amplitude * perlinNoise3D(p * frequency, uint(params.seed));
        amplitude *= params.persistence;
        frequency *= params.lacunarity;
    }
    
    return noise;
}

// Perlin noise function
