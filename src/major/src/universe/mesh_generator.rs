use super::{Voxel, VoxelVertex};
use std::collections::HashMap;

/// Trait for voxel mesh generation algorithms
pub trait MeshGenerator: Send + Sync {
    /// Generate a mesh from voxel data
    /// 
    /// # Arguments
    /// * `voxels` - Flattened voxel array (x + y*size + z*size*size indexing)
    /// * `size` - Dimension of the cubic chunk (size x size x size)
    /// 
    /// # Returns
    /// A tuple of (vertices, indices) representing the mesh
    fn generate_mesh(
        &self,
        voxels: &[Voxel],
        size: usize,
    ) -> Result<(Vec<VoxelVertex>, Vec<u32>), String>;
    
    /// Get the name of this mesh generator
    fn name(&self) -> &str;
}

/// Simple cube mesh generator that creates one quad per visible voxel face
pub struct SimpleCubeMeshGenerator;

impl SimpleCubeMeshGenerator {
    pub fn new() -> Self {
        Self
    }
    
    /// Check if a voxel position is within bounds and contains air
    fn is_air(&self, voxels: &[Voxel], size: usize, x: i32, y: i32, z: i32) -> bool {
        if x < 0 || y < 0 || z < 0 || x >= size as i32 || y >= size as i32 || z >= size as i32 {
            // Out of bounds is considered air
            return true;
        }
        
        let idx = x as usize + y as usize * size + z as usize * size * size;
        idx >= voxels.len() || voxels[idx].0 == 0
    }
    
    /// Get voxel color based on type
    fn get_voxel_color(&self, voxel_type: usize) -> [f32; 4] {
        match voxel_type {
            1 => [0.5, 0.5, 0.5, 1.0], // Stone - gray
            2 => [0.4, 0.3, 0.2, 1.0], // Dirt - brown
            3 => [0.2, 0.7, 0.3, 1.0], // Grass - green
            4 => [0.8, 0.6, 0.4, 1.0], // Sand - sandy
            5 => [0.3, 0.3, 0.8, 1.0], // Water - blue
            _ => [1.0, 0.0, 1.0, 1.0], // Unknown - magenta
        }
    }
}

impl MeshGenerator for SimpleCubeMeshGenerator {
    fn generate_mesh(
        &self,
        voxels: &[Voxel],
        size: usize,
    ) -> Result<(Vec<VoxelVertex>, Vec<u32>), String> {
        if voxels.is_empty() || size == 0 || size > 64 {
            return Ok((vec![], vec![]));
        }
        
        let mut vertices = Vec::new();
        let mut indices = Vec::new();
        
        // Iterate through all voxels
        for z in 0..size {
            for y in 0..size {
                for x in 0..size {
                    let idx = x + y * size + z * size * size;
                    if idx >= voxels.len() {
                        continue;
                    }
                    
                    let voxel = voxels[idx];
                    if voxel.0 == 0 {
                        // Skip air voxels
                        continue;
                    }
                    
                    let color = self.get_voxel_color(voxel.0);
                    let xi = x as i32;
                    let yi = y as i32;
                    let zi = z as i32;
                    
                    // Check each face and add if exposed to air
                    // For each face, we create one vertex with the face position and size
                    // The vertex shader will expand this to a quad
                    
                    // +X face (right)
                    if self.is_air(voxels, size, xi + 1, yi, zi) {
                        let base_idx = vertices.len() as u32;
                        vertices.push(VoxelVertex {
                            position: [(x + 1) as f32, y as f32, z as f32],
                            size: [1.0, 1.0],
                            normal_dir: 0, // +X
                            color,
                        });
                        // Single index per face for point rendering that gets expanded to quad
                        indices.push(base_idx);
                    }
                    
                    // -X face (left)
                    if self.is_air(voxels, size, xi - 1, yi, zi) {
                        let base_idx = vertices.len() as u32;
                        vertices.push(VoxelVertex {
                            position: [x as f32, y as f32, z as f32],
                            size: [1.0, 1.0],
                            normal_dir: 1, // -X
                            color,
                        });
                        indices.push(base_idx);
                    }
                    
                    // +Y face (back)
                    if self.is_air(voxels, size, xi, yi + 1, zi) {
                        let base_idx = vertices.len() as u32;
                        vertices.push(VoxelVertex {
                            position: [x as f32, (y + 1) as f32, z as f32],
                            size: [1.0, 1.0],
                            normal_dir: 2, // +Y
                            color,
                        });
                        indices.push(base_idx);
                    }
                    
                    // -Y face (front)
                    if self.is_air(voxels, size, xi, yi - 1, zi) {
                        let base_idx = vertices.len() as u32;
                        vertices.push(VoxelVertex {
                            position: [x as f32, y as f32, z as f32],
                            size: [1.0, 1.0],
                            normal_dir: 3, // -Y
                            color,
                        });
                        indices.push(base_idx);
                    }
                    
                    // +Z face (top)
                    if self.is_air(voxels, size, xi, yi, zi + 1) {
                        let base_idx = vertices.len() as u32;
                        vertices.push(VoxelVertex {
                            position: [x as f32, y as f32, (z + 1) as f32],
                            size: [1.0, 1.0],
                            normal_dir: 4, // +Z
                            color,
                        });
                        indices.push(base_idx);
                    }
                    
                    // -Z face (bottom)
                    if self.is_air(voxels, size, xi, yi, zi - 1) {
                        let base_idx = vertices.len() as u32;
                        vertices.push(VoxelVertex {
                            position: [x as f32, y as f32, z as f32],
                            size: [1.0, 1.0],
                            normal_dir: 5, // -Z
                            color,
                        });
                        indices.push(base_idx);
                    }
                }
            }
        }
        
        println!("SimpleCubeMeshGenerator: Generated {} vertices ({} faces) from {} non-air voxels",
            vertices.len(), vertices.len(), voxels.iter().filter(|v| v.0 != 0).count());
        
        Ok((vertices, indices))
    }
    
