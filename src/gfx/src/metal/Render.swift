import Foundation
import Math
import Metal
import MetalKit

// MARK: - Library (Assuming it's at "angelite/src/swift/math/src")

// Assuming you have the equivalent Swift math functions in separate files
// like Scalar.swift, Vec.swift, Mat.swift, Quat.swift in the path "angelite/src/swift/math/src"
// These @_silgen_name attributes are crucial for C interoperability.  They
// prevent Swift from mangling the function names, making them callable from C.
/*
    uint32_t seed;
    float amplitude;
    float frequency;
    float persistence;
    float lacunarity;
    uint32_t octaves;
    float2 offset;
*/
@frozen public struct Noise {
  var dataHeapOffset: UInt32 = 0
  var seed: UInt32
  var octaves: UInt32
  var amplitude: Float
  var frequency: Float
  var persistence: Float
  var lacunarity: Float
  var offset: Vec3
  var dimensions: UVec3
  var padding: Float = 0.0

  public init(
    seed: UInt32, amplitude: Float, frequency: Float, persistence: Float, lacunarity: Float,
    octaves: UInt32, offset: Vec3, dimensions: UVec3
  ) {
    self.seed = seed
    self.amplitude = amplitude
    self.frequency = frequency
    self.persistence = persistence
    self.lacunarity = lacunarity
    self.octaves = octaves
    self.offset = offset
    self.dimensions = dimensions
  }
  
  public init(seed: UInt32) {
    self.init(
      seed: seed, amplitude: 1.0, frequency: 1.0, persistence: 0.5, lacunarity: 2.0, octaves: 4,
      offset: Vec3(x: 0.0, y: 0.0, z: 0.0), dimensions: UVec3(x: 32, y: 32, z: 32))
  }
}

struct Terrain {
  var heightScale: Float
  var heightOffset: Float
  var squishingFactor: Float
  var padding: Float
  
  init(heightScale: Float, heightOffset: Float, squishingFactor: Float) {
    self.heightScale = heightScale
    self.heightOffset = heightOffset
    self.squishingFactor = squishingFactor
    self.padding = 0.0
  }
}

@frozen public struct Camera {
  var projection: Mat4
  var position: Vec3
  var yaw: Quat
  var pitch: Quat

  public init(projection: Mat4) {
    self.projection = projection
    self.position = v3Splat(s: 0.0)
    self.yaw = qId()
    self.pitch = qId()
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
    return lhs.volume.id == rhs.volume.id && lhs.position.x == rhs.position.x
      && lhs.position.y == rhs.position.y && lhs.position.z == rhs.position.z
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
  var materialId: UInt16  // Material ID for rendering
  var padding: UInt16  // Padding to ensure 16-byte alignment
}

/*
     uint32_t state;
    uint32_t offsetPalette;
    uint32_t offsetCompressed;
    uint32_t offsetRaw;
    uint32_t offsetMesh;
    uint32_t countPalette;
    atomic_uint countFaces;
    uint32_t sizeRawMaxBytes;
    uint32_t meshValid;
    uint32_t padding;
*/
struct ChunkMetadata {
  var state: UInt32 = 0
  var offsetPalette: UInt32
  var offsetCompressed: UInt32
  var offsetRaw: UInt32
  var offsetMesh: UInt32
  var countPalette: UInt32
  var countFaces: UInt32 = 0
  var sizeRawMaxBytes: UInt32 = 0
  var meshValid: UInt32 = 0
  var padding: UInt32 = 0
}

public struct Renderer {
  var surface: Surface.View

  var device: MTLDevice
  var commandQueue: MTLCommandQueue

  var frame: Int = 0

  var maxConcurrentChunks: Int
  var maxFacesPerChunk: Int = 6144
  var worldChunkSize: UVec3 = uv3Splat(s: 8)
  var totalPossibleFaces: Int = 0
  var chunksInUse: Int = 0
  var activeChunks: [ActiveChunk: Int] = [:]

  var pipelines: PipelineManager
  var heapBuffer: MTLBuffer
  var metadataOffsetBuffer: MTLBuffer
  var commandBuffer: MTLCommandBuffer?

  var renderTargetTexture: MTLTexture?

  var captureManager = MTLCaptureManager.shared()
  var captureScope: MTLCaptureScope?

  var noiseTexture: MTLTexture?

