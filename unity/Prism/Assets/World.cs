using System;
using UnityEngine;
using System.Collections.Generic;

public class World : MonoBehaviour
{
    public int cubeSize = 1; // Size of each cube
    public float freq = 1.0f;
    public Vector3Int worldSize = new Vector3Int(10, 1, 10); // Size of the world (number of cubes in each dimension)
    public Vector3Int chunkSize = new Vector3Int(8, 8, 8); // Size of the world (number of cubes in each dimension)
    const float GOLDEN = 0.618033988f;
            public float squishFactor = 0.6f; // Adjust this value to control the squish effect
            public float heightOffset = 32f; // Adjust this value to control the overall height of the terrain
    public int[,,] worldData; // 3D boolean array to store world data
       private void Start()
        {
            GenerateWorld();
        }
    
        private void GenerateWorld()
        {
            GameObject worldObject = new GameObject("World");
            worldObject.transform.parent = transform;

            // Initialize world data
            worldData = new int[worldSize.x * chunkSize.x, worldSize.y * chunkSize.y, worldSize.z * chunkSize.z];


            for (int z = 0; z < worldSize.z * chunkSize.z; z++)
            {
                for (int x = 0; x < worldSize.x * chunkSize.x; x++)
                {
                    float sampleX = (float)x / ((float)worldSize.x * (float)chunkSize.x) * GOLDEN * freq;
                    float sampleZ = (float)z / ((float)worldSize.z * (float)chunkSize.z) * GOLDEN * freq;
                    Debug.Log(sampleX);
                    float noise3D = Noise3D(sampleX, sampleZ, squishFactor);
                    int height = Mathf.RoundToInt(noise3D * (float)worldSize.y * (float)chunkSize.y + heightOffset);
                    Debug.Log(height);
                    
                    for (int y = 0; y < Math.Min(height, 7); y++)
                    {
                        worldData[x, y, z] = 1;
                    }
                }
            }

            for (int z = 0; z < worldSize.z; z++)
            {
                for (int x = 0; x < worldSize.x; x++)
                {
                    var chunkGameObject = new GameObject("Chunk");
                    chunkGameObject.transform.parent = transform;
                    chunkGameObject.transform.localPosition = new Vector3(x * chunkSize.x, 0, z * chunkSize.z);
                    chunkGameObject.AddComponent<Chunk>();
                    var chunk = chunkGameObject.GetComponent<Chunk>();
                    chunk.world = this;
                    chunk.chunkPosition = new Vector3Int(x, 0, z);
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