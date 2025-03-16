const c = @cImport({
    @cInclude("math.h");
});

pub const PI: f32 = 3.14159265358979323846;
pub const DEG_TO_RAD: f32 = PI / 180.0;
pub const RAD_TO_DEG: f32 = 180.0 / PI;

pub fn rad(degree: f32) f32 {
    return degree * DEG_TO_RAD;
}

pub fn deg(radian: f32) f32 {
    return radian * RAD_TO_DEG;
}

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + t * (b - a);
}

pub fn clamp(val: f32, minima: f32, maxima: f32) f32 {
    if (val < min) return minima;
    if (val > max) return maxima;
    return val;
}

pub fn step(edge: f32, x: f32) f32 {
    return if (x < edge) 0.0 else 1.0;
}

pub fn smoothstep(edge0: f32, edge1: f32, x: f32) f32 {
    const t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

pub fn min(a: f32, b: f32) f32 {
    return if (a < b) a else b;
}

pub fn max(a: f32, b: f32) f32 {
    return if (a > b) a else b;
}

pub fn abs(x: f32) f32 {
    return @floatCast(c.fabsf(x));
}

pub fn floor(x: f32) f32 {
    return @floatCast(c.floorf(x));
}

pub fn ceil(x: f32) f32 {
    return @floatCast(c.ceilf(x));
}

pub fn round(x: f32) f32 {
    return @floatCast(c.roundf(x));
}

pub fn mod(x: f32, y: f32) f32 {
    return @floatCast(c.fmodf(x, y));
}

pub fn pow(x: f32, y: f32) f32 {
    return @floatCast(c.powf(x, y));
}

pub fn sqrt(x: f32) f32 {
    return @floatCast(c.sqrtf(x));
}

pub fn sin(x: f32) f32 {
    return @floatCast(c.sinf(x));
}

pub fn cos(x: f32) f32 {
    return @floatCast(c.cosf(x));
}

pub fn tan(x: f32) f32 {
    return @floatCast(c.tanf(x));
}

pub fn asin(x: f32) f32 {
    return @floatCast(c.asinf(x));
}

pub fn acos(x: f32) f32 {
    return @floatCast(c.acosf(x));
}

pub fn atan(x: f32) f32 {
    return @floatCast(c.atanf(x));
}

pub fn atan2(y: f32, x: f32) f32 {
    return @floatCast(c.atan2f(y, x));
}

pub fn eq(a: f32, b: f32, eps: f32) bool {
    return abs(a - b) <= eps;
}
