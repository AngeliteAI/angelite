// /Users/solmidnight/work/angelite/src/swift/gfx/MathScalar.swift
// Generated binding for combined math and scalar zig files

import Foundation

// Constants from include/math.zig
public let PI: Float = 3.14159265358979323846
public let TWO_PI: Float = 6.28318530717958647692
public let HALF_PI: Float = 1.57079632679489661923
public let INV_PI: Float = 0.31830988618379067154
public let DEG_TO_RAD: Float = 0.01745329251994329577
public let RAD_TO_DEG: Float = 57.2957795130823208768
public let EPSILON: Float = 0.000001

// Functions from scalar.zig
@_silgen_name("rad")
public func rad(deg: Float) -> Float

@_silgen_name("deg")
public func deg(rad: Float) -> Float

@_silgen_name("lerp")
public func lerp(a: Float, b: Float, t: Float) -> Float

@_silgen_name("clamp")
public func clamp(val: Float, min: Float, max: Float) -> Float

@_silgen_name("step")
public func step(edge: Float, x: Float) -> Float

@_silgen_name("smoothstep")
public func smoothstep(edge0: Float, edge1: Float, x: Float) -> Float

@_silgen_name("min")
public func min(a: Float, b: Float) -> Float

@_silgen_name("max")
public func max(a: Float, b: Float) -> Float

@_silgen_name("abs")
public func abs(x: Float) -> Float

@_silgen_name("floor")
public func floor(x: Float) -> Float

@_silgen_name("ceil")
public func ceil(x: Float) -> Float

@_silgen_name("round")
public func round(x: Float) -> Float

@_silgen_name("mod")
public func mod(x: Float, y: Float) -> Float

@_silgen_name("pow")
public func pow(x: Float, y: Float) -> Float

@_silgen_name("sqrt")
public func sqrt(x: Float) -> Float

@_silgen_name("sin")
public func sin(x: Float) -> Float

@_silgen_name("cos")
public func cos(x: Float) -> Float

@_silgen_name("tan")
public func tan(x: Float) -> Float

@_silgen_name("asin")
public func asin(x: Float) -> Float

@_silgen_name("acos")
public func acos(x: Float) -> Float

@_silgen_name("atan")
public func atan(x: Float) -> Float

@_silgen_name("atan2")
public func atan2(y: Float, x: Float) -> Float

@_silgen_name("eq")
public func eq(a: Float, b: Float, eps: Float) -> Bool
```

*   Correct function naming and return types.
*   All relevant constants and functions are in a single file.