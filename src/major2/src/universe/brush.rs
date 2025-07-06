use crate::math::Vec3;
use super::{Voxel, sdf::Sdf};
use std::sync::Arc;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum BlendMode {
    Replace,
    Mix,
    Add,
    Multiply,
    Min,
    Max,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum DistanceMetric {
    Euclidean,
    Manhattan,
    Chebyshev,
}

#[derive(Clone)]
pub enum Condition {
    // Basic spatial conditions
    Height { min: f32, max: f32 },
    Depth { min: f32, max: f32 },
    Distance { point: Vec3<f32>, min: f32, max: f32 },
    SdfDistance { min: f32, max: f32 },  // Distance from SDF surface
    
    // Surface property conditions
    Slope { min: f32, max: f32 },
    Curvature { min: f32, max: f32 },
    AmbientOcclusion { min: f32, max: f32, samples: u32 },
    
    // Noise-based conditions
    Noise3D {
        scale: f32,
        octaves: u32,
        persistence: f32,
        lacunarity: f32,
        threshold: f32,
        seed: u32,
    },
    
    VoronoiCell {
        scale: f32,
        cell_index: u32,
        distance_metric: DistanceMetric,
        seed: u32,
    },
    
    Turbulence {
        scale: f32,
        octaves: u32,
        threshold: f32,
        seed: u32,
    },
    
    // Pattern conditions
    Checkerboard {
        scale: f32,
        offset: Vec3<f32>,
    },
    
    Stripes {
        direction: Vec3<f32>,
        width: f32,
        offset: f32,
    },
    
    // Logical operations
    And(Box<Condition>, Box<Condition>),
    Or(Box<Condition>, Box<Condition>),
    Not(Box<Condition>),
    Xor(Box<Condition>, Box<Condition>),
    
    // Custom GPU conditions
    CustomGpu {
        shader_id: u32,
        parameters: Vec<f32>,
    },
    
    // SDF-based condition
    InsideSdf {
        sdf: Arc<dyn Sdf>,
        threshold: f32,
    },
}

impl std::fmt::Debug for Condition {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Height { min, max } => write!(f, "Height {{ min: {}, max: {} }}", min, max),
            Self::Depth { min, max } => write!(f, "Depth {{ min: {}, max: {} }}", min, max),
            Self::Distance { point, min, max } => write!(f, "Distance {{ point: {:?}, min: {}, max: {} }}", point, min, max),
            Self::SdfDistance { min, max } => write!(f, "SdfDistance {{ min: {}, max: {} }}", min, max),
            Self::Slope { min, max } => write!(f, "Slope {{ min: {}, max: {} }}", min, max),
            Self::Curvature { min, max } => write!(f, "Curvature {{ min: {}, max: {} }}", min, max),
            Self::AmbientOcclusion { min, max, samples } => write!(f, "AmbientOcclusion {{ min: {}, max: {}, samples: {} }}", min, max, samples),
            Self::Noise3D { scale, octaves, persistence, lacunarity, threshold, seed } => {
                write!(f, "Noise3D {{ scale: {}, octaves: {}, persistence: {}, lacunarity: {}, threshold: {}, seed: {} }}", 
                       scale, octaves, persistence, lacunarity, threshold, seed)
            }
            Self::VoronoiCell { scale, cell_index, distance_metric, seed } => {
                write!(f, "VoronoiCell {{ scale: {}, cell_index: {}, distance_metric: {:?}, seed: {} }}", 
                       scale, cell_index, distance_metric, seed)
            }
            Self::Turbulence { scale, octaves, threshold, seed } => {
                write!(f, "Turbulence {{ scale: {}, octaves: {}, threshold: {}, seed: {} }}", 
                       scale, octaves, threshold, seed)
            }
            Self::Checkerboard { scale, offset } => write!(f, "Checkerboard {{ scale: {}, offset: {:?} }}", scale, offset),
            Self::Stripes { direction, width, offset } => write!(f, "Stripes {{ direction: {:?}, width: {}, offset: {} }}", direction, width, offset),
            Self::And(left, right) => write!(f, "And({:?}, {:?})", left, right),
            Self::Or(left, right) => write!(f, "Or({:?}, {:?})", left, right),
            Self::Not(inner) => write!(f, "Not({:?})", inner),
            Self::Xor(left, right) => write!(f, "Xor({:?}, {:?})", left, right),
            Self::CustomGpu { shader_id, parameters } => write!(f, "CustomGpu {{ shader_id: {}, parameters: {:?} }}", shader_id, parameters),
            Self::InsideSdf { sdf: _, threshold } => write!(f, "InsideSdf {{ sdf: <Arc<dyn Sdf>>, threshold: {} }}", threshold),
        }
    }
}

