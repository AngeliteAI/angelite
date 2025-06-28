use crate::gfx::Gfx;
use super::Voxel;
use std::sync::Arc;
use std::collections::HashMap;

// Two-stage palette compression system
pub struct PaletteCompressionSystem {
    gfx: Arc<dyn Gfx>,
    palette_counter: PaletteCounter,
    bitpack_compressor: BitpackCompressor,
}

impl PaletteCompressionSystem {
    pub fn new(gfx: Arc<dyn Gfx>) -> Self {
        Self {
            palette_counter: PaletteCounter::new(gfx.clone()),
            bitpack_compressor: BitpackCompressor::new(gfx.clone()),
            gfx,
        }
    }
    
    pub async fn compress_workspace(
        &mut self,
        workspace: &[Voxel],
        dimensions: (u32, u32, u32),
    ) -> Result<CompressedVoxelData, String> {
        // Stage 1: Count unique voxels and build palette
        let (palette, unique_count) = self.palette_counter
            .count_unique_voxels(workspace)
            .await?;
        
        // Stage 2: Compress to bitpacked format
        let bitpacked_data = self.bitpack_compressor
            .compress_to_bitpacked(workspace, &palette)
            .await?;
        
        let compression_ratio = calculate_compression_ratio(workspace.len(), &bitpacked_data);
        
        Ok(CompressedVoxelData {
            palette,
            bitpacked_data,
            dimensions,
            compression_ratio,
        })
    }
}

#[derive(Clone, serde::Serialize, serde::Deserialize)]
pub struct CompressedVoxelData {
    pub palette: Vec<Voxel>,
    pub bitpacked_data: BitpackedData,
    pub dimensions: (u32, u32, u32),
    pub compression_ratio: f32,
}

#[derive(Clone, serde::Serialize, serde::Deserialize)]
pub struct BitpackedData {
    pub data: Vec<u8>,
    pub bits_per_index: u8,
    pub voxel_count: usize,
}

impl BitpackedData {
    pub fn get_index(&self, voxel_idx: usize) -> u8 {
        // Handle edge cases
        if voxel_idx >= self.voxel_count {
            return 0;
        }
        
        // Special case: if bits_per_index is 0 (single palette entry), all indices are 0
        if self.bits_per_index == 0 || self.data.is_empty() {
            return 0;
        }
        
        let bit_offset = voxel_idx * self.bits_per_index as usize;
        let byte_offset = bit_offset / 8;
        let bit_shift = bit_offset % 8;
        
        // Bounds check
        if byte_offset >= self.data.len() {
            return 0;
        }
        
        let mut value = 0u8;
        let mask = (1 << self.bits_per_index) - 1;
        
        // Read bits across byte boundaries if necessary
        if bit_shift + self.bits_per_index as usize <= 8 {
            // All bits in one byte
            value = (self.data[byte_offset] >> bit_shift) & mask;
        } else {
            // Bits span two bytes
            let bits_from_first = 8 - bit_shift;
            let bits_from_second = self.bits_per_index - bits_from_first as u8;
            
            value = (self.data[byte_offset] >> bit_shift) & ((1 << bits_from_first) - 1);
            if byte_offset + 1 < self.data.len() {
                value |= (self.data[byte_offset + 1] & ((1 << bits_from_second) - 1)) << bits_from_first;
            }
        }
        
        value
    }
    
    pub fn set_index(&mut self, voxel_idx: usize, palette_idx: u8) {
        let bit_offset = voxel_idx * self.bits_per_index as usize;
        let byte_offset = bit_offset / 8;
        let bit_shift = bit_offset % 8;
        
        let mask = (1 << self.bits_per_index) - 1;
        let value = palette_idx & mask;
        
        if bit_shift + self.bits_per_index as usize <= 8 {
            // All bits in one byte
            self.data[byte_offset] &= !(mask << bit_shift);
            self.data[byte_offset] |= value << bit_shift;
        } else {
            // Bits span two bytes
            let bits_from_first = 8 - bit_shift;
            let bits_from_second = self.bits_per_index - bits_from_first as u8;
            
            // Clear and set first byte
            self.data[byte_offset] &= !((1 << bits_from_first) - 1) << bit_shift;
            self.data[byte_offset] |= (value & ((1 << bits_from_first) - 1)) << bit_shift;
            
            // Clear and set second byte
            if byte_offset + 1 < self.data.len() {
                self.data[byte_offset + 1] &= !((1 << bits_from_second) - 1);
                self.data[byte_offset + 1] |= value >> bits_from_first;
            }
        }
    }
}

