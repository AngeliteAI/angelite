#version 450
#include "000_chunk.glsl"

#define MAX_GEN 8
#define HEAP_BITS 32
#define CHUNK_SIZE 8
#define MAX_PALETTE_SIZE 256

// Use a specialization constant to determine which phase we're in
layout(constant_id = 0) const uint PHASE = 0; // 0 = palette creation, 1 = data compression

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

layout(set = 0, binding = 0) buffer HeapBuffer {
    uint heap[];
};

layout(set = 0, binding = 1) buffer MetadataHeapOffsets {
    uint metadataHeapOffsets[];
};

// Standard GLSL entry point that will call the appropriate phase
void main() {
    if (PHASE == 0) {
        createPalette();
    } else {
        compressData();
    }
}

// Phase 1: Create the palette of unique block types
void createPalette() {
    // Get global thread index
    uvec3 threadPos = gl_GlobalInvocationID.xyz;

    // Check if we're within chunk bounds
    if (any(greaterThanEqual(threadPos, uvec3(CHUNK_SIZE)))) {
        return;
    }

    // Get metadata heap offset
    uint metadataHeapOffset = metadataHeapOffsets[0];
    uint offsetPalette = heap[metadataHeapOffset + 1]; // Metadata.offsetPalette
    uint offsetRaw = heap[metadataHeapOffset + 3]; // Metadata.offsetRaw

    // Calculate thread index within chunk
    uint index = threadPos.x + CHUNK_SIZE * (threadPos.y + CHUNK_SIZE * threadPos.z);

    // Get the block ID from raw data
    uint blockID = heap[offsetRaw + index];

    // -------------------------------
    // STEP 1: Palette Creation
    // -------------------------------
    uint paletteIndex = 0;
    bool found = false;
    bool added = false;

    // Keep trying until we've either found the blockID or added it to the palette
    while (!added) {
        // Get current palette count
        uint currentCount = atomicOr(heap[metadataHeapOffset + 5], 0); // Non-destructive read with atomicOr

        // Check if blockID is already in the palette
        for (uint i = 0; i < currentCount; i++) {
            if (heap[offsetPalette + i] == blockID) {
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
            uint originalCount = atomicCompSwap(
                heap[metadataHeapOffset + 5],  // countPalette address
                currentCount,                  // expected value
                currentCount + 1               // new value
            );

            if (originalCount == currentCount) {
                // Our CAS succeeded - we reserved palette[currentCount]
                heap[offsetPalette + currentCount] = blockID;
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

    // Check if we're within chunk bounds
    if (any(greaterThanEqual(threadPos, uvec3(CHUNK_SIZE)))) {
        return;
    }

    // Get metadata heap offset
    uint metadataHeapOffset = metadataHeapOffsets[0];
    uint offsetPalette = heap[metadataHeapOffset + 1]; // Metadata.offsetPalette
    uint offsetCompressed = heap[metadataHeapOffset + 2]; // Metadata.offsetCompressed
    uint offsetRaw = heap[metadataHeapOffset + 3]; // Metadata.offsetRaw

    // Calculate thread index within chunk
    uint index = threadPos.x + CHUNK_SIZE * (threadPos.y + CHUNK_SIZE * threadPos.z);

    // Get the block ID from raw data
    uint blockID = heap[offsetRaw + index];
    
    // Find this block ID in the palette to get its index
    uint paletteIndex = 0;
    uint countPalette = atomicOr(heap[metadataHeapOffset + 5], 0);
    bool found = false;
    
    for (uint i = 0; i < countPalette; i++) {
        if (heap[offsetPalette + i] == blockID) {
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
    uint bitCursor = index * bits;
    uint wordOffset = bitCursor / HEAP_BITS;
    uint bitOffset = bitCursor % HEAP_BITS;

    // Create mask for the bits we need
    uint mask = (1u << bits) - 1u;

    if (bits <= (HEAP_BITS - bitOffset)) {
        // Case 1: Palette index fits in a single word
        uint oldVal, newVal;
        bool success = false;

        while (!success) {
            // Read current value
            oldVal = atomicOr(heap[offsetCompressed + wordOffset], 0);

            // Clear bits and set new bits
            newVal = (oldVal & ~(mask << bitOffset)) | ((paletteIndex & mask) << bitOffset);

            // Try to update
            uint result = atomicCompSwap(
                heap[offsetCompressed + wordOffset],
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
        uint maskCurrent = (1u << bitsInCurrent) - 1u;
        uint maskNext = (1u << bitsInNext) - 1u;

        // Process first word
        uint oldVal1, newVal1;
        bool success1 = false;

        while (!success1) {
            oldVal1 = atomicOr(heap[offsetCompressed + wordOffset], 0);
            newVal1 = (oldVal1 & ~(maskCurrent << bitOffset)) |
                      ((paletteIndex & maskCurrent) << bitOffset);

            uint result = atomicCompSwap(
                heap[offsetCompressed + wordOffset],
                oldVal1,
                newVal1
            );

            success1 = (result == oldVal1);
        }

        // Process second word
        uint oldVal2, newVal2;
        bool success2 = false;

        while (!success2) {
            oldVal2 = atomicOr(heap[offsetCompressed + wordOffset + 1], 0);
            newVal2 = (oldVal2 & ~maskNext) | ((paletteIndex >> bitsInCurrent) & maskNext);

            uint result = atomicCompSwap(
                heap[offsetCompressed + wordOffset + 1],
                oldVal2,
                newVal2
            );

            success2 = (result == oldVal2);
        }
    }
}
