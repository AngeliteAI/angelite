#include <metal_stdlib>
#include <metal_atomic>
using namespace metal;

#define MAX_GEN 8 
#define HEAP_BITS 32
#define CHUNK_SIZE 8
#define heap_t uint32_t

struct Camera {
    float4x4 viewProjection;
};

struct Face {
    bool valid;
    uint3 position;
    uint faceDir;
    uint blockID;
};

struct Metadata {
    uint32_t state;
    uint32_t offsetPalette;
    uint32_t offsetCompressed;
    uint32_t offsetRaw;
    uint32_t offsetMesh;
    uint32_t countPalette;
    atomic_uint countFaces;
    uint32_t sizeRawMaxBytes;
    uint32_t meshValid;
    uint32_t padding;
};

struct Terrain {
    float heightScale;
    float heightOffset;
    float squishingFactor;
    uint32_t seed;
    uint2 worldOffset;
};

struct Noise {
    uint32_t dataHeapOffset;
    uint32_t seed;
    uint32_t octaves;
    float amplitude;
    float frequency;
    float persistence;
    float lacunarity;
    float3 offset; // 3D offset
    uint3 dimensions; // 3D dimensions
    float padding; // Reduced padding to maintain alignment
};

uint hash( uint x ) {
    x += ( x << 10u );
    x ^= ( x >>  6u );
    x += ( x <<  3u );
    x ^= ( x >> 11u );
    x += ( x << 15u );
    return x;
}

uint hash( uint2 v ) { return hash( v.x ^ hash(v.y) ); }
uint hash( uint3 v ) { return hash( v.x ^ hash(v.y) ^ hash(v.z) ); }
uint hash( uint4 v ) { return hash( v.x ^ hash(v.y) ^ hash(v.z) ^ hash(v.w) ); }

float3 hash(float3 p, uint32_t seed) {
    uint3 q = uint3(p);
    uint3 h = uint3(
        hash(q.x ^ seed),
        hash(q.y ^ seed),
        hash(q.z ^ seed)
    );
    // Convert to floats in range [-1, 1]
    // Reinterpret bits to create floats in [-1,1] range
    // Create values in [1,2) range by setting exponent bits
    uint3 floatBits = (h & 0x007FFFFF) | 0x3F800000;
    // Convert bits to float and map from [1,2) to [-1,1)
    return as_type<float3>(floatBits) * 2.0f - 3.0f;
}

// Add a hash function for uint3 with seed
uint hashWithSeed(uint3 v, uint32_t seed) {
    return hash(v.x ^ seed) ^ hash(v.y ^ seed) ^ hash(v.z ^ seed);
}

uint32_t getPaletteValue(
    device const heap_t* heap,
    device const Metadata* metadata,
    uint32_t indexPalette
) {
    uint32_t offsetPalette = metadata->offsetPalette;
    uint32_t countPalette = metadata->countPalette;
    uint32_t offsetCompressed = metadata->offsetCompressed;

    device const uint32_t* palette = heap + offsetPalette;
    device const uint32_t* data = heap + offsetCompressed;

    if (countPalette == 0) {
        return 0;
    }

    if (countPalette == 1) {
        return palette[0];
    }

    uint32_t bits = max(1u, uint32_t(ceil(log2(float(countPalette)))));

    uint32_t bitCursor = indexPalette * bits;

    uint32_t outerOffset = bitCursor / HEAP_BITS;
    uint32_t innerOffset = bitCursor % HEAP_BITS;

    uint32_t paletteIndex = 0;
    uint32_t remainingBits = HEAP_BITS - innerOffset; 
    
    uint32_t mask = (1ULL << bits) - 1ULL;

    if (bits <= remainingBits) {
        paletteIndex = (data[outerOffset] >> innerOffset) & mask;

    } else {
        uint32_t bitsInCurrent = remainingBits;
        uint32_t bitsInNext = bits - bitsInCurrent;
        
        // Get lower bits from current uint64
        uint32_t part1 = data[outerOffset] >> innerOffset;
        
        // Get upper bits from next uint64
        uint32_t part2 = data[outerOffset + 1] & ((1ULL << bitsInNext) - 1);
        
        // Fixed combination logic - ensure proper bit alignment
        paletteIndex = part1 | (part2 << bitsInCurrent);
        // Apply final mask to ensure we don't have extra bits
        paletteIndex &= mask;
    }

    return palette[paletteIndex];
}

