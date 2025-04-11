// Quaternion math library implementation based on scalar, vector, and matrix functions
// No std dependency, using hardware acceleration where possible

const scalar = @import("scalar.zig");
const vec = @import("vec.zig");
const mat = @import("mat.zig");
const quaternion = @import("include").quat;

pub const Quat = quaternion.Quat;

// Constructor functions
pub export fn q(x: f32, y: f32, z: f32, w: f32) Quat {
    return Quat{ .v = vec.v3(x, y, z), .w = w };
}

pub export fn qFromVec(v: vec.Vec3, w: f32) Quat {
    return Quat{ .v = v, .w = w };
}

pub export fn qId() Quat {
    return Quat{ .v = vec.v3Zero(), .w = 1.0 };
}

pub export fn qZero() Quat {
    return Quat{ .v = vec.v3Zero(), .w = 0.0 };
}

// Create quaternion from axis-angle representation
pub export fn qAxis(axis: vec.Vec3, angle: f32) Quat {
    const halfAngle = angle * 0.5;
    const sinHalf = scalar.sin(halfAngle);
    const cosHalf = scalar.cos(halfAngle);

    const normalized = vec.v3Norm(axis);
    return Quat{ .v = vec.v3Scale(normalized, sinHalf), .w = cosHalf };
}

// Create quaternion from Euler angles (in radians)
pub export fn qEuler(x: f32, y: f32, z: f32) Quat {
    // Convert Euler angles to quaternion using the ZYX convention
    const halfX = x * 0.5;
    const halfY = y * 0.5;
    const halfZ = z * 0.5;

    const cx = scalar.cos(halfX);
    const sx = scalar.sin(halfX);
    const cy = scalar.cos(halfY);
    const sy = scalar.sin(halfY);
    const cz = scalar.cos(halfZ);
    const sz = scalar.sin(halfZ);

    // ZYX rotation order (common in computer graphics)
    return Quat{ .v = vec.v3(sx * cy * cz + cx * sy * sz, cx * sy * cz - sx * cy * sz, cx * cy * sz + sx * sy * cz), .w = cx * cy * cz - sx * sy * sz };
}

// Create quaternion from rotation matrix
pub export fn qFromM3(m: mat.Mat3) Quat {
    const m00 = mat.m3Get(m, 0, 0);
    const m01 = mat.m3Get(m, 0, 1);
    const m02 = mat.m3Get(m, 0, 2);
    const m10 = mat.m3Get(m, 1, 0);
    const m11 = mat.m3Get(m, 1, 1);
    const m12 = mat.m3Get(m, 1, 2);
    const m20 = mat.m3Get(m, 2, 0);
    const m21 = mat.m3Get(m, 2, 1);
    const m22 = mat.m3Get(m, 2, 2);

    const trace = m00 + m11 + m22;
    var result: Quat = undefined;

    if (trace > 0.0) {
        const s = 0.5 / scalar.sqrt(trace + 1.0);
        result.w = 0.25 / s;
        result.v.x = (m21 - m12) * s;
        result.v.y = (m02 - m20) * s;
        result.v.z = (m10 - m01) * s;
    } else if (m00 > m11 and m00 > m22) {
        const s = 2.0 * scalar.sqrt(1.0 + m00 - m11 - m22);
        result.w = (m21 - m12) / s;
        result.v.x = 0.25 * s;
        result.v.y = (m01 + m10) / s;
        result.v.z = (m02 + m20) / s;
    } else if (m11 > m22) {
        const s = 2.0 * scalar.sqrt(1.0 + m11 - m00 - m22);
        result.w = (m02 - m20) / s;
        result.v.x = (m01 + m10) / s;
        result.v.y = 0.25 * s;
        result.v.z = (m12 + m21) / s;
    } else {
        const s = 2.0 * scalar.sqrt(1.0 + m22 - m00 - m11);
        result.w = (m10 - m01) / s;
        result.v.x = (m02 + m20) / s;
        result.v.y = (m12 + m21) / s;
        result.v.z = 0.25 * s;
    }

    return qNorm(result);
}

pub export fn qFromM4(m: mat.Mat4) Quat {
    // Extract the 3x3 rotation part and convert it
    const m3 = mat.m3FromM4(m);
    return qFromM3(m3);
}

