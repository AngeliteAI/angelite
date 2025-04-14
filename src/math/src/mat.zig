// Matrix math library implementation based on scalar and vector functions
// No std dependency, using hardware acceleration where possible

const std = @import("std");
const scalar = @import("scalar.zig");
const vec = @import("vec.zig");
const mat = @import("include").mat;

pub const Mat2 = mat.Mat2;
pub const Mat3 = mat.Mat3;
pub const Mat4 = mat.Mat4;

// Generic matrix operations for any dimension
fn MatOp(comptime dim: usize) type {
    return struct {
        const Matrix = switch (dim) {
            2 => Mat2,
            3 => Mat3,
            4 => Mat4,
            else => @compileError("Unsupported matrix dimension"),
        };

        const Vector = switch (dim) {
            2 => vec.Vec2,
            3 => vec.Vec3,
            4 => vec.Vec4,
            else => @compileError("Unsupported vector dimension"),
        };

        const VecAdd = switch (dim) {
            2 => vec.v2Add,
            3 => vec.v3Add,
            4 => vec.v4Add,
            else => @compileError("Unsupported vector dimension"),
        };

        const VecScale = switch (dim) {
            2 => vec.v2Scale,
            3 => vec.v3Scale,
            4 => vec.v4Scale,
            else => @compileError("Unsupported vector dimension"),
        };

        const VecDot = switch (dim) {
            2 => vec.v2Dot,
            3 => vec.v3Dot,
            4 => vec.v4Dot,
            else => @compileError("Unsupported vector dimension"),
        };

        pub inline fn id() Matrix {
            var result: [dim * dim]f32 = [_]f32{0} ** (dim * dim);

            for (0..dim) |i| {
                result[i * dim + i] = 1.0;
            }

            return Matrix.fromArray(&result);
        }

        pub inline fn zero() Matrix {
            var result: [dim * dim]f32 = [_]f32{0} ** (dim * dim);
            return Matrix.fromArray(&result);
        }

        pub inline fn add(a: Matrix, b: Matrix) Matrix {
            const aArr = a.asArray();
            const bArr = b.asArray();
            var result: [dim * dim]f32 = undefined;

            for (0..(dim * dim)) |i| {
                result[i] = aArr[i] + bArr[i];
            }

            return Matrix.fromArray(&result);
        }

        pub inline fn sub(a: Matrix, b: Matrix) Matrix {
            const aArr = a.asArray();
            const bArr = b.asArray();
            var result: [dim * dim]f32 = undefined;

            for (0..(dim * dim)) |i| {
                result[i] = aArr[i] - bArr[i];
            }

            return Matrix.fromArray(&result);
        }

        pub inline fn mul(a: Matrix, b: Matrix) Matrix {
            const aArr = a.asArray();
            const bArr = b.asArray();
            var result: [dim * dim]f32 = undefined;

            for (0..dim) |col| {
                for (0..dim) |row| {
                    var sum: f32 = 0.0;
                    for (0..dim) |i| {
                        sum += aArr[i * dim + row] * bArr[col * dim + i];
                    }
                    result[col * dim + row] = sum;
                }
            }

            return Matrix.fromArray(&result);
        }

        pub inline fn scale(m: Matrix, s: f32) Matrix {
            const mArr = m.asArray();
            var result: [dim * dim]f32 = undefined;

            for (0..(dim * dim)) |i| {
                result[i] = mArr[i] * s;
            }

            return Matrix.fromArray(&result);
        }

        pub inline fn mulVec(m: Matrix, v: Vector) Vector {
            const mArr = m.asArray();
            const rows = [_]f32{0} ** dim;
            var result: [dim]f32 = rows;

            switch (dim) {
                2 => {
                    result[0] = mArr[0] * v.x + mArr[2] * v.y;
                    result[1] = mArr[1] * v.x + mArr[3] * v.y;
                },
                3 => {
                    result[0] = mArr[0] * v.x + mArr[3] * v.y + mArr[6] * v.z;
                    result[1] = mArr[1] * v.x + mArr[4] * v.y + mArr[7] * v.z;
                    result[2] = mArr[2] * v.x + mArr[5] * v.y + mArr[8] * v.z;
                },
                4 => {
                    result[0] = mArr[0] * v.x + mArr[4] * v.y + mArr[8] * v.z + mArr[12] * v.w;
                    result[1] = mArr[1] * v.x + mArr[5] * v.y + mArr[9] * v.z + mArr[13] * v.w;
                    result[2] = mArr[2] * v.x + mArr[6] * v.y + mArr[10] * v.z + mArr[14] * v.w;
                    result[3] = mArr[3] * v.x + mArr[7] * v.y + mArr[11] * v.z + mArr[15] * v.w;
                },
                else => unreachable,
            }

            return @bitCast(result);
        }

        pub inline fn tr(m: Matrix) Matrix {
            const mArr = m.asArray();
            var result: [dim * dim]f32 = undefined;

            for (0..dim) |row| {
                for (0..dim) |col| {
                    result[row * dim + col] = mArr[col * dim + row];
                }
            }

            return Matrix.fromArray(&result);
        }

        pub inline fn det(m: Matrix) f32 {
            const mArr = m.asArray();

            switch (dim) {
                2 => {
                    return mArr[0] * mArr[3] - mArr[1] * mArr[2];
                },
                3 => {
                    const a00 = mArr[0];
                    const a01 = mArr[3];
                    const a02 = mArr[6];
                    const a10 = mArr[1];
                    const a11 = mArr[4];
                    const a12 = mArr[7];
                    const a20 = mArr[2];
                    const a21 = mArr[5];
                    const a22 = mArr[8];

                    return a00 * (a11 * a22 - a12 * a21) -
                        a01 * (a10 * a22 - a12 * a20) +
                        a02 * (a10 * a21 - a11 * a20);
                },
                4 => {
                    const a00 = mArr[0];
                    const a01 = mArr[4];
                    const a02 = mArr[8];
                    const a03 = mArr[12];
                    const a10 = mArr[1];
                    const a11 = mArr[5];
                    const a12 = mArr[9];
                    const a13 = mArr[13];
                    const a20 = mArr[2];
                    const a21 = mArr[6];
                    const a22 = mArr[10];
                    const a23 = mArr[14];
                    const a30 = mArr[3];
                    const a31 = mArr[7];
                    const a32 = mArr[11];
                    const a33 = mArr[15];

                    const b00 = a00 * a11 - a01 * a10;
                    const b01 = a00 * a12 - a02 * a10;
                    const b02 = a00 * a13 - a03 * a10;
                    const b03 = a01 * a12 - a02 * a11;
                    const b04 = a01 * a13 - a03 * a11;
                    const b05 = a02 * a13 - a03 * a12;
                    const b06 = a20 * a31 - a21 * a30;
                    const b07 = a20 * a32 - a22 * a30;
                    const b08 = a20 * a33 - a23 * a30;
                    const b09 = a21 * a32 - a22 * a31;
                    const b10 = a21 * a33 - a23 * a31;
                    const b11 = a22 * a33 - a23 * a32;

                    return b00 * b11 - b01 * b10 + b02 * b09 + b03 * b08 - b04 * b07 + b05 * b06;
                },
                else => unreachable,
            }
        }

        pub inline fn inv(m: Matrix) Matrix {
            const mArr = m.asArray();
            var result: [dim * dim]f32 = undefined;

            const d = det(m);
            if (scalar.abs(d) < 1e-6) {
                return id(); // Return identity if not invertible
            }

            const invDet = 1.0 / d;

            switch (dim) {
                2 => {
                    result[0] = mArr[3] * invDet;
                    result[1] = -mArr[1] * invDet;
                    result[2] = -mArr[2] * invDet;
                    result[3] = mArr[0] * invDet;
                },
                3 => {
                    const a00 = mArr[0];
                    const a01 = mArr[3];
                    const a02 = mArr[6];
                    const a10 = mArr[1];
                    const a11 = mArr[4];
                    const a12 = mArr[7];
                    const a20 = mArr[2];
                    const a21 = mArr[5];
                    const a22 = mArr[8];

                    // Calculate cofactors
                    result[0] = (a11 * a22 - a12 * a21) * invDet;
                    result[1] = (a20 * a12 - a10 * a22) * invDet;
                    result[2] = (a10 * a21 - a20 * a11) * invDet;
                    result[3] = (a21 * a02 - a01 * a22) * invDet;
                    result[4] = (a00 * a22 - a20 * a02) * invDet;
                    result[5] = (a20 * a01 - a00 * a21) * invDet;
                    result[6] = (a01 * a12 - a11 * a02) * invDet;
                    result[7] = (a10 * a02 - a00 * a12) * invDet;
                    result[8] = (a00 * a11 - a10 * a01) * invDet;
                },
                4 => {
                    const a00 = mArr[0];
                    const a01 = mArr[4];
                    const a02 = mArr[8];
                    const a03 = mArr[12];
                    const a10 = mArr[1];
                    const a11 = mArr[5];
                    const a12 = mArr[9];
                    const a13 = mArr[13];
                    const a20 = mArr[2];
                    const a21 = mArr[6];
                    const a22 = mArr[10];
                    const a23 = mArr[14];
                    const a30 = mArr[3];
                    const a31 = mArr[7];
                    const a32 = mArr[11];
                    const a33 = mArr[15];

                    const b00 = a00 * a11 - a01 * a10;
                    const b01 = a00 * a12 - a02 * a10;
                    const b02 = a00 * a13 - a03 * a10;
                    const b03 = a01 * a12 - a02 * a11;
                    const b04 = a01 * a13 - a03 * a11;
                    const b05 = a02 * a13 - a03 * a12;
                    const b06 = a20 * a31 - a21 * a30;
                    const b07 = a20 * a32 - a22 * a30;
                    const b08 = a20 * a33 - a23 * a30;
                    const b09 = a21 * a32 - a22 * a31;
                    const b10 = a21 * a33 - a23 * a31;
                    const b11 = a22 * a33 - a23 * a32;

                    result[0] = (a11 * b11 - a12 * b10 + a13 * b09) * invDet;
                    result[1] = (a10 * b11 - a12 * b08 + a13 * b07) * -invDet;
                    result[2] = (a10 * b10 - a11 * b08 + a13 * b06) * invDet;
                    result[3] = (a10 * b09 - a11 * b07 + a12 * b06) * -invDet;
                    result[4] = (a01 * b11 - a02 * b10 + a03 * b09) * -invDet;
                    result[5] = (a00 * b11 - a02 * b08 + a03 * b07) * invDet;
                    result[6] = (a00 * b10 - a01 * b08 + a03 * b06) * -invDet;
                    result[7] = (a00 * b09 - a01 * b07 + a02 * b06) * invDet;
                    result[8] = (a31 * b05 - a32 * b04 + a33 * b03) * invDet;
                    result[9] = (a30 * b05 - a32 * b02 + a33 * b01) * -invDet;
                    result[10] = (a30 * b04 - a31 * b02 + a33 * b00) * invDet;
                    result[11] = (a30 * b03 - a31 * b01 + a32 * b00) * -invDet;
                    result[12] = (a21 * b05 - a22 * b04 + a23 * b03) * -invDet;
                    result[13] = (a20 * b05 - a22 * b02 + a23 * b01) * invDet;
                    result[14] = (a20 * b04 - a21 * b02 + a23 * b00) * -invDet;
                    result[15] = (a20 * b03 - a21 * b01 + a22 * b00) * invDet;
                },
                else => unreachable,
            }

            return Matrix.fromArray(&result);
        }

        pub inline fn get(m: Matrix, row: i32, col: i32) f32 {
            const mArr = m.asArray();
            const r = @as(usize, @intCast(row));
            const c = @as(usize, @intCast(col));
            return mArr[c * dim + r];
        }

        pub inline fn set(m: *Matrix, row: i32, col: i32, val: f32) void {
            const r = @as(usize, @intCast(row));
            const c = @as(usize, @intCast(col));
            m.data[c * dim + r] = val;
        }
    };
}

