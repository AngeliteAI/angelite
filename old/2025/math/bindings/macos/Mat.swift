// /Users/solmidnight/work/angelite/src/swift/gfx/Mat.swift
// Generated binding for mat.zig

import Foundation

@frozen public struct Mat2 {
  public var data: (Float, Float, Float, Float)

  public init(data: (Float, Float, Float, Float)) {
    self.data = data
  }
}

@frozen public struct Mat3 {
  public var data: (Float, Float, Float, Float, Float, Float, Float, Float, Float)

  public init(data: (Float, Float, Float, Float, Float, Float, Float, Float, Float)) {
    self.data = data
  }
}

@frozen public struct Mat4 {
  public var data:
    (
      Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float,
      Float, Float, Float
    )

  public init(
    data: (
      Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float, Float,
      Float, Float, Float
    )
  ) {
    self.data = data
  }
}

@_silgen_name("m2Id")
public func m2Id() -> Mat2

@_silgen_name("m3Id")
public func m3Id() -> Mat3

@_silgen_name("m4Id")
public func m4Id() -> Mat4

@_silgen_name("m2Zero")
public func m2Zero() -> Mat2

@_silgen_name("m3Zero")
public func m3Zero() -> Mat3

@_silgen_name("m4Zero")
public func m4Zero() -> Mat4

@_silgen_name("m2Add")
public func m2Add(a: Mat2, b: Mat2) -> Mat2

@_silgen_name("m3Add")
public func m3Add(a: Mat3, b: Mat3) -> Mat3

@_silgen_name("m4Add")
public func m4Add(a: Mat4, b: Mat4) -> Mat4

@_silgen_name("m2Sub")
public func m2Sub(a: Mat2, b: Mat2) -> Mat2

@_silgen_name("m3Sub")
public func m3Sub(a: Mat3, b: Mat3) -> Mat3

@_silgen_name("m4Sub")
public func m4Sub(a: Mat4, b: Mat4) -> Mat4

@_silgen_name("m2Mul")
public func m2Mul(a: Mat2, b: Mat2) -> Mat2

@_silgen_name("m3Mul")
public func m3Mul(a: Mat3, b: Mat3) -> Mat3

@_silgen_name("m4Mul")
public func m4Mul(a: Mat4, b: Mat4) -> Mat4

@_silgen_name("m2Scale")
public func m2Scale(m: Mat2, s: Float) -> Mat2

@_silgen_name("m3Scale")
public func m3Scale(m: Mat3, s: Float) -> Mat3

@_silgen_name("m4Scale")
public func m4Scale(m: Mat4, s: Float) -> Mat4

@_silgen_name("m2V2")
public func m2V2(m: Mat2, v: Vec2) -> Vec2

@_silgen_name("m3V3")
public func m3V3(m: Mat3, v: Vec3) -> Vec3

@_silgen_name("m4V4")
public func m4V4(m: Mat4, v: Vec4) -> Vec4

@_silgen_name("m4Point")
public func m4Point(m: Mat4, v: Vec3) -> Vec3

@_silgen_name("m4Dir")
public func m4Dir(m: Mat4, v: Vec3) -> Vec3

@_silgen_name("m2Tr")
public func m2Tr(m: Mat2) -> Mat2

@_silgen_name("m3Tr")
public func m3Tr(m: Mat3) -> Mat3

@_silgen_name("m4Tr")
public func m4Tr(m: Mat4) -> Mat4

@_silgen_name("m2Det")
public func m2Det(m: Mat2) -> Float

@_silgen_name("m3Det")
public func m3Det(m: Mat3) -> Float

@_silgen_name("m4Det")
public func m4Det(m: Mat4) -> Float

@_silgen_name("m2Inv")
public func m2Inv(m: Mat2) -> Mat2

@_silgen_name("m3Inv")
public func m3Inv(m: Mat3) -> Mat3

@_silgen_name("m4Inv")
public func m4Inv(m: Mat4) -> Mat4

@_silgen_name("m2Get")
public func m2Get(m: Mat2, row: Int32, col: Int32) -> Float

@_silgen_name("m3Get")
public func m3Get(m: Mat3, row: Int32, col: Int32) -> Float

@_silgen_name("m4Get")
public func m4Get(m: Mat4, row: Int32, col: Int32) -> Float

@_silgen_name("m2Set")
public func m2Set(m: UnsafeMutablePointer<Mat2>?, row: Int32, col: Int32, val: Float)

@_silgen_name("m3Set")
public func m3Set(m: UnsafeMutablePointer<Mat3>?, row: Int32, col: Int32, val: Float)

@_silgen_name("m4Set")
public func m4Set(m: UnsafeMutablePointer<Mat4>?, row: Int32, col: Int32, val: Float)

@_silgen_name("m2Rot")
public func m2Rot(angle: Float) -> Mat2

@_silgen_name("m3RotX")
public func m3RotX(angle: Float) -> Mat3

@_silgen_name("m3RotY")
public func m3RotY(angle: Float) -> Mat3

@_silgen_name("m3RotZ")
public func m3RotZ(angle: Float) -> Mat3

@_silgen_name("m3RotAxis")
public func m3RotAxis(axis: Vec3, angle: Float) -> Mat3

@_silgen_name("m4RotX")
public func m4RotX(angle: Float) -> Mat4

@_silgen_name("m4RotY")
public func m4RotY(angle: Float) -> Mat4

@_silgen_name("m4RotZ")
public func m4RotZ(angle: Float) -> Mat4

@_silgen_name("m4RotAxis")
public func m4RotAxis(axis: Vec3, angle: Float) -> Mat4

@_silgen_name("m4RotEuler")
public func m4RotEuler(x: Float, y: Float, z: Float) -> Mat4

@_silgen_name("m2Scaling")
public func m2Scaling(x: Float, y: Float) -> Mat2

@_silgen_name("m3Scaling")
public func m3Scaling(x: Float, y: Float, z: Float) -> Mat3

@_silgen_name("m4Scaling")
public func m4Scaling(x: Float, y: Float, z: Float) -> Mat4

@_silgen_name("m4ScalingV3")
public func m4ScalingV3(scale: Vec3) -> Mat4

@_silgen_name("m4Trans")
public func m4Trans(x: Float, y: Float, z: Float) -> Mat4

@_silgen_name("m4TransV3")
public func m4TransV3(v: Vec3) -> Mat4

@_silgen_name("m4LookAt")
public func m4LookAt(eye: Vec3, target: Vec3, up: Vec3) -> Mat4

@_silgen_name("m4Persp")
public func m4Persp(fovy: Float, aspect: Float, near: Float, far: Float) -> Mat4

@_silgen_name("m4Ortho")
public func m4Ortho(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float)
  -> Mat4

@_silgen_name("m3FromM4")
public func m3FromM4(m: Mat4) -> Mat3

@_silgen_name("m4FromM3")
public func m4FromM3(m: Mat3) -> Mat4

@_silgen_name("m3Normal")
public func m3Normal(model: Mat4) -> Mat3
