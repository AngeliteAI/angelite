use crate::math::{Vec3, Vector, Quaternion, Mat4f};
use std::sync::Arc;

// Enhanced SDF trait with normal calculation
pub trait Sdf: Send + Sync {
    fn distance(&self, point: Vec3<f32>) -> f32;
    
    /// Get a reference to self as Any for downcasting
    fn as_any(&self) -> &dyn std::any::Any;
    
    fn normal(&self, point: Vec3<f32>) -> Vec3<f32> {
        const EPSILON: f32 = 0.001;
        let dx = self.distance(point + Vec3::new([EPSILON, 0.0, 0.0])) - self.distance(point - Vec3::new([EPSILON, 0.0, 0.0]));
        let dy = self.distance(point + Vec3::new([0.0, EPSILON, 0.0])) - self.distance(point - Vec3::new([0.0, EPSILON, 0.0]));
        let dz = self.distance(point + Vec3::new([0.0, 0.0, EPSILON])) - self.distance(point - Vec3::new([0.0, 0.0, EPSILON]));
        Vec3::new([dx, dy, dz]).normalize()
    }
    
    fn gradient(&self, point: Vec3<f32>) -> Vec3<f32> {
        const H: f32 = 0.001;
        let dx = self.distance(point + Vec3::new([H, 0.0, 0.0])) - self.distance(point - Vec3::new([H, 0.0, 0.0]));
        let dy = self.distance(point + Vec3::new([0.0, H, 0.0])) - self.distance(point - Vec3::new([0.0, H, 0.0]));
        let dz = self.distance(point + Vec3::new([0.0, 0.0, H])) - self.distance(point - Vec3::new([0.0, 0.0, H]));
        Vec3::new([dx, dy, dz]) / (2.0 * H)
    }
}

// Basic primitives with optimized distance functions
pub struct Sphere {
    pub center: Vec3<f32>,
    pub radius: f32,
}

