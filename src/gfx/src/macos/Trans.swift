import Foundation

@frozen public struct Transform {
    let id: UInt64
    public init() {
        self.id = 0
    }
}

@frozen public struct NoiseParams {
    var seed: UInt64 = 12345
    var frequency: Float = 0.1
    var amplitude: Float = 1.0
    var octaves: UInt32 = 1
    var lacunarity: Float = 2.0
    var persistence: Float = 0.5

    public init() {}
}

@frozen public struct BiasParams {
    var dimension: UInt32 = 0 // Assuming 0, 1, 2 map to Dim.X, Dim.Y, Dim.Z
    var squishFactor: Float = 1.0
    var heightOffset: Float = 0.0
    var scaleY: Float = 1.0
    var scaleFactor: Float = 1.0

     public init() {}
}

// MARK: - C-Callable Functions
@_cdecl("box")
public func box(width: Float, height: Float, depth: Float) -> UnsafeMutableRawPointer? {
    print("box (Swift stub)")
    return nil
}

@_cdecl("sphere")
public func sphere(radius: Float) -> UnsafeMutableRawPointer? {
    print("sphere (Swift stub)")
    return nil
}

@_cdecl("cylinder")
public func cylinder(radius: Float, height: Float) -> UnsafeMutableRawPointer? {
    print("cylinder (Swift stub)")
    return nil
}

@_cdecl("cone")
public func cone(radius: Float, height: Float) -> UnsafeMutableRawPointer? {
    print("cone (Swift stub)")
    return nil
}

@_cdecl("capsule")
public func capsule(radius: Float, height: Float) -> UnsafeMutableRawPointer? {
    print("capsule (Swift stub)")
    return nil
}

@_cdecl("torus")
public func torus(major_radius: Float, minor_radius: Float) -> UnsafeMutableRawPointer? {
    print("torus (Swift stub)")
    return nil
}

@_cdecl("plane")
public func plane(height: Float) -> UnsafeMutableRawPointer? {
    print("plane (Swift stub)")
    return nil
}

@_cdecl("heightmap")
public func heightmap(size: Float, height: Float) -> UnsafeMutableRawPointer? {
    print("heightmap (Swift stub)")
    return nil
}

@_cdecl("translate")
public func translate(vol: UnsafeMutableRawPointer?, x: Float, y: Float, z: Float) -> UnsafeMutableRawPointer? {
    print("translate (Swift stub)")
    return nil
}

@_cdecl("rotate")
public func rotate(vol: UnsafeMutableRawPointer?, x: Float, y: Float, z: Float, angle: Float) -> UnsafeMutableRawPointer? {
    print("rotate (Swift stub)")
    return nil
}

@_cdecl("scale")
public func scale(vol: UnsafeMutableRawPointer?, x: Float, y: Float, z: Float) -> UnsafeMutableRawPointer? {
    print("scale (Swift stub)")
    return nil
}

@_cdecl("bias")
public func bias(vol: UnsafeMutableRawPointer?, bias_params: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
    print("bias (Swift stub)")
    return nil
}

@_cdecl("flattenBelow")
public func flattenBelow(vol: UnsafeMutableRawPointer?, height: Float, transition: Float) -> UnsafeMutableRawPointer? {
    print("flattenBelow (Swift stub)")
    return nil
}

@_cdecl("amplifyAbove")
public func amplifyAbove(vol: UnsafeMutableRawPointer?, height: Float, factor: Float, transition: Float) -> UnsafeMutableRawPointer? {
    print("amplifyAbove (Swift stub)")
    return nil
}

@_cdecl("join")
public func join(a: UnsafeMutableRawPointer?, b: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    print("join (Swift stub)")
    return nil
}

@_cdecl("cut")
public func cut(a: UnsafeMutableRawPointer?, b: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    print("cut (Swift stub)")
    return nil
}

@_cdecl("intersect")
public func intersect(a: UnsafeMutableRawPointer?, b: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer? {
    print("intersect (Swift stub)")
    return nil
}

@_cdecl("blend")
public func blend(a: UnsafeMutableRawPointer?, b: UnsafeMutableRawPointer?, smoothness: Float) -> UnsafeMutableRawPointer? {
    print("blend (Swift stub)")
    return nil
}

@_cdecl("elongate")
public func elongate(vol: UnsafeMutableRawPointer?, x: Float, y: Float, z: Float) -> UnsafeMutableRawPointer? {
    print("elongate (Swift stub)")
    return nil
}

@_cdecl("round")
public func round(vol: UnsafeMutableRawPointer?, radius: Float) -> UnsafeMutableRawPointer? {
    print("round (Swift stub)")
    return nil
}

@_cdecl("shell")
public func shell(vol: UnsafeMutableRawPointer?, thickness: Float) -> UnsafeMutableRawPointer? {
    print("shell (Swift stub)")
    return nil
}

@_cdecl("perlinNoise")
public func perlinNoise(params: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
    print("perlinNoise (Swift stub)")
    return nil
}

@_cdecl("simplexNoise")
public func simplexNoise(params: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
    print("simplexNoise (Swift stub)")
    return nil
}

@_cdecl("worleyNoise")
public func worleyNoise(params: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
    print("worleyNoise (Swift stub)")
    return nil
}

@_cdecl("ridgedNoise")
public func ridgedNoise(params: UnsafeRawPointer?) -> UnsafeMutableRawPointer? {
    print("ridgedNoise (Swift stub)")
    return nil
}

@_cdecl("displace")
public func displace(vol: UnsafeMutableRawPointer?, noise: UnsafeMutableRawPointer?, strength: Float) -> UnsafeMutableRawPointer? {
    print("displace (Swift stub)")
    return nil
}

@_cdecl("warp")
public func warp(vol: UnsafeMutableRawPointer?, noise: UnsafeMutableRawPointer?, strength: Float) -> UnsafeMutableRawPointer? {
    print("warp (Swift stub)")
    return nil
}

@_cdecl("bend")
public func bend(vol: UnsafeMutableRawPointer?, angle: Float, axis: UInt8) -> UnsafeMutableRawPointer? {
    print("bend (Swift stub)")
    return nil
}

@_cdecl("twist")
public func twist(vol: UnsafeMutableRawPointer?, strength: Float, axis: UInt8) -> UnsafeMutableRawPointer? {
    print("twist (Swift stub)")
    return nil
}

@_cdecl("repeat")
public func repeatVolume(vol: UnsafeMutableRawPointer?, x: Float, y: Float, z: Float) -> UnsafeMutableRawPointer? {
    print("repeatVolume (Swift stub)")
    return nil
}

@_cdecl("repeatLimited")
public func repeatLimited(vol: UnsafeMutableRawPointer?, x: Float, y: Float, z: Float, count: UInt32) -> UnsafeMutableRawPointer? {
    print("repeatLimited (Swift stub)")
    return nil
}

@_cdecl("generate")
public func generate(vol: UnsafeMutableRawPointer?, size_x: UInt32, size_y: UInt32, size_z: UInt32) -> UnsafeMutableRawPointer? {
    print("generate (Swift stub)")
    return nil
}

@_cdecl("release")
public func release(sdf: UnsafeMutableRawPointer?) {
    print("release (Swift stub)")
}
