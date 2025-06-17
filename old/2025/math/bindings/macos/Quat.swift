// /Users/solmidnight/work/angelite/src/swift/gfx/Quat.swift
// Generated binding for quat.zig

import Foundation

@frozen public struct Quat {
  public var v: Vec3
  public var w: Float

  public init(v: Vec3, w: Float) {
    self.v = v
    self.w = w
  }
}

@_silgen_name("q")
public func q(x: Float, y: Float, z: Float, w: Float) -> Quat

@_silgen_name("qFromVec")
public func qFromVec(v: Vec3, w: Float) -> Quat

@_silgen_name("qId")
public func qId() -> Quat

@_silgen_name("qZero")
public func qZero() -> Quat

@_silgen_name("qAxis")
public func qAxis(axis: Vec3, angle: Float) -> Quat

@_silgen_name("qEuler")
public func qEuler(x: Float, y: Float, z: Float) -> Quat

@_silgen_name("qFromM3")
public func qFromM3(m: Mat3) -> Quat

@_silgen_name("qFromM4")
public func qFromM4(m: Mat4) -> Quat

@_silgen_name("qToM3")
public func qToM3(q: Quat) -> Mat3

@_silgen_name("qToM4")
public func qToM4(q: Quat) -> Mat4

@_silgen_name("qAdd")
public func qAdd(a: Quat, b: Quat) -> Quat

@_silgen_name("qSub")
public func qSub(a: Quat, b: Quat) -> Quat

@_silgen_name("qMul")
public func qMul(a: Quat, b: Quat) -> Quat

@_silgen_name("qScale")
public func qScale(q: Quat, s: Float) -> Quat

@_silgen_name("qNeg")
public func qNeg(q: Quat) -> Quat

@_silgen_name("qLen")
public func qLen(q: Quat) -> Float

@_silgen_name("qLen2")
public func qLen2(q: Quat) -> Float

@_silgen_name("qNorm")
public func qNorm(q: Quat) -> Quat

@_silgen_name("qConj")
public func qConj(q: Quat) -> Quat

@_silgen_name("qInv")
public func qInv(q: Quat) -> Quat

@_silgen_name("qDot")
public func qDot(a: Quat, b: Quat) -> Float

@_silgen_name("qEq")
public func qEq(a: Quat, b: Quat, eps: Float) -> Bool

@_silgen_name("qRotV3")
public func qRotV3(q: Quat, v: Vec3) -> Vec3

@_silgen_name("qLerp")
public func qLerp(a: Quat, b: Quat, t: Float) -> Quat

@_silgen_name("qSlerp")
public func qSlerp(a: Quat, b: Quat, t: Float) -> Quat

@_silgen_name("qNlerp")
public func qNlerp(a: Quat, b: Quat, t: Float) -> Quat

@_silgen_name("qGetAxis")
public func qGetAxis(
  q: Quat, axis: UnsafeMutablePointer<Vec3>?, angle: UnsafeMutablePointer<Float>?)

@_silgen_name("qToEuler")
public func qToEuler(q: Quat) -> Vec3

@_silgen_name("qRotX")
public func qRotX(angle: Float) -> Quat

@_silgen_name("qRotY")
public func qRotY(angle: Float) -> Quat

@_silgen_name("qRotZ")
public func qRotZ(angle: Float) -> Quat

@_silgen_name("qRoll")
public func qRoll(quat: Quat) -> Float

@_silgen_name("qPitch")
public func qPitch(quat: Quat) -> Float

@_silgen_name("qYaw")
public func qYaw(quat: Quat) -> Float

@_silgen_name("qLookAt")
public func qLookAt(dir: Vec3, up: Vec3) -> Quat

@_silgen_name("qFromTo")
public func qFromTo(from: Vec3, to: Vec3) -> Quat

@_silgen_name("qGetVec")
public func qGetVec(q: Quat) -> Vec3

@_silgen_name("qGetW")
public func qGetW(q: Quat) -> Float
