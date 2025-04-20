#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_atomic_float : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_debug_printf : enable
#extension GL_EXT_shader_atomic_int64 : require

#define MAX_GEN 8
#define CHUNK_SIZE 8
#define REGION_SIZE 8
#define MAX_PALETTE_SIZE 256
#define HEIGHTMAP_POINTS_PER_CHUNK 64  // 8x8 voxels per chunk
#define TOTAL_HEIGHTMAP_POINTS 4096     // 64 points per chunk * 64 chunks

struct Quad {
    uvec3 a;
    uvec3 b;
    uvec3 c;
    uvec3 d;
};

layout(push_constant) uniform PushConstants {
    uint64_t heapAddress; // Device address of the heap
    uint64_t regionOffset;
    uint64_t heightmapOffset;
} pushConstants;

layout(buffer_reference, scalar, align = 4) buffer RegionRef {
    uint64_t chunkOffsets[512];
};

layout(buffer_reference, scalar, align = 4) buffer ChunkRef {
    uint64_t countPalette;
    uint64_t offsetPalette;
    uint64_t offsetCompressed;
};

layout(buffer_reference, scalar, align = 4) buffer HeightmapRef {
    // We'll use the same memory location for both phases
    // Phase 0: Store height mask as uint
    // Phase 1: Reinterpret as float for height value
    uint heights[TOTAL_HEIGHTMAP_POINTS];
};

layout(buffer_reference, scalar, align = 4) buffer CompressedDataRef {
    uint64_t data[];
};

layout(buffer_reference, scalar, align = 4) buffer PaletteRef {
    uint64_t entries[];
};

// Use a specialization constant to determine which phase we're in
layout(constant_id = 0) const uint PHASE = 0; // 0 = palette creation, 1 = data compression

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Helper function to get chunk reference
ChunkRef getChunkRef(RegionRef region, uint chunkIndex) {
    return ChunkRef(region.chunkOffsets[chunkIndex]);
}

// Helper function to calculate heightmap index
uint calculateHeightmapIndex(uvec3 threadPos) {
    // Calculate region and chunk indices
    uvec3 regionPos = threadPos / CHUNK_SIZE;
    uvec3 localPos = threadPos % CHUNK_SIZE;
    
    // Calculate chunk index within region
    uint chunkIndex = regionPos.x + REGION_SIZE * (regionPos.y + REGION_SIZE * regionPos.z);
    
    // Calculate local index within chunk (in XY plane)
    uint localIndex = localPos.x + CHUNK_SIZE * localPos.y;
    
    // Calculate global heightmap index
    return chunkIndex * HEIGHTMAP_POINTS_PER_CHUNK + localIndex;
}

void tessellateHeightmap() {
    // Get buffer references
    RegionRef regionRef = RegionRef(pushConstants.heapAddress + pushConstants.regionOffset);
    HeightmapRef heightmapRef = HeightmapRef(pushConstants.heapAddress + pushConstants.heightmapOffset);

    // Only process XY plane (z=0)
    if (gl_GlobalInvocationID.z > 0) {
        return;
    }
    
    // Get thread identification
    uvec2 threadId = gl_LocalInvocationID.xy;
    uint threadIndex = threadId.x + threadId.y * gl_WorkGroupSize.x;
    
    // Check if we're within the total number of heightmap points
    if (threadIndex >= TOTAL_HEIGHTMAP_POINTS) {
        return;
    }
    
    // Calculate position in heightmap
    uint heightMapIndex = threadIndex;
    
    // Add memory barrier before reading height mask
    memoryBarrierBuffer();
    
    // Read the height mask
    uint heightMask = heightmapRef.heights[heightMapIndex];
    
    // Find the highest non-air block (position of most significant bit)
    int height = 0;
    if (heightMask != 0) {
        height = findLSB(heightMask);
        // Limit debug prints to reduce overhead
        if (threadIndex % 1024 == 0) {
            debugPrintfEXT("Tessellate: Thread %u - HeightMask: 0x%x MSB: %d\n", 
                          threadIndex, heightMask, height);
        }
    }
    
    // Convert the height to a float and reinterpret the bits as a uint
    // The height value represents the Y-coordinate of the highest non-air block
    float heightFloat = float(height);
    uint heightBits = floatBitsToUint(heightFloat);
    
    // Add memory barrier before writing
    memoryBarrierBuffer();
    
    // Write the height value
    heightmapRef.heights[heightMapIndex] = heightBits;
    
    // Add memory barrier after writing
    memoryBarrierBuffer();
    
    // Limit debug prints to reduce overhead
    if (threadIndex % 1024 == 0) {
        debugPrintfEXT("Tessellate: Thread %u - Final height (Y): %d (bits: 0x%x)\n", 
                       threadIndex, height, heightBits);
    }
}

