import Metal
import MetalKit
import simd

// Based on the vertex pooling technique from the paper
// This is an adaptation for face-based rendering rather than vertex-based

// Each face is represented compactly

// Struct to track buffer processing information

// Store this with each chunk for rendering
struct ChunkRenderData {
  var position: SIMD3<Int>
  var commandIndices: [UInt32]  // Indices into the vertex pool for this chunk
}

class Renderer: NSObject, MTKViewDelegate {
  let device: MTLDevice
  let voxelGenerator: VoxelGenerator
  let meshGenerator: MeshGenerator
  let voxelRenderer: VoxelRenderer
  let commandQueue: MTLCommandQueue

  // Chunk data
  var chunkVoxel: [SIMD3<Int>: VoxelChunk] = [:]
  var chunkVoxelDirty: [SIMD3<Int>] = []
  var chunkVoxelGenIdMapping = [Int: SIMD3<Int>]()
  var chunkRenderData: [SIMD3<Int>: ChunkRenderData] = [:]
  var chunkMeshDirty: [SIMD3<Int>] = []
  var chunkMeshGenIdMapping = [Int: SIMD3<Int>]()

  // Camera
  var cameraPosition = SIMD3<Float>(0, 16, 0)
  var viewMatrix = matrix_identity_float4x4
  var projectionMatrix = matrix_identity_float4x4

  // For viewport size
  var viewportSize = CGSize(width: 1, height: 1)

  init(device: MTLDevice) {
    self.device = device
    self.commandQueue = device.makeCommandQueue()!

    let chunkSize = SIMD3<UInt32>(16, 16, 16)
    self.voxelGenerator = VoxelGenerator(device: device, chunkSize: chunkSize)
    self.meshGenerator = MeshGenerator(device: device, chunkSize: chunkSize)
    self.voxelRenderer = VoxelRenderer(device: device)

    super.init()

    // Queue up chunks to generate around origin
    for x in -5...5 {
      for y in 0...10 {
        for z in -5...5 {
          let position = SIMD3<Int>(x, y, z)
          chunkVoxelDirty.append(position)
        }
      }
    }

    updateViewMatrix()
    updateProjectionMatrix(aspectRatio: 1.0)
  }

