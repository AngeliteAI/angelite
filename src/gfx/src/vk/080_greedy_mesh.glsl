#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_atomic_float : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_debug_printf : enable
#extension GL_EXT_shader_atomic_int64 : require
#extension GL_KHR_shader_subgroup_ballot : require
#extension GL_KHR_shader_subgroup_arithmetic : require
#extension GL_KHR_shader_subgroup_basic : require
#extension GL_KHR_shader_subgroup_vote : require

// Specify SPIR-V version 1.3

#define MAX_GEN 8
#define CHUNK_SIZE 8
#define REGION_SIZE 8
#define MAX_PALETTE_SIZE 256
#define HEIGHTMAP_POINTS_PER_CHUNK 64  // 8x8 grid per chunk
#define GRID_SIZE uint(64)

layout(push_constant, scalar) uniform PushConstants {
    uint64_t heapAddress; // Device address of the heap
    uint64_t regionOffset;
    uint64_t faceTrackingOffset; // Offset to face tracking buffer
} pushConstants;

layout(buffer_reference, scalar) buffer RegionRef {
    uint64_t offsetBitmap;  // New field for heightmap offset
    uint64_t offsetMesh;
    uint64_t faceCount;
    uint64_t chunkOffsets[512];
};

layout(buffer_reference, scalar) buffer ChunkRef {
    uint64_t countPalette;
    uint64_t offsetPalette;
    uint64_t offsetCompressed;
};

layout(buffer_reference, scalar) buffer BitmapRef {
    uint64_t x[4096];  // 64x64 grid of floats, each column bit represents presense of a block
    uint64_t y[4096];  // 64x64 grid of floats, each column bit represents presense of a block
    uint64_t z[4096];  // 64x64 grid of floats, each column bit represents presense of a block
};

layout(buffer_reference, scalar) buffer HeapBufferRef {
    uint64_t data[];
};

// Face tracking buffer to prevent duplicate processing
layout(buffer_reference, scalar) buffer FaceTrackingRef {
    uint64_t processedFaces[3][4096];  // [axis][index] to track processed faces
};

// Use a specialization constant to determine which phase we're in
layout(constant_id = 0) const uint AXIS = 0; 

struct Quad {
    uvec2 size;
    uvec2 position;
    uint axis;     // Axis normal 0 = -X, 1 = +X, 2 = -Y, 3 = +Y, 4 = -Z, 5 = +Z
    uint material; // Material ID
};

void emitQuad(Quad quad) {
    RegionRef regionRef = RegionRef(pushConstants.heapAddress + pushConstants.regionOffset);
    uint64_t faceCount = atomicAdd(regionRef.faceCount, 1);
    HeapBufferRef meshRef = HeapBufferRef(pushConstants.heapAddress + regionRef.offsetMesh);

    #define QUAD_SIZEOF 6
    uint64_t slot = faceCount * QUAD_SIZEOF;

    // Ensure we don't exceed the buffer size
    if (slot + QUAD_SIZEOF > 0xFFFFFFFF) {
        return;
    }

    meshRef.data[uint(slot)] = uint64_t(quad.position.x);
    meshRef.data[uint(slot + 1)] = uint64_t(quad.position.y);
    meshRef.data[uint(slot + 2)] = uint64_t(quad.size.x);
    meshRef.data[uint(slot + 3)] = uint64_t(quad.size.y);
    meshRef.data[uint(slot + 4)] = uint64_t(quad.axis);
    meshRef.data[uint(slot + 5)] = uint64_t(quad.material);
    
    // Add memory barrier after writing to the mesh buffer
    memoryBarrierBuffer();
}

int findLSB64(uint64_t value) {
    uint lowBits = uint(value);
    if (lowBits != 0) {
        return findLSB(lowBits);
    }
    
    uint highBits = uint(value >> 32);
    if(highBits != 0) {
        return 32 + findLSB(highBits);
    }

    return -1;
}

// Function to get bitmap slice for a specific axis and position
uint64_t getBitmapSlice(BitmapRef bitmap, uint axis, uvec2 orthogonal) {
    // For each axis, we need to select the bitmap that represents the orthogonal plane
    switch (axis) {
        case 0: // X-axis: use the Z bitmap (YZ plane)
            // For the X axis, orthogonal.x is Y and orthogonal.y is Z
            return bitmap.x[orthogonal.x + orthogonal.y * GRID_SIZE];
        case 1: // Y-axis: use the X bitmap (XZ plane)
            // For the Y axis, orthogonal.x is X and orthogonal.y is Z
            return bitmap.y[orthogonal.x + orthogonal.y * GRID_SIZE];
        case 2: // Z-axis: use the Y bitmap (XY plane)
            // For the Z axis, orthogonal.x is X and orthogonal.y is Y
            return bitmap.z[orthogonal.x + orthogonal.y * GRID_SIZE];
    }
    return 0; // Unreachable
}

