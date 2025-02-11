using System;
using UnityEngine;
using System.Collections.Generic;
using Unity.Collections;
using Unity.Jobs;
using Unity.Jobs.LowLevel.Unsafe;

public class World : MonoBehaviour
{
    public float cubeSize = 1; // Size of each cube
    public float freq = 0.5f;
    public float amplitude = 1.0f;
    public Vector3Int worldSize = new Vector3Int(10, 4, 10); // Size of the world (number of cubes in each dimension)
    public Vector3Int chunkSize = new Vector3Int(8, 8, 8); // Size of the world (number of cubes in each dimension)
    const float GOLDEN = 0.618033988f;
            public float squishFactor = 0.6f; // Adjust this value to control the squish effect
            public float heightOffset = 8f; // Adjust this value to control the overall height of the terrain
    public NativeArray<int> worldData;
    JobHandle genHandle;

    // Set up the job
    public struct GenJob : IJobParallelFor
    {
        public float squishFactor;
        public float heightOffset;
        public float freq;
        public float amplitude;
        public Vector3Int chunkSize;
        public Vector3Int worldSize;
        public NativeArray<int> worldData;
        public void Execute(int index)
        {
            var final = index;
            var width = chunkSize.x * worldSize.x;
            var height = chunkSize.y * worldSize.y;
            var depth = chunkSize.z * worldSize.z;
            int _z = index / (width * height);
            index -= _z * width * height;
            float z = _z;
            float y = index / width;
            float x = index % width;
            float density = (float) SimplexNoise.Simplex3DFractal(new Vector3((float)x / (float)width * freq, (float)y / (float) height * freq, (float) z / (float) depth * freq)) * amplitude;
            Debug.Log(density);
            float densityMod = squishFactor * ((float)heightOffset - y);
            if (density + densityMod > 0)
            {
                worldData[final] = 1;
            }
            else
            {
                worldData[final] = 0;
            }
        }
    }
    
       private void Start()
        {
            GenerateWorld();
        }

        private void GenerateWorld()
        {
            // Initialize world data
            worldData = new NativeArray<int>(
                worldSize.x * worldSize.y * worldSize.z * chunkSize.x * chunkSize.y * chunkSize.z, Allocator.Persistent);

            int numBatches = Math.Max(1, JobsUtility.JobWorkerCount / 2);
            int totalItems = worldData.Length;
            int batchSize = totalItems / numBatches;

            var job = new GenJob
                {
                    squishFactor = squishFactor,
                    heightOffset = heightOffset,
                    freq = freq,
                    amplitude = amplitude,
                    chunkSize = chunkSize,
                    worldData = worldData,
                    worldSize = worldSize
                }
                ;
            JobHandle handle = job.Schedule(worldData.Length, batchSize);
            handle.Complete();
        for (int z = 0; z < worldSize.z; z++)
            {
                for (int y = 0; y < worldSize.y; y++)
                {
                    for (int x = 0; x < worldSize.x; x++)
                    {
                        var chunkGameObject = new GameObject("Chunk");
                        chunkGameObject.transform.parent = transform;
                        chunkGameObject.transform.localPosition = new Vector3(x * chunkSize.x * cubeSize, y * chunkSize.y * cubeSize, z * chunkSize.z * cubeSize);
                        chunkGameObject.transform.localScale = Vector3.one * cubeSize;
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