  // MARK: - MTKViewDelegate

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    viewportSize = size
    let aspectRatio = Float(size.width / size.height)
    updateProjectionMatrix(aspectRatio: aspectRatio)
  }

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
      let renderPassDescriptor = view.currentRenderPassDescriptor
    else { return }

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
      let depthTexture = device.makeTexture(descriptor: depthTexDesc)!
      renderPassDescriptor.depthAttachment.texture = depthTexture
      renderPassDescriptor.depthAttachment.loadAction = .clear
      renderPassDescriptor.depthAttachment.storeAction = .dontCare
      renderPassDescriptor.depthAttachment.clearDepth = 1.0
    }

    // Create command buffer
    guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

    // Process chunk generation queue
    let maxChunksPerFrame = 10

    // Generate voxel data
    for _ in 0..<min(maxChunksPerFrame, chunkVoxelDirty.count) {
      let position = chunkVoxelDirty.removeLast()
      generateChunk(commandBuffer: commandBuffer, position: position)
    }

    // Generate meshes
    for _ in 0..<min(maxChunksPerFrame, chunkMeshDirty.count) {
      let position = chunkMeshDirty.removeLast()
      if let chunk = chunkVoxel[position] {
        generateMesh(commandBuffer: commandBuffer, chunk: chunk)
      }
    }

    // Update camera information for rendering
    updateViewMatrix()
    voxelRenderer.updateCamera(position: cameraPosition)

    // Create camera data for shaders
    var cameraData = CameraData(
      position: cameraPosition,
      viewProjection: projectionMatrix * viewMatrix
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

  func generateChunk(commandBuffer: MTLCommandBuffer, position: SIMD3<Int>) {
    Task {
      let (callId, voxelData) = await voxelGenerator.generateVoxels(
        commandBuffer: commandBuffer,
        position: position
      )

      // Store the mapping
      self.chunkVoxelGenIdMapping[callId] = position

      // Process the results on the main thread
      await MainActor.run {
        guard let voxelData = voxelData,
          let position = self.chunkVoxelGenIdMapping.removeValue(forKey: callId)
        else {
          print("Failed to generate voxel data for call ID \(callId)")
          return
        }

        // Store voxel data
        self.chunkVoxel[position] = VoxelChunk(position: position, voxelData: voxelData)

        // Queue mesh generation
        self.chunkMeshDirty.append(position)
      }
    }
  }
  func generateMesh(commandBuffer: MTLCommandBuffer, chunk: VoxelChunk) {
    // Create a Task to handle the async mesh generation
    Task {
      let (callId, faces) = await meshGenerator.generateMesh(
        commandBuffer: commandBuffer,
        voxelData: chunk.voxelData,
        position: chunk.position
      )

      // Store the mapping
      self.chunkMeshGenIdMapping[callId] = chunk.position

      // Process the results on the main thread
      await MainActor.run {
        guard let position = self.chunkMeshGenIdMapping.removeValue(forKey: callId) else { return }

        // Clean up old mesh if it exists
        if let oldRenderData = self.chunkRenderData[position] {
          for index in oldRenderData.commandIndices {
            self.voxelRenderer.facePool.releaseBucket(commandIndex: index)
          }
        }

        guard let faces = faces, !faces.isEmpty else {
          // If there are no faces, we can skip adding to the renderer
          return
        }

        // Add faces to the renderer
        let commandIndices = self.voxelRenderer.addChunk(position: position, faceData: faces)

        // Save render data for this chunk
        let renderData = ChunkRenderData(
          position: position, commandIndices: commandIndices.map { UInt32($0) })
        self.chunkRenderData[position] = renderData
      }
    }
  }
  // MARK: - Camera Control

  func moveCamera(deltaX: Float, deltaY: Float, deltaZ: Float) {
    // Simple camera movement
    cameraPosition.x += deltaX
    cameraPosition.y += deltaY
    cameraPosition.z += deltaZ
  }

  private func updateViewMatrix() {
    // Look at the center of the world
    let center = SIMD3<Float>(0, 0, 0)
    let up = SIMD3<Float>(0, 1, 0)

    // Create view matrix
    viewMatrix = matrix_look_at(cameraPosition, center, up)
  }

  private func updateProjectionMatrix(aspectRatio: Float) {
    // Create perspective projection matrix
    let fov = 65.0 * (Float.pi / 180.0)
    let near: Float = 0.1
    let far: Float = 1000.0

    projectionMatrix = matrix_perspective_right_hand(fov, aspectRatio, near, far)
  }
}

// MARK: - Camera Data Structure

struct CameraData {
  var position: SIMD3<Float>
  var viewProjection: float4x4
}

// MARK: - Matrix Utility Functions

// Create a perspective projection matrix
func matrix_perspective_right_hand(
  _ fovyRadians: Float,
  _ aspect: Float,
  _ nearZ: Float,
  _ farZ: Float
) -> float4x4 {
  let ys = 1 / tanf(fovyRadians * 0.5)
  let xs = ys / aspect
  let zs = farZ / (nearZ - farZ)

  return float4x4(
    SIMD4<Float>(xs, 0, 0, 0),
    SIMD4<Float>(0, ys, 0, 0),
    SIMD4<Float>(0, 0, zs, -1),
    SIMD4<Float>(0, 0, zs * nearZ, 0)
  )
}

// Create a look-at matrix
func matrix_look_at(
  _ eye: SIMD3<Float>,
  _ center: SIMD3<Float>,
  _ up: SIMD3<Float>
) -> float4x4 {
  let z = normalize(eye - center)
  let x = normalize(cross(up, z))
  let y = normalize(cross(z, x))

  let t = SIMD3<Float>(
    -dot(x, eye),
    -dot(y, eye),
    -dot(z, eye)
  )

  return float4x4(
    SIMD4<Float>(x.x, y.x, z.x, 0),
    SIMD4<Float>(x.y, y.y, z.y, 0),
    SIMD4<Float>(x.z, y.z, z.z, 0),
    SIMD4<Float>(t.x, t.y, t.z, 1)
  )
}
