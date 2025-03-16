const scalar = @import("scalar.zig");
const std = @import("std");

pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub inline fn asArray(self: *const Vec2) *const [2]f32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [2]f32) Vec2 {
        return @bitCast(arr.*);
    }
};

pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub inline fn asArray(self: *const Vec3) *const [3]f32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [3]f32) Vec3 {
        return @bitCast(arr.*);
    }
};

pub const Vec4 = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub inline fn asArray(self: *const Vec4) *const [4]f32 {
        return @ptrCast(&self.x);
    }

    pub inline fn fromArray(arr: *const [4]f32) Vec4 {
        return @bitCast(arr.*);
    }
};

// Generic vector operations for any dimension
fn VecOp(comptime dim: usize) type {
    return struct {
        const Vector = switch (dim) {
            2 => Vec2,
            3 => Vec3,
            4 => Vec4,
            else => @compileError("Unsupported vector dimension"),
        };

        pub inline fn add(a: Vector, b: Vector) Vector {
            const aArr = a.asArray();
            const bArr = b.asArray();
            var result: [dim]f32 = undefined;

            for (0..dim) |i| {
                result[i] = aArr[i] + bArr[i];
            }

            return Vector.fromArray(&result);
        }

        pub inline fn sub(a: Vector, b: Vector) Vector {
            const aArr = a.asArray();
            const bArr = b.asArray();
            var result: [dim]f32 = undefined;

            for (0..dim) |i| {
                result[i] = aArr[i] - bArr[i];
            }

            return Vector.fromArray(&result);
        }

        pub inline fn mul(a: Vector, b: Vector) Vector {
            const aArr = a.asArray();
            const bArr = b.asArray();
            var result: [dim]f32 = undefined;

            for (0..dim) |i| {
                result[i] = aArr[i] * bArr[i];
            }

            return Vector.fromArray(&result);
        }

        pub inline fn div(a: Vector, b: Vector) Vector {
            const aArr = a.asArray();
            const bArr = b.asArray();
            var result: [dim]f32 = undefined;

            for (0..dim) |i| {
                result[i] = aArr[i] / bArr[i];
            }

            return Vector.fromArray(&result);
        }

        pub inline fn scale(v: Vector, s: f32) Vector {
            const vArr = v.asArray();
            var result: [dim]f32 = undefined;

            for (0..dim) |i| {
                result[i] = vArr[i] * s;
            }

            return Vector.fromArray(&result);
        }

        pub inline fn neg(v: Vector) Vector {
            const vArr = v.asArray();
            var result: [dim]f32 = undefined;

            for (0..dim) |i| {
                result[i] = -vArr[i];
            }

            return Vector.fromArray(&result);
        }

        pub inline fn dot(a: Vector, b: Vector) f32 {
            const aArr = a.asArray();
            const bArr = b.asArray();
            var sum: f32 = 0;

            for (0..dim) |i| {
                sum += aArr[i] * bArr[i];
            }

            return sum;
        }

        pub inline fn len2(v: Vector) f32 {
            return dot(v, v);
        }

        pub inline fn len(v: Vector) f32 {
            return scalar.sqrt(len2(v));
        }

        pub inline fn dist2(a: Vector, b: Vector) f32 {
            return len2(sub(a, b));
        }

        pub inline fn dist(a: Vector, b: Vector) f32 {
            return scalar.sqrt(dist2(a, b));
        }

        pub inline fn norm(v: Vector) Vector {
            const length = len(v);
            if (length < 0.000001) {
                return zero();
            }
            return scale(v, 1.0 / length);
        }

        pub inline fn lerp(a: Vector, b: Vector, t: f32) Vector {
            const aArr = a.asArray();
            const bArr = b.asArray();
            var result: [dim]f32 = undefined;

            for (0..dim) |i| {
                result[i] = scalar.lerp(aArr[i], bArr[i], t);
            }

            return Vector.fromArray(&result);
        }

        pub inline fn eq(a: Vector, b: Vector, eps: f32) bool {
            const aArr = a.asArray();
            const bArr = b.asArray();

            for (0..dim) |i| {
                if (!scalar.eq(aArr[i], bArr[i], eps)) {
                    return false;
                }
            }

            return true;
        }

        pub inline fn zero() Vector {
            var result: [dim]f32 = undefined;
            for (0..dim) |i| {
                result[i] = 0;
            }
            return Vector.fromArray(&result);
        }

        pub inline fn one() Vector {
            var result: [dim]f32 = undefined;
            for (0..dim) |i| {
                result[i] = 1;
            }
            return Vector.fromArray(&result);
        }

        pub inline fn unit(idx: usize) Vector {
            var result: [dim]f32 = undefined;
            for (0..dim) |i| {
                result[i] = if (i == idx) 1 else 0;
            }
            return Vector.fromArray(&result);
        }
    };
}

