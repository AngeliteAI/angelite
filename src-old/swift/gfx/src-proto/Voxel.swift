import Metal
import MetalKit
import simd

struct GpuGenerator {
  var size: SIMD3<UInt32>
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
  let queue: MTLCommandQueue

  private let lock = NSLock()  // Add thread safety
  private var nextCallId = 0
  private var trackingInfo = [Int: BufferTrackingInfo]()
  private var buffersByCallId = [Int: MTLBuffer]()

  // Voxel data
  let chunkSize: SIMD3<UInt32>

  init(device: MTLDevice, chunkSize: SIMD3<UInt32>) {
    self.device = device
    self.chunkSize = chunkSize
    self.queue = device.makeCommandQueue()!

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
    commandBuffer: MTLCommandBuffer?,
    position: SIMD3<Int>
  ) async -> (Int, [UInt8]?) {
    // Thread-safe ID generation
    let callId = lock.withLock {
      let callId = nextCallId
      nextCallId += 1

      // Create tracking info for this call
      var info = BufferTrackingInfo(callId: callId)
      trackingInfo[callId] = info
      return callId
    }

    // Create our own command buffer
    guard let localCommandBuffer = queue.makeCommandBuffer() else {
      return (callId, nil)
    }

    // Set up buffers
    var generator = GpuGenerator(size: chunkSize)
    let generatorSize = MemoryLayout<GpuGenerator>.size
    let generatorBuffer = device.makeBuffer(
      bytes: &generator, length: generatorSize, options: [])!

    let totalVoxels = Int(chunkSize.x * chunkSize.y * chunkSize.z)
    let chunkBuffer = device.makeBuffer(length: totalVoxels, options: .storageModeShared)!

    // Store buffer reference (thread-safe)
    lock.withLock {
      buffersByCallId[callId] = chunkBuffer
    }
    // Create a compute command encoder
    guard let computeEncoder = localCommandBuffer.makeComputeCommandEncoder() else {
      return (callId, nil)
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

    // Use withCheckedContinuation to bridge between callback-based API and async/await
    return await withCheckedContinuation { continuation in
      // Set a completion handler before committing
      localCommandBuffer.addCompletedHandler { [weak self] buffer in
        guard let self = self else {
          continuation.resume(returning: (callId, nil))
          return
        }

        // Thread-safe updates
        self.lock.lock()

        // Check if we still have the tracking info and buffer
        guard var updatedInfo = self.trackingInfo[callId],
          let chunkBuffer = self.buffersByCallId[callId]
        else {
          self.lock.unlock()
          continuation.resume(returning: (callId, nil))
          return
        }

        // Update tracking info
        updatedInfo.complete()
        updatedInfo.additionalData["status"] = buffer.status.rawValue
        updatedInfo.additionalData["error"] = buffer.error?.localizedDescription ?? "None"
        self.trackingInfo[callId] = updatedInfo
        self.lock.unlock()

        // Extract voxel data safely
        let bufferContents = chunkBuffer.contents()
        var voxelData = [UInt8](repeating: 0, count: totalVoxels)
        memcpy(&voxelData, bufferContents, totalVoxels)

        // Resume the continuation with the result
        continuation.resume(returning: (callId, voxelData))
      }

      // Commit the command buffer
      localCommandBuffer.commit()
    }
  }

  // Clean up resources for a call
  func cleanup(callId: Int) {
    lock.lock()
    defer { lock.unlock() }

    buffersByCallId.removeValue(forKey: callId)
    trackingInfo.removeValue(forKey: callId)
  }
}

class VoxelRenderer {
  let device: MTLDevice
  let pipelineState: MTLRenderPipelineState
  let depthStencilState: MTLDepthStencilState
  let facePool: FacePool

  // Camera position for view-dependent operations
  var cameraPosition = v3Zero()
  private let lock = NSLock()  // Add thread safety

  // For debugging
  private var frameCount = 0

