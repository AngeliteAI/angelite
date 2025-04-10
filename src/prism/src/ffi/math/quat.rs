use super::mat::{Mat3, Mat4};
use super::vec::Vec3;

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Quat {
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub w: f32,
}

extern "C" {
    // Quaternion constructors
    pub fn q(x: f32, y: f32, z: f32, w: f32) -> Quat;
    pub fn qFromVec(v: Vec3, w: f32) -> Quat;
    pub fn qId() -> Quat;
    pub fn qZero() -> Quat;
    pub fn qAxis(axis: Vec3, angle: f32) -> Quat;
    pub fn qEuler(x: f32, y: f32, z: f32) -> Quat;
    pub fn qFromM3(m: Mat3) -> Quat;
    pub fn qFromM4(m: Mat4) -> Quat;

    // Quaternion operations
    pub fn qAdd(a: Quat, b: Quat) -> Quat;
    pub fn qSub(a: Quat, b: Quat) -> Quat;
    pub fn qMul(a: Quat, b: Quat) -> Quat;
    pub fn qScale(q: Quat, s: f32) -> Quat;
    pub fn qNeg(q: Quat) -> Quat;
    pub fn qLen2(q: Quat) -> f32;
    pub fn qNorm(q: Quat) -> Quat;
    pub fn qConj(q: Quat) -> Quat;
    pub fn qInv(q: Quat) -> Quat;
    pub fn qDot(a: Quat, b: Quat) -> f32;
    pub fn qEq(a: Quat, b: Quat, eps: f32) -> bool;
    pub fn qRotV3(q: Quat, v: Vec3) -> Vec3;
    pub fn qLerp(a: Quat, b: Quat, t: f32) -> Quat;
    pub fn qSlerp(a: Quat, b: Quat, t: f32) -> Quat;
}

// Safe wrappers for Quat
impl Quat {
    #[inline]
    pub fn identity() -> Self {
        unsafe { qId() }
    }

    #[inline]
    pub fn from_axis_angle(axis: &Vec3, angle: f32) -> Self {
        unsafe { qAxis(*axis, angle) }
    }

    #[inline]
    pub fn from_euler(x: f32, y: f32, z: f32) -> Self {
        unsafe { qEuler(x, y, z) }
    }

    #[inline]
    pub fn rotate_vec(&self, v: &Vec3) -> Vec3 {
        unsafe { qRotV3(*self, *v) }
    }

    #[inline]
    pub fn normalize(&self) -> Self {
        unsafe { qNorm(*self) }
    }

    #[inline]
    pub fn conjugate(&self) -> Self {
        unsafe { qConj(*self) }
    }

    #[inline]
    pub fn inverse(&self) -> Self {
        unsafe { qInv(*self) }
    }
}
