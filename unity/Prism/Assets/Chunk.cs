using System;
using UnityEngine;
using System.Collections.Generic;
using Unity.Collections;
using Unity.Jobs;
using Unity.Jobs.LowLevel.Unsafe;
using UnityEngine.Rendering;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class Chunk : MonoBehaviour
{
    public World world; 
    public NativeArray<int> data;
    public Vector3Int pos;
    JobHandle genHandle;

    public Vector3Int chunkPosition;
    private List<List<Vector3>> vertices = new List<List<Vector3>>();
    private List<List<int>> triangles = new List<List<int>>();
    private List<Material> materials = new List<Material>();
    
    public void Start()    
    {
            // Initialize data
                       data = new NativeArray<int>(
                           world.chunkSize.x * world.chunkSize.y * world.chunkSize.z, Allocator.Persistent);
           
                       int numBatches = Math.Max(1, JobsUtility.JobWorkerCount / 2);
                       int totalItems = data.Length;
                       int batchSize = totalItems / numBatches;
                        Debug.Log(totalItems + " / " + numBatches); 
                       var job = world.NewRegionGenJob();
                       job.data = data;
                       job.pos = pos;
                       genHandle = job.Schedule(data.Length, 64);
               

    }

    public void Update()
    {
        if (!genHandle.IsCompleted)
        {
            return;
        }
        genHandle.Complete();
        
        for (int z = 0; z < world.chunkSize.z; z++)
        {
            for (int y = 0; y < world.chunkSize.y; y++)
            {
                for (int x = 0; x < world.chunkSize.x; x++)
                {
                if (IsCubeExists(new Vector3Int(x,y,z)))
                {
                    CreateCube(new Vector3Int(x, y, z), 1);
                }
                }
            }
        }

        Mesh mesh = new Mesh();
        CombineSubmeshes(mesh);

        MeshFilter meshFilter = gameObject.GetComponent<MeshFilter>();
        MeshRenderer meshRenderer = gameObject.GetComponent<MeshRenderer>();

        meshFilter.mesh = mesh;
        meshRenderer.materials = materials.ToArray();
    }

    private void CreateCube(Vector3Int position, int blockId)
{
    int submeshIndex = GetOrCreateSubmeshIndex(blockId);
// Front face
if (!IsCubeExists(position + new Vector3Int(0, 0, 1)))
{
    int vertexIndex = vertices[submeshIndex].Count;
    vertices[submeshIndex].Add(new Vector3(position.x, position.y, position.z + 1));
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y, position.z + 1));
    vertices[submeshIndex].Add(new Vector3(position.x, position.y + 1, position.z + 1));
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y + 1, position.z + 1));

    triangles[submeshIndex].Add(vertexIndex + 0); triangles[submeshIndex].Add(vertexIndex + 1); triangles[submeshIndex].Add(vertexIndex + 2);
    triangles[submeshIndex].Add(vertexIndex + 2); triangles[submeshIndex].Add(vertexIndex + 1); triangles[submeshIndex].Add(vertexIndex + 3);
}

// Top face
if (!IsCubeExists(position + new Vector3Int(0, 1, 0)))
{
    int vertexIndex = vertices[submeshIndex].Count;
    vertices[submeshIndex].Add(new Vector3(position.x, position.y + 1, position.z));
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y + 1, position.z));
    vertices[submeshIndex].Add(new Vector3(position.x, position.y + 1, position.z + 1));
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y + 1, position.z + 1));

    triangles[submeshIndex].Add(vertexIndex + 0); triangles[submeshIndex].Add(vertexIndex + 2); triangles[submeshIndex].Add(vertexIndex + 1);
    triangles[submeshIndex].Add(vertexIndex + 2); triangles[submeshIndex].Add(vertexIndex + 3); triangles[submeshIndex].Add(vertexIndex + 1);
}

// Left face
if (!IsCubeExists(position + new Vector3Int(-1, 0, 0)))
{
    int vertexIndex = vertices[submeshIndex].Count;
    vertices[submeshIndex].Add(new Vector3(position.x, position.y, position.z));
    vertices[submeshIndex].Add(new Vector3(position.x, position.y + 1, position.z));
    vertices[submeshIndex].Add(new Vector3(position.x, position.y, position.z + 1));
    vertices[submeshIndex].Add(new Vector3(position.x, position.y + 1, position.z + 1));

    triangles[submeshIndex].Add(vertexIndex + 0); triangles[submeshIndex].Add(vertexIndex + 2); triangles[submeshIndex].Add(vertexIndex + 1);
    triangles[submeshIndex].Add(vertexIndex + 2); triangles[submeshIndex].Add(vertexIndex + 3); triangles[submeshIndex].Add(vertexIndex + 1);
}

