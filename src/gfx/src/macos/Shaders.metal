#include <metal_stdlib>
using namespace metal;

struct Block {
    uint64_t offset;
    uint64_t size;
}

struct Chunk {
    Block palette;
    Block voxels;
    uint64_t suboffset;
}

uint64_t getPaletteValue(
    device const uint64_t* heap [[buffer(0)]],   
    uint32_t paletteIndex
) {
    return heap[metadataHeapOffsets[paletteIndex]];
}

kernel void countFacesInPalette(
    device const uint64_t* heap [[buffer(0)]],   
    device const uint64_t* metadataHeapOffsets [[buffer(1)]] 
) {

}