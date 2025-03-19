import Metal
import MetalKit

struct GpuGenerator {
  var size: SIMD3<UInt32>
}

struct GpuMesh {
  var vertexCount: UInt32 = 0
  var indexCount: UInt32 = 0
}

struct GpuMesher {
  var size: SIMD3<UInt32>
}

// Struct to track buffer processing information
struct BufferTrackingInfo {
  let callId: Int
  let startTime: CFAbsoluteTime
  var endTime: CFAbsoluteTime?
  var status: String
  var additionalData: [String: Any]

  init(callId: Int) {
    self.callId = callId
    self.startTime = CFAbsoluteTimeGetCurrent()
    self.status = "Started"
    self.additionalData = [:]
  }

  mutating func complete() {
    self.endTime = CFAbsoluteTimeGetCurrent()
    self.status = "Completed"
  }

  var processingTime: TimeInterval? {
    if let endTime = endTime {
      return endTime - startTime
    }
    return nil
  }
}

struct VertexChunk {
  var position: SIMD3<Int>
  var vertices: [SIMD3<Float>]
  var indices: [UInt32]

  init(position: SIMD3<Int>, vertices: [SIMD3<Float>], indices: [UInt32]) {
    self.position = position
    self.vertices = vertices
    self.indices = indices
  }
}
struct VoxelChunk {
  var position: SIMD3<Int>
  var voxelData: [UInt8]

  init(position: SIMD3<Int>, voxelData: [UInt8]) {
    self.position = position
    self.voxelData = voxelData
  }
}

class VoxelGenerator {
  let device: MTLDevice
  let pipelineState: MTLComputePipelineState

  private var nextCallId = 0
  private var trackingInfo = [Int: BufferTrackingInfo]()
  private var buffersByCallId = [Int: MTLBuffer]()

  // Voxel data
  let chunkSize: SIMD3<UInt32>

  init(device: MTLDevice, chunkSize: SIMD3<UInt32>) {
    self.device = device
    self.chunkSize = chunkSize

    // Load the compute function
    guard let library = device.makeDefaultLibrary(),
      let computeFunction = library.makeFunction(name: "baseTerrain")
    else {
      fatalError("Failed to load compute function")
    }

    // Create the compute pipeline state
    do {
      pipelineState = try device.makeComputePipelineState(function: computeFunction)
    } catch {
      fatalError("Failed to create compute pipeline state: \(error)")
    }
  }

  func generateVoxels(
    commandBuffer: MTLCommandBuffer, position: SIMD3<Int>,
    completion: @escaping (Int, [UInt8]?) -> Void
  ) -> Int {
    let callId = nextCallId
    nextCallId += 1

    // Create tracking info for this call
    var info = BufferTrackingInfo(callId: callId)
    trackingInfo[callId] = info

    // Set up buffers
    var generator = GpuGenerator(size: chunkSize)
    let generatorSize = MemoryLayout<GpuGenerator>.size
    let generatorBuffer = device.makeBuffer(bytes: &generator, length: generatorSize, options: [])!

    let totalVoxels = Int(chunkSize.x * chunkSize.y * chunkSize.z)
    let chunkBuffer = device.makeBuffer(length: totalVoxels, options: .storageModeShared)!

    // Store buffer reference
    buffersByCallId[callId] = chunkBuffer

    // Set a completion handler
    commandBuffer.addCompletedHandler { [weak self] buffer in
      guard let self = self else { return }

      // Update tracking info
      var updatedInfo = self.trackingInfo[callId]!
      updatedInfo.complete()
      updatedInfo.additionalData["status"] = buffer.status.rawValue
      updatedInfo.additionalData["error"] = buffer.error?.localizedDescription ?? "None"
      self.trackingInfo[callId] = updatedInfo

      // Extract voxel data
      let bufferContents = chunkBuffer.contents()
      var voxelData = [UInt8](repeating: 0, count: totalVoxels)
      memcpy(&voxelData, bufferContents, totalVoxels)

      // Call completion handler
      DispatchQueue.main.async {
        completion(callId, voxelData)
      }
    }

    // Create a compute command encoder
    guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
      info.status = "Failed to create compute encoder"
      trackingInfo[callId] = info
      completion(callId, nil)
      return callId
    }

    // Set up compute pass
    computeEncoder.setComputePipelineState(pipelineState)
    computeEncoder.setBuffer(generatorBuffer, offset: 0, index: 0)
    computeEncoder.setBuffer(chunkBuffer, offset: 0, index: 1)

    // Calculate dispatch size
    let width = Int(chunkSize.x)
    let height = Int(chunkSize.y)
    let depth = Int(chunkSize.z)

    let threadsPerGroup = MTLSize(width: 4, height: 4, depth: 4)
    let threadgroups = MTLSize(
      width: (width + threadsPerGroup.width - 1) / threadsPerGroup.width,
      height: (height + threadsPerGroup.height - 1) / threadsPerGroup.height,
      depth: (depth + threadsPerGroup.depth - 1) / threadsPerGroup.depth
    )

    // Dispatch threads
    computeEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
    computeEncoder.endEncoding()

