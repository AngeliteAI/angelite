use super::{VertexPoolBatchRenderer, VoxelVertex, CompressedChunk, Voxel};
use crate::gfx::{Gfx, Mesh, Color};
use crate::math::{Vec3f, Vec3};
use std::sync::Arc;
use std::collections::HashMap;

/// Bridge between the universe voxel system and the graphics system
pub struct VoxelRendererBridge {
    gfx: Arc<dyn Gfx>,
    chunk_meshes: HashMap<u64, *const Mesh>,
    single_mesh: Option<*const Mesh>, // For combined mesh rendering
}

impl VoxelRendererBridge {
    pub fn new(gfx: Arc<dyn Gfx>) -> Self {
        Self {
            gfx,
            chunk_meshes: HashMap::new(),
            single_mesh: None,
        }
    }
    
    /// Process a compressed chunk and create/update its mesh
    pub async fn add_chunk(&mut self, chunk: CompressedChunk) -> Result<(), String> {
        let chunk_id = self.chunk_id_from_position(Vec3::new([
            chunk.position.x() as i32,
            chunk.position.y() as i32,
            chunk.position.z() as i32,
        ]));
        
        println!("Processing chunk at position {:?} for rendering", chunk.position);
        
        // Generate greedy mesh
        let (vertices, indices) = self.generate_greedy_mesh_for_chunk(&chunk).await?;
        
        if vertices.is_empty() {
            println!("No vertices generated for chunk");
            return Ok(());
        }
        
        println!("Generated {} vertices for chunk", vertices.len());
        
        // Get or create mesh
        let mesh = if let Some(&existing_mesh) = self.chunk_meshes.get(&chunk_id) {
            existing_mesh
        } else {
            let new_mesh = self.gfx.mesh_create();
            self.chunk_meshes.insert(chunk_id, new_mesh);
            new_mesh
        };
        
        // Convert VoxelVertex to separate arrays for the Gfx trait
        let positions: Vec<Vec3f> = vertices.iter()
            .map(|v| Vec3f::new(v.position))
            .collect();
            
        let normal_dirs: Vec<u32> = vertices.iter()
            .map(|v| v.normal_dir)
            .collect();
            
        let colors: Vec<Color> = vertices.iter()
            .map(|v| Color {
                r: v.color[0],
                g: v.color[1],
                b: v.color[2],
                a: v.color[3],
            })
            .collect();
            
        let sizes: Vec<[f32; 2]> = vertices.iter()
            .map(|v| v.size)
            .collect();
        
        // Update mesh data
        self.gfx.mesh_update_vertices(mesh, &positions);
        self.gfx.mesh_update_normal_dirs(mesh, &normal_dirs);
        self.gfx.mesh_update_albedo(mesh, &colors);
        self.gfx.mesh_update_face_sizes(mesh, &sizes);
        
        Ok(())
    }
    
    async fn generate_greedy_mesh_for_chunk(
        &self,
        chunk: &CompressedChunk,
    ) -> Result<(Vec<VoxelVertex>, Vec<u32>), String> {
        // Decompress chunk
        let chunk_size = 32; // Standard chunk size for this codebase
        
        let voxel_count = chunk_size * chunk_size * chunk_size;
        let compressed_data = super::palette_compression::CompressedVoxelData {
            palette: chunk.palette.clone(),
            bitpacked_data: super::palette_compression::BitpackedData {
                data: chunk.indices.data.clone(),
                bits_per_index: chunk.indices.bits_per_index,
                voxel_count,
            },
            dimensions: (chunk_size as u32, chunk_size as u32, chunk_size as u32),
            compression_ratio: 0.0,
        };
        
        let decompressed = super::palette_compression::VoxelDecompressor::decompress_chunk(&compressed_data);
        
        // Use the existing greedy mesh generation
        let renderer = VertexPoolBatchRenderer::new(self.gfx.clone());
        renderer.generate_greedy_mesh(&decompressed, chunk_size)
    }
    
    fn chunk_id_from_position(&self, position: Vec3<i32>) -> u64 {
        let x = position.x() as u64 & 0xFFFFF;
        let y = position.y() as u64 & 0xFFFFF;
        let z = position.z() as u64 & 0xFFFFF;
        (x << 40) | (y << 20) | z
    }
    
    pub fn render(&self) {
        // The meshes are automatically rendered by the Gfx system
        // when frame_commit_draw is called
    }
    
    pub fn cleanup(&mut self) {
        // Destroy all meshes
        for (_, &mesh) in &self.chunk_meshes {
            self.gfx.mesh_destroy(mesh);
        }
        self.chunk_meshes.clear();
        
        if let Some(mesh) = self.single_mesh {
            self.gfx.mesh_destroy(mesh);
            self.single_mesh = None;
        }
    }
    
    /// Update the single combined mesh with greedy mesh data
    /// This is used by synthesis for simplified rendering
    pub fn update_combined_mesh(
        &mut self,
        vertices: &[Vec3f],
        normal_dirs: &[u32],
        colors: &[Color],
        sizes: &[[f32; 2]],
    ) {
        // Get or create the single mesh
        let mesh = if let Some(existing) = self.single_mesh {
            existing
        } else {
            let new_mesh = self.gfx.mesh_create();
            self.single_mesh = Some(new_mesh);
            new_mesh
        };
        
        // Update mesh data
        self.gfx.mesh_update_vertices(mesh, vertices);
        self.gfx.mesh_update_normal_dirs(mesh, normal_dirs);
        self.gfx.mesh_update_albedo(mesh, colors);
        self.gfx.mesh_update_face_sizes(mesh, sizes);
    }
    
    /// Get the single mesh for rendering
    pub fn get_single_mesh(&self) -> Option<*const Mesh> {
        self.single_mesh
    }
}

impl Drop for VoxelRendererBridge {
    fn drop(&mut self) {
        self.cleanup();
    }
}