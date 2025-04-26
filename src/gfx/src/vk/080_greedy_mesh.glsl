#version 450
#extension GL_EXT_buffer_reference : require
#extension GL_EXT_buffer_reference2 : require
#extension GL_EXT_scalar_block_layout : require
#extension GL_EXT_shader_atomic_float : require
#extension GL_ARB_gpu_shader_int64 : require
#extension GL_EXT_debug_printf : enable
#extension GL_EXT_shader_atomic_int64 : require
#extension GL_KHR_shader_subgroup_ballot : require
#extension GL_KHR_shader_subgroup_arithmetic : require
#extension GL_KHR_shader_subgroup_basic : require
#extension GL_KHR_shader_subgroup_vote : require
#extension GL_EXT_shader_explicit_arithmetic_types_int64 : enable

layout(push_constant, scalar) uniform PushConstants {
    uint64_t heapAddress; // Device address of the heap
    uint64_t regionOffset;
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
    uint64_t data[3][4096];  // 64x64 grid of floats, each column bit represents presense of a block
};

layout(buffer_reference, scalar) buffer HeapBufferRef {
    uint64_t data[];
};


struct Quad {
    uvec2 size;
    uvec3 position;
    uint axis;     // Axis normal 0 = -X, 1 = +X, 2 = -Y, 3 = +Y, 4 = -Z, 5 = +Z
    uint material; // Material ID
};

#define QUAD_SIZEOF 7  // Updated size for 3D position (x,y,z) + size (w,h) + axis + material

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

uint64_t ortho(uint axis) {
    // Calculate orthogonal axes for a given axis
    // For X axis (0,1), return Y axis (1)
    // For Y axis (2,3), return Z axis (2)
    // For Z axis (4,5), return X axis (0)
    uint baseAxis = axis % 3;
    
    switch(baseAxis) {
        case 0: return 1; // For X axis, orthogonal is Y
        case 1: return 2; // For Y axis, orthogonal is Z
        case 2: return 0; // For Z axis, orthogonal is X
    }
    
    return 0; // Default fallback
}

uint64_t faceMask(BitmapRef bitmapRef, uvec2 uv, uint axis, bool backface) {
    // Select the appropriate bitmap plane based on axis
    uint planeIndex = uint(ortho(axis));
    
    // Get the bits along the axis-aligned column at (uv.x, uv.y)
    uint64_t value = bitmapRef.data[planeIndex][uv.x + 64 * uv.y];
    
    // Determine which voxels should have visible faces
    // For front faces, we need voxels with no neighbor in front (value >> 1)
    // For back faces, we need voxels with no neighbor behind (value << 1)
    uint64_t neighbors = backface ? value << 1 : value >> 1;
    
    // A face is visible if:
    // 1. The voxel exists (bit set in value)
    // 2. The neighboring voxel doesn't exist (bit not set in neighbors)
    return value & ~neighbors;
}

uint64_t findLSB64(uint64_t value) {
    uint lower = uint(value & 0xffffffff);
    uint upper = uint(value >> 32);

    if(lower != 0) {
        return findLSB(lower);
    } else if(upper != 0) {
        return findLSB(upper) + 32;
    }

    return 0;
}

void emitQuad(Quad quad) {
    RegionRef regionRef = RegionRef(pushConstants.heapAddress + pushConstants.regionOffset);
    HeapBufferRef meshRef = HeapBufferRef(pushConstants.heapAddress + regionRef.offsetMesh);

    uint64_t slot = atomicAdd(regionRef.faceCount, 1);

    if(slot >= 100000) {
        return;
    }
    uint64_t offset = slot * QUAD_SIZEOF;

    meshRef.data[uint(offset + 0)] = quad.position.x;
    meshRef.data[uint(offset + 1)] = quad.position.y;
    meshRef.data[uint(offset + 2)] = quad.position.z;
    meshRef.data[uint(offset + 3)] = quad.size.x;
    meshRef.data[uint(offset + 4)] = quad.size.y;
    meshRef.data[uint(offset + 5)] = quad.axis;
    meshRef.data[uint(offset + 6)] = quad.material;
}

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;


void main() {
    RegionRef regionRef = RegionRef(pushConstants.heapAddress + pushConstants.regionOffset);
    BitmapRef bitmapRef = BitmapRef(pushConstants.heapAddress + regionRef.offsetBitmap);

    uvec2 uv = gl_GlobalInvocationID.xy;
    uint axis = gl_WorkGroupID.z / 2;
    bool backface = gl_WorkGroupID.z % 2 == 0;

    uint64_t mask = faceMask(bitmapRef, uv, axis, backface);
    while(mask != 0) {
        uint64_t primary = findLSB64(mask);
        uvec3 uvw = uvec3(uv, primary);

        uvec2 size = uvec2(1);

        uint material = 0;
        


        Quad quad;
        quad.position = uvw;
        quad.size = size;
        quad.axis = axis;
        quad.material = material;

        emitQuad(quad); 
        mask = mask & ~(uint64_t(1) << primary);
    }
}