constant int3 faceNormals[6] = {
    int3(-1, 0, 0),  // -X
    int3(1, 0, 0),   // +X
    int3(0, -1, 0),  // -Y
    int3(0, 1, 0),   // +Y
    int3(0, 0, -1),  // -Z
    int3(0, 0, 1)    // +Z
};

bool isFaceVisible(
    device const heap_t* heap,
    device const Metadata* metadata,
    uint3 position,
    uint direction
) {
    int3 directionVector = faceNormals[direction]; 
    int3 neighbor = int3(position) + directionVector;
    if (neighbor.x < 0 || neighbor.x >= CHUNK_SIZE ||
        neighbor.y < 0 || neighbor.y >= CHUNK_SIZE ||
        neighbor.z < 0 || neighbor.z >= CHUNK_SIZE) {
        return false;
    }
    const uint indexPalette = neighbor.x + CHUNK_SIZE * (neighbor.y + neighbor.z * CHUNK_SIZE);
    const uint neighborBlockId = getPaletteValue(
        heap,
        metadata,
        indexPalette
    );
    return neighborBlockId == 0;
}

template<typename FaceProcessor>
void processVisibleFaces(
    device const heap_t* heap,
    device const Metadata* metadata,
    uint3 position,
    FaceProcessor processor
) {
    // Skip if this voxel is empty (air)
    const uint indexPalette = position.x + CHUNK_SIZE * (position.y + position.z * CHUNK_SIZE);
    const uint blockID = getPaletteValue(heap, metadata, indexPalette);
    const bool isSolid = blockID != 0;

    if (!isSolid) {
        return;
    } 
    
    // Check each face direction
    for (uint faceDir = 0; faceDir < 6; faceDir++) {
        // Check if face is visible
        if (isFaceVisible(heap, metadata, position, faceDir)) {
            // Call the processor with the face info
            processor(position, faceDir, blockID);
        }
    }
}


// Fade function for smooth interpolation
float fade(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Improved gradient function for Perlin noise
float3 gradientVector(uint hash, float3 p) {
    // Use a switch case to select one of 12 gradient directions
    switch(hash & 15) {
        case 0:  return float3(1, 1, 0);
        case 1:  return float3(-1, 1, 0);
        case 2:  return float3(1, -1, 0);
        case 3:  return float3(-1, -1, 0);
        case 4:  return float3(1, 0, 1);
        case 5:  return float3(-1, 0, 1);
        case 6:  return float3(1, 0, -1);
        case 7:  return float3(-1, 0, -1);
        case 8:  return float3(0, 1, 1);
        case 9:  return float3(0, -1, 1);
        case 10: return float3(0, 1, -1);
        case 11: return float3(0, -1, -1);
        case 12: return float3(1, 1, 0);
        case 13: return float3(-1, 1, 0);
        case 14: return float3(0, -1, 1);
        case 15: return float3(0, -1, -1);
    }
    return float3(0); // Should never happen
}

// Improved Perlin noise function
float perlinNoise3D(float3 p, uint32_t seed) {
    float3 i = floor(p);
    float3 f = fract(p);
    
    // Better fade function application
    float3 u = float3(fade(f.x), fade(f.y), fade(f.z));
    
    // Get hash values for the 8 cube corners
    uint h000 = hashWithSeed(uint3(i) + uint3(0,0,0), seed);
    uint h100 = hashWithSeed(uint3(i) + uint3(1,0,0), seed);
    uint h010 = hashWithSeed(uint3(i) + uint3(0,1,0), seed);
    uint h110 = hashWithSeed(uint3(i) + uint3(1,1,0), seed);
    uint h001 = hashWithSeed(uint3(i) + uint3(0,0,1), seed);
    uint h101 = hashWithSeed(uint3(i) + uint3(1,0,1), seed);
    uint h011 = hashWithSeed(uint3(i) + uint3(0,1,1), seed);
    uint h111 = hashWithSeed(uint3(i) + uint3(1,1,1), seed);
    
    // Get gradient vectors and calculate dot products with distance vectors
    float n000 = dot(gradientVector(h000, f - float3(0,0,0)), f - float3(0,0,0));
    float n100 = dot(gradientVector(h100, f - float3(1,0,0)), f - float3(1,0,0));
    float n010 = dot(gradientVector(h010, f - float3(0,1,0)), f - float3(0,1,0));
    float n110 = dot(gradientVector(h110, f - float3(1,1,0)), f - float3(1,1,0));
    float n001 = dot(gradientVector(h001, f - float3(0,0,1)), f - float3(0,0,1));
    float n101 = dot(gradientVector(h101, f - float3(1,0,1)), f - float3(1,0,1));
    float n011 = dot(gradientVector(h011, f - float3(0,1,1)), f - float3(0,1,1));
    float n111 = dot(gradientVector(h111, f - float3(1,1,1)), f - float3(1,1,1));
    
    // Trilinear interpolation
    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);
    
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    
    // Final interpolation along z
    return 0.5 * mix(nxy0, nxy1, u.z) + 0.5; // Scale to [0, 1] range
}

