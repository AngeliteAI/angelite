use std::ops::{Add, Sub, Mul, Index, IndexMut};
use std::fmt;
use super::vector::{Vector, Vec3f, Vec4f};
use super::quaternion::Quat;

/// Generic matrix type using const generics
/// Stored in column-major order for GPU compatibility
#[repr(C)]
#[derive(Clone, Copy, PartialEq)]
pub struct Matrix<T, const R: usize, const C: usize>(pub [[T; R]; C]); // Column-major: data[col][row]

// Type aliases for common matrix types
pub type Mat2<T> = Matrix<T, 2, 2>;
pub type Mat3<T> = Matrix<T, 3, 3>;
pub type Mat4<T> = Matrix<T, 4, 4>;
pub type Mat2x3<T> = Matrix<T, 2, 3>;
pub type Mat3x4<T> = Matrix<T, 3, 4>;

// Float aliases
pub type Mat2f = Mat2<f32>;
pub type Mat3f = Mat3<f32>;
pub type Mat4f = Mat4<f32>;

impl<T, const R: usize, const C: usize> Matrix<T, R, C> {
    /// Create matrix from column arrays
    #[inline]
    pub const fn from_cols(data: [[T; R]; C]) -> Self {
        Self(data)
    }
}

impl<T: Default + Copy, const R: usize, const C: usize> Default for Matrix<T, R, C> {
    fn default() -> Self {
        Self([[T::default(); R]; C])
    }
}

impl<T: fmt::Debug, const R: usize, const C: usize> fmt::Debug for Matrix<T, R, C> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Matrix{}x{} [", R, C)?;
        for row in 0..R {
            if row > 0 { write!(f, ", ")?; }
            write!(f, "[")?;
            for col in 0..C {
                if col > 0 { write!(f, ", ")?; }
                write!(f, "{:?}", self.0[col][row])?;
            }
            write!(f, "]")?;
        }
        write!(f, "]")
    }
}

// Indexing by (row, col)
impl<T, const R: usize, const C: usize> Index<(usize, usize)> for Matrix<T, R, C> {
    type Output = T;
    
    #[inline]
    fn index(&self, (row, col): (usize, usize)) -> &Self::Output {
        &self.0[col][row]
    }
}

impl<T, const R: usize, const C: usize> IndexMut<(usize, usize)> for Matrix<T, R, C> {
    #[inline]
    fn index_mut(&mut self, (row, col): (usize, usize)) -> &mut Self::Output {
        &mut self.0[col][row]
    }
}

// Float-specific operations
impl<const R: usize, const C: usize> Matrix<f32, R, C> {
    /// Zero matrix
    #[inline]
    pub const fn zero() -> Self {
        Self([[0.0; R]; C])
    }
    
    /// Get column as vector
    #[inline]
    pub fn col(&self, col: usize) -> Vector<f32, R> {
        Vector::new(self.0[col])
    }
    
    /// Get row as vector
    #[inline]
    pub fn row(&self, row: usize) -> Vector<f32, C> {
        let mut result = [0.0; C];
        for col in 0..C {
            result[col] = self.0[col][row];
        }
        Vector::new(result)
    }
    
    /// Convert to flat array in column-major order
    #[inline]
    pub fn to_cols_array(&self) -> [f32; R * C] {
        let mut result = [0.0; R * C];
        let mut idx = 0;
        for col in 0..C {
            for row in 0..R {
                result[idx] = self.0[col][row];
                idx += 1;
            }
        }
        result
    }
}

// Square matrix operations
impl<const N: usize> Matrix<f32, N, N> {
    /// Identity matrix
    #[inline]
    pub fn identity() -> Self {
        let mut result = Self::zero();
        for i in 0..N {
            result.0[i][i] = 1.0;
        }
        result
    }
    
    /// Transpose
    #[inline]
    pub fn transpose(&self) -> Self {
        let mut result = Self::zero();
        for row in 0..N {
            for col in 0..N {
                result.0[row][col] = self.0[col][row];
            }
        }
        result
    }
}

// Mat3 specific operations
impl Mat3f {
    /// Create 3x3 matrix from column vectors
    #[inline]
    pub fn from_cols_vec(x: Vec3f, y: Vec3f, z: Vec3f) -> Self {
        Self::from_cols([x.0, y.0, z.0])
    }
    