impl Sdf for Sphere {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        (point - self.center).length() - self.radius
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
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
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct Plane {
    pub normal: Vec3<f32>,
    pub distance: f32,
}

impl Sdf for Plane {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        point.dot(self.normal) - self.distance
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
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
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
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
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Advanced primitives
pub struct Capsule {
    pub a: Vec3<f32>,
    pub b: Vec3<f32>,
    pub radius: f32,
}

impl Sdf for Capsule {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let pa = point - self.a;
        let ba = self.b - self.a;
        let h = pa.dot(ba) / ba.dot(ba);
        let h_clamped = h.clamp(0.0, 1.0);
        (pa - ba * h_clamped).length() - self.radius
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct Cone {
    pub tip: Vec3<f32>,
    pub base: Vec3<f32>,
    pub radius: f32,
}

impl Sdf for Cone {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let ba = self.base - self.tip;
        let pa = point - self.tip;
        let baba = ba.dot(ba);
        let paba = pa.dot(ba) / baba;
        let x = (pa - ba * paba).length();
        let cax = (self.radius - self.radius * paba).max(0.0);
        let cay = if paba < 0.5 { -1.0 } else { 1.0 } * baba.sqrt() * paba * (1.0 - paba);
        let k = (cax * cax + cay * cay).sqrt();
        let f = x - cax * self.radius / k;
        let g = x.hypot(pa.z() - ba.length()).min(x.hypot(pa.z()));
        if paba < 0.0 || paba > 1.0 { g } else { f.min(0.0).max(g) }
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct HexPrism {
    pub center: Vec3<f32>,
    pub radius: f32,
    pub height: f32,
}

impl Sdf for HexPrism {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let p = (point - self.center).abs();
        let k = Vec3::new([-0.8660254, 0.5, 0.57735]);
        let p_xy = Vec3::new([p.x(), p.y(), 0.0]);
        let p_k = Vec3::new([k.x() * p.x() + k.y() * p.y(), k.z() * p.y(), 0.0]);
        let d1 = (p_xy - Vec3::new([k.x(), k.y(), 0.0]) * (2.0 * p_k.x().min(0.0))).length() - self.radius;
        let d2 = p.z() - self.height * 0.5;
        d1.max(d2.abs())
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// CSG Operations
pub struct Union<A: Sdf, B: Sdf> {
    pub a: A,
    pub b: B,
}

impl<A: Sdf + 'static, B: Sdf + 'static> Sdf for Union<A, B> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        self.a.distance(point).min(self.b.distance(point))
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct Intersection<A: Sdf, B: Sdf> {
    pub a: A,
    pub b: B,
}

impl<A: Sdf + 'static, B: Sdf + 'static> Sdf for Intersection<A, B> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        self.a.distance(point).max(self.b.distance(point))
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct Difference<A: Sdf, B: Sdf> {
    pub a: A,
    pub b: B,
}

impl<A: Sdf + 'static, B: Sdf + 'static> Sdf for Difference<A, B> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        self.a.distance(point).max(-self.b.distance(point))
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct SmoothUnion<A: Sdf, B: Sdf> {
    pub a: A,
    pub b: B,
    pub k: f32,
}

impl<A: Sdf + 'static, B: Sdf + 'static> Sdf for SmoothUnion<A, B> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let d1 = self.a.distance(point);
        let d2 = self.b.distance(point);
        let h = (0.5 + 0.5 * (d2 - d1) / self.k).clamp(0.0, 1.0);
        d2 * (1.0 - h) + d1 * h - self.k * h * (1.0 - h)
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct SmoothIntersection<A: Sdf, B: Sdf> {
    pub a: A,
    pub b: B,
    pub k: f32,
}

impl<A: Sdf + 'static, B: Sdf + 'static> Sdf for SmoothIntersection<A, B> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let d1 = self.a.distance(point);
        let d2 = self.b.distance(point);
        let h = (0.5 - 0.5 * (d2 - d1) / self.k).clamp(0.0, 1.0);
        d2 * h + d1 * (1.0 - h) + self.k * h * (1.0 - h)
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct SmoothDifference<A: Sdf, B: Sdf> {
    pub a: A,
    pub b: B,
    pub k: f32,
}

impl<A: Sdf + 'static, B: Sdf + 'static> Sdf for SmoothDifference<A, B> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let d1 = self.a.distance(point);
        let d2 = -self.b.distance(point);
        let h = (0.5 - 0.5 * (d2 + d1) / self.k).clamp(0.0, 1.0);
        d2 * h + d1 * (1.0 - h) + self.k * h * (1.0 - h)
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Transformations
pub struct Transform<S: Sdf> {
    pub sdf: S,
    pub position: Vec3<f32>,
    pub rotation: Quaternion<f32>,
    pub scale: Vec3<f32>,
}

impl<S: Sdf + 'static> Sdf for Transform<S> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let inv_rot = self.rotation.conjugate();
        let local_point = inv_rot.rotate_vector((point - self.position) / self.scale);
        self.sdf.distance(local_point) * self.scale.min_element()
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Deformations
pub struct Twist<S: Sdf> {
    pub sdf: S,
    pub amount: f32,
}

impl<S: Sdf + 'static> Sdf for Twist<S> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let k = self.amount * point.y();
        let c = k.cos();
        let s = k.sin();
        let q = Vec3::new([c * point.x() - s * point.z(), point.y(), s * point.x() + c * point.z()]);
        self.sdf.distance(q)
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct Bend<S: Sdf> {
    pub sdf: S,
    pub amount: f32,
}

impl<S: Sdf + 'static> Sdf for Bend<S> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let k = self.amount * point.x();
        let c = k.cos();
        let s = k.sin();
        let q = Vec3::new([point.x(), c * point.y() - s * point.z(), s * point.y() + c * point.z()]);
        self.sdf.distance(q)
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct Displacement<S: Sdf, F: Fn(Vec3<f32>) -> f32 + Send + Sync> {
    pub sdf: S,
    pub displacement: F,
}

impl<S: Sdf + 'static, F: Fn(Vec3<f32>) -> f32 + Send + Sync + 'static> Sdf for Displacement<S, F> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        self.sdf.distance(point) + (self.displacement)(point)
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Repetition
pub struct InfiniteRepetition<S: Sdf> {
    pub sdf: S,
    pub period: Vec3<f32>,
}

impl<S: Sdf + 'static> Sdf for InfiniteRepetition<S> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let q = Vec3::new([
            point.x() % self.period.x() - 0.5 * self.period.x(),
            point.y() % self.period.y() - 0.5 * self.period.y(),
            point.z() % self.period.z() - 0.5 * self.period.z(),
        ]);
        self.sdf.distance(q)
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct FiniteRepetition<S: Sdf> {
    pub sdf: S,
    pub period: Vec3<f32>,
    pub count: Vec3<i32>,
}

impl<S: Sdf + 'static> Sdf for FiniteRepetition<S> {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let id = (point / self.period).round();
        let clamped_id = Vec3::new([
            id.x().clamp(0.0, (self.count.x() - 1) as f32),
            id.y().clamp(0.0, (self.count.y() - 1) as f32),
            id.z().clamp(0.0, (self.count.z() - 1) as f32),
        ]);
        let q = point - clamped_id * self.period;
        self.sdf.distance(q)
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Advanced SDFs
pub struct FractalTerrain {
    pub base_sdf: Box<dyn Sdf>,
    pub octaves: u32,
    pub persistence: f32,
    pub lacunarity: f32,
    pub noise_scale: f32,
}

impl Sdf for FractalTerrain {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let mut d = self.base_sdf.distance(point);
        let mut amplitude = 1.0;
        let mut frequency = self.noise_scale;
        
