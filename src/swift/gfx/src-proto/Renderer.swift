import Metal
import MetalKit
import simd

enum Key: UInt16 {
  case w = 13
  case a = 0
  case s = 1
  case d = 2
}

// Store this with each chunk for rendering
struct ChunkRenderData {
  var position: SIMD3<Int>
  var commandIndices: [UInt32]  // Indices into the vertex pool for this chunk
}

class Renderer: NSObject, MTKViewDelegate {
  // Called whenever the drawable size of the view changes
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    viewportSize = size
    updateProjectionMatrix(aspectRatio: Float(size.width / size.height))
  }

  let device: MTLDevice
  let voxelGenerator: VoxelGenerator
  let meshGenerator: MeshGenerator
  let voxelRenderer: VoxelRenderer
  let commandQueue: MTLCommandQueue

  var keysPressed: Set<Key> = []
  var cameraSpeed: Float = 1.0

  // Chunk data with thread safety
  private let chunksLock = NSLock()
  private var _chunkVoxel: [SIMD3<Int>: VoxelChunk] = [:]
  private var _chunkVoxelDirty: [SIMD3<Int>] = []
  private var _chunkVoxelGenIdMapping = [Int: SIMD3<Int>]()
  private var _chunkRenderData: [SIMD3<Int>: ChunkRenderData] = [:]
  private var _chunkMeshDirty: [SIMD3<Int>] = []
  private var _chunkMeshGenIdMapping = [Int: SIMD3<Int>]()

  // Thread-safe accessors
  var chunkVoxel: [SIMD3<Int>: VoxelChunk] {
    get {
      chunksLock.lock()
      defer { chunksLock.unlock() }
      return _chunkVoxel
    }
    set {
      chunksLock.lock()
      _chunkVoxel = newValue
      chunksLock.unlock()
    }
  }

  var chunkVoxelDirty: [SIMD3<Int>] {
    get {
      chunksLock.lock()
      defer { chunksLock.unlock() }
      return _chunkVoxelDirty
    }
    set {
      chunksLock.lock()
      _chunkVoxelDirty = newValue
      chunksLock.unlock()
    }
  }

  var chunkMeshDirty: [SIMD3<Int>] {
    get {
      chunksLock.lock()
      defer { chunksLock.unlock() }
      return _chunkMeshDirty
    }
    set {
      chunksLock.lock()
      _chunkMeshDirty = newValue
      chunksLock.unlock()
    }
  }

  // Camera
  var cameraPosition = v3(x: 0, y: 0, z: -10)
  var pitch: Quat = qId()
  var yaw: Quat = qId()
  var t: Float = 0.0

  var rotation = qId()
  var viewMatrix = m4Id()
  var projectionMatrix = m4Id()

  // For viewport size
  var viewportSize = CGSize(width: 1, height: 1)

  // Debugging
  var frameCount = 0
  var nextChunkGeneration = 0
  private var isProcessingChunk = false
  // In the Renderer init method, modify the camera position:

  init(device: MTLDevice) {
    self.device = device
    self.commandQueue = device.makeCommandQueue()!

    let chunkSize = SIMD3<UInt32>(16, 16, 16)
    self.voxelGenerator = VoxelGenerator(device: device, chunkSize: chunkSize)
    self.meshGenerator = MeshGenerator(device: device, chunkSize: chunkSize)
    self.voxelRenderer = VoxelRenderer(device: device)

    super.init()

    // Queue up chunks in a more visible area
    chunksLock.lock()
    for x in -2...2 {
      for y in 0...3 {
        for z in -2...2 {
          let position = SIMD3<Int>(x, y, z)
          _chunkVoxelDirty.append(position)
        }
      }
    }
    chunksLock.unlock()

    updateViewMatrix()
    updateProjectionMatrix(aspectRatio: 1.0)

    // Print visibility info
  }

  // Add this helper method to the Renderer class
  func printVisibilityInfo() {
    print("==== VISIBILITY DEBUG INFO ====")
    print("Camera position: \(cameraPosition)")

    chunksLock.lock()
    let chunkCount = _chunkVoxel.count
    let renderDataCount = _chunkRenderData.count
    chunksLock.unlock()

    print("Chunks loaded: \(chunkCount)")
    print("Chunks with render data: \(renderDataCount)")

    print(projectionMatrix)
    print(viewMatrix)

    let drawCommands = voxelRenderer.facePool.getTotalDrawCount()
    print("Total draw commands: \(drawCommands)")
    print("==============================")
  }

  func rotateCamera(deltaX: Float, deltaY: Float, deltaTime: Float) {
    let sens: Float = 1000
    let z = qRotY(angle: sens * deltaX * deltaTime)
    let x = qRotX(angle: sens * deltaY * deltaTime)
    yaw = qMul(a: yaw, b: x)
    pitch = qMul(a: pitch, b: qMul(a: x, b: z))
    updateViewMatrix()
  }

  func moveCamera(deltaTime: Float) {
    // Calculate movement based on pressed keys
    var movement = v3Zero()

    if keysPressed.contains(.w) {
      movement.z += 1
    }
    if keysPressed.contains(.s) {
      movement.z -= 1
    }
    if keysPressed.contains(.a) {
      movement.x -= 1
    }
    if keysPressed.contains(.d) {
      movement.x += 1
    }

    // Normalize movement vector, so diagonal movement isn't faster
    if v3Len(v: movement) > 0.001 {
      movement = v3Norm(v: movement)
    }

    // Rotate movement vector by camera's yaw
    let rotationMatrix = qToM4(q: qMul(a: yaw, b: pitch))
    let rotatedMovement = m4V4(m: rotationMatrix, v: v4FromV3(v: movement, w: 1.0))

    cameraPosition = v3Add(
      a: cameraPosition,
      b: v3Mul(
        a: v3FromV4(v: rotatedMovement),

        b: v3(
          x: cameraSpeed * deltaTime, y: cameraSpeed * deltaTime,
          z: cameraSpeed * deltaTime)))  // Scale by time and speed
    updateViewMatrix()
  }

  // Helper function to determine which face groups should be visible

  // Modify the updateViewMatrix method to look toward terrain
  private func updateViewMatrix() {
    // Combine yaw and pitch into a single rotation quaternion

    rotation = qMul(a: yaw, b: pitch)

    viewMatrix = m4Inv(m: m4Mul(a: m4TransV3(v: cameraPosition), b: qToM4(q: rotation)))
  }
  func draw(in view: MTKView) {
    let deltaTime = 1.0 / Float(view.preferredFramesPerSecond)
    t += 0.01 * deltaTime
    moveCamera(deltaTime: deltaTime)

    guard let drawable = view.currentDrawable else {
      return
    }

    guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
      return
    }

    // Set depth attachment for proper depth testing
    if view.depthStencilPixelFormat == .invalid {
      view.depthStencilPixelFormat = .depth32Float
      let depthTexDesc = MTLTextureDescriptor.texture2DDescriptor(
        pixelFormat: .depth32Float,
        width: Int(viewportSize.width),
        height: Int(viewportSize.height),
        mipmapped: false
      )
      depthTexDesc.usage = [.renderTarget]
      depthTexDesc.storageMode = .private
      let depthTexture = device.makeTexture(descriptor: depthTexDesc)
      if depthTexture != nil {
        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .dontCare
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
      }
    }

    // Create command buffer
    guard let commandBuffer = commandQueue.makeCommandBuffer() else {
      return
    }

    frameCount += 1

    // Process chunk generation queue - only process 1 chunk each 10 frames
    if frameCount % 10 == 0 && !isProcessingChunk && nextChunkGeneration < chunkVoxelDirty.count {
      let position = chunkVoxelDirty[nextChunkGeneration]
      isProcessingChunk = true
      generateChunk(position: position)
      nextChunkGeneration += 1
    }

    // Generate meshes occasionally
    if frameCount % 16 == 0 && !isProcessingChunk && !chunkMeshDirty.isEmpty {
      var chunk = chunksLock.withLock {
        let position = _chunkMeshDirty.last!
        let chunk = _chunkVoxel[position]
        _chunkMeshDirty.removeLast()
        return chunk
      }

      if let chunk = chunk {
        isProcessingChunk = true
        generateMesh(chunk: chunk)
      }
    }

    // Update camera information for rendering
    updateViewMatrix()
    voxelRenderer.updateCamera(position: cameraPosition)

    if frameCount % 60 == 0 {
    }

    var cameraData = CameraData(
      viewProjection: m4Mul(a: projectionMatrix, b: viewMatrix)
    )

    // Draw chunks
    voxelRenderer.draw(
      commandBuffer: commandBuffer,
      renderPassDescriptor: renderPassDescriptor,
      cameraData: &cameraData
    )

    // Present and commit
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  // MARK: - Chunk Generation

  // Fix for data races in Renderer.swift

  // 1. Modify generateChunk function to avoid data races
  func generateChunk(position: SIMD3<Int>) {
    // Use Task.detached to avoid inheriting actor isolation
    Task.detached {
      let (callId, voxelData) = await self.voxelGenerator.generateVoxels(
        commandBuffer: nil,
        position: position
      )

      guard let voxelData = voxelData else {
        await MainActor.run {
          self.isProcessingChunk = false
        }
        return
      }

      // Run UI updates on MainActor
      await MainActor.run {
        self.chunksLock.withLock {
          // Store voxel data
          self._chunkVoxel[position] = VoxelChunk(
            position: position, voxelData: voxelData)
          // Queue mesh generation
          self._chunkMeshDirty.append(position)
        }

        // Clean up resources
        self.voxelGenerator.cleanup(callId: callId)
        self.isProcessingChunk = false
      }
    }
  }

  // 2. Modify generateMesh function to avoid data races
  func generateMesh(chunk: VoxelChunk) {
    // Use Task.detached to avoid inheriting actor isolation
    Task.detached {
      let (callId, faces) = await self.meshGenerator.generateMesh(
        commandBuffer: nil,
        voxelData: chunk.voxelData,
        position: chunk.position
      )

      let position = chunk.position

      // Process results on MainActor to avoid data races
      await MainActor.run {
        self.chunksLock.withLock {
          // Clean up old mesh if it exists
          if let oldRenderData = self._chunkRenderData[position] {
            for index in oldRenderData.commandIndices {
              self.voxelRenderer.facePool.releaseBucket(commandIndex: index)
            }
          }
        }

        guard let faces = faces, !faces.isEmpty else {
          self.isProcessingChunk = false
          return
        }

        // Add faces to the renderer
        let commandIndices = self.voxelRenderer.addChunk(
          position: position, faceData: faces)

        // Save render data for this chunk
        self.chunksLock.withLock {
          self._chunkRenderData[position] = ChunkRenderData(
            position: position,
            commandIndices: commandIndices.map { UInt32($0) }
          )
        }

        // Clean up resources
        self.meshGenerator.cleanup(callId: callId)
        self.isProcessingChunk = false
      }
    }
  }

  private func updateProjectionMatrix(aspectRatio: Float) {
    // Create perspective projection matrix
    let fov = 65.0 * (Float.pi / 180.0)
    let near: Float = 0.1
    let far: Float = 1000.0

    projectionMatrix = m4Persp(fovy: fov, aspect: aspectRatio, near: near, far: far)
  }
}

public struct CameraData {
  var viewProjection: Mat4
}