impl Condition {
    // Builder methods for common conditions
    pub fn height(min: f32, max: f32) -> Self {
        Self::Height { min, max }
    }
    
    pub fn depth(min: f32, max: f32) -> Self {
        Self::Depth { min, max }
    }
    
    pub fn sdf_distance(min: f32, max: f32) -> Self {
        Self::SdfDistance { min, max }
    }
    
    pub fn slope(min: f32, max: f32) -> Self {
        Self::Slope { min, max }
    }
    
    pub fn noise(scale: f32, threshold: f32, seed: u32) -> Self {
        Self::Noise3D {
            scale,
            octaves: 1,
            persistence: 0.5,
            lacunarity: 2.0,
            threshold,
            seed,
        }
    }
    
    pub fn fractal_noise(scale: f32, octaves: u32, threshold: f32, seed: u32) -> Self {
        Self::Noise3D {
            scale,
            octaves,
            persistence: 0.5,
            lacunarity: 2.0,
            threshold,
            seed,
        }
    }
    
    pub fn voronoi(scale: f32, cell_index: u32, seed: u32) -> Self {
        Self::VoronoiCell {
            scale,
            cell_index,
            distance_metric: DistanceMetric::Euclidean,
            seed,
        }
    }
    
    pub fn and(self, other: Condition) -> Self {
        Self::And(Box::new(self), Box::new(other))
    }
    
    pub fn or(self, other: Condition) -> Self {
        Self::Or(Box::new(self), Box::new(other))
    }
    
    pub fn not(self) -> Self {
        Self::Not(Box::new(self))
    }
    
    pub fn xor(self, other: Condition) -> Self {
        Self::Xor(Box::new(self), Box::new(other))
    }
}

// Context for condition evaluation
#[derive(Clone, Debug)]
pub struct EvaluationContext {
    pub position: Vec3<f32>,
    pub sdf_value: f32,
    pub normal: Vec3<f32>,
    pub surface_position: Vec3<f32>,
    pub depth_from_surface: f32,
}

// Brush trait for applying voxels based on conditions
pub trait Brush: Send + Sync {
    fn sample(&self, context: &EvaluationContext) -> Option<(Voxel, f32)>;
    fn priority(&self) -> i32;
    fn blend_mode(&self) -> BlendMode;
    fn as_any(&self) -> &dyn std::any::Any;
}

// Single layer brush
#[derive(Clone)]
pub struct BrushLayer {
    pub condition: Condition,
    pub voxel: Voxel,
    pub blend_weight: f32,
    pub priority: i32,
}

impl Brush for BrushLayer {
    fn sample(&self, context: &EvaluationContext) -> Option<(Voxel, f32)> {
        if evaluate_condition(&self.condition, context) {
            Some((self.voxel, self.blend_weight))
        } else {
            None
        }
    }
    
    fn priority(&self) -> i32 {
        self.priority
    }
    
