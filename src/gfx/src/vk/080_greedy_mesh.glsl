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

// Add a global face tracking buffer to prevent duplicate processing
layout(buffer_reference, scalar) buffer FaceTrackingRef {
    uint64_t processedFaces[3][4096];  // [axis][index] to track processed faces
};

// Use a specialization constant to determine which phase we're in
layout(constant_id = 0) const uint AXIS = 0; 

uint calculateHeightmapIndex(uvec2 threadPos) {
    // Calculate region and chunk indices
    uint x = clamp(threadPos.x, 0, GRID_SIZE - 1);
    uint y = clamp(threadPos.y, 0, GRID_SIZE - 1);
    
    // Use the same index calculation as in 070_generate_heightmap.glsl
    return x + y * GRID_SIZE;
}

uvec3 columnCoords(uvec3 threadPos, uint off) {
    uvec3 axisPos = uvec3(0);
        for(int i = 0; i < 3; i++) {
            axisPos[(i + off) % 3] = threadPos[i];
        }
    return axisPos;
}

struct Quad {
    uvec3 min;    // Minimum coordinate
    uvec3 max;    // Maximum coordinate
    uint axis;     // Axis normal (0=X, 1=Y, 2=Z)
    uint material; // Material ID
};

void emitQuad(Quad quad) {
    RegionRef regionRef = RegionRef(pushConstants.heapAddress + pushConstants.regionOffset);

    uint64_t faceCount = atomicAdd(regionRef.faceCount, 1);

    // Debug print when a quad is emitted
    if (gl_LocalInvocationIndex == 0) {
        debugPrintfEXT("Emitting quad: min(%u,%u,%u) max(%u,%u,%u) axis=%u material=%u faceCount=%llu\n", 
            quad.min.x, quad.min.y, quad.min.z, 
            quad.max.x, quad.max.y, quad.max.z, 
            quad.axis, quad.material, faceCount);
    }

    HeapBufferRef meshRef = HeapBufferRef(pushConstants.heapAddress + regionRef.offsetMesh);

    #define QUAD_SIZEOF 8
    uint64_t slot = faceCount * QUAD_SIZEOF;

    meshRef.data[uint(slot)] = uint64_t(quad.min.x);
    meshRef.data[uint(slot + 1)] = uint64_t(quad.min.y);
    meshRef.data[uint(slot + 2)] = uint64_t(quad.min.z);
    meshRef.data[uint(slot + 3)] = uint64_t(quad.max.x);
    meshRef.data[uint(slot + 4)] = uint64_t(quad.max.y);
    meshRef.data[uint(slot + 5)] = uint64_t(quad.max.z);
    meshRef.data[uint(slot + 6)] = uint64_t(quad.axis);
    meshRef.data[uint(slot + 7)] = uint64_t(quad.material);
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

uint64_t getBitmapSlice(BitmapRef bitmap, uint axis, uvec2 orthogonal) {
    // For each axis, we need to select the bitmap that represents the orthogonal plane
    switch (axis) {
        case 0: // X-axis: use the Z bitmap (YZ plane)
            // For the X axis, orthogonal.x is Y and orthogonal.y is Z
            return bitmap.y[orthogonal.x + orthogonal.y * GRID_SIZE];
        case 1: // Y-axis: use the X bitmap (XZ plane)
            // For the Y axis, orthogonal.x is X and orthogonal.y is Z
            return bitmap.z[orthogonal.x + orthogonal.y * GRID_SIZE];
        case 2: // Z-axis: use the Y bitmap (XY plane)
            // For the Z axis, orthogonal.x is X and orthogonal.y is Y
            return bitmap.x[orthogonal.x + orthogonal.y * GRID_SIZE];
    }
    return 0; // Unreachable
}



shared uint64_t workgroupFaceMask[8];     // Current face mask for this workgroup
shared uint64_t workgroupProcessed[8];    // Processed bits for this workgroup
shared bool workgroupHasFaces;      
void markProcessed(uint localU, int primary) {
    atomicOr(workgroupProcessed[localU], uint64_t(1) << primary);
}

bool isProcessed(int localU, int primary) {
    return (workgroupProcessed[localU] & (uint64_t(1) << primary)) != 0;
}

// Improved face mask calculation for height field transitions
uint64_t calculateFaceMask(uint64_t slice, uint axis, uint dims) {
    uint64_t faceMask = 0;
    
    // For height fields, we need to detect transitions between different heights
    for (uint i = 0; i < dims; i++) {
        bool currentSolid = (slice & (uint64_t(1) << i)) != 0;
        
        // Only consider solid voxels for face generation
        if (!currentSolid) {
            continue;
        }
        
        // Check for transitions in all directions
        bool hasTransition = false;
        
        // Check for transition to empty space in previous position
        if (i > 0) {
            bool prevSolid = (slice & (uint64_t(1) << (i - 1))) != 0;
            if (prevSolid != currentSolid) {
                hasTransition = true;
            }
        } else {
            // At the left edge and solid, always create a face
            hasTransition = true;
        }
        
        // Check for transition to empty space in next position
        if (i < dims - 1) {
            bool nextSolid = (slice & (uint64_t(1) << (i + 1))) != 0;
            if (nextSolid != currentSolid) {
                hasTransition = true;
            }
        } else {
            // At the right edge and solid, always create a face
            hasTransition = true;
        }
        
        // If there's a transition or it's an edge, set the face bit
        if (hasTransition) {
            faceMask |= (uint64_t(1) << i);
            
            // Debug print for face detection
            if (gl_LocalInvocationIndex == 0) {
                if (i == 0 || i == dims - 1) {
                    debugPrintfEXT("  - Edge face at position %u\n", i);
                } else {
                    debugPrintfEXT("  - Interior face at position %u: transition detected\n", i);
                }
            }
        }
    }
    
    // Debug print for face mask calculation
    if (faceMask != 0 && gl_LocalInvocationIndex == 0) {
        debugPrintfEXT("Height field face mask: slice=%llx, mask=%llx\n", slice, faceMask);
    }
    
    return faceMask;
}

// Function to check if a face has been processed globally
bool isFaceProcessed(FaceTrackingRef tracking, uint axis, uint index, uint primary) {
    uint64_t mask = tracking.processedFaces[axis][index];
    return (mask & (uint64_t(1) << primary)) != 0;
}

// Function to mark a face as processed globally
void markFaceProcessed(FaceTrackingRef tracking, uint axis, uint index, uint primary) {
    atomicOr(tracking.processedFaces[axis][index], uint64_t(1) << primary);
}

void binaryGreedyMesh(BitmapRef bitmapRef, uint axis) {
    uint u = (axis + 1) % 3;
    uint v = (axis + 2) % 3;

    uvec3 global = uvec3(gl_GlobalInvocationID.xyz);
    uvec3 local = uvec3(gl_LocalInvocationID.xyz);
    uvec3 workgroup = gl_WorkGroupID;

    // Map global coordinates to the 2D orthogonal plane based on the current axis
    // For example, if axis=0 (X), we need Y and Z coordinates
    uvec2 globalUV = uvec2(0);
    uvec2 localUV = uvec2(0);
    uvec2 workgroupUV = uvec2(0);

    // Map to the orthogonal plane: for axis=0, use (Y,Z); for axis=1, use (X,Z); for axis=2, use (X,Y)
    for(uint i = 0; i < 2; i++) {
        uint orthoAxis = (axis + i) % 3;
        globalUV[i] = global[orthoAxis];
        localUV[i] = local[orthoAxis];
        workgroupUV[i] = workgroup[orthoAxis];
    }

    if(gl_LocalInvocationIndex == 0) {
        workgroupHasFaces = false;
        for (int i = 0 ; i < 8; i++ ){ 
            workgroupFaceMask[i] = 0;
            workgroupProcessed[i] = 0;
        }
        
        // Debug print workgroup info
        debugPrintfEXT("Workgroup %u,%u,%u starting axis=%u, orthogonal plane=(%u,%u)\n", 
            workgroup.x, workgroup.y, workgroup.z, axis, u, v);
    }

    barrier();

    uvec3 dims = uvec3(GRID_SIZE);

    uint64_t currentSlice = getBitmapSlice(bitmapRef, axis, globalUV);

    // Debug print for non-zero slices
    if (currentSlice != 0 && gl_LocalInvocationIndex == 0) {
        debugPrintfEXT("Non-zero slice at axis=%u, orthogonal=(%u,%u): %llx\n", 
            axis, globalUV.x, globalUV.y, currentSlice);
    }

    // Use improved face mask calculation
    uint64_t faceMask = calculateFaceMask(currentSlice, axis, dims[axis]);

    workgroupFaceMask[localUV.x] = faceMask;    
 
    if(faceMask != 0) {
        workgroupHasFaces = true;
        
        // Debug print for non-zero face masks
        if (gl_LocalInvocationIndex == 0) {
            debugPrintfEXT("Non-zero face mask at axis=%u, localUV(%u,%u): %llx\n", 
                axis, localUV.x, localUV.y, faceMask);
        }
    }

    barrier();

    if(!workgroupHasFaces) {
        if (gl_LocalInvocationIndex == 0) {
            debugPrintfEXT("Workgroup %u,%u,%u has no faces, skipping\n", 
                workgroup.x, workgroup.y, workgroup.z);
        }
        return;
    }

    // Get reference to global face tracking
    FaceTrackingRef globalTracking = FaceTrackingRef(pushConstants.heapAddress + pushConstants.faceTrackingOffset);

    bool workgroupDone = false;

    while(!workgroupDone) {
        uint64_t localFaceMask = workgroupFaceMask[localUV.x] & ~workgroupProcessed[localUV.x];

        bool hasUnprocessedFace = localFaceMask != 0;

        uvec4 facesBallot = subgroupBallot(hasUnprocessedFace);

        if(subgroupAll(!hasUnprocessedFace)) {
            workgroupDone = true;
            if (gl_LocalInvocationIndex == 0) {
                debugPrintfEXT("Workgroup %u,%u,%u completed all faces\n", 
                    workgroup.x, workgroup.y, workgroup.z);
            }
            continue;
        }

        // Improved election to ensure only one thread processes a face
        bool elected = hasUnprocessedFace && subgroupElect();

        // Check if the face has been processed globally
        if (elected) {
            int primary = findLSB64(localFaceMask);
            
            // Calculate global index for face tracking
            uint globalIndex = globalUV.x + globalUV.y * GRID_SIZE;
            
            // Check if face has been processed globally
            if (isFaceProcessed(globalTracking, axis, globalIndex, primary)) {
                // Skip this face as it's already been processed
                markProcessed(localUV.x, primary);
                continue;
            }
            
            // Mark as processed locally and globally
            markProcessed(localUV.x, primary);
            markFaceProcessed(globalTracking, axis, globalIndex, primary);
            
            // Debug print for elected thread
            debugPrintfEXT("Thread %u,%u,%u elected with primary=%d\n", 
                global.x, global.y, global.z, primary);

            uint uStart = globalUV.x;
            uint uEnd = uStart + 1;

            bool canExtendU = true;
            while(canExtendU && uEnd < dims[u]) {
                int extLocalU = int(uEnd) % 8;
                int extWorkgroupU = int(uEnd) / 8;

                if (extWorkgroupU == workgroupUV.x) {
                    // Check if the next position has a face at the same primary position
                    uint64_t nextFaceMask = workgroupFaceMask[extLocalU];
                    bool hasFace = (nextFaceMask & (uint64_t(1) << primary)) != 0;
                    bool alreadyProcessed = isProcessed(extLocalU, primary);
                    
                    // For height fields, also check if the height transition is continuous
                    uint64_t currentSlice = getBitmapSlice(bitmapRef, axis, uvec2(uEnd-1, globalUV.y));
                    uint64_t nextSlice = getBitmapSlice(bitmapRef, axis, uvec2(uEnd, globalUV.y));
                    bool heightContinuous = true;
                    
                    // Check if the height transition is similar
                    if (primary > 0 && primary < dims[axis] - 1) {
                        bool curr1 = (currentSlice & (uint64_t(1) << (primary-1))) != 0;
                        bool curr2 = (currentSlice & (uint64_t(1) << primary)) != 0;
                        bool next1 = (nextSlice & (uint64_t(1) << (primary-1))) != 0;
                        bool next2 = (nextSlice & (uint64_t(1) << primary)) != 0;
                        heightContinuous = (curr1 == next1) && (curr2 == next2);
                    }
                    
                    if (hasFace && !alreadyProcessed && heightContinuous) {
                        uEnd++;
                        // Mark as processed locally
                        markProcessed(extLocalU, primary);
                        
                        // Mark as processed globally
                        uint nextGlobalIndex = uEnd + globalUV.y * GRID_SIZE;
                        markFaceProcessed(globalTracking, axis, nextGlobalIndex, primary);
                        
                        debugPrintfEXT("Extended U at height %d: continuous transition found\n", primary);
                    } else {
                        canExtendU = false;
                        if (!heightContinuous) {
                            debugPrintfEXT("Stopped U extension at height %d: height discontinuity\n", primary);
                        }
                    }
                } else {
                    // We've reached another workgroup, need to check bitmap directly
                    uint nextGlobalU = uEnd;
                    uint64_t nextSlice = getBitmapSlice(bitmapRef, axis, uvec2(nextGlobalU, globalUV.y));
                    
                    // Check if voxel has face using improved face detection
                    bool hasFace = false;
                    
                    // Get solid state at primary position
                    bool isSolidNext = (nextSlice & (uint64_t(1) << primary)) != 0;
                    
                    // For interior positions, check neighbors for transitions
                    if (primary > 0 && primary < int(dims[axis]) - 1) {
                        bool prevSolid = (nextSlice & (uint64_t(1) << (primary - 1))) != 0;
                        bool nextSolid = (nextSlice & (uint64_t(1) << (primary + 1))) != 0;
                        
                        // Create face if this position is solid and has a transition with any neighbor
                        hasFace = isSolidNext && (isSolidNext != prevSolid || isSolidNext != nextSolid);
                        
                        if (hasFace && gl_LocalInvocationIndex == 0) {
                            debugPrintfEXT("Interior face at height %d: transitions detected\n", primary);
                        }
                    } else {
                        // For edge positions, always create face if solid
                        hasFace = isSolidNext;
                        
                        if (hasFace && gl_LocalInvocationIndex == 0) {
                            debugPrintfEXT("Edge face at height %d: solid edge\n", primary);
                        }
                    }
                    
                    // Check if face has been processed globally
                    uint nextGlobalIndex = nextGlobalU + globalUV.y * GRID_SIZE;
                    if (hasFace && !isFaceProcessed(globalTracking, axis, nextGlobalIndex, primary)) {
                        uEnd++;
                        // Mark as processed globally
                        markFaceProcessed(globalTracking, axis, nextGlobalIndex, primary);
                    } else {
                        canExtendU = false;
                    } 
                }
            }

            // Debug print for U extension
            if (uEnd > uStart + 1) {
                debugPrintfEXT("Extended U from %u to %u (length=%u)\n", 
                    uStart, uEnd, uEnd - uStart);
            }

            uint vStart = globalUV.y;
            uint vEnd = vStart + 1;
                
            // Try to extend in v direction
            bool canExtendV = true;
            while (canExtendV && vEnd < dims[v]) {
                // Check if the entire range from uStart to uEnd-1 has faces
                bool rangeHasFaces = true;
                bool heightContinuous = true;
                
                for (uint uCheck = uStart; uCheck < uEnd; uCheck++) {
                    uint64_t currentSlice = getBitmapSlice(bitmapRef, axis, uvec2(uCheck, vEnd-1));
                    uint64_t checkSlice = getBitmapSlice(bitmapRef, axis, uvec2(uCheck, vEnd));
                    
                    // Check if voxel has face using improved face detection
                    bool hasFace = false;
                    bool isSolidCheck = (checkSlice & (uint64_t(1) << primary)) != 0;
                    
                    // For interior positions, check neighbors for transitions
                    if (primary > 0 && primary < int(dims[axis]) - 1) {
                        bool prevSolid = (checkSlice & (uint64_t(1) << (primary - 1))) != 0;
                        bool nextSolid = (checkSlice & (uint64_t(1) << (primary + 1))) != 0;
                        
                        // Create face if this position is solid and has a transition with any neighbor
                        hasFace = isSolidCheck && (isSolidCheck != prevSolid || isSolidCheck != nextSolid);
                        
                        // Also check if the height pattern is consistent with the previous row
                        bool currentPrevSolid = (currentSlice & (uint64_t(1) << (primary - 1))) != 0;
                        bool currentNextSolid = (currentSlice & (uint64_t(1) << (primary + 1))) != 0;
                        bool currentSolid = (currentSlice & (uint64_t(1) << primary)) != 0;
                        
                        // Check if transition pattern is similar
                        if ((currentSolid != prevSolid) != (isSolidCheck != prevSolid) ||
                            (currentSolid != nextSolid) != (isSolidCheck != nextSolid)) {
                            heightContinuous = false;
                        }
                    } else {
                        // For edge positions, always create face if solid
                        hasFace = isSolidCheck;
                    }
                    
                    // Check if face has been processed globally
                    uint checkGlobalIndex = uCheck + vEnd * GRID_SIZE;
                    if (!hasFace || isFaceProcessed(globalTracking, axis, checkGlobalIndex, primary)) {
                        rangeHasFaces = false;
                        break;
                    }
                }
                
                if (rangeHasFaces && heightContinuous) {
                    vEnd++;
                    
                    // Debug print for V extension
                    if (gl_LocalInvocationIndex == 0) {
                        debugPrintfEXT("Extended V at row %u with continuous height pattern\n", vEnd-1);
                    }
                    
                    // Mark all faces in this row as processed globally
                    for (uint uCheck = uStart; uCheck < uEnd; uCheck++) {
                        uint checkGlobalIndex = uCheck + vEnd * GRID_SIZE;
                        markFaceProcessed(globalTracking, axis, checkGlobalIndex, primary);
                    }
                } else {
                    canExtendV = false;
                    
                    // Debug print for stopped V extension
                    if (gl_LocalInvocationIndex == 0) {
                        if (!rangeHasFaces) {
                            debugPrintfEXT("Stopped V extension: missing faces in row\n");
                        } else if (!heightContinuous) {
                            debugPrintfEXT("Stopped V extension: height pattern changed\n");
                        }
                    }
                }
            }
                
            // Debug print for V extension
            if (vEnd > vStart + 1) {
                debugPrintfEXT("Extended V from %u to %u (length=%u)\n", 
                    vStart, vEnd, vEnd - vStart);
            }
                
            // Create quad
            uvec3 minPos, maxPos;
                
            // Construct quad position vectors based on axis
            minPos = uvec3(0, 0, 0);
            maxPos = uvec3(0, 0, 0);
                
            // The primary dimension is the height in the axis direction
            minPos[axis] = uint(primary);
            // The u and v dimensions are the orthogonal coordinates
            minPos[u] = uStart;
            minPos[v] = vStart;
                
            // The primary dimension is a single layer thick
            maxPos[axis] = uint(primary) + 1;
            // The u and v dimensions extend to the end of the greedy merged area
            maxPos[u] = uEnd;
            maxPos[v] = vEnd;
                
            // Use a default material ID of 1 for now
            uint materialId = 0xFF;
            
            // Debug print for quad creation
            debugPrintfEXT("Creating quad for axis=%u: min(%u,%u,%u) max(%u,%u,%u) size: %ux%u\n", 
                axis, 
                minPos.x, minPos.y, minPos.z, 
                maxPos.x, maxPos.y, maxPos.z,
                maxPos[u] - minPos[u], maxPos[v] - minPos[v]);
                
            emitQuad(Quad(minPos, maxPos, axis, materialId));
                
            // Mark all bits that were merged into this quad as processed
            for (uint vMerge = vStart; vMerge < vEnd; vMerge++) {
                // Only process bits in other rows, since we've already processed our own row
                if (vMerge != vStart) {
                    for (uint uMerge = uStart; uMerge < uEnd; uMerge++) {
                        // If within same workgroup, mark as processed in shared memory
                        int mergeLocalU = int(uMerge) % 8;
                        int mergeWorkgroupU = int(uMerge) / 8;
                            
                        if (mergeWorkgroupU == int(workgroupUV.x) && vMerge == globalUV.y) {
                            markProcessed(mergeLocalU, primary);
                        }
                        
                        // Mark as processed globally
                        uint mergeGlobalIndex = uMerge + vMerge * GRID_SIZE;
                        markFaceProcessed(globalTracking, axis, mergeGlobalIndex, primary);
                    }
                }
            }
        }
            
        // Synchronize before next iteration
        barrier();
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
    
    // Debug print for thread start
    if (gl_LocalInvocationIndex == 0) {
        debugPrintfEXT("Thread %u,%u,%u starting with AXIS=%u\n", 
            threadPos.x, threadPos.y, threadPos.z, AXIS);
    }
    
    barrier();

    // Process all three axes to ensure we capture all faces in the volume
    for(int d = 0; d < 3; d++) {
        // Debug print for each axis iteration
        if (gl_LocalInvocationIndex == 0) {
            debugPrintfEXT("Thread %u,%u,%u processing axis %d\n", 
                threadPos.x, threadPos.y, threadPos.z, d);
        }
        
        // Ensure all threads participate in processing each axis
        binaryGreedyMesh(bitmapRef, uint(d));
        barrier();
    }
    
    // Debug print for thread completion
    if (gl_LocalInvocationIndex == 0) {
        debugPrintfEXT("Thread %u,%u,%u completed all axes\n", 
            threadPos.x, threadPos.y, threadPos.z);
    }
}
