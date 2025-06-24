import Foundation
import AppKit

// MARK: - C-compatible Type Definitions

// Struct for Frustum that is C-compatible
@frozen
public struct CFrustum {
    public var left: Int32
    public var right: Int32
    public var top: Int32
    public var bottom: Int32

    public init(left: Int32 = 0, right: Int32 = 0, top: Int32 = 0, bottom: Int32 = 0) {
        self.left = left
        self.right = right
        self.top = top
        self.bottom = bottom
    }
}

// Union-like Data structure using memory overlay for C compatibility
@frozen
public struct CData {
    // Raw storage for the union
    private var storage: (UInt64, UInt64)

    // Vector access
    public var x: Float {
        get {
            return withUnsafePointer(to: storage) { ptr in
                return ptr.withMemoryRebound(to: (Float, Float, UInt8).self, capacity: 1) { $0.pointee.0 }
            }
        }
        set {
            withUnsafeMutablePointer(to: &storage) { ptr in
                ptr.withMemoryRebound(to: (Float, Float, UInt8).self, capacity: 1) { ptr in
                    var value = ptr.pointee
                    value.0 = newValue
                    ptr.pointee = value
                }
            }
        }
    }

    public var y: Float {
        get {
            return withUnsafePointer(to: storage) { ptr in
                return ptr.withMemoryRebound(to: (Float, Float, UInt8).self, capacity: 1) { $0.pointee.1 }
            }
        }
        set {
            withUnsafeMutablePointer(to: &storage) { ptr in
                ptr.withMemoryRebound(to: (Float, Float, UInt8).self, capacity: 1) { ptr in
                    var value = ptr.pointee
                    value.1 = newValue
                    ptr.pointee = value
                }
            }
        }
    }

    public var active: UInt8 {
        get {
            return withUnsafePointer(to: storage) { ptr in
                return ptr.withMemoryRebound(to: (Float, Float, UInt8).self, capacity: 1) { $0.pointee.2 }
            }
        }
        set {
            withUnsafeMutablePointer(to: &storage) { ptr in
                ptr.withMemoryRebound(to: (Float, Float, UInt8).self, capacity: 1) { ptr in
                    var value = ptr.pointee
                    value.2 = newValue
                    ptr.pointee = value
                }
            }
        }
    }

    // Alternative field access patterns could be defined here for union behavior

    public init(x: Float = 0, y: Float = 0, active: Bool = false) {
        storage = (0, 0) // Initialize raw storage

        // Set the values using properties to ensure proper memory layout
        self.x = x
        self.y = y
        self.active = active ? 1 : 0
    }
}

// Actor type enum (matching Rust)
public enum ActorType: UInt32 {
    case unknown = 0;
    case player = 1;
    case zombie = 2;
    case turret = 3;
    case ghost = 4;
    // Add more actor types as needed
}

// Actor class that mirrors Rust's Actor enum representation
public class Actor {
    // Memory layout compatible with Rust's Actor enum
    private var tag: UInt32 // This matches the Rust enum discriminant

    // Additional fields for position (not part of the Rust enum but used in Swift)
    var x: Float = 0
    var y: Float = 0

    // Computed property to access the type
    var type: ActorType {
        get {
            return ActorType(rawValue: tag) ?? .unknown
        }
        set {
            tag = newValue.rawValue
        }
    }

    init(type: ActorType) {
        self.tag = type.rawValue
    }

    // Create a plain C representation for FFI
    func toCRepresentation() -> UInt32 {
        return tag
    }
}

// Global storage for actors to prevent deallocation
private var actorRegistry: [UnsafeMutableRawPointer: Actor] = [:]

// MARK: - Engine Implementation

// Engine creation
@_cdecl("engine_create")
public func engine_create() {
    print("Swift: engine_create called")
    // Initialize engine resources here

    // Ensure NSApplication is properly initialized
    let app = NSApplication.shared
    if !app.isRunning {
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        app.activate(ignoringOtherApps: true)
    }
}






// Camera/View management
@_cdecl("engine_set_focus_point")
public func engine_set_focus_point(x: Float, y: Float) {
    print("Swift: engine_set_focus_point called with x: \(x), y: \(y)")
    // Set camera focus point
}

