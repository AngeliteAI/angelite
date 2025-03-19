// /Users/solmidnight/work/angelite/src/swift/gfx/Mat.swift
// Generated binding for mat.zig

import Foundation

public struct Mat2 {
    public var data: (Float, Float, Float, Float)

    public init(d0: Float, d1: Float, d2: Float, d3: Float) {
        self.data = (d0, d1, d2, d3)
    }
}

public struct Mat3 {
    public var data: (Float, Float, Float, Float, Float, Float, Float, Float, Float)

    public init(d0: Float, d1: Float, d2: Float, d3: Float, d4: Float, d5: Float, d6: Float, d7: Float, d8: Float) {
        self.data = (d0, d1, d2, d3, d4, d5, d6, d7, d8)
    }
}

public struct Mat4 {
    public var data: (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float)

    public init(d0: Float, d1: Float, d2: Float, d3: Float, d4: Float, d5: Float, d6: Float, d7: Float, d8: Float, d9: Float, d10: Float, d11: Float, d12: Float, d13: Float, d14: Float, d15: Float) {
        self.data = (d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15)
    }
}

@_silgen_name("m2_id")
public func m2Id() -> Mat2

@_silgen_name("m3_id")
public func m3Id() -> Mat3

@_silgen_name("m4_id")
public func m4Id() -> Mat4

@_silgen_name("m2_zero")
public func m2Zero() -> Mat2

@_silgen_name("m3_zero")
public func m3Zero() -> Mat3

@_silgen_name("m4_zero")
public func m4Zero() -> Mat4

@_silgen_name("m2_add")
public func m2Add(a: Mat2, b: Mat2) -> Mat2

@_silgen_name("m3_add")
public func m3Add(a: Mat3, b: Mat3) -> Mat3

@_silgen_name("m4_add")
public func m4Add(a: Mat4, b: Mat4) -> Mat4

@_silgen_name("m2_sub")
public func m2Sub(a: Mat2, b: Mat2) -> Mat2

@_silgen_name("m3_sub")
public func m3Sub(a: Mat3, b: Mat3) -> Mat3

@_silgen_name("m4_sub")
public func m4Sub(a: Mat4, b: Mat4) -> Mat4

@_silgen_name("m2_mul")
public func m2Mul(a: Mat2, b: Mat2) -> Mat2

@_silgen_name("m3_mul")
public func m3Mul(a: Mat3, b: Mat3) -> Mat3

@_silgen_name("m4_mul")
public func m4Mul(a: Mat4, b: Mat4) -> Mat4

@_silgen_name("m2_scale")
public func m2Scale(m: Mat2, s: Float) -> Mat2

@_silgen_name("m3_scale")
public func m3Scale(m: Mat3, s: Float) -> Mat3

@_silgen_name("m4_scale")
public func m4Scale(m: Mat4, s: Float) -> Mat4

@_silgen_name("m2_v2")
public func m2V2(m: Mat2, v: Vec2) -> Vec2

@_silgen_name("m3_v3")
public func m3V3(m: Mat3, v: Vec3) -> Vec3

@_silgen_name("m4_v4")
public func m4V4(m: Mat4, v: Vec4) -> Vec4

@_silgen_name("m4_point")
public func m4Point(m: Mat4, v: Vec3) -> Vec3

@_silgen_name("m4_dir")
public func m4Dir(m: Mat4, v: Vec3) -> Vec3

@_silgen_name("m2_tr")
public func m2Tr(m: Mat2) -> Mat2

@_silgen_name("m3_tr")
public func m3Tr(m: Mat3) -> Mat3

@_silgen_name("m4_tr")
public func m4Tr(m: Mat4) -> Mat4

@_silgen_name("m2_det")
public func m2Det(m: Mat2) -> Float

@_silgen_name("m3_det")
public func m3Det(m: Mat3) -> Float

@_silgen_name("m4_det")
public func m4Det(m: Mat4) -> Float

@_silgen_name("m2_inv")
public func m2Inv(m: Mat2) -> Mat2

@_silgen_name("m3_inv")
public func m3Inv(m: Mat3) -> Mat3

@_silgen_name("m4_inv")
public func m4Inv(m: Mat4) -> Mat4

@_silgen_name("m2_get")
public func m2Get(m: Mat2, row: Int32, col: Int32) -> Float

@_silgen_name("m3_get")
public func m3Get(m: Mat3, row: Int32, col: Int32) -> Float

@_silgen_name("m4_get")
public func m4Get(m: Mat4, row: Int32, col: Int32) -> Float

@_silgen_name("m2_set")
public func m2Set(m: UnsafeMutablePointer<Mat2>?, row: Int32, col: Int32, val: Float) -> Void

@_silgen_name("m3_set")
public func m3Set(m: UnsafeMutablePointer<Mat3>?, row: Int32, col: Int32, val: Float) -> Void

@_silgen_name("m4_set")
public func m4Set(m: UnsafeMutablePointer<Mat4>?, row: Int32, col: Int32, val: Float) -> Void

@_silgen_name("m2_rot")
public func m2Rot(angle: Float) -> Mat2

@_silgen_name("m3_rot_x")
public func m3RotX(angle: Float) -> Mat3

@_silgen_name("m3_rot_y")
public func m3RotY(angle: Float) -> Mat3

@_silgen_name("m3_rot_z")
public func m3RotZ(angle: Float) -> Mat3

@_silgen_name("m3_rot_axis")
public func m3RotAxis(axis: Vec3, angle: Float) -> Mat3

@_silgen_name("m4_rot_x")
public func m4RotX(angle: Float) -> Mat4

@_silgen_name("m4_rot_y")
public func m4RotY(angle: Float) -> Mat4

@_silgen_name("m4_rot_z")
public func m4RotZ(angle: Float) -> Mat4

@_silgen_name("m4_rot_axis")
public func m4RotAxis(axis: Vec3, angle: Float) -> Mat4

@_silgen_name("m4_rot_euler")
public func m4RotEuler(x: Float, y: Float, z: Float) -> Mat4

@_silgen_name("m2_scaling")
public func m2Scaling(x: Float, y: Float) -> Mat2

@_silgen_name("m3_scaling")
public func m3Scaling(x: Float, y: Float, z: Float) -> Mat3

@_silgen_name("m4_scaling")
public func m4Scaling(x: Float, y: Float, z: Float) -> Mat4

@_silgen_name("m4_scaling_v3")
public func m4ScalingV3(scale: Vec3) -> Mat4

@_silgen_name("m4_trans")
public func m4Trans(x: Float, y: Float, z: Float) -> Mat4

@_silgen_name("m4_trans_v3")
public func m4TransV3(v: Vec3) -> Mat4

@_silgen_name("m4_look_at")
public func m4LookAt(eye: Vec3, target: Vec3, up: Vec3) -> Mat4

@_silgen_name("m4_persp")
public func m4Persp(fovy: Float, aspect: Float, near: Float, far: Float) -> Mat4

@_silgen_name("m4_ortho")
public func m4Ortho(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> Mat4

@_silgen_name("m3_from_m4")
public func m3FromM4(m: Mat4) -> Mat3

@_silgen_name("m4_from_m3")
public func m4FromM3(m: Mat3) -> Mat4

@_silgen_name("m3_normal")
public func m3Normal(model: Mat4) -> Mat3
```