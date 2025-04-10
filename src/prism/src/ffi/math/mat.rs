use super::vec::Vec3;

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Mat2 {
    pub data: [f32; 4],
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Mat3 {
    pub data: [f32; 9],
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Mat4 {
    pub data: [f32; 16],
}

extern "C" {
    // Matrix constructors
    pub fn m2Id() -> Mat2;
    pub fn m3Id() -> Mat3;
    pub fn m4Id() -> Mat4;
    pub fn m2Zero() -> Mat2;
    pub fn m3Zero() -> Mat3;
    pub fn m4Zero() -> Mat4;

    // Matrix operations
    pub fn m4Mul(a: Mat4, b: Mat4) -> Mat4;
    pub fn m4Inv(m: Mat4) -> Mat4;
    pub fn m4Tr(m: Mat4) -> Mat4;
    pub fn m4Det(m: Mat4) -> f32;

    // Transformation matrices
    pub fn m4Scaling(x: f32, y: f32, z: f32) -> Mat4;
    pub fn m4Trans(x: f32, y: f32, z: f32) -> Mat4;
    pub fn m4RotX(angle: f32) -> Mat4;
    pub fn m4RotY(angle: f32) -> Mat4;
    pub fn m4RotZ(angle: f32) -> Mat4;
    pub fn m4RotAxis(axis: Vec3, angle: f32) -> Mat4;
    pub fn m4RotEuler(x: f32, y: f32, z: f32) -> Mat4;

    // View/projection matrices
    pub fn m4LookAt(eye: Vec3, target: Vec3, up: Vec3) -> Mat4;
    pub fn m4Persp(fovy: f32, aspect: f32, near: f32, far: f32) -> Mat4;
    pub fn m4Ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) -> Mat4;
}

// Safe wrappers for Mat4
impl Mat4 {
    #[inline]
    pub fn identity() -> Self {
        unsafe { m4Id() }
    }

    #[inline]
    pub fn translate(x: f32, y: f32, z: f32) -> Self {
        unsafe { m4Trans(x, y, z) }
    }

    #[inline]
    pub fn scale(x: f32, y: f32, z: f32) -> Self {
        unsafe { m4Scaling(x, y, z) }
    }

    #[inline]
    pub fn rotate_x(angle: f32) -> Self {
        unsafe { m4RotX(angle) }
    }

    #[inline]
    pub fn rotate_y(angle: f32) -> Self {
        unsafe { m4RotY(angle) }
    }

    #[inline]
    pub fn rotate_z(angle: f32) -> Self {
        unsafe { m4RotZ(angle) }
    }

    #[inline]
    pub fn multiply(&self, other: &Mat4) -> Self {
        unsafe { m4Mul(*self, *other) }
    }

    #[inline]
    pub fn inverse(&self) -> Self {
        unsafe { m4Inv(*self) }
    }

    #[inline]
    pub fn perspective(fovy: f32, aspect: f32, near: f32, far: f32) -> Self {
        unsafe { m4Persp(fovy, aspect, near, far) }
    }

    #[inline]
    pub fn look_at(eye: &Vec3, target: &Vec3, up: &Vec3) -> Self {
        unsafe { m4LookAt(*eye, *target, *up) }
    }
}
