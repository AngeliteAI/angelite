use super::brush::{Condition, Brush, BrushLayer, LayeredBrush, BiomeBrush, StructuralBrush, 
                   TransitionBrush, ScatterBrush, BlendMode};
use super::BrushSchema;
use crate::math::Vec3;
use std::sync::Arc;

// GPU instruction format matching shader
#[repr(C, align(16))]
#[derive(Clone, Copy, Debug)]
pub struct BrushInstruction {
    pub opcode: u32,
    pub padding1: [u32; 3],
    pub params: [[f32; 4]; 2],
}

// GPU brush layer format matching shader
#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct GpuBrushLayer {
    pub condition_start: u32,
    pub condition_count: u32,
    pub voxel_id: u32,
    pub blend_weight: f32,
    pub priority: i32,
}

pub struct BrushCompiler {
    instructions: Vec<BrushInstruction>,
}

impl BrushCompiler {
    pub fn new() -> Self {
        Self {
            instructions: Vec::new(),
        }
    }

    /// Compile a complete brush schema to GPU format
    pub fn compile_schema(&mut self, schema: &BrushSchema) -> Result<(Vec<u8>, Vec<u8>), String> {
        self.instructions.clear();
        let mut gpu_layers = Vec::new();

        // Compile each brush layer
        for brush in &schema.layers {
            let any = brush.as_any();
            
            if let Some(layered_brush) = any.downcast_ref::<LayeredBrush>() {
                // Handle LayeredBrush
                for layer in &layered_brush.layers {
                    let condition_start = self.instructions.len() as u32;
                    let condition_count = self.compile_condition(&layer.condition)?;
                    
                    gpu_layers.push(GpuBrushLayer {
                        condition_start,
                        condition_count,
                        voxel_id: layer.voxel.0 as u32,
                        blend_weight: layer.blend_weight * layered_brush.global_weight,
                        priority: layer.priority,
                    });
                }
            } else if let Some(brush_layer) = any.downcast_ref::<BrushLayer>() {
                // Handle single BrushLayer
                let condition_start = self.instructions.len() as u32;
                let condition_count = self.compile_condition(&brush_layer.condition)?;
                
                gpu_layers.push(GpuBrushLayer {
                    condition_start,
                    condition_count,
                    voxel_id: brush_layer.voxel.0 as u32,
                    blend_weight: brush_layer.blend_weight,
                    priority: brush_layer.priority,
                });
            } else if let Some(biome_brush) = any.downcast_ref::<BiomeBrush>() {
                // Handle BiomeBrush - convert to conditions
                let condition_start = self.instructions.len() as u32;
                
                // Create compound condition for biome ranges
                let temp_condition = Condition::Height { 
                    min: biome_brush.temperature_range.0, 
                    max: biome_brush.temperature_range.1 
                };
                let humid_condition = Condition::Noise3D {
                    scale: 0.01,
                    octaves: 1,
                    persistence: 0.5,
                    lacunarity: 2.0,
                    threshold: biome_brush.humidity_range.0,
                    seed: 42,
                };
                let alt_condition = Condition::Height {
                    min: biome_brush.altitude_range.0,
                    max: biome_brush.altitude_range.1,
                };
                
                // Combine conditions
                let combined = Condition::And(
                    Box::new(temp_condition),
                    Box::new(Condition::And(
                        Box::new(humid_condition),
                        Box::new(alt_condition)
                    ))
                );
                
                let condition_count = self.compile_condition(&combined)?;
                
                gpu_layers.push(GpuBrushLayer {
                    condition_start,
                    condition_count,
                    voxel_id: biome_brush.voxel.0 as u32,
                    blend_weight: 1.0,
                    priority: 0,
                });
            } else if let Some(structural_brush) = any.downcast_ref::<StructuralBrush>() {
                // Handle StructuralBrush
                let condition_start = self.instructions.len() as u32;
                
                // Use InsideSdf condition with threshold
                let condition = Condition::InsideSdf {
                    sdf: structural_brush.structure_sdf.clone(),
                    threshold: structural_brush.wall_thickness,
                };
                
                let condition_count = self.compile_condition(&condition)?;
                
                gpu_layers.push(GpuBrushLayer {
                    condition_start,
                    condition_count,
                    voxel_id: structural_brush.wall_material.0 as u32,
                    blend_weight: 1.0,
                    priority: 10, // High priority for structures
                });
                
                // Add fill material if present
                if let Some(fill) = structural_brush.fill_material {
                    let fill_condition = Condition::InsideSdf {
                        sdf: structural_brush.structure_sdf.clone(),
                        threshold: -structural_brush.wall_thickness,
                    };
                    
                    let condition_start = self.instructions.len() as u32;
                    let condition_count = self.compile_condition(&fill_condition)?;
                    
                    gpu_layers.push(GpuBrushLayer {
                        condition_start,
                        condition_count,
                        voxel_id: fill.0 as u32,
                        blend_weight: 1.0,
                        priority: 9, // Slightly lower than walls
                    });
                }
            } else if let Some(transition_brush) = any.downcast_ref::<TransitionBrush>() {
                // Handle TransitionBrush - create two layers with distance conditions
                let condition_a = Condition::InsideSdf {
                    sdf: transition_brush.transition_sdf.clone(),
                    threshold: -transition_brush.transition_width * 0.5,
                };
                
                let condition_start_a = self.instructions.len() as u32;
                let condition_count_a = self.compile_condition(&condition_a)?;
                
                gpu_layers.push(GpuBrushLayer {
                    condition_start: condition_start_a,
                    condition_count: condition_count_a,
                    voxel_id: transition_brush.material_a.0 as u32,
                    blend_weight: 1.0,
                    priority: 5,
                });
                
                let condition_b = Condition::Not(Box::new(Condition::InsideSdf {
                    sdf: transition_brush.transition_sdf.clone(),
                    threshold: transition_brush.transition_width * 0.5,
                }));
                
                let condition_start_b = self.instructions.len() as u32;
                let condition_count_b = self.compile_condition(&condition_b)?;
                
                gpu_layers.push(GpuBrushLayer {
                    condition_start: condition_start_b,
                    condition_count: condition_count_b,
                    voxel_id: transition_brush.material_b.0 as u32,
                    blend_weight: 1.0,
                    priority: 5,
                });
            } else if let Some(scatter_brush) = any.downcast_ref::<ScatterBrush>() {
                // Handle ScatterBrush - compile base brush first
                // This is a simplified approach - in practice you'd want more sophisticated scattering
                if let Some(base_layer) = scatter_brush.base_brush.as_any().downcast_ref::<BrushLayer>() {
                    let condition_start = self.instructions.len() as u32;
                    let condition_count = self.compile_condition(&base_layer.condition)?;
                    
                    gpu_layers.push(GpuBrushLayer {
                        condition_start,
                        condition_count,
                        voxel_id: base_layer.voxel.0 as u32,
                        blend_weight: base_layer.blend_weight,
                        priority: base_layer.priority,
                    });
                }
                
                // Add scattered features with noise condition
                if let Some(feature_layer) = scatter_brush.feature_brush.as_any().downcast_ref::<BrushLayer>() {
                    let scatter_condition = Condition::And(
                        Box::new(feature_layer.condition.clone()),
                        Box::new(Condition::Noise3D {
                            scale: 1.0 / scatter_brush.min_distance,
                            octaves: 1,
                            persistence: 0.5,
                            lacunarity: 2.0,
                            threshold: 1.0 - scatter_brush.density,
                            seed: scatter_brush.seed,
                        })
                    );
                    
                    let condition_start = self.instructions.len() as u32;
                    let condition_count = self.compile_condition(&scatter_condition)?;
                    
                    gpu_layers.push(GpuBrushLayer {
                        condition_start,
                        condition_count,
                        voxel_id: feature_layer.voxel.0 as u32,
                        blend_weight: feature_layer.blend_weight,
                        priority: feature_layer.priority + 1, // Slightly higher priority
                    });
                }
            } else {
                // If we encounter an unknown brush type, try to extract basic info
                // This ensures forward compatibility
                return Err(format!("Unsupported brush type: {:?}", std::any::type_name_of_val(&**brush)));
            }
        }

        // If no layers were compiled, fail deadly as requested
        if gpu_layers.is_empty() {
            panic!("FATAL: No brush layers were compiled. Synthesis must specify valid world generation parameters.");
        }

        // Convert to bytes
        let instructions_bytes = self.instructions_to_bytes();
        let layers_bytes = self.layers_to_bytes(&gpu_layers);

        Ok((instructions_bytes, layers_bytes))
    }

