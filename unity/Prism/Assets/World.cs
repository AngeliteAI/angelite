    using System;
    using Unity.Collections;
    using Unity.Jobs;
    using UnityEngine;

    public class World : MonoBehaviour
    {
   public float cubeSize = 1; // Size of each cube
     public float freq = 0.5f;
     public float amplitude = 1.0f;
     public Vector3Int worldSize = new Vector3Int(8, 8, 8); // Size of the region (number of cubes in each dimension)
     public Vector3Int chunkSize = new Vector3Int(8, 8, 8); // Size of the region (number of cubes in each dimension)
     const float GOLDEN = 0.618033988f;
             public float squishFactor = 0.6f; // Adjust this value to control the squish effect
             public float heightOffset = 8f; // Adjust this value to control the overall height of the terrain       


    // Set up the job
    public struct GenJob : IJobParallelFor
    {
        public float squishFactor;
        public float heightOffset;
        public float freq;
        public Vector3Int pos;
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
            float density = (float) SimplexNoise.Simplex3DFractal(pos * size + new Vector3((float)x / (float)width * freq, (float)y / (float) height * freq, (float) z / (float) depth * freq)) * amplitude;
            float densityMod = squishFactor * ((float)heightOffset - y);
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
                                     heightOffset = heightOffset,
                                     freq = freq,
                                     
                                     amplitude = amplitude,
                                     size = chunkSize,
                                 }
                                 ;
             }

             private int impld = 0;
             public void Update()
             {
                 if (impld % 100 == 0)
                 {
                    var gen = new GameObject("Chunk");
                                   gen.transform.parent = transform;
                                   gen.transform.localPosition = new Vector3(chunkSize.x  * impld, 0, 0);
                                   gen.AddComponent<Chunk>();
                                   gen.GetComponent<Chunk>().world = this;
                                   gen.GetComponent<Chunk>().pos.x = impld;
                 }
               
                 impld++;
                 
             }
    }