// Convert quaternion to matrices
pub export fn qToM3(quat: Quat) mat.Mat3 {
    const normalized = qNorm(quat);
    const x = normalized.v.x;
    const y = normalized.v.y;
    const z = normalized.v.z;
    const w = normalized.w;

    const xx = x * x;
    const xy = x * y;
    const xz = x * z;
    const xw = x * w;
    const yy = y * y;
    const yz = y * z;
    const yw = y * w;
    const zz = z * z;
    const zw = z * w;

    var result = mat.m3Zero();

    // First row
    mat.m3Set(&result, 0, 0, 1.0 - 2.0 * (yy + zz));
    mat.m3Set(&result, 0, 1, 2.0 * (xy - zw));
    mat.m3Set(&result, 0, 2, 2.0 * (xz + yw));

    // Second row
    mat.m3Set(&result, 1, 0, 2.0 * (xy + zw));
    mat.m3Set(&result, 1, 1, 1.0 - 2.0 * (xx + zz));
    mat.m3Set(&result, 1, 2, 2.0 * (yz - xw));

    // Third row
    mat.m3Set(&result, 2, 0, 2.0 * (xz - yw));
    mat.m3Set(&result, 2, 1, 2.0 * (yz + xw));
    mat.m3Set(&result, 2, 2, 1.0 - 2.0 * (xx + yy));

    return result;
}

pub export fn qToM4(quat: Quat) mat.Mat4 {
    const m3 = qToM3(quat);
    return mat.m4FromM3(m3);
}

// Basic quaternion operations
pub export fn qAdd(a: Quat, b: Quat) Quat {
    return Quat{ .v = vec.v3Add(a.v, b.v), .w = a.w + b.w };
}

pub export fn qSub(a: Quat, b: Quat) Quat {
    return Quat{ .v = vec.v3Sub(a.v, b.v), .w = a.w - b.w };
}

pub export fn qMul(a: Quat, b: Quat) Quat {
    // Quaternion multiplication: a * b
    const vCross = vec.v3Cross(a.v, b.v);

    // Calculate vector component
    const v1 = vec.v3Scale(b.v, a.w); // a.w * b.v
    const v2 = vec.v3Scale(a.v, b.w); // b.w * a.v
    const vSum = vec.v3Add(vec.v3Add(v1, v2), vCross);

    // Calculate scalar component
    const w = a.w * b.w - vec.v3Dot(a.v, b.v);

    return Quat{ .v = vSum, .w = w };
}

// For the qScale function
pub export fn qScale(quat: Quat, s: f32) Quat {
    // Change q.w to quat.w
    return Quat{ .v = vec.v3Scale(quat.v, s), .w = quat.w * s };
}

// For the qNeg function
pub export fn qNeg(quat: Quat) Quat {
    // Change q.w to quat.w
    return Quat{ .v = vec.v3Neg(quat.v), .w = -quat.w };
}

// For the qLen2 function
pub export fn qLen2(quat: Quat) f32 {
    // Change q.w to quat.w
    return vec.v3Len2(quat.v) + quat.w * quat.w;
}

// For the qNorm function
pub export fn qNorm(quat: Quat) Quat {
    const len = scalar.sqrt(qLen2(quat));
    if (len < 0.000001) {
        return qId(); // Return identity quaternion if length too small
    }
    // Change q to quat
    return qScale(quat, 1.0 / len);
}

// For the qConj function
pub export fn qConj(quat: Quat) Quat {
    // Change q.w to quat.w
    return Quat{ .v = vec.v3Neg(quat.v), .w = quat.w };
}

pub export fn qInv(quat: Quat) Quat {
    const len2 = qLen2(quat);
    if (len2 < 0.000001) {
        return qId(); // Return identity quaternion if length too small
    }

    const conj = qConj(quat);
    return qScale(conj, 1.0 / len2);
}

// Dot product and equality check
pub export fn qDot(a: Quat, b: Quat) f32 {
    return vec.v3Dot(a.v, b.v) + a.w * b.w;
}

pub export fn qEq(a: Quat, b: Quat, eps: f32) bool {
    return vec.v3Eq(a.v, b.v, eps) and scalar.eq(a.w, b.w, eps);
}

