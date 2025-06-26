use std::ops::{Add, Sub, Mul, Div, Neg, Index, IndexMut, AddAssign, SubAssign, MulAssign, DivAssign};
use std::fmt;

/// A generic N-dimensional vector using const generics
#[repr(C)]
#[derive(Clone, Copy, PartialEq)]
pub struct Vector<T, const N: usize>(pub [T; N]);

impl<T, const N: usize> Vector<T, N> {
    /// Create a new vector from an array
    #[inline]
    pub const fn new(data: [T; N]) -> Self {
        Self(data)
    }
}


// Type aliases for common vector types
pub type Vec2<T> = Vector<T, 2>;
pub type Vec3<T> = Vector<T, 3>;
pub type Vec4<T> = Vector<T, 4>;

// Convenience type aliases
pub type Vec2f = Vec2<f32>;
pub type Vec3f = Vec3<f32>;
pub type Vec4f = Vec4<f32>;
pub type Vec2d = Vec2<f64>;
pub type Vec3d = Vec3<f64>;
pub type Vec4d = Vec4<f64>;

impl<T: Default + Copy, const N: usize> Default for Vector<T, N> {
    fn default() -> Self {
        Self([T::default(); N])
    }
}

impl<T: fmt::Debug, const N: usize> fmt::Debug for Vector<T, N> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Vector{:?}", self.0)
    }
}

impl<T: fmt::Display, const N: usize> fmt::Display for Vector<T, N> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[")?;
        for (i, v) in self.0.iter().enumerate() {
            if i > 0 { write!(f, ", ")?; }
            write!(f, "{}", v)?;
        }
        write!(f, "]")
    }
}

// Indexing
impl<T, const N: usize> Index<usize> for Vector<T, N> {
    type Output = T;
    
    #[inline]
    fn index(&self, index: usize) -> &Self::Output {
        &self.0[index]
    }
}

impl<T, const N: usize> IndexMut<usize> for Vector<T, N> {
    #[inline]
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        &mut self.0[index]
    }
}

// Common constructors for specific dimensions
impl<T: Copy + Default> Vec2<T> {
    #[inline]
    pub const fn xy(x: T, y: T) -> Self {
        Self([x, y])
    }
}

impl<T: Copy + Default> Vec3<T> {
    #[inline]
    pub const fn xyz(x: T, y: T, z: T) -> Self {
        Self([x, y, z])
    }
}

impl<T: Copy + Default> Vec4<T> {
    #[inline]
    pub const fn xyzw(x: T, y: T, z: T, w: T) -> Self {
        Self([x, y, z, w])
    }
}

// Arithmetic operations
macro_rules! impl_vector_op {
    ($trait:ident, $method:ident, $op:tt) => {
        impl<T: $trait<Output = T> + Copy, const N: usize> $trait for Vector<T, N> {
            type Output = Self;
            
            #[inline]
            fn $method(self, rhs: Self) -> Self::Output {
                let mut result = self;
                for i in 0..N {
                    result.0[i] = self.0[i] $op rhs.0[i];
                }
                result
            }
        }
        
        impl<T: $trait<Output = T> + Copy, const N: usize> $trait<T> for Vector<T, N> {
            type Output = Self;
            
            #[inline]
            fn $method(self, rhs: T) -> Self::Output {
                let mut result = self;
                for i in 0..N {
                    result.0[i] = self.0[i] $op rhs;
                }
                result
            }
        }
    };
}

impl_vector_op!(Add, add, +);
impl_vector_op!(Sub, sub, -);
impl_vector_op!(Mul, mul, *);
impl_vector_op!(Div, div, /);

// Assignment operations
macro_rules! impl_vector_assign_op {
    ($trait:ident, $method:ident, $op:tt) => {
        impl<T: $trait + Copy, const N: usize> $trait for Vector<T, N> {
            #[inline]
            fn $method(&mut self, rhs: Self) {
                for i in 0..N {
                    self.0[i] $op rhs.0[i];
                }
            }
        }
        
        impl<T: $trait + Copy, const N: usize> $trait<T> for Vector<T, N> {
            #[inline]
            fn $method(&mut self, rhs: T) {
                for i in 0..N {
                    self.0[i] $op rhs;
                }
            }
        }
    };
}

impl_vector_assign_op!(AddAssign, add_assign, +=);
impl_vector_assign_op!(SubAssign, sub_assign, -=);
impl_vector_assign_op!(MulAssign, mul_assign, *=);
impl_vector_assign_op!(DivAssign, div_assign, /=);

impl<T: Neg<Output = T> + Copy, const N: usize> Neg for Vector<T, N> {
    type Output = Self;
    
    #[inline]
    fn neg(self) -> Self::Output {
        let mut result = self;
        for i in 0..N {
            result.0[i] = -self.0[i];
        }
        result
    }
}

// Vector operations
impl<T, const N: usize> Vector<T, N> 
where 
    T: Copy + Default + Add<Output = T> + Sub<Output = T> + Mul<Output = T> + Div<Output = T>
{
    /// Dot product
    #[inline]
    pub fn dot(self, rhs: Self) -> T {
        let mut sum = T::default();
        for i in 0..N {
            sum = sum + self.0[i] * rhs.0[i];
        }
        sum
    }
}

// Float-specific operations
impl<const N: usize> Vector<f32, N> {
    /// Zero vector
    #[inline]
    pub const fn zero() -> Self {
        Self([0.0; N])
    }
    
    /// One vector
    #[inline]
    pub const fn one() -> Self {
        Self([1.0; N])
    }
    
    /// Length squared
    #[inline]
    pub fn length_squared(self) -> f32 {
        self.dot(self)
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
            self / len
        } else {
            self
        }
    }
    
    /// Linear interpolation
    #[inline]
    pub fn lerp(self, other: Self, t: f32) -> Self {
        self * (1.0 - t) + other * t
    }
}

// Cross product for 3D vectors
impl<T> Vec3<T> 
where 
    T: Copy + Sub<Output = T> + Mul<Output = T>
{
    #[inline]
    pub fn cross(self, rhs: Self) -> Self {
        Self::new([
            self.0[1] * rhs.0[2] - self.0[2] * rhs.0[1],
            self.0[2] * rhs.0[0] - self.0[0] * rhs.0[2],
            self.0[0] * rhs.0[1] - self.0[1] * rhs.0[0],
        ])
    }
}

// Common constants for Vec3f
impl Vec3f {
    pub const ZERO: Self = Self::xyz(0.0, 0.0, 0.0);
    pub const ONE: Self = Self::xyz(1.0, 1.0, 1.0);
    pub const X: Self = Self::xyz(1.0, 0.0, 0.0);
    pub const Y: Self = Self::xyz(0.0, 1.0, 0.0);
    pub const Z: Self = Self::xyz(0.0, 0.0, 1.0);
    pub const NEG_X: Self = Self::xyz(-1.0, 0.0, 0.0);
    pub const NEG_Y: Self = Self::xyz(0.0, -1.0, 0.0);
    pub const NEG_Z: Self = Self::xyz(0.0, 0.0, -1.0);
}

// From/Into conversions
impl<T: Copy, const N: usize> From<[T; N]> for Vector<T, N> {
    #[inline]
    fn from(data: [T; N]) -> Self {
        Self(data)
    }
}

impl<T: Copy, const N: usize> From<&[T; N]> for Vector<T, N> {
    #[inline]
    fn from(data: &[T; N]) -> Self {
        Self(*data)
    }
}

impl<T, const N: usize> Into<[T; N]> for Vector<T, N> {
    #[inline]
    fn into(self) -> [T; N] {
        self.0
    }
}