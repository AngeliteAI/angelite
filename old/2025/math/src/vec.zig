const scalar = @import("scalar.zig");
const vec = @import("include").vec;

pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;
pub const Vec4 = vec.Vec4;
pub const IVec2 = vec.IVec2;
pub const IVec3 = vec.IVec3;
pub const IVec4 = vec.IVec4;
pub const UVec2 = vec.UVec2;
pub const UVec3 = vec.UVec3;
pub const UVec4 = vec.UVec4;

fn isInteger(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == .int;
}

fn isSignedInteger(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == .int and info.int.signedness == .signed;
}

fn isUnsignedInteger(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == .int and info.int.signedness == .unsigned;
}

fn isFloat32(comptime T: type) bool {
    return T == f32;
}

fn VecOp(comptime dim: usize, comptime VectorType: type) type {
    const ElementType = @typeInfo(VectorType).@"struct".fields[0].type;
    const FloatVector = Vec(dim, f32);

    comptime if (isFloat32(ElementType)) {
        //========================================//
        //          f32 Vector Operations         //
        //========================================//
        return struct {
            const Vector = VectorType;
            const Element = ElementType;
            const FloatVec = FloatVector; // Is the same as Vector for f32

            pub inline fn add(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = aArr[i] + bArr[i];
                }
                return Vector.fromArray(&result);
            }
            pub inline fn sub(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = aArr[i] - bArr[i];
                }
                return Vector.fromArray(&result);
            }
            pub inline fn mul(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = aArr[i] * bArr[i];
                }
                return Vector.fromArray(&result);
            }
            pub inline fn div(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = aArr[i] / bArr[i];
                }
                return Vector.fromArray(&result);
            }
            pub inline fn scale(v: Vector, s: Element) Vector {
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = vArr[i] * s;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn neg(v: Vector) Vector {
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = -vArr[i];
                }
                return Vector.fromArray(&result);
            }
            pub inline fn dot(a: Vector, b: Vector) Element {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var sum: Element = 0;
                for (0..dim) |i| {
                    sum += aArr[i] * bArr[i];
                }
                return sum;
            }
            pub inline fn len2(v: Vector) Element {
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
            pub inline fn norm(v: Vector) Vector { // Returns Vector (f32)
                const length = len(v);
                if (length < 0.000001) {
                    return zero();
                }
                return scale(v, 1.0 / length);
            }
            pub inline fn lerp(a: Vector, b: Vector, t: f32) Vector { // Returns Vector (f32)
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
                    if (!scalar.eq(aArr[i], bArr[i], eps)) return false;
                }
                return true;
            }
            pub inline fn zero() Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = 0;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn one() Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = 1;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn unit(idx: usize) Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = if (i == idx) 1 else 0;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn splat(s: Element) Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = s;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn clamp(v: Vector, minVal: Element, maxVal: Element) Vector {
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = @min(@max(vArr[i], minVal), maxVal);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn abs(v: Vector) Vector { // Uses scalar.abs for f32
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = scalar.abs(vArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn minComponent(v: Vector) Element {
                const vArr = v.asArray();
                var min_val: Element = vArr[0];
                for (1..dim) |i| {
                    if (vArr[i] < min_val) min_val = vArr[i];
                }
                return min_val;
            }
            pub inline fn maxComponent(v: Vector) Element {
                const vArr = v.asArray();
                var max_val: Element = vArr[0];
                for (1..dim) |i| {
                    if (vArr[i] > max_val) max_val = vArr[i];
                }
                return max_val;
            }
            pub inline fn componentMin(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = @min(aArr[i], bArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn componentMax(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = @max(aArr[i], bArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn floor(v: Vector) Vector {
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = scalar.floor(vArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn ceil(v: Vector) Vector {
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = scalar.ceil(vArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn round(v: Vector) Vector {
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = scalar.round(vArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn step(edge: Vector, v: Vector) Vector { // Returns Vector (f32)
                const edgeArr = edge.asArray();
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = scalar.step(edgeArr[i], vArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn smoothstep(edge0: Vector, edge1: Vector, v: Vector) Vector { // Returns Vector (f32)
                const edge0Arr = edge0.asArray();
                const edge1Arr = edge1.asArray();
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = scalar.smoothstep(edge0Arr[i], edge1Arr[i], vArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn isZero(v: Vector, eps: f32) bool {
                return eq(v, zero(), eps);
            }
            pub inline fn isOne(v: Vector, eps: f32) bool {
                return eq(v, one(), eps);
            }
            pub inline fn isUnit(v: Vector, eps: f32) bool {
                return scalar.eq(len(v), 1.0, eps);
            }
        };
    } else if (isUnsignedInteger(ElementType)) {
        //========================================//
        //    Unsigned Integer Vector Operations  //
        //========================================//
        return struct {
            const Vector = VectorType;
            const Element = ElementType;
            const FloatVec = FloatVector;

            pub inline fn add(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = aArr[i] +% bArr[i];
                }
                return Vector.fromArray(&result); // Wrap add
            }
            pub inline fn sub(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = aArr[i] -% bArr[i];
                }
                return Vector.fromArray(&result); // Wrap sub
            }
            pub inline fn mul(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = aArr[i] *% bArr[i];
                }
                return Vector.fromArray(&result); // Wrap mul
            }
            pub inline fn div(a: Vector, b: Vector) Vector { // Integer division
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = @divTrunc(aArr[i], bArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn scale(v: Vector, s: Element) Vector {
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = vArr[i] *% s;
                }
                return Vector.fromArray(&result); // Wrap mul
            }
            pub inline fn neg(v: Vector) Vector { // Unsigned negation (wrap around 0)
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = 0 -% vArr[i];
                }
                return Vector.fromArray(&result);
            }
            pub inline fn dot(a: Vector, b: Vector) Element {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var sum: Element = 0;
                for (0..dim) |i| {
                    sum +%= aArr[i] *% bArr[i];
                }
                return sum; // Wrap add/mul
            }
            pub inline fn len2(v: Vector) Element {
                return dot(v, v);
            }
            pub inline fn len(v: Vector) f32 {
                return scalar.sqrt(@as(f32, @floatFromInt(len2(v))));
            }
            pub inline fn dist2(a: Vector, b: Vector) Element {
                return len2(sub(a, b));
            }
            pub inline fn dist(a: Vector, b: Vector) f32 {
                return scalar.sqrt(@as(f32, @floatFromInt(dist2(a, b))));
            }
            pub inline fn norm(v: Vector) FloatVec { // Convert to f32 vector and normalize
                const vArr = v.asArray();
                var floatArr: [dim]f32 = undefined;
                for (0..dim) |i| {
                    floatArr[i] = @as(f32, @floatFromInt(vArr[i]));
                }
                const floatVec = FloatVec.fromArray(&floatArr);
                const length = VecOp(dim, FloatVec).len(floatVec);
                if (length < 0.000001) {
                    return VecOp(dim, FloatVec).zero();
                }
                return VecOp(dim, FloatVec).scale(floatVec, 1.0 / length);
            }
            pub inline fn lerp(a: Vector, b: Vector, t: f32) FloatVec { // Convert to f32 vectors and lerp
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]f32 = undefined;
                for (0..dim) |i| {
                    const af: f32 = @as(f32, @floatFromInt(aArr[i]));
                    const bf: f32 = @as(f32, @floatFromInt(bArr[i]));
                    result[i] = scalar.lerp(af, bf, t);
                }
                return FloatVec.fromArray(&result);
            }
            pub inline fn eq(a: Vector, b: Vector, eps: Element) bool { // Exact comparison or within eps for integers
                const aArr = a.asArray();
                const bArr = b.asArray();
                for (0..dim) |i| {
                    const diff = if (aArr[i] > bArr[i]) aArr[i] - bArr[i] else bArr[i] - aArr[i];
                    if (diff > eps) return false;
                }
                return true;
            }
            pub inline fn zero() Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = 0;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn one() Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = 1;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn unit(idx: usize) Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = if (i == idx) 1 else 0;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn splat(s: Element) Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = s;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn clamp(v: Vector, minVal: Element, maxVal: Element) Vector {
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = @min(@max(vArr[i], minVal), maxVal);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn abs(v: Vector) Vector {
                return v;
            } // Abs of unsigned is itself
            pub inline fn minComponent(v: Vector) Element {
                const vArr = v.asArray();
                var min_val: Element = vArr[0];
                for (1..dim) |i| {
                    if (vArr[i] < min_val) min_val = vArr[i];
                }
                return min_val;
            }
            pub inline fn maxComponent(v: Vector) Element {
                const vArr = v.asArray();
                var max_val: Element = vArr[0];
                for (1..dim) |i| {
                    if (vArr[i] > max_val) max_val = vArr[i];
                }
                return max_val;
            }
            pub inline fn componentMin(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = @min(aArr[i], bArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn componentMax(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = @max(aArr[i], bArr[i]);
                }
                return Vector.fromArray(&result);
            }
            // No floor, ceil, round, step, smoothstep, isZero, isOne, isUnit for unsigned integers
        };
    } else if (isSignedInteger(ElementType)) {
        //========================================//
        //     Signed Integer Vector Operations   //
        //========================================//
        return struct {
            const Vector = VectorType;
            const Element = ElementType;
            const FloatVec = FloatVector;

            pub inline fn add(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = aArr[i] +% bArr[i];
                }
                return Vector.fromArray(&result); // Wrap add
            }
            pub inline fn sub(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = aArr[i] -% bArr[i];
                }
                return Vector.fromArray(&result); // Wrap sub
            }
            pub inline fn mul(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = aArr[i] *% bArr[i];
                }
                return Vector.fromArray(&result); // Wrap mul
            }
            pub inline fn div(a: Vector, b: Vector) Vector { // Integer division
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = @divTrunc(aArr[i], bArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn scale(v: Vector, s: Element) Vector {
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = vArr[i] *% s;
                }
                return Vector.fromArray(&result); // Wrap mul
            }
            pub inline fn neg(v: Vector) Vector { // Signed negation
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = -%vArr[i];
                }
                return Vector.fromArray(&result); // Wrap neg
            }
            pub inline fn dot(a: Vector, b: Vector) Element {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var sum: Element = 0;
                for (0..dim) |i| {
                    sum +%= aArr[i] *% bArr[i];
                }
                return sum; // Wrap add/mul
            }
            pub inline fn len2(v: Vector) Element {
                return dot(v, v);
            }
            pub inline fn len(v: Vector) f32 {
                return scalar.sqrt(@as(f32, @floatFromInt(len2(v))));
            }
            pub inline fn dist2(a: Vector, b: Vector) Element {
                return len2(sub(a, b));
            }
            pub inline fn dist(a: Vector, b: Vector) f32 {
                return scalar.sqrt(@as(f32, @floatFromInt(dist2(a, b))));
            }
            pub inline fn norm(v: Vector) FloatVec { // Convert to f32 vector and normalize
                const vArr = v.asArray();
                var floatArr: [dim]f32 = undefined;
                for (0..dim) |i| {
                    floatArr[i] = @as(f32, @floatFromInt(vArr[i]));
                }
                const floatVec = FloatVec.fromArray(&floatArr);
                const length = VecOp(dim, FloatVec).len(floatVec);
                if (length < 0.000001) {
                    return VecOp(dim, FloatVec).zero();
                }
                return VecOp(dim, FloatVec).scale(floatVec, 1.0 / length);
            }
            pub inline fn lerp(a: Vector, b: Vector, t: f32) FloatVec { // Convert to f32 vectors and lerp
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]f32 = undefined;
                for (0..dim) |i| {
                    const af: f32 = @as(f32, @floatFromInt(aArr[i]));
                    const bf: f32 = @as(f32, @floatFromInt(bArr[i]));
                    result[i] = scalar.lerp(af, bf, t);
                }
                return FloatVec.fromArray(&result);
            }
            pub inline fn eq(a: Vector, b: Vector, eps: Element) bool { // Exact comparison or within eps for integers
                const aArr = a.asArray();
                const bArr = b.asArray();
                for (0..dim) |i| {
                    const diff = if (aArr[i] > bArr[i]) aArr[i] -% bArr[i] else bArr[i] -% aArr[i];
                    if (diff > eps) return false; // Assuming eps is non-negative
                }
                return true;
            }
            pub inline fn zero() Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = 0;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn one() Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = 1;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn unit(idx: usize) Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = if (i == idx) 1 else 0;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn splat(s: Element) Vector {
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = s;
                }
                return Vector.fromArray(&result);
            }
            pub inline fn clamp(v: Vector, minVal: Element, maxVal: Element) Vector {
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = @min(@max(vArr[i], minVal), maxVal);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn abs(v: Vector) Vector { // Uses @abs for signed integers
                const vArr = v.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    // This line is causing the error:
                    // result[i] = @as(i32, @abs(@as(i32, vArr[i]))); // Incorrect

                    if (vArr[i] < 0) {
                        result[i] = -vArr[i];
                    } else {
                        result[i] = vArr[i];
                    }
                    // --- FIX ENDS HERE ---
                }
                return Vector.fromArray(&result);
            }
            pub inline fn minComponent(v: Vector) Element {
                const vArr = v.asArray();
                var min_val: Element = vArr[0];
                for (1..dim) |i| {
                    if (vArr[i] < min_val) min_val = vArr[i];
                }
                return min_val;
            }
            pub inline fn maxComponent(v: Vector) Element {
                const vArr = v.asArray();
                var max_val: Element = vArr[0];
                for (1..dim) |i| {
                    if (vArr[i] > max_val) max_val = vArr[i];
                }
                return max_val;
            }
            pub inline fn componentMin(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = @min(aArr[i], bArr[i]);
                }
                return Vector.fromArray(&result);
            }
            pub inline fn componentMax(a: Vector, b: Vector) Vector {
                const aArr = a.asArray();
                const bArr = b.asArray();
                var result: [dim]Element = undefined;
                for (0..dim) |i| {
                    result[i] = @max(aArr[i], bArr[i]);
                }
                return Vector.fromArray(&result);
            }
            // No floor, ceil, round, step, smoothstep, isZero, isOne, isUnit for signed integers
        };
    } else {
        @compileError("Unsupported ElementType for VecOp");
    };
}

fn Vec(comptime dim: usize, comptime ElementType: type) type {
    return switch (dim) {
        2 => if (ElementType == f32) Vec2 else if (ElementType == i32) IVec2 else if (ElementType == u32) UVec2 else @compileError("Unsupported element type for Vec2"),
        3 => if (ElementType == f32) Vec3 else if (ElementType == i32) IVec3 else if (ElementType == u32) UVec3 else @compileError("Unsupported element type for Vec3"),
        4 => if (ElementType == f32) Vec4 else if (ElementType == i32) IVec4 else if (ElementType == u32) UVec4 else @compileError("Unsupported element type for Vec4"),
        else => @compileError("Unsupported vector dimension"),
    };
}

// Constructor functions
pub export fn v2(x: f32, y: f32) Vec2 {
    return Vec2{ .x = x, .y = y };
}

pub export fn v3(x: f32, y: f32, z: f32) Vec3 {
    return Vec3{ .x = x, .y = y, .z = z };
}

pub export fn v4(x: f32, y: f32, z: f32, w: f32) Vec4 {
    return Vec4{ .x = x, .y = y, .z = z, .w = w };
}

pub export fn iv2(x: i32, y: i32) IVec2 {
    return IVec2{ .x = x, .y = y };
}

pub export fn iv3(x: i32, y: i32, z: i32) IVec3 {
    return IVec3{ .x = x, .y = y, .z = z };
}

pub export fn iv4(x: i32, y: i32, z: i32, w: i32) IVec4 {
    return IVec4{ .x = x, .y = y, .z = z, .w = w };
}

pub export fn uv2(x: u32, y: u32) UVec2 {
    return UVec2{ .x = x, .y = y };
}

pub export fn uv3(x: u32, y: u32, z: u32) UVec3 {
    return UVec3{ .x = x, .y = y, .z = z };
}

pub export fn uv4(x: u32, y: u32, z: u32, w: u32) UVec4 {
    return UVec4{ .x = x, .y = y, .z = z, .w = w };
}

// Common constants
pub export fn v2Zero() Vec2 {
    return VecOp(2, Vec2).zero();
}

pub export fn v3Zero() Vec3 {
    return VecOp(3, Vec3).zero();
}

pub export fn v4Zero() Vec4 {
    return VecOp(4, Vec4).zero();
}

pub export fn v2One() Vec2 {
    return VecOp(2, Vec2).one();
}

pub export fn v3One() Vec3 {
    return VecOp(3, Vec3).one();
}

pub export fn v4One() Vec4 {
    return VecOp(4, Vec4).one();
}

pub export fn iv2Zero() IVec2 {
    return VecOp(2, IVec2).zero();
}

pub export fn iv3Zero() IVec3 {
    return VecOp(3, IVec3).zero();
}

pub export fn iv4Zero() IVec4 {
    return VecOp(4, IVec4).zero();
}

pub export fn uv2Zero() UVec2 {
    return VecOp(2, UVec2).zero();
}

pub export fn uv3Zero() UVec3 {
    return VecOp(3, UVec3).zero();
}

pub export fn uv4Zero() UVec4 {
    return VecOp(4, UVec4).zero();
}

pub export fn iv2One() IVec2 {
    return VecOp(2, IVec2).one();
}

pub export fn iv3One() IVec3 {
    return VecOp(3, IVec3).one();
}

pub export fn iv4One() IVec4 {
    return VecOp(4, IVec4).one();
}

pub export fn uv2One() UVec2 {
    return VecOp(2, UVec2).one();
}

pub export fn uv3One() UVec3 {
    return VecOp(3, UVec3).one();
}

pub export fn uv4One() UVec4 {
    return VecOp(4, UVec4).one();
}

// Unit vectors
pub export fn v2X() Vec2 {
    return VecOp(2, Vec2).unit(0);
}

pub export fn v2Y() Vec2 {
    return VecOp(2, Vec2).unit(1);
}

pub export fn v3X() Vec3 {
    return VecOp(3, Vec3).unit(0);
}

pub export fn v3Y() Vec3 {
    return VecOp(3, Vec3).unit(1);
}

pub export fn v3Z() Vec3 {
    return VecOp(3, Vec3).unit(2);
}

pub export fn v4X() Vec4 {
    return VecOp(4, Vec4).unit(0);
}

pub export fn v4Y() Vec4 {
    return VecOp(4, Vec4).unit(1);
}

pub export fn v4Z() Vec4 {
    return VecOp(4, Vec4).unit(2);
}

pub export fn v4W() Vec4 {
    return VecOp(4, Vec4).unit(3);
}

pub export fn iv2X() IVec2 {
    return VecOp(2, IVec2).unit(0);
}

pub export fn iv2Y() IVec2 {
    return VecOp(2, IVec2).unit(1);
}

pub export fn iv3X() IVec3 {
    return VecOp(3, IVec3).unit(0);
}

pub export fn iv3Y() IVec3 {
    return VecOp(3, IVec3).unit(1);
}

pub export fn iv3Z() IVec3 {
    return VecOp(3, IVec3).unit(2);
}

pub export fn iv4X() IVec4 {
    return VecOp(4, IVec4).unit(0);
}

pub export fn iv4Y() IVec4 {
    return VecOp(4, IVec4).unit(1);
}

pub export fn iv4Z() IVec4 {
    return VecOp(4, IVec4).unit(2);
}

pub export fn iv4W() IVec4 {
    return VecOp(4, IVec4).unit(3);
}

pub export fn uv2X() UVec2 {
    return VecOp(2, UVec2).unit(0);
}

pub export fn uv2Y() UVec2 {
    return VecOp(2, UVec2).unit(1);
}

pub export fn uv3X() UVec3 {
    return VecOp(3, UVec3).unit(0);
}

pub export fn uv3Y() UVec3 {
    return VecOp(3, UVec3).unit(1);
}

pub export fn uv3Z() UVec3 {
    return VecOp(3, UVec3).unit(2);
}

pub export fn uv4X() UVec4 {
    return VecOp(4, UVec4).unit(0);
}

pub export fn uv4Y() UVec4 {
    return VecOp(4, UVec4).unit(1);
}

pub export fn uv4Z() UVec4 {
    return VecOp(4, UVec4).unit(2);
}

pub export fn uv4W() UVec4 {
    return VecOp(4, UVec4).unit(3);
}

// Basic operations
pub export fn v2Add(a: Vec2, b: Vec2) Vec2 {
    return VecOp(2, Vec2).add(a, b);
}

pub export fn v3Add(a: Vec3, b: Vec3) Vec3 {
    return VecOp(3, Vec3).add(a, b);
}

pub export fn v4Add(a: Vec4, b: Vec4) Vec4 {
    return VecOp(4, Vec4).add(a, b);
}

pub export fn v2Sub(a: Vec2, b: Vec2) Vec2 {
    return VecOp(2, Vec2).sub(a, b);
}

pub export fn v3Sub(a: Vec3, b: Vec3) Vec3 {
    return VecOp(3, Vec3).sub(a, b);
}

pub export fn v4Sub(a: Vec4, b: Vec4) Vec4 {
    return VecOp(4, Vec4).sub(a, b);
}

pub export fn v2Mul(a: Vec2, b: Vec2) Vec2 {
    return VecOp(2, Vec2).mul(a, b);
}

pub export fn v3Mul(a: Vec3, b: Vec3) Vec3 {
    return VecOp(3, Vec3).mul(a, b);
}

pub export fn v4Mul(a: Vec4, b: Vec4) Vec4 {
    return VecOp(4, Vec4).mul(a, b);
}

pub export fn v2Div(a: Vec2, b: Vec2) Vec2 {
    return VecOp(2, Vec2).div(a, b);
}

pub export fn v3Div(a: Vec3, b: Vec3) Vec3 {
    return VecOp(3, Vec3).div(a, b);
}

pub export fn v4Div(a: Vec4, b: Vec4) Vec4 {
    return VecOp(4, Vec4).div(a, b);
}

pub export fn v2Scale(v: Vec2, s: f32) Vec2 {
    return VecOp(2, Vec2).scale(v, s);
}

pub export fn v3Scale(v: Vec3, s: f32) Vec3 {
    return VecOp(3, Vec3).scale(v, s);
}

pub export fn v4Scale(v: Vec4, s: f32) Vec4 {
    return VecOp(4, Vec4).scale(v, s);
}

pub export fn v2Neg(v: Vec2) Vec2 {
    return VecOp(2, Vec2).neg(v);
}

pub export fn v3Neg(v: Vec3) Vec3 {
    return VecOp(3, Vec3).neg(v);
}

pub export fn v4Neg(v: Vec4) Vec4 {
    return VecOp(4, Vec4).neg(v);
}

pub export fn iv2Add(a: IVec2, b: IVec2) IVec2 {
    return VecOp(2, IVec2).add(a, b);
}

pub export fn iv3Add(a: IVec3, b: IVec3) IVec3 {
    return VecOp(3, IVec3).add(a, b);
}

pub export fn iv4Add(a: IVec4, b: IVec4) IVec4 {
    return VecOp(4, IVec4).add(a, b);
}

pub export fn iv2Sub(a: IVec2, b: IVec2) IVec2 {
    return VecOp(2, IVec2).sub(a, b);
}

pub export fn iv3Sub(a: IVec3, b: IVec3) IVec3 {
    return VecOp(3, IVec3).sub(a, b);
}

pub export fn iv4Sub(a: IVec4, b: IVec4) IVec4 {
    return VecOp(4, IVec4).sub(a, b);
}

pub export fn iv2Mul(a: IVec2, b: IVec2) IVec2 {
    return VecOp(2, IVec2).mul(a, b);
}

pub export fn iv3Mul(a: IVec3, b: IVec3) IVec3 {
    return VecOp(3, IVec3).mul(a, b);
}

pub export fn iv4Mul(a: IVec4, b: IVec4) IVec4 {
    return VecOp(4, IVec4).mul(a, b);
}

pub export fn iv2Div(a: IVec2, b: IVec2) IVec2 {
    return VecOp(2, IVec2).div(a, b);
}

pub export fn iv3Div(a: IVec3, b: IVec3) IVec3 {
    return VecOp(3, IVec3).div(a, b);
}

pub export fn iv4Div(a: IVec4, b: IVec4) IVec4 {
    return VecOp(4, IVec4).div(a, b);
}

pub export fn iv2Scale(v: IVec2, s: i32) IVec2 {
    return VecOp(2, IVec2).scale(v, s);
}

pub export fn iv3Scale(v: IVec3, s: i32) IVec3 {
    return VecOp(3, IVec3).scale(v, s);
}

pub export fn iv4Scale(v: IVec4, s: i32) IVec4 {
    return VecOp(4, IVec4).scale(v, s);
}

pub export fn iv2Neg(v: IVec2) IVec2 {
    return VecOp(2, IVec2).neg(v);
}

pub export fn iv3Neg(v: IVec3) IVec3 {
    return VecOp(3, IVec3).neg(v);
}

pub export fn iv4Neg(v: IVec4) IVec4 {
    return VecOp(4, IVec4).neg(v);
}

pub export fn uv2Add(a: UVec2, b: UVec2) UVec2 {
    return VecOp(2, UVec2).add(a, b);
}

pub export fn uv3Add(a: UVec3, b: UVec3) UVec3 {
    return VecOp(3, UVec3).add(a, b);
}

pub export fn uv4Add(a: UVec4, b: UVec4) UVec4 {
    return VecOp(4, UVec4).add(a, b);
}

pub export fn uv2Sub(a: UVec2, b: UVec2) UVec2 {
    return VecOp(2, UVec2).sub(a, b);
}

pub export fn uv3Sub(a: UVec3, b: UVec3) UVec3 {
    return VecOp(3, UVec3).sub(a, b);
}

pub export fn uv4Sub(a: UVec4, b: UVec4) UVec4 {
    return VecOp(4, UVec4).sub(a, b);
}

pub export fn uv2Mul(a: UVec2, b: UVec2) UVec2 {
    return VecOp(2, UVec2).mul(a, b);
}

pub export fn uv3Mul(a: UVec3, b: UVec3) UVec3 {
    return VecOp(3, UVec3).mul(a, b);
}

pub export fn uv4Mul(a: UVec4, b: UVec4) UVec4 {
    return VecOp(4, UVec4).mul(a, b);
}

pub export fn uv2Div(a: UVec2, b: UVec2) UVec2 {
    return VecOp(2, UVec2).div(a, b);
}

pub export fn uv3Div(a: UVec3, b: UVec3) UVec3 {
    return VecOp(3, UVec3).div(a, b);
}

pub export fn uv4Div(a: UVec4, b: UVec4) UVec4 {
    return VecOp(4, UVec4).div(a, b);
}

pub export fn uv2Scale(v: UVec2, s: u32) UVec2 {
    return VecOp(2, UVec2).scale(v, s);
}

pub export fn uv3Scale(v: UVec3, s: u32) UVec3 {
    return VecOp(3, UVec3).scale(v, s);
}

pub export fn uv4Scale(v: UVec4, s: u32) UVec4 {
    return VecOp(4, UVec4).scale(v, s);
}

pub export fn uv2Neg(v: UVec2) UVec2 {
    return VecOp(2, UVec2).neg(v); // Note: Negation for UVec might wrap around or be undefined depending on desired behavior.
}

pub export fn uv3Neg(v: UVec3) UVec3 {
    return VecOp(3, UVec3).neg(v); // Note: Negation for UVec might wrap around or be undefined depending on desired behavior.
}

pub export fn uv4Neg(v: UVec4) UVec4 {
    return VecOp(4, UVec4).neg(v); // Note: Negation for UVec might wrap around or be undefined depending on desired behavior.
}

// Vector operations
pub export fn v2Dot(a: Vec2, b: Vec2) f32 {
    return VecOp(2, Vec2).dot(a, b);
}

pub export fn v3Dot(a: Vec3, b: Vec3) f32 {
    return VecOp(3, Vec3).dot(a, b);
}

pub export fn v4Dot(a: Vec4, b: Vec4) f32 {
    return VecOp(4, Vec4).dot(a, b);
}

pub export fn v3Cross(a: Vec3, b: Vec3) Vec3 {
    return Vec3{
        .x = a.y * b.z - a.z * b.y,
        .y = a.z * b.x - a.x * b.z,
        .z = a.x * b.y - a.y * b.x,
    };
}

pub export fn iv2Dot(a: IVec2, b: IVec2) i32 {
    return VecOp(2, IVec2).dot(a, b);
}

pub export fn iv3Dot(a: IVec3, b: IVec3) i32 {
    return VecOp(3, IVec3).dot(a, b);
}

pub export fn iv4Dot(a: IVec4, b: IVec4) i32 {
    return VecOp(4, IVec4).dot(a, b);
}

pub export fn iv3Cross(a: IVec3, b: IVec3) IVec3 {
    return IVec3{
        .x = a.y * b.z - a.z * b.y,
        .y = a.z * b.x - a.x * b.z,
        .z = a.x * b.y - a.y * b.x,
    };
}

pub export fn uv2Dot(a: UVec2, b: UVec2) u32 {
    return VecOp(2, UVec2).dot(a, b);
}

pub export fn uv3Dot(a: UVec3, b: UVec3) u32 {
    return VecOp(3, UVec3).dot(a, b);
}

pub export fn uv4Dot(a: UVec4, b: UVec4) u32 {
    return VecOp(4, UVec4).dot(a, b);
}

pub export fn v2Len(v: Vec2) f32 {
    return VecOp(2, Vec2).len(v);
}

pub export fn v3Len(v: Vec3) f32 {
    return VecOp(3, Vec3).len(v);
}

pub export fn v4Len(v: Vec4) f32 {
    return VecOp(4, Vec4).len(v);
}

pub export fn v2Len2(v: Vec2) f32 {
    return VecOp(2, Vec2).len2(v);
}

pub export fn v3Len2(v: Vec3) f32 {
    return VecOp(3, Vec3).len2(v);
}

pub export fn v4Len2(v: Vec4) f32 {
    return VecOp(4, Vec4).len2(v);
}

pub export fn iv2Len(v: IVec2) f32 {
    return VecOp(2, IVec2).len(v);
}

pub export fn iv3Len(v: IVec3) f32 {
    return VecOp(3, IVec3).len(v);
}

pub export fn iv4Len(v: IVec4) f32 {
    return VecOp(4, IVec4).len(v);
}

pub export fn iv2Len2(v: IVec2) i32 {
    return VecOp(2, IVec2).len2(v);
}

pub export fn iv3Len2(v: IVec3) i32 {
    return VecOp(3, IVec3).len2(v);
}

pub export fn iv4Len2(v: IVec4) i32 {
    return VecOp(4, IVec4).len2(v);
}

pub export fn uv2Len(v: UVec2) f32 {
    return VecOp(2, UVec2).len(v);
}

pub export fn uv3Len(v: UVec3) f32 {
    return VecOp(3, UVec3).len(v);
}

pub export fn uv4Len(v: UVec4) f32 {
    return VecOp(4, UVec4).len(v);
}

pub export fn uv2Len2(v: UVec2) u32 {
    return VecOp(2, UVec2).len2(v);
}

pub export fn uv3Len2(v: UVec3) u32 {
    return VecOp(3, UVec3).len2(v);
}

pub export fn uv4Len2(v: UVec4) u32 {
    return VecOp(4, UVec4).len2(v);
}

pub export fn v2Dist(a: Vec2, b: Vec2) f32 {
    return VecOp(2, Vec2).dist(a, b);
}

pub export fn v3Dist(a: Vec3, b: Vec3) f32 {
    return VecOp(3, Vec3).dist(a, b);
}

pub export fn v4Dist(a: Vec4, b: Vec4) f32 {
    return VecOp(4, Vec4).dist(a, b);
}

pub export fn v2Dist2(a: Vec2, b: Vec2) f32 {
    return VecOp(2, Vec2).dist2(a, b);
}

pub export fn v3Dist2(a: Vec3, b: Vec3) f32 {
    return VecOp(3, Vec3).dist2(a, b);
}

pub export fn v4Dist2(a: Vec4, b: Vec4) f32 {
    return VecOp(4, Vec4).dist2(a, b);
}

pub export fn iv2Dist(a: IVec2, b: IVec2) f32 {
    return VecOp(2, IVec2).dist(a, b);
}

pub export fn iv3Dist(a: IVec3, b: IVec3) f32 {
    return VecOp(3, IVec3).dist(a, b);
}

pub export fn iv4Dist(a: IVec4, b: IVec4) f32 {
    return VecOp(4, IVec4).dist(a, b);
}

pub export fn iv2Dist2(a: IVec2, b: IVec2) i32 {
    return VecOp(2, IVec2).dist2(a, b);
}

pub export fn iv3Dist2(a: IVec3, b: IVec3) i32 {
    return VecOp(3, IVec3).dist2(a, b);
}

pub export fn iv4Dist2(a: IVec4, b: IVec4) i32 {
    return VecOp(4, IVec4).dist2(a, b);
}

pub export fn uv2Dist(a: UVec2, b: UVec2) f32 {
    return VecOp(2, UVec2).dist(a, b);
}

pub export fn uv3Dist(a: UVec3, b: UVec3) f32 {
    return VecOp(3, UVec3).dist(a, b);
}

pub export fn uv4Dist(a: UVec4, b: UVec4) f32 {
    return VecOp(4, UVec4).dist(a, b);
}

pub export fn uv2Dist2(a: UVec2, b: UVec2) u32 {
    return VecOp(2, UVec2).dist2(a, b);
}

pub export fn uv3Dist2(a: UVec3, b: UVec3) u32 {
    return VecOp(3, UVec3).dist2(a, b);
}

pub export fn uv4Dist2(a: UVec4, b: UVec4) u32 {
    return VecOp(4, UVec4).dist2(a, b);
}

pub export fn v2Norm(v: Vec2) Vec2 {
    return VecOp(2, Vec2).norm(v);
}

pub export fn v3Norm(v: Vec3) Vec3 {
    return VecOp(3, Vec3).norm(v);
}

pub export fn v4Norm(v: Vec4) Vec4 {
    return VecOp(4, Vec4).norm(v);
}

pub export fn iv2Norm(v: IVec2) Vec2 { // Norm returns Vec2 for IVec2
    return VecOp(2, IVec2).norm(v);
}

pub export fn iv3Norm(v: IVec3) Vec3 { // Norm returns Vec3 for IVec3
    return VecOp(3, IVec3).norm(v);
}

pub export fn iv4Norm(v: IVec4) Vec4 { // Norm returns Vec4 for IVec4
    return VecOp(4, IVec4).norm(v);
}

pub export fn uv2Norm(v: UVec2) Vec2 { // Norm returns Vec2 for UVec2
    return VecOp(2, UVec2).norm(v);
}

pub export fn uv3Norm(v: UVec3) Vec3 { // Norm returns Vec3 for UVec3
    return VecOp(3, UVec3).norm(v);
}

pub export fn uv4Norm(v: UVec4) Vec4 { // Norm returns Vec4 for UVec4
    return VecOp(4, UVec4).norm(v);
}

// Interpolation and comparison
pub export fn v2Lerp(a: Vec2, b: Vec2, t: f32) Vec2 {
    return VecOp(2, Vec2).lerp(a, b, t);
}

pub export fn v3Lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
    return VecOp(3, Vec3).lerp(a, b, t);
}

pub export fn v4Lerp(a: Vec4, b: Vec4, t: f32) Vec4 {
    return VecOp(4, Vec4).lerp(a, b, t);
}

pub export fn iv2Lerp(a: IVec2, b: IVec2, t: f32) Vec2 { // Lerp returns Vec2 for IVec2
    return VecOp(2, IVec2).lerp(a, b, t);
}

pub export fn iv3Lerp(a: IVec3, b: IVec3, t: f32) Vec3 { // Lerp returns Vec3 for IVec3
    return VecOp(3, IVec3).lerp(a, b, t);
}

pub export fn iv4Lerp(a: IVec4, b: IVec4, t: f32) Vec4 { // Lerp returns Vec4 for IVec4
    return VecOp(4, IVec4).lerp(a, b, t);
}

pub export fn uv2Lerp(a: UVec2, b: UVec2, t: f32) Vec2 { // Lerp returns Vec2 for UVec2
    return VecOp(2, UVec2).lerp(a, b, t);
}

pub export fn uv3Lerp(a: UVec3, b: UVec3, t: f32) Vec3 { // Lerp returns Vec3 for UVec3
    return VecOp(3, UVec3).lerp(a, b, t);
}

pub export fn uv4Lerp(a: UVec4, b: UVec4, t: f32) Vec4 { // Lerp returns Vec4 for UVec4
    return VecOp(4, UVec4).lerp(a, b, t);
}

pub export fn v2Eq(a: Vec2, b: Vec2, eps: f32) bool {
    return VecOp(2, Vec2).eq(a, b, eps);
}

pub export fn v3Eq(a: Vec3, b: Vec3, eps: f32) bool {
    return VecOp(3, Vec3).eq(a, b, eps);
}

pub export fn v4Eq(a: Vec4, b: Vec4, eps: f32) bool {
    return VecOp(4, Vec4).eq(a, b, eps);
}

pub export fn iv2Eq(a: IVec2, b: IVec2, eps: i32) bool {
    return VecOp(2, IVec2).eq(a, b, eps);
}

pub export fn iv3Eq(a: IVec3, b: IVec3, eps: i32) bool {
    return VecOp(3, IVec3).eq(a, b, eps);
}

pub export fn iv4Eq(a: IVec4, b: IVec4, eps: i32) bool {
    return VecOp(4, IVec4).eq(a, b, eps);
}

pub export fn uv2Eq(a: UVec2, b: UVec2, eps: u32) bool {
    return VecOp(2, UVec2).eq(a, b, eps);
}

pub export fn uv3Eq(a: UVec3, b: UVec3, eps: u32) bool {
    return VecOp(3, UVec3).eq(a, b, eps);
}

pub export fn uv4Eq(a: UVec4, b: UVec4, eps: u32) bool {
    return VecOp(4, UVec4).eq(a, b, eps);
}

// Splatting
pub export fn v2Splat(s: f32) Vec2 {
    return VecOp(2, Vec2).splat(s);
}

pub export fn v3Splat(s: f32) Vec3 {
    return VecOp(3, Vec3).splat(s);
}

pub export fn v4Splat(s: f32) Vec4 {
    return VecOp(4, Vec4).splat(s);
}

pub export fn iv2Splat(s: i32) IVec2 {
    return VecOp(2, IVec2).splat(s);
}

pub export fn iv3Splat(s: i32) IVec3 {
    return VecOp(3, IVec3).splat(s);
}

pub export fn iv4Splat(s: i32) IVec4 {
    return VecOp(4, IVec4).splat(s);
}

pub export fn uv2Splat(s: u32) UVec2 {
    return VecOp(2, UVec2).splat(s);
}

pub export fn uv3Splat(s: u32) UVec3 {
    return VecOp(3, UVec3).splat(s);
}

pub export fn uv4Splat(s: u32) UVec4 {
    return VecOp(4, UVec4).splat(s);
}

// Clamping
pub export fn v2Clamp(v: Vec2, minVal: f32, maxVal: f32) Vec2 {
    return VecOp(2, Vec2).clamp(v, minVal, maxVal);
}

pub export fn v3Clamp(v: Vec3, minVal: f32, maxVal: f32) Vec3 {
    return VecOp(3, Vec3).clamp(v, minVal, maxVal);
}

pub export fn v4Clamp(v: Vec4, minVal: f32, maxVal: f32) Vec4 {
    return VecOp(4, Vec4).clamp(v, minVal, maxVal);
}

pub export fn iv2Clamp(v: IVec2, minVal: i32, maxVal: i32) IVec2 {
    return VecOp(2, IVec2).clamp(v, minVal, maxVal);
}

pub export fn iv3Clamp(v: IVec3, minVal: i32, maxVal: i32) IVec3 {
    return VecOp(3, IVec3).clamp(v, minVal, maxVal);
}

pub export fn iv4Clamp(v: IVec4, minVal: i32, maxVal: i32) IVec4 {
    return VecOp(4, IVec4).clamp(v, minVal, maxVal);
}

pub export fn uv2Clamp(v: UVec2, minVal: u32, maxVal: u32) UVec2 {
    return VecOp(2, UVec2).clamp(v, minVal, maxVal);
}

pub export fn uv3Clamp(v: UVec3, minVal: u32, maxVal: u32) UVec3 {
    return VecOp(3, UVec3).clamp(v, minVal, maxVal);
}

pub export fn uv4Clamp(v: UVec4, minVal: u32, maxVal: u32) UVec4 {
    return VecOp(4, UVec4).clamp(v, minVal, maxVal);
}

// Absolute Value
pub export fn v2Abs(v: Vec2) Vec2 {
    return VecOp(2, Vec2).abs(v);
}

pub export fn v3Abs(v: Vec3) Vec3 {
    return VecOp(3, Vec3).abs(v);
}

pub export fn v4Abs(v: Vec4) Vec4 {
    return VecOp(4, Vec4).abs(v);
}

pub export fn iv2Abs(v: IVec2) IVec2 {
    return VecOp(2, IVec2).abs(v);
}

pub export fn iv3Abs(v: IVec3) IVec3 {
    return VecOp(3, IVec3).abs(v);
}

pub export fn iv4Abs(v: IVec4) IVec4 {
    return VecOp(4, IVec4).abs(v);
}

// Min/Max Components
pub export fn v2MinComponent(v: Vec2) f32 {
    return VecOp(2, Vec2).minComponent(v);
}

pub export fn v3MinComponent(v: Vec3) f32 {
    return VecOp(3, Vec3).minComponent(v);
}

pub export fn v4MinComponent(v: Vec4) f32 {
    return VecOp(4, Vec4).minComponent(v);
}

pub export fn iv2MinComponent(v: IVec2) i32 {
    return VecOp(2, IVec2).minComponent(v);
}

pub export fn iv3MinComponent(v: IVec3) i32 {
    return VecOp(3, IVec3).minComponent(v);
}

pub export fn iv4MinComponent(v: IVec4) i32 {
    return VecOp(4, IVec4).minComponent(v);
}

pub export fn uv2MinComponent(v: UVec2) u32 {
    return VecOp(2, UVec2).minComponent(v);
}

pub export fn uv3MinComponent(v: UVec3) u32 {
    return VecOp(3, UVec3).minComponent(v);
}

pub export fn uv4MinComponent(v: UVec4) u32 {
    return VecOp(4, UVec4).minComponent(v);
}

pub export fn v2MaxComponent(v: Vec2) f32 {
    return VecOp(2, Vec2).maxComponent(v);
}

pub export fn v3MaxComponent(v: Vec3) f32 {
    return VecOp(3, Vec3).maxComponent(v);
}

pub export fn v4MaxComponent(v: Vec4) f32 {
    return VecOp(4, Vec4).maxComponent(v);
}

pub export fn iv2MaxComponent(v: IVec2) i32 {
    return VecOp(2, IVec2).maxComponent(v);
}

pub export fn iv3MaxComponent(v: IVec3) i32 {
    return VecOp(3, IVec3).maxComponent(v);
}

pub export fn iv4MaxComponent(v: IVec4) i32 {
    return VecOp(4, IVec4).maxComponent(v);
}

pub export fn uv2MaxComponent(v: UVec2) u32 {
    return VecOp(2, UVec2).maxComponent(v);
}

pub export fn uv3MaxComponent(v: UVec3) u32 {
    return VecOp(3, UVec3).maxComponent(v);
}

pub export fn uv4MaxComponent(v: UVec4) u32 {
    return VecOp(4, UVec4).maxComponent(v);
}

// Component-wise Min/Max
pub export fn v2ComponentMin(a: Vec2, b: Vec2) Vec2 {
    return VecOp(2, Vec2).componentMin(a, b);
}

pub export fn v3ComponentMin(a: Vec3, b: Vec3) Vec3 {
    return VecOp(3, Vec3).componentMin(a, b);
}

pub export fn v4ComponentMin(a: Vec4, b: Vec4) Vec4 {
    return VecOp(4, Vec4).componentMin(a, b);
}

pub export fn iv2ComponentMin(a: IVec2, b: IVec2) IVec2 {
    return VecOp(2, IVec2).componentMin(a, b);
}

pub export fn iv3ComponentMin(a: IVec3, b: IVec3) IVec3 {
    return VecOp(3, IVec3).componentMin(a, b);
}

pub export fn iv4ComponentMin(a: IVec4, b: IVec4) IVec4 {
    return VecOp(4, IVec4).componentMin(a, b);
}

pub export fn uv2ComponentMin(a: UVec2, b: UVec2) UVec2 {
    return VecOp(2, UVec2).componentMin(a, b);
}

pub export fn uv3ComponentMin(a: UVec3, b: UVec3) UVec3 {
    return VecOp(3, UVec3).componentMin(a, b);
}

pub export fn uv4ComponentMin(a: UVec4, b: UVec4) UVec4 {
    return VecOp(4, UVec4).componentMin(a, b);
}

pub export fn v2ComponentMax(a: Vec2, b: Vec2) Vec2 {
    return VecOp(2, Vec2).componentMax(a, b);
}

pub export fn v3ComponentMax(a: Vec3, b: Vec3) Vec3 {
    return VecOp(3, Vec3).componentMax(a, b);
}

pub export fn v4ComponentMax(a: Vec4, b: Vec4) Vec4 {
    return VecOp(4, Vec4).componentMax(a, b);
}

pub export fn iv2ComponentMax(a: IVec2, b: IVec2) IVec2 {
    return VecOp(2, IVec2).componentMax(a, b);
}

pub export fn iv3ComponentMax(a: IVec3, b: IVec3) IVec3 {
    return VecOp(3, IVec3).componentMax(a, b);
}

pub export fn iv4ComponentMax(a: IVec4, b: IVec4) IVec4 {
    return VecOp(4, IVec4).componentMax(a, b);
}

pub export fn uv2ComponentMax(a: UVec2, b: UVec2) UVec2 {
    return VecOp(2, UVec2).componentMax(a, b);
}

pub export fn uv3ComponentMax(a: UVec3, b: UVec3) UVec3 {
    return VecOp(3, UVec3).componentMax(a, b);
}

pub export fn uv4ComponentMax(a: UVec4, b: UVec4) UVec4 {
    return VecOp(4, UVec4).componentMax(a, b);
}

// Floor, Ceil, Round (for Vec only)
pub export fn v2Floor(v: Vec2) Vec2 {
    return VecOp(2, Vec2).floor(v);
}

pub export fn v3Floor(v: Vec3) Vec3 {
    return VecOp(3, Vec3).floor(v);
}

pub export fn v4Floor(v: Vec4) Vec4 {
    return VecOp(4, Vec4).floor(v);
}

pub export fn v2Ceil(v: Vec2) Vec2 {
    return VecOp(2, Vec2).ceil(v);
}

pub export fn v3Ceil(v: Vec3) Vec3 {
    return VecOp(3, Vec3).ceil(v);
}

pub export fn v4Ceil(v: Vec4) Vec4 {
    return VecOp(4, Vec4).ceil(v);
}

pub export fn v2Round(v: Vec2) Vec2 {
    return VecOp(2, Vec2).round(v);
}

pub export fn v3Round(v: Vec3) Vec3 {
    return VecOp(3, Vec3).round(v);
}

pub export fn v4Round(v: Vec4) Vec4 {
    return VecOp(4, Vec4).round(v);
}

// Step and Smoothstep (for Vec only)
pub export fn v2Step(edge: Vec2, v: Vec2) Vec2 {
    return VecOp(2, Vec2).step(edge, v);
}

pub export fn v3Step(edge: Vec3, v: Vec3) Vec3 {
    return VecOp(3, Vec3).step(edge, v);
}

pub export fn v4Step(edge: Vec4, v: Vec4) Vec4 {
    return VecOp(4, Vec4).step(edge, v);
}

pub export fn v2Smoothstep(edge0: Vec2, edge1: Vec2, v: Vec2) Vec2 {
    return VecOp(2, Vec2).smoothstep(edge0, edge1, v);
}

pub export fn v3Smoothstep(edge0: Vec3, edge1: Vec3, v: Vec3) Vec3 {
    return VecOp(3, Vec3).smoothstep(edge0, edge1, v);
}

pub export fn v4Smoothstep(edge0: Vec4, edge1: Vec4, v: Vec4) Vec4 {
    return VecOp(4, Vec4).smoothstep(edge0, edge1, v);
}

// Is Zero, Is One, Is Unit (for Vec only)
pub export fn v2IsZero(v: Vec2, eps: f32) bool {
    return VecOp(2, Vec2).isZero(v, eps);
}

pub export fn v3IsZero(v: Vec3, eps: f32) bool {
    return VecOp(3, Vec3).isZero(v, eps);
}

pub export fn v4IsZero(v: Vec4, eps: f32) bool {
    return VecOp(4, Vec4).isZero(v, eps);
}

pub export fn v2IsOne(v: Vec2, eps: f32) bool {
    return VecOp(2, Vec2).isOne(v, eps);
}

pub export fn v3IsOne(v: Vec3, eps: f32) bool {
    return VecOp(3, Vec3).isOne(v, eps);
}

pub export fn v4IsOne(v: Vec4, eps: f32) bool {
    return VecOp(4, Vec4).isOne(v, eps);
}

pub export fn v2IsUnit(v: Vec2, eps: f32) bool {
    return VecOp(2, Vec2).isUnit(v, eps);
}

pub export fn v3IsUnit(v: Vec3, eps: f32) bool {
    return VecOp(3, Vec3).isUnit(v, eps);
}

pub export fn v4IsUnit(v: Vec4, eps: f32) bool {
    return VecOp(4, Vec4).isUnit(v, eps);
}

// Reflection and refraction (Note: Reflection/Refraction typically use floats, integer versions might not be directly applicable or physically meaningful in the same way)
pub export fn v2Reflect(v: Vec2, n: Vec2) Vec2 {
    const dot2 = v2Dot(v, n) * 2.0;
    return v2Sub(v, v2Scale(n, dot2));
}

pub export fn v3Reflect(v: Vec3, n: Vec3) Vec3 {
    const dot2 = v3Dot(v, n) * 2.0;
    return v3Sub(v, v3Scale(n, dot2));
}

pub export fn v3Refract(v: Vec3, n: Vec3, eta: f32) Vec3 {
    const dot = v3Dot(v, n);
    const k = 1.0 - eta * eta * (1.0 - dot * dot);

    if (k < 0.0) {
        return v3Zero(); // Total internal reflection
    } else {
        return v3Sub(v3Scale(v, eta), v3Scale(n, eta * dot + scalar.sqrt(k)));
    }
}

// Type conversions
pub export fn v3FromV2(v: Vec2, z: f32) Vec3 {
    return Vec3{ .x = v.x, .y = v.y, .z = z };
}

pub export fn v4FromV3(v: Vec3, w: f32) Vec4 {
    return Vec4{ .x = v.x, .y = v.y, .z = v.z, .w = w };
}

pub export fn v2FromV3(v: Vec3) Vec2 {
    return Vec2{ .x = v.x, .y = v.y };
}

pub export fn v3FromV4(v: Vec4) Vec3 {
    return Vec3{ .x = v.x, .y = v.y, .z = v.z };
}

pub export fn iv3FromIVec2(v: IVec2, z: i32) IVec3 {
    return IVec3{ .x = v.x, .y = v.y, .z = z };
}

pub export fn iv4FromIVec3(v: IVec3, w: i32) IVec4 {
    return IVec4{ .x = v.x, .y = v.y, .z = v.z, .w = w };
}

pub export fn iv2FromIVec3(v: IVec3) IVec2 {
    return IVec2{ .x = v.x, .y = v.y };
}

pub export fn iv3FromIVec4(v: IVec4) IVec3 {
    return IVec3{ .x = v.x, .y = v.y, .z = v.z };
}

pub export fn uv3FromUVec2(v: UVec2, z: u32) UVec3 {
    return UVec3{ .x = v.x, .y = v.y, .z = z };
}

pub export fn uv4FromUVec3(v: UVec3, w: u32) UVec4 {
    return UVec4{ .x = v.x, .y = v.y, .z = v.z, .w = w };
}

pub export fn uv2FromUVec3(v: UVec3) UVec2 {
    return UVec2{ .x = v.x, .y = v.y };
}

pub export fn uv3FromUVec4(v: UVec4) UVec3 {
    return UVec3{ .x = v.x, .y = v.y, .z = v.z };
}

pub export fn v2FromIVec2(v: IVec2) Vec2 {
    return Vec2{ .x = @floatFromInt(v.x), .y = @floatFromInt(v.y) };
}

pub export fn v3FromIVec3(v: IVec3) Vec3 {
    return Vec3{ .x = @floatFromInt(v.x), .y = @floatFromInt(v.y), .z = @floatFromInt(v.z) };
}

pub export fn v4FromIVec4(v: IVec4) Vec4 {
    return Vec4{ .x = @floatFromInt(v.x), .y = @floatFromInt(v.y), .z = @floatFromInt(v.z), .w = @floatFromInt(v.w) };
}

pub export fn v2FromUVec2(v: UVec2) Vec2 {
    return Vec2{ .x = @floatFromInt(v.x), .y = @floatFromInt(v.y) };
}

pub export fn v3FromUVec3(v: UVec3) Vec3 {
    return Vec3{ .x = @floatFromInt(v.x), .y = @floatFromInt(v.y), .z = @floatFromInt(v.z) }; // Assuming w=0 for v3->v4 conversion
}

pub export fn v4FromUVec4(v: UVec4) Vec4 {
    return Vec4{ .x = @floatFromInt(v.x), .y = @floatFromInt(v.y), .z = @floatFromInt(v.z), .w = @floatFromInt(v.w) };
}
// Conversions from float (Vec*) to integer (IVec*/UVec*)
pub export fn iVec2FromV2(v: Vec2) IVec2 {
    return IVec2{
        .x = @as(i32, @intFromFloat(v.x)),
        .y = @as(i32, @intFromFloat(v.y)),
    };
}

pub export fn iVec3FromV3(v: Vec3) IVec3 {
    return IVec3{
        .x = @as(i32, @intFromFloat(v.x)),
        .y = @as(i32, @intFromFloat(v.y)),
        .z = @as(i32, @intFromFloat(v.z)),
    };
}

pub export fn iVec4FromV4(v: Vec4) IVec4 {
    return IVec4{
        .x = @as(i32, @intFromFloat(v.x)),
        .y = @as(i32, @intFromFloat(v.y)),
        .z = @as(i32, @intFromFloat(v.z)),
        .w = @as(i32, @intFromFloat(v.w)),
    };
}

pub export fn uVec2FromV2(v: Vec2) UVec2 {
    return UVec2{
        .x = @as(u32, @intFromFloat(v.x)),
        .y = @as(u32, @intFromFloat(v.y)),
    };
}

pub export fn uVec3FromV3(v: Vec3) UVec3 {
    return UVec3{
        .x = @as(u32, @intFromFloat(v.x)),
        .y = @as(u32, @intFromFloat(v.y)),
        .z = @as(u32, @intFromFloat(v.z)),
    };
}

pub export fn uVec4FromV4(v: Vec4) UVec4 {
    return UVec4{
        .x = @as(u32, @intFromFloat(v.x)),
        .y = @as(u32, @intFromFloat(v.y)),
        .z = @as(u32, @intFromFloat(v.z)),
        .w = @as(u32, @intFromFloat(v.w)),
    };
}

// Conversions between integer types (IVec* <-> UVec*)
pub export fn iVec2FromUVec2(v: UVec2) IVec2 {
    return IVec2{
        .x = @as(i32, @intCast(v.x)),
        .y = @as(i32, @intCast(v.y)),
    };
}

pub export fn iVec3FromUVec3(v: UVec3) IVec3 {
    return IVec3{
        .x = @as(i32, @intCast(v.x)),
        .y = @as(i32, @intCast(v.y)),
        .z = @as(i32, @intCast(v.z)),
    };
}

pub export fn iVec4FromUVec4(v: UVec4) IVec4 {
    return IVec4{
        .x = @as(i32, @intCast(v.x)),
        .y = @as(i32, @intCast(v.y)),
        .z = @as(i32, @intCast(v.z)),
        .w = @as(i32, @intCast(v.w)),
    };
}

pub export fn uVec2FromIVec2(v: IVec2) UVec2 {
    return UVec2{
        .x = @as(u32, @intCast(v.x)),
        .y = @as(u32, @intCast(v.y)),
    };
}

pub export fn uVec3FromIVec3(v: IVec3) UVec3 {
    return UVec3{
        .x = @as(u32, @intCast(v.x)),
        .y = @as(u32, @intCast(v.y)),
        .z = @as(u32, @intCast(v.z)),
    };
}

pub export fn uVec4FromIVec4(v: IVec4) UVec4 {
    return UVec4{
        .x = @as(u32, @intCast(v.x)),
        .y = @as(u32, @intCast(v.y)),
        .z = @as(u32, @intCast(v.z)),
        .w = @as(u32, @intCast(v.w)),
    };
}