void maskHeightmapColumns() {
    // Get buffer references
    RegionRef regionRef = RegionRef(pushConstants.heapAddress + pushConstants.regionOffset);
    HeightmapRef heightmapRef = HeightmapRef(pushConstants.heapAddress + pushConstants.heightmapOffset);
    
    // Get thread position
    uvec3 threadPos = gl_GlobalInvocationID.xyz;
    
    // Calculate thread index for debug prints
    uint threadIndex = threadPos.x + 64 * (threadPos.y + 64 * threadPos.z);
    
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
    
    // Get chunk reference
    ChunkRef chunkRef = getChunkRef(regionRef, chunkIndex);
    
    // Add memory barrier before reading palette count
    memoryBarrierBuffer();
    
    // Get palette count
    uint64_t paletteCount = chunkRef.countPalette;
    
    // If palette count is 0, this is an empty chunk - skip
    if (paletteCount == 0) {
        // Debug print for empty chunks (limited to reduce output)
        if (threadIndex % 1024 == 0) {
            debugPrintfEXT("MaskHeightmap: Empty chunk at region (%u,%u,%u), chunk %u\n", 
                          regionPos.x, regionPos.y, regionPos.z, chunkIndex);
        }
        return;
    }
    
    // Get references to the palette and compressed data
    PaletteRef paletteRef = PaletteRef(pushConstants.heapAddress + chunkRef.offsetPalette);
    CompressedDataRef compressedRef = CompressedDataRef(pushConstants.heapAddress + chunkRef.offsetCompressed);
    
    // Calculate the block index within the chunk
    uint blockIndex = localPos.x + CHUNK_SIZE * (localPos.y + CHUNK_SIZE * localPos.z);
    
    // Calculate how many bits are needed for palette indices
    uint bits = max(1u, uint(ceil(log2(float(paletteCount)))));
    
    // Calculate bit positions for this voxel's palette index
    uint bitCursor = blockIndex * bits;
    uint wordOffset = bitCursor / 64;
    uint bitOffset = bitCursor % 64;
    
    // Create mask for the bits we need
    uint64_t mask = (uint64_t(1u) << bits) - uint64_t(1u);
    
    // Read the palette index from compressed data
    uint64_t paletteIndex = 0;
    if (bits <= (64 - bitOffset)) {
        // Case 1: Palette index fits in a single word
        paletteIndex = (compressedRef.data[wordOffset] >> bitOffset) & mask;
    } else {
        // Case 2: Palette index spans two words
        uint bitsInCurrent = 64 - bitOffset;
        uint bitsInNext = bits - bitsInCurrent;
        
        // Get lower bits from current word
        uint64_t part1 = compressedRef.data[wordOffset] >> bitOffset;
        
        // Get upper bits from next word
        uint64_t part2 = compressedRef.data[wordOffset + 1] & ((uint64_t(1u) << bitsInNext) - uint64_t(1u));
        
        // Combine the parts
        paletteIndex = part1 | (part2 << bitsInCurrent);
        // Apply final mask to ensure we don't have extra bits
        paletteIndex &= mask;
    }
    
    // Get the actual block ID from the palette
    uint64_t blockID = paletteRef.entries[uint(paletteIndex)];
    
    // If the block is not air (blockID != 0), set the corresponding bit in the heightmap mask
    if (blockID != 0) {
        // Calculate the heightmap index for this column (x,y position)
        uint heightMapIndex = calculateHeightmapIndex(uvec3(threadPos.xy, 0));
        
        // Add memory barrier before atomic operation
        memoryBarrierBuffer();
        
        // Set the bit corresponding to this block's height
        uint bitMask = 1u << threadPos.z;
        
        // Use atomicOr to set the bit
        uint oldValue = atomicOr(heightmapRef.heights[heightMapIndex], bitMask);
        
        // Add memory barrier after atomic operation
        memoryBarrierBuffer();
        
        // Debug print for non-air blocks (limited to reduce output)
            debugPrintfEXT("MaskHeightmap: Non-air block at pos (%u,%u,%u) - BlockID: %llu, Height: %u, OldMask: 0x%x, NewMask: 0x%x\n", 
                          threadPos.x, threadPos.y, threadPos.z, blockID, threadPos.z, oldValue, oldValue | bitMask);
    }
}

void main() {
    // Add a global memory barrier at the start of each shader invocation
    memoryBarrier();
    
    if (PHASE == 0) {
        maskHeightmapColumns();
    } else {
        tessellateHeightmap();
    }
    
    // Add a global memory barrier at the end of each shader invocation
    memoryBarrier();
}