  var camera: Camera? = Camera(
    projection: m4Persp(fovy: Float.pi / 1.5, aspect: 1.0, near: 0.1, far: 100.0))

  // New properties for chunk generation
  var chunkRegenTimer: Float = 0.0
  var chunkOffset: IVec3 = iv3Splat(s: 0)
  var regenerateChunk: Bool = true
  var metadataHeapOffset: UInt32 = 0
  var noiseHeapOffset: UInt32 = 1337
  var terrainHeapOffset: UInt32 = 2674
    
  // Remove multiple chunk properties
  // var chunkMetadataOffsets: [UInt32] = []
  // var numChunks: Int = 1 // For now, just one chunk
    

  public init(surface: Surface.View) {
    self.device = surface.device
    self.surface = surface
    self.commandQueue = device.makeCommandQueue()!

    self.maxConcurrentChunks = 64
    self.pipelines = PipelineManager(device: device)

    self.commandBuffer = renderer?.commandQueue.makeCommandBuffer()!

    self.heapBuffer = device.makeBuffer(
      //4 gigabytes
      length: 10_000_000,
      options: .storageModeShared
    )!
      
    // Allocate space for metadata for all chunks
    // let metadataSize = MemoryLayout<ChunkMetadata>.size
    // let totalMetadataSize = metadataSize * numChunks
    
    // Initialize metadata offsets
    // for i in 0..<numChunks {
    //    chunkMetadataOffsets.append(UInt32(i * metadataSize))
    // }
      
    // Create metadata offset buffer
    self.metadataOffsetBuffer = device.makeBuffer(
        bytes: [metadataHeapOffset],
        length: MemoryLayout<UInt32>.size,
        options: .storageModeShared
    )!
    captureScope = try? captureManager.makeCaptureScope(commandQueue: self.commandQueue)
    captureScope?.label = "VoxelFaceCount"
    do {
      // Create compute pipelines
      try self.pipelines.createComputePipeline(
        name: "voxel_countFacesFromPalette",
        functionName: "countFacesFromPalette"
      )
      _ = try self.pipelines.createComputePipeline(
        name: "voxel_generateMeshFromPalette",
        functionName: "generateMeshFromPalette"
      )
      try self.pipelines.createComputePipeline(
        name: "test_generateNoiseTexture",
        functionName: "generateNoiseTexture"
      )
       try self.pipelines.createComputePipeline(
        name: "voxel_compressVoxelCreatePalette",
        functionName: "compressVoxelCreatePalette"
      )
      try self.pipelines.createComputePipeline(
        name: "voxel_compressVoxelRawData",
        functionName: "compressVoxelRawData"
      )
      try self.pipelines.createComputePipeline(
        name: "voxel_generateTerrainVoxelData",
        functionName: "generateTerrainVoxelData"
      )

      let descriptor = MTLRenderPipelineDescriptor()
      descriptor.vertexFunction = try pipelines.getFunction(name: "vertexFaceShader")
      descriptor.fragmentFunction = try pipelines.getFunction(name: "fragmentFaceShader")
      descriptor.colorAttachments[0].pixelFormat = surface.metalView.colorPixelFormat
      try pipelines.createRenderPipeline(
        name: "voxel_face",
        descriptor: descriptor
      )
    } catch {
      print("❌ Failed to create pipelines: \(error)")
      fatalError("Pipeline creation failed")
    }

    let descriptor = MTLTextureDescriptor()
    descriptor.textureType = .type3D
    descriptor.pixelFormat = .r32Float
    descriptor.width = 32
    descriptor.height = 32
    descriptor.depth = 32
    descriptor.usage = [.shaderRead, .shaderWrite]
    self.noiseTexture = device.makeTexture(descriptor: descriptor)
    self.noiseTexture?.label = "3D Noise Texture"

    self.heapBuffer.label = "Heap Buffer"

    var heapContents = heapBuffer.contents()

    var uncompressed = [UInt32](repeating: 0, count: 512)
    for x in 0..<8 {
      for y in 0..<8 {
        for z in 0..<8 {
          if x == 2 && y == 2 && z == 2 {
            uncompressed[x * 8 * 8 + y * 8 + z] = 1
          }
          if x == 5 && y == 5 && z == 5 {
            uncompressed[x * 8 * 8 + y * 8 + z] = 1
          }
        }
      }
    }
    print("Uncompressed data: \(uncompressed)")

    var palette = Palette(uncompressed: uncompressed)

    var metadata = ChunkMetadata(
      offsetPalette: 100,
      offsetCompressed: 500,
      offsetRaw: 2000,
      offsetMesh: 1000,
      countPalette: UInt32(palette.palette.count),
      countFaces: 0,
      meshValid: 0
    )

    print("Palette: \(palette.palette)")
    print("Palette data: \(palette.data)")
    print("Metadata: \(metadata)")

    let palettePtr = (heapContents + 4 * Int(metadata.offsetPalette)).bindMemory(
      to: UInt32.self, capacity: Int(metadata.countPalette))
    let noisePtr = (heapContents + 4 * Int(noiseHeapOffset)).bindMemory(
      to: Noise.self, capacity: palette.data.count)
    let terrainPtr = (heapContents + 4 * Int(terrainHeapOffset)).bindMemory(
      to: Terrain.self, capacity: palette.data.count)
    let dataPtr = (heapContents + 4 * Int(metadata.offsetCompressed)).bindMemory(
      to: UInt32.self, capacity: palette.data.count)

    let metadataPtr = (heapContents + 4 * Int(metadataHeapOffset)).bindMemory(to: ChunkMetadata.self, capacity: 1)

    metadataPtr.pointee = metadata
    print("palette")
    for i in 0..<metadata.countPalette {
      palettePtr[Int(i)] = UInt32(palette.palette[Int(i)])
    }
    print("data")
    for i in 0..<palette.data.count {
      dataPtr[i] = palette.data[i]
    }
    noisePtr.pointee = Noise(
      seed: 1337, 
      amplitude: 1.0, 
      frequency: 2.0,  // Increase frequency for more variation
      persistence: 0.5, 
      lacunarity: 2.0,
      octaves: 3,  // Fewer octaves for smoother terrain
      offset: Vec3(x: 0.0, y: 0.0, z: 0.0), 
      dimensions: UVec3(x: 32, y: 32, z: 32))
    
    // More appropriate terrain parameters for 8x8x8 chunk
    terrainPtr.pointee = Terrain(
      heightScale: 0.8,     // Scale between 0-1 is good for height as percentage of chunk
      heightOffset: 0.2,    // Small offset to ensure some terrain at the bottom
      squishingFactor: 1.0  // No squishing needed for small chunks
    )
    print("done")
  }