    fn blend_mode(&self) -> BlendMode {
        BlendMode::Mix
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Multi-layer brush with complex blending
#[derive(Clone)]
pub struct LayeredBrush {
    pub layers: Vec<BrushLayer>,
    pub blend_mode: BlendMode,
    pub global_weight: f32,
}

impl Brush for LayeredBrush {
    fn sample(&self, context: &EvaluationContext) -> Option<(Voxel, f32)> {
        let mut result: Option<(Voxel, f32)> = None;
        
        for layer in &self.layers {
            if let Some((voxel, weight)) = layer.sample(context) {
                result = match result {
                    None => Some((voxel, weight * self.global_weight)),
                    Some((prev_voxel, prev_weight)) => {
                        // Blend based on weights and priority
                        if layer.priority > prev_weight as i32 {
                            Some((voxel, weight * self.global_weight))
                        } else if layer.priority == prev_weight as i32 {
                            // Mix voxels based on weights
                            let total_weight = prev_weight + weight;
                            if total_weight > 0.0 {
                                // For now, just take the one with higher weight
                                if weight > prev_weight {
                                    Some((voxel, weight * self.global_weight))
                                } else {
                                    Some((prev_voxel, prev_weight * self.global_weight))
                                }
                            } else {
                                result
                            }
                        } else {
                            result
                        }
                    }
                };
            }
        }
        
        result
    }
    
    fn priority(&self) -> i32 {
        self.layers.iter().map(|l| l.priority).max().unwrap_or(0)
    }
    
    fn blend_mode(&self) -> BlendMode {
        self.blend_mode
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Biome-based brush
#[derive(Clone)]
pub struct BiomeBrush {
    pub temperature_range: (f32, f32),
    pub humidity_range: (f32, f32),
    pub altitude_range: (f32, f32),
    pub voxel: Voxel,
    pub blend_width: f32,
}

impl Brush for BiomeBrush {
    fn sample(&self, context: &EvaluationContext) -> Option<(Voxel, f32)> {
        // Calculate biome parameters from position
        let temperature = calculate_temperature(context.position);
        let humidity = calculate_humidity(context.position);
        let altitude = context.position.z();
        
        // Check if within biome ranges with smooth blending
        let temp_factor = smooth_range_check(temperature, self.temperature_range, self.blend_width);
        let humid_factor = smooth_range_check(humidity, self.humidity_range, self.blend_width);
        let alt_factor = smooth_range_check(altitude, self.altitude_range, self.blend_width);
        
        let weight = temp_factor * humid_factor * alt_factor;
        
        if weight > 0.0 {
            Some((self.voxel, weight))
        } else {
            None
        }
    }
    
    fn priority(&self) -> i32 {
        0
    }
    
    fn blend_mode(&self) -> BlendMode {
        BlendMode::Mix
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Structural brush for buildings and features
#[derive(Clone)]
pub struct StructuralBrush {
    pub structure_sdf: Arc<dyn Sdf>,
    pub wall_material: Voxel,
    pub fill_material: Option<Voxel>,
    pub wall_thickness: f32,
}

impl Brush for StructuralBrush {
    fn sample(&self, context: &EvaluationContext) -> Option<(Voxel, f32)> {
        let dist = self.structure_sdf.distance(context.position);
        
        if dist < 0.0 {
            // Inside structure
            if let Some(fill) = self.fill_material {
                Some((fill, 1.0))
            } else if dist > -self.wall_thickness {
                // Wall region
                Some((self.wall_material, 1.0))
            } else {
                None
            }
        } else if dist < self.wall_thickness {
            // Wall region outside
            Some((self.wall_material, 1.0))
        } else {
            None
        }
    }
    
    fn priority(&self) -> i32 {
        10 // High priority for structures
    }
    
    fn blend_mode(&self) -> BlendMode {
        BlendMode::Replace
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Transition brush for smooth material transitions
#[derive(Clone)]
pub struct TransitionBrush {
    pub material_a: Voxel,
    pub material_b: Voxel,
    pub transition_sdf: Arc<dyn Sdf>,
    pub transition_width: f32,
    pub transition_profile: TransitionProfile,
}

#[derive(Clone, Copy, Debug)]
pub enum TransitionProfile {
    Linear,
    Smooth,
    Cubic,
    Custom(fn(f32) -> f32),
}

impl Brush for TransitionBrush {
    fn sample(&self, context: &EvaluationContext) -> Option<(Voxel, f32)> {
        let dist = self.transition_sdf.distance(context.position);
        let normalized_dist = (dist + self.transition_width * 0.5) / self.transition_width;
        
        if normalized_dist >= 0.0 && normalized_dist <= 1.0 {
            let factor = match self.transition_profile {
                TransitionProfile::Linear => normalized_dist,
                TransitionProfile::Smooth => smoothstep(normalized_dist),
                TransitionProfile::Cubic => normalized_dist * normalized_dist * (3.0 - 2.0 * normalized_dist),
                TransitionProfile::Custom(f) => f(normalized_dist),
            };
            
            // Return material based on transition factor
            if factor < 0.5 {
                Some((self.material_a, 1.0 - factor * 2.0))
            } else {
                Some((self.material_b, (factor - 0.5) * 2.0))
            }
        } else if normalized_dist < 0.0 {
            Some((self.material_a, 1.0))
        } else {
            Some((self.material_b, 1.0))
        }
    }
    
    fn priority(&self) -> i32 {
        5
    }
    
    fn blend_mode(&self) -> BlendMode {
        BlendMode::Mix
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Scatter brush for vegetation and details
pub struct ScatterBrush {
    pub base_brush: Box<dyn Brush>,
    pub feature_brush: Box<dyn Brush>,
    pub density: f32,
    pub min_distance: f32,
    pub seed: u32,
}

impl Brush for ScatterBrush {
    fn sample(&self, context: &EvaluationContext) -> Option<(Voxel, f32)> {
        // First check base brush
        if let Some(base_result) = self.base_brush.sample(context) {
            // Check if we should place a feature here
            let hash = hash_position(context.position, self.seed);
            if hash < self.density {
                // Check minimum distance constraint using spatial hash
                if check_min_distance(context.position, self.min_distance, self.seed) {
                    // Try to place feature
                    if let Some(feature_result) = self.feature_brush.sample(context) {
                        return Some(feature_result);
                    }
                }
            }
            Some(base_result)
        } else {
            None
        }
    }
    
    fn priority(&self) -> i32 {
        self.base_brush.priority().max(self.feature_brush.priority())
    }
    
    fn blend_mode(&self) -> BlendMode {
        self.base_brush.blend_mode()
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Helper functions
fn evaluate_condition(condition: &Condition, context: &EvaluationContext) -> bool {
    match condition {
        Condition::Height { min, max } => {
            context.position.z() >= *min && context.position.z() <= *max
        }
        
        Condition::Depth { min, max } => {
            context.depth_from_surface >= *min && context.depth_from_surface <= *max
        }
        
        Condition::Distance { point, min, max } => {
            let dist = (context.position - *point).length();
            dist >= *min && dist <= *max
        }
        
        Condition::Slope { min, max } => {
            let slope_angle = context.normal.z().acos().to_degrees();
            slope_angle >= *min && slope_angle <= *max
        }
        
        Condition::Curvature { min, max } => {
            // Approximate curvature from SDF gradient
            let curvature = estimate_curvature(context);
            curvature >= *min && curvature <= *max
        }
        
        Condition::Noise3D { scale, octaves, persistence, lacunarity, threshold, seed } => {
            let noise_val = fractal_noise_3d(
                context.position * *scale,
                *octaves,
                *persistence,
                *lacunarity,
                *seed
            );
            noise_val > *threshold
        }
        
        Condition::VoronoiCell { scale, cell_index, distance_metric, seed } => {
            let (nearest_index, _) = voronoi_cell(
                context.position * *scale,
                *distance_metric,
                *seed
            );
            nearest_index == *cell_index
        }
        
        Condition::And(a, b) => {
            evaluate_condition(a, context) && evaluate_condition(b, context)
        }
        
        Condition::Or(a, b) => {
            evaluate_condition(a, context) || evaluate_condition(b, context)
        }
        
        Condition::Not(a) => {
            !evaluate_condition(a, context)
        }
        
        Condition::Xor(a, b) => {
            evaluate_condition(a, context) != evaluate_condition(b, context)
        }
        
        _ => true, // TODO: Implement remaining conditions
    }
}

fn estimate_curvature(context: &EvaluationContext) -> f32 {
    // Simple curvature estimation based on normal variation
    // In production, sample normals around the point
    0.0
}

fn fractal_noise_3d(
    pos: Vec3<f32>,
    octaves: u32,
    persistence: f32,
    lacunarity: f32,
    seed: u32
) -> f32 {
    let mut value = 0.0;
    let mut amplitude = 1.0;
    let mut frequency = 1.0;
    let mut max_value = 0.0;
    
    for i in 0..octaves {
        value += amplitude * simplex_noise_3d(pos * frequency, seed + i);
        max_value += amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }
    
    value / max_value
}

fn simplex_noise_3d(pos: Vec3<f32>, seed: u32) -> f32 {
    // Simplified noise function - in production use proper simplex noise
    let x = pos.x() + seed as f32 * 73.0;
    let y = pos.y() + seed as f32 * 131.0;
    let z = pos.z() + seed as f32 * 197.0;
    
    ((x.sin() * 43758.5453 + y.sin() * 12345.6789 + z.sin() * 98765.4321).sin() * 0.5 + 0.5).fract() * 2.0 - 1.0
}

fn voronoi_cell(pos: Vec3<f32>, metric: DistanceMetric, seed: u32) -> (u32, f32) {
    // Simple voronoi implementation
    let cell = pos.floor();
    let local = pos - cell;
    
    let mut min_dist = f32::MAX;
    let mut min_index = 0u32;
    
    for x in -1..=1 {
        for y in -1..=1 {
            for z in -1..=1 {
                let neighbor = cell + Vec3::new([x as f32, y as f32, z as f32]);
                let point = hash_to_point(neighbor, seed);
                let offset = Vec3::new([x as f32, y as f32, z as f32]) + point - local;
                
                let dist = match metric {
                    DistanceMetric::Euclidean => offset.length(),
                    DistanceMetric::Manhattan => offset.x().abs() + offset.y().abs() + offset.z().abs(),
                    DistanceMetric::Chebyshev => offset.x().abs().max(offset.y().abs()).max(offset.z().abs()),
                };
                
                if dist < min_dist {
                    min_dist = dist;
                    min_index = hash_cell_index(neighbor, seed);
                }
            }
        }
    }
    
    (min_index, min_dist)
}

fn hash_to_point(cell: Vec3<f32>, seed: u32) -> Vec3<f32> {
    let x = hash_float(cell.x() as u32, seed);
    let y = hash_float(cell.y() as u32, seed + 1);
    let z = hash_float(cell.z() as u32, seed + 2);
    Vec3::new([x, y, z])
}

fn hash_float(x: u32, seed: u32) -> f32 {
    let mut h = x.wrapping_add(seed);
    h = h.wrapping_mul(0x85ebca6b);
    h ^= h >> 13;
    h = h.wrapping_mul(0xc2b2ae35);
    h ^= h >> 16;
    (h & 0x7fffffff) as f32 / 0x7fffffff as f32
}

fn hash_cell_index(cell: Vec3<f32>, seed: u32) -> u32 {
    let mut h = (cell.x() as u32).wrapping_add((cell.y() as u32) << 16).wrapping_add((cell.z() as u32) << 8);
    h = h.wrapping_add(seed);
    h = h.wrapping_mul(0x85ebca6b);
    h ^= h >> 13;
    h = h.wrapping_mul(0xc2b2ae35);
    h ^= h >> 16;
    h
}

fn calculate_temperature(pos: Vec3<f32>) -> f32 {
    // Simple temperature model based on latitude and altitude
    let latitude_factor = (pos.z() * 0.01).cos();
    let altitude_factor = (-pos.y() * 0.001).exp();
    latitude_factor * altitude_factor * 30.0 + 10.0
}

fn calculate_humidity(pos: Vec3<f32>) -> f32 {
    // Simple humidity model
    simplex_noise_3d(pos * 0.01, 42) * 0.5 + 0.5
}

fn smooth_range_check(value: f32, range: (f32, f32), blend_width: f32) -> f32 {
    if value < range.0 - blend_width {
        0.0
    } else if value < range.0 {
        smoothstep((value - (range.0 - blend_width)) / blend_width)
    } else if value <= range.1 {
        1.0
    } else if value < range.1 + blend_width {
        smoothstep(1.0 - (value - range.1) / blend_width)
    } else {
        0.0
    }
}

fn smoothstep(x: f32) -> f32 {
    let x = x.clamp(0.0, 1.0);
    x * x * (3.0 - 2.0 * x)
}

fn hash_position(pos: Vec3<f32>, seed: u32) -> f32 {
    hash_float(
        (pos.x() * 73.0) as u32 ^ (pos.y() * 131.0) as u32 ^ (pos.z() * 197.0) as u32,
        seed
    )
}

fn check_min_distance(pos: Vec3<f32>, min_distance: f32, seed: u32) -> bool {
    // Simple spatial hash check - in production use proper spatial data structure
    true
}