// Stage 1: Palette Counter
pub struct PaletteCounter {
    gfx: Arc<dyn Gfx>,
}

impl PaletteCounter {
    pub fn new(gfx: Arc<dyn Gfx>) -> Self {
        Self { gfx }
    }
    
    pub async fn count_unique_voxels(
        &mut self,
        workspace: &[Voxel],
    ) -> Result<(Vec<Voxel>, u32), String> {
        // For now, use CPU implementation
        // TODO: Implement GPU version
        
        let mut histogram = HashMap::new();
        for voxel in workspace {
            *histogram.entry(*voxel).or_insert(0u32) += 1;
        }
        
        // Sort by frequency (most common first)
        let mut palette: Vec<_> = histogram.into_iter()
            .map(|(voxel, count)| (voxel, count))
            .collect();
        palette.sort_by_key(|(_, count)| std::cmp::Reverse(*count));
        
        let unique_voxels: Vec<_> = palette.iter().map(|(v, _)| *v).collect();
        let unique_count = unique_voxels.len() as u32;
        
        Ok((unique_voxels, unique_count))
    }
}

// Stage 2: Bitpack Compressor
pub struct BitpackCompressor {
    gfx: Arc<dyn Gfx>,
}

impl BitpackCompressor {
    pub fn new(gfx: Arc<dyn Gfx>) -> Self {
        Self { gfx }
    }
    
    pub async fn compress_to_bitpacked(
        &mut self,
        workspace: &[Voxel],
        palette: &[Voxel],
    ) -> Result<BitpackedData, String> {
        // Calculate bits needed
        let bits_per_index = calculate_bits_needed(palette.len());
        
        // Create palette lookup
        let mut palette_lookup = HashMap::new();
        for (idx, voxel) in palette.iter().enumerate() {
            palette_lookup.insert(*voxel, idx as u8);
        }
        
        // Allocate bitpacked buffer
        let total_bits = workspace.len() * bits_per_index as usize;
        let total_bytes = (total_bits + 7) / 8;
        let mut data = vec![0u8; total_bytes];
        
        // Pack voxels
        let mut bitpacked = BitpackedData {
            data,
            bits_per_index,
            voxel_count: workspace.len(),
        };
        
        for (idx, voxel) in workspace.iter().enumerate() {
            if let Some(&palette_idx) = palette_lookup.get(voxel) {
                bitpacked.set_index(idx, palette_idx);
            }
        }
        
        Ok(bitpacked)
    }
}

// Decompression utilities
pub struct VoxelDecompressor;

impl VoxelDecompressor {
    pub fn decompress_chunk(compressed: &CompressedVoxelData) -> Vec<Voxel> {
        let mut decompressed = Vec::with_capacity(compressed.bitpacked_data.voxel_count);
        
        // Special case: single palette entry means all voxels are the same
        if compressed.palette.len() == 1 {
            let voxel = compressed.palette.get(0).copied().unwrap_or(Voxel(0));
            decompressed.resize(compressed.bitpacked_data.voxel_count, voxel);
            return decompressed;
        }
        
        for i in 0..compressed.bitpacked_data.voxel_count {
            let palette_idx = compressed.bitpacked_data.get_index(i) as usize;
            if palette_idx < compressed.palette.len() {
                decompressed.push(compressed.palette[palette_idx]);
            } else {
                decompressed.push(Voxel(0)); // Default/air voxel
            }
        }
        
        decompressed
    }
    
    pub fn decompress_region(
        compressed: &CompressedVoxelData,
        region_start: (u32, u32, u32),
        region_size: (u32, u32, u32),
    ) -> Vec<Voxel> {
        let mut decompressed = Vec::with_capacity(
            (region_size.0 * region_size.1 * region_size.2) as usize
        );
        
        for z in 0..region_size.2 {
            for y in 0..region_size.1 {
                for x in 0..region_size.0 {
                    let wx = region_start.0 + x;
                    let wy = region_start.1 + y;
                    let wz = region_start.2 + z;
                    
                    if wx < compressed.dimensions.0 && 
                       wy < compressed.dimensions.1 && 
                       wz < compressed.dimensions.2 {
                        let idx = (wz * compressed.dimensions.1 * compressed.dimensions.0 +
                                  wy * compressed.dimensions.0 + wx) as usize;
                        let palette_idx = compressed.bitpacked_data.get_index(idx) as usize;
                        
                        if palette_idx < compressed.palette.len() {
                            decompressed.push(compressed.palette[palette_idx]);
                        } else {
                            decompressed.push(Voxel(0));
                        }
                    } else {
                        decompressed.push(Voxel(0));
                    }
                }
            }
        }
        
        decompressed
    }
}

