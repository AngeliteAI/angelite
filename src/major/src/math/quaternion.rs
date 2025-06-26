use std::ops::{Add, Sub, Mul, Neg};
use std::fmt;
use super::vector::{Vec3, Vec3f};

/// Quaternion for 3D rotations
/// Stored as (v, w) where v is the vector part and w is the scalar part
#[repr(C)]
#[derive(Clone, Copy, PartialEq)]
pub struct Quaternion<T>(pub Vec3<T>, pub T); // (vector part, scalar part)

pub type Quat = Quaternion<f32>;
pub type Quatd = Quaternion<f64>;

impl<T> Quaternion<T> {
    #[inline]
    pub const fn new(x: T, y: T, z: T, w: T) -> Self 
    where T: Copy
    {
        Self(Vec3::new([x, y, z]), w)
    }
    
    // Accessor methods for compatibility
    #[inline]
    pub fn x(&self) -> T where T: Copy { self.0[0] }
    
    #[inline]
    pub fn y(&self) -> T where T: Copy { self.0[1] }
    
    #[inline]
    pub fn z(&self) -> T where T: Copy { self.0[2] }
}

impl<T: fmt::Debug> fmt::Debug for Quaternion<T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Quaternion({:?}, {:?})", self.0, self.1)
    }
}

impl<T: fmt::Display> fmt::Display for Quaternion<T> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[{}, {}]", self.0, self.1)
    }
}

impl<T: Default + Copy> Default for Quaternion<T> {
    fn default() -> Self {
        Self(Vec3::default(), T::default())
    }
}

// Float-specific operations
impl Quaternion<f32> {
    /// Identity quaternion
    #[inline]
    pub const fn identity() -> Self {
        Self(Vec3f::ZERO, 1.0)
    }
    
    /// Create quaternion from axis and angle
    #[inline]
    pub fn from_axis_angle(axis: Vec3f, angle: f32) -> Self {
        let half_angle = angle * 0.5;
        let s = half_angle.sin();
        let c = half_angle.cos();
        let axis = axis.normalize();
        
        Self(axis * s, c)
    }
    
    /// Create quaternion from rotation around X axis
    #[inline]
    pub fn from_rotation_x(angle: f32) -> Self {
        let half = angle * 0.5;
        Self(Vec3f::xyz(half.sin(), 0.0, 0.0), half.cos())
    }
    
    /// Create quaternion from rotation around Y axis
    #[inline]
    pub fn from_rotation_y(angle: f32) -> Self {
        let half = angle * 0.5;
        Self(Vec3f::xyz(0.0, half.sin(), 0.0), half.cos())
    }
    
    /// Create quaternion from rotation around Z axis
    #[inline]
    pub fn from_rotation_z(angle: f32) -> Self {
        let half = angle * 0.5;
        Self(Vec3f::xyz(0.0, 0.0, half.sin()), half.cos())
    }
    
    /// Create quaternion from Euler angles (pitch, yaw, roll)
    #[inline]
    pub fn from_euler(pitch: f32, yaw: f32, roll: f32) -> Self {
        let (sp, cp) = (pitch * 0.5).sin_cos();
        let (sy, cy) = (yaw * 0.5).sin_cos();
        let (sr, cr) = (roll * 0.5).sin_cos();
        
        Self(
            Vec3f::xyz(
                sp * cy * cr - cp * sy * sr,
                cp * sy * cr + sp * cy * sr,
                cp * cy * sr - sp * sy * cr,
            ),
            cp * cy * cr + sp * sy * sr,
        )
    }
    