// Constructor functions
pub fn v2(x: f32, y: f32) Vec2 {
    return .{ .x = x, .y = y };
}

pub fn v3(x: f32, y: f32, z: f32) Vec3 {
    return .{ .x = x, .y = y, .z = z };
}

pub fn v4(x: f32, y: f32, z: f32, w: f32) Vec4 {
    return .{ .x = x, .y = y, .z = z, .w = w };
}

// Common constants
pub fn v2Zero() Vec2 {
    return VecOp(2).zero();
}

pub fn v3Zero() Vec3 {
    return VecOp(3).zero();
}

pub fn v4Zero() Vec4 {
    return VecOp(4).zero();
}

pub fn v2One() Vec2 {
    return VecOp(2).one();
}

pub fn v3One() Vec3 {
    return VecOp(3).one();
}

pub fn v4One() Vec4 {
    return VecOp(4).one();
}

// Unit vectors
pub fn v2X() Vec2 {
    return VecOp(2).unit(0);
}

pub fn v2Y() Vec2 {
    return VecOp(2).unit(1);
}

pub fn v3X() Vec3 {
    return VecOp(3).unit(0);
}

pub fn v3Y() Vec3 {
    return VecOp(3).unit(1);
}

pub fn v3Z() Vec3 {
    return VecOp(3).unit(2);
}

pub fn v4X() Vec4 {
    return VecOp(4).unit(0);
}

pub fn v4Y() Vec4 {
    return VecOp(4).unit(1);
}

pub fn v4Z() Vec4 {
    return VecOp(4).unit(2);
}

pub fn v4W() Vec4 {
    return VecOp(4).unit(3);
}

// Basic operations
pub fn v2Add(a: Vec2, b: Vec2) Vec2 {
    return VecOp(2).add(a, b);
}

pub fn v3Add(a: Vec3, b: Vec3) Vec3 {
    return VecOp(3).add(a, b);
}

pub fn v4Add(a: Vec4, b: Vec4) Vec4 {
    return VecOp(4).add(a, b);
}

pub fn v2Sub(a: Vec2, b: Vec2) Vec2 {
    return VecOp(2).sub(a, b);
}

pub fn v3Sub(a: Vec3, b: Vec3) Vec3 {
    return VecOp(3).sub(a, b);
}

pub fn v4Sub(a: Vec4, b: Vec4) Vec4 {
    return VecOp(4).sub(a, b);
}

pub fn v2Mul(a: Vec2, b: Vec2) Vec2 {
    return VecOp(2).mul(a, b);
}

pub fn v3Mul(a: Vec3, b: Vec3) Vec3 {
    return VecOp(3).mul(a, b);
}

pub fn v4Mul(a: Vec4, b: Vec4) Vec4 {
    return VecOp(4).mul(a, b);
}

pub fn v2Div(a: Vec2, b: Vec2) Vec2 {
    return VecOp(2).div(a, b);
}

pub fn v3Div(a: Vec3, b: Vec3) Vec3 {
    return VecOp(3).div(a, b);
}

pub fn v4Div(a: Vec4, b: Vec4) Vec4 {
    return VecOp(4).div(a, b);
}

pub fn v2Scale(v: Vec2, s: f32) Vec2 {
    return VecOp(2).scale(v, s);
}

pub fn v3Scale(v: Vec3, s: f32) Vec3 {
    return VecOp(3).scale(v, s);
}

pub fn v4Scale(v: Vec4, s: f32) Vec4 {
    return VecOp(4).scale(v, s);
}

pub fn v2Neg(v: Vec2) Vec2 {
    return VecOp(2).neg(v);
}

pub fn v3Neg(v: Vec3) Vec3 {
    return VecOp(3).neg(v);
}

pub fn v4Neg(v: Vec4) Vec4 {
    return VecOp(4).neg(v);
}

// Vector operations
pub fn v2Dot(a: Vec2, b: Vec2) f32 {
    return VecOp(2).dot(a, b);
}

