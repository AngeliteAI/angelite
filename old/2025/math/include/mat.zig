const vec = @import("vec.zig");
pub const Mat2 = extern struct {
    data: [4]f32,

    pub inline fn asArray(self: *const Mat2) *const [4]f32 {
        return &self.data;
    }

    pub inline fn fromArray(arr: *const [4]f32) Mat2 {
        return Mat2{ .data = arr.* };
    }
};

pub const Mat3 = extern struct {
    data: [9]f32,

    pub inline fn asArray(self: *const Mat3) *const [9]f32 {
        return &self.data;
    }

    pub inline fn fromArray(arr: *const [9]f32) Mat3 {
        return Mat3{ .data = arr.* };
    }
};

pub const Mat4 = extern struct {
    data: [16]f32,

    pub inline fn asArray(self: *const Mat4) *const [16]f32 {
        return &self.data;
    }

    pub inline fn fromArray(arr: *const [16]f32) Mat4 {
        return Mat4{ .data = arr.* };
    }
};

// Creation functions
pub extern fn m2Id() Mat2;
pub extern fn m3Id() Mat3;
pub extern fn m4Id() Mat4;
pub extern fn m2Zero() Mat2;
pub extern fn m3Zero() Mat3;
pub extern fn m4Zero() Mat4;
// Basic matrix operations
pub extern fn m2Add(a: Mat2, b: Mat2) Mat2;
pub extern fn m3Add(a: Mat3, b: Mat3) Mat3;
pub extern fn m4Add(a: Mat4, b: Mat4) Mat4;
pub extern fn m2Sub(a: Mat2, b: Mat2) Mat2;
pub extern fn m3Sub(a: Mat3, b: Mat3) Mat3;
pub extern fn m4Sub(a: Mat4, b: Mat4) Mat4;
pub extern fn m2Mul(a: Mat2, b: Mat2) Mat2;
pub extern fn m3Mul(a: Mat3, b: Mat3) Mat3;
pub extern fn m4Mul(a: Mat4, b: Mat4) Mat4;
pub extern fn m2Scale(m: Mat2, s: f32) Mat2;
pub extern fn m3Scale(m: Mat3, s: f32) Mat3;
pub extern fn m4Scale(m: Mat4, s: f32) Mat4;
// Matrix-vector operations
pub extern fn m2V2(m: Mat2, v: vec.Vec2) vec.Vec2;
pub extern fn m3V3(m: Mat3, v: vec.Vec3) vec.Vec3;
pub extern fn m4V4(m: Mat4, v: vec.Vec4) vec.Vec4;
pub extern fn m4Point(m: Mat4, v: vec.Vec3) vec.Vec3;
pub extern fn m4Dir(m: Mat4, v: vec.Vec3) vec.Vec3;
// Matrix properties
pub extern fn m2Tr(m: Mat2) Mat2;
pub extern fn m3Tr(m: Mat3) Mat3;
pub extern fn m4Tr(m: Mat4) Mat4;
pub extern fn m2Det(m: Mat2) f32;
pub extern fn m3Det(m: Mat3) f32;
pub extern fn m4Det(m: Mat4) f32;
pub extern fn m2Inv(m: Mat2) Mat2;
pub extern fn m3Inv(m: Mat3) Mat3;
pub extern fn m4Inv(m: Mat4) Mat4;
// Matrix access
pub extern fn m2Get(m: Mat2, row: i32, col: i32) f32;
pub extern fn m3Get(m: Mat3, row: i32, col: i32) f32;
pub extern fn m4Get(m: Mat4, row: i32, col: i32) f32;
pub extern fn m2Set(m: *Mat2, row: i32, col: i32, val: f32) void;
pub extern fn m3Set(m: *Mat3, row: i32, col: i32, val: f32) void;
pub extern fn m4Set(m: *Mat4, row: i32, col: i32, val: f32) void;
// Rotation matrices
pub extern fn m2Rot(angle: f32) Mat2;
pub extern fn m3RotX(angle: f32) Mat3;
pub extern fn m3RotY(angle: f32) Mat3;
pub extern fn m3RotZ(angle: f32) Mat3;
pub extern fn m3RotAxis(axis: vec.Vec3, angle: f32) Mat3;
pub extern fn m4RotX(angle: f32) Mat4;
pub extern fn m4RotY(angle: f32) Mat4;
pub extern fn m4RotZ(angle: f32) Mat4;
pub extern fn m4RotAxis(axis: vec.Vec3, angle: f32) Mat4;
pub extern fn m4RotEuler(x: f32, y: f32, z: f32) Mat4;
// Scaling matrices
pub extern fn m2Scaling(x: f32, y: f32) Mat2;
pub extern fn m3Scaling(x: f32, y: f32, z: f32) Mat3;
pub extern fn m4Scaling(x: f32, y: f32, z: f32) Mat4;
pub extern fn m4ScalingV3(scale: vec.Vec3) Mat4;
// Translation matrix (Mat4 only)
pub extern fn m4Trans(x: f32, y: f32, z: f32) Mat4;
pub extern fn m4TransV3(v: vec.Vec3) Mat4;
// View and projection matrices
pub extern fn m4LookAt(eye: vec.Vec3, target: vec.Vec3, up: vec.Vec3) Mat4;
pub extern fn m4Persp(fovy: f32, aspect: f32, near: f32, far: f32) Mat4;
pub extern fn m4Ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4;
// Matrix conversion
pub extern fn m3FromM4(m: Mat4) Mat3;
pub extern fn m4FromM3(m: Mat3) Mat4;
// Special matrices
pub extern fn m3Normal(model: Mat4) Mat3;
