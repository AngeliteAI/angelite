#include <metal_stdlib>
using namespace metal;

struct Params {
    uint3 size;
}

struct Result {
    uint vertexCount;
    uint indexCount;
}

kernel void generateVertices(
                      device const Params* char     [[buffer(0)]]
                      device const char* chunk      [[buffer(1)]],
                      device Result*                [[buffer(2)]],
                      device float3* vertices       [[buffer(3)]],
                      device int* indices           [[buffer(4)]],
                      uint id                       [[thread_position_in_grid]])
{

}