// Create identity matrices
pub export fn m2Id() Mat2 {
    return MatOp(2).id();
}

pub export fn m3Id() Mat3 {
    return MatOp(3).id();
}

pub export fn m4Id() Mat4 {
    return MatOp(4).id();
}

// Create zero matrices
pub export fn m2Zero() Mat2 {
    return MatOp(2).zero();
}

pub export fn m3Zero() Mat3 {
    return MatOp(3).zero();
}

pub export fn m4Zero() Mat4 {
    return MatOp(4).zero();
}

// Basic matrix operations
pub export fn m2Add(a: Mat2, b: Mat2) Mat2 {
    return MatOp(2).add(a, b);
}

pub export fn m3Add(a: Mat3, b: Mat3) Mat3 {
    return MatOp(3).add(a, b);
}

pub export fn m4Add(a: Mat4, b: Mat4) Mat4 {
    return MatOp(4).add(a, b);
}

pub export fn m2Sub(a: Mat2, b: Mat2) Mat2 {
    return MatOp(2).sub(a, b);
}

pub export fn m3Sub(a: Mat3, b: Mat3) Mat3 {
    return MatOp(3).sub(a, b);
}

pub export fn m4Sub(a: Mat4, b: Mat4) Mat4 {
    return MatOp(4).sub(a, b);
}