  init(device: MTLDevice, faceBucketSize: Int = 64, maxBuckets: Int = 256) {
    self.device = device

    // Initialize face pool with smaller values for debugging
    self.facePool = FacePool(
      device: device, faceBucketSize: faceBucketSize, maxBuckets: maxBuckets)

    // Create render pipeline
    guard let library = device.makeDefaultLibrary() else {
      fatalError("Could not find default library")
    }

    // Check if functions exist before trying to use them
    guard let vertexFunction = library.makeFunction(name: "vertexFaceShader"),
      let fragmentFunction = library.makeFunction(name: "fragmentFaceShader")
    else {
      fatalError("Could not find required shader functions in the default library")
    }

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.label = "Face Render Pipeline"
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction

    // Set up color attachments
    pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

    // Set up depth attachment
    pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

    // Create pipeline state
    do {
      pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch {
      fatalError("Failed to create render pipeline state: \(error)")
    }

    // Create depth stencil state for proper depth testing
    let depthStencilDescriptor = MTLDepthStencilDescriptor()
    depthStencilDescriptor.depthCompareFunction = .less
    depthStencilDescriptor.isDepthWriteEnabled = true
    depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!

  }

  // Add chunk to the renderer from mesh data
  func addChunk(position: SIMD3<Int>, faceData: [Face]) -> [Int] {
    lock.lock()
    defer { lock.unlock() }

    if faceData.isEmpty {
      return []
    }

    var bucketIndices: [Int] = []
    var currentBucketIndex: Int? = nil
    var currentFaceIndex = 0

    for (i, face) in faceData.enumerated() {
      // If we don't have a bucket or the current one is full, request a new one
      if currentBucketIndex == nil || currentFaceIndex >= facePool.faceBucketSize {
        // Position for sorting (chunk center)
        let chunkCenter = v3(
          x: Float(position.x) + 0.5,
          y: Float(position.y) + 0.5,
          z: Float(position.z) + 0.5
        )

        // Debug info
        if i > 0 {
        }

        currentBucketIndex = facePool.requestBucket(
          position: chunkCenter, faceGroup: face.normal)
        if currentBucketIndex == nil {
          break
        }

        bucketIndices.append(currentBucketIndex!)
        currentFaceIndex = 0
      }

      // Add face to the current bucket
      if let bucketIndex = currentBucketIndex {
        facePool.addFace(bucketIndex: bucketIndex, faceIndex: currentFaceIndex, face: face)
        currentFaceIndex += 1
      }
    }

    return bucketIndices
  }

  // Remove a chunk from the renderer
  func removeChunk(commandIndices: [UInt32]) {
    lock.lock()
    defer { lock.unlock() }

    for index in commandIndices {
      facePool.releaseBucket(commandIndex: index)
    }
  }

  // Update camera position
  func updateCamera(position: Vec3) {
    lock.lock()
    defer { lock.unlock() }

    let oldPosition = cameraPosition
    cameraPosition = position

    if frameCount % 60 == 0 {
    }
  }

  // Draw all chunks using multi-draw-indirect
  func draw(
    commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor,
    cameraData: inout CameraData
  ) {
    frameCount += 1

    // Debug info
    if frameCount % 60 == 0 {
    }

    // Check for valid command buffer
    // Create render encoder
    guard
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(
        descriptor: renderPassDescriptor)
    else {
      return
    }

    renderEncoder.label = "Main Scene Render"

    // Set render pipeline and depth state
    renderEncoder.setRenderPipelineState(pipelineState)
    renderEncoder.setDepthStencilState(depthStencilState)

    // Set up camera uniforms
    renderEncoder.setVertexBytes(&cameraData, length: MemoryLayout<CameraData>.size, index: 1)
    renderEncoder.setFragmentBytes(&cameraData, length: MemoryLayout<CameraData>.size, index: 1)

    // Only render if we have something to draw
    let totalDrawCount = facePool.getTotalDrawCount()
    if totalDrawCount > 0 {
      if frameCount % 60 == 0 {
      }

      // Draw using the face pool
      facePool.draw(commandEncoder: renderEncoder)
    } else {
      if frameCount % 60 == 0 {
      }
    }

    // End encoding
    renderEncoder.endEncoding()
  }

  // Perform back-face culling using the vertex pool's mask function
  private func performBackFaceCulling() {
    // Determine which face groups to show based on camera position
    var visibleGroups = Set<UInt8>()

    // For a simple implementation, we show faces when looking from that direction
    // Group 0: -X, Group 1: +X, Group 2: -Y, Group 3: +Y, Group 4: -Z, Group 5: +Z
    if cameraPosition.x < 0 { visibleGroups.insert(0) } else { visibleGroups.insert(1) }
    if cameraPosition.y < 0 { visibleGroups.insert(2) } else { visibleGroups.insert(3) }
    if cameraPosition.z < 0 { visibleGroups.insert(4) } else { visibleGroups.insert(5) }

    // Mask draw commands to only include visible groups
    facePool.mask { command in
      return visibleGroups.contains(command.group)
    }
  }

  // Sort faces from front to back for optimal rendering
  private func performFrontToBackOrdering() {
    facePool.order { a, b in
      // Calculate squared distance to camera
      let distA = v3Dist(a: a.position, b: cameraPosition)
      let distB = v3Dist(a: b.position, b: cameraPosition)

      // Sort by distance (closest first)
      return distA < distB
    }
  }
}
