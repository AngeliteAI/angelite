#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_atomic_float : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_shader_atomic_int64 : require
#extension GL_EXT_debug_printf : enable

#define MAX_GEN 8
#define HEAP_BITS 64
#define CHUNK_SIZE 8
#define REGION_SIZE 8
#define MAX_PALETTE_SIZE 256

// Use a specialization constant to determine which phase we're in
layout(constant_id = 0) const uint PHASE = 0; // 0 = palette creation, 1 = data compression

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(buffer_reference, scalar) buffer HeapBufferRef {
    uint64_t data[];
};

layout(push_constant, scalar) uniform PushConstants {
    uint64_t heapAddress;        // Device address of the heap
    uint64_t workspaceOffset; // Offset to noise context
    uint64_t regionOffset;
} pushConstants;


layout(buffer_reference, scalar) buffer WorkspaceRef {
    uint64_t offsetRaw;
    uvec3 size;
};

layout(buffer_reference, scalar) buffer RegionRef {
    uint64_t offsetBitmap;
    uint64_t chunkOffsets[512];
};

layout(buffer_reference, scalar) buffer ChunkRef {
    uint64_t countPalette;
    uint64_t offsetPalette;
    uint64_t offsetCompressed;
};

// Helper function to calculate chunk index within a region
uint calculateChunkIndex(uvec3 threadPos) {
    uvec3 regionPos = threadPos / CHUNK_SIZE;
    uvec3 localPos = threadPos % CHUNK_SIZE;
    
    // Calculate chunk index within region
    uint chunkIndex = regionPos.x + REGION_SIZE * (regionPos.y + REGION_SIZE * regionPos.z);
    
    // Calculate local index within chunk
    uint localIndex = localPos.x + CHUNK_SIZE * (localPos.y + CHUNK_SIZE * localPos.z);
    
    return chunkIndex * (CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE) + localIndex;
}

// Helper function to get chunk reference
ChunkRef getChunkRef(RegionRef region, uint chunkIndex) {
    return ChunkRef(pushConstants.heapAddress + region.chunkOffsets[chunkIndex]);
}

// Phase 1: Create the palette of unique block types
void createPalette() {
    // Get global thread index
    uvec3 threadPos = gl_GlobalInvocationID.xyz;
    
    // Debug print when x is 0
    if (threadPos.x == 0) {
        debugPrintfEXT("Phase 1 - Thread: (%d, %d, %d)\n", threadPos.x, threadPos.y, threadPos.z);
    }
    
    // Check if we're within workspace bounds (64^3)
    if (any(greaterThanEqual(threadPos, uvec3(64)))) {
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 1 - Out of bounds: (%d, %d, %d)\n", threadPos.x, threadPos.y, threadPos.z);
        }
        return;
    }
    
    // Calculate region and chunk indices
    uvec3 regionPos = threadPos / CHUNK_SIZE;
    uvec3 localPos = threadPos % CHUNK_SIZE;
    
    // Check if we're within region bounds
    if (any(greaterThanEqual(regionPos, uvec3(REGION_SIZE)))) {
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 1 - Region out of bounds: (%d, %d, %d), regionPos: (%d, %d, %d)\n", 
                          threadPos.x, threadPos.y, threadPos.z, regionPos.x, regionPos.y, regionPos.z);
        }
        return;
    }
    
    // Calculate chunk index within region
    uint chunkIndex = regionPos.x + REGION_SIZE * (regionPos.y + REGION_SIZE * regionPos.z);
    
    // Calculate local index within chunk
    uint localIndex = localPos.x + CHUNK_SIZE * (localPos.y + CHUNK_SIZE * localPos.z);
    
    // Get buffer references
    RegionRef region = RegionRef(pushConstants.heapAddress + pushConstants.regionOffset);
    WorkspaceRef workspace = WorkspaceRef(pushConstants.heapAddress + pushConstants.workspaceOffset);
    
    // Get chunk reference
    ChunkRef chunk = getChunkRef(region, chunkIndex);
    HeapBufferRef palette = HeapBufferRef(pushConstants.heapAddress + chunk.offsetPalette);
    HeapBufferRef compressed = HeapBufferRef(pushConstants.heapAddress + chunk.offsetCompressed);
    
    // Initialize palette count to 0 for the first thread in each chunk
    if (localIndex == 0) {
        // Only the first thread in each chunk should initialize the palette count
        atomicExchange(chunk.countPalette, 0);
        memoryBarrier();
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 1 - Initialized chunk palette count to 0\n");
        }
    }
    
    // Wait for all threads to reach this point, ensuring initialization is complete
    barrier();
    
    if (threadPos.x == 0) {
        debugPrintfEXT("Phase 1 - Chunk info - countPalette: %llu, offsetPalette: %llu, offsetCompressed: %llu\n", 
                      chunk.countPalette, chunk.offsetPalette, chunk.offsetCompressed);
    }
    
    // Calculate global index in workspace
    uint globalIndex = threadPos.x + 64 * (threadPos.y + 64 * threadPos.z);
    
    // Get the block ID from raw data
    HeapBufferRef rawData = HeapBufferRef(pushConstants.heapAddress + workspace.offsetRaw);
    uint64_t blockID = rawData.data[globalIndex];

    if (threadPos.x == 0) {
        debugPrintfEXT("Phase 1 - BlockID: %llu, chunkIndex: %u, localIndex: %u, globalIndex: %u\n", 
                      blockID, chunkIndex, localIndex, globalIndex);
    }

    // Ensure all threads in workgroup have loaded their block IDs before proceeding
    barrier();

    // -------------------------------
    // STEP 1: Palette Creation
    // -------------------------------
    uint64_t paletteIndex = 0;
    bool found = false;
    bool added = false;

    // Keep trying until we've either found the blockID or added it to the palette
    while (!added) {
        // Get current palette count - use a memory barrier to ensure all threads see the most recent count
        memoryBarrier();
        uint64_t currentCount = atomicOr(chunk.countPalette, 0);
        memoryBarrier();

        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 1 - Current palette count: %llu\n", currentCount);
        }

        // Check if blockID is already in the palette
        for (uint64_t i = 0; i < currentCount; i++) {
            if (palette.data[uint(i)] == blockID) {
                paletteIndex = i;
                found = true;
                added = true;
                if (threadPos.x == 0) {
                    debugPrintfEXT("Phase 1 - Found blockID at palette index: %llu\n", i);
                }
                break;
            }
        }

        // If found, we're done with palette creation
        if (found) {
            break;
        }

        // Not found, try to add it
        if (currentCount < MAX_PALETTE_SIZE) {
            // Try to atomically increment the count
            uint64_t originalCount = atomicCompSwap(
                chunk.countPalette,
                currentCount,          // expected value
                currentCount + 1       // new value
            );

            if (originalCount == currentCount) {
                // Our CAS succeeded - we reserved palette[currentCount]
                palette.data[uint(currentCount)] = blockID;
                memoryBarrier();
                paletteIndex = currentCount;
                added = true;
                if (threadPos.x == 0) {
                    debugPrintfEXT("Phase 1 - Added blockID to palette at index: %llu\n", currentCount);
                }
            }
            // If CAS failed, another thread modified count - we'll loop and try again
        } else {
            // Palette is full
            // Just use the first entry as fallback (this is a limitation)
            paletteIndex = 0;
            added = true;
            if (threadPos.x == 0) {
                debugPrintfEXT("Phase 1 - Palette full, using fallback index 0\n");
            }
        }
        
        // Add a workgroup barrier to ensure all threads see the updated palette
        barrier();
    }
}