    // Commit the command buffer
    info.status = "Submitted"
    trackingInfo[callId] = info

    return callId
  }
}

class VertexPool {

}

class VoxelRenderer {
  let pipelineState: MTLRenderPipelineState
  init(device: MTLDevice) {
    // Initialize the renderer with the device
    // Load shaders, set up pipeline, etc.

    guard let library = device.makeDefaultLibrary(),
      let vertexFunction = library.makeFunction(name: "vertexMain"),
        let fragmentFunction = library.makeFunction(name: "fragmentMain")
    else {
      fatalError("Failed to load compute function")
    }

    let descriptor = MTLRenderPipelineDescriptor()

    descriptor.vertexFunction = vertexFunction;
    descriptor.fragmentFunction = fragmentFunction;

    // Create the compute pipeline state
    do {
      pipelineState = try device.makeRenderPipelineState(
        descriptor: descriptor)
    } catch {
      fatalError("Failed to create compute pipeline state: \(error)")
    }
  }

  func draw(commandBuffer: MTLCommandBuffer, drawable: CAMetalDrawable) {
    // Create a render pass descriptor
    let renderPassDescriptor = MTLRenderPassDescriptor()
    renderPassDescriptor.colorAttachments[0].texture = drawable.texture
    renderPassDescriptor.colorAttachments[0].loadAction = .clear
    renderPassDescriptor.colorAttachments[0].storeAction = .store
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
      red: 0, green: 0, blue: 0, alpha: 1)

    // Create a render command encoder
    guard
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {
      return
    }

    // Set the pipeline state and draw calls here
    renderEncoder.setRenderPipelineState(pipelineState)

    // End encoding
    renderEncoder.endEncoding()
  }
}

class MeshGenerator {
  let device: MTLDevice
  let pipelineState: MTLComputePipelineState

  private var nextCallId = 0
  private var trackingInfo = [Int: BufferTrackingInfo]()
  private var buffersByCallId = [Int: MTLBuffer]()

  // Voxel data
  let chunkSize: SIMD3<UInt32>

  init(device: MTLDevice, chunkSize: SIMD3<UInt32>) {
    self.device = device
    self.chunkSize = chunkSize

    // Load the compute function
    guard let library = device.makeDefaultLibrary(),
      let computeFunction = library.makeFunction(name: "generateMesh")
    else {
      fatalError("Failed to load compute function")
    }

    // Create the compute pipeline state
    do {
      pipelineState = try device.makeComputePipelineState(function: computeFunction)
    } catch {
      fatalError("Failed to create compute pipeline state: \(error)")
    }
  }

  func generateMesh(
    commandBuffer: MTLCommandBuffer,
    voxelData: [UInt8],
    position: SIMD3<Int>,
    completion: @escaping (Int, [SIMD3<Float>]?) -> Void
  ) -> Int {
    let callId = nextCallId
    nextCallId += 1

    // Create tracking info for this call
    var info = BufferTrackingInfo(callId: callId)
    trackingInfo[callId] = info

    // Set up buffers
    var mesher = GpuMesher(size: chunkSize)
    let mesherSize = MemoryLayout<GpuMesher>.size
    let mesherBuffer = device.makeBuffer(bytes: &mesher, length: mesherSize, options: [])!

    // Create voxel data buffer
    let voxelSize = voxelData.count
    let voxelBuffer = device.makeBuffer(bytes: voxelData, length: voxelSize, options: [])!

    // Create mesh info buffer
    var mesh = GpuMesh(vertexCount: 0, indexCount: 0)
    let meshInfoBuffer = device.makeBuffer(
      bytes: &mesh, length: MemoryLayout<GpuMesh>.size, options: .storageModeShared)!

    // Create vertex and index buffers (with conservative max sizes)
    // A block can have up to 3 triangles per face, 2 faces per axis, 8 corners
    let maxVertices = Int(chunkSize.x * chunkSize.y * chunkSize.z * 8)

    let vertexBuffer = device.makeBuffer(
      length: maxVertices * MemoryLayout<SIMD3<Float>>.stride, options: .storageModeShared)!

    // First compute pass to count vertices and indices
    guard let countEncoder = commandBuffer.makeComputeCommandEncoder() else {
      info.status = "Failed to create compute encoder"
      trackingInfo[callId] = info
      completion(callId, nil)
      return callId
    }

    countEncoder.setComputePipelineState(pipelineState)
    countEncoder.setBuffer(mesherBuffer, offset: 0, index: 0)
    countEncoder.setBuffer(voxelBuffer, offset: 0, index: 1)
    countEncoder.setBuffer(meshInfoBuffer, offset: 0, index: 2)
    countEncoder.setBuffer(vertexBuffer, offset: 0, index: 3)

    // Calculate dispatch size
    let width = Int(chunkSize.x)
    let height = Int(chunkSize.y)
    let depth = Int(chunkSize.z)

    let threadsPerGroup = MTLSize(width: 4, height: 4, depth: 4)
    let threadgroups = MTLSize(
      width: (width + threadsPerGroup.width - 1) / threadsPerGroup.width,
      height: (height + threadsPerGroup.height - 1) / threadsPerGroup.height,
      depth: (depth + threadsPerGroup.depth - 1) / threadsPerGroup.depth
    )

    countEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadsPerGroup)
    countEncoder.endEncoding()

