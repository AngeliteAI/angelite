import Foundation
import Math
import Metal
import MetalKit

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

public class ActiveChunk: Hashable {
    let volume: Volume
    let position: IVec3

    public func hash(into hasher: inout Hasher) {
        hasher.combine(volume.id)
        hasher.combine(position.x)
        hasher.combine(position.y)
        hasher.combine(position.z)
    }

    public static func == (lhs: ActiveChunk, rhs: ActiveChunk) -> Bool {
        return lhs.volume.id == rhs.volume.id && lhs.position.x == rhs.position.x && lhs.position.y == rhs.position.y && lhs.position.z == rhs.position.z
    }

    init(volume: Volume, position: IVec3) {
        self.volume = volume
        self.position = position
    }
}

struct DrawCommand {
    var indexCount: UInt32
    var instanceCount: UInt32
    var indexStart: UInt32
    var baseVertex: UInt32
    var baseInstance: UInt32
    var allocationID: UInt32
    var faceOffset: UInt32
    var faceCount: UInt32
}

struct Face {
    var position: UVec3  // Base position
    var normal: UInt8  // Face direction/normal (0-5)
    var materialId: UInt16 // Material ID for rendering
    var padding: UInt16  // Padding to ensure 16-byte alignment
}

struct ChunkMetadata {
    var position: SIMD3<Int32>     // 3D position of the chunk in world space
    var lodLevel: UInt8            // Level of detail for the chunk
    var modified: Bool             // Flag indicating if chunk has been modified and needs remeshing
    var visible: Bool              // Flag indicating if chunk is visible in current view
    var generatedFaces: UInt32     // Counter for the number of faces generated for this chunk
    var allocationID: UInt32       // ID of memory allocation for this chunk's faces
    var allocationOffset: UInt32   // Offset in GPU memory for faces
}

public struct Renderer {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue

    var maxConcurrentChunks: Int
    var maxFacesPerChunk: Int = 6144
    var worldChunkSize: UVec3 = uv3Splat(s: 8)
    var totalPossibleFaces: Int = 0
    var chunksInUse: Int = 0
    var activeChunks: [ActiveChunk : Int] = [:]

    var pipelines: PipelineManager

    public init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!

        self.maxConcurrentChunks = 64
        self.pipelines = PipelineManager(device: device)
        self.palettes = PaletteManager(device: device)

        setupPipelines()
    }

    private func setupPipelines() {
        do {
            // Create compute pipelines
            try pipelines.createComputePipeline(
                name: "voxel_countFacesFromPalette", 
                functionName: "countFacesFromPalette"
            )
            
            try pipelines.createComputePipeline(
                name: "voxel_generateMeshFromPalette", 
                functionName: "generateMeshFromPalette"
            )
            
            try pipelines.createComputePipeline(
                name: "voxel_cullChunks", 
                functionName: "cullChunks"
            )
            
            try pipelines.createComputePipeline(
                name: "voxel_generateDrawCommands", 
                functionName: "generateDrawCommands"
            )
            
            try pipelines.createComputePipeline(
                name: "voxel_compactDrawCommands", 
                functionName: "compactDrawCommands"
            )
            
            // Create render pipeline
            let renderDescriptor = try pipelines.createBasicRenderPipelineDescriptor(
                vertexFunction: "vertexShaderWithGPUMemory",
                fragmentFunction: "fragmentFaceShader"
            )
            try pipelines.createRenderPipeline(
                name: "voxel_renderPipeline", 
                descriptor: renderDescriptor
            )
        } catch {
            print("❌ Failed to create pipelines: \(error)")
            fatalError("Pipeline creation failed")
        }
    }
    
    private func setupBuffers() {
        // Create chunk metadata buffer (Shared since CPU needs to read/write)
        let chunkMetadataSize = maxConcurrentChunks * MemoryLayout<ChunkMetadata>.stride
        _ = buffers.createBuffer(
            name: "chunkMetadata", 
            length: chunkMetadataSize, 
            options: .storageModeShared
        )
        
        // Create voxel data buffer (Private with staging for optimal performance)
        let voxelDataSize = maxConcurrentChunks * Int(worldChunkSize.x * worldChunkSize.y * worldChunkSize.z)
        _ = buffers.createBuffer(
            name: "voxelData", 
            length: voxelDataSize, 
            options: .storageModePrivate,
            createStaging: true
        )
        
        // Create faces buffer (Private with staging)
        let totalPossibleFaces = maxConcurrentChunks * maxFacesPerChunk
        let facesSize = totalPossibleFaces * MemoryLayout<Face>.stride
        _ = buffers.createBuffer(
            name: "faces", 
            length: facesSize, 
            options: .storageModePrivate,
            createStaging: true
        )
        
        // Create draw commands buffer (Private with staging)
        let drawCommandsSize = totalPossibleFaces * MemoryLayout<DrawCommand>.stride
        _ = buffers.createBuffer(
            name: "drawCommands", 
            length: drawCommandsSize, 
            options: .storageModePrivate,
            createStaging: true
        )
        
        // Create compacted draw commands buffer (Private with staging)
        _ = buffers.createBuffer(
            name: "compactedDrawCommands", 
            length: drawCommandsSize, 
            options: .storageModePrivate,
            createStaging: true
        )
        
        // Create visibility buffer (Shared for atomic operations)
        let visibilitySize = maxConcurrentChunks * MemoryLayout<UInt32>.stride
        _ = buffers.createBuffer(
            name: "visibility", 
            length: visibilitySize, 
            options: .storageModeShared
        )
        
        // Create indirect args buffer (Shared for atomic counters)
        let indirectArgsSize = 8 * MemoryLayout<UInt32>.stride
        _ = buffers.createBuffer(
            name: "indirectArgs", 
            length: indirectArgsSize, 
            options: .storageModeShared
        )
        
        // Create index buffer (Immutable, so we can use Managed mode for best performance)
        let indices: [UInt16] = [0, 1, 2, 0, 2, 3] // Indices for a quad
        _ = buffers.createOrUpdateBuffer(
            name: "indexBuffer", 
            data: indices, 
            options: .storageModeManaged
        )
    }
}

var renderer: Renderer?;

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

    renderer = Renderer(device: device!)

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
