#version 450
#extension GL_EXT_buffer_reference : require
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

layout(buffer_reference, scalar, align = 16) buffer HeapBufferRef {
    uint64_t data[];
};

layout(push_constant) uniform PushConstants {
    uint64_t heapAddress;        // Device address of the heap
    uint64_t workspaceOffset; // Offset to noise context
    uint64_t regionOffset;
    uint64_t compressorContextOffset;
} pushConstants;


layout(buffer_reference, scalar, align = 16) buffer CompressorContextRef {
    uint64_t faceCount;
};

layout(buffer_reference, scalar, align = 16) buffer WorkspaceRef {
    uint64_t offsetRaw;
    uvec3 size;
};

layout(buffer_reference, scalar, align = 16) buffer RegionRef {
    uint64_t chunkOffsets[512];
};

layout(buffer_reference, scalar, align = 16) buffer ChunkRef {
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
    return ChunkRef(region.chunkOffsets[chunkIndex]);
}

// Phase 1: Create the palette of unique block types
void createPalette() {
    // Get global thread index
    uvec3 threadPos = gl_GlobalInvocationID.xyz;
    
    // Check if we're within workspace bounds (64^3)
    if (any(greaterThanEqual(threadPos, uvec3(64)))) {
        return;
    }
    
    // Calculate region and chunk indices
    uvec3 regionPos = threadPos / CHUNK_SIZE;
    uvec3 localPos = threadPos % CHUNK_SIZE;
    
    // Check if we're within region bounds
    if (any(greaterThanEqual(regionPos, uvec3(REGION_SIZE)))) {
        return;
    }
    
    // Calculate chunk index within region
    uint chunkIndex = regionPos.x + REGION_SIZE * (regionPos.y + REGION_SIZE * regionPos.z);
    
    // Calculate local index within chunk
    uint localIndex = localPos.x + CHUNK_SIZE * (localPos.y + CHUNK_SIZE * localPos.z);
    
    // Get buffer references
    RegionRef region = RegionRef(pushConstants.regionOffset);
    WorkspaceRef workspace = WorkspaceRef(pushConstants.workspaceOffset);
    CompressorContextRef compressor = CompressorContextRef(pushConstants.compressorContextOffset);
    HeapBufferRef heap = HeapBufferRef(pushConstants.heapAddress);
    
    // Get chunk reference
    ChunkRef chunk = getChunkRef(region, chunkIndex);
    
    // Calculate global index in workspace
    uint globalIndex = threadPos.x + 64 * (threadPos.y + 64 * threadPos.z);
    
    // Get the block ID from raw data
    uint64_t blockID = heap.data[uint(workspace.offsetRaw + globalIndex)];

    // -------------------------------
    // STEP 1: Palette Creation
    // -------------------------------
    uint64_t paletteIndex = 0;
    bool found = false;
    bool added = false;

    // Keep trying until we've either found the blockID or added it to the palette
    while (!added) {
        // Get current palette count
        uint64_t currentCount = atomicOr(chunk.countPalette, 0);

        // Check if blockID is already in the palette
        for (uint64_t i = 0; i < currentCount; i++) {
            if (heap.data[uint(chunk.offsetPalette + i)] == blockID) {
                paletteIndex = i;
                found = true;
                added = true;
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
                heap.data[uint(chunk.offsetPalette + currentCount)] = blockID;
                paletteIndex = currentCount;
                added = true;
            }
            // If CAS failed, another thread modified count - we'll loop and try again
        } else {
            // Palette is full
            // Just use the first entry as fallback (this is a limitation)
            paletteIndex = 0;
            added = true;
        }
    }
}

