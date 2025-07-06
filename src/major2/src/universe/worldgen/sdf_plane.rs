use crate::math::Vec3;
use crate::universe::{
    Voxel, WorldBounds, VoxelWorkspace, GenerationParams, BrushSchema,
    sdf::{Sdf, Plane},
    brush::{Brush, BrushLayer, Condition, BlendMode, EvaluationContext},
};
use std::sync::Arc;

/// Full SDF-based plane generator using the complete SDF and Brush system
pub struct SdfPlaneGenerator {
    plane_sdf: Plane,
    brush_schema: BrushSchema,
}

impl SdfPlaneGenerator {
    pub fn new() -> Self {
        // Create a plane at z=0 (Z-up convention)
        let plane_sdf = Plane {
            normal: Vec3::new([0.0, 0.0, 1.0]),
            distance: 0.0,
        };
        
        // Create brush layers for terrain generation
        let stone_layer = BrushLayer {
            condition: Condition::Depth { min: 2.0, max: f32::INFINITY },
            voxel: Voxel(1), // Stone
            blend_weight: 1.0,
            priority: 0,
        };
        
        let dirt_layer = BrushLayer {
            condition: Condition::Depth { min: 0.5, max: 2.0 },
            voxel: Voxel(2), // Dirt
            blend_weight: 1.0,
            priority: 1,
        };
        
        let grass_layer = BrushLayer {
            condition: Condition::Depth { min: -0.5, max: 0.5 }
                .and(Condition::Slope { min: 0.0, max: 30.0 }), // Only on relatively flat surfaces
            voxel: Voxel(3), // Grass
            blend_weight: 1.0,
            priority: 2,
        };
        
        let air_layer = BrushLayer {
            condition: Condition::Depth { min: f32::NEG_INFINITY, max: -0.5 }, // Above surface
            voxel: Voxel(0), // Air
            blend_weight: 1.0,
            priority: 3,
        };
        
        let brush_schema = BrushSchema {
            layers: vec![
                Arc::new(stone_layer),
                Arc::new(dirt_layer),
                Arc::new(grass_layer),
                Arc::new(air_layer),
            ],
            blend_mode: BlendMode::Replace,
        };
        
        Self {
            plane_sdf,
            brush_schema,
        }
    }
    
    pub async fn generate_world_region(
        &self,
        bounds: WorldBounds,
        params: GenerationParams,
    ) -> Result<VoxelWorkspace, String> {
        // This will be implemented through FFI to use GPU compute shaders
        // For now, provide the interface that will be called
        
        unsafe {
            let result = worldgen_generate_sdf_plane(
                self as *const Self,
                &bounds as *const WorldBounds,
                &params as *const GenerationParams,
            );
            
            if result.is_null() {
                return Err("Failed to generate SDF plane".to_string());
            }
            
            // Convert FFI result to VoxelWorkspace
            let workspace = std::ptr::read(result);
            worldgen_free_workspace(result);
            
            Ok(workspace)
        }
    }
}

// FFI declarations for Zig GPU worldgen
unsafe extern "C" {
    fn worldgen_generate_sdf_plane(
        generator: *const SdfPlaneGenerator,
        bounds: *const WorldBounds,
        params: *const GenerationParams,
    ) -> *mut VoxelWorkspace;
    
    fn worldgen_free_workspace(workspace: *mut VoxelWorkspace);
}


