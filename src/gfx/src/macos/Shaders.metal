#include <metal_stdlib>
#include <metal_atomic>
using namespace metal;

#define HEAP_BITS 32
#define CHUNK_SIZE 8
#define heap_t uint32_t

struct Camera {
    float4x4 viewProjection;
};

struct Face {
    uint3 position;
    uint faceDir;
    uint blockID;
};

struct Metadata {
    uint32_t state;
    uint32_t offsetPalette;
    uint32_t offsetData;
    uint32_t offsetMesh;
    uint32_t countPalette;
    atomic_uint countFaces;
    uint32_t meshValid;
    uint32_t padding;
};

uint32_t getPaletteValue(
    device const heap_t* heap  [[aligned(8)]],
    device const Metadata* metadata  [[aligned(8)]],
    uint32_t indexPalette
) {
    uint32_t offsetPalette = metadata->offsetPalette;
    uint32_t countPalette = metadata->countPalette;
    uint32_t offsetData = metadata->offsetData;

    device const uint32_t* palette = heap + offsetPalette;
    device const uint32_t* data = heap + offsetData;

    

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

kernel void countFacesFromPalette(
    device const heap_t* heap  [[buffer(0), aligned(8)]],
    device const uint32_t* heapOffsets [[buffer(1)]],
    uint3 threadgroupPosition [[thread_position_in_grid]],
    uint3 threadgroupsPerGrid [[threadgroups_per_grid]],
    uint3 threadPosition [[thread_position_in_threadgroup]]
) {
    const uint metadataIndex = threadgroupPosition.x + 
        threadgroupsPerGrid.x * 
        (threadgroupPosition.y + threadgroupPosition.z * threadgroupsPerGrid.y);

    const uint32_t heapOffsetMetadata = heapOffsets[metadataIndex];

    device  Metadata* metadata = 
        (device  Metadata*)(heap + heapOffsetMetadata);
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
const uint metadataIndex = threadgroupPosition.x + 
        threadgroupsPerGrid.x * 
        (threadgroupPosition.y + threadgroupPosition.z * threadgroupsPerGrid.y);

    const uint32_t heapOffsetMetadata = metadataHeapOffsets[metadataIndex];

    device  Metadata* metadata = 
        (device  Metadata*)(heap + heapOffsetMetadata);

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
    uint32_t heapOffsetMetadata = metadataHeapOffsets[chunkIndex];

    device  Metadata* metadata = 
        (device  Metadata*)(heap + heapOffsetMetadata);

    device Face* faces = (device Face*)(((device uint8_t*)heap) + 4 * metadata->offsetMesh);

     Face face = faces[faceIndex];
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