// Rotation operations
pub export fn qRotV3(quat: Quat, v: vec.Vec3) vec.Vec3 {
    // v' = q * v * q^-1 (optimized implementation)
    const normalized = qNorm(quat);

    // Calculate using the formula:
    // v' = v + 2 * cross(quat.v, cross(q.v, v) + q.w * v)

    const qv = normalized.v;
    const qw = normalized.w;

    const temp1 = vec.v3Scale(v, qw);
    const temp2 = vec.v3Cross(qv, v);
    const temp3 = vec.v3Add(temp1, temp2);
    const temp4 = vec.v3Cross(qv, temp3);
    const temp5 = vec.v3Scale(temp4, 2.0);

    return vec.v3Add(v, temp5);
}

// Interpolation
pub export fn qLerp(a: Quat, b: Quat, t: f32) Quat {
    // Adjust b if dot product is negative (take shortest path)
    var bAdjusted = b;
    const dot = qDot(a, b);
    if (dot < 0.0) {
        bAdjusted = qNeg(b);
    }

    return Quat{ .v = vec.v3Lerp(a.v, bAdjusted.v, t), .w = scalar.lerp(a.w, bAdjusted.w, t) };
}

pub export fn qSlerp(a: Quat, b: Quat, t: f32) Quat {
    // Spherical linear interpolation
    const normalized_a = qNorm(a);
    var normalized_b = qNorm(b);

    var dot = qDot(normalized_a, normalized_b);

    // If dot < 0, take shorter path
    if (dot < 0.0) {
        normalized_b = qNeg(normalized_b);
        dot = -dot;
    }

    // Set threshold for linear interpolation (when quaternions are very close)
    const DOT_THRESHOLD = 0.9995;

    if (dot > DOT_THRESHOLD) {
        // Quaternions are very close - linear interpolation is fine
        return qNorm(qLerp(normalized_a, normalized_b, t));
    }

    // Clamp dot to valid range
    const clampedDot = scalar.clamp(dot, -1.0, 1.0);

    // Calculate angle and sin values
    const theta_0 = scalar.acos(clampedDot);
    const theta = theta_0 * t;

    const sin_theta = scalar.sin(theta);
    const sin_theta_0 = scalar.sin(theta_0);

    // Calculate coefficients
    const s0 = scalar.cos(theta) - clampedDot * sin_theta / sin_theta_0;
    const s1 = sin_theta / sin_theta_0;

    // Perform the actual interpolation
    return Quat{ .v = vec.v3Add(vec.v3Scale(normalized_a.v, s0), vec.v3Scale(normalized_b.v, s1)), .w = normalized_a.w * s0 + normalized_b.w * s1 };
}

pub export fn qNlerp(a: Quat, b: Quat, t: f32) Quat {
    // Normalized linear interpolation
    return qNorm(qLerp(a, b, t));
}

// Extract information
pub export fn qGetAxis(quat: Quat, axis: *vec.Vec3, angle: *f32) void {
    const normalized = qNorm(quat);

    const w = normalized.w;
    const len = vec.v3Len(normalized.v);

    if (len < 0.000001) {
        // No rotation - use arbitrary axis
        axis.* = vec.v3X();
        angle.* = 0.0;
        return;
    }

    // Calculate axis and angle
    axis.* = vec.v3Scale(normalized.v, 1.0 / len);
    angle.* = 2.0 * scalar.acos(scalar.clamp(w, -1.0, 1.0));
}

pub export fn qToEuler(quat: Quat) vec.Vec3 {
    const normalized = qNorm(quat);
    const x = normalized.v.x;
    const y = normalized.v.y;
    const z = normalized.v.z;
    const w = normalized.w;

    // Calculate roll (x-axis rotation)
    const sinr_cosp = 2.0 * (w * x + y * z);
    const cosr_cosp = 1.0 - 2.0 * (x * x + y * y);
    const roll = scalar.atan2(sinr_cosp, cosr_cosp);

    // Calculate pitch (y-axis rotation)
    const sinp = 2.0 * (w * y - z * x);
    var pitch: f32 = 0.0;

    if (scalar.abs(sinp) >= 1.0) {
        // Use 90 degrees if out of range
        pitch = scalar.PI / 2.0 * scalar.step(0.0, sinp);
    } else {
        pitch = scalar.asin(sinp);
    }

    // Calculate yaw (z-axis rotation)
    const siny_cosp = 2.0 * (w * z + x * y);
    const cosy_cosp = 1.0 - 2.0 * (y * y + z * z);
    const yaw = scalar.atan2(siny_cosp, cosy_cosp);

    return vec.v3(roll, pitch, yaw);
}