// Palette update system for dynamic modifications
pub struct PaletteUpdateSystem;

impl PaletteUpdateSystem {
    pub fn add_voxel_to_palette(
        compressed: &mut CompressedVoxelData,
        new_voxel: Voxel,
    ) -> Result<u8, String> {
        // Check if voxel already exists
        if let Some(idx) = compressed.palette.iter().position(|&v| v == new_voxel) {
            return Ok(idx as u8);
        }
        
        // Check if palette is full
        let max_palette_size = 1 << compressed.bitpacked_data.bits_per_index;
        if compressed.palette.len() >= max_palette_size {
            return Err("Palette is full, requires recompression".to_string());
        }
        
        // Add to palette
        compressed.palette.push(new_voxel);
        Ok((compressed.palette.len() - 1) as u8)
    }
    
    pub fn optimize_palette(compressed: &mut CompressedVoxelData) {
        // Count usage of each palette entry
        let mut usage_counts = vec![0u32; compressed.palette.len()];
        
        for i in 0..compressed.bitpacked_data.voxel_count {
            let palette_idx = compressed.bitpacked_data.get_index(i) as usize;
            if palette_idx < usage_counts.len() {
                usage_counts[palette_idx] += 1;
            }
        }
        
        // Create remapping based on usage frequency
        let mut indexed_counts: Vec<_> = usage_counts.iter()
            .enumerate()
            .map(|(idx, &count)| (idx, count))
            .collect();
        indexed_counts.sort_by_key(|(_, count)| std::cmp::Reverse(*count));
        
        // Build remapping table
        let mut remap = vec![0u8; compressed.palette.len()];
        for (new_idx, (old_idx, _)) in indexed_counts.iter().enumerate() {
            remap[*old_idx] = new_idx as u8;
        }
        
        // Reorder palette
        let mut new_palette = vec![Voxel(0); compressed.palette.len()];
        for (old_idx, &new_idx) in remap.iter().enumerate() {
            new_palette[new_idx as usize] = compressed.palette[old_idx];
        }
        compressed.palette = new_palette;
        
        // Remap all indices
        for i in 0..compressed.bitpacked_data.voxel_count {
            let old_idx = compressed.bitpacked_data.get_index(i);
            let new_idx = remap[old_idx as usize];
            compressed.bitpacked_data.set_index(i, new_idx);
        }
    }
}

// Helper functions
fn calculate_bits_needed(palette_size: usize) -> u8 {
    if palette_size <= 1 {
        1
    } else {
        (palette_size as f32).log2().ceil() as u8
    }
}

fn calculate_compression_ratio(original_size: usize, compressed: &BitpackedData) -> f32 {
    let original_bytes = original_size * std::mem::size_of::<Voxel>();
    let compressed_bytes = compressed.data.len();
    original_bytes as f32 / compressed_bytes as f32
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_bitpacking() {
        let mut bitpacked = BitpackedData {
            data: vec![0; 10],
            bits_per_index: 3,
            voxel_count: 20,
        };
        
        // Test setting and getting
        for i in 0..8 {
            bitpacked.set_index(i, i as u8);
            assert_eq!(bitpacked.get_index(i), i as u8);
        }
        
        // Test cross-byte boundaries
        bitpacked.set_index(2, 7);
        assert_eq!(bitpacked.get_index(2), 7);
    }
    
    #[test]
    fn test_compression() {
        // Create test data with repetition
        let workspace = vec![
            Voxel(1), Voxel(1), Voxel(2), Voxel(1),
            Voxel(3), Voxel(1), Voxel(2), Voxel(1),
        ];
        
        // Mock compression
        let palette = vec![Voxel(1), Voxel(2), Voxel(3)];
        let bits_per_index = 2; // Can represent 0-3
        
        assert_eq!(calculate_bits_needed(palette.len()), 2);
    }
}