    /// Create quaternion that rotates from one vector to another
    #[inline]
    pub fn from_rotation_arc(from: Vec3f, to: Vec3f) -> Self {
        let from = from.normalize();
        let to = to.normalize();
        
        let dot = from.dot(to);
        
        if dot > 0.999999 {
            // Vectors are parallel
            Self::identity()
        } else if dot < -0.999999 {
            // Vectors are opposite, find orthogonal axis
            let axis = if from[0].abs() > 0.9 {
                Vec3f::xyz(0.0, 1.0, 0.0)
            } else {
                Vec3f::xyz(1.0, 0.0, 0.0)
            };
            let axis = from.cross(axis).normalize();
            Self::from_axis_angle(axis, std::f32::consts::PI)
        } else {
            let v = from.cross(to);
            let s = (2.0 * (1.0 + dot)).sqrt();
            let invs = 1.0 / s;
            
            Self(v * invs, s * 0.5)
        }
    }
    
    /// Create quaternion from 3x3 rotation matrix columns
    #[inline]
    pub fn from_mat3(m: &crate::math::Mat3f) -> Self {
        let m00 = m[(0, 0)];
        let m11 = m[(1, 1)];
        let m22 = m[(2, 2)];
        let trace = m00 + m11 + m22;
        
        if trace > 0.0 {
            let s = 0.5 / (trace + 1.0).sqrt();
            Self(
                Vec3f::xyz(
                    (m[(2, 1)] - m[(1, 2)]) * s,
                    (m[(0, 2)] - m[(2, 0)]) * s,
                    (m[(1, 0)] - m[(0, 1)]) * s,
                ),
                0.25 / s,
            )
        } else if m00 > m11 && m00 > m22 {
            let s = 2.0 * (1.0f32 + m00 - m11 - m22).sqrt();
            Self(
                Vec3f::xyz(
                    0.25 * s,
                    (m[(0, 1)] + m[(1, 0)]) / s,
                    (m[(0, 2)] + m[(2, 0)]) / s,
                ),
                (m[(2, 1)] - m[(1, 2)]) / s,
            )
        } else if m11 > m22 {
            let s = 2.0 * (1.0f32 + m11 - m00 - m22).sqrt();
            Self(
                Vec3f::xyz(
                    (m[(0, 1)] + m[(1, 0)]) / s,
                    0.25 * s,
                    (m[(1, 2)] + m[(2, 1)]) / s,
                ),
                (m[(0, 2)] - m[(2, 0)]) / s,
            )
        } else {
            let s = 2.0 * (1.0f32 + m22 - m00 - m11).sqrt();
            Self(
                Vec3f::xyz(
                    (m[(0, 2)] + m[(2, 0)]) / s,
                    (m[(1, 2)] + m[(2, 1)]) / s,
                    0.25 * s,
                ),
                (m[(1, 0)] - m[(0, 1)]) / s,
            )
        }
    }
    
    /// Create quaternion from scaled axis (axis * angle)
    #[inline]
    pub fn from_scaled_axis(v: Vec3f) -> Self {
        let angle = v.length();
        if angle > 0.0 {
            Self::from_axis_angle(v / angle, angle)
        } else {
            Self::identity()
        }
    }
    
    /// Conjugate (inverse for unit quaternions)
    #[inline]
    pub fn conjugate(self) -> Self {
        Self(-self.0, self.1)
    }
    
    /// Length squared
    #[inline]
    pub fn length_squared(self) -> f32 {
        self.0.length_squared() + self.1 * self.1
    }
    
    /// Length
    #[inline]
    pub fn length(self) -> f32 {
        self.length_squared().sqrt()
    }
    
    /// Normalize
    #[inline]
    pub fn normalize(self) -> Self {
        let len = self.length();
        if len > 0.0 {
            self * (1.0 / len)
        } else {
            self
        }
    }
    
    /// Dot product
    #[inline]
    pub fn dot(self, other: Self) -> f32 {
        self.0.dot(other.0) + self.1 * other.1
    }
    
    /// Linear interpolation
    #[inline]
    pub fn lerp(self, other: Self, t: f32) -> Self {
        Self(
            self.0.lerp(other.0, t),
            self.1 + (other.1 - self.1) * t,
        ).normalize()
    }
    
