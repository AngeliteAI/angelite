use crate::math::Vec3;
use super::sdf::{Sdf, Sphere, Box3, Plane};
use std::sync::Arc;

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
pub const SDF_SPHERE: u32 = 0;
pub const SDF_BOX: u32 = 1;
pub const SDF_PLANE: u32 = 2;
pub const SDF_CYLINDER: u32 = 3;
pub const SDF_TORUS: u32 = 4;
pub const SDF_CAPSULE: u32 = 5;
pub const SDF_CONE: u32 = 6;
pub const SDF_HEX_PRISM: u32 = 7;

pub const SDF_UNION: u32 = 100;
pub const SDF_INTERSECTION: u32 = 101;
pub const SDF_DIFFERENCE: u32 = 102;

pub struct SdfSerializer {
    nodes: Vec<GpuSdfNode>,
}

impl SdfSerializer {
    pub fn new() -> Self {
        Self { nodes: Vec::new() }
    }
    
    pub fn serialize_plane(&mut self, normal: Vec3<f32>, distance: f32) -> Vec<GpuSdfNode> {
        self.nodes.clear();
        
        let mut node = GpuSdfNode::default();
        node.node_type = SDF_PLANE;
        node.params[0][0] = normal.x();
        node.params[0][1] = normal.y();
        node.params[0][2] = normal.z();
        node.params[0][3] = distance;
        self.nodes.push(node);
        
        self.nodes.clone()
    }
}