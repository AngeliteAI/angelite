#define REPR uint
#define REGION_HEIGHT 32
#define REGION_SIZE 8
#define CHUNK_SIZE 8
struct Region {
    uvec2 position;
    uint heightMapDataOffset;
    uint heightMapMeshOffset;
    uint heightMapResolutionInChunks;
    //offset height, each unit represents N chunks, where N is the number of bits in the representation (uint = 32 chunks vertically on Z axis)
    uint height;
    uint maxHeight;
    //each usize represents a column of chunks, looking down and flattening the Z axis of the region.
    //each bit represents a chunk in the z axis
    //0 means the chunk is air
    //1 means the chunk is partially or entirely solid material
    //this will be used to count trailing zeros to find the height
    uint existsDataOffset;
};
// Metadata struct for the chunk
struct Chunk {
    uint state;
    uint offsetPalette;
    uint offsetCompressed;
    uint offsetRaw;
    uint offsetMesh;
    uint countPalette;
    uint countFaces;
    uint sizeRawMaxBytes;
    uint meshValid;
    uint padding;
};