    /// Spherical linear interpolation
    #[inline]
    pub fn slerp(self, mut other: Self, t: f32) -> Self {
        let mut dot = self.dot(other);
        
        // Take shortest path
        if dot < 0.0 {
            other = -other;
            dot = -dot;
        }
        
        if dot > 0.999995 {
            // Very close, use linear interpolation
            self.lerp(other, t)
        } else {
            let theta = dot.acos();
            let sin_theta = theta.sin();
            let a = ((1.0 - t) * theta).sin() / sin_theta;
            let b = (t * theta).sin() / sin_theta;
            
            self * a + other * b
        }
    }
    
    /// Rotate a vector by this quaternion
    #[inline]
    pub fn rotate_vector(self, v: Vec3f) -> Vec3f {
        // Efficient method: v' = v + 2w(q.v × v) + 2(q.v × (q.v × v))
        let uv = self.0.cross(v);
        let uuv = self.0.cross(uv);
        
        v + ((uv * self.1) + uuv) * 2.0
    }
    
    /// Create a rotation that looks from 'eye' position towards 'target' position
    /// with the given 'up' vector defining the vertical direction
    /// Coordinate system: X+ East (right), Y+ North (forward), Z+ Up
    #[inline]
    pub fn look_at(eye: Vec3f, target: Vec3f, world_up: Vec3f) -> Self {
        // Calculate the forward direction (Y axis points towards target)
        let forward = (target - eye).normalize();
        
        // Calculate right vector (X axis)
        // Right = forward × up (for right-handed coordinate system)
        let right = if forward.dot(world_up).abs() > 0.999 {
            // Forward is parallel to up, choose an arbitrary perpendicular vector
            if world_up[2].abs() < 0.9 {
                forward.cross(Vec3f::Z).normalize()
            } else {
                forward.cross(Vec3f::X).normalize()
            }
        } else {
            forward.cross(world_up).normalize()
        };
        
        // Recalculate up to ensure orthogonality
        let up = right.cross(forward);
        
        // Build rotation matrix for camera orientation where:
        // Camera X -> right vector
        // Camera Y -> forward vector (towards target)
        // Camera Z -> up vector
        
        // Create rotation matrix (column-major)
        let mat = crate::math::Mat3f::from_cols([
            right.0,
            forward.0,
            up.0
        ]);
        
        // Convert to quaternion
        Self::from_mat3(&mat)
    }
}

// Arithmetic operations
impl<T: Copy + Add<Output = T>> Add for Quaternion<T> {
    type Output = Self;
    
    #[inline]
    fn add(self, rhs: Self) -> Self::Output {
        Self(self.0 + rhs.0, self.1 + rhs.1)
    }
}

impl<T: Copy + Sub<Output = T>> Sub for Quaternion<T> {
    type Output = Self;
    
    #[inline]
    fn sub(self, rhs: Self) -> Self::Output {
        Self(self.0 - rhs.0, self.1 - rhs.1)
    }
}

// Quaternion multiplication
impl Mul for Quaternion<f32> {
    type Output = Self;
    
    #[inline]
    fn mul(self, rhs: Self) -> Self::Output {
        // (q1.w * q2.v + q2.w * q1.v + q1.v × q2.v, q1.w * q2.w - q1.v · q2.v)
        Self(
            self.0 * rhs.1 + rhs.0 * self.1 + self.0.cross(rhs.0),
            self.1 * rhs.1 - self.0.dot(rhs.0),
        )
    }
}

// Scalar multiplication
impl Mul<f32> for Quaternion<f32> {
    type Output = Self;
    
    #[inline]
    fn mul(self, rhs: f32) -> Self::Output {
        Self(self.0 * rhs, self.1 * rhs)
    }
}

// Vector rotation
impl Mul<Vec3f> for Quaternion<f32> {
    type Output = Vec3f;
    
    #[inline]
    fn mul(self, rhs: Vec3f) -> Self::Output {
        self.rotate_vector(rhs)
    }
}

impl Neg for Quaternion<f32> {
    type Output = Self;
    
    #[inline]
    fn neg(self) -> Self::Output {
        Self(-self.0, -self.1)
    }
}