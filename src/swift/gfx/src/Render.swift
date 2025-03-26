import Foundation
import Math

// MARK: - Library (Assuming it's at "angelite/src/swift/math/src")

// Assuming you have the equivalent Swift math functions in separate files
// like Scalar.swift, Vec.swift, Mat.swift, Quat.swift in the path "angelite/src/swift/math/src"
// These @_silgen_name attributes are crucial for C interoperability.  They
// prevent Swift from mangling the function names, making them callable from C.


@frozen public struct Camera {
    let position: Vec3
    let rotation: Quat
    let projection: Mat4

    public init(position: Vec3, rotation: Quat, projection: Mat4) {
        self.position = position
        self.rotation = rotation
        self.projection = projection
    }
}

@frozen public struct RenderSettings {
    var viewDistance: UInt32
    var enableAO: Bool

    public init(viewDistance: UInt32, enableAO: Bool) {
        self.viewDistance = viewDistance
        self.enableAO = enableAO
    }

    // Initialize with default values (like the Zig code)
    public init() {
        self.viewDistance = 16
        self.enableAO = true
    }
}


// MARK: - C-Callable Functions
@_cdecl("initRenderer")
public func initRenderer(surface: UnsafeMutableRawPointer) -> Bool {
    if surface == nil {
        print("initRenderer called with null surface pointer")
        return false
    }

    let typedSurface = surface.bindMemory(to: Surface.self, capacity: 1)
    let id = typedSurface.pointee.id;
    print("Renderer initialized (Swift): id = \(id)")

    let device = surfaceViews[id]?.pointee.device;

    print("Renderer initialized (Swift): id = \(id), device = \(device)")

    return true
}

@_cdecl("shutdownRenderer")
public func shutdownRenderer() {
    // Clean up resources here.
    print("Renderer shutdown (Swift)")
}

@_cdecl("setCamera")
public func setCamera(camera: UnsafeMutableRawPointer) {
}

@_cdecl("setSettings")
public func setSettings(settings: UnsafeMutableRawPointer) {
}

@_cdecl("addVolume")
public func addVolume(voxels: UnsafeMutableRawPointer?, position: UnsafeRawPointer) {
    print("Add volume (Swift) at position: \(position)")
}

@_cdecl("removeVolume")
public func removeVolume(position: UnsafeRawPointer) {
     print("Remove volume (Swift) at position: \(position)")
}

@_cdecl("clearVolumes")
public func clearVolumes() {
    print("Clear volumes (Swift)")
}

@_cdecl("render")
public func render() {
    print("Render (Swift)")
}
