use crate::math::{Vec3, Quaternion, Mat4f};
use super::sdf::*;
use super::brush::{Condition, BlendMode, DistanceMetric};
use std::sync::Arc;
use std::any::Any;

// GPU-compatible SDF node structure matching GLSL
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct GpuSdfNode {
    pub node_type: u32,
    pub _padding1: [u32; 3],
    pub params: [[f32; 4]; 4],
    pub children: [u32; 2],
    pub _padding2: [u32; 2],
}

impl Default for GpuSdfNode {
    fn default() -> Self {
        Self {
            node_type: 0,
            _padding1: [0; 3],
            params: [[0.0; 4]; 4],
            children: [0; 2],
            _padding2: [0; 2],
        }
    }
}

// SDF node types matching GLSL constants
// Primitives
pub const SDF_SPHERE: u32 = 0;
pub const SDF_BOX: u32 = 1;
pub const SDF_PLANE: u32 = 2;
pub const SDF_CYLINDER: u32 = 3;
pub const SDF_TORUS: u32 = 4;
pub const SDF_CAPSULE: u32 = 5;
pub const SDF_CONE: u32 = 6;
pub const SDF_HEX_PRISM: u32 = 7;

// CSG Operations
pub const SDF_UNION: u32 = 100;
pub const SDF_INTERSECTION: u32 = 101;
pub const SDF_DIFFERENCE: u32 = 102;
pub const SDF_SMOOTH_UNION: u32 = 103;
pub const SDF_SMOOTH_INTERSECTION: u32 = 104;
pub const SDF_SMOOTH_DIFFERENCE: u32 = 105;

// Transformations
pub const SDF_TRANSFORM: u32 = 200;
pub const SDF_TWIST: u32 = 201;
pub const SDF_BEND: u32 = 202;
pub const SDF_DISPLACEMENT: u32 = 203;

// Repetitions
pub const SDF_INFINITE_REPETITION: u32 = 300;
pub const SDF_FINITE_REPETITION: u32 = 301;

// Advanced
pub const SDF_FRACTAL_TERRAIN: u32 = 400;
pub const SDF_BEZIER: u32 = 401;

// Brush condition types
pub const CONDITION_HEIGHT: u32 = 1000;
pub const CONDITION_DEPTH: u32 = 1001;
pub const CONDITION_DISTANCE: u32 = 1002;
pub const CONDITION_SDF_DISTANCE: u32 = 1003;
pub const CONDITION_SLOPE: u32 = 1004;
pub const CONDITION_CURVATURE: u32 = 1005;
pub const CONDITION_NOISE3D: u32 = 1006;
pub const CONDITION_VORONOI: u32 = 1007;
pub const CONDITION_TURBULENCE: u32 = 1008;
pub const CONDITION_CHECKERBOARD: u32 = 1009;
pub const CONDITION_STRIPES: u32 = 1010;
pub const CONDITION_AND: u32 = 1100;
pub const CONDITION_OR: u32 = 1101;
pub const CONDITION_NOT: u32 = 1102;
pub const CONDITION_XOR: u32 = 1103;
pub const CONDITION_INSIDE_SDF: u32 = 1104;

// GPU-compatible brush condition node
#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct GpuConditionNode {
    pub condition_type: u32,
    pub _padding1: [u32; 3],
    pub params: [[f32; 4]; 2],
    pub children: [u32; 2],
    pub _padding2: [u32; 2],
}

impl Default for GpuConditionNode {
    fn default() -> Self {
        Self {
            condition_type: 0,
            _padding1: [0; 3],
            params: [[0.0; 4]; 2],
            children: [0; 2],
            _padding2: [0; 2],
        }
    }
}

// Serializer that handles all SDF types and brush conditions
pub struct SdfSerializer {
    sdf_nodes: Vec<GpuSdfNode>,
    condition_nodes: Vec<GpuConditionNode>,
}

impl SdfSerializer {
    pub fn new() -> Self {
        Self { 
            sdf_nodes: Vec::new(),
            condition_nodes: Vec::new(),
        }
    }
    