// Phase 2: Compress the voxel data using the palette indices
void compressData() {
    // Get global thread index
    uvec3 threadPos = gl_GlobalInvocationID.xyz;
    
    // Debug print when x is 0
    if (threadPos.x == 0) {
        debugPrintfEXT("Phase 2 - Thread: (%d, %d, %d)\n", threadPos.x, threadPos.y, threadPos.z);
    }
    
    // Check if we're within workspace bounds (64^3)
    if (any(greaterThanEqual(threadPos, uvec3(64)))) {
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 2 - Out of bounds: (%d, %d, %d)\n", threadPos.x, threadPos.y, threadPos.z);
        }
        return;
    }
    
    // Calculate region and chunk indices
    uvec3 regionPos = threadPos / CHUNK_SIZE;
    uvec3 localPos = threadPos % CHUNK_SIZE;
    
    // Check if we're within region bounds
    if (any(greaterThanEqual(regionPos, uvec3(REGION_SIZE)))) {
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 2 - Region out of bounds: (%d, %d, %d), regionPos: (%d, %d, %d)\n", 
                          threadPos.x, threadPos.y, threadPos.z, regionPos.x, regionPos.y, regionPos.z);
        }
        return;
    }
    
    // Calculate chunk index within region
    uint chunkIndex = regionPos.x + REGION_SIZE * (regionPos.y + REGION_SIZE * regionPos.z);
    
    // Calculate local index within chunk
    uint localIndex = localPos.x + CHUNK_SIZE * (localPos.y + CHUNK_SIZE * localPos.z);
    
    // Get buffer references
    RegionRef region = RegionRef(pushConstants.heapAddress + pushConstants.regionOffset);
    WorkspaceRef workspace = WorkspaceRef(pushConstants.heapAddress + pushConstants.workspaceOffset);
    
    // Get chunk reference
    ChunkRef chunk = getChunkRef(region, chunkIndex);
    HeapBufferRef palette = HeapBufferRef(pushConstants.heapAddress + chunk.offsetPalette);
    HeapBufferRef compressed = HeapBufferRef(pushConstants.heapAddress + chunk.offsetCompressed);
    
    if (threadPos.x == 0) {
        debugPrintfEXT("Phase 2 - Chunk info - countPalette: %llu, offsetPalette: %llu, offsetCompressed: %llu\n", 
                      chunk.countPalette, chunk.offsetPalette, chunk.offsetCompressed);
    }
    
    // Calculate global index in workspace
    uint globalIndex = threadPos.x + 64 * (threadPos.y + 64 * threadPos.z);
    
    // Get the block ID from raw data
    HeapBufferRef rawData = HeapBufferRef(pushConstants.heapAddress + workspace.offsetRaw);
    uint64_t blockID = rawData.data[globalIndex];
    
    if (threadPos.x == 0) {
        debugPrintfEXT("Phase 2 - BlockID: %llu, chunkIndex: %u, localIndex: %u, globalIndex: %u\n", 
                      blockID, chunkIndex, localIndex, globalIndex);
    }
    
    // Find this block ID in the palette to get its index
    uint64_t paletteIndex = 0;
    uint64_t countPalette = atomicOr(chunk.countPalette, 0);
    if (countPalette <= 1) {
        return;
    }
    bool found = false;
    
    if (threadPos.x == 0) {
        debugPrintfEXT("Phase 2 - Palette count: %llu\n", countPalette);
    }
    
    for (uint64_t i = 0; i < countPalette; i++) {
        if (palette.data[uint(i)] == blockID && palette.data[uint(i)] != 0xDEADBEEF) {
            paletteIndex = i;
            found = true;
            if (threadPos.x == 0) {
                debugPrintfEXT("Phase 2 - Found blockID at palette index: %llu\n", i);
            }
            break;
        }
    }
    
    // If not found, use 0 as fallback
    if (!found) {
        paletteIndex = 0;
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 2 - BlockID not found in palette, using fallback index 0\n");
        }
    }

    // Calculate how many bits are needed for palette indices
    uint bits = uint(ceil(log2(float(countPalette))));
    
    if (threadPos.x == 0) {
        debugPrintfEXT("Phase 2 - Bits needed for palette indices: %u\n", bits);
    }

    // Calculate bit positions for this voxel's palette index
    uint bitCursor = localIndex * bits;
    uint wordOffset = bitCursor / HEAP_BITS;
    uint bitOffset = bitCursor % HEAP_BITS;
    
    if (threadPos.x == 0) {
        debugPrintfEXT("Phase 2 - Bit cursor: %u, word offset: %u, bit offset: %u\n", 
                      bitCursor, wordOffset, bitOffset);
    }

    // Create mask for the bits we need
    uint64_t mask = (uint64_t(1u) << bits) - uint64_t(1u);

    if (bits <= (HEAP_BITS - bitOffset)) {
        // Case 1: Palette index fits in a single word
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 2 - Case 1: Palette index fits in a single word\n");
        }

        // Calculate the offset in the heap buffer (in uint64_t units)
        uint heapOffset = uint(chunk.offsetCompressed / 8) + wordOffset;
        
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 2 - Heap offset: %u\n", heapOffset);
        }
        
        // Create a mask with 1s in the positions we want to set
        uint64_t setMask = (paletteIndex & mask) << bitOffset;
        
        // Use atomicOr to set the bits
        atomicOr(compressed.data[wordOffset], setMask);
        
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 2 - Successfully wrote palette index to compressed data using atomicOr\n");
        }
    } else {
        // Case 2: Palette index spans two words
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 2 - Case 2: Palette index spans two words\n");
        }
        
        uint bitsInCurrent = HEAP_BITS - bitOffset;
        uint bitsInNext = bits - bitsInCurrent;

        // Create masks for each part
        uint64_t maskCurrent = (uint64_t(1u) << bitsInCurrent) - uint64_t(1u);
        uint64_t maskNext = (uint64_t(1u) << bitsInNext) - uint64_t(1u);
        
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 2 - Bits in current word: %u, bits in next word: %u\n", 
                          bitsInCurrent, bitsInNext);
        }

        // Calculate offsets in the heap buffer (in uint64_t units)
        uint heapOffset1 = uint(chunk.offsetCompressed / 8) + wordOffset;
        uint heapOffset2 = heapOffset1 + 1;
        
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 2 - Heap offset1: %u, heap offset2: %u\n", 
                          heapOffset1, heapOffset2);
        }
        
        // Process first word
        uint64_t setMask1 = (paletteIndex & maskCurrent) << bitOffset;
        
        // Use atomicOr for the first word
        atomicOr(compressed.data[wordOffset], setMask1);
        
        // Process second word
        uint64_t setMask2 = ((paletteIndex >> bitsInCurrent) & maskNext);
        
        // Use atomicOr for the second word
        atomicOr(compressed.data[wordOffset + 1], setMask2);
        
        if (threadPos.x == 0) {
            debugPrintfEXT("Phase 2 - Successfully wrote palette index to compressed data (two words) using atomicOr\n");
        }
    }
}

void main() {
    if (PHASE == 0) {
        createPalette();
    } else {
        compressData();
    }
}