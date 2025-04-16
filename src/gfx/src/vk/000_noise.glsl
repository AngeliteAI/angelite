struct NoiseContext {
    uint64_t noiseParamOffset;
    uint64_t noiseDataOffset;
};

struct NoiseParams {
    float seed;
    float scale;
    float frequency;
    float lacunarity;
    float persistence;
    ivec3 offset;
    uvec3 size;
};
