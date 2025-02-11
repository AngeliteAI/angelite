using UnityEngine;

public class SimplexNoise : MonoBehaviour
{
    private static readonly Vector3[] Grad3 = {
        new Vector3(1.0f, 1.0f, 0.0f), new Vector3(-1.0f, 1.0f, 0.0f),
        new Vector3(1.0f, -1.0f, 0.0f), new Vector3(-1.0f, -1.0f, 0.0f),
        new Vector3(1.0f, 0.0f, 1.0f), new Vector3(-1.0f, 0.0f, 1.0f),
        new Vector3(1.0f, 0.0f, -1.0f), new Vector3(-1.0f, 0.0f, -1.0f),
        new Vector3(0.0f, 1.0f, 1.0f), new Vector3(0.0f, -1.0f, 1.0f),
        new Vector3(0.0f, 1.0f, -1.0f), new Vector3(0.0f, -1.0f, -1.0f)
    };

    private static readonly Matrix4x4 Rot1 = new Matrix4x4(
        new Vector4(-0.37f, 0.36f, 0.85f, 0.0f),
        new Vector4(-0.14f, -0.93f, 0.34f, 0.0f),
        new Vector4(0.92f, 0.01f, 0.4f, 0.0f),
        new Vector4(0.0f, 0.0f, 0.0f, 1.0f)
    );

    private static readonly Matrix4x4 Rot2 = new Matrix4x4(
        new Vector4(-0.55f, -0.39f, 0.74f, 0.0f),
        new Vector4(0.33f, -0.91f, -0.24f, 0.0f),
        new Vector4(0.77f, 0.12f, 0.63f, 0.0f),
        new Vector4(0.0f, 0.0f, 0.0f, 1.0f)
    );

    private static readonly Matrix4x4 Rot3 = new Matrix4x4(
        new Vector4(-0.71f, 0.52f, -0.47f, 0.0f),
        new Vector4(-0.08f, -0.72f, -0.68f, 0.0f),
        new Vector4(-0.7f, -0.45f, 0.56f, 0.0f),
        new Vector4(0.0f, 0.0f, 0.0f, 1.0f)
    );

    private static Vector3 Random3(Vector3 c)
    {
        float j = 4096.0f * Mathf.Sin(Vector3.Dot(c, new Vector3(17.0f, 59.4f, 15.0f)));
        Vector3 r = new Vector3(
            Mathf.Floor(j * 512.0f),
            Mathf.Floor(j * 512.0f * (1.0f / 125.0f)),
            Mathf.Floor(j * 512.0f * (1.0f / 125.0f * 1.0f / 125.0f))
        );
        return r * (1.0f / 512.0f) - new Vector3(0.5f, 0.5f, 0.5f);
    }

