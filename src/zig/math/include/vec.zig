pub const Vec2 = extern struct {
    x: f32,
    y: f32,
};
pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,
};
pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,
};
// Constructor functions
pub extern fn v2(x: f32, y: f32) Vec2;
pub extern fn v3(x: f32, y: f32, z: f32) Vec3;
pub extern fn v4(x: f32, y: f32, z: f32, w: f32) Vec4;
// Common constants
pub extern fn v2Zero() Vec2;
pub extern fn v3Zero() Vec3;
pub extern fn v4Zero() Vec4;
pub extern fn v2One() Vec2;
pub extern fn v3One() Vec3;
pub extern fn v4One() Vec4;
// Unit vectors
pub extern fn v2X() Vec2;
pub extern fn v2Y() Vec2;
pub extern fn v3X() Vec3;
pub extern fn v3Y() Vec3;
pub extern fn v3Z() Vec3;
pub extern fn v4X() Vec4;
pub extern fn v4Y() Vec4;
pub extern fn v4Z() Vec4;
pub extern fn v4W() Vec4;
// Basic operations
pub extern fn v2Add(a: Vec2, b: Vec2) Vec2;
pub extern fn v3Add(a: Vec3, b: Vec3) Vec3;
pub extern fn v4Add(a: Vec4, b: Vec4) Vec4;
pub extern fn v2Sub(a: Vec2, b: Vec2) Vec2;
pub extern fn v3Sub(a: Vec3, b: Vec3) Vec3;
pub extern fn v4Sub(a: Vec4, b: Vec4) Vec4;
pub extern fn v2Mul(a: Vec2, b: Vec2) Vec2;
pub extern fn v3Mul(a: Vec3, b: Vec3) Vec3;
pub extern fn v4Mul(a: Vec4, b: Vec4) Vec4;
pub extern fn v2Div(a: Vec2, b: Vec2) Vec2;
pub extern fn v3Div(a: Vec3, b: Vec3) Vec3;
pub extern fn v4Div(a: Vec4, b: Vec4) Vec4;
pub extern fn v2Scale(v: Vec2, s: f32) Vec2;
pub extern fn v3Scale(v: Vec3, s: f32) Vec3;
pub extern fn v4Scale(v: Vec4, s: f32) Vec4;
pub extern fn v2Neg(v: Vec2) Vec2;
pub extern fn v3Neg(v: Vec3) Vec3;
pub extern fn v4Neg(v: Vec4) Vec4;
// Vector operations
pub extern fn v2Dot(a: Vec2, b: Vec2) f32;
pub extern fn v3Dot(a: Vec3, b: Vec3) f32;
pub extern fn v4Dot(a: Vec4, b: Vec4) f32;
pub extern fn v3Cross(a: Vec3, b: Vec3) Vec3;
pub extern fn v2Len(v: Vec2) f32;
pub extern fn v3Len(v: Vec3) f32;
pub extern fn v4Len(v: Vec4) f32;
pub extern fn v2Len2(v: Vec2) f32;
pub extern fn v3Len2(v: Vec3) f32;
pub extern fn v4Len2(v: Vec4) f32;
pub extern fn v2Dist(a: Vec2, b: Vec2) f32;
pub extern fn v3Dist(a: Vec3, b: Vec3) f32;
pub extern fn v4Dist(a: Vec4, b: Vec4) f32;
pub extern fn v2Dist2(a: Vec2, b: Vec2) f32;
pub extern fn v3Dist2(a: Vec3, b: Vec3) f32;
pub extern fn v4Dist2(a: Vec4, b: Vec4) f32;
pub extern fn v2Norm(v: Vec2) Vec2;
pub extern fn v3Norm(v: Vec3) Vec3;
pub extern fn v4Norm(v: Vec4) Vec4;
// Interpolation and comparison
pub extern fn v2Lerp(a: Vec2, b: Vec2, t: f32) Vec2;
pub extern fn v3Lerp(a: Vec3, b: Vec3, t: f32) Vec3;
pub extern fn v4Lerp(a: Vec4, b: Vec4, t: f32) Vec4;
pub extern fn v2Eq(a: Vec2, b: Vec2, eps: f32) bool;
pub extern fn v3Eq(a: Vec3, b: Vec3, eps: f32) bool;
pub extern fn v4Eq(a: Vec4, b: Vec4, eps: f32) bool;
// Reflection and refraction
pub extern fn v2Reflect(v: Vec2, n: Vec2) Vec2;
pub extern fn v3Reflect(v: Vec3, n: Vec3) Vec3;
pub extern fn v3Refract(v: Vec3, n: Vec3, eta: f32) Vec3;
// Type conversions
pub extern fn v3FromV2(v: Vec2, z: f32) Vec3;
pub extern fn v4FromV3(v: Vec3, w: f32) Vec4;
pub extern fn v2FromV3(v: Vec3) Vec2;
pub extern fn v3FromV4(v: Vec4) Vec3;