  public mutating func updateRenderTargetIfNeeded() {
    guard let view = self.surface.metalView else { return }

    let width = Int(view.drawableSize.width)
    let height = Int(view.drawableSize.height)

    // Only create a new texture if needed
    if renderTargetTexture == nil || renderTargetTexture!.width != width
      || renderTargetTexture!.height != height
    {

      let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: view.colorPixelFormat,
        width: width,
        height: height,
        mipmapped: false
      )
      textureDescriptor.usage = [.renderTarget, .shaderRead]
      renderTargetTexture = device.makeTexture(descriptor: textureDescriptor)
      renderTargetTexture?.label = "Main Render Target"
    }
  }
}

var renderer: Renderer?

// MARK: - C-Callable Functions
@_cdecl("initRenderer")
public func initRenderer(surface: UnsafeMutableRawPointer) -> Bool {
  if surface == nil {
    print("initRenderer called with null surface pointer")
    return false
  }

  let typedSurface = surface.bindMemory(to: Surface.self, capacity: 1)
  let id = typedSurface.pointee.id
  print("Renderer initialized (Swift): Surface id = \(id)")

  let surfaceView = surfaceViews[id]?.pointee

  renderer = Renderer(surface: surfaceView!)

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
  let deltaTime: Float = 1.0 / 60.0  // Assuming 60 FPS

  renderer?.updateRenderTargetIfNeeded()

  let inputHandler = renderer?.surface.inputHandler

  // Process mouse movement for camera rotation (simplified, no forced activation)
  if inputHandler?.isMouseCaptured == true {
    let deltaX = inputHandler?.mouseDeltaX ?? 0
    let deltaY = inputHandler?.mouseDeltaY ?? 0

    print("Mouse delta: x=\(deltaX), y=\(deltaY)")
    // Apply rotations based on mouse movement
    let sens: Float = 1.0
    let z = qRotY(angle: sens * deltaX)
    let x = qRotX(angle: sens * deltaY)
    let yawTemp = qMul(a: renderer?.camera?.yaw ?? qId(), b: z)
    renderer?.camera?.yaw = yawTemp
    let pitchTemp = qMul(a: renderer?.camera?.pitch ?? qId(), b: x)
    renderer?.camera?.pitch = pitchTemp

    // Reset mouse deltas after use
    inputHandler?.mouseDeltaX = 0
    inputHandler?.mouseDeltaY = 0
  }

  // Process keyboard movement
  // ...existing code for movement...

  // Debug camera position and rotation
  let rotationMatrix = qToM4(
    q: qMul(a: renderer?.camera?.yaw ?? qId(), b: renderer?.camera?.pitch ?? qId()))
  print(
    "Camera: pos=\(renderer?.camera?.position ?? v3Splat(s: 0)), yaw=\(renderer?.camera?.yaw ?? qId())"
  )

  // Check if WASD + space + l shift is pressed with array for loop and dictionary lookup
  let keysPressed = inputHandler?.keysPressed ?? []
  var movement = v3(x: 0, y: 0, z: 0)
  for key in keysPressed {
    print("Key pressed: \(key)")
    switch key {
    case .w:
      print("W key pressed")
      movement = v3Add(a: movement, b: v3Y())
    case .a:
      print("A key pressed")
      movement = v3Sub(a: movement, b: v3X())
    case .s:
      print("S key pressed")
      movement = v3Sub(a: movement, b: v3Y())
    case .d:
      print("D key pressed")
      movement = v3Add(a: movement, b: v3X())
    case .escape:
      print("Escape key pressed")
      // Handle escape key press
      abort()
    case .space:
      print("Space key pressed")
      //Z axis
      movement = v3Add(a: movement, b: v3Z())

    case .c:

      // -Z axis
      movement = v3Sub(a: movement, b: v3Z())
      print("C key pressed")
    case .lShift:
      print("Left Shift key pressed")
    default:
      break
    }
  }
  let rotatedMovement = m4V4(m: rotationMatrix, v: v4FromV3(v: movement, w: 1.0))

  let cameraSpeed: Float = 1.0
  let posTemp = v3Add(
    a: renderer?.camera?.position ?? v3Splat(s: 0.0),
    b: v3Mul(
      a: v3FromV4(v: rotatedMovement),

      b: v3(
        x: cameraSpeed * deltaTime, y: cameraSpeed * deltaTime,
        z: cameraSpeed * deltaTime)))  // Scale by time and speed
  renderer?.camera?.position = posTemp

  let renderPassDescriptor = MTLRenderPassDescriptor()
  
  // Safely unwrap drawable texture
  guard let currentDrawable = renderer?.surface.metalView.currentDrawable else {
    print("No drawable texture available")
    return
  }
  
    let currentTexture = currentDrawable.texture
    
  renderPassDescriptor.colorAttachments[0].texture = currentTexture
  renderPassDescriptor.colorAttachments[0].loadAction = .clear
  renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
  renderPassDescriptor.colorAttachments[0].storeAction = .store
  

guard let commandBuffer = renderer?.commandQueue.makeCommandBuffer()! else {
    print("Failed to create command buffer")
    return
  }
  commandBuffer.label = "Render Command Buffer"

  // Set the render pass descriptor
  commandBuffer.addCompletedHandler { _ in
    // Handle completion if needed
  }

  // Create a render encoder

let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
renderEncoder.label = "Face Rendering Encoder"

// Set the render pipeline
do {
if let pipeline = try renderer?.pipelines.getRenderPipeline(name: "voxel_face") {
    renderEncoder.setRenderPipelineState(pipeline)
}
} catch {
    print("❌ Failed to set render pipeline state: \(error)")
  }

// Set vertex/fragment buffers
renderEncoder.setVertexBuffer(renderer?.heapBuffer, offset: 0, index: 1)
renderEncoder.setVertexBuffer(renderer?.metadataOffsetBuffer, offset: 0, index: 2)

// Set renderer?.camera buffer
let drawableSize = renderer?.surface.metalView.drawableSize ?? CGSize(width: 1.0, height: 1.0)
let aspect = Float(drawableSize.width / drawableSize.height)
renderer?.camera?.projection = m4Persp(fovy: Float.pi / 1.5, aspect: aspect, near: 0.1, far: 100.0)
let transform: Mat4 = m4Mul(a: m4TransV3(v: renderer?.camera?.position ?? v3Splat(s: 0.0)), b: rotationMatrix)
// Create a matrix that flips the z-axis (makes "below" appear "above")
var xyzFlipMatrix = m4Id()
m4Set(m: &xyzFlipMatrix, row: 2, col: 2, val: -1)  // Invert the z component
let view: Mat4 = m4Inv(m: m4Mul(a: transform, b: m4RotX(angle: 3.14 / 2)));
// Correct matrix multiplication order: view -> zFlip -> projection
let projectionMatrix = renderer?.camera?.projection ?? m4Id()
var viewProjection: Mat4 = m4Mul(a: projectionMatrix, b: m4Mul(a: xyzFlipMatrix, b: view))
renderEncoder.setVertexBytes(&viewProjection, length: MemoryLayout<Mat4>.size, index: 3)

// Draw call - get metadata pointer using the correct offset
let heapContents = renderer?.heapBuffer.contents()
let metadataPtr = (heapContents? + 4 * Int(renderer?.metadataHeapOffset ?? 0)).bindMemory(to: ChunkMetadata.self, capacity: 1)
let faceCount = metadataPtr?.pointee.countFaces ?? 0
print("Draw call with faceCount: \(faceCount)")
if faceCount > 0 {
    renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: Int(faceCount) * 6)
}

