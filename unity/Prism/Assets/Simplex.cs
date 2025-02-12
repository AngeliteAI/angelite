using Unity.Mathematics;

public struct SimplexNoise
{
    private static readonly float3[] Grad3 = {
        new float3(1.0f, 1.0f, 0.0f), new float3(-1.0f, 1.0f, 0.0f),
        new float3(1.0f, -1.0f, 0.0f), new float3(-1.0f, -1.0f, 0.0f),
        new float3(1.0f, 0.0f, 1.0f), new float3(-1.0f, 0.0f, 1.0f),
        new float3(1.0f, 0.0f, -1.0f), new float3(-1.0f, 0.0f, -1.0f),
        new float3(0.0f, 1.0f, 1.0f), new float3(0.0f, -1.0f, 1.0f),
        new float3(0.0f, 1.0f, -1.0f), new float3(0.0f, -1.0f, -1.0f)
    };

    private static readonly float4x4 Rot1 = new float4x4(
        -0.37f, 0.36f, 0.85f, 0.0f,
        -0.14f, -0.93f, 0.34f, 0.0f,
        0.92f, 0.01f, 0.4f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f
    );

    private static readonly float4x4 Rot2 = new float4x4(
        -0.55f, -0.39f, 0.74f, 0.0f,
        0.33f, -0.91f, -0.24f, 0.0f,
        0.77f, 0.12f, 0.63f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f
    );

    private static readonly float4x4 Rot3 = new float4x4(
        -0.71f, 0.52f, -0.47f, 0.0f,
        -0.08f, -0.72f, -0.68f, 0.0f,
        -0.7f, -0.45f, 0.56f, 0.0f,
        0.0f, 0.0f, 0.0f, 1.0f
    );

    private static float3 Random3(float3 c)
    {
        float j = 4096.0f * math.sin(math.dot(c, new float3(17.0f, 59.4f, 15.0f)));
        float3 r = new float3(
            math.floor(j * 512.0f),
            math.floor(j * 512.0f * (1.0f / 125.0f)),
            math.floor(j * 512.0f * (1.0f / 125.0f * 1.0f / 125.0f))
        );
        return r * (1.0f / 512.0f) - new float3(0.5f);
    }

    private static float Simplex3D(float3 p)
    {
        const float F3 = 1.0f / 3.0f;
        const float G3 = 1.0f / 6.0f;

        float3 s = math.floor(p + math.dot(p, new float3(F3)));
        float3 x = p - s + math.dot(s, new float3(G3));

        float3 e = new float3(
            x.x >= 0.0f ? 1.0f : 0.0f,
            x.y >= 0.0f ? 1.0f : 0.0f,
            x.z >= 0.0f ? 1.0f : 0.0f
        );

        float3 i1 = new float3(
            e.x * (1.0f - e.z),
            e.y * (1.0f - e.x),
            e.z * (1.0f - e.y)
        );

        float3 i2 = new float3(
            (1.0f - e.z) * (1.0f - e.x),
            (1.0f - e.x) * (1.0f - e.y),
            (1.0f - e.y) * (1.0f - e.z)
        );

        float3 x1 = x - i1 + G3;
        float3 x2 = x - i2 + 2.0f * G3;
        float3 x3 = x - 1.0f + 3.0f * G3;

        float4 w = new float4(
            math.max(0.6f - math.dot(x, x), 0.0f),
            math.max(0.6f - math.dot(x1, x1), 0.0f),
            math.max(0.6f - math.dot(x2, x2), 0.0f),
            math.max(0.6f - math.dot(x3, x3), 0.0f)
        );

        w = w * w;
        w = w * w;

        float4 d = new float4(
            math.dot(Random3(s), x),
            math.dot(Random3(s + i1), x1),
            math.dot(Random3(s + i2), x2),
            math.dot(Random3(s + 1.0f), x3)
        );

        return math.dot(d, w) * 52.0f;
    }

    public static float Simplex3DFractal(float3 m)
    {
        return 0.5333333f * Simplex3D(math.mul(Rot1, new float4(m, 1)).xyz)
             + 0.2666667f * Simplex3D(math.mul(Rot2, new float4(m * 2.0f, 1)).xyz)
             + 0.1333333f * Simplex3D(math.mul(Rot3, new float4(m * 4.0f, 1)).xyz)
             + 0.0666667f * Simplex3D(m * 8.0f);
    }

    public static float GetNoise(float3 position, float time)
    {
        float2 p = new float2(position.x, position.z) / 8.0f;
        float3 p3 = new float3(p.x, p.y, time * 0.025f);

        float value;
        if (p.x <= 0.6f)
        {
            value = Simplex3D(p3 * 32.0f);
        }
        else
        {
            value = Simplex3DFractal(p3 * 8.0f + new float3(8.0f));
        }

        value = 0.5f + 0.5f * value;
        value *= math.smoothstep(0.0f, 0.005f, math.abs(0.6f - p.x));

        return value;
    }
}