// Phase 2: Compress the voxel data using the palette indices
void compressData() {
    // Get global thread index
    uvec3 threadPos = gl_GlobalInvocationID.xyz;
    
    // Check if we're within workspace bounds (64^3)
    if (any(greaterThanEqual(threadPos, uvec3(64)))) {
        return;
    }
    
    // Calculate region and chunk indices
    uvec3 regionPos = threadPos / CHUNK_SIZE;
    uvec3 localPos = threadPos % CHUNK_SIZE;
    
    // Check if we're within region bounds
    if (any(greaterThanEqual(regionPos, uvec3(REGION_SIZE)))) {
        return;
    }
    
    // Calculate chunk index within region
    uint chunkIndex = regionPos.x + REGION_SIZE * (regionPos.y + REGION_SIZE * regionPos.z);
    
    // Calculate local index within chunk
    uint localIndex = localPos.x + CHUNK_SIZE * (localPos.y + CHUNK_SIZE * localPos.z);
    
    // Get buffer references
    RegionRef region = RegionRef(pushConstants.regionOffset);
    WorkspaceRef workspace = WorkspaceRef(pushConstants.workspaceOffset);
    CompressorContextRef compressor = CompressorContextRef(pushConstants.compressorContextOffset);
    HeapBufferRef heap = HeapBufferRef(pushConstants.heapAddress);
    
    // Get chunk reference
    ChunkRef chunk = getChunkRef(region, chunkIndex);
    
    // Calculate global index in workspace
    uint globalIndex = threadPos.x + 64 * (threadPos.y + 64 * threadPos.z);
    
    // Get the block ID from raw data
    uint64_t blockID = heap.data[uint(workspace.offsetRaw + globalIndex)];
    
    // Find this block ID in the palette to get its index
    uint64_t paletteIndex = 0;
    uint64_t countPalette = atomicOr(chunk.countPalette, 0);
    bool found = false;
    
    for (uint64_t i = 0; i < countPalette; i++) {
        if (heap.data[uint(chunk.offsetPalette + i)] == blockID) {
            paletteIndex = i;
            found = true;
            break;
        }
    }
    
    // If not found, use 0 as fallback
    if (!found) {
        paletteIndex = 0;
    }

    // Calculate how many bits are needed for palette indices
    uint bits = max(1u, uint(ceil(log2(float(countPalette)))));

    // Calculate bit positions for this voxel's palette index
    uint bitCursor = localIndex * bits;
    uint wordOffset = bitCursor / HEAP_BITS;
    uint bitOffset = bitCursor % HEAP_BITS;

    // Create mask for the bits we need
    uint64_t mask = (uint64_t(1u) << bits) - uint64_t(1u);

    if (bits <= (HEAP_BITS - bitOffset)) {
        // Case 1: Palette index fits in a single word
        uint64_t oldVal, newVal;
        bool success = false;

        // Ensure proper alignment for atomic operations
        uint alignedOffset = uint((chunk.offsetCompressed + wordOffset) & ~7u); // Align to 8 bytes
        uint offsetInWord = uint((chunk.offsetCompressed + wordOffset) & 7u);

        while (!success) {
            // Read current value with proper alignment
            oldVal = atomicOr(heap.data[alignedOffset], uint64_t(0));
            
            // Adjust bit offset based on alignment
            uint adjustedBitOffset = bitOffset + (offsetInWord * 8);
            
            // Clear bits and set new bits
            newVal = (oldVal & ~(mask << adjustedBitOffset)) | ((paletteIndex & mask) << adjustedBitOffset);

            // Try to update with proper alignment
            uint64_t result = atomicCompSwap(
                heap.data[alignedOffset],
                oldVal,
                newVal
            );

            success = (result == oldVal);
        }
    } else {
        // Case 2: Palette index spans two words
        uint bitsInCurrent = HEAP_BITS - bitOffset;
        uint bitsInNext = bits - bitsInCurrent;

        // Create masks for each part
        uint64_t maskCurrent = (uint64_t(1u) << bitsInCurrent) - uint64_t(1u);
        uint64_t maskNext = (uint64_t(1u) << bitsInNext) - uint64_t(1u);

        // Ensure proper alignment for first word
        uint alignedOffset1 = uint((chunk.offsetCompressed + wordOffset) & ~7u);
        uint offsetInWord1 = uint((chunk.offsetCompressed + wordOffset) & 7u);
        
        // Process first word
        uint64_t oldVal1, newVal1;
        bool success1 = false;

        while (!success1) {
            oldVal1 = atomicOr(heap.data[alignedOffset1], uint64_t(0));
            uint adjustedBitOffset1 = bitOffset + (offsetInWord1 * 8);
            newVal1 = (oldVal1 & ~(maskCurrent << adjustedBitOffset1)) |
                      ((paletteIndex & maskCurrent) << adjustedBitOffset1);

            uint64_t result = atomicCompSwap(
                heap.data[alignedOffset1],
                oldVal1,
                newVal1
            );

            success1 = (result == oldVal1);
        }

        // Ensure proper alignment for second word
        uint alignedOffset2 = uint((chunk.offsetCompressed + wordOffset + 1) & ~7u);
        uint offsetInWord2 = uint((chunk.offsetCompressed + wordOffset + 1) & 7u);
        
        // Process second word
        uint64_t oldVal2, newVal2;
        bool success2 = false;

        while (!success2) {
            oldVal2 = atomicOr(heap.data[alignedOffset2], uint64_t(0));
            uint adjustedBitOffset2 = offsetInWord2 * 8;
            newVal2 = (oldVal2 & ~maskNext) | ((paletteIndex >> bitsInCurrent) & maskNext);

            uint64_t result = atomicCompSwap(
                heap.data[alignedOffset2],
                oldVal2,
                newVal2
            );

            success2 = (result == oldVal2);
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