renderEncoder.endEncoding()
do {
    let computeEncoder = commandBuffer.makeComputeCommandEncoder()!

    computeEncoder.label = "Test noise generate texture"
    // Set the compute pipeline
  do {
    if let pipeline = try renderer?.pipelines.getComputePipeline(name: "test_generateNoiseTexture") {
      computeEncoder.setComputePipelineState(pipeline)
    } else {
      print("❌ Pipeline not found")
    }
  } catch {
    print("❌ Failed to set compute pipeline state: \(error)")
  }
  computeEncoder.setBuffer(renderer?.heapBuffer, offset: 0, index: 0)
  var noiseOffset = renderer?.noiseHeapOffset ?? 1337;
  computeEncoder.setBytes(
    &noiseOffset, length: MemoryLayout<UInt32>.size, index: 1)
  let threadgroupSize1 = MTLSizeMake(8, 8, 8)
  let gridSize1 = MTLSizeMake(4, 4, 4)
  print("Dispatching noise texture compute kernel with gridSize: \(gridSize1) and threadgroupSize: \(threadgroupSize1)")
  computeEncoder.dispatchThreadgroups(gridSize1, threadsPerThreadgroup: threadgroupSize1)
  computeEncoder.endEncoding()
}

  // === Face count/mesh generation compute passes (unchanged)
  do {
  var computeEncoder = commandBuffer.makeComputeCommandEncoder()!
  // ...existing code: set pipelines, buffers, dispatch threads...
    do {
    if let pipeline = try renderer?.pipelines.getComputePipeline(name: "voxel_countFacesFromPalette") {
      computeEncoder.setComputePipelineState(pipeline)
    } else {
      print("❌ Pipeline not found")
    }
  } catch {
    print("❌ Failed to set compute pipeline state: \(error)")
  }
  computeEncoder.setBuffer(renderer?.heapBuffer, offset: 0, index: 0)
  computeEncoder.setBuffer(renderer?.metadataOffsetBuffer, offset: 0, index: 1)
  let threadgroupSize2 = MTLSizeMake(8, 8, 8)
  let gridSize2 = MTLSizeMake(1, 1, 1)  // For a single 8x8x8 chunk
  computeEncoder.dispatchThreadgroups(gridSize2, threadsPerThreadgroup: threadgroupSize2)
  do {
    if let pipeline = try renderer?.pipelines.getComputePipeline(name: "voxel_generateMeshFromPalette") {
      computeEncoder.setComputePipelineState(pipeline)
    } else {
      print("❌ Pipeline not found")
    }
    
  } catch {
    print("❌ Failed to set compute pipeline state: \(error)")
  }
  computeEncoder.dispatchThreadgroups(gridSize2, threadsPerThreadgroup: threadgroupSize2)
  computeEncoder.endEncoding()
  }
  // Add Metal debugging capture
  let captureManager = MTLCaptureManager.shared()
  let captureDescriptor = MTLCaptureDescriptor()
  captureDescriptor.captureObject = renderer!.commandQueue

  // Create a capture scope

  commandBuffer.label = "ChunkFaceCount"
  if let drawable = renderer?.surface.metalView.currentDrawable {
    commandBuffer.present(drawable)
  }
  commandBuffer.addCompletedHandler { _ in
    // Check results - meshFaces should be updated in the metadata
    if let heapContents = renderer?.heapBuffer.contents() {
      // Use the correct offset to access metadata
      let metadataPtr = (heapContents + 4 * Int(renderer?.metadataHeapOffset ?? 0)).bindMemory(to: ChunkMetadata.self, capacity: 1)
      let faceCount = metadataPtr.pointee.countFaces
      print("Detected \(faceCount) faces")
      
      // Debug the metadata structure
      print("Metadata: palette offset=\(metadataPtr.pointee.offsetPalette), mesh offset=\(metadataPtr.pointee.offsetMesh)")
      print("Metadata: raw offset=\(metadataPtr.pointee.offsetRaw), compressed offset=\(metadataPtr.pointee.offsetCompressed)")
      
      // The expected face count would be 6 * 16 = 96 faces
      let expectedFaceCount: UInt32 = 6 * 2
      print("Expected: \(expectedFaceCount) faces?")
      
      renderer?.frame += 1
      
      print("Frame \(renderer?.frame)")
    }
  }
  print("camera position: \(renderer?.camera?.position)")
  commandBuffer.commit()
  
  if(renderer?.frame ?? 0) % 100 == 0 {
    renderer?.captureScope?.end()
  }
    
  // Chunk regeneration logic
  renderer?.chunkRegenTimer += deltaTime
  if renderer?.chunkRegenTimer ?? 0.0 >= 1.0 {
    renderer?.chunkRegenTimer = 0.0
    renderer?.regenerateChunk = true
  }

  if renderer?.regenerateChunk ?? false {
    renderer?.regenerateChunk = false

    guard let commandBuffer = renderer?.commandQueue.makeCommandBuffer() else {
      print("Failed to create command buffer")
      return
    }
    commandBuffer.label = "Chunk Generation Command Buffer"
      
    // Update metadata offset buffer with the correct offset for the current chunk
    let metadataOffset = renderer?.metadataHeapOffset ?? 0
    renderer?.metadataOffsetBuffer.contents().storeBytes(of: metadataOffset, as: UInt32.self)
    
    print("Regenerating chunk with metadata offset: \(metadataOffset)")

    // Reset face count in metadata before generating new mesh
    if let heapContents = renderer?.heapBuffer.contents() {
      let metadataPtr = (heapContents + 4 * Int(metadataOffset)).bindMemory(to: ChunkMetadata.self, capacity: 1)
      metadataPtr.pointee.countFaces = 0
      print("Reset face count to 0")
    }

    // === Generate Noise Texture
    do {
      let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
      computeEncoder.label = "Generate Noise Texture"
      if let pipeline = try? renderer?.pipelines.getComputePipeline(name: "test_generateNoiseTexture") {
        computeEncoder.setComputePipelineState(pipeline)
      } else {
        print("❌ Pipeline not found")
      }
      computeEncoder.setBuffer(renderer?.heapBuffer, offset: 0, index: 0)
      var noiseOffset = renderer?.noiseHeapOffset ?? 1337
      computeEncoder.setBytes(&noiseOffset, length: MemoryLayout<UInt32>.size, index: 1)
      let threadgroupSize = MTLSizeMake(8, 8, 8)
      let gridSize = MTLSizeMake(4, 4, 4)
      computeEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadgroupSize)
      computeEncoder.endEncoding()
    }

    // === Generate Terrain Voxel Data
    do {
      let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
      computeEncoder.label = "Generate Terrain Voxel Data"
      if let pipeline = try? renderer?.pipelines.getComputePipeline(name: "voxel_generateTerrainVoxelData") {
        computeEncoder.setComputePipelineState(pipeline)
      } else {
        print("❌ Pipeline not found")
      }
      computeEncoder.setBuffer(renderer?.heapBuffer, offset: 0, index: 0)
      var metadataOffset = renderer?.metadataHeapOffset ?? 0
      var noiseOffset = renderer?.noiseHeapOffset ?? 1337
      var terrainOffset = renderer?.terrainHeapOffset ?? 2674
      computeEncoder.setBytes(&metadataOffset, length: MemoryLayout<UInt32>.size, index: 1)
      computeEncoder.setBytes(&noiseOffset, length: MemoryLayout<UInt32>.size, index: 2)
      computeEncoder.setBytes(&terrainOffset, length: MemoryLayout<UInt32>.size, index: 3)
      let threadgroupSize = MTLSizeMake(8, 8, 8)
      let gridSize = MTLSizeMake(1, 1, 1)
      computeEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadgroupSize)
      computeEncoder.endEncoding()
    }

    // === Compress Voxel Data - Create Palette
    do {
      let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
      computeEncoder.label = "Compress Voxel Data - Create Palette"
      if let pipeline = try? renderer?.pipelines.getComputePipeline(name: "voxel_compressVoxelCreatePalette") {
        computeEncoder.setComputePipelineState(pipeline)
      } else {
        print("❌ Pipeline not found")
      }
      computeEncoder.setBuffer(renderer?.heapBuffer, offset: 0, index: 0)
      var metadataOffset = renderer?.metadataHeapOffset ?? 0
      computeEncoder.setBytes(&metadataOffset, length: MemoryLayout<UInt32>.size, index: 1)
      let threadgroupSize = MTLSizeMake(8, 8, 8)
      let gridSize = MTLSizeMake(1, 1, 1)
      computeEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadgroupSize)
      computeEncoder.endEncoding()
    }

    // === Compress Voxel Data - Raw Data
    do {
      let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
      computeEncoder.label = "Compress Voxel Data - Raw Data"
      if let pipeline = try? renderer?.pipelines.getComputePipeline(name: "voxel_compressVoxelRawData") {
        computeEncoder.setComputePipelineState(pipeline)
      } else {
        print("❌ Pipeline not found")
      }
      computeEncoder.setBuffer(renderer?.heapBuffer, offset: 0, index: 0)
      var metadataOffset = renderer?.metadataHeapOffset ?? 0
      computeEncoder.setBytes(&metadataOffset, length: MemoryLayout<UInt32>.size, index: 1)
      let threadgroupSize = MTLSizeMake(8, 8, 8)
      let gridSize = MTLSizeMake(1, 1, 1)
      computeEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadgroupSize)
      computeEncoder.endEncoding()
    }

    // === Count Faces From Palette
    do {
      let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
      computeEncoder.label = "Count Faces From Palette"
      if let pipeline = try? renderer?.pipelines.getComputePipeline(name: "voxel_countFacesFromPalette") {
        computeEncoder.setComputePipelineState(pipeline)
      } else {
        print("❌ Pipeline not found")
      }
      computeEncoder.setBuffer(renderer?.heapBuffer, offset: 0, index: 0)
      computeEncoder.setBuffer(renderer?.metadataOffsetBuffer, offset: 0, index: 1)
      let threadgroupSize = MTLSizeMake(1, 1, 1)
      let gridSize = MTLSizeMake(8, 8, 8)
      computeEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadgroupSize)
      computeEncoder.endEncoding()
    }

    // === Generate Mesh From Palette
    do {
      let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
      computeEncoder.label = "Generate Mesh From Palette"
      if let pipeline = try? renderer?.pipelines.getComputePipeline(name: "voxel_generateMeshFromPalette") {
        computeEncoder.setComputePipelineState(pipeline)
      } else {
        print("❌ Pipeline not found")
      }
      computeEncoder.setBuffer(renderer?.heapBuffer, offset: 0, index: 0)
      computeEncoder.setBuffer(renderer?.metadataOffsetBuffer, offset: 0, index: 1)
      let threadgroupSize = MTLSizeMake(8, 8, 8)
      let gridSize = MTLSizeMake(1, 1, 1)
      computeEncoder.dispatchThreadgroups(gridSize, threadsPerThreadgroup: threadgroupSize)
      computeEncoder.endEncoding()
    }

    commandBuffer.commit()
    
    // Wait for face generation to complete and debug the result
    commandBuffer.waitUntilCompleted()
    if let heapContents = renderer?.heapBuffer.contents() {
      let metadataPtr = (heapContents + 4 * Int(metadataOffset)).bindMemory(to: ChunkMetadata.self, capacity: 1)
      print("After generation, detected \(metadataPtr.pointee.countFaces) faces")
    }
  }
}
