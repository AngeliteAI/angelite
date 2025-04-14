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
pub extern fn logf(x: f32) f32;
pub extern fn log2f(x: f32) f32;
pub extern fn log10f(x: f32) f32;
pub extern fn exp(x: f32) f32;
pub extern fn exp2(x: f32) f32;