kernel void generateNoiseTexture(
    device heap_t* heap [[buffer(0)]],
    device const uint32_t* noiseHeapOffsets [[buffer(1)]],
    uint3 threadgroupPosition [[threadgroup_position_in_grid]],
    uint3 threadgroupsPerGrid [[threadgroups_per_grid]],
    uint3 threadPosition [[thread_position_in_threadgroup]],
    uint3 threads_per_threadgroup [[threads_per_threadgroup]]
) {
    const uint32_t noiseHeapOffset = noiseHeapOffsets[0];
    device const Noise* noiseParam = (device const Noise*)(heap + noiseHeapOffset);
    
    // Get dimensions from the noise parameters
    uint3 textureDimensions = noiseParam->dimensions;
    
    // Calculate base position for this thread
    uint3 basePos = threadgroupPosition * threads_per_threadgroup + threadPosition;
    
    // Calculate how many noise values each thread must process in each dimension
    uint3 valuesPerThread = (textureDimensions + threadgroupsPerGrid * threads_per_threadgroup - 1) / 
                           (threadgroupsPerGrid * threads_per_threadgroup);
    
    // Get destination in heap for noise data
    device float* noiseData = (device float*)(heap + noiseParam->dataHeapOffset);
    
    for (uint i = 0; i < valuesPerThread.x; i++) {
        for (uint j = 0; j < valuesPerThread.y; j++) {
            for (uint k = 0; k < valuesPerThread.z; k++) {
                uint3 localPos = basePos + uint3(i, j, k) * (threadgroupsPerGrid * threads_per_threadgroup);
                
                // Skip if outside dimensions
                if (any(localPos >= textureDimensions)) {
                    continue;
                }
                
                // Calculate normalized coordinates
                float3 normalizedPos = float3(localPos) / float3(textureDimensions);
                
                // Scale to appropriate frequency range
                float3 noiseInput = normalizedPos * noiseParam->frequency;
                
                // Apply initial offset
                noiseInput += noiseParam->offset;
                
                // Compute improved fbm noise
                float fbm = 0.0;
                float currentAmplitude = noiseParam->amplitude;
                float currentFrequency = 1.0;
                float normalizer = 0.0;
                
                for(uint octave = 0; octave < noiseParam->octaves; octave++) {
                    float3 noisePos = noiseInput * currentFrequency;
                    fbm += currentAmplitude * perlinNoise3D(noisePos, noiseParam->seed + octave);
                    normalizer += currentAmplitude;
                    currentAmplitude *= noiseParam->persistence;
                    currentFrequency *= noiseParam->lacunarity;
                }
                
                // Normalize the result
                fbm /= normalizer;
                
                // Calculate 1D index from 3D position
                uint index = localPos.x + textureDimensions.x * (localPos.y + textureDimensions.y * localPos.z);
                
                // Write to heap instead of texture
                noiseData[index] = fbm;
            }
        }
    }
}