pub export fn m2Mul(a: Mat2, b: Mat2) Mat2 {
    return MatOp(2).mul(a, b);
}

pub export fn m3Mul(a: Mat3, b: Mat3) Mat3 {
    return MatOp(3).mul(a, b);
}

pub export fn m4Mul(a: Mat4, b: Mat4) Mat4 {
    return MatOp(4).mul(a, b);
}

pub export fn m2Scale(m: Mat2, s: f32) Mat2 {
    return MatOp(2).scale(m, s);
}

pub export fn m3Scale(m: Mat3, s: f32) Mat3 {
    return MatOp(3).scale(m, s);
}

pub export fn m4Scale(m: Mat4, s: f32) Mat4 {
    return MatOp(4).scale(m, s);
}

// Matrix-vector operations
pub export fn m2V2(m: Mat2, v: vec.Vec2) vec.Vec2 {
    return MatOp(2).mulVec(m, v);
}

pub export fn m3V3(m: Mat3, v: vec.Vec3) vec.Vec3 {
    return MatOp(3).mulVec(m, v);
}

pub export fn m4V4(m: Mat4, v: vec.Vec4) vec.Vec4 {
    return MatOp(4).mulVec(m, v);
}

pub export fn m4Point(m: Mat4, v: vec.Vec3) vec.Vec3 {
    // Transform as a homogeneous coordinate with w=1
    const v4 = vec.v4FromV3(v, 1.0);
    const transformed = MatOp(4).mulVec(m, v4);

    // Perspective divide if w is not 0
    if (transformed.w != 0.0) {
        const invW = 1.0 / transformed.w;
        return vec.v3(transformed.x * invW, transformed.y * invW, transformed.z * invW);
    }

    return vec.v3FromV4(transformed);
}

