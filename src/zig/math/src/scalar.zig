// Math utility functions implemented in Zig without std library
// Using hardware acceleration where possible through intrinsics

// Constants needed for calculations
pub const PI: f32 = 3.14159265358979323846;
pub const PI_OVER_180: f32 = PI / 180.0;
pub const _180_OVER_PI: f32 = 180.0 / PI;

/// Convert degrees to radians
pub export fn rad(degree: f32) f32 {
    return degree * PI_OVER_180;
}

/// Convert radians to degrees
pub export fn deg(radian: f32) f32 {
    return radian * _180_OVER_PI;
}

/// Linear interpolation between a and b using t as factor
pub export fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + t * (b - a);
}

/// Clamp value between min and max
pub export fn clamp(val: f32, minimum: f32, maximum: f32) f32 {
    if (val < minimum) return minimum;
    if (val > maximum) return maximum;
    return val;
}

/// Step function, returns 0.0 if x < edge, otherwise 1.0
pub export fn step(edge: f32, x: f32) f32 {
    return if (x < edge) 0.0 else 1.0;
}

/// Smooth Hermite interpolation
pub export fn smoothstep(edge0: f32, edge1: f32, x: f32) f32 {
    // Clamp x to 0..1 range
    const t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

/// Return minimum of two values
pub export fn min(a: f32, b: f32) f32 {
    return if (a < b) a else b;
}

/// Return maximum of two values
pub export fn max(a: f32, b: f32) f32 {
    return if (a > b) a else b;
}

/// Return absolute value
pub export fn abs(x: f32) f32 {
    return if (x < 0.0) -x else x;
}

/// Return largest integer not greater than x
pub export fn floor(x: f32) f32 {
    // Hardware implementation using assembly if available
    // This could be replaced with platform-specific intrinsics
    const i = @as(i32, @intFromFloat(x));
    const f = @as(f32, @floatFromInt(i));
    return if (x < 0.0 and f != x) f - 1.0 else f;
}

/// Return smallest integer not less than x
pub export fn ceil(x: f32) f32 {
    const i = @as(i32, @intFromFloat(x));
    const f = @as(f32, @floatFromInt(i));
    return if (x > 0.0 and f != x) f + 1.0 else f;
}

/// Round to nearest integer
pub export fn round(x: f32) f32 {
    return floor(x + 0.5);
}

/// Return remainder of x / y
pub export fn mod(x: f32, y: f32) f32 {
    return x - y * floor(x / y);
}

/// Raise x to power y
pub export fn pow(x: f32, y: f32) f32 {
    // Implementation for integer y values (optimized case)
    if (y == 0.0) return 1.0;
    if (x == 0.0) return 0.0;

    // For non-integer powers, we can use an approximation
    // Taylor series approximation (limited range/precision)
    if (x > 0.0) {
        const ln_x = @log(x);
        return @exp(y * ln_x);
    } else {
        // Handle negative base with integer exponent
        const int_y = @as(i32, @intFromFloat(y));
        if (@as(f32, @floatFromInt(int_y)) == y) {
            const result = pow(-x, y);
            return if (@mod(int_y, 2) == 0) result else -result;
        } else {
            return 0.0 / 0.0; // NaN for negative base with non-integer exponent
        }
    }
}

/// Square root function
pub export fn sqrt(x: f32) f32 {
    if (x < 0.0) return 0.0 / 0.0; // NaN
    if (x == 0.0) return 0.0;

    // Hardware implementation using assembly if available
    // This could be replaced with platform-specific intrinsics
    return @sqrt(x);
}

/// Sine function
pub export fn sin(x: f32) f32 {
    return @sin(x);
}

/// Cosine function
pub export fn cos(x: f32) f32 {
    // Use identity: cos(x) = sin(x + π/2)
    return sin(x + PI / 2.0);
}

/// Tangent function
pub export fn tan(x: f32) f32 {
    const cos_x = cos(x);
    if (cos_x == 0.0) return @as(f32, @bitCast(@as(u32, 0x7F800000))); // Infinity
    return sin(x) / cos_x;
}

/// Arcsine function
pub export fn asin(x: f32) f32 {
    // Approximation using Taylor series
    if (x < -1.0 or x > 1.0) return 0.0 / 0.0; // NaN

    // asin(x) ≈ x + (x³/6) + (3x⁵/40) + (5x⁷/112) + ...
    const x2 = x * x;
    const x3 = x2 * x;
    const x5 = x3 * x2;
    const x7 = x5 * x2;

    return x + x3 / 6.0 + 3.0 * x5 / 40.0 + 5.0 * x7 / 112.0;
}

/// Arccosine function
pub export fn acos(x: f32) f32 {
    // Use identity: acos(x) = π/2 - asin(x)
    return PI / 2.0 - asin(x);
}

/// Arctangent function
pub export fn atan(x: f32) f32 {
    // Approximation for the range [-1, 1]
    if (abs(x) <= 1.0) {
        const x2 = x * x;
        const x3 = x2 * x;
        const x5 = x3 * x2;
        const x7 = x5 * x2;
        return x - x3 / 3.0 + x5 / 5.0 - x7 / 7.0;
    } else {
        // For |x| > 1, use atan(x) = π/2 - atan(1/x)
        const sign: f32 = if (x > 0.0) 1.0 else -1.0;
        return sign * PI / 2.0 - atan(1.0 / x);
    }
}

/// Two-argument arctangent
pub export fn atan2(y: f32, x: f32) f32 {
    if (x > 0.0) {
        return atan(y / x);
    } else if (x < 0.0) {
        return atan(y / x) + (if (y >= 0.0) PI else -PI);
    } else {
        return if (y > 0.0) PI / 2.0 else if (y < 0.0) -PI / 2.0 else 0.0;
    }
}

/// Approximately equal within epsilon
pub export fn eq(a: f32, b: f32, eps: f32) bool {
    return abs(a - b) <= eps;
}

pub export fn log(x: f32) f32 {
    return @log(x);
}

// Added: Base-2 logarithm
pub export fn log2(x: f32) f32 {
    return @log2(x);
}

// Added: Base-10 logarithm
pub export fn log10(x: f32) f32 {
    return @log10(x);
}

// Added: Exponential function (e^x)
pub export fn exp(x: f32) f32 {
    return @exp(x);
}

pub export fn exp2(x: f32) f32 {
    return @exp2(x);
}
