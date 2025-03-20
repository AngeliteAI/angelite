import Metal
import MetalKit
import simd

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
  var cameraPosition = SIMD3<Float>(0, 16, 0)
  var viewMatrix = matrix_identity_float4x4
  var projectionMatrix = matrix_identity_float4x4

  // For viewport size
  var viewportSize = CGSize(width: 1, height: 1)
  
  // Debugging
  var frameCount = 0
  var nextChunkGeneration = 0
  private var isProcessingChunk = false
// In the Renderer init method, modify the camera position:

init(device: MTLDevice) {
    print("Initializing Renderer...")
    self.device = device
    self.commandQueue = device.makeCommandQueue()!

    let chunkSize = SIMD3<UInt32>(16, 16, 16)
    self.voxelGenerator = VoxelGenerator(device: device, chunkSize: chunkSize)
    self.meshGenerator = MeshGenerator(device: device, chunkSize: chunkSize)
    self.voxelRenderer = VoxelRenderer(device: device)

    super.init()
    
    print("Renderer initialized, starting with fewer chunks for debugging")

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

    // Place camera farther back and higher to see more terrain
    cameraPosition = SIMD3<Float>(5, 20, 15)
    updateViewMatrix()
    updateProjectionMatrix(aspectRatio: 1.0)
    print("Initial camera position: \(cameraPosition)")
    
    // Print visibility info
    printVisibilityInfo()
}

// Add this helper method to the Renderer class
func printVisibilityInfo() {
    print("==== VISIBILITY DEBUG INFO ====")
    print("Camera position: \(cameraPosition)")
    
    let visibleGroups = determineVisibleGroups(cameraPos: cameraPosition)
    print("Visible face groups: \(visibleGroups.sorted())")
    
    chunksLock.lock()
    let chunkCount = _chunkVoxel.count
    let renderDataCount = _chunkRenderData.count
    chunksLock.unlock()
    
    print("Chunks loaded: \(chunkCount)")
    print("Chunks with render data: \(renderDataCount)")
    
    let drawCommands = voxelRenderer.facePool.getTotalDrawCount()
    print("Total draw commands: \(drawCommands)")
    print("==============================")
}

// Helper function to determine which face groups should be visible
func determineVisibleGroups(cameraPos: SIMD3<Float>) -> Set<UInt8> {
    var visibleGroups = Set<UInt8>()
    
    // For a simple implementation, we show faces when looking from that direction
    // Group 0: -X, Group 1: +X, Group 2: -Y, Group 3: +Y, Group 4: -Z, Group 5: +Z
    if cameraPos.x < 0 { visibleGroups.insert(0) } else { visibleGroups.insert(1) }
    if cameraPos.y < 0 { visibleGroups.insert(2) } else { visibleGroups.insert(3) }
    if cameraPos.z < 0 { visibleGroups.insert(4) } else { visibleGroups.insert(5) }
    
    return visibleGroups
}



// Modify the updateViewMatrix method to look toward terrain
private func updateViewMatrix() {
    // Look at a point in the terrain, not just the origin
    let center = SIMD3<Float>(0, 5, 0)
    let up = SIMD3<Float>(0, 1, 0)

    // Create view matrix
    viewMatrix = matrix_look_at(cameraPosition, center, up)
}
  
  // MARK: - MTKViewDelegate

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    viewportSize = size
    
    // Make sure we have a valid size
    let width = max(size.width, 1)
    let height = max(size.height, 1)
    let aspectRatio = Float(width / height)
    
    updateProjectionMatrix(aspectRatio: aspectRatio)
    print("View size changed: \(size), aspect ratio: \(aspectRatio)")
  }

 
  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable else {
      print("No drawable available")
      return
    }
    
    guard let renderPassDescriptor = view.currentRenderPassDescriptor else {
      print("No render pass descriptor available")
      return
    }

    // Set depth attachment for proper depth testing
    if view.depthStencilPixelFormat == .invalid {
      print("Setting up depth stencil pixel format")
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
      print("Failed to create command buffer")
      return
    }

    frameCount += 1

    print(frameCount);
    
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
      return chunk;
      };
      
      if let chunk = chunk {
        isProcessingChunk = true
        generateMesh(chunk: chunk)
      }
    }

    print("onto")

    // Update camera information for rendering
    updateViewMatrix()
    voxelRenderer.updateCamera(position: cameraPosition)

    // Print debug info occasionally
    if frameCount % 60 == 0 {
      print("Frame \(frameCount): Camera at \(cameraPosition)")
      printVisibilityInfo()
    }

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

  // Fix for data races in Renderer.swift

// 1. Modify generateChunk function to avoid data races
func generateChunk(position: SIMD3<Int>) {
  // Use Task.detached to avoid inheriting actor isolation
  Task.detached {
    print("Starting voxel generation for position: \(position)")
    let (callId, voxelData) = await self.voxelGenerator.generateVoxels(
      commandBuffer: nil,
      position: position
    )

    print("Voxel generation complete for position: \(position), callId: \(callId)")
    
    guard let voxelData = voxelData else {
      print("Failed to generate voxel data for position: \(position)")
      await MainActor.run {
        self.isProcessingChunk = false
      }
      return
    }
      
    // Run UI updates on MainActor
    await MainActor.run {
      self.chunksLock.withLock {
        // Store voxel data
        self._chunkVoxel[position] = VoxelChunk(position: position, voxelData: voxelData)
        // Queue mesh generation
        self._chunkMeshDirty.append(position)
      }
      
      // Clean up resources
      self.voxelGenerator.cleanup(callId: callId)
      self.isProcessingChunk = false
      print("Chunk voxel data stored for position: \(position)")
    }
  }
}

// 2. Modify generateMesh function to avoid data races
func generateMesh(chunk: VoxelChunk) {
  // Use Task.detached to avoid inheriting actor isolation
  Task.detached {
    print("Starting mesh generation for position: \(chunk.position)")
    let (callId, faces) = await self.meshGenerator.generateMesh(
      commandBuffer: nil,
      voxelData: chunk.voxelData,
      position: chunk.position
    )

    print("Mesh generation complete for position: \(chunk.position), callId: \(callId)")
    
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
        print("No faces generated for chunk at \(position)")
        self.isProcessingChunk = false
        return
      }

      print("Generated \(faces.count) faces for chunk at \(position)")
      
      // Add faces to the renderer
      let commandIndices = self.voxelRenderer.addChunk(position: position, faceData: faces)

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
  
  // MARK: - Camera Control

  func moveCamera(deltaX: Float, deltaY: Float, deltaZ: Float) {
    // Simple camera movement
    cameraPosition.x += deltaX
    cameraPosition.y += deltaY
    cameraPosition.z += deltaZ
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