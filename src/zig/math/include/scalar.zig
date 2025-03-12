// scalar.zig
// Scalar operations for C ABI math library

pub extern fn rad(deg: f32) f32;
pub extern fn deg(rad: f32) f32;
pub extern fn lerp(a: f32, b: f32, t: f32) f32;
pub extern fn clamp(val: f32, min: f32, max: f32) f32;
pub extern fn step(edge: f32, x: f32) f32;
pub extern fn smoothstep(edge0: f32, edge1: f32, x: f32) f32;
pub extern fn min(a: f32, b: f32) f32;
pub extern fn max(a: f32, b: f32) f32;
pub extern fn abs(x: f32) f32;
pub extern fn floor(x: f32) f32;
pub extern fn ceil(x: f32) f32;
pub extern fn round(x: f32) f32;
pub extern fn mod(x: f32, y: f32) f32;
pub extern fn pow(x: f32, y: f32) f32;
pub extern fn sqrt(x: f32) f32;
pub extern fn sin(x: f32) f32;
pub extern fn cos(x: f32) f32;
pub extern fn tan(x: f32) f32;
pub extern fn asin(x: f32) f32;
pub extern fn acos(x: f32) f32;
pub extern fn atan(x: f32) f32;
pub extern fn atan2(y: f32, x: f32) f32;
pub extern fn eq(a: f32, b: f32, eps: f32) bool;

// vec.zig
// Vector types and operations for C ABI math library

const std = @import("std");

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
pub extern fn v2_zero() Vec2;
pub extern fn v3_zero() Vec3;
pub extern fn v4_zero() Vec4;

pub extern fn v2_one() Vec2;
pub extern fn v3_one() Vec3;
pub extern fn v4_one() Vec4;

// Unit vectors
pub extern fn v2_x() Vec2;
pub extern fn v2_y() Vec2;

pub extern fn v3_x() Vec3;
pub extern fn v3_y() Vec3;
pub extern fn v3_z() Vec3;

pub extern fn v4_x() Vec4;
pub extern fn v4_y() Vec4;
pub extern fn v4_z() Vec4;
pub extern fn v4_w() Vec4;

// Basic operations
pub extern fn v2_add(a: Vec2, b: Vec2) Vec2;
pub extern fn v3_add(a: Vec3, b: Vec3) Vec3;
pub extern fn v4_add(a: Vec4, b: Vec4) Vec4;

pub extern fn v2_sub(a: Vec2, b: Vec2) Vec2;
pub extern fn v3_sub(a: Vec3, b: Vec3) Vec3;
pub extern fn v4_sub(a: Vec4, b: Vec4) Vec4;

pub extern fn v2_mul(a: Vec2, b: Vec2) Vec2;
pub extern fn v3_mul(a: Vec3, b: Vec3) Vec3;
pub extern fn v4_mul(a: Vec4, b: Vec4) Vec4;

pub extern fn v2_div(a: Vec2, b: Vec2) Vec2;
pub extern fn v3_div(a: Vec3, b: Vec3) Vec3;
pub extern fn v4_div(a: Vec4, b: Vec4) Vec4;

pub extern fn v2_scale(v: Vec2, s: f32) Vec2;
pub extern fn v3_scale(v: Vec3, s: f32) Vec3;
pub extern fn v4_scale(v: Vec4, s: f32) Vec4;

pub extern fn v2_neg(v: Vec2) Vec2;
pub extern fn v3_neg(v: Vec3) Vec3;
pub extern fn v4_neg(v: Vec4) Vec4;

// Vector operations
pub extern fn v2_dot(a: Vec2, b: Vec2) f32;
pub extern fn v3_dot(a: Vec3, b: Vec3) f32;
pub extern fn v4_dot(a: Vec4, b: Vec4) f32;

pub extern fn v3_cross(a: Vec3, b: Vec3) Vec3;

pub extern fn v2_len(v: Vec2) f32;
pub extern fn v3_len(v: Vec3) f32;
pub extern fn v4_len(v: Vec4) f32;

pub extern fn v2_len2(v: Vec2) f32;
pub extern fn v3_len2(v: Vec3) f32;
pub extern fn v4_len2(v: Vec4) f32;

pub extern fn v2_dist(a: Vec2, b: Vec2) f32;
pub extern fn v3_dist(a: Vec3, b: Vec3) f32;
pub extern fn v4_dist(a: Vec4, b: Vec4) f32;

pub extern fn v2_dist2(a: Vec2, b: Vec2) f32;
pub extern fn v3_dist2(a: Vec3, b: Vec3) f32;
pub extern fn v4_dist2(a: Vec4, b: Vec4) f32;

pub extern fn v2_norm(v: Vec2) Vec2;
pub extern fn v3_norm(v: Vec3) Vec3;
pub extern fn v4_norm(v: Vec4) Vec4;

// Interpolation and comparison
pub extern fn v2_lerp(a: Vec2, b: Vec2, t: f32) Vec2;
pub extern fn v3_lerp(a: Vec3, b: Vec3, t: f32) Vec3;
pub extern fn v4_lerp(a: Vec4, b: Vec4, t: f32) Vec4;

pub extern fn v2_eq(a: Vec2, b: Vec2, eps: f32) bool;
pub extern fn v3_eq(a: Vec3, b: Vec3, eps: f32) bool;
pub extern fn v4_eq(a: Vec4, b: Vec4, eps: f32) bool;

// Reflection and refraction
pub extern fn v2_reflect(v: Vec2, n: Vec2) Vec2;
pub extern fn v3_reflect(v: Vec3, n: Vec3) Vec3;
pub extern fn v3_refract(v: Vec3, n: Vec3, eta: f32) Vec3;

// Type conversions
pub extern fn v3_from_v2(v: Vec2, z: f32) Vec3;
pub extern fn v4_from_v3(v: Vec3, w: f32) Vec4;
pub extern fn v2_from_v3(v: Vec3) Vec2;
pub extern fn v3_from_v4(v: Vec4) Vec3;

// Random vectors
pub extern fn v2_rand(min: f32, max: f32) Vec2;
pub extern fn v3_rand(min: f32, max: f32) Vec3;
pub extern fn v3_rand_unit() Vec3;
pub extern fn v3_rand_sphere() Vec3;