pub export fn m4Dir(m: Mat4, v: vec.Vec3) vec.Vec3 {
    // Transform as a direction vector with w=0
    const v4 = vec.v4FromV3(v, 0.0);
    const transformed = MatOp(4).mulVec(m, v4);
    return vec.v3FromV4(transformed);
}

// Matrix properties
pub export fn m2Tr(m: Mat2) Mat2 {
    return MatOp(2).tr(m);
}

pub export fn m3Tr(m: Mat3) Mat3 {
    return MatOp(3).tr(m);
}

pub export fn m4Tr(m: Mat4) Mat4 {
    return MatOp(4).tr(m);
}

pub export fn m2Det(m: Mat2) f32 {
    return MatOp(2).det(m);
}

pub export fn m3Det(m: Mat3) f32 {
    return MatOp(3).det(m);
}

pub export fn m4Det(m: Mat4) f32 {
    return MatOp(4).det(m);
}

pub export fn m2Inv(m: Mat2) Mat2 {
    return MatOp(2).inv(m);
}

pub export fn m3Inv(m: Mat3) Mat3 {
    return MatOp(3).inv(m);
}

pub export fn m4Inv(m: Mat4) Mat4 {
    return MatOp(4).inv(m);
}

// Matrix access
pub export fn m2Get(m: Mat2, row: i32, col: i32) f32 {
    return MatOp(2).get(m, row, col);
}

