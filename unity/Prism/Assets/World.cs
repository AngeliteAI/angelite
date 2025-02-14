    using System;
    using Unity.Burst;
    using Unity.Collections;
    using Unity.Jobs;
    using Unity.Mathematics;
    using UnityEngine;
    using UnityEngine.UIElements;

    public class World : MonoBehaviour
    {
   public float cubeSize = 1; // Size of each cube
   public float loaded = 0;
   public float loadTime = 0.0f;
   public float loadRate = 0.1f;
     public float freq = 0.5f;
     public float amplitude = 1.0f;
     public Vector3Int worldSize = new Vector3Int(8, 8, 8); // Size of the region (number of cubes in each dimension)
     public Vector3Int chunkSize = new Vector3Int(8, 8, 8); // Size of the region (number of cubes in each dimension)
     const float GOLDEN = 0.618033988f;
             public float squishFactor = 0.6f; // Adjust this value to control the squish effect
             public float heightOffset = 8f; // Adjust this value to control the overall height of the terrain       

             public Material stone;
             
    // Set up the job
    [BurstCompile(CompileSynchronously = true)]
    public struct GenJob : IJobParallelFor
    {
        public float squishFactor;
        public float heightOffset;
        public float freq;
        public Vector3Int pos;
        public int chunkY;
        public float amplitude;
        public Vector3Int size;
        public NativeArray<int> data;
        public void Execute(int index)
        {
            var final = index;
            var width = size.x;
            var height = size.y;
            var depth = size.z;
            int _z = index / (width * height);
            index -= _z * width * height;
            float z = _z;
            float y = index / width;
            float x = index % width;
            float density = (float) SimplexNoise.Simplex3DFractal(new int3(pos.x, pos.y, pos.z) * new int3(size.x, size.y, size.z) + new float3((float)x / (float)width * freq, (float)y / (float) height * freq, (float) z / (float) depth * freq)) * amplitude;
            float densityMod = squishFactor * ((float)heightOffset - y - chunkY);
            
            if (density + densityMod > 0)
            {
                data[final] = 1;
            }
            else
            {
                data[final] = 0;
            }
        }
    }
             public GenJob NewRegionGenJob()
             {
                 
                 return new GenJob
                                 {
                                     squishFactor = squishFactor,
                                     heightOffset =  heightOffset,
                                     freq = freq,
                                     
                                     amplitude = amplitude,
                                     size = chunkSize,
                                 }
                                 ;
             }

             private int impld = 0;

             public void Start()
             {
                 NativeLeakDetection.Mode = NativeLeakDetectionMode.EnabledWithStackTrace;
             }

             public void Update()
             {
                 loadTime += Time.deltaTime;
                 if (loaded < worldSize.x * worldSize.y * worldSize.z && loadTime >= loadRate) {
                     // Convert linear index to 3D coordinates
                     int index = (int)loaded;
                     int x = index % worldSize.x;
                     int y = (index / worldSize.x) % worldSize.y;
                     int z = index / (worldSize.x * worldSize.y);
    
                     var gen = new GameObject("Chunk");
                     gen.transform.parent = transform;
    
                     // Position the chunk based on its 3D coordinates
                     gen.transform.localPosition = new Vector3(
                         x * chunkSize.x,
                         y * chunkSize.y,
                         z * chunkSize.z
                     );
    
                     var chunk = gen.AddComponent<Chunk>();
                     chunk.world = this;
                     chunk.pos = new Vector3Int(x, y, z);
    
                     loaded++;
                     loadTime = 0.0f;
                 }
             }
    }