using UnityEngine;
using System.Collections.Generic;

public class World : MonoBehaviour
{
    public int cubeSize = 1; // Size of each cube
    public Vector3Int worldSize = new Vector3Int(10, 10, 10); // Size of the world (number of cubes in each dimension)
    public float fillPercentage = 0.5f; // Percentage of cubes to generate (0.0 to 1.0)

    private bool[,,] worldData; // 3D boolean array to store world data

    private void Start()
    {
        GenerateWorld();
    }

    private void GenerateWorld()
    {
        GameObject worldObject = new GameObject("World");
        worldObject.transform.parent = transform;

        MeshFilter meshFilter = worldObject.AddComponent<MeshFilter>();
        MeshRenderer meshRenderer = worldObject.AddComponent<MeshRenderer>();

        List<Vector3> vertices = new List<Vector3>();
        List<int> triangles = new List<int>();

        // Initialize world data
        worldData = new bool[worldSize.x, worldSize.y, worldSize.z];
        for (int z = 0; z < worldSize.z; z++)
        {
            for (int y = 0; y < worldSize.y; y++)
            {
                for (int x = 0; x < worldSize.x; x++)
                {
                    worldData[x, y, z] = Random.value < fillPercentage;
                }
            }
        }

        // Generate cubes
        for (int z = 0; z < worldSize.z; z++)
        {
            for (int y = 0; y < worldSize.y; y++)
            {
                for (int x = 0; x < worldSize.x; x++)
                {
                    if (worldData[x, y, z])
                    {
                        CreateCube(vertices, triangles, new Vector3Int(x, y, z));
                    }
                }
            }
        }

        Mesh mesh = new Mesh();
        mesh.vertices = vertices.ToArray();
        mesh.triangles = triangles.ToArray();
        mesh.RecalculateNormals();

        meshFilter.mesh = mesh;
        meshRenderer.material = new Material(Shader.Find("Standard"));
    }

    private void CreateCube(List<Vector3> vertices, List<int> triangles, Vector3Int position)
    {
        int vertexIndex = vertices.Count;

        vertices.Add(position); // 0
        vertices.Add(new Vector3(position.x + 1, position.y, position.z)); // 1
        vertices.Add(new Vector3(position.x, position.y + 1, position.z)); // 2
        vertices.Add(new Vector3(position.x + 1, position.y + 1, position.z)); // 3
        vertices.Add(new Vector3(position.x, position.y, position.z + 1)); // 4
        vertices.Add(new Vector3(position.x + 1, position.y, position.z + 1)); // 5
        vertices.Add(new Vector3(position.x, position.y + 1, position.z + 1)); // 6
        vertices.Add(new Vector3(position.x + 1, position.y + 1, position.z + 1)); // 7

        // Front face
        if (!IsCubeExists(position + new Vector3Int(0, 0, -1)))
        {
            triangles.Add(vertexIndex + 0); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 2);
            triangles.Add(vertexIndex + 2); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 3);
        }

        // Top face
        if (!IsCubeExists(position + new Vector3Int(0, 1, 0)))
        {
            triangles.Add(vertexIndex + 2); triangles.Add(vertexIndex + 3); triangles.Add(vertexIndex + 6);
            triangles.Add(vertexIndex + 3); triangles.Add(vertexIndex + 7); triangles.Add(vertexIndex + 6);
        }

        // Left face
        if (!IsCubeExists(position + new Vector3Int(-1, 0, 0)))
        {
            triangles.Add(vertexIndex + 0); triangles.Add(vertexIndex + 4); triangles.Add(vertexIndex + 6);
            triangles.Add(vertexIndex + 0); triangles.Add(vertexIndex + 6); triangles.Add(vertexIndex + 2);
        }

        // Right face
        if (!IsCubeExists(position + new Vector3Int(1, 0, 0)))
        {
            triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 7); triangles.Add(vertexIndex + 5);
            triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 5); triangles.Add(vertexIndex + 3);
        }

        // Back face
        if (!IsCubeExists(position + new Vector3Int(0, 0, 1)))
        {
            triangles.Add(vertexIndex + 4); triangles.Add(vertexIndex + 5); triangles.Add(vertexIndex + 7);
            triangles.Add(vertexIndex + 4); triangles.Add(vertexIndex + 7); triangles.Add(vertexIndex + 6);
        }

        // Bottom face
        if (!IsCubeExists(position + new Vector3Int(0, -1, 0)))
        {
            triangles.Add(vertexIndex + 0); triangles.Add(vertexIndex + 1); triangles.Add(vertexIndex + 5);
            triangles.Add(vertexIndex + 0); triangles.Add(vertexIndex + 5); triangles.Add(vertexIndex + 4);
        }
    }

    private bool IsCubeExists(Vector3Int position)
    {
        if (position.x < 0 || position.x >= worldSize.x ||
            position.y < 0 || position.y >= worldSize.y ||
            position.z < 0 || position.z >= worldSize.z)
        {
            return false;
        }

        return worldData[position.x, position.y, position.z];
    }
}