    /// Create rotation matrix from quaternion
    #[inline]
    pub fn from_quat(q: Quat) -> Self {
        let x = q.0[0];
        let y = q.0[1];
        let z = q.0[2];
        let w = q.1;
        
        let x2 = x + x;
        let y2 = y + y;
        let z2 = z + z;
        let xx2 = x * x2;
        let xy2 = x * y2;
        let xz2 = x * z2;
        let yy2 = y * y2;
        let yz2 = y * z2;
        let zz2 = z * z2;
        let wx2 = w * x2;
        let wy2 = w * y2;
        let wz2 = w * z2;
        
        Self::from_cols([
            [1.0 - yy2 - zz2, xy2 + wz2, xz2 - wy2],
            [xy2 - wz2, 1.0 - xx2 - zz2, yz2 + wx2],
            [xz2 + wy2, yz2 - wx2, 1.0 - xx2 - yy2],
        ])
    }
}

// Mat4 specific operations
impl Mat4f {
    /// Create 4x4 matrix from column vectors
    #[inline]
    pub fn from_cols_vec(x: Vec4f, y: Vec4f, z: Vec4f, w: Vec4f) -> Self {
        Self::from_cols([x.0, y.0, z.0, w.0])
    }
    
    /// Create translation matrix
    #[inline]
    pub fn from_translation(v: Vec3f) -> Self {
        let mut result = Self::identity();
        result.0[3][0] = v[0];
        result.0[3][1] = v[1];
        result.0[3][2] = v[2];
        result
    }
    
    /// Create scale matrix
    #[inline]
    pub fn from_scale(v: Vec3f) -> Self {
        let mut result = Self::zero();
        result.0[0][0] = v[0];
        result.0[1][1] = v[1];
        result.0[2][2] = v[2];
        result.0[3][3] = 1.0;
        result
    }
    
    /// Create rotation matrix from quaternion
    #[inline]
    pub fn from_quat(q: Quat) -> Self {
        let mat3 = Mat3f::from_quat(q);
        let mut result = Self::identity();
        for col in 0..3 {
            for row in 0..3 {
                result.0[col][row] = mat3.0[col][row];
            }
        }
        result
    }
    
    /// Create matrix from rotation and translation
    #[inline]
    pub fn from_rotation_translation(q: Quat, v: Vec3f) -> Self {
        let mut result = Self::from_quat(q);
        result.0[3][0] = v[0];
        result.0[3][1] = v[1];
        result.0[3][2] = v[2];
        result
    }
    
    /// Create look-at matrix for X+ right, Y+ forward, Z+ up coordinate system
    #[inline]
    pub fn look_at(eye: Vec3f, center: Vec3f, up: Vec3f) -> Self {
        // Y+ is forward in our coordinate system
        let forward = (center - eye).normalize();
        // X+ is right
        let right = forward.cross(up).normalize();
        // Z+ is up (recalculated for orthogonality)
        let up = right.cross(forward);
        
        // Build view matrix that transforms world space to view space
        // In view space: X+ right, Y+ forward, Z+ up
        Self::from_cols([
            [right[0], up[0], -forward[0], 0.0],
            [right[1], up[1], -forward[1], 0.0],
            [right[2], up[2], -forward[2], 0.0],
            [-right.dot(eye), -up.dot(eye), forward.dot(eye), 1.0],
        ])
    }
    
    /// Create perspective projection matrix
    #[inline]
    pub fn perspective(fov_radians: f32, aspect: f32, near: f32, far: f32) -> Self {
        let f = 1.0 / (fov_radians * 0.5).tan();
        let range = far - near;
        
        Self::from_cols([
            [f / aspect, 0.0, 0.0, 0.0],
            [0.0, f, 0.0, 0.0],
            [0.0, 0.0, -(far + near) / range, -1.0],
            [0.0, 0.0, -(2.0 * far * near) / range, 0.0],
        ])
    }
    
    /// Create orthographic projection matrix
    #[inline]
    pub fn orthographic(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) -> Self {
        let w = right - left;
        let h = top - bottom;
        let d = far - near;
        
        Self::from_cols([
            [2.0 / w, 0.0, 0.0, 0.0],
            [0.0, 2.0 / h, 0.0, 0.0],
            [0.0, 0.0, -2.0 / d, 0.0],
            [-(right + left) / w, -(top + bottom) / h, -(far + near) / d, 1.0],
        ])
    }
    
