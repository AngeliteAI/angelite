using System;
using UnityEngine;
using System.Collections.Generic;

public class World : MonoBehaviour
{
    public int cubeSize = 1; // Size of each cube
    public float freq = 1.0f;
    public Vector3Int worldSize = new Vector3Int(10, 1, 10); // Size of the world (number of cubes in each dimension)
    public Vector3Int chunkSize = new Vector3Int(8, 8, 8); // Size of the world (number of cubes in each dimension)
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
                    var height = (int)(Mathf.PerlinNoise(x * freq, z * freq) * (float) worldSize.y * (float) chunkSize.y);
                    for (int y = 0; y < height; y++)
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
                    chunk.chunkPosition =  new Vector3Int(x, 0, z);
                }
            }
        }
}