@_cdecl("engine_set_origin")
public func engine_set_origin(x: Int64, y: Int64) {
    print("Swift: engine_set_origin called with x: \(x), y: \(y)")
    // Set world origin coordinates
    // Note: Using Int64 as Swift doesn't have Int128
}

// Cell management
@_cdecl("engine_cell_set")
public func engine_cell_set(x: Int64, y: Int64, tile: UInt32) {
    print("Swift: engine_cell_set called with x: \(x), y: \(y), tile: \(tile)")
    // Set cell at given coordinates to specified tile type
}

// For C interoperability, we return an opaque pointer
@_cdecl("engine_cell_frustum")
public func engine_cell_frustum(_ engine: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
    print("Swift: engine_cell_frustum called")

    // Create a CFrustum and allocate memory for it
    let frustum = CFrustum(left: 0, right: 100, top: 0, bottom: 100)
    let frustumPtr = UnsafeMutablePointer<CFrustum>.allocate(capacity: 1)
    frustumPtr.initialize(to: frustum)

    return UnsafeMutableRawPointer(frustumPtr)
}

// Actor management
@_cdecl("engine_actor_create")
public func engine_actor_create(ty: UInt32) -> UnsafeMutableRawPointer {
    print("Swift: engine_actor_create called with type: \(ty)")

    // Convert raw UInt32 to ActorType
    let actorType = ActorType(rawValue: ty) ?? .unknown
    print("Creating actor of type: \(actorType)")
    let dataPtr = UnsafeMutablePointer<UInt32>.allocate(capacity: (MemoryLayout<ActorType>.size))
    dataPtr.initialize(to: actorType.rawValue)
    //cast to u32 ptr
    let raw = UnsafeMutableRawPointer(dataPtr)
    actorRegistry[dataPtr] = Actor(type: actorType)

    return raw
}

@_cdecl("engine_actor_move")
public func engine_actor_move(actor: UnsafeMutableRawPointer, x: Float, y: Float) {
    print("Swift: engine_actor_move called with x: \(x), y: \(y)")

    // Get the actor from registry and update position
    if let actorObj = actorRegistry[actor] {
        actorObj.x = x
        actorObj.y = y
        print("Moved actor of type: \(actorObj.type) to position (\(x), \(y))")
    } else {
        print("Warning: Could not find actor in registry")
    }
}

@_cdecl("engine_actor_draw")
public func engine_actor_draw(actor: UnsafeMutableRawPointer) {
    print("Swift: engine_actor_draw called")

    // Draw the actor
    if let actorObj = actorRegistry[actor] {
        // Implement drawing logic here
        print("Drawing actor of type: \(actorObj.type) at position (\(actorObj.x), \(actorObj.y))")
    } else {
        print("Warning: Could not find actor in registry")
    }
}

// Input binding
@_cdecl("engine_input_binding_data")
public func engine_input_binding_data(bind: UInt32) -> UnsafeMutableRawPointer {
    print("Swift: engine_input_binding_data called with bind: \(bind)")

    // Create a CData struct with union-like memory layout
    let data = CData(x: 0.0, y: 0.0, active: false)
    let dataPtr = UnsafeMutablePointer<CData>.allocate(capacity: 1)
    dataPtr.initialize(to: data)

    return UnsafeMutableRawPointer(dataPtr)
}

@_cdecl("engine_input_binding_activate")
public func engine_input_binding_activate(button: UInt32, activate: Bool) {
    print("Swift: engine_input_binding_activate called with button: \(button), activate: \(activate)")
    // Activate or deactivate an input binding
}

@_cdecl("engine_input_binding_move")
public func engine_input_binding_move(axis: UInt32, x: Float, y: Float) {
    print("Swift: engine_input_binding_move called with axis: \(axis), x: \(x), y: \(y)")
    // Handle movement input for a specific axis
}

// Debug
@_cdecl("engine_debug_value")
public func engine_debug_value(name: UnsafePointer<Int8>) {
    let swiftString = String(cString: name)
    print("Swift: Debug value: \(swiftString)")
    // Handle debug output
}