    /// Inverse (for affine transformations)
    #[inline]
    pub fn inverse(&self) -> Self {
        // For affine matrices (rotation + translation)
        // Extract rotation part (upper-left 3x3)
        let mut rot = Mat3f::zero();
        for i in 0..3 {
            for j in 0..3 {
                rot.0[i][j] = self.0[i][j];
            }
        }
        
        // Transpose rotation (inverse for orthogonal matrices)
        rot = rot.transpose();
        
        // Extract translation
        let trans = Vec3f::xyz(self.0[3][0], self.0[3][1], self.0[3][2]);
        
        // Compute new translation: -R^T * t
        let new_trans = Vec3f::xyz(
            -(rot.0[0][0] * trans[0] + rot.0[0][1] * trans[1] + rot.0[0][2] * trans[2]),
            -(rot.0[1][0] * trans[0] + rot.0[1][1] * trans[1] + rot.0[1][2] * trans[2]),
            -(rot.0[2][0] * trans[0] + rot.0[2][1] * trans[1] + rot.0[2][2] * trans[2]),
        );
        
        // Build result
        let mut result = Self::identity();
        for i in 0..3 {
            for j in 0..3 {
                result.0[i][j] = rot.0[i][j];
            }
        }
        result.0[3][0] = new_trans[0];
        result.0[3][1] = new_trans[1];
        result.0[3][2] = new_trans[2];
        
        result
    }
}

// Matrix addition
impl<T: Copy + Add<Output = T>, const R: usize, const C: usize> Add for Matrix<T, R, C> {
    type Output = Self;
    
    #[inline]
    fn add(self, rhs: Self) -> Self::Output {
        let mut result = self;
        for col in 0..C {
            for row in 0..R {
                result.0[col][row] = self.0[col][row] + rhs.0[col][row];
            }
        }
        result
    }
}

// Matrix subtraction
impl<T: Copy + Sub<Output = T>, const R: usize, const C: usize> Sub for Matrix<T, R, C> {
    type Output = Self;
    
    #[inline]
    fn sub(self, rhs: Self) -> Self::Output {
        let mut result = self;
        for col in 0..C {
            for row in 0..R {
                result.0[col][row] = self.0[col][row] - rhs.0[col][row];
            }
        }
        result
    }
}

// Matrix multiplication
impl<T, const R: usize, const N: usize, const C: usize> Mul<Matrix<T, N, C>> for Matrix<T, R, N>
where
    T: Copy + Default + Add<Output = T> + Mul<Output = T>,
{
    type Output = Matrix<T, R, C>;
    
    #[inline]
    fn mul(self, rhs: Matrix<T, N, C>) -> Self::Output {
        let mut result = Matrix::<T, R, C>::default();
        for col in 0..C {
            for row in 0..R {
                let mut sum = T::default();
                for k in 0..N {
                    sum = sum + self.0[k][row] * rhs.0[col][k];
                }
                result.0[col][row] = sum;
            }
        }
        result
    }
}

// Matrix-vector multiplication
impl<T, const R: usize, const C: usize> Mul<Vector<T, C>> for Matrix<T, R, C>
where
    T: Copy + Default + Add<Output = T> + Mul<Output = T>,
{
    type Output = Vector<T, R>;
    
    #[inline]
    fn mul(self, rhs: Vector<T, C>) -> Self::Output {
        let mut result = Vector::<T, R>::default();
        for row in 0..R {
            let mut sum = T::default();
            for col in 0..C {
                sum = sum + self.0[col][row] * rhs[col];
            }
            result[row] = sum;
        }
        result
    }
}

// Scalar multiplication
impl<T: Copy + Mul<Output = T>, const R: usize, const C: usize> Mul<T> for Matrix<T, R, C> {
    type Output = Self;
    
    #[inline]
    fn mul(self, rhs: T) -> Self::Output {
        let mut result = self;
        for col in 0..C {
            for row in 0..R {
                result.0[col][row] = self.0[col][row] * rhs;
            }
        }
        result
    }
}