kernel void generateTerrainVoxelData(
    device heap_t* heap [[buffer(0)]],
    device const uint32_t* metadataHeapOffsets [[buffer(1)]],
    device const uint32_t* noiseHeapOffsets [[buffer(2)]],
    device const uint32_t* terrainHeapOffsets [[buffer(3)]],
    uint3 threadgroupPosition [[threadgroup_position_in_grid]],
    uint3 threadgroupsPerGrid [[threadgroups_per_grid]],
    uint3 threadPosition [[thread_position_in_threadgroup]],
    uint3 threads_per_threadgroup [[threads_per_threadgroup]]
) {
    const uint32_t terrainHeapOffset = terrainHeapOffsets[0];
    device const Terrain* terrainParam = (device const Terrain*)(heap + terrainHeapOffset);

    const uint32_t noiseHeapOffset = noiseHeapOffsets[0];
    device const Noise* noiseParam = (device const Noise*)(heap + noiseHeapOffset);

    const uint32_t metadataHeapOffset = metadataHeapOffsets[0];
    device Metadata* metadata = (device Metadata*)(heap + metadataHeapOffset);

    // Calculate base position for this thread
    uint3 basePos = threadgroupPosition * threads_per_threadgroup + threadPosition;
    
    // Get dimensions from the noise parameters
    uint3 textureDimensions = noiseParam->dimensions;
    
    // Calculate how many noise values each thread must process in each dimension
    uint3 valuesPerThread = (textureDimensions + threadgroupsPerGrid * threads_per_threadgroup - 1) / 
                           (threadgroupsPerGrid * threads_per_threadgroup);

    // Get access to the noise data
    device const float* noiseData = (device const float*)(heap + noiseParam->dataHeapOffset);

    // Process all assigned noise values
    for (uint i = 0; i < valuesPerThread.x; i++) {
        for (uint j = 0; j < valuesPerThread.y; j++) {
            for (uint k = 0; k < valuesPerThread.z; k++) {
                uint3 localPos = basePos + uint3(i, j, k) * (threadgroupsPerGrid * threads_per_threadgroup);
                
                // Skip if outside dimensions
                if (any(localPos >= textureDimensions)) {
                    continue;
                }
                
                // Calculate normalized coordinates
                float3 normalizedPos = float3(localPos) / float3(textureDimensions);
                
                // Calculate 1D index from 3D position to get the noise value from heap
                uint index = localPos.x + textureDimensions.x * (localPos.y + textureDimensions.y * localPos.z);
                float noiseValue = noiseData[index];
                
                // Calculate base terrain height
                float terrainHeight = terrainParam->heightScale * noiseValue + terrainParam->heightOffset;
                
                // Apply squishing factor to Z coordinate to compress the terrain vertically
                float squashedZ = float(localPos.z) * terrainParam->squishingFactor;
                
                // FIXED: Use the actual terrain height calculation instead of hardcoded value
                bool solid = squashedZ < terrainHeight;

                uint terrainValue = solid ? 1 : 0;

                if(solid) {
                    // Set the uncompressed terrain value, do not compress, that is done later
                    uint32_t offsetRaw = metadata->offsetRaw;
                    device uint32_t* rawData = (device uint32_t*)(heap + offsetRaw);
                    uint rawIndex = localPos.x + CHUNK_SIZE * (localPos.y + CHUNK_SIZE * localPos.z);
                    rawData[rawIndex] = terrainValue;
                }
            }
        }
    }
}

