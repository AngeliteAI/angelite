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
#define HEIGHTMAP_POINTS_PER_CHUNK 64  // 8x8 grid per chunk
#define GRID_SIZE uint(64)


layout(push_constant, scalar) uniform PushConstants {
    uint64_t heapAddress; // Device address of the heap
    uint64_t regionOffset;
} pushConstants;

layout(buffer_reference, scalar) buffer RegionRef {
    uint64_t offsetBitmap;  // Heightmap offset
    uint64_t offsetMesh;    // Mesh data offset
    uint64_t faceCount;     // Number of faces
    uint64_t chunkOffsets[512];
};

layout(buffer_reference, scalar) buffer ChunkRef {
    uint64_t countPalette;
    uint64_t offsetPalette;
    uint64_t offsetCompressed;
};

layout(buffer_reference, scalar) buffer BitmapRef {
    uint64_t data[3][4096];  // 8x8 grid of floats
};

layout(buffer_reference, scalar) buffer HeapBufferRef {
    uint64_t data[];
};


// Use a specialization constant to determine which phase we're in
layout(constant_id = 0) const uint PHASE = 0; // 0 = palette creation, 1 = data compression

layout(local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

// Helper function to get chunk reference
ChunkRef getChunkRef(RegionRef region, uint chunkIndex) {
    return ChunkRef(pushConstants.heapAddress + region.chunkOffsets[chunkIndex]);
}

// Helper function to calculate heightmap index
uint calculateHeightmapIndex(uvec2 threadPos) {
    // Calculate region and chunk indices
    uint x = clamp(threadPos.x, 0, GRID_SIZE - 1);
    uint y = clamp(threadPos.y, 0, GRID_SIZE - 1);
    
    // Use the same index calculation as in 070_generate_heightmap.glsl
    return x + y * GRID_SIZE;
}

void tessellateHeightmap() {
    // Get buffer references
    RegionRef regionRef = RegionRef(pushConstants.heapAddress + pushConstants.regionOffset);
    BitmapRef bitmapRef = BitmapRef(pushConstants.heapAddress + regionRef.offsetBitmap);
}

uvec3 columnCoords(uvec3 threadPos, uint off) {
    uvec3 axisPos = uvec3(0);
        for(int i = 0; i < 3; i++) {
            axisPos[(i + off) % 3] = threadPos[i];
        }
    return axisPos;
}



void maskColumnAxis(BitmapRef bitmapRef, uvec3 threadPos, uint off) {
    uvec3 axisPos = columnCoords(threadPos, off);
    uint index = calculateHeightmapIndex(axisPos.xy);
    
    // Bounds check to ensure we're within valid range
    if (index >= 4096) {
        return;
    }
    
    // Create a bit mask for this specific height - use 64-bit value
    // Ensure axisPos.z is within valid range for bit shifting (0-63)
    if (axisPos.z >= 64) {
        return;
    }
    
    uint64_t bitMask = (uint64_t(1u) << uint64_t(axisPos.z));
    
    // Add memory barrier before atomic operation
    memoryBarrierBuffer();
    
    // Use atomicOr to set the bit with proper alignment
    // This ensures we record all non-air blocks in each column
    uint64_t oldValue = atomicOr(bitmapRef.data[off][uint(index)], bitMask);

    // Add memory barrier after atomic operation
    memoryBarrierBuffer();
}

void maskHeightmapColumns() {
    // Get buffer references
    RegionRef regionRef = RegionRef(pushConstants.heapAddress + pushConstants.regionOffset);
    BitmapRef bitmapRef = BitmapRef(pushConstants.heapAddress + regionRef.offsetBitmap);
    
    // Get thread position in global coordinates
    uvec3 threadPos = gl_GlobalInvocationID.xyz;
    
    // Calculate thread index for debug prints
    uint64_t threadIndex = uint64_t(threadPos.x + 64 * (threadPos.y + 64 * threadPos.z));
    
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
    uint64_t chunkIndex = uint64_t(regionPos.x + REGION_SIZE * (regionPos.y + REGION_SIZE * regionPos.z));
    
    // Bounds check for chunk index
    if (chunkIndex >= 512) {
        return;
    }
    
    // Only debug print for the first column (x=0)
    bool shouldDebug = (threadPos.x == 0);
    
    // Get chunk reference
    ChunkRef chunkRef = getChunkRef(regionRef, uint(chunkIndex));
    
    // Add memory barrier before reading palette count
    memoryBarrierBuffer();
    
    // Get palette count
    uint64_t paletteCount = chunkRef.countPalette;
    
    // Get references to the palette and compressed data
    HeapBufferRef paletteRef = HeapBufferRef(pushConstants.heapAddress + chunkRef.offsetPalette);
    HeapBufferRef compressedRef = HeapBufferRef(pushConstants.heapAddress + chunkRef.offsetCompressed);
    
    // Calculate the block index within the chunk
    uint64_t blockIndex = uint64_t(localPos.x + CHUNK_SIZE * (localPos.y + CHUNK_SIZE * localPos.z));
    
    uint64_t paletteIndex = 0;
    if(paletteCount > 1) {
        // Calculate how many bits are needed for palette indices
        // Ensure we don't overflow with 64-bit shifts
        uint bits = uint(ceil(log2(float(paletteCount))));
        
        // Safety check - ensure bits is reasonable
        if (bits > 32) {
            bits = 32; // Limit to a reasonable value
        }
        
        // Calculate bit positions for this voxel's palette index
        uint64_t bitCursor = blockIndex * uint64_t(bits);
        uint64_t wordOffset = bitCursor / 64;
        uint64_t bitOffset = bitCursor % 64;
        
        // Bounds check for compressed data access
        if (wordOffset >= 512 * 512) {
            return;
        }
        
        // Create mask for the bits we need
        uint64_t mask = (uint64_t(1u) << bits) - uint64_t(1u);
        
        // Read the palette index from compressed data
        if (bits <= (64 - bitOffset)) {
            // Case 1: Palette index fits in a single word
            // Calculate the offset in the heap buffer (in uint64_t units)
            uint heapOffset = uint(wordOffset);
            
            paletteIndex = (compressedRef.data[heapOffset] >> bitOffset) & mask;
        } else {
            // Case 2: Palette index spans two words
            uint bitsInCurrent = 64 - uint(bitOffset);
            uint bitsInNext = bits - bitsInCurrent;
            
            // Calculate offsets in the heap buffer (in uint64_t units)
            uint heapOffset1 = uint(wordOffset);
            uint heapOffset2 = heapOffset1 + 1;
            
            // Bounds check for compressed data access
            if (heapOffset2 >= 512 * 512) {
                return;
            }
            
            // Get lower bits from current word
            uint64_t part1 = compressedRef.data[heapOffset1] >> bitOffset;
            
            // Get upper bits from next word
            uint64_t part2 = compressedRef.data[heapOffset2] & ((uint64_t(1u) << bitsInNext) - uint64_t(1u));
            
            // Combine the parts
            paletteIndex = part1 | (part2 << bitsInCurrent);
            
            // Apply final mask to ensure we don't have extra bits
            paletteIndex &= mask;
        }
    }

    if(paletteCount == 1) {
        paletteIndex = 0;
    }
    
    // Bounds check for palette access
    if (paletteIndex >= MAX_PALETTE_SIZE || paletteIndex >= paletteCount) {
        return;
    }
    
    // Get the block ID from the palette
    uint64_t blockID = 0;
    if(paletteIndex < paletteCount) {
        blockID = paletteRef.data[uint(paletteIndex)];
    }

    // If the block is not air (blockID != 0), set the corresponding bit in the heightmap mask
    if (blockID != 0) {
        for(int i = 0; i < 3; i++) {
            maskColumnAxis(bitmapRef, threadPos, i);
        }
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