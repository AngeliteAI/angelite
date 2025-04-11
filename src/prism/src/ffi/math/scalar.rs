extern "C" {
    // Constants
    pub static PI: f32;
    pub static PI_OVER_180: f32;
    pub static _180_OVER_PI: f32;

    // Conversion functions
    pub fn rad(degree: f32) -> f32;
    pub fn deg(radian: f32) -> f32;

    // Math operations
    pub fn lerp(a: f32, b: f32, t: f32) -> f32;
    pub fn clamp(val: f32, minimum: f32, maximum: f32) -> f32;
    pub fn step(edge: f32, x: f32) -> f32;
    pub fn smoothstep(edge0: f32, edge1: f32, x: f32) -> f32;
    pub fn min(a: f32, b: f32) -> f32;
    pub fn max(a: f32, b: f32) -> f32;
    pub fn abs(x: f32) -> f32;
    pub fn floor(x: f32) -> f32;
    pub fn ceil(x: f32) -> f32;
    pub fn round(x: f32) -> f32;
    pub fn mod_(x: f32, y: f32) -> f32;
    pub fn pow(x: f32, y: f32) -> f32;
    pub fn sqrt(x: f32) -> f32;
    pub fn sin(x: f32) -> f32;
    pub fn cos(x: f32) -> f32;
    pub fn tan(x: f32) -> f32;
    pub fn asin(x: f32) -> f32;
    pub fn acos(x: f32) -> f32;
    pub fn atan(x: f32) -> f32;
    pub fn atan2(y: f32, x: f32) -> f32;
    pub fn eq(a: f32, b: f32, eps: f32) -> bool;
    pub fn log(x: f32) -> f32;
    pub fn log2(x: f32) -> f32;
    pub fn log10(x: f32) -> f32;
    pub fn exp(x: f32) -> f32;
    pub fn exp2(x: f32) -> f32;
}