kernel void compressVoxelCreatePalette(
    device heap_t* heap [[buffer(0)]],
    device const uint32_t* metadataHeapOffsets [[buffer(1)]],
    uint3 threadPosition [[thread_position_in_grid]]
) {
    const uint32_t metadataHeapOffset = metadataHeapOffsets[0];
    device Metadata* metadata = (device Metadata*)(heap + metadataHeapOffset);
    
    // Initialize palette only in the first thread
    if (all(threadPosition == uint3(0, 0, 0))) {
        uint32_t offsetPalette = metadata->offsetPalette;
        device uint32_t* palette = (device uint32_t*)(heap + offsetPalette);

        // Initialize the first palette entry as air (0)
        palette[0] = 0;
        
        // Reset palette count to 1 (air is always the first entry)
        atomic_store_explicit(
            (device atomic_uint*)&metadata->countPalette, 
            1, 
            memory_order_relaxed
        );
    }
    
    // Wait for initialization to complete
    threadgroup_barrier(mem_flags::mem_device);
    
    // Calculate index for this thread
    uint index = threadPosition.x + CHUNK_SIZE * (threadPosition.y + CHUNK_SIZE * threadPosition.z);
    
    // Skip if outside chunk bounds
    if (any(threadPosition >= uint3(CHUNK_SIZE))) {
        return;
    }
    
    // Get the block ID from raw data for this position
    uint32_t offsetRaw = metadata->offsetRaw;
    device const uint32_t* rawData = (device const uint32_t*)(heap + offsetRaw);
    uint32_t blockID = rawData[index];
    
    // Skip air blocks (already in palette at index 0)
    if (blockID == 0) {
        return;
    }
    
    uint32_t offsetPalette = metadata->offsetPalette;
    device uint32_t* palette = (device uint32_t*)(heap + offsetPalette);
    
    // Loop until we either find the block or add it to the palette
    bool added = false;
    while (!added) {
        // Get current palette count
        uint currentCount = atomic_load_explicit(
            (device atomic_uint*)&metadata->countPalette, 
            memory_order_relaxed
        );
        
        // Check if this blockID is already in the palette
        bool found = false;
        for (uint j = 0; j < currentCount; j++) {
            if (palette[j] == blockID) {
                found = true;
                added = true;
                break;
            }
        }
        
        // If not found, try to add it to the palette
        if (!found) {
            // First check if we have room
            if (currentCount >= 256) { // Maximum palette size (arbitrary limit, adjust as needed)
                // Palette is full, just stop
                break;
            }
            
            // Try to reserve the next spot in the palette
            if (atomic_compare_exchange_weak_explicit(
                (device atomic_uint*)&metadata->countPalette,
                &currentCount,
                currentCount + 1,
                memory_order_relaxed,
                memory_order_relaxed)) {
                
                // We successfully incremented the count, now set the value
                palette[currentCount] = blockID;
                added = true;
            }
            // If CAS failed, another thread modified the count - loop and try again
        }
    }
}