    fn name(&self) -> &str {
        "SimpleCube"
    }
}

/// Binary greedy mesh generator that merges adjacent faces
pub struct BinaryGreedyMeshGenerator;

impl BinaryGreedyMeshGenerator {
    pub fn new() -> Self {
        Self
    }
    
    /// Get voxel color based on type
    fn get_voxel_color(&self, voxel_type: usize) -> [f32; 4] {
        match voxel_type {
            1 => [0.5, 0.5, 0.5, 1.0], // Stone - gray
            2 => [0.4, 0.3, 0.2, 1.0], // Dirt - brown
            3 => [0.2, 0.7, 0.3, 1.0], // Grass - green
            4 => [0.8, 0.6, 0.4, 1.0], // Sand - sandy
            5 => [0.3, 0.3, 0.8, 1.0], // Water - blue
            _ => [1.0, 0.0, 1.0, 1.0], // Unknown - magenta
        }
    }
    
    fn greedy_mesh_binary_axis(
        &self,
        voxels: &[Voxel],
        size: usize,
        axis: usize,
        axis_cols: &Vec<Vec<u64>>,
        vertices: &mut Vec<VoxelVertex>,
        indices: &mut Vec<u32>,
    ) -> Result<(), String> {
        let u = (axis + 1) % 3;
        let v = (axis + 2) % 3;
        
        // For each face direction (negative and positive)
        for forward in [false, true] {
            // Create face masks by detecting solid->air transitions
            let mut face_masks = vec![vec![0u64; size]; size];
            
            for b in 0..size {
                for a in 0..size {
                    let col = axis_cols[a][b];
                    
                    if forward {
                        // Positive direction: current is solid AND next is air
                        face_masks[a][b] = col & !(col << 1);
                        // Also add faces at the boundary (last solid voxel)
                        if size < 64 {
                            face_masks[a][b] |= col & (1u64 << (size - 1));
                        }
                    } else {
                        // Negative direction: current is solid AND previous is air
                        face_masks[a][b] = col & !(col >> 1);
                        // Also add faces at the boundary (first solid voxel)
                        face_masks[a][b] |= col & 1u64;
                    }
                }
            }
            
            // Group faces by voxel type
            let mut type_masks: HashMap<u16, Vec<Vec<u64>>> = HashMap::new();
            
            for b in 0..size {
                for a in 0..size {
                    let mut col = face_masks[a][b];
                    
                    while col != 0 {
                        let bit_pos = col.trailing_zeros() as usize;
                        col &= col - 1; // Clear lowest bit
                        
                        // Get voxel position
                        let mut pos = [0; 3];
                        pos[axis] = bit_pos;
                        pos[u] = a;
                        pos[v] = b;
                        
                        let voxel_idx = pos[0] + pos[1] * size + pos[2] * size * size;
                        if voxel_idx >= voxels.len() {
                            continue;
                        }
                        
                        let voxel_type = voxels[voxel_idx].0;
                        
                        // Get or create mask for this voxel type
                        let type_mask = type_masks.entry(voxel_type as u16).or_insert_with(|| {
                            vec![vec![0u64; size]; size]
                        });
                        
                        // Set bit in the appropriate mask
                        type_mask[a][b] |= 1u64 << bit_pos;
                    }
                }
            }
            
            // Process each voxel type separately
            for (voxel_type, type_mask) in type_masks {
                // Process each layer along the axis
                for layer in 0..size {
                    let mut plane = vec![0u32; size];
                    
                    // Build binary plane for this layer
                    for b in 0..size {
                        for a in 0..size {
                            if (type_mask[a][b] >> layer) & 1 == 1 {
                                plane[a] |= 1u32 << b;
                            }
                        }
                    }
                    
                    // Skip empty planes
                    if plane.iter().all(|&row| row == 0) {
                        continue;
                    }
                    
                    // Greedy mesh this binary plane
                    let quads = self.greedy_mesh_binary_plane(&mut plane, size);
                    
                    // Convert quads to vertices
                    for quad in quads {
                        let mut position = [0.0; 3];
                        position[axis] = if forward {
                            (layer + 1) as f32
                        } else {
                            layer as f32
                        };
                        position[u] = quad.x as f32;
                        position[v] = quad.y as f32;
                        
                        let face_size = [quad.w as f32, quad.h as f32];
                        let normal_dir = match (axis, forward) {
                            (0, true) => 0,   // +X
                            (0, false) => 1,  // -X
                            (1, true) => 2,   // +Y
                            (1, false) => 3,  // -Y
                            (2, true) => 4,   // +Z
                            (2, false) => 5,  // -Z
                            _ => unreachable!(),
                        };
                        
                        let color = self.get_voxel_color(voxel_type as usize);
                        
                        vertices.push(VoxelVertex {
                            position,
                            size: face_size,
                            normal_dir: normal_dir as u32,
                            color,
                        });
                        
                        indices.push(vertices.len() as u32 - 1);
                    }
                }
            }
        }
        
        Ok(())
    }
    