        for _ in 0..self.octaves {
            d += amplitude * simplex_noise_3d(point * frequency);
            amplitude *= self.persistence;
            frequency *= self.lacunarity;
        }
        
        d
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct BezierSdf {
    pub control_points: Vec<Vec3<f32>>,
    pub thickness: f32,
}

impl Sdf for BezierSdf {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        // Approximate distance to bezier curve
        let mut min_dist = f32::MAX;
        const SEGMENTS: u32 = 32;
        
        for i in 0..SEGMENTS {
            let t = i as f32 / (SEGMENTS - 1) as f32;
            let curve_point = self.bezier_point(t);
            let dist = (point - curve_point).length();
            min_dist = min_dist.min(dist);
        }
        
        min_dist - self.thickness
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

impl BezierSdf {
    fn bezier_point(&self, t: f32) -> Vec3<f32> {
        let n = self.control_points.len();
        if n == 0 { return Vec3::zero(); }
        if n == 1 { return self.control_points[0]; }
        
        let mut points = self.control_points.clone();
        for i in 1..n {
            for j in 0..n-i {
                points[j] = points[j] * (1.0 - t) + points[j + 1] * t;
            }
        }
        points[0]
    }
}

// Noise functions
fn simplex_noise_3d(point: Vec3<f32>) -> f32 {
    // Simple hash-based noise for now
    let x = point.x().sin() * 43758.5453;
    let y = point.y().sin() * 12345.6789;
    let z = point.z().sin() * 98765.4321;
    ((x + y + z).sin() * 0.5 + 0.5).fract() * 2.0 - 1.0
}

// Dynamic SDF operations for runtime composition
pub struct DynUnion {
    pub a: Box<dyn Sdf>,
    pub b: Box<dyn Sdf>,
}

impl Sdf for DynUnion {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        self.a.distance(point).min(self.b.distance(point))
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
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
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
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
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
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
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

pub struct DynTransform {
    pub sdf: Box<dyn Sdf>,
    pub position: Vec3<f32>,
    pub rotation: Quaternion<f32>,
    pub scale: Vec3<f32>,
}

impl Sdf for DynTransform {
    fn distance(&self, point: Vec3<f32>) -> f32 {
        let inv_rot = self.rotation.conjugate();
        let local_point = inv_rot.rotate_vector((point - self.position) / self.scale);
        self.sdf.distance(local_point) * self.scale.min_element()
    }
    
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

// Builder trait for ergonomic SDF construction
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
    
    fn transform(self, position: Vec3<f32>, rotation: Quaternion<f32>, scale: Vec3<f32>) -> Box<dyn Sdf> {
        Box::new(DynTransform { sdf: Box::new(self), position, rotation, scale })
    }
    
    fn translate(self, offset: Vec3<f32>) -> Box<dyn Sdf> {
        self.transform(offset, Quaternion::identity(), Vec3::one())
    }
    
    fn rotate(self, rotation: Quaternion<f32>) -> Box<dyn Sdf> {
        self.transform(Vec3::zero(), rotation, Vec3::one())
    }
    
    fn scale_uniform(self, scale: f32) -> Box<dyn Sdf> {
        self.transform(Vec3::zero(), Quaternion::identity(), Vec3::one() * scale)
    }
}

impl<T: Sdf + 'static> SdfOps for T {}

// Extension methods for boxed SDFs
pub trait BoxedSdfOps {
    fn union(self, other: impl Sdf + 'static) -> Box<dyn Sdf>;
    fn intersection(self, other: impl Sdf + 'static) -> Box<dyn Sdf>;
    fn difference(self, other: impl Sdf + 'static) -> Box<dyn Sdf>;
    fn smooth_union(self, other: impl Sdf + 'static, k: f32) -> Box<dyn Sdf>;
    fn transform(self, position: Vec3<f32>, rotation: Quaternion<f32>, scale: Vec3<f32>) -> Box<dyn Sdf>;
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
    
    fn transform(self, position: Vec3<f32>, rotation: Quaternion<f32>, scale: Vec3<f32>) -> Box<dyn Sdf> {
        Box::new(DynTransform { sdf: self, position, rotation, scale })
    }
}