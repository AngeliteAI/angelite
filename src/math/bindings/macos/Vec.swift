
import Foundation

@frozen public struct Vec2 {
  public var x: Float
  public var y: Float

  public init(x: Float, y: Float) {
    self.x = x
    self.y = y
  }
}

@frozen public struct Vec3 {
  public var x: Float
  public var y: Float
  public var z: Float

  public init(x: Float, y: Float, z: Float) {
    self.x = x
    self.y = y
    self.z = z
  }
}

@frozen public struct Vec4 {
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

@frozen public struct IVec2 {
    public var x: Int32
    public var y: Int32

    public init(x: Int32, y: Int32) {
        self.x = x
        self.y = y
    }
}

@frozen public struct IVec3 {
    public var x: Int32
    public var y: Int32
    public var z: Int32

    public init(x: Int32, y: Int32, z: Int32) {
        self.x = x
        self.y = y
        self.z = z
    }
}

@frozen public struct IVec4 {
    public var x: Int32
    public var y: Int32
    public var z: Int32
    public var w: Int32

    public init(x: Int32, y: Int32, z: Int32, w: Int32) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
}

@frozen public struct UVec2 {
    public var x: UInt32
    public var y: UInt32

    public init(x: UInt32, y: UInt32) {
        self.x = x
        self.y = y
    }
}

@frozen public struct UVec3 {
    public var x: UInt32
    public var y: UInt32
    public var z: UInt32

    public init(x: UInt32, y: UInt32, z: UInt32) {
        self.x = x
        self.y = y
        self.z = z
    }
}

@frozen public struct UVec4 {
    public var x: UInt32
    public var y: UInt32
    public var z: UInt32
    public var w: UInt32