pub export fn m3Get(m: Mat3, row: i32, col: i32) f32 {
    return MatOp(3).get(m, row, col);
}

pub export fn m4Get(m: Mat4, row: i32, col: i32) f32 {
    return MatOp(4).get(m, row, col);
}

pub export fn m2Set(m: *Mat2, row: i32, col: i32, val: f32) void {
    MatOp(2).set(m, row, col, val);
}

pub export fn m3Set(m: *Mat3, row: i32, col: i32, val: f32) void {
    MatOp(3).set(m, row, col, val);
}

pub export fn m4Set(m: *Mat4, row: i32, col: i32, val: f32) void {
    MatOp(4).set(m, row, col, val);
}

// Rotation matrices
pub export fn m2Rot(angle: f32) Mat2 {
    const c = scalar.cos(angle);
    const s = scalar.sin(angle);

    return Mat2{ .data = .{ c, s, -s, c } };
}

pub export fn m3RotX(angle: f32) Mat3 {
    const c = scalar.cos(angle);
    const s = scalar.sin(angle);

    var result = m3Id();
    result.data[4] = c;
    result.data[5] = s;
    result.data[7] = -s;
    result.data[8] = c;

    return result;
}

pub export fn m3RotY(angle: f32) Mat3 {
    const c = scalar.cos(angle);
    const s = scalar.sin(angle);

    var result = m3Id();
    result.data[0] = c;
    result.data[2] = -s;
    result.data[6] = s;
    result.data[8] = c;

    return result;
}

pub export fn m3RotZ(angle: f32) Mat3 {
    const c = scalar.cos(angle);
    const s = scalar.sin(angle);

    var result = m3Id();
    result.data[0] = c;
    result.data[1] = s;
    result.data[3] = -s;
    result.data[4] = c;

    return result;
}

pub export fn m3RotAxis(axis: vec.Vec3, angle: f32) Mat3 {
    const normalized = vec.v3Norm(axis);
    const x = normalized.x;
    const y = normalized.y;
    const z = normalized.z;

    const c = scalar.cos(angle);
    const s = scalar.sin(angle);
    const t = 1.0 - c;

    const tx = t * x;
    const ty = t * y;
    const tz = t * z;

    const sx = s * x;
    const sy = s * y;
    const sz = s * z;

    return Mat3{ .data = .{ tx * x + c, tx * y + sz, tx * z - sy, tx * y - sz, ty * y + c, ty * z + sx, tx * z + sy, ty * z - sx, tz * z + c } };
}

pub export fn m4RotX(angle: f32) Mat4 {
    const c = scalar.cos(angle);
    const s = scalar.sin(angle);

    var result = m4Id();
    result.data[5] = c;
    result.data[6] = s;
    result.data[9] = -s;
    result.data[10] = c;

    return result;
}

pub export fn m4RotY(angle: f32) Mat4 {
    const c = scalar.cos(angle);
    const s = scalar.sin(angle);

    var result = m4Id();
    result.data[0] = c;
    result.data[2] = -s;
    result.data[8] = s;
    result.data[10] = c;

    return result;
}

pub export fn m4RotZ(angle: f32) Mat4 {
    const c = scalar.cos(angle);
    const s = scalar.sin(angle);

    var result = m4Id();
    result.data[0] = c;
    result.data[1] = s;
    result.data[4] = -s;
    result.data[5] = c;

    return result;
}

pub export fn m4RotAxis(axis: vec.Vec3, angle: f32) Mat4 {
    const normalized = vec.v3Norm(axis);
    const x = normalized.x;
    const y = normalized.y;
    const z = normalized.z;

    const c = scalar.cos(angle);
    const s = scalar.sin(angle);
    const t = 1.0 - c;

    const tx = t * x;
    const ty = t * y;
    const tz = t * z;

    const sx = s * x;
    const sy = s * y;
    const sz = s * z;

    var result = m4Id();
    result.data[0] = tx * x + c;
    result.data[1] = tx * y + sz;
    result.data[2] = tx * z - sy;

    result.data[4] = tx * y - sz;
    result.data[5] = ty * y + c;
    result.data[6] = ty * z + sx;

    result.data[8] = tx * z + sy;
    result.data[9] = ty * z - sx;
    result.data[10] = tz * z + c;

    return result;
}