    private static float Simplex3D(Vector3 p)
    {
        const float F3 = 1.0f / 3.0f;
        const float G3 = 1.0f / 6.0f;

        float pX = p.x, pY = p.y, pZ = p.z;
        float s0 = Mathf.Floor(pX + Vector3.Dot(p, Vector3.one * F3));
        float s1 = Mathf.Floor(pY + Vector3.Dot(p, Vector3.one * F3));
        float s2 = Mathf.Floor(pZ + Vector3.Dot(p, Vector3.one * F3));
        Vector3 s = new Vector3(s0, s1, s2);

        float x0 = pX - s0 + Vector3.Dot(s, Vector3.one * G3);
        float x1 = pY - s1 + Vector3.Dot(s, Vector3.one * G3);
        float x2 = pZ - s2 + Vector3.Dot(s, Vector3.one * G3);
        Vector3 x = new Vector3(x0, x1, x2);

        float e0 = (x0 >= 0.0f ? 1.0f : 0.0f);
        float e1 = (x1 >= 0.0f ? 1.0f : 0.0f);
        float e2 = (x2 >= 0.0f ? 1.0f : 0.0f);
        Vector3 e = new Vector3(e0, e1, e2);

        float i10 = e0 * (1.0f - e2);
        float i11 = e1 * (1.0f - e0);
        float i12 = e2 * (1.0f - e1);
        Vector3 i1 = new Vector3(i10, i11, i12);

        float i20 = (1.0f - e2) * (1.0f - e0);
        float i21 = (1.0f - e0) * (1.0f - e1);
        float i22 = (1.0f - e1) * (1.0f - e2);
        Vector3 i2 = new Vector3(i20, i21, i22);

        Vector3 x1Vec = x - i1 + Vector3.one * G3;
        Vector3 x2Vec = x - i2 + Vector3.one * (2.0f * G3);
        Vector3 x3Vec = x - Vector3.one + Vector3.one * (3.0f * G3);

        float w0 = x.x * x.x + x.y * x.y + x.z * x.z;
        float w1 = x1Vec.x * x1Vec.x + x1Vec.y * x1Vec.y + x1Vec.z * x1Vec.z;
        float w2 = x2Vec.x * x2Vec.x + x2Vec.y * x2Vec.y + x2Vec.z * x2Vec.z;
        float w3 = x3Vec.x * x3Vec.x + x3Vec.y * x3Vec.y + x3Vec.z * x3Vec.z;
        float w0Max = Mathf.Max(0.6f - w0, 0.0f);
        float w1Max = Mathf.Max(0.6f - w1, 0.0f);
        float w2Max = Mathf.Max(0.6f - w2, 0.0f);
        float w3Max = Mathf.Max(0.6f - w3, 0.0f);

        float d0 = Random3(s).x * x.x + Random3(s).y * x.y + Random3(s).z * x.z;
        float d1 = Random3(s + i1).x * x1Vec.x + Random3(s + i1).y * x1Vec.y + Random3(s + i1).z * x1Vec.z;
        float d2 = Random3(s + i2).x * x2Vec.x + Random3(s + i2).y * x2Vec.y + Random3(s + i2).z * x2Vec.z;
        float d3 = Random3(s + Vector3.one).x * x3Vec.x + Random3(s + Vector3.one).y * x3Vec.y + Random3(s + Vector3.one).z * x3Vec.z;
        float w0Pow = w0Max * w0Max;
        float w1Pow = w1Max * w1Max;
        float w2Pow = w2Max * w2Max;
        float w3Pow = w3Max * w3Max;
        w0Pow *= w0Pow;
        w1Pow *= w1Pow;
        w2Pow *= w2Pow;
        w3Pow *= w3Pow;
        d0 *= w0Pow;
        d1 *= w1Pow;
        d2 *= w2Pow;
        d3 *= w3Pow;

        return d0 + d1 + d2 + d3 * 52.0f;
    }


    public static float Simplex3DFractal(Vector3 m)
    {
        return 0.5333333f * Simplex3D(Mul(m, Rot1))
             + 0.2666667f * Simplex3D(Mul(m * 2.0f, Rot2))
             + 0.1333333f * Simplex3D(Mul(m * 4.0f, Rot3))
             + 0.0666667f * Simplex3D(m * 8.0f);
    }

    private static float Dot(Vector3 a, Vector3 b)
    {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    private static Vector3 Mul(Vector3 a, Matrix4x4 b)
    {
        return new Vector3(
            a.x * b.m00 + a.y * b.m01 + a.z * b.m02 + b.m03,
            a.x * b.m10 + a.y * b.m11 + a.z * b.m12 + b.m13,
            a.x * b.m20 + a.y * b.m21 + a.z * b.m22 + b.m23
        );
    }

    public float GetNoise(Vector3 position, float time)
    {
        Vector2 p = new Vector2(position.x, position.z) / 8.0f;
        Vector3 p3 = new Vector3(p.x, p.y, time * 0.025f);

        float value;
        if (p.x <= 0.6f)
        {
            value = Simplex3D(p3 * 32.0f);
        }
        else
        {
            value = Simplex3DFractal(p3 * 8.0f + Vector3.one * 8.0f);
        }

        value = 0.5f + 0.5f * value;
        value *= Mathf.SmoothStep(0.0f, 0.005f, Mathf.Abs(0.6f - p.x));

        return value;
    }
}