    pub fn serialize_sdf(&mut self, sdf: &dyn Sdf) -> Result<u32, String> {
        let node_index = self.sdf_nodes.len() as u32;
        let mut node = GpuSdfNode::default();
        
        // Use downcasting to handle all SDF types
        let any = sdf.as_any();
        
        // Primitives
        if let Some(sphere) = any.downcast_ref::<Sphere>() {
            node.node_type = SDF_SPHERE;
            node.params[0] = [sphere.center.x(), sphere.center.y(), sphere.center.z(), sphere.radius];
        } else if let Some(box3) = any.downcast_ref::<Box3>() {
            node.node_type = SDF_BOX;
            node.params[0] = [box3.center.x(), box3.center.y(), box3.center.z(), 0.0];
            node.params[1] = [box3.half_extents.x(), box3.half_extents.y(), box3.half_extents.z(), 0.0];
        } else if let Some(plane) = any.downcast_ref::<Plane>() {
            node.node_type = SDF_PLANE;
            node.params[0] = [plane.normal.x(), plane.normal.y(), plane.normal.z(), plane.distance];
        } else if let Some(cylinder) = any.downcast_ref::<Cylinder>() {
            node.node_type = SDF_CYLINDER;
            node.params[0] = [cylinder.base.x(), cylinder.base.y(), cylinder.base.z(), cylinder.height];
            node.params[1] = [cylinder.radius, 0.0, 0.0, 0.0];
        } else if let Some(torus) = any.downcast_ref::<Torus>() {
            node.node_type = SDF_TORUS;
            node.params[0] = [torus.center.x(), torus.center.y(), torus.center.z(), torus.major_radius];
            node.params[1] = [torus.minor_radius, 0.0, 0.0, 0.0];
        } else if let Some(capsule) = any.downcast_ref::<Capsule>() {
            node.node_type = SDF_CAPSULE;
            node.params[0] = [capsule.a.x(), capsule.a.y(), capsule.a.z(), capsule.radius];
            node.params[1] = [capsule.b.x(), capsule.b.y(), capsule.b.z(), 0.0];
        } else if let Some(cone) = any.downcast_ref::<Cone>() {
            node.node_type = SDF_CONE;
            node.params[0] = [cone.tip.x(), cone.tip.y(), cone.tip.z(), cone.radius];
            node.params[1] = [cone.base.x(), cone.base.y(), cone.base.z(), 0.0];
        } else if let Some(hex_prism) = any.downcast_ref::<HexPrism>() {
            node.node_type = SDF_HEX_PRISM;
            node.params[0] = [hex_prism.center.x(), hex_prism.center.y(), hex_prism.center.z(), hex_prism.radius];
            node.params[1] = [hex_prism.height, 0.0, 0.0, 0.0];
        }
        // CSG Operations (using dynamic variants)
        else if let Some(op) = any.downcast_ref::<DynUnion>() {
            node.node_type = SDF_UNION;
            node.children[0] = self.serialize_sdf(op.a.as_ref())?;
            node.children[1] = self.serialize_sdf(op.b.as_ref())?;
        } else if let Some(op) = any.downcast_ref::<DynIntersection>() {
            node.node_type = SDF_INTERSECTION;
            node.children[0] = self.serialize_sdf(op.a.as_ref())?;
            node.children[1] = self.serialize_sdf(op.b.as_ref())?;
        } else if let Some(op) = any.downcast_ref::<DynDifference>() {
            node.node_type = SDF_DIFFERENCE;
            node.children[0] = self.serialize_sdf(op.a.as_ref())?;
            node.children[1] = self.serialize_sdf(op.b.as_ref())?;
        } else if let Some(op) = any.downcast_ref::<DynSmoothUnion>() {
            node.node_type = SDF_SMOOTH_UNION;
            node.children[0] = self.serialize_sdf(op.a.as_ref())?;
            node.children[1] = self.serialize_sdf(op.b.as_ref())?;
            node.params[0][0] = op.k;
        }
        // Transformations
        else if let Some(op) = any.downcast_ref::<DynTransform>() {
            node.node_type = SDF_TRANSFORM;
            node.children[0] = self.serialize_sdf(op.sdf.as_ref())?;
            // Store position, rotation quaternion, and scale
            node.params[0] = [op.position.x(), op.position.y(), op.position.z(), 0.0];
            node.params[1] = [op.rotation.0[0], op.rotation.0[1], op.rotation.0[2], op.rotation.0[3]];
            node.params[2] = [op.scale.x(), op.scale.y(), op.scale.z(), 0.0];
        }
        // Advanced
        else if let Some(op) = any.downcast_ref::<FractalTerrain>() {
            node.node_type = SDF_FRACTAL_TERRAIN;
            node.children[0] = self.serialize_sdf(op.base_sdf.as_ref())?;
            node.params[0] = [op.octaves as f32, op.persistence, op.lacunarity, op.noise_scale];
        } else if let Some(op) = any.downcast_ref::<BezierSdf>() {
            node.node_type = SDF_BEZIER;
            node.params[0][0] = op.thickness;
            node.params[0][1] = op.control_points.len() as f32;
            // Store first few control points inline
            for i in 0..3.min(op.control_points.len()) {
                node.params[i+1] = [op.control_points[i].x(), op.control_points[i].y(), op.control_points[i].z(), 0.0];
            }
        } else {
            return Err(format!("Unsupported SDF type: {:?}", std::any::type_name_of_val(&sdf)));
        }
        
        self.sdf_nodes.push(node);
        Ok(node_index)
    }
    
    
    pub fn serialize_condition(&mut self, condition: &Condition) -> Result<u32, String> {
        let node_index = self.condition_nodes.len() as u32;
        let mut node = GpuConditionNode::default();
        
        match condition {
            Condition::Height { min, max } => {
                node.condition_type = CONDITION_HEIGHT;
                node.params[0] = [*min, *max, 0.0, 0.0];
            }
            Condition::Depth { min, max } => {
                node.condition_type = CONDITION_DEPTH;
                node.params[0] = [*min, *max, 0.0, 0.0];
            }
            Condition::Distance { point, min, max } => {
                node.condition_type = CONDITION_DISTANCE;
                node.params[0] = [point.x(), point.y(), point.z(), 0.0];
                node.params[1] = [*min, *max, 0.0, 0.0];
            }
            Condition::SdfDistance { min, max } => {
                node.condition_type = CONDITION_SDF_DISTANCE;
                node.params[0] = [*min, *max, 0.0, 0.0];
            }
            Condition::Slope { min, max } => {
                node.condition_type = CONDITION_SLOPE;
                node.params[0] = [*min, *max, 0.0, 0.0];
            }
            Condition::Curvature { min, max } => {
                node.condition_type = CONDITION_CURVATURE;
                node.params[0] = [*min, *max, 0.0, 0.0];
            }
            Condition::Noise3D { scale, octaves, persistence, lacunarity, threshold, seed } => {
                node.condition_type = CONDITION_NOISE3D;
                node.params[0] = [*scale, *octaves as f32, *persistence, *lacunarity];
                node.params[1] = [*threshold, *seed as f32, 0.0, 0.0];
            }
            Condition::VoronoiCell { scale, cell_index, distance_metric, seed } => {
                node.condition_type = CONDITION_VORONOI;
                node.params[0] = [*scale, *cell_index as f32, match distance_metric {
                    DistanceMetric::Euclidean => 0.0,
                    DistanceMetric::Manhattan => 1.0,
                    DistanceMetric::Chebyshev => 2.0,
                }, *seed as f32];
            }
            Condition::Turbulence { scale, octaves, threshold, seed } => {
                node.condition_type = CONDITION_TURBULENCE;
                node.params[0] = [*scale, *octaves as f32, *threshold, *seed as f32];
            }
            Condition::Checkerboard { scale, offset } => {
                node.condition_type = CONDITION_CHECKERBOARD;
                node.params[0] = [*scale, offset.x(), offset.y(), offset.z()];
            }
            Condition::Stripes { direction, width, offset } => {
                node.condition_type = CONDITION_STRIPES;
                node.params[0] = [direction.x(), direction.y(), direction.z(), *width];
                node.params[1] = [*offset, 0.0, 0.0, 0.0];
            }
            Condition::And(a, b) => {
                node.condition_type = CONDITION_AND;
                node.children[0] = self.serialize_condition(a)?;
                node.children[1] = self.serialize_condition(b)?;
            }
            Condition::Or(a, b) => {
                node.condition_type = CONDITION_OR;
                node.children[0] = self.serialize_condition(a)?;
                node.children[1] = self.serialize_condition(b)?;
            }
            Condition::Not(a) => {
                node.condition_type = CONDITION_NOT;
                node.children[0] = self.serialize_condition(a)?;
            }
            Condition::Xor(a, b) => {
                node.condition_type = CONDITION_XOR;
                node.children[0] = self.serialize_condition(a)?;
                node.children[1] = self.serialize_condition(b)?;
            }
            Condition::InsideSdf { sdf, threshold } => {
                node.condition_type = CONDITION_INSIDE_SDF;
                node.params[0][0] = *threshold;
                // Note: SDF serialization would need to be handled separately
            }
            _ => return Err("Unsupported condition type".to_string()),
        }
        
        self.condition_nodes.push(node);
        Ok(node_index)
    }
    
    pub fn get_sdf_nodes(&self) -> &[GpuSdfNode] {
        &self.sdf_nodes
    }
    
    pub fn get_condition_nodes(&self) -> &[GpuConditionNode] {
        &self.condition_nodes
    }
}

// Utility function to serialize SDF tree for GPU
pub fn serialize_sdf_tree(sdf: &dyn Sdf) -> Result<Vec<GpuSdfNode>, String> {
    let mut serializer = SdfSerializer::new();
    serializer.serialize_sdf(sdf)?;
    Ok(serializer.sdf_nodes)
}