pub export fn m4RotEuler(x: f32, y: f32, z: f32) Mat4 {
    const rx = m4RotX(x);
    const ry = m4RotY(y);
    const rz = m4RotZ(z);

    // Apply in Z, Y, X order (most common convention)
    return m4Mul(m4Mul(rx, ry), rz);
}

// Scaling matrices
pub export fn m2Scaling(x: f32, y: f32) Mat2 {
    return Mat2{ .data = .{ x, 0.0, 0.0, y } };
}

pub export fn m3Scaling(x: f32, y: f32, z: f32) Mat3 {
    var result = m3Zero();
    result.data[0] = x;
    result.data[4] = y;
    result.data[8] = z;
    return result;
}

pub export fn m4Scaling(x: f32, y: f32, z: f32) Mat4 {
    var result = m4Zero();
    result.data[0] = x;
    result.data[5] = y;
    result.data[10] = z;
    result.data[15] = 1.0;
    return result;
}

pub export fn m4ScalingV3(scale: vec.Vec3) Mat4 {
    return m4Scaling(scale.x, scale.y, scale.z);
}

// Translation matrix (4x4 only)
pub export fn m4Trans(x: f32, y: f32, z: f32) Mat4 {
    var result = m4Id();
    result.data[12] = x;
    result.data[13] = y;
    result.data[14] = z;
    return result;
}

pub export fn m4TransV3(v: vec.Vec3) Mat4 {
    return m4Trans(v.x, v.y, v.z);
}

// View and projection matrices
pub export fn m4LookAt(eye: vec.Vec3, target: vec.Vec3, up: vec.Vec3) Mat4 {
    std.debug.print("m4LookAt: eye=({d},{d},{d}) target=({d},{d},{d}) up=({d},{d},{d})\n", 
                  .{eye.x, eye.y, eye.z, target.x, target.y, target.z, up.x, up.y, up.z});
    
    // Calculate direction vector from eye to target
    const dir = vec.v3Sub(target, eye);
    const dir_len = vec.v3Len(dir);
    
    // Check if direction vector is zero (eye == target)
    if (dir_len < 0.0001) {
        std.debug.print("WARNING: Eye and target positions are too close - using default view\n", .{});
        return m4Id(); // Return identity if eye and target are effectively the same point
    }
    
    // Normalize direction for forward vector
    const f = vec.Vec3{
        .x = dir.x / dir_len,
        .y = dir.y / dir_len,
        .z = dir.z / dir_len,
    };
    
    // Special handling for Z-up when looking along Z axis
    // Calculate whether the up vector is parallel to the view direction
    const upDotF = vec.v3Dot(up, f);
    const parallel = scalar.abs(upDotF) > 0.9999;
    
    // Choose appropriate right and up vectors based on the situation
    var r: vec.Vec3 = undefined;
    var u: vec.Vec3 = undefined;
    
    if (parallel) {
        // For Z-up when looking along Z: use X as right and derive up from that
        if (scalar.abs(f.x) < 0.9) {
            // If not looking along X, use X axis for right
            r = vec.v3Norm(vec.v3Cross(vec.v3(1, 0, 0), f));
        } else {
            // If looking along X, use Y axis for right
            r = vec.v3Norm(vec.v3Cross(vec.v3(0, 1, 0), f));
        }
        
        // Recalculate up from right and forward for proper orthogonality
        u = vec.v3Cross(r, f);
        std.debug.print("Using alternate basis for Z-up\n", .{});
    } else {
        // Normal case - calculate right from forward and up
        r = vec.v3Norm(vec.v3Cross(f, up));
        // Calculate orthogonal up
        u = vec.v3Cross(r, f);
    }
    
    // Construct the view matrix
    var result = m4Id();
    
    // Row 0 - right vector
    result.data[0] = r.x;
    result.data[1] = u.x;
    result.data[2] = f.x;  // Removed negative sign
    
    // Row 1 - up vector
    result.data[4] = r.y;
    result.data[5] = u.y;
    result.data[6] = f.y;  // Removed negative sign
    
    // Row 2 - forward vector (removed negation)
    result.data[8] = r.z;
    result.data[9] = u.z;
    result.data[10] = f.z;  // Removed negative sign
    
    // Row 3 - translation
    result.data[12] = -vec.v3Dot(r, eye);
    result.data[13] = -vec.v3Dot(u, eye);
    result.data[14] = -vec.v3Dot(f, eye);  // Added negative sign to match forward vector change
    
    std.debug.print("View matrix with Z-up:\n", .{});
    std.debug.print("[{d:6.3} {d:6.3} {d:6.3} {d:6.3}]\n", 
                   .{result.data[0], result.data[1], result.data[2], result.data[3]});
    std.debug.print("[{d:6.3} {d:6.3} {d:6.3} {d:6.3}]\n", 
                   .{result.data[4], result.data[5], result.data[6], result.data[7]});
    std.debug.print("[{d:6.3} {d:6.3} {d:6.3} {d:6.3}]\n", 
                   .{result.data[8], result.data[9], result.data[10], result.data[11]});
    std.debug.print("[{d:6.3} {d:6.3} {d:6.3} {d:6.3}]\n", 
                   .{result.data[12], result.data[13], result.data[14], result.data[15]});

    return result;
}