    fn greedy_mesh_binary_plane(&self, plane: &mut [u32], size: usize) -> Vec<GreedyQuad> {
        let mut quads = Vec::new();
        
        for row in 0..size {
            let mut y = 0;
            
            while y < size as u32 {
                // Skip zeros to find start of solid run
                y += (plane[row] >> y).trailing_zeros();
                if y >= size as u32 {
                    break;
                }
                
                // Find height of solid run
                let h = (plane[row] >> y).trailing_ones();
                
                // Create mask for this height at this y position
                let h_mask = if h >= 32 { !0u32 } else { (1u32 << h) - 1 };
                let mask = h_mask << y;
                
                // Try to expand horizontally
                let mut w = 1;
                while row + w < size {
                    // Check if next row has the same pattern
                    let next_row_bits = (plane[row + w] >> y) & h_mask;
                    if next_row_bits != h_mask {
                        break;
                    }
                    w += 1;
                }
                
                // Clear the bits we've merged in ALL rows
                for r in 0..w {
                    plane[row + r] &= !mask;
                }
                
                quads.push(GreedyQuad {
                    x: row as u32,
                    y,
                    w: w as u32,
                    h,
                });
                
                y += h;
            }
        }
        
        quads
    }
}

impl MeshGenerator for BinaryGreedyMeshGenerator {
    fn generate_mesh(
        &self,
        voxels: &[Voxel],
        size: usize,
    ) -> Result<(Vec<VoxelVertex>, Vec<u32>), String> {
        if voxels.is_empty() || size == 0 || size > 64 {
            return Ok((vec![], vec![]));
        }
        
        let mut vertices = Vec::new();
        let mut indices = Vec::new();
        
        // Build binary columns for each axis
        let mut axis_cols = vec![vec![vec![0u64; size]; size]; 3];
        
        // Fill binary columns with correct indexing
        for z in 0..size {
            for y in 0..size {
                for x in 0..size {
                    let idx = x + y * size + z * size * size;
                    if idx < voxels.len() && voxels[idx].0 != 0 {
                        // For each axis, we store bits representing position along that axis
                        axis_cols[0][z][y] |= 1u64 << x; // X axis
                        axis_cols[1][z][x] |= 1u64 << y; // Y axis
                        axis_cols[2][y][x] |= 1u64 << z; // Z axis
                    }
                }
            }
        }
        
        // Process each axis
        for axis in 0..3 {
            self.greedy_mesh_binary_axis(
                voxels, size, axis, &axis_cols[axis],
                &mut vertices, &mut indices
            )?;
        }
        
        println!("BinaryGreedyMeshGenerator: Generated {} vertices from {} non-air voxels",
            vertices.len(), voxels.iter().filter(|v| v.0 != 0).count());
        
        Ok((vertices, indices))
    }
    
    fn name(&self) -> &str {
        "BinaryGreedy"
    }
}

// Helper struct for greedy meshing
struct GreedyQuad {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
}