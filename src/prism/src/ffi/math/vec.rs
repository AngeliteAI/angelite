#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Vec2 {
    pub x: f32,
    pub y: f32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Vec3 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Vec4 {
    pub x: f32,
    pub y: f32,
    pub z: f32,
    pub w: f32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct IVec2 {
    pub x: i32,
    pub y: i32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct IVec3 {
    pub x: i32,
    pub y: i32,
    pub z: i32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct IVec4 {
    pub x: i32,
    pub y: i32,
    pub z: i32,
    pub w: i32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct UVec2 {
    pub x: u32,
    pub y: u32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct UVec3 {
    pub x: u32,
    pub y: u32,
    pub z: u32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct UVec4 {
    pub x: u32,
    pub y: u32,
    pub z: u32,
    pub w: u32,
}

// Core vector constructors
extern "C" {
    pub fn v2(x: f32, y: f32) -> Vec2;
    pub fn v3(x: f32, y: f32, z: f32) -> Vec3;
    pub fn v4(x: f32, y: f32, z: f32, w: f32) -> Vec4;
    pub fn iv2(x: i32, y: i32) -> IVec2;
    pub fn iv3(x: i32, y: i32, z: i32) -> IVec3;
    pub fn iv4(x: i32, y: i32, z: i32, w: i32) -> IVec4;
    pub fn uv2(x: u32, y: u32) -> UVec2;
    pub fn uv3(x: u32, y: u32, z: u32) -> UVec3;
    pub fn uv4(x: u32, y: u32, z: u32, w: u32) -> UVec4;

    // Common vectors
    pub fn v2Zero() -> Vec2;
    pub fn v3Zero() -> Vec3;
    pub fn v4Zero() -> Vec4;
    pub fn v2One() -> Vec2;
    pub fn v3One() -> Vec3;
    pub fn v4One() -> Vec4;

    // Vector operations
    pub fn v3Add(a: Vec3, b: Vec3) -> Vec3;
    pub fn v3Sub(a: Vec3, b: Vec3) -> Vec3;
    pub fn v3Mul(a: Vec3, b: Vec3) -> Vec3;
    pub fn v3Div(a: Vec3, b: Vec3) -> Vec3;
    pub fn v3Scale(v: Vec3, s: f32) -> Vec3;
    pub fn v3Neg(v: Vec3) -> Vec3;
    pub fn v3Dot(a: Vec3, b: Vec3) -> f32;
    pub fn v3Cross(a: Vec3, b: Vec3) -> Vec3;
    pub fn v3Len(v: Vec3) -> f32;
    pub fn v3Len2(v: Vec3) -> f32;
    pub fn v3Dist(a: Vec3, b: Vec3) -> f32;
    pub fn v3Norm(v: Vec3) -> Vec3;
    pub fn v3Lerp(a: Vec3, b: Vec3, t: f32) -> Vec3;
}

// Safe wrappers for Vec3
impl Vec3 {
    #[inline]
    pub fn new(x: f32, y: f32, z: f32) -> Self {
        unsafe { v3(x, y, z) }
    }

    #[inline]
    pub fn zero() -> Self {
        unsafe { v3Zero() }
    }

    #[inline]
    pub fn one() -> Self {
        unsafe { v3One() }
    }

    #[inline]
    pub fn add(&self, other: &Vec3) -> Vec3 {
        unsafe { v3Add(*self, *other) }
    }

    #[inline]
    pub fn sub(&self, other: &Vec3) -> Vec3 {
        unsafe { v3Sub(*self, *other) }
    }

    #[inline]
    pub fn scale(&self, s: f32) -> Vec3 {
        unsafe { v3Scale(*self, s) }
    }

    #[inline]
    pub fn dot(&self, other: &Vec3) -> f32 {
        unsafe { v3Dot(*self, *other) }
    }

    #[inline]
    pub fn cross(&self, other: &Vec3) -> Vec3 {
        unsafe { v3Cross(*self, *other) }
    }

    #[inline]
    pub fn length(&self) -> f32 {
        unsafe { v3Len(*self) }
    }

    #[inline]
    pub fn normalize(&self) -> Vec3 {
        unsafe { v3Norm(*self) }
    }
}