    public init(x: UInt32, y: UInt32, z: UInt32, w: UInt32) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
}


// Constructor functions
@_silgen_name("v2")
public func v2(x: Float, y: Float) -> Vec2

@_silgen_name("v3")
public func v3(x: Float, y: Float, z: Float) -> Vec3

@_silgen_name("v4")
public func v4(x: Float, y: Float, z: Float, w: Float) -> Vec4

@_silgen_name("iv2")
public func iv2(x: Int32, y: Int32) -> IVec2

@_silgen_name("iv3")
public func iv3(x: Int32, y: Int32, z: Int32) -> IVec3

@_silgen_name("iv4")
public func iv4(x: Int32, y: Int32, z: Int32, w: Int32) -> IVec4

@_silgen_name("uv2")
public func uv2(x: UInt32, y: UInt32) -> UVec2

@_silgen_name("uv3")
public func uv3(x: UInt32, y: UInt32, z: UInt32) -> UVec3

@_silgen_name("uv4")
public func uv4(x: UInt32, y: UInt32, z: UInt32, w: UInt32) -> UVec4


// Common constants
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

@_silgen_name("iv2Zero")
public func iv2Zero() -> IVec2

@_silgen_name("iv3Zero")
public func iv3Zero() -> IVec3

@_silgen_name("iv4Zero")
public func iv4Zero() -> IVec4

@_silgen_name("uv2Zero")
public func uv2Zero() -> UVec2

@_silgen_name("uv3Zero")
public func uv3Zero() -> UVec3

@_silgen_name("uv4Zero")
public func uv4Zero() -> UVec4

@_silgen_name("iv2One")
public func iv2One() -> IVec2

@_silgen_name("iv3One")
public func iv3One() -> IVec3

@_silgen_name("iv4One")
public func iv4One() -> IVec4

@_silgen_name("uv2One")
public func uv2One() -> UVec2

@_silgen_name("uv3One")
public func uv3One() -> UVec3

@_silgen_name("uv4One")
public func uv4One() -> UVec4


// Unit vectors
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

@_silgen_name("iv2X")
public func iv2X() -> IVec2

@_silgen_name("iv2Y")
public func iv2Y() -> IVec2

@_silgen_name("iv3X")
public func iv3X() -> IVec3

@_silgen_name("iv3Y")
public func iv3Y() -> IVec3

@_silgen_name("iv3Z")
public func iv3Z() -> IVec3

@_silgen_name("iv4X")
public func iv4X() -> IVec4

@_silgen_name("iv4Y")
public func iv4Y() -> IVec4

@_silgen_name("iv4Z")
public func iv4Z() -> IVec4

@_silgen_name("iv4W")
public func iv4W() -> IVec4

@_silgen_name("uv2X")
public func uv2X() -> UVec2

@_silgen_name("uv2Y")
public func uv2Y() -> UVec2

@_silgen_name("uv3X")
public func uv3X() -> UVec3

@_silgen_name("uv3Y")
public func uv3Y() -> UVec3

@_silgen_name("uv3Z")
public func uv3Z() -> UVec3

@_silgen_name("uv4X")
public func uv4X() -> UVec4

@_silgen_name("uv4Y")
public func uv4Y() -> UVec4

@_silgen_name("uv4Z")
public func uv4Z() -> UVec4

@_silgen_name("uv4W")
public func uv4W() -> UVec4


// Basic operations - Vec
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


// Basic operations - IVec
@_silgen_name("iv2Add")
public func iv2Add(a: IVec2, b: IVec2) -> IVec2

@_silgen_name("iv3Add")
public func iv3Add(a: IVec3, b: IVec3) -> IVec3

@_silgen_name("iv4Add")
public func iv4Add(a: IVec4, b: IVec4) -> IVec4

@_silgen_name("iv2Sub")
public func iv2Sub(a: IVec2, b: IVec2) -> IVec2

@_silgen_name("iv3Sub")
public func iv3Sub(a: IVec3, b: IVec3) -> IVec3

@_silgen_name("iv4Sub")
public func iv4Sub(a: IVec4, b: IVec4) -> IVec4

@_silgen_name("iv2Mul")
public func iv2Mul(a: IVec2, b: IVec2) -> IVec2

@_silgen_name("iv3Mul")
public func iv3Mul(a: IVec3, b: IVec3) -> IVec3

@_silgen_name("iv4Mul")
public func iv4Mul(a: IVec4, b: IVec4) -> IVec4

@_silgen_name("iv2Div")
public func iv2Div(a: IVec2, b: IVec2) -> IVec2

@_silgen_name("iv3Div")
public func iv3Div(a: IVec3, b: IVec3) -> IVec3

@_silgen_name("iv4Div")
public func iv4Div(a: IVec4, b: IVec4) -> IVec4

@_silgen_name("iv2Scale")
public func iv2Scale(v: IVec2, s: Int32) -> IVec2

@_silgen_name("iv3Scale")
public func iv3Scale(v: IVec3, s: Int32) -> IVec3

@_silgen_name("iv4Scale")
public func iv4Scale(v: IVec4, s: Int32) -> IVec4

@_silgen_name("iv2Neg")
public func iv2Neg(v: IVec2) -> IVec2

@_silgen_name("iv3Neg")
public func iv3Neg(v: IVec3) -> IVec3

@_silgen_name("iv4Neg")
public func iv4Neg(v: IVec4) -> IVec4


// Basic operations - UVec
@_silgen_name("uv2Add")
public func uv2Add(a: UVec2, b: UVec2) -> UVec2

@_silgen_name("uv3Add")
public func uv3Add(a: UVec3, b: UVec3) -> UVec3

@_silgen_name("uv4Add")
public func uv4Add(a: UVec4, b: UVec4) -> UVec4

@_silgen_name("uv2Sub")
public func uv2Sub(a: UVec2, b: UVec2) -> UVec2

@_silgen_name("uv3Sub")
public func uv3Sub(a: UVec3, b: UVec3) -> UVec3

@_silgen_name("uv4Sub")
public func uv4Sub(a: UVec4, b: UVec4) -> UVec4

@_silgen_name("uv2Mul")
public func uv2Mul(a: UVec2, b: UVec2) -> UVec2

@_silgen_name("uv3Mul")
public func uv3Mul(a: UVec3, b: UVec3) -> UVec3

@_silgen_name("uv4Mul")
public func uv4Mul(a: UVec4, b: UVec4) -> UVec4

@_silgen_name("uv2Div")
public func uv2Div(a: UVec2, b: UVec2) -> UVec2

@_silgen_name("uv3Div")
public func uv3Div(a: UVec3, b: UVec3) -> UVec3

@_silgen_name("uv4Div")
public func uv4Div(a: UVec4, b: UVec4) -> UVec4

@_silgen_name("uv2Scale")
public func uv2Scale(v: UVec2, s: UInt32) -> UVec2

@_silgen_name("uv3Scale")
public func uv3Scale(v: UVec3, s: UInt32) -> UVec3

@_silgen_name("uv4Scale")
public func uv4Scale(v: UVec4, s: UInt32) -> UVec4

@_silgen_name("uv2Neg")
public func uv2Neg(v: UVec2) -> UVec2

@_silgen_name("uv3Neg")
public func uv3Neg(v: UVec3) -> UVec3

@_silgen_name("uv4Neg")
public func uv4Neg(v: UVec4) -> UVec4


// Vector operations - Vec
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


// Vector operations - IVec
@_silgen_name("iv2Dot")
public func iv2Dot(a: IVec2, b: IVec2) -> Int32

@_silgen_name("iv3Dot")
public func iv3Dot(a: IVec3, b: IVec3) -> Int32

@_silgen_name("iv4Dot")
public func iv4Dot(a: IVec4, b: IVec4) -> Int32

@_silgen_name("iv3Cross")
public func iv3Cross(a: IVec3, b: IVec3) -> IVec3

@_silgen_name("iv2Len")
public func iv2Len(v: IVec2) -> Float

@_silgen_name("iv3Len")
public func iv3Len(v: IVec3) -> Float

@_silgen_name("iv4Len")
public func iv4Len(v: IVec4) -> Float

@_silgen_name("iv2Len2")
public func iv2Len2(v: IVec2) -> Int32

@_silgen_name("iv3Len2")
public func iv3Len2(v: IVec3) -> Int32

@_silgen_name("iv4Len2")
public func iv4Len2(v: IVec4) -> Int32

@_silgen_name("iv2Dist")
public func iv2Dist(a: IVec2, b: IVec2) -> Float

@_silgen_name("iv3Dist")
public func iv3Dist(a: IVec3, b: IVec3) -> Float

@_silgen_name("iv4Dist")
public func iv4Dist(a: IVec4, b: IVec4) -> Float

@_silgen_name("iv2Dist2")
public func iv2Dist2(a: IVec2, b: IVec2) -> Int32

@_silgen_name("iv3Dist2")
public func iv3Dist2(a: IVec3, b: IVec3) -> Int32

@_silgen_name("iv4Dist2")
public func iv4Dist2(a: IVec4, b: IVec4) -> Int32

@_silgen_name("iv2Norm")
public func iv2Norm(v: IVec2) -> Vec2

@_silgen_name("iv3Norm")
public func iv3Norm(v: IVec3) -> Vec3

@_silgen_name("iv4Norm")
public func iv4Norm(v: IVec4) -> Vec4


// Vector operations - UVec
@_silgen_name("uv2Dot")
public func uv2Dot(a: UVec2, b: UVec2) -> UInt32

@_silgen_name("uv3Dot")
public func uv3Dot(a: UVec3, b: UVec3) -> UInt32

@_silgen_name("uv4Dot")
public func uv4Dot(a: UVec4, b: UVec4) -> UInt32

@_silgen_name("uv2Len")
public func uv2Len(v: UVec2) -> Float

@_silgen_name("uv3Len")
public func uv3Len(v: UVec3) -> Float

@_silgen_name("uv4Len")
public func uv4Len(v: UVec4) -> Float

@_silgen_name("uv2Len2")
public func uv2Len2(v: UVec2) -> UInt32

@_silgen_name("uv3Len2")
public func uv3Len2(v: UVec3) -> UInt32

@_silgen_name("uv4Len2")
public func uv4Len2(v: UVec4) -> UInt32

@_silgen_name("uv2Dist")
public func uv2Dist(a: UVec2, b: UVec2) -> Float

@_silgen_name("uv3Dist")
public func uv3Dist(a: UVec3, b: UVec3) -> Float

@_silgen_name("uv4Dist")
public func uv4Dist(a: UVec4, b: UVec4) -> Float

@_silgen_name("uv2Dist2")
public func uv2Dist2(a: UVec2, b: UVec2) -> UInt32

@_silgen_name("uv3Dist2")
public func uv3Dist2(a: UVec3, b: UVec3) -> UInt32

@_silgen_name("uv4Dist2")
public func uv4Dist2(a: UVec4, b: UVec4) -> UInt32

@_silgen_name("uv2Norm")
public func uv2Norm(v: UVec2) -> Vec2

@_silgen_name("uv3Norm")
public func uv3Norm(v: UVec3) -> Vec3

@_silgen_name("uv4Norm")
public func uv4Norm(v: UVec4) -> Vec4


// Interpolation and comparison - Vec
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


// Interpolation and comparison - IVec
@_silgen_name("iv2Lerp")
public func iv2Lerp(a: IVec2, b: IVec2, t: Float) -> Vec2

@_silgen_name("iv3Lerp")
public func iv3Lerp(a: IVec3, b: IVec3, t: Float) -> Vec3

@_silgen_name("iv4Lerp")
public func iv4Lerp(a: IVec4, b: IVec4, t: Float) -> Vec4

@_silgen_name("iv2Eq")
public func iv2Eq(a: IVec2, b: IVec2, eps: Int32) -> Bool

@_silgen_name("iv3Eq")
public func iv3Eq(a: IVec3, b: IVec3, eps: Int32) -> Bool

@_silgen_name("iv4Eq")
public func iv4Eq(a: IVec4, b: IVec4, eps: Int32) -> Bool


// Interpolation and comparison - UVec
@_silgen_name("uv2Lerp")
public func uv2Lerp(a: UVec2, b: UVec2, t: Float) -> Vec2

@_silgen_name("uv3Lerp")
public func uv3Lerp(a: UVec3, b: UVec3, t: Float) -> Vec3

@_silgen_name("uv4Lerp")
public func uv4Lerp(a: UVec4, b: UVec4, t: Float) -> Vec4

@_silgen_name("uv2Eq")
public func uv2Eq(a: UVec2, b: UVec2, eps: UInt32) -> Bool

@_silgen_name("uv3Eq")
public func uv3Eq(a: UVec3, b: UVec3, eps: UInt32) -> Bool

@_silgen_name("uv4Eq")
public func uv4Eq(a: UVec4, b: UVec4, eps: UInt32) -> Bool


// Splatting
@_silgen_name("v2Splat")
public func v2Splat(s: Float) -> Vec2

@_silgen_name("v3Splat")
public func v3Splat(s: Float) -> Vec3

@_silgen_name("v4Splat")
public func v4Splat(s: Float) -> Vec4

@_silgen_name("iv2Splat")
public func iv2Splat(s: Int32) -> IVec2

@_silgen_name("iv3Splat")
public func iv3Splat(s: Int32) -> IVec3

@_silgen_name("iv4Splat")
public func iv4Splat(s: Int32) -> IVec4

@_silgen_name("uv2Splat")
public func uv2Splat(s: UInt32) -> UVec2

@_silgen_name("uv3Splat")
public func uv3Splat(s: UInt32) -> UVec3

@_silgen_name("uv4Splat")
public func uv4Splat(s: UInt32) -> UVec4


// Clamping
@_silgen_name("v2Clamp")
public func v2Clamp(v: Vec2, minVal: Float, maxVal: Float) -> Vec2

@_silgen_name("v3Clamp")
public func v3Clamp(v: Vec3, minVal: Float, maxVal: Float) -> Vec3

@_silgen_name("v4Clamp")
public func v4Clamp(v: Vec4, minVal: Float, maxVal: Float) -> Vec4

@_silgen_name("iv2Clamp")
public func iv2Clamp(v: IVec2, minVal: Int32, maxVal: Int32) -> IVec2

@_silgen_name("iv3Clamp")
public func iv3Clamp(v: IVec3, minVal: Int32, maxVal: Int32) -> IVec3

@_silgen_name("iv4Clamp")
public func iv4Clamp(v: IVec4, minVal: Int32, maxVal: Int32) -> IVec4

@_silgen_name("uv2Clamp")
public func uv2Clamp(v: UVec2, minVal: UInt32, maxVal: UInt32) -> UVec2

@_silgen_name("uv3Clamp")
public func uv3Clamp(v: UVec3, minVal: UInt32, maxVal: UInt32) -> UVec3

@_silgen_name("uv4Clamp")
public func uv4Clamp(v: UVec4, minVal: UInt32, maxVal: UInt32) -> UVec4


// Absolute Value
@_silgen_name("v2Abs")
public func v2Abs(v: Vec2) -> Vec2

@_silgen_name("v3Abs")
public func v3Abs(v: Vec3) -> Vec3

@_silgen_name("v4Abs")
public func v4Abs(v: Vec4) -> Vec4

@_silgen_name("iv2Abs")
public func iv2Abs(v: IVec2) -> IVec2

@_silgen_name("iv3Abs")
public func iv3Abs(v: IVec3) -> IVec3

@_silgen_name("iv4Abs")
public func iv4Abs(v: IVec4) -> IVec4


// Min/Max Components
@_silgen_name("v2MinComponent")
public func v2MinComponent(v: Vec2) -> Float

@_silgen_name("v3MinComponent")
public func v3MinComponent(v: Vec3) -> Float

@_silgen_name("v4MinComponent")
public func v4MinComponent(v: Vec4) -> Float

@_silgen_name("iv2MinComponent")
public func iv2MinComponent(v: IVec2) -> Int32

@_silgen_name("iv3MinComponent")
public func iv3MinComponent(v: IVec3) -> Int32

@_silgen_name("iv4MinComponent")
public func iv4MinComponent(v: IVec4) -> Int32

@_silgen_name("uv2MinComponent")
public func uv2MinComponent(v: UVec2) -> UInt32

@_silgen_name("uv3MinComponent")
public func uv3MinComponent(v: UVec3) -> UInt32

@_silgen_name("uv4MinComponent")
public func uv4MinComponent(v: UVec4) -> UInt32

@_silgen_name("v2MaxComponent")
public func v2MaxComponent(v: Vec2) -> Float

@_silgen_name("v3MaxComponent")
public func v3MaxComponent(v: Vec3) -> Float

@_silgen_name("v4MaxComponent")
public func v4MaxComponent(v: Vec4) -> Float

@_silgen_name("iv2MaxComponent")
public func iv2MaxComponent(v: IVec2) -> Int32

@_silgen_name("iv3MaxComponent")
public func iv3MaxComponent(v: IVec3) -> Int32

@_silgen_name("iv4MaxComponent")
public func iv4MaxComponent(v: IVec4) -> Int32

@_silgen_name("uv2MaxComponent")
public func uv2MaxComponent(v: UVec2) -> UInt32

@_silgen_name("uv3MaxComponent")
public func uv3MaxComponent(v: UVec3) -> UInt32

@_silgen_name("uv4MaxComponent")
public func uv4MaxComponent(v: UVec4) -> UInt32


// Component-wise Min/Max
@_silgen_name("v2ComponentMin")
public func v2ComponentMin(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3ComponentMin")
public func v3ComponentMin(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4ComponentMin")
public func v4ComponentMin(a: Vec4, b: Vec4) -> Vec4

@_silgen_name("iv2ComponentMin")
public func iv2ComponentMin(a: IVec2, b: IVec2) -> IVec2

@_silgen_name("iv3ComponentMin")
public func iv3ComponentMin(a: IVec3, b: IVec3) -> IVec3

@_silgen_name("iv4ComponentMin")
public func iv4ComponentMin(a: IVec4, b: IVec4) -> IVec4

@_silgen_name("uv2ComponentMin")
public func uv2ComponentMin(a: UVec2, b: UVec2) -> UVec2

@_silgen_name("uv3ComponentMin")
public func uv3ComponentMin(a: UVec3, b: UVec3) -> UVec3

@_silgen_name("uv4ComponentMin")
public func uv4ComponentMin(a: UVec4, b: UVec4) -> UVec4

@_silgen_name("v2ComponentMax")
public func v2ComponentMax(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3ComponentMax")
public func v3ComponentMax(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4ComponentMax")
public func v4ComponentMax(a: Vec4, b: Vec4) -> Vec4

@_silgen_name("iv2ComponentMax")
public func iv2ComponentMax(a: IVec2, b: IVec2) -> IVec2

@_silgen_name("iv3ComponentMax")
public func iv3ComponentMax(a: IVec3, b: IVec3) -> IVec3

@_silgen_name("iv4ComponentMax")
public func iv4ComponentMax(a: IVec4, b: IVec4) -> IVec4

@_silgen_name("uv2ComponentMax")
public func uv2ComponentMax(a: UVec2, b: UVec2) -> UVec2

@_silgen_name("uv3ComponentMax")
public func uv3ComponentMax(a: UVec3, b: UVec3) -> UVec3

@_silgen_name("uv4ComponentMax")
public func uv4ComponentMax(a: UVec4, b: UVec4) -> UVec4


// Floor, Ceil, Round (for Vec only)
@_silgen_name("v2Floor")
public func v2Floor(v: Vec2) -> Vec2

@_silgen_name("v3Floor")
public func v3Floor(v: Vec3) -> Vec3

@_silgen_name("v4Floor")
public func v4Floor(v: Vec4) -> Vec4

@_silgen_name("v2Ceil")
public func v2Ceil(v: Vec2) -> Vec2

@_silgen_name("v3Ceil")
public func v3Ceil(v: Vec3) -> Vec3

@_silgen_name("v4Ceil")
public func v4Ceil(v: Vec4) -> Vec4

@_silgen_name("v2Round")
public func v2Round(v: Vec2) -> Vec2

@_silgen_name("v3Round")
public func v3Round(v: Vec3) -> Vec3

@_silgen_name("v4Round")
public func v4Round(v: Vec4) -> Vec4


// Step and Smoothstep (for Vec only)
@_silgen_name("v2Step")
public func v2Step(edge: Vec2, v: Vec2) -> Vec2

@_silgen_name("v3Step")
public func v3Step(edge: Vec3, v: Vec3) -> Vec3

@_silgen_name("v4Step")
public func v4Step(edge: Vec4, v: Vec4) -> Vec4

@_silgen_name("v2Smoothstep")
public func v2Smoothstep(edge0: Vec2, edge1: Vec2, v: Vec2) -> Vec2

@_silgen_name("v3Smoothstep")
public func v3Smoothstep(edge0: Vec3, edge1: Vec3, v: Vec3) -> Vec3

@_silgen_name("v4Smoothstep")
public func v4Smoothstep(edge0: Vec4, edge1: Vec4, v: Vec4) -> Vec4


// Is Zero, Is One, Is Unit (for Vec only)
@_silgen_name("v2IsZero")
public func v2IsZero(v: Vec2, eps: Float) -> Bool

@_silgen_name("v3IsZero")
public func v3IsZero(v: Vec3, eps: Float) -> Bool

@_silgen_name("v4IsZero")
public func v4IsZero(v: Vec4, eps: Float) -> Bool

@_silgen_name("v2IsOne")
public func v2IsOne(v: Vec2, eps: Float) -> Bool

@_silgen_name("v3IsOne")
public func v3IsOne(v: Vec3, eps: Float) -> Bool

@_silgen_name("v4IsOne")
public func v4IsOne(v: Vec4, eps: Float) -> Bool

@_silgen_name("v2IsUnit")
public func v2IsUnit(v: Vec2, eps: Float) -> Bool

@_silgen_name("v3IsUnit")
public func v3IsUnit(v: Vec3, eps: Float) -> Bool

@_silgen_name("v4IsUnit")
public func v4IsUnit(v: Vec4, eps: Float) -> Bool


// Projection and Rejection (for Vec only)
@_silgen_name("v2Project")
public func v2Project(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3Project")
public func v3Project(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4Project")
public func v4Project(a: Vec4, b: Vec4) -> Vec4

@_silgen_name("v2Reject")
public func v2Reject(a: Vec2, b: Vec2) -> Vec2

@_silgen_name("v3Reject")
public func v3Reject(a: Vec3, b: Vec3) -> Vec3

@_silgen_name("v4Reject")
public func v4Reject(a: Vec4, b: Vec4) -> Vec4


// Reflection and refraction
@_silgen_name("v2Reflect")
public func v2Reflect(v: Vec2, n: Vec2) -> Vec2

@_silgen_name("v3Reflect")
public func v3Reflect(v: Vec3, n: Vec3) -> Vec3

@_silgen_name("v3Refract")
public func v3Refract(v: Vec3, n: Vec3, eta: Float) -> Vec3


// Type conversions
@_silgen_name("v3FromV2")
public func v3FromV2(v: Vec2, z: Float) -> Vec3

@_silgen_name("v4FromV3")
public func v4FromV3(v: Vec3, w: Float) -> Vec4

@_silgen_name("v2FromV3")
public func v2FromV3(v: Vec3) -> Vec2

@_silgen_name("v3FromV4")
public func v3FromV4(v: Vec4) -> Vec3

@_silgen_name("iv3FromIVec2")
public func iv3FromIVec2(v: IVec2, z: Int32) -> IVec3

@_silgen_name("iv4FromIVec3")
public func iv4FromIVec3(v: IVec3, w: Int32) -> IVec4

@_silgen_name("iv2FromIVec3")
public func iv2FromIVec3(v: IVec3) -> IVec2

@_silgen_name("iv3FromIVec4")
public func iv3FromIVec4(v: IVec4) -> IVec3

@_silgen_name("uv3FromUVec2")
public func uv3FromUVec2(v: UVec2, z: UInt32) -> UVec3

@_silgen_name("uv4FromUVec3")
public func uv4FromUVec3(v: UVec3, w: UInt32) -> UVec4

@_silgen_name("uv2FromUVec3")
public func uv2FromUVec3(v: UVec3) -> UVec2

@_silgen_name("uv3FromUVec4")
public func uv3FromUVec4(v: UVec4) -> UVec3

@_silgen_name("v2FromIVec2")
public func v2FromIVec2(v: IVec2) -> Vec2

@_silgen_name("v3FromIVec3")
public func v3FromIVec3(v: IVec3) -> Vec3

@_silgen_name("v4FromIVec4")
public func v4FromIVec4(v: IVec4) -> Vec4

@_silgen_name("v2FromUVec2")
public func v2FromUVec2(v: UVec2) -> Vec2

@_silgen_name("v3FromUVec3")
public func v3FromUVec3(v: UVec3) -> Vec3

@_silgen_name("v4FromUVec4")
public func v4FromUVec4(v: UVec4) -> Vec4

@_silgen_name("iVec2FromV2")
public func iVec2FromV2(v: Vec2) -> IVec2

@_silgen_name("iVec3FromV3")
public func iVec3FromV3(v: Vec3) -> IVec3

@_silgen_name("iVec4FromV4")
public func iVec4FromV4(v: Vec4) -> IVec4

@_silgen_name("uVec2FromV2")
public func uVec2FromV2(v: Vec2) -> UVec2

@_silgen_name("uVec3FromV3")
public func uVec3FromV3(v: Vec3) -> UVec3

@_silgen_name("uVec4FromV4")
public func uVec4FromV4(v: Vec4) -> UVec4

@_silgen_name("iVec2FromUVec2")
public func iVec2FromUVec2(v: UVec2) -> IVec2

@_silgen_name("iVec3FromUVec3")
public func iVec3FromUVec3(v: UVec3) -> IVec3

@_silgen_name("iVec4FromUVec4")
public func iVec4FromUVec4(v: UVec4) -> IVec4

@_silgen_name("uVec2FromIVec2")
public func uVec2FromIVec2(v: IVec2) -> UVec2

@_silgen_name("uVec3FromIVec3")
public func uVec3FromIVec3(v: IVec3) -> UVec3

@_silgen_name("uVec4FromIVec4")
public func uVec4FromIVec4(v: IVec4) -> UVec4