pub export fn m4Persp(fovy: f32, aspect: f32, near: f32, far: f32) Mat4 {
    const tanHalfFovy = scalar.tan(fovy / 2.0);
    const oneOverTanHalfFovy = 1.0 / tanHalfFovy;
    const math_constants = @import("math.zig");

    var result = m4Zero();
    result.data[0] = oneOverTanHalfFovy / aspect;
    result.data[5] = oneOverTanHalfFovy;
    
    if (math_constants.CURRENT_RENDER_API == math_constants.RENDER_API_VULKAN) {
        // Vulkan/DirectX style with [0,1] Z-range
        result.data[10] = far / (far - near);
        result.data[11] = 1.0;
        result.data[14] = -(far * near) / (far - near);
        std.debug.print("Created Vulkan-style projection matrix ([0,1] Z-range)\n", .{});
    } else {
        // Metal/OpenGL style with [-1,1] Z-range
        result.data[10] = (far + near) / (far - near);
        result.data[11] = 1.0;
        result.data[14] = -(2.0 * far * near) / (far - near);
        std.debug.print("Created Metal/OpenGL-style projection matrix ([-1,1] Z-range)\n", .{});
    }
    //result[15] is 0.0, which is what m4Zero initialized it to

    return result;
}
pub export fn m4Ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4 {
    var result = m4Id();
    result.data[0] = 2.0 / (right - left);
    result.data[5] = 2.0 / (top - bottom);
    result.data[10] = -2.0 / (far - near);
    result.data[12] = -(right + left) / (right - left);
    result.data[13] = -(top + bottom) / (top - bottom);
    result.data[14] = -(far + near) / (far - near);

    return result;
}

// Matrix conversion
pub export fn m3FromM4(m: Mat4) Mat3 {
    return Mat3{ .data = .{ m.data[0], m.data[1], m.data[2], m.data[4], m.data[5], m.data[6], m.data[8], m.data[9], m.data[10] } };
}

pub export fn m4FromM3(m: Mat3) Mat4 {
    return Mat4{ .data = .{ m.data[0], m.data[1], m.data[2], 0.0, m.data[3], m.data[4], m.data[5], 0.0, m.data[6], m.data[7], m.data[8], 0.0, 0.0, 0.0, 0.0, 1.0 } };
}

// Special matrices
pub export fn m3Normal(model: Mat4) Mat3 {
    // Normal matrix is the transpose of the inverse of the upper-left 3x3 part
    // of the model matrix (removes translation and ensures correct normals when scaling)
    const m3 = m3FromM4(model);
    return m3Tr(m3Inv(m3));
}