// Basic rotation quaternions
pub export fn qRotX(angle: f32) Quat {
    const halfAngle = angle * 0.5;
    return Quat{ .v = vec.v3(scalar.sin(halfAngle), 0.0, 0.0), .w = scalar.cos(halfAngle) };
}

pub export fn qRotY(angle: f32) Quat {
    const halfAngle = angle * 0.5;
    return Quat{ .v = vec.v3(0.0, scalar.sin(halfAngle), 0.0), .w = scalar.cos(halfAngle) };
}

pub export fn qRotZ(angle: f32) Quat {
    const halfAngle = angle * 0.5;
    return Quat{ .v = vec.v3(0.0, 0.0, scalar.sin(halfAngle)), .w = scalar.cos(halfAngle) };
}

pub export fn qRoll(quat: Quat) f32 {
    const sinr_cosp = 2.0 * (quat.w * quat.v.x + quat.v.y * quat.v.z);
    const cosr_cosp = 1.0 - 2.0 * (quat.v.x * quat.v.x + quat.v.y * quat.v.y);
    return scalar.atan2(sinr_cosp, cosr_cosp);
}

pub export fn qPitch(quat: Quat) f32 {
    const sinp = 2.0 * (quat.w * quat.v.y - quat.v.z * quat.v.x);
    if (@abs(sinp) >= 1.0) {
        return if (sinp > 0) @as(f32, @import("math.zig").HALF_PI) else -@as(f32, @import("math.zig").HALF_PI);
    } else {
        return scalar.asin(sinp);
    }
}

pub export fn qYaw(quat: Quat) f32 {
    const siny_cosp = 2.0 * (quat.w * quat.v.z + quat.v.x * quat.v.y);
    const cosy_cosp = 1.0 - 2.0 * (quat.v.y * quat.v.y + quat.v.z * quat.v.z);
    return scalar.atan2(siny_cosp, cosy_cosp);
}

// Additional utility functions
pub export fn qLookAt(dir: vec.Vec3, up: vec.Vec3) Quat {
    const normalized_dir = vec.v3Norm(dir);
    const normalized_up = vec.v3Norm(up);

    // Calculate the right vector
    const right = vec.v3Cross(normalized_up, normalized_dir);

    // Ensure orthogonality
    const adjusted_up = vec.v3Cross(normalized_dir, right);

    // Create a rotation matrix
    var rotation_matrix = mat.m3Zero();

    // Set columns of the matrix
    for (0..3) |i| {
        mat.m3Set(&rotation_matrix, @as(i32, @intCast(i)), 0, right.asArray()[i]);
        mat.m3Set(&rotation_matrix, @as(i32, @intCast(i)), 1, adjusted_up.asArray()[i]);
        mat.m3Set(&rotation_matrix, @as(i32, @intCast(i)), 2, normalized_dir.asArray()[i]);
    }

    // Convert to quaternion
    return qFromM3(rotation_matrix);
}

pub export fn qFromTo(from: vec.Vec3, to: vec.Vec3) Quat {
    const normalized_from = vec.v3Norm(from);
    const normalized_to = vec.v3Norm(to);

    const dot = vec.v3Dot(normalized_from, normalized_to);

    // If vectors are parallel (same direction)
    if (dot > 0.999999) {
        return qId();
    }

    // If vectors are parallel (opposite direction)
    if (dot < -0.999999) {
        // Find an orthogonal vector to 'from'
        var axis = vec.v3Cross(vec.v3X(), normalized_from);

        // If axis length is too small, try another direction
        if (vec.v3Len2(axis) < 0.000001) {
            axis = vec.v3Cross(vec.v3Y(), normalized_from);
        }

        // Create quaternion for 180-degree rotation
        return qAxis(vec.v3Norm(axis), scalar.PI);
    }

    // General case
    const axis = vec.v3Cross(normalized_from, normalized_to);
    const s = scalar.sqrt((1.0 + dot) * 2.0);
    const invs = 1.0 / s;

    return Quat{ .v = vec.v3Scale(axis, invs), .w = s * 0.5 };
}

// Vector and scalar extraction
pub export fn qGetVec(quat: Quat) vec.Vec3 {
    return quat.v;
}

pub export fn qGetW(quat: Quat) f32 {
    return quat.w;
}