    // Store buffer references for later cleanup
    buffersByCallId[callId] = vertexBuffer

    // Set a completion handler
    commandBuffer.addCompletedHandler { [weak self] buffer in
      guard let self = self else { return }

      // Update tracking info
      var updatedInfo = self.trackingInfo[callId]!
      updatedInfo.complete()
      updatedInfo.additionalData["status"] = buffer.status.rawValue
      updatedInfo.additionalData["error"] = buffer.error?.localizedDescription ?? "None"
      self.trackingInfo[callId] = updatedInfo

      // Extract mesh data
      let meshInfo = meshInfoBuffer.contents().load(as: GpuMesh.self)
      let vertexCount = Int(meshInfo.vertexCount)
      let indexCount = Int(meshInfo.indexCount)

      // Bounds check to prevent crash
      if vertexCount > maxVertices {
        DispatchQueue.main.async {
          completion(callId, nil)
        }
        return
      }

      // Extract vertex data
      let vertexPtr = vertexBuffer.contents().bindMemory(
        to: SIMD3<Float>.self, capacity: vertexCount)
      var vertices = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: vertexCount)
      for i in 0..<vertexCount {
        vertices[i] = vertexPtr[i]
      }

      // Extract index data
      // Call completion handler
      DispatchQueue.main.async {
        completion(callId, vertices)
      }
    }

    // Commit the command buffer
    info.status = "Submitted"
    trackingInfo[callId] = info

    return callId
  }
}

class Renderer: NSObject, MTKViewDelegate {
  let device: MTLDevice
  let voxelGenerator: VoxelGenerator
  let voxelRenderer: VoxelRenderer
  let meshGenerator: MeshGenerator
  let commandQueue: MTLCommandQueue
  var chunkVoxel: [SIMD3<Int>: VoxelChunk] = [SIMD3<Int>: VoxelChunk]()
  var chunkVoxelDirty: [SIMD3<Int>] = []
  var chunkVoxelGenIdMapping = [Int: SIMD3<Int>]()
  var chunkMesh: [SIMD3<Int>: VertexChunk] = [SIMD3<Int>: VertexChunk]()
  var chunkMeshDirty: [SIMD3<Int>] = []

  init(device: MTLDevice) {
    self.device = device
    self.commandQueue = device.makeCommandQueue()!

    var chunkSize = SIMD3<UInt32>(16, 16, 16)
    self.voxelGenerator = VoxelGenerator(device: device, chunkSize: chunkSize)
    self.meshGenerator = MeshGenerator(device: device, chunkSize: chunkSize)

    super.init()

    for x in 0..<10 {
      for y in 0..<10 {
        for z in 0..<10 {
          let position = SIMD3<Int>(x, y, z)
          chunkVoxelDirty.append(position)
        }
      }
    }
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
  }

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
      let renderPassDescriptor = view.currentRenderPassDescriptor
    else { return }

    // Create a command buffer
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      print("DEez")
      return
    }

    for i in 0..<[10, chunkVoxelDirty.count].min()! {
      let position = chunkVoxelDirty.popLast()!
      generateChunk(commandBuffer: commandBuffer, position: position)
    }

    for i in 0..<[10, chunkMeshDirty.count].min()! {
      let position = chunkMeshDirty.popLast()!
      let chunk = chunkVoxel[position]!
      generateMesh(commandBuffer: commandBuffer, chunk: chunk)
    }

    commandBuffer.commit()
  }

  func generateMesh(commandBuffer: MTLCommandBuffer, chunk: VoxelChunk) {
    let callId = meshGenerator.generateMesh(
      commandBuffer: commandBuffer, voxelData: chunk.voxelData, position: chunk.position
    ) { callId, vertices in
      guard let vertices = vertices else {
        print("Failed to generate mesh data for call ID \(callId)")
        return
      }
      print(vertices)
      self.chunkMesh[chunk.position] = VertexChunk(position: chunk.position, vertices: vertices)
    }

  }

  func generateChunk(commandBuffer: MTLCommandBuffer, position: SIMD3<Int>) {
    let callId = voxelGenerator.generateVoxels(commandBuffer: commandBuffer, position: position) {
      callId, voxelData in
      var position = self.chunkVoxelGenIdMapping[callId]!
      guard let voxelData = voxelData else {
        print("Failed to generate voxel data for call ID \(callId)")
        return
      }
      self.chunkVoxel[position] = VoxelChunk(position: position, voxelData: voxelData)
      self.chunkMeshDirty.append(position)
    }
    chunkVoxelGenIdMapping[callId] = position
    print("Generated chunk at \(position) with call ID \(callId)")

    // Check if the call ID is already in the dictionary
    if let existingPosition = chunkVoxelGenIdMapping[callId] {
      print("Call ID \(callId) already exists with position \(existingPosition)")
    } else {
      print("Call ID \(callId) does not exist in the dictionary.")
    }
  }
}
