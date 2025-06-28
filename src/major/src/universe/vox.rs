use crate::math::Vec3;
use std::collections::HashMap;
use crate::math::Vector;

pub struct Database {
    pub mapping: HashMap<Voxel, Attributes>,
}

pub struct Attributes {
    pub color: [f32; 4],
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
pub struct Voxel(pub usize);

pub enum Condition {
    Depth { min: f32, max: f32 },
    Height { min: f32, max: f32 },
    Slope { min: f32, max: f32 },
    Noise { seed: u64, threshold: f32, scale: f32 },
    Curvature { min: f32, max: f32 },
    Distance { point: Vec3<f32>, min: f32, max: f32 },
    And(Box<Condition>, Box<Condition>),
    Or(Box<Condition>, Box<Condition>),
    Not(Box<Condition>),
}

impl Condition {
    pub fn depth(min: f32, max: f32) -> Self {
        Self::Depth { min, max }
    }
    
    pub fn height(min: f32, max: f32) -> Self {
        Self::Height { min, max }
    }
    
    pub fn slope(min: f32, max: f32) -> Self {
        Self::Slope { min, max }
    }
    
    pub fn noise(seed: u64, threshold: f32, scale: f32) -> Self {
        Self::Noise { seed, threshold, scale }
    }
    
    pub fn curvature(min: f32, max: f32) -> Self {
        Self::Curvature { min, max }
    }
    
    pub fn distance(point: Vec3<f32>, min: f32, max: f32) -> Self {
        Self::Distance { point, min, max }
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
}

pub trait Volume<const AXIS_SIZE: usize> {
    fn voxel_get(&self, position: Vec3<i64>) -> Voxel;
    fn voxel_set(&self, position: Vec3<i64>, voxel: Voxel);
}

pub trait Brush {
    fn when(&mut self, condition: Condition, voxel: Voxel) -> &mut Self;
    fn layer(&mut self, next: impl Brush) -> impl Brush;
    fn scatter(&mut self, feature_brush: impl Brush, density: f32, seed: u64) -> impl Brush;
}

pub trait Sdf: Send + Sync {
    fn distance(&self, point: Vec3<f32>) -> f32;
}

pub struct Sphere {
    pub center: Vec3<f32>,
    pub radius: f32,
}

impl Sdf for Sphere {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        (point - self.center).length() - self.radius
    }
}

pub struct Box3 {
    pub center: Vec3<f32>,
    pub half_extents: Vec3<f32>,
}

impl Sdf for Box3 {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let q = (point - self.center).abs() - self.half_extents;
        q.max(Vec3::zero()).length() + q.x().max(q.y()).max(q.z()).min(0.0)
    }
}

pub struct Cylinder {
    pub base: Vec3<f32>,
    pub height: f32,
    pub radius: f32,
}

impl Sdf for Cylinder {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let p = point - self.base;
        let d = Vector([p.x(), 0.0, p.z()]).length() - self.radius;
        let h = (p.y().abs() - self.height * 0.5).max(0.0);
        (d.max(0.0).powi(2) + h.powi(2)).sqrt() + d.min(0.0).max(-h)
    }
}

pub struct Torus {
    pub center: Vec3<f32>,
    pub major_radius: f32,
    pub minor_radius: f32,
}

impl Sdf for Torus {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let p = point - self.center;
        let q = Vector([Vector([p.x(), 0.0, p.z()]).length() - self.major_radius, p.y(), 0.0]);
        q.length() - self.minor_radius
    }
}

pub struct Plane {
    pub normal: Vec3<f32>,
    pub distance: f32,
}

impl Sdf for Plane {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        point.dot(self.normal) + self.distance
    }
}

pub struct Union<A: Sdf, B: Sdf> {
    pub a: A,
    pub b: B,
}

impl<A: Sdf, B: Sdf> Sdf for Union<A, B> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        self.a.distance(point).min(self.b.distance(point))
    }
}

pub struct Intersection<A: Sdf, B: Sdf> {
    pub a: A,
    pub b: B,
}

impl<A: Sdf, B: Sdf> Sdf for Intersection<A, B> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        self.a.distance(point).max(self.b.distance(point))
    }
}

pub struct Difference<A: Sdf, B: Sdf> {
    pub a: A,
    pub b: B,
}

impl<A: Sdf, B: Sdf> Sdf for Difference<A, B> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        self.a.distance(point).max(-self.b.distance(point))
    }
}

pub struct SmoothUnion<A: Sdf, B: Sdf> {
    pub a: A,
    pub b: B,
    pub k: f32,
}

impl<A: Sdf, B: Sdf> Sdf for SmoothUnion<A, B> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let d1 = self.a.distance(point);
        let d2 = self.b.distance(point);
        let h = (0.5 + 0.5 * (d2 - d1) / self.k).clamp(0.0, 1.0);
        d2 * (1.0 - h) + d1 * h - self.k * h * (1.0 - h)
    }
}

pub struct Transform<S: Sdf> {
    pub sdf: S,
    pub position: Vec3<f32>,
    pub rotation: crate::math::Quaternion<f32>,
    pub scale: Vec3<f32>,
}