// Right face
if (!IsCubeExists(position + new Vector3Int(1, 0, 0)))
{
    int vertexIndex = vertices[submeshIndex].Count;
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y, position.z));
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y + 1, position.z));
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y, position.z + 1));
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y + 1, position.z + 1));

    triangles[submeshIndex].Add(vertexIndex + 0); triangles[submeshIndex].Add(vertexIndex + 1); triangles[submeshIndex].Add(vertexIndex + 2);
    triangles[submeshIndex].Add(vertexIndex + 1); triangles[submeshIndex].Add(vertexIndex + 3); triangles[submeshIndex].Add(vertexIndex + 2);
}

// Back face
if (!IsCubeExists(position + new Vector3Int(0, 0, -1)))
{
    int vertexIndex = vertices[submeshIndex].Count;
    vertices[submeshIndex].Add(new Vector3(position.x, position.y, position.z));
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y, position.z));
    vertices[submeshIndex].Add(new Vector3(position.x, position.y + 1, position.z));
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y + 1, position.z));

    triangles[submeshIndex].Add(vertexIndex + 0); triangles[submeshIndex].Add(vertexIndex + 2); triangles[submeshIndex].Add(vertexIndex + 1);
    triangles[submeshIndex].Add(vertexIndex + 1); triangles[submeshIndex].Add(vertexIndex + 2); triangles[submeshIndex].Add(vertexIndex + 3);
}

// Bottom face
if (!IsCubeExists(position + new Vector3Int(0, -1, 0)))
{
    int vertexIndex = vertices[submeshIndex].Count;
    vertices[submeshIndex].Add(new Vector3(position.x, position.y, position.z));
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y, position.z));
    vertices[submeshIndex].Add(new Vector3(position.x, position.y, position.z + 1));
    vertices[submeshIndex].Add(new Vector3(position.x + 1, position.y, position.z + 1));

    triangles[submeshIndex].Add(vertexIndex + 0); triangles[submeshIndex].Add(vertexIndex + 1); triangles[submeshIndex].Add(vertexIndex + 2);
    triangles[submeshIndex].Add(vertexIndex + 2); triangles[submeshIndex].Add(vertexIndex + 1); triangles[submeshIndex].Add(vertexIndex + 3);
}

}

    private int GetOrCreateSubmeshIndex(int blockId)
    {
        for (int i = 0; i < materials.Count; i++)
        {
            if (materials[i].color == GetColorForBlockId(blockId))
            {
                return i;
            }
        }

        Material newMaterial = new Material(Shader.Find("Universal Render Pipeline/Lit"));
        newMaterial.color = GetColorForBlockId(blockId);
        materials.Add(newMaterial);
        vertices.Add(new List<Vector3>());
        triangles.Add(new List<int>());
        return materials.Count - 1;
    }

    private Color GetColorForBlockId(int blockId)
    {
        // Implement your logic here to return a color based on the block ID
        // For example:
        switch (blockId)
        {
            case 1: return Color.red;
            case 2: return Color.green;
            case 3: return Color.blue;
            // ... add more cases as needed
            default: return Color.gray;
        }
    }

    private void CombineSubmeshes(Mesh mesh)
    {
        List<Vector3> combinedVertices = new List<Vector3>();
        List<int> combinedTriangles = new List<int>();
        int vertexOffset = 0;

        for (int i = 0; i < vertices.Count; i++)
        {
            combinedVertices.AddRange(vertices[i]);
            for (int j = 0; j < triangles[i].Count; j++)
            {
                combinedTriangles.Add(triangles[i][j] + vertexOffset);
            }
            vertexOffset += vertices[i].Count;
        }

        mesh.subMeshCount = vertices.Count;
        mesh.vertices = combinedVertices.ToArray();
        mesh.triangles = combinedTriangles.ToArray();
        mesh.subMeshCount = vertices.Count;

        int submeshOffset = 0;
        for (int i = 0; i < vertices.Count; i++)
        {
            mesh.SetSubMesh(i, new SubMeshDescriptor(submeshOffset, triangles[i].Count)
            {
                bounds = new Bounds(Vector3.zero, Vector3.one * 1000)
            });
            submeshOffset += triangles[i].Count;
        }

        mesh.RecalculateNormals();
    }

    private bool IsCubeExists(Vector3Int position)
    {
        var s = world.chunkSize;
        if (position.y < 0)
        {
            return true;
        }
        if (position.x < 0 || position.x >= s.x || position.y >= s.y ||
            position.z < 0 || position.z >= s.z)
        {
            return false;
        }
        return data[position.x + s.x * (position.y + s.y * position.z)] != 0;
    }

}