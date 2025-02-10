using System;
using UnityEngine;
using System.Collections.Generic;

public class World : MonoBehaviour
{
    public int cubeSize = 1; // Size of each cube
    public float scale = 0.5f;
    public float amplitude = 1.0f;
    public Vector3Int worldSize = new Vector3Int(10, 4, 10); // Size of the world (number of cubes in each dimension)
    public Vector3Int chunkSize = new Vector3Int(8, 8, 8); // Size of the world (number of cubes in each dimension)
    const float GOLDEN = 0.618033988f;
            public float squishFactor = 0.6f; // Adjust this value to control the squish effect
            public float heightOffset = 8f; // Adjust this value to control the overall height of the terrain
    public int[,,] worldData; // 3D boolean array to store world data
       private void Start()
        {
            GenerateWorld();
        }

        private void GenerateWorld()
        {
            // Initialize world data
            worldData = new int[worldSize.x * chunkSize.x, worldSize.y * chunkSize.y, worldSize.z * chunkSize.z];

            var noiseData = Noise.Calc3D(worldSize.x * chunkSize.x, worldSize.y * chunkSize.y, worldSize.z * chunkSize.z,
                scale);
            ;
            for (int z = 0; z < worldSize.z * chunkSize.z; z++)
            {
                for (int x = 0; x < worldSize.x * chunkSize.x; x++)
                {
                    for (int y = 0; y < worldSize.y * chunkSize.y; y++)
                    {
                        float density = noiseData[x, y, z] * amplitude;
                        float densityMod = squishFactor * ((float)y - heightOffset);
                        Debug.Log(densityMod);
                        Debug.Log(density);
                        if (density + densityMod > 0)
                        {
                            worldData[x, y, z] = 1;
                        }
                        else
                        {
                            worldData[x, y, z] = 0;
                        }
                    }
                }
            }

            for (int z = 0; z < worldSize.z; z++)
            {
                for (int y = 0; y < worldSize.y; y++)
                {
                    for (int x = 0; x < worldSize.x; x++)
                    {
                        var chunkGameObject = new GameObject("Chunk");
                        chunkGameObject.transform.parent = transform;
                        chunkGameObject.transform.localPosition = new Vector3(x * chunkSize.x, y * chunkSize.y, z * chunkSize.z);
                        chunkGameObject.AddComponent<Chunk>();
                        var chunk = chunkGameObject.GetComponent<Chunk>();
                        chunk.world = this;
                        chunk.chunkPosition = new Vector3Int(x, y, z);
                    }
                }
            }
        }

        private float Noise3D(float x, float y, float squishFactor)
        {
            // Calculate the 3D noise value using Perlin noise
            float noiseX = x;
            float noiseY = y * squishFactor;
            float noiseZ = y * (1 - squishFactor);

            return Mathf.Max(0.0f, Mathf.PerlinNoise(noiseX, noiseY) + Mathf.PerlinNoise(noiseX, noiseZ));
        }
}