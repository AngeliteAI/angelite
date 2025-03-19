// /Users/solmidnight/work/angelite/src/swift/gfx/Vec.swift
// Generated binding for vec.zig

import Foundation

public struct Vec2 {
    public var x: Float
    public var y: Float

    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

public struct Vec3 {
    public var x: Float
    public var y: Float
    public var z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
}

public struct Vec4 {
    public var x: Float
    public var y: Float
    public var z: Float
    public var w: Float

    public init(x: Float, y: Float, z: Float, w: Float) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
}

@_silgen_name("v2")
public func v2(x: Float, y: Float) -> Vec2

@_silgen_name("v3")
public func v3(x: Float, y: Float, z: Float) -> Vec3

@_silgen_name("v4")
public func v4(x: Float, y: Float, z: Float, w: Float) -> Vec4

@_silgen_name("v2_zero")
public func v2Zero() -> Vec2

@_silgen_name("v3_zero")
public func v3Zero() -> Vec3

@_silgen_name("v4_zero")
public func v4Zero() -> Vec4

@_silgen_name("v2_one")
public func v2One() -> Vec2

@_silgen_name("v3_one")
public func v3One() -> Vec3

@_silgen_name("v4_one")
public func v4One() -> Vec4

@_silgen_name("v2_x")
public func v2X() -> Vec2

@_silgen_name("v2_y")
public func v2Y() -> Vec2

@_silgen_name("v3_x")
public func v3X() -> Vec3

@_silgen_name("v3_y")
public func v3Y() -> Vec3

@_silgen_name("v3_z")
public func v3Z() -> Vec3

@_silgen_name("v4_x")
public func v4X() -> Vec4

@_silgen_name("v4_y")
public func v4Y() -> Vec4

@_silgen_name("v4_z")
public func v4Z() -> Vec4

@_silgen_name("v4_w")
public func v4W() -> Vec4

@_silgen_name("v2_add")
public func v2Add(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3_add")
public func v3Add(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4_add")
public func v4Add(a: Vec4, b: Vec4) -> Vec4

@_silgen_name("v2_sub")
public func v2Sub(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3_sub")
public func v3Sub(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4_sub")
public func v4Sub(a: Vec4, b: Vec4) -> Vec4

@_silgen_name("v2_mul")
public func v2Mul(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3_mul")
public func v3Mul(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4_mul")
public func v4Mul(a: Vec4, b: Vec4) -> Vec4

@_silgen_name("v2_div")
public func v2Div(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3_div")
public func v3Div(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4_div")
public func v4Div(a: Vec4, b: Vec4) -> Vec4

@_silgen_name("v2_scale")
public func v2Scale(v: Vec2, s: Float) -> Vec2

@_silgen_name("v3_scale")
public func v3Scale(v: Vec3, s: Float) -> Vec3

@_silgen_name("v4_scale")
public func v4Scale(v: Vec4, s: Float) -> Vec4

@_silgen_name("v2_neg")
public func v2Neg(v: Vec2) -> Vec2

@_silgen_name("v3_neg")
public func v3Neg(v: Vec3) -> Vec3

@_silgen_name("v4_neg")
public func v4Neg(v: Vec4) -> Vec4

@_silgen_name("v2_dot")
public func v2Dot(a: Vec2, b: Vec2) -> Float

@_silgen_name("v3_dot")
public func v3Dot(a: Vec3, b: Vec3) -> Float

@_silgen_name("v4_dot")
public func v4Dot(a: Vec4, b: Vec4) -> Float

@_silgen_name("v3_cross")
public func v3Cross(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v2_len")
public func v2Len(v: Vec2) -> Float

@_silgen_name("v3_len")
public func v3Len(v: Vec3) -> Float

@_silgen_name("v4_len")
public func v4Len(v: Vec4) -> Float

@_silgen_name("v2_len2")
public func v2Len2(v: Vec2) -> Float

@_silgen_name("v3_len2")
public func v3Len2(v: Vec3) -> Float

@_silgen_name("v4_len2")
public func v4Len2(v: Vec4) -> Float

@_silgen_name("v2_dist")
public func v2Dist(a: Vec2, b: Vec2) -> Float

@_silgen_name("v3_dist")
public func v3Dist(a: Vec3, b: Vec3) -> Float

@_silgen_name("v4_dist")
public func v4Dist(a: Vec4, b: Vec4) -> Float

@_silgen_name("v2_dist2")
public func v2Dist2(a: Vec2, b: Vec2) -> Float

@_silgen_name("v3_dist2")
public func v3Dist2(a: Vec3, b: Vec3) -> Float

@_silgen_name("v4_dist2")
public func v4Dist2(a: Vec4, b: Vec4) -> Float

@_silgen_name("v2_norm")
public func v2Norm(v: Vec2) -> Vec2

@_silgen_name("v3_norm")
public func v3Norm(v: Vec3) -> Vec3

@_silgen_name("v4_norm")
public func v4Norm(v: Vec4) -> Vec4

@_silgen_name("v2_lerp")
public func v2Lerp(a: Vec2, b: Vec2, t: Float) -> Vec2

@_silgen_name("v3_lerp")
public func v3Lerp(a: Vec3, b: Vec3, t: Float) -> Vec3

@_silgen_name("v4_lerp")
public func v4Lerp(a: Vec4, b: Vec4, t: Float) -> Vec4

@_silgen_name("v2_eq")
public func v2Eq(a: Vec2, b: Vec2, eps: Float) -> Bool

@_silgen_name("v3_eq")
public func v3Eq(a: Vec3, b: Vec3, eps: Float) -> Bool

@_silgen_name("v4_eq")
public func v4Eq(a: Vec4, b: Vec4, eps: Float) -> Bool

@_silgen_name("v2_reflect")
public func v2Reflect(v: Vec2, n: Vec2) -> Vec2

@_silgen_name("v3_reflect")
public func v3Reflect(v: Vec3, n: Vec3) -> Vec3

@_silgen_name("v3_refract")
public func v3Refract(v: Vec3, n: Vec3, eta: Float) -> Vec3

@_silgen_name("v3_from_v2")
public func v3FromV2(v: Vec2, z: Float) -> Vec3

@_silgen_name("v4_from_v3")
public func v4FromV3(v: Vec3, w: Float) -> Vec4

@_silgen_name("v2_from_v3")
public func v2FromV3(v: Vec3) -> Vec2

@_silgen_name("v3_from_v4")
public func v3FromV4(v: Vec4) -> Vec3
```