kernel void compressVoxelRawData(
    device heap_t* heap [[buffer(0)]],
    device const uint32_t* metadataHeapOffsets [[buffer(1)]],
    uint3 threadPosition [[thread_position_in_grid]]
) {
    const uint32_t metadataHeapOffset = metadataHeapOffsets[0];
    device Metadata* metadata = (device Metadata*)(heap + metadataHeapOffset);
    
    // Calculate index for this thread
    uint index = threadPosition.x + CHUNK_SIZE * (threadPosition.y + CHUNK_SIZE * threadPosition.z);
    
    // Skip if outside chunk bounds
    if (any(threadPosition >= uint3(CHUNK_SIZE))) {
        return;
    }
    
    // Get the block ID from raw data for this position
    uint32_t offsetRaw = metadata->offsetRaw;
    device const uint32_t* rawData = (device const uint32_t*)(heap + offsetRaw);
    uint32_t blockID = rawData[index];
    
    // Skip air blocks (already in palette at index 0)
    if (blockID == 0) {
        return;
    }
    
    // Get the palette value for this blockID
    uint32_t offsetPalette = metadata->offsetPalette;
    device const uint32_t* palette = (device const uint32_t*)(heap + offsetPalette);
    
    //Get the palette index for this blockID
    uint32_t paletteIndex = 0;
    for (uint j = 0; j < metadata->countPalette; j++) {
        if (palette[j] == blockID) {
            paletteIndex = j;
            break;
        }
    }
    // Write the palette index to the raw data, atomically with bit operations if needed
    uint32_t offsetCompressed = metadata->offsetCompressed;
    device uint32_t* compressedData = (device uint32_t*)(heap + offsetCompressed);
    uint32_t compressedIndex = index / HEAP_BITS;
    uint32_t compressedBitIndex = index % HEAP_BITS;
    uint32_t mask = (1ULL << HEAP_BITS) - 1ULL;
    uint32_t compressedValue = compressedData[compressedIndex];
    //Use atomics  
    while (true) {
        uint32_t oldValue = atomic_load_explicit(
            (device atomic_uint*)&compressedData[compressedIndex],
            memory_order_relaxed
        );
        uint32_t newValue = (oldValue & ~(mask << compressedBitIndex)) | 
                            ((paletteIndex & mask) << compressedBitIndex);
        uint32_t bitsLeft = HEAP_BITS - compressedBitIndex;
        if (bitsLeft < HEAP_BITS) {
            newValue |= (compressedValue & ((1ULL << bitsLeft) - 1));

            while (true) {
                uint32_t oldValue2 = atomic_load_explicit(
                    (device atomic_uint*)&compressedData[compressedIndex + 1],
                    memory_order_relaxed
                );
                uint32_t newValue2 = (oldValue2 & mask) | 
                                     ((paletteIndex >> bitsLeft) & mask);
                if (atomic_compare_exchange_weak_explicit(
                    (device atomic_uint*)&compressedData[compressedIndex + 1],
                    &oldValue2,
                    newValue2,
                    memory_order_relaxed,
                    memory_order_relaxed)) {
                    break;
                }
            }
        }
        if (atomic_compare_exchange_weak_explicit(
            (device atomic_uint*)&compressedData[compressedIndex],
            &oldValue,
            newValue,
            memory_order_relaxed,
            memory_order_relaxed)) {
            break;
        }
    }
}

kernel void countFacesFromPalette(
    device const heap_t* heap [[buffer(0)]],
    device const uint32_t* metadataHeapOffsets [[buffer(1)]],
    uint3 threadgroupPosition [[thread_position_in_grid]],
    uint3 threadgroupsPerGrid [[threadgroups_per_grid]],
    uint3 threadPosition [[thread_position_in_threadgroup]]
) {
    const uint32_t metadataHeapOffset = metadataHeapOffsets[0];

    device  Metadata* metadata = 
        (device  Metadata*)(heap + metadataHeapOffset);
    processVisibleFaces(
        heap,
        metadata,
        threadPosition,
        [&](uint3 position, uint faceDir, uint blockID) {
            atomic_fetch_add_explicit(
                &metadata->countFaces,
                1,
                memory_order_relaxed
            );
        }
    );
}

kernel void generateMeshFromPalette(
    device const uint32_t* heap [[buffer(0)]],
    device const uint32_t* metadataHeapOffsets [[buffer(1)]],
    uint3 threadgroupPosition [[thread_position_in_grid]],
    uint3 threadgroupsPerGrid [[threadgroups_per_grid]],
    uint3 threadPosition [[thread_position_in_threadgroup]]
) {
    const uint32_t metadataHeapOffset = metadataHeapOffsets[0];

    device  Metadata* metadata = 
        (device  Metadata*)(heap + metadataHeapOffset);

    if(metadata->offsetMesh == 0) {
        return;
    }
    
    if(all(threadPosition == uint3(0))) {
        atomic_store_explicit(
            &metadata->countFaces,
            0,
            memory_order_relaxed
        ); 
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);

    processVisibleFaces(
        heap,
        metadata,
        threadPosition,
        [&](uint3 position, uint faceDir, uint blockID) {
            const uint faceIndex = atomic_fetch_add_explicit(
                &metadata->countFaces,
                1,
                memory_order_relaxed
            );

            const uint faceOffset = 4 * metadata->offsetMesh + faceIndex * sizeof(Face);
            device Face* faces = (device Face*)(((device uint8_t*)heap) + faceOffset);

            faces[faceIndex].position = position;
            faces[faceIndex].faceDir = faceDir;
            faces[faceIndex].blockID = blockID; 
            faces[faceIndex].valid = true;
        }
    );
}

