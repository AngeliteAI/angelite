using UnityEngine;
using System.Collections.Generic;

public class Chunk : MonoBehaviour
{
    public World world;
    public Vector3Int chunkPosition;
    
    public void Start()
    {
            List<Vector3> vertices = new List<Vector3>();
            List<int> triangles = new List<int>();
    
             for (int z = 0; z < world.chunkSize.z; z++)
                {
                    for (int y = 0; y < world.chunkSize.y; y++)
                    {
                        for (int x = 0; x < world.chunkSize.x; x++)
                        {
                            var i = world.chunkSize.x * chunkPosition.x;
                            var j = world.chunkSize.y * chunkPosition.y;
                            var k = world.chunkSize.x * chunkPosition.x;
                            if (world.worldData[x + i, y + j, z + k] != 0)
                            {
                                CreateCube(vertices, triangles, new Vector3Int(x, y, z) + world.chunkSize * chunkPosition);
                            }
                        }
                    }
                }
        
                Mesh mesh = new Mesh();
                mesh.vertices = vertices.ToArray();
                mesh.triangles = triangles.ToArray();
                mesh.RecalculateNormals();
        
            MeshFilter meshFilter = gameObject.AddComponent<MeshFilter>();
            MeshRenderer meshRenderer = gameObject.AddComponent<MeshRenderer>();
    
                meshFilter.mesh = mesh;
                meshRenderer.material = new Material(Shader.Find("Standard"));
    } 

        // Generate cubes

    private void CreateCube(List<Vector3> vertices, List<int> triangles, Vector3Int position)
    {
        // Front face
        if (!IsCubeExists(position + new Vector3Int(0, 0, -1)))
        {
            int vertexIndex = vertices.Count;
            vertices.Add(new Vector3(position.x, position.y, position.z));
            vertices.Add(new Vector3(position.x + 1, position.y, position.z));
            vertices.Add(new Vector3(position.x, position.y + 1, position.z));
            vertices.Add(new Vector3(position.x + 1, position.y + 1, position.z));

            triangles.Add(vertexIndex + 0); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 2);
            triangles.Add(vertexIndex + 2); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 3);
        }

        // Top face
        if (!IsCubeExists(position + new Vector3Int(0, 1, 0)))
        {
            int vertexIndex = vertices.Count;
            vertices.Add(new Vector3(position.x, position.y + 1, position.z));
            vertices.Add(new Vector3(position.x + 1, position.y + 1, position.z));
            vertices.Add(new Vector3(position.x, position.y + 1, position.z + 1));
            vertices.Add(new Vector3(position.x + 1, position.y + 1, position.z + 1));

            triangles.Add(vertexIndex + 0); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 2);
            triangles.Add(vertexIndex + 2); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 3);
        }

        // Left face
        if (!IsCubeExists(position + new Vector3Int(-1, 0, 0)))
        {
            int vertexIndex = vertices.Count;
            vertices.Add(new Vector3(position.x, position.y, position.z));
            vertices.Add(new Vector3(position.x, position.y + 1, position.z));
            vertices.Add(new Vector3(position.x, position.y, position.z + 1));
            vertices.Add(new Vector3(position.x, position.y + 1, position.z + 1));

            triangles.Add(vertexIndex + 0); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 2);
            triangles.Add(vertexIndex + 2); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 3);
        }

        // Right face
        if (!IsCubeExists(position + new Vector3Int(1, 0, 0)))
        {
            int vertexIndex = vertices.Count;
            vertices.Add(new Vector3(position.x + 1, position.y, position.z));
            vertices.Add(new Vector3(position.x + 1, position.y + 1, position.z));
            vertices.Add(new Vector3(position.x + 1, position.y, position.z + 1));
            vertices.Add(new Vector3(position.x + 1, position.y + 1, position.z + 1));

            triangles.Add(vertexIndex + 0); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 2);
            triangles.Add(vertexIndex + 2); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 3);
        }

        // Back face
        if (!IsCubeExists(position + new Vector3Int(0, 0, 1)))
        {
            int vertexIndex = vertices.Count;
            vertices.Add(new Vector3(position.x, position.y, position.z + 1));
            vertices.Add(new Vector3(position.x + 1, position.y, position.z + 1));
            vertices.Add(new Vector3(position.x + 1, position.y + 1, position.z + 1));
            vertices.Add(new Vector3(position.x, position.y + 1, position.z + 1));

            triangles.Add(vertexIndex + 0); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 3);
            triangles.Add(vertexIndex + 3); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 2);
        }

        // Bottom face
        if (!IsCubeExists(position + new Vector3Int(0, -1, 0)))
        {
            int vertexIndex = vertices.Count;
            vertices.Add(new Vector3(position.x, position.y, position.z));
            vertices.Add(new Vector3(position.x + 1, position.y, position.z));
            vertices.Add(new Vector3(position.x, position.y, position.z + 1));
            vertices.Add(new Vector3(position.x + 1, position.y, position.z + 1));

            triangles.Add(vertexIndex + 0); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 2);
            triangles.Add(vertexIndex + 2); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 3);
        }
    }

    private bool IsCubeExists(Vector3Int position)
    {
        if (position.x < 0 || position.x >= world.chunkSize.x * world.worldSize.x ||
            position.y < 0 || position.y >= world.chunkSize.y * world.worldSize.y ||
            position.z < 0 || position.z >= world.chunkSize.z * world.worldSize.z)
        {
            return true;
        }

        return world.worldData[position.x, position.y, position.z] != 0;
    }
}