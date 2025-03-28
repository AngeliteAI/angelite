const vec = @import("vec.zig");
const mat = @import("mat.zig");

// Quaternion type using Vec3 for vector component and scalar for w
pub const Quat = extern struct {
    v: vec.Vec3, // Vector part (x, y, z)
    w: f32, // Scalar part

    pub inline fn asArray(self: *const Quat) *const [4]f32 {
        return @ptrCast(&self.v.x);
    }

    pub inline fn fromArray(arr: *const [4]f32) Quat {
        return Quat{ .v = vec.Vec3{ .x = arr[0], .y = arr[1], .z = arr[2] }, .w = arr[3] };
    }
};

// Constructor functions
pub extern fn q(x: f32, y: f32, z: f32, w: f32) Quat;
pub extern fn qFromVec(v: vec.Vec3, w: f32) Quat;
pub extern fn qId() Quat;
pub extern fn qZero() Quat;

// Create quaternion from axis-angle representation
pub extern fn qAxis(axis: vec.Vec3, angle: f32) Quat;

// Create quaternion from Euler angles (in radians)
pub extern fn qEuler(x: f32, y: f32, z: f32) Quat;

// Create quaternion from rotation matrix
pub extern fn qFromM3(m: mat.Mat3) Quat;
pub extern fn qFromM4(m: mat.Mat4) Quat;

// Convert quaternion to matrices
pub extern fn qToM3(q: Quat) mat.Mat3;
pub extern fn qToM4(q: Quat) mat.Mat4;

// Basic quaternion operations
pub extern fn qAdd(a: Quat, b: Quat) Quat;
pub extern fn qSub(a: Quat, b: Quat) Quat;
pub extern fn qMul(a: Quat, b: Quat) Quat; // Quaternion multiplication
pub extern fn qScale(q: Quat, s: f32) Quat;
pub extern fn qNeg(q: Quat) Quat;

// Quaternion properties
pub extern fn qLen(q: Quat) f32;
pub extern fn qLen2(q: Quat) f32;
pub extern fn qNorm(q: Quat) Quat; // Normalize quaternion
pub extern fn qConj(q: Quat) Quat; // Conjugate
pub extern fn qInv(q: Quat) Quat; // Inverse quaternion

// Dot product and equality check
pub extern fn qDot(a: Quat, b: Quat) f32;
pub extern fn qEq(a: Quat, b: Quat, eps: f32) bool;

// Rotation operations
pub extern fn qRotV3(q: Quat, v: vec.Vec3) vec.Vec3; // Rotate a vector by quaternion

// Interpolation
pub extern fn qLerp(a: Quat, b: Quat, t: f32) Quat; // Linear interpolation
pub extern fn qSlerp(a: Quat, b: Quat, t: f32) Quat; // Spherical linear interpolation
pub extern fn qNlerp(a: Quat, b: Quat, t: f32) Quat; // Normalized linear interpolation

// Extract information
pub extern fn qGetAxis(q: Quat, axis: *vec.Vec3, angle: *f32) void;
pub extern fn qToEuler(q: Quat) vec.Vec3; // Returns Euler angles as Vec3

// Basic rotation quaternions
pub extern fn qRotX(angle: f32) Quat;
pub extern fn qRotY(angle: f32) Quat;
pub extern fn qRotZ(angle: f32) Quat;

pub extern fn qRoll(quat: Quat) f32;
pub extern fn qPitch(quat: Quat) f32;
pub extern fn qYaw(quat: Quat) f32;

// Additional utility functions
pub extern fn qLookAt(dir: vec.Vec3, up: vec.Vec3) Quat; // Quaternion that rotates towards a direction
pub extern fn qFromTo(from: vec.Vec3, to: vec.Vec3) Quat; // Quaternion to rotate from one vector to another

// Vector and scalar extraction
pub extern fn qGetVec(q: Quat) vec.Vec3; // Get vector part
pub extern fn qGetW(q: Quat) f32; // Get scalar part