// Calculate face mask based on the Rust implementation
uint64_t calculateFaceMask(uint64_t slice, uint axis, uint dims, bool isPositive) {
    if (isPositive) {
        // For positive faces (right, top, front), find where solid meets air in the positive direction
        return slice & ~(slice >> 1);
    } else {
        // For negative faces (left, bottom, back), find where solid meets air in the negative direction
        return slice & ~(slice << 1);
    }
}

// Function to check if a face has been processed globally
bool isFaceProcessed(FaceTrackingRef tracking, uint axis, uint index, uint primary) {
    uint64_t mask = tracking.processedFaces[axis][index];
    return (mask & (uint64_t(1) << primary)) != 0;
}

// Function to mark a face as processed globally
void markFaceProcessed(FaceTrackingRef tracking, uint axis, uint index, uint primary) {
    // Use atomicOr to set the bit with proper alignment
    atomicOr(tracking.processedFaces[axis][index], uint64_t(1) << primary);
    
    // Add memory barrier after atomic operation
    memoryBarrierBuffer();
}

uvec3 columnCoords(uvec3 threadPos, uint off) {
    uvec3 axisPos = uvec3(0);
        for(int i = 0; i < 3; i++) {
            axisPos[(i + off) % 3] = threadPos[i];
        }
    return axisPos;
}

// Simple face mesh implementation
void simpleFaceMesh(BitmapRef bitmapRef, uint axis, bool isPositive) {
    uvec3 global = uvec3(gl_GlobalInvocationID.xyz);
    
    // Map global coordinates to the 2D orthogonal plane based on the current axis
    uvec2 globalUV = uvec2(0);
    
    // Map to the orthogonal plane: for axis=0, use (Y,Z); for axis=1, use (X,Z); for axis=2, use (X,Y)
    for(uint i = 0; i < 2; i++) {
        uint orthoAxis = (axis + 1 + i) % 3;
        globalUV[i] = global[orthoAxis];
    }
    
    // Check if position is within grid bounds
    if (globalUV.x >= GRID_SIZE || globalUV.y >= GRID_SIZE) {
        return;
    }
    
    // Get the bitmap slice for this position
    uint64_t currentSlice = getBitmapSlice(bitmapRef, axis, globalUV);
    
    // Calculate face mask based on the simple face mesh logic
    uint64_t faceMask = calculateFaceMask(currentSlice, axis, GRID_SIZE, isPositive);
    
    // No faces to process
    if(faceMask == 0) {
        return;
    }
    
    // Get reference to global face tracking
    FaceTrackingRef globalTracking = FaceTrackingRef(pushConstants.heapAddress + pushConstants.faceTrackingOffset);
    
    // Calculate global index for face tracking
    uint globalIndex = globalUV.x + globalUV.y * GRID_SIZE;
    
    // Process each bit in the face mask
    while(faceMask != 0) {
        // Find the position of the first set bit
        int primary = findLSB64(faceMask);
        
        // Check if face has been processed globally
        if (!isFaceProcessed(globalTracking, axis, globalIndex, primary)) {
            // Mark as processed globally
            markFaceProcessed(globalTracking, axis, globalIndex, primary);
            
            // Convert internal axis (0-2) to the 0-5 convention for the Quad structure
            uint quadAxis;
            if (axis == 0) {
                quadAxis = isPositive ? 1 : 0;
            } else if (axis == 1) {
                quadAxis = isPositive ? 3 : 2;
            } else if (axis == 2) {
                quadAxis = isPositive ? 5 : 4;
            } else {
                quadAxis = 0;
            }
            
            // Create a single-face quad
            Quad quad;
            quad.position = globalUV;
            quad.size = uvec2(1, 1); // Simple face is 1x1
            quad.axis = quadAxis;
            quad.material = 0xFF; // Default material
            
            // Emit the quad
            emitQuad(quad);
        }
        
        // Clear the bit we just processed
        faceMask &= ~(uint64_t(1) << primary);
    }
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

void main() {
    // Get the heap address from push constants
    uint64_t heapAddr = pushConstants.heapAddress;
    uint64_t regionOffset = pushConstants.regionOffset;
    RegionRef regionRef = RegionRef(heapAddr + regionOffset);
    BitmapRef bitmapRef = BitmapRef(heapAddr + regionRef.offsetBitmap);

    uvec3 threadPos = uvec3(gl_GlobalInvocationID.xyz);
    uvec3 axisPos = columnCoords(threadPos, AXIS);

    // Process all three axes to ensure we capture all faces in the volume
    for(int d = 0; d < 3; d++) {
        // Process both positive and negative faces for each axis
        for (int i = 0; i < 2; i++) {
            bool isPositive = i == 0;
            
            // Process the current axis and face direction with simple face meshing
            simpleFaceMesh(bitmapRef, uint(d), isPositive);
            
            // Ensure all threads complete processing the current face direction before moving to the next
            barrier();
        }
    }
}