impl<S: Sdf> Sdf for Transform<S> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let inv_rot = self.rotation.conjugate();
        let local_point = inv_rot.rotate_vector((point - self.position) / self.scale);
        self.sdf.distance(local_point) * self.scale.min_element()
    }
}

// Builder methods for easier CSG construction
pub trait SdfOps: Sdf + Sized + 'static {
    fn union(self, other: impl Sdf + 'static) -> Box<dyn Sdf> {
        Box::new(DynUnion { a: Box::new(self), b: Box::new(other) })
    }
    
    fn intersection(self, other: impl Sdf + 'static) -> Box<dyn Sdf> {
        Box::new(DynIntersection { a: Box::new(self), b: Box::new(other) })
    }
    
    fn difference(self, other: impl Sdf + 'static) -> Box<dyn Sdf> {
        Box::new(DynDifference { a: Box::new(self), b: Box::new(other) })
    }
    
    fn smooth_union(self, other: impl Sdf + 'static, k: f32) -> Box<dyn Sdf> {
        Box::new(DynSmoothUnion { a: Box::new(self), b: Box::new(other), k })
    }
    
    fn transform(self, position: Vec3<f32>, rotation: crate::math::Quaternion<f32>, scale: Vec3<f32>) -> Box<dyn Sdf> {
        Box::new(DynTransform { sdf: Box::new(self), position, rotation, scale })
    }
}

impl<T: Sdf + 'static> SdfOps for T {}

// Extension methods for boxed SDFs
pub trait BoxedSdfOps {
    fn union(self, other: impl Sdf + 'static) -> Box<dyn Sdf>;
    fn intersection(self, other: impl Sdf + 'static) -> Box<dyn Sdf>;
    fn difference(self, other: impl Sdf + 'static) -> Box<dyn Sdf>;
    fn smooth_union(self, other: impl Sdf + 'static, k: f32) -> Box<dyn Sdf>;
    fn transform(self, position: Vec3<f32>, rotation: crate::math::Quaternion<f32>, scale: Vec3<f32>) -> Box<dyn Sdf>;
}

impl BoxedSdfOps for Box<dyn Sdf> {
    fn union(self, other: impl Sdf + 'static) -> Box<dyn Sdf> {
        Box::new(DynUnion { a: self, b: Box::new(other) })
    }
    
    fn intersection(self, other: impl Sdf + 'static) -> Box<dyn Sdf> {
        Box::new(DynIntersection { a: self, b: Box::new(other) })
    }
    
    fn difference(self, other: impl Sdf + 'static) -> Box<dyn Sdf> {
        Box::new(DynDifference { a: self, b: Box::new(other) })
    }
    
    fn smooth_union(self, other: impl Sdf + 'static, k: f32) -> Box<dyn Sdf> {
        Box::new(DynSmoothUnion { a: self, b: Box::new(other), k })
    }
    
    fn transform(self, position: Vec3<f32>, rotation: crate::math::Quaternion<f32>, scale: Vec3<f32>) -> Box<dyn Sdf> {
        Box::new(DynTransform { sdf: self, position, rotation, scale })
    }
}

// Dynamic CSG operations for boxed SDFs
pub struct DynUnion {
    pub a: Box<dyn Sdf>,
    pub b: Box<dyn Sdf>,
}

impl Sdf for DynUnion {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        self.a.distance(point).min(self.b.distance(point))
    }
}

pub struct DynIntersection {
    pub a: Box<dyn Sdf>,
    pub b: Box<dyn Sdf>,
}

impl Sdf for DynIntersection {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        self.a.distance(point).max(self.b.distance(point))
    }
}

pub struct DynDifference {
    pub a: Box<dyn Sdf>,
    pub b: Box<dyn Sdf>,
}

impl Sdf for DynDifference {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        self.a.distance(point).max(-self.b.distance(point))
    }
}

pub struct DynSmoothUnion {
    pub a: Box<dyn Sdf>,
    pub b: Box<dyn Sdf>,
    pub k: f32,
}

impl Sdf for DynSmoothUnion {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let d1 = self.a.distance(point);
        let d2 = self.b.distance(point);
        let h = (0.5 + 0.5 * (d2 - d1) / self.k).clamp(0.0, 1.0);
        d2 * (1.0 - h) + d1 * h - self.k * h * (1.0 - h)
    }
}

pub struct DynTransform {
    pub sdf: Box<dyn Sdf>,
    pub position: Vec3<f32>,
    pub rotation: crate::math::Quaternion<f32>,
    pub scale: Vec3<f32>,
}

impl Sdf for DynTransform {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let inv_rot = self.rotation.conjugate();
        let local_point = inv_rot.rotate_vector((point - self.position) / self.scale);
        self.sdf.distance(local_point) * self.scale.min_element()
    }
}

pub fn paint<B: Brush>(
    sdf: &dyn Sdf,
    size: (u32, u32, u32),
    brush: &mut B,
) -> Option<Box<dyn std::any::Any>> {
    // Implementation would apply the brush to the SDF
    // and generate material data
    todo!("Implement paint function")
}


pub struct Chunk {
    volume: Box<dyn Volume<{ Self::SIZE }>>,
}

impl Chunk {
    pub const SIZE: usize = 64;
}