    /// Compile a single condition to GPU instructions
    fn compile_condition(&mut self, condition: &Condition) -> Result<u32, String> {
        let start_idx = self.instructions.len();
        self.compile_condition_recursive(condition)?;
        Ok((self.instructions.len() - start_idx) as u32)
    }

    fn compile_condition_recursive(&mut self, condition: &Condition) -> Result<(), String> {
        match condition {
            Condition::Height { min, max } => {
                self.instructions.push(BrushInstruction {
                    opcode: 0, // COND_HEIGHT
                    padding1: [0; 3],
                    params: [
                        [0.0, 0.0, 0.0, 0.0],
                        [*min, *max, 0.0, 0.0],
                    ],
                });
            }
            Condition::Depth { min, max } => {
                self.instructions.push(BrushInstruction {
                    opcode: 1, // COND_DEPTH
                    padding1: [0; 3],
                    params: [
                        [0.0, 0.0, 0.0, 0.0],
                        [*min, *max, 0.0, 0.0],
                    ],
                });
            }
            Condition::Distance { point, min, max } => {
                self.instructions.push(BrushInstruction {
                    opcode: 2, // COND_DISTANCE
                    padding1: [0; 3],
                    params: [
                        [point.x(), point.y(), point.z(), 0.0],
                        [*min, *max, 0.0, 0.0],
                    ],
                });
            }
            Condition::SdfDistance { min, max } => {
                // Use the COND_DISTANCE opcode with special marker to indicate SDF distance
                // When point is all zeros, it means use SDF distance
                self.instructions.push(BrushInstruction {
                    opcode: 2, // COND_DISTANCE
                    padding1: [0; 3],
                    params: [
                        [0.0, 0.0, 0.0, 0.0], // All zeros = use SDF distance
                        [*min, *max, 0.0, 0.0],
                    ],
                });
            }
            Condition::Slope { min, max } => {
                self.instructions.push(BrushInstruction {
                    opcode: 3, // COND_SLOPE
                    padding1: [0; 3],
                    params: [
                        [0.0, 0.0, 0.0, 0.0],
                        [*min, *max, 0.0, 0.0],
                    ],
                });
            }
            Condition::Curvature { min, max } => {
                self.instructions.push(BrushInstruction {
                    opcode: 4, // COND_CURVATURE
                    padding1: [0; 3],
                    params: [
                        [0.0, 0.0, 0.0, 0.0],
                        [*min, *max, 0.0, 0.0],
                    ],
                });
            }
            Condition::AmbientOcclusion { min, max, samples } => {
                self.instructions.push(BrushInstruction {
                    opcode: 5, // COND_AMBIENT_OCCLUSION
                    padding1: [0; 3],
                    params: [
                        [*samples as f32, 0.0, 0.0, 0.0],
                        [*min, *max, 0.0, 0.0],
                    ],
                });
            }
            Condition::Noise3D { scale, octaves, persistence, lacunarity, threshold, seed } => {
                self.instructions.push(BrushInstruction {
                    opcode: 6, // COND_NOISE_3D
                    padding1: [0; 3],
                    params: [
                        [*scale, *octaves as f32, *persistence, *lacunarity],
                        [*threshold, *seed as f32, 0.0, 0.0],
                    ],
                });
            }
            Condition::VoronoiCell { scale, cell_index, distance_metric: _, seed } => {
                self.instructions.push(BrushInstruction {
                    opcode: 7, // COND_VORONOI_CELL
                    padding1: [0; 3],
                    params: [
                        [*scale, *cell_index as f32, 0.0, 0.0],
                        [*seed as f32, 0.0, 0.0, 0.0],
                    ],
                });
            }
            Condition::Turbulence { scale, octaves, threshold, seed } => {
                self.instructions.push(BrushInstruction {
                    opcode: 8, // COND_TURBULENCE
                    padding1: [0; 3],
                    params: [
                        [*scale, *octaves as f32, 0.0, 0.0],
                        [*threshold, *seed as f32, 0.0, 0.0],
                    ],
                });
            }
            Condition::Checkerboard { scale, offset } => {
                self.instructions.push(BrushInstruction {
                    opcode: 9, // COND_CHECKERBOARD
                    padding1: [0; 3],
                    params: [
                        [*scale, offset.x(), offset.y(), offset.z()],
                        [0.0, 0.0, 0.0, 0.0],
                    ],
                });
            }
            Condition::Stripes { direction, width, offset } => {
                self.instructions.push(BrushInstruction {
                    opcode: 10, // COND_STRIPES
                    padding1: [0; 3],
                    params: [
                        [direction.x(), direction.y(), direction.z(), *width],
                        [*offset, 0.0, 0.0, 0.0],
                    ],
                });
            }
            Condition::And(left, right) => {
                self.instructions.push(BrushInstruction {
                    opcode: 20, // COND_AND
                    padding1: [0; 3],
                    params: [[0.0; 4], [0.0; 4]],
                });
                self.compile_condition_recursive(left)?;
                self.compile_condition_recursive(right)?;
            }
            Condition::Or(left, right) => {
                self.instructions.push(BrushInstruction {
                    opcode: 21, // COND_OR
                    padding1: [0; 3],
                    params: [[0.0; 4], [0.0; 4]],
                });
                self.compile_condition_recursive(left)?;
                self.compile_condition_recursive(right)?;
            }
            Condition::Not(inner) => {
                self.instructions.push(BrushInstruction {
                    opcode: 22, // COND_NOT
                    padding1: [0; 3],
                    params: [[0.0; 4], [0.0; 4]],
                });
                self.compile_condition_recursive(inner)?;
            }
            Condition::Xor(left, right) => {
                self.instructions.push(BrushInstruction {
                    opcode: 23, // COND_XOR
                    padding1: [0; 3],
                    params: [[0.0; 4], [0.0; 4]],
                });
                self.compile_condition_recursive(left)?;
                self.compile_condition_recursive(right)?;
            }
            Condition::InsideSdf { sdf, threshold } => {
                // For inside SDF, we store the threshold
                // The SDF itself needs to be serialized separately and referenced
                self.instructions.push(BrushInstruction {
                    opcode: 30, // COND_INSIDE_SDF
                    padding1: [0; 3],
                    params: [
                        [*threshold, 0.0, 0.0, 0.0],
                        [0.0, 0.0, 0.0, 0.0],
                    ],
                });
            }
            _ => {
                return Err(format!("Unsupported condition type: {:?}", condition));
            }
        }
        Ok(())
    }

    fn instructions_to_bytes(&self) -> Vec<u8> {
        if self.instructions.is_empty() {
            panic!("FATAL: No brush instructions compiled. World generation requires valid conditions.");
        }

        unsafe {
            std::slice::from_raw_parts(
                self.instructions.as_ptr() as *const u8,
                self.instructions.len() * std::mem::size_of::<BrushInstruction>()
            ).to_vec()
        }
    }

    fn layers_to_bytes(&self, layers: &[GpuBrushLayer]) -> Vec<u8> {
        if layers.is_empty() {
            panic!("FATAL: No brush layers to compile. World generation requires at least one layer.");
        }

        unsafe {
            std::slice::from_raw_parts(
                layers.as_ptr() as *const u8,
                layers.len() * std::mem::size_of::<GpuBrushLayer>()
            ).to_vec()
        }
    }
}