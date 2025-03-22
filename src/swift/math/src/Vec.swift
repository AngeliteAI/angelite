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

@_silgen_name("v2Zero")
public func v2Zero() -> Vec2

@_silgen_name("v3Zero")
public func v3Zero() -> Vec3

@_silgen_name("v4Zero")
public func v4Zero() -> Vec4

@_silgen_name("v2One")
public func v2One() -> Vec2

@_silgen_name("v3One")
public func v3One() -> Vec3

@_silgen_name("v4One")
public func v4One() -> Vec4

@_silgen_name("v2X")
public func v2X() -> Vec2

@_silgen_name("v2Y")
public func v2Y() -> Vec2

@_silgen_name("v3X")
public func v3X() -> Vec3

@_silgen_name("v3Y")
public func v3Y() -> Vec3

@_silgen_name("v3Z")
public func v3Z() -> Vec3

@_silgen_name("v4X")
public func v4X() -> Vec4

@_silgen_name("v4Y")
public func v4Y() -> Vec4

@_silgen_name("v4Z")
public func v4Z() -> Vec4

@_silgen_name("v4W")
public func v4W() -> Vec4

@_silgen_name("v2Add")
public func v2Add(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3Add")
public func v3Add(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4Add")
public func v4Add(a: Vec4, b: Vec4) -> Vec4

@_silgen_name("v2Sub")
public func v2Sub(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3Sub")
public func v3Sub(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4Sub")
public func v4Sub(a: Vec4, b: Vec4) -> Vec4

@_silgen_name("v2Mul")
public func v2Mul(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3Mul")
public func v3Mul(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4Mul")
public func v4Mul(a: Vec4, b: Vec4) -> Vec4

@_silgen_name("v2Div")
public func v2Div(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3Div")
public func v3Div(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4Div")
public func v4Div(a: Vec4, b: Vec4) -> Vec4

@_silgen_name("v2Scale")
public func v2Scale(v: Vec2, s: Float) -> Vec2

@_silgen_name("v3Scale")
public func v3Scale(v: Vec3, s: Float) -> Vec3

@_silgen_name("v4Scale")
public func v4Scale(v: Vec4, s: Float) -> Vec4

@_silgen_name("v2Neg")
public func v2Neg(v: Vec2) -> Vec2

@_silgen_name("v3Neg")
public func v3Neg(v: Vec3) -> Vec3

@_silgen_name("v4Neg")
public func v4Neg(v: Vec4) -> Vec4

@_silgen_name("v2Dot")
public func v2Dot(a: Vec2, b: Vec2) -> Float

@_silgen_name("v3Dot")
public func v3Dot(a: Vec3, b: Vec3) -> Float

@_silgen_name("v4Dot")
public func v4Dot(a: Vec4, b: Vec4) -> Float

@_silgen_name("v3Cross")
public func v3Cross(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v2Len")
public func v2Len(v: Vec2) -> Float

@_silgen_name("v3Len")
public func v3Len(v: Vec3) -> Float

@_silgen_name("v4Len")
public func v4Len(v: Vec4) -> Float

@_silgen_name("v2Len2")
public func v2Len2(v: Vec2) -> Float

@_silgen_name("v3Len2")
public func v3Len2(v: Vec3) -> Float

@_silgen_name("v4Len2")
public func v4Len2(v: Vec4) -> Float

@_silgen_name("v2Dist")
public func v2Dist(a: Vec2, b: Vec2) -> Float

@_silgen_name("v3Dist")
public func v3Dist(a: Vec3, b: Vec3) -> Float

@_silgen_name("v4Dist")
public func v4Dist(a: Vec4, b: Vec4) -> Float

@_silgen_name("v2Dist2")
public func v2Dist2(a: Vec2, b: Vec2) -> Float

@_silgen_name("v3Dist2")
public func v3Dist2(a: Vec3, b: Vec3) -> Float

@_silgen_name("v4Dist2")
public func v4Dist2(a: Vec4, b: Vec4) -> Float

@_silgen_name("v2Norm")
public func v2Norm(v: Vec2) -> Vec2

@_silgen_name("v3Norm")
public func v3Norm(v: Vec3) -> Vec3

@_silgen_name("v4Norm")
public func v4Norm(v: Vec4) -> Vec4

@_silgen_name("v2Lerp")
public func v2Lerp(a: Vec2, b: Vec2, t: Float) -> Vec2

@_silgen_name("v3Lerp")
public func v3Lerp(a: Vec3, b: Vec3, t: Float) -> Vec3

@_silgen_name("v4Lerp")
public func v4Lerp(a: Vec4, b: Vec4, t: Float) -> Vec4

@_silgen_name("v2Eq")
public func v2Eq(a: Vec2, b: Vec2, eps: Float) -> Bool

@_silgen_name("v3Eq")
public func v3Eq(a: Vec3, b: Vec3, eps: Float) -> Bool

@_silgen_name("v4Eq")
public func v4Eq(a: Vec4, b: Vec4, eps: Float) -> Bool

@_silgen_name("v2Reflect")
public func v2Reflect(v: Vec2, n: Vec2) -> Vec2

@_silgen_name("v3Reflect")
public func v3Reflect(v: Vec3, n: Vec3) -> Vec3

@_silgen_name("v3Refract")
public func v3Refract(v: Vec3, n: Vec3, eta: Float) -> Vec3

@_silgen_name("v3FromV2")
public func v3FromV2(v: Vec2, z: Float) -> Vec3

@_silgen_name("v4FromV3")
public func v4FromV3(v: Vec3, w: Float) -> Vec4

@_silgen_name("v2FromV3")
public func v2FromV3(v: Vec3) -> Vec2

@_silgen_name("v3FromV4")
public func v3FromV4(v: Vec4) -> Vec3