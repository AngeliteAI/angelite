const vec = @import("vec");

pub const Mat2 = extern struct {
    data: [4]f32,
};

pub const Mat3 = extern struct {
    data: [9]f32,
};

pub const Mat4 = extern struct {
    data: [16]f32,
};

// Creation functions
pub extern fn m2_id() Mat2;
pub extern fn m3_id() Mat3;
pub extern fn m4_id() Mat4;

pub extern fn m2_zero() Mat2;
pub extern fn m3_zero() Mat3;
pub extern fn m4_zero() Mat4;

// Basic matrix operations
pub extern fn m2_add(a: Mat2, b: Mat2) Mat2;
pub extern fn m3_add(a: Mat3, b: Mat3) Mat3;
pub extern fn m4_add(a: Mat4, b: Mat4) Mat4;

pub extern fn m2_sub(a: Mat2, b: Mat2) Mat2;
pub extern fn m3_sub(a: Mat3, b: Mat3) Mat3;
pub extern fn m4_sub(a: Mat4, b: Mat4) Mat4;

pub extern fn m2_mul(a: Mat2, b: Mat2) Mat2;
pub extern fn m3_mul(a: Mat3, b: Mat3) Mat3;
pub extern fn m4_mul(a: Mat4, b: Mat4) Mat4;

pub extern fn m2_scale(m: Mat2, s: f32) Mat2;
pub extern fn m3_scale(m: Mat3, s: f32) Mat3;
pub extern fn m4_scale(m: Mat4, s: f32) Mat4;

// Matrix-vector operations
pub extern fn m2_v2(m: Mat2, v: vec.Vec2) vec.Vec2;
pub extern fn m3_v3(m: Mat3, v: vec.Vec3) vec.Vec3;
pub extern fn m4_v4(m: Mat4, v: vec.Vec4) vec.Vec4;

pub extern fn m4_point(m: Mat4, v: vec.Vec3) vec.Vec3;
pub extern fn m4_dir(m: Mat4, v: vec.Vec3) vec.Vec3;

// Matrix properties
pub extern fn m2_tr(m: Mat2) Mat2;
pub extern fn m3_tr(m: Mat3) Mat3;
pub extern fn m4_tr(m: Mat4) Mat4;

pub extern fn m2_det(m: Mat2) f32;
pub extern fn m3_det(m: Mat3) f32;
pub extern fn m4_det(m: Mat4) f32;

pub extern fn m2_inv(m: Mat2) Mat2;
pub extern fn m3_inv(m: Mat3) Mat3;
pub extern fn m4_inv(m: Mat4) Mat4;

// Matrix access
pub extern fn m2_get(m: Mat2, row: i32, col: i32) f32;
pub extern fn m3_get(m: Mat3, row: i32, col: i32) f32;
pub extern fn m4_get(m: Mat4, row: i32, col: i32) f32;

pub extern fn m2_set(m: *Mat2, row: i32, col: i32, val: f32) void;
pub extern fn m3_set(m: *Mat3, row: i32, col: i32, val: f32) void;
pub extern fn m4_set(m: *Mat4, row: i32, col: i32, val: f32) void;

// Rotation matrices
pub extern fn m2_rot(angle: f32) Mat2;

pub extern fn m3_rot_x(angle: f32) Mat3;
pub extern fn m3_rot_y(angle: f32) Mat3;
pub extern fn m3_rot_z(angle: f32) Mat3;
pub extern fn m3_rot_axis(axis: vec.Vec3, angle: f32) Mat3;

pub extern fn m4_rot_x(angle: f32) Mat4;
pub extern fn m4_rot_y(angle: f32) Mat4;
pub extern fn m4_rot_z(angle: f32) Mat4;
pub extern fn m4_rot_axis(axis: vec.Vec3, angle: f32) Mat4;
pub extern fn m4_rot_euler(x: f32, y: f32, z: f32) Mat4;

// Scaling matrices
pub extern fn m2_scaling(x: f32, y: f32) Mat2;
pub extern fn m3_scaling(x: f32, y: f32, z: f32) Mat3;
pub extern fn m4_scaling(x: f32, y: f32, z: f32) Mat4;
pub extern fn m4_scaling_v3(scale: vec.Vec3) Mat4;

// Translation matrix (Mat4 only)
pub extern fn m4_trans(x: f32, y: f32, z: f32) Mat4;
pub extern fn m4_trans_v3(v: vec.Vec3) Mat4;

// View and projection matrices
pub extern fn m4_look_at(eye: vec.Vec3, target: vec.Vec3, up: vec.Vec3) Mat4;
pub extern fn m4_persp(fovy: f32, aspect: f32, near: f32, far: f32) Mat4;
pub extern fn m4_ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) Mat4;

// Matrix conversion
pub extern fn m3_from_m4(m: Mat4) Mat3;
pub extern fn m4_from_m3(m: Mat3) Mat4;

// Special matrices
pub extern fn m3_normal(model: Mat4) Mat3;
