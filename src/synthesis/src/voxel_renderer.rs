use major::{
    gfx::{Gfx, Mesh, Color},
    math::{Vec3f, Vec3},
    universe::{VoxelVertex, CompressedChunk, Voxel},
};
use std::sync::Arc;
use std::collections::HashMap;

/// Manages rendering of voxel chunks through the graphics system
pub struct VoxelChunkRenderer {
    gfx: Arc<dyn Gfx>,
    chunk_meshes: HashMap<ChunkId, ChunkMesh>,
    batch: *const major::gfx::Batch,
}

#[derive(Clone, Copy, Debug, Hash, Eq, PartialEq)]
pub struct ChunkId(pub i32, pub i32, pub i32);

struct ChunkMesh {
    mesh: *const Mesh,
    vertex_count: usize,
}

impl VoxelChunkRenderer {
    pub fn new(gfx: Arc<dyn Gfx>) -> Self {
        let batch = gfx.batch_create();
        Self {
            gfx,
            chunk_meshes: HashMap::new(),
            batch,
        }
    }
    
    /// Add or update a chunk's mesh
    pub fn update_chunk(
        &mut self,
        chunk_id: ChunkId,
        vertices: Vec<VoxelVertex>,
    ) {
        if vertices.is_empty() {
            // Remove empty chunks
            if let Some(chunk_mesh) = self.chunk_meshes.remove(&chunk_id) {
                self.gfx.batch_remove_mesh(self.batch, chunk_mesh.mesh);
                self.gfx.mesh_destroy(chunk_mesh.mesh);
            }
            return;
        }
        
        // Get or create mesh for this chunk
        let mesh = if let Some(chunk_mesh) = self.chunk_meshes.get(&chunk_id) {
            chunk_mesh.mesh
        } else {
            let new_mesh = self.gfx.mesh_create();
            self.gfx.batch_add_mesh(self.batch, new_mesh);
            self.chunk_meshes.insert(chunk_id, ChunkMesh {
                mesh: new_mesh,
                vertex_count: 0,
            });
            new_mesh
        };
        
        // Convert VoxelVertex data to separate arrays
        let positions: Vec<Vec3f> = vertices.iter()
            .map(|v| {
                // Add chunk offset to vertex position
                let chunk_offset = Vec3f::xyz(
                    chunk_id.0 as f32 * 32.0, // Assuming 32x32x32 chunks
                    chunk_id.1 as f32 * 32.0,
                    chunk_id.2 as f32 * 32.0,
                );
                Vec3f::xyz(v.position[0], v.position[1], v.position[2]) + chunk_offset
            })
            .collect();
            
        let normal_dirs: Vec<u32> = vertices.iter()
            .map(|v| v.normal_dir)
            .collect();
            
        let colors: Vec<Color> = vertices.iter()
            .map(|v| Color::new(v.color[0], v.color[1], v.color[2], v.color[3]))
            .collect();
            
        let sizes: Vec<[f32; 2]> = vertices.iter()
            .map(|v| v.size)
            .collect();
        
        // Update mesh data
        self.gfx.mesh_update_vertices(mesh, &positions);
        self.gfx.mesh_update_normal_dirs(mesh, &normal_dirs);
        self.gfx.mesh_update_albedo(mesh, &colors);
        self.gfx.mesh_update_face_sizes(mesh, &sizes);
        
        // Update vertex count
        if let Some(chunk_mesh) = self.chunk_meshes.get_mut(&chunk_id) {
            chunk_mesh.vertex_count = vertices.len();
        }
        
        println!("Updated chunk {:?} with {} vertices", chunk_id, vertices.len());
    }
    
    /// Get the batch for rendering
    pub fn get_batch(&self) -> *const major::gfx::Batch {
        self.batch
    }
    
    /// Clear all chunks
    pub fn clear(&mut self) {
        for (_, chunk_mesh) in self.chunk_meshes.drain() {
            self.gfx.batch_remove_mesh(self.batch, chunk_mesh.mesh);
            self.gfx.mesh_destroy(chunk_mesh.mesh);
        }
    }
}

impl Drop for VoxelChunkRenderer {
    fn drop(&mut self) {
        self.clear();
        self.gfx.batch_destroy(self.batch);
    }
}