kernel void cullChunks(
    device const uint32_t* heap [[buffer(0)]],
    device const uint32_t* metadataHeapOffsets [[buffer(1)]]
) {

}

kernel void generateDrawCommands(
    device const uint32_t* heap [[buffer(0)]],
    device const uint32_t* metadataHeapOffsets [[buffer(1)]]
) {

}

kernel void compactDrawCommands(
    device const uint32_t* heap [[buffer(0)]],
    device const uint32_t* metadataHeapOffsets [[buffer(1)]]
) {

}

vertex float4 vertexFaceShader(
    uint vertexID [[vertex_id]],
    device const uint32_t* heap [[buffer(1)]],
    device const uint32_t* metadataHeapOffsets [[buffer(2)]],
    device const Camera* camera [[buffer(3)]]

) {
     float2 quad[6] = {
        float2(0.0, 0.0), // triangle 1
        float2(1.0, 0.0),
        float2(0.0, 1.0),
        float2(1.0, 0.0), // triangle 2
        float2(1.0, 1.0),
        float2(0.0, 1.0)
    };
    
    uint faceIndex = vertexID / 6;
    uint faceVertex = vertexID % 6;

    uint32_t chunkIndex = 0;
    uint32_t metadataHeapOffset = metadataHeapOffsets[chunkIndex];

    device  Metadata* metadata = 
        (device  Metadata*)(heap + metadataHeapOffset);

    device Face* faces = (device Face*)(((device uint8_t*)heap) + 4 * metadata->offsetMesh);

     Face face = faces[faceIndex];
     if (!face.valid) {
        return float4(0, 0, 0, 42069);
     }
    uint3 position = face.position;
    int3 normal = faceNormals[face.faceDir];
    uint faceDir = face.faceDir;

    int3 tangent, bitangent;
    if(abs(normal.y) == 1) {
        tangent = int3(1, 0, 0);
        bitangent = int3(0, 0, normal.y > 0 ? 1 : -1);
    } else {
        // +X 
        // tangent = int3(0, 0, -1)
        // bitangent = int3(0, 1, 0)
        // -X
        // tangent = int3(0, 0, 1)
        // bitangent = int3(0, 1, 0)
        tangent = int3(normal.z, 0, -normal.x);
        bitangent = int3(0, normal.y > 0 ? 1 : -1, 0);
    }

    float2 uv = quad[faceVertex];
    float3 faceOrigin = float3(position);
    
    // For positive-facing directions, offset by 1 unit in that direction
    if (normal.x > 0) faceOrigin.x += 1.0;
    if (normal.y > 0) faceOrigin.y += 1.0;
    if (normal.z > 0) faceOrigin.z += 1.0;

    float3 vertexPos = faceOrigin;
    
    // Unified approach for all face types
    if (normal.x != 0) {  // X faces
        vertexPos.y += uv.y;
        vertexPos.z += normal.x > 0 ? (1.0 - uv.x) : uv.x;
    }
    else if (normal.y != 0) {  // Y faces
        vertexPos.x += uv.x;
        vertexPos.z += normal.y < 0 ? uv.y : (1.0 - uv.y);
    }
    else if (normal.z != 0) {  // Z faces
        vertexPos.x += normal.z < 0 ? (1.0 - uv.x) : uv.x;
        vertexPos.y += uv.y;
    }
    
    float4 worldPosition = float4(vertexPos, 1.0);
    float4 viewPosition = camera->viewProjection * worldPosition;
    
    return viewPosition;
}

fragment half4 fragmentFaceShader(
    float4 position [[position]]
) {
    return half4(1);
}
