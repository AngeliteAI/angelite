#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float3 position;
    float4 color;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertexShader(uint vertexID [[vertex_id]],
                              constant Vertex *vertices [[buffer(0)]]) {
    VertexOut out;
    out.position = float4(vertices[vertexID].position, 1.0);
    out.color = vertices[vertexID].color;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}