pub fn v3Dot(a: Vec3, b: Vec3) f32 {
    return VecOp(3).dot(a, b);
}

pub fn v4Dot(a: Vec4, b: Vec4) f32 {
    return VecOp(4).dot(a, b);
}

pub fn v3Cross(a: Vec3, b: Vec3) Vec3 {
    return .{
        .x = a.y * b.z - a.z * b.y,
        .y = a.z * b.x - a.x * b.z,
        .z = a.x * b.y - a.y * b.x,
    };
}

pub fn v2Len(v: Vec2) f32 {
    return VecOp(2).len(v);
}

pub fn v3Len(v: Vec3) f32 {
    return VecOp(3).len(v);
}

pub fn v4Len(v: Vec4) f32 {
    return VecOp(4).len(v);
}

pub fn v2Len2(v: Vec2) f32 {
    return VecOp(2).len2(v);
}

pub fn v3Len2(v: Vec3) f32 {
    return VecOp(3).len2(v);
}

pub fn v4Len2(v: Vec4) f32 {
    return VecOp(4).len2(v);
}

pub fn v2Dist(a: Vec2, b: Vec2) f32 {
    return VecOp(2).dist(a, b);
}

pub fn v3Dist(a: Vec3, b: Vec3) f32 {
    return VecOp(3).dist(a, b);
}

pub fn v4Dist(a: Vec4, b: Vec4) f32 {
    return VecOp(4).dist(a, b);
}

pub fn v2Dist2(a: Vec2, b: Vec2) f32 {
    return VecOp(2).dist2(a, b);
}

pub fn v3Dist2(a: Vec3, b: Vec3) f32 {
    return VecOp(3).dist2(a, b);
}

pub fn v4Dist2(a: Vec4, b: Vec4) f32 {
    return VecOp(4).dist2(a, b);
}

pub fn v2Norm(v: Vec2) Vec2 {
    return VecOp(2).norm(v);
}

pub fn v3Norm(v: Vec3) Vec3 {
    return VecOp(3).norm(v);
}

pub fn v4Norm(v: Vec4) Vec4 {
    return VecOp(4).norm(v);
}

// Interpolation and comparison
pub fn v2Lerp(a: Vec2, b: Vec2, t: f32) Vec2 {
    return VecOp(2).lerp(a, b, t);
}

pub fn v3Lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
    return VecOp(3).lerp(a, b, t);
}

pub fn v4Lerp(a: Vec4, b: Vec4, t: f32) Vec4 {
    return VecOp(4).lerp(a, b, t);
}

pub fn v2Eq(a: Vec2, b: Vec2, eps: f32) bool {
    return VecOp(2).eq(a, b, eps);
}

pub fn v3Eq(a: Vec3, b: Vec3, eps: f32) bool {
    return VecOp(3).eq(a, b, eps);
}

pub fn v4Eq(a: Vec4, b: Vec4, eps: f32) bool {
    return VecOp(4).eq(a, b, eps);
}

// Reflection and refraction
pub fn v2Reflect(v: Vec2, n: Vec2) Vec2 {
    const dot2 = v2Dot(v, n) * 2.0;
    return v2Sub(v, v2Scale(n, dot2));
}

pub fn v3Reflect(v: Vec3, n: Vec3) Vec3 {
    const dot2 = v3Dot(v, n) * 2.0;
    return v3Sub(v, v3Scale(n, dot2));
}

pub fn v3Refract(v: Vec3, n: Vec3, eta: f32) Vec3 {
    const dot = v3Dot(v, n);
    const k = 1.0 - eta * eta * (1.0 - dot * dot);

    if (k < 0.0) {
        return v3Zero(); // Total internal reflection
    } else {
        return v3Sub(v3Scale(v, eta), v3Scale(n, eta * dot + scalar.sqrt(k)));
    }
}

// Type conversions
pub fn v3FromV2(v: Vec2, z: f32) Vec3 {
    return .{ .x = v.x, .y = v.y, .z = z };
}

pub fn v4FromV3(v: Vec3, w: f32) Vec4 {
    return .{ .x = v.x, .y = v.y, .z = v.z, .w = w };
}

pub fn v2FromV3(v: Vec3) Vec2 {
    return .{ .x = v.x, .y = v.y };
}

pub fn v3FromV4(v: Vec4) Vec3 {
    return .{ .x = v.x, .y = v.y, .z = v.z };
}
