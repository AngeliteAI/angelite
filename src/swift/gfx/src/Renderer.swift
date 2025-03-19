import Metal
import MetalKit
import simd

// Based on the vertex pooling technique from the paper
// This is an adaptation for face-based rendering rather than vertex-based

// Each face is represented compactly
struct Face {
    var position: SIMD3<UInt32> // Base position
    var normal: UInt8 // Face direction/normal (0-5)
    
    init(position: SIMD3<UInt32>, normal: UInt8) {
        self.position = position
        self.normal = normal
    }
}

// Draw indirect command (DAIC from the paper)
struct FaceDrawCommand {
    // Standard Metal indirect command values
    var indexCount: UInt32
    var instanceCount: UInt32
    var indexStart: UInt32
    var baseVertex: UInt32
    var baseInstance: UInt32
    
    // Additional metadata for sorting/masking (as in the paper)
    var position: SIMD3<Float> // Position for sorting
    var group: UInt8 // Group for masking (e.g., face direction)
    var index: UnsafeMutablePointer<UInt32>? // Pointer to track index in buffer
    
    init(indexCount: UInt32, instanceCount: UInt32, indexStart: UInt32, baseVertex: UInt32, baseInstance: UInt32, 
         position: SIMD3<Float>, group: UInt8, index: UnsafeMutablePointer<UInt32>?) {
        self.indexCount = indexCount
        self.instanceCount = instanceCount
        self.indexStart = indexStart
        self.baseVertex = baseVertex
        self.baseInstance = baseInstance
        self.position = position
        self.group = group
        self.index = index
    }
}

class VertexPool {
    private let device: MTLDevice
    
    // Buffers
    private var faceBuffer: MTLBuffer // Pool of faces
    private var indirectBuffer: MTLBuffer // Buffer of draw commands
    private var indexBuffer: MTLBuffer // Shared index buffer
    
    // Pool management
    private var faceBucketSize: Int // K in the paper
    private var maxBuckets: Int // N in the paper
    private var freeBuckets: [Int] = [] // Queue of free buckets
    private var drawCommands: [FaceDrawCommand] = [] // Buffer of draw commands
    
    // Effective draw count (for masking)
    private var effectiveDrawCount: Int = 0
    
    init(device: MTLDevice, faceBucketSize: Int, maxBuckets: Int) {
        self.device = device
        self.faceBucketSize = faceBucketSize
        self.maxBuckets = maxBuckets
        
        // Create face buffer pool
        let faceBufferSize = faceBucketSize * maxBuckets * MemoryLayout<Face>.stride
        self.faceBuffer = device.makeBuffer(length: faceBufferSize, options: .storageModeShared)!
        
        // Create indirect command buffer
        let indirectBufferSize = maxBuckets * MemoryLayout<MTLDrawIndexedPrimitivesIndirectArguments>.stride
        self.indirectBuffer = device.makeBuffer(length: indirectBufferSize, options: .storageModeShared)!
        
        // Create shared index buffer
        // For a quad (face), we need 6 indices (2 triangles)
        // We use the same pattern for all faces, just with different offsets
        var indices: [UInt16] = []
        for i in 0..<faceBucketSize {
            let baseVertex = UInt16(i * 4) // 4 vertices per face
            indices.append(baseVertex)
            indices.append(baseVertex + 1)
            indices.append(baseVertex + 2)
            indices.append(baseVertex)
            indices.append(baseVertex + 2)
            indices.append(baseVertex + 3)
        }
        self.indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: .storageModeShared)!
        
        // Initialize free buckets
        for i in 0..<maxBuckets {
            freeBuckets.append(i)
        }
    }

    func _faceBucketSize() -> Int {
        return faceBucketSize
    }
    
    // Request a bucket for faces
    func requestBucket(position: SIMD3<Float>, faceGroup: UInt8) -> Int? {
        guard !freeBuckets.isEmpty else { return nil }
        
        let bucketIndex = freeBuckets.removeLast()
        let baseVertex = bucketIndex * faceBucketSize
        
        // Create index for tracking this command's position
        let index = UnsafeMutablePointer<UInt32>.allocate(capacity: 1)
        index.pointee = UInt32(drawCommands.count)
        
        // Create draw command
        let command = FaceDrawCommand(
            indexCount: UInt32(faceBucketSize * 6), // 6 indices per face (2 triangles)
            instanceCount: 1,
            indexStart: UInt32(baseVertex * 6), // 6 indices per face
            baseVertex: UInt32(baseVertex * 4), // 4 vertices per face
            baseInstance: 0,
            position: position,
            group: faceGroup,
            index: index
        )
        
        drawCommands.append(command)
        return bucketIndex
    }
    
    // Add a face to a bucket
    func addFace(bucketIndex: Int, faceIndex: Int, face: Face) {
        guard bucketIndex < maxBuckets && faceIndex < faceBucketSize else { return }
        
        let offset = (bucketIndex * faceBucketSize + faceIndex) * MemoryLayout<Face>.stride
        let facesPtr = faceBuffer.contents().advanced(by: offset).bindMemory(to: Face.self, capacity: 1)
        facesPtr.pointee = face
    }
    
    // Release a bucket
    func releaseBucket(commandIndex: UInt32) {
        guard commandIndex < drawCommands.count else { return }
        
        let bucketIndex = Int(drawCommands[Int(commandIndex)].baseVertex) / (faceBucketSize * 4)
        freeBuckets.append(bucketIndex)
        
        // Swap with last command and update indices
        let lastIndex = drawCommands.count - 1
        if commandIndex != lastIndex {
            drawCommands[Int(commandIndex)] = drawCommands[lastIndex]
            if let indexPtr = drawCommands[Int(commandIndex)].index {
                indexPtr.pointee = commandIndex
            }
        }
        
        // Free the index pointer
        drawCommands[lastIndex].index?.deallocate()
        
        drawCommands.removeLast()
        if effectiveDrawCount > drawCommands.count {
            effectiveDrawCount = drawCommands.count
        }
    }
    
    // Mask draw commands based on a predicate function
    func mask(_ predicate: (FaceDrawCommand) -> Bool) {
        var frontIndex = 0
        var backIndex = drawCommands.count - 1
        
        while frontIndex <= backIndex {
            // Find a command at the front that doesn't match the predicate
            while frontIndex < backIndex && predicate(drawCommands[frontIndex]) {
                frontIndex += 1
            }
            
            // Find a command at the back that matches the predicate
            while frontIndex < backIndex && !predicate(drawCommands[backIndex]) {
                backIndex -= 1
            }
            
            // Swap if needed and update indices
            if frontIndex < backIndex {
                drawCommands.swapAt(frontIndex, backIndex)
                
                // Update the indices in the pointers
                if let frontPtr = drawCommands[frontIndex].index {
                    frontPtr.pointee = UInt32(frontIndex)
                }
                if let backPtr = drawCommands[backIndex].index {
                    backPtr.pointee = UInt32(backIndex)
                }
                
                frontIndex += 1
                backIndex -= 1
            }
        }
        
        effectiveDrawCount = frontIndex
    }
    
    // Order the masked portion of draw commands
    func order(_ comparator: (FaceDrawCommand, FaceDrawCommand) -> Bool) {
        // Sort only the effective (masked) portion
        let sortedPortion = drawCommands[0..<effectiveDrawCount].sorted(by: comparator)
        for i in 0..<effectiveDrawCount {
            drawCommands[i] = sortedPortion[i]
            // Update indices
            if let indexPtr = drawCommands[i].index {
                indexPtr.pointee = UInt32(i)
            }
        }
    }
    
    // Update the indirect buffer with the current draw commands
    func updateIndirectBuffer() {
        let commandsPtr = indirectBuffer.contents().bindMemory(
            to: MTLDrawIndexedPrimitivesIndirectArguments.self, 
            capacity: drawCommands.count
        )
        
        for i in 0..<drawCommands.count {
            let cmd = drawCommands[i]
            commandsPtr[i] = MTLDrawIndexedPrimitivesIndirectArguments(
                indexCount: cmd.indexCount,
                instanceCount: cmd.instanceCount,
                indexStart: cmd.indexStart,
                baseVertex: Int32(cmd.baseVertex),
                baseInstance: cmd.baseInstance
            )
        }
    }
    
    // Draw using the pool
    func draw(commandEncoder: MTLRenderCommandEncoder, maskAndSort: Bool = true) {
        // Update indirect buffer before drawing
        updateIndirectBuffer()
        
        // Set vertex and index buffers
        commandEncoder.setVertexBuffer(faceBuffer, offset: 0, index: 0)
        commandEncoder.setFragmentBuffer(faceBuffer, offset: 0, index: 0)
        
        // Draw the faces with multi-draw-indirect
        commandEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0,
            indirectBuffer: indirectBuffer,
            indirectBufferOffset: 0
        )
    }
    
    // Get resources
    func getFaceBuffer() -> MTLBuffer { return faceBuffer }
    func getIndexBuffer() -> MTLBuffer { return indexBuffer }
    func getIndirectBuffer() -> MTLBuffer { return indirectBuffer }
    func getDrawCount() -> Int { return effectiveDrawCount }
    func getTotalDrawCount() -> Int { return drawCommands.count }
}

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

  init(position: SIMD3<Int>, vertices: [SIMD3<Float>]) {
    self.position = position
    self.vertices = vertices
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
import Metal
import simd

class VoxelRenderer {
    let device: MTLDevice
    let pipelineState: MTLRenderPipelineState
    let depthStencilState: MTLDepthStencilState
    let vertexPool: VertexPool
    
    // Camera position for view-dependent operations
    var cameraPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    
    init(device: MTLDevice, faceBucketSize: Int = 256, maxBuckets: Int = 1024) {
        self.device = device
        
        // Initialize vertex pool
        self.vertexPool = VertexPool(device: device, faceBucketSize: faceBucketSize, maxBuckets: maxBuckets)
        
        // Create render pipeline
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertexFaceShader")!
        let fragmentFunction = library.makeFunction(name: "fragmentFaceShader")!
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
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
        var bucketIndices: [Int] = []
        var currentBucketIndex: Int? = nil
        var currentFaceIndex = 0
        
        for face in faceData {
            // If we don't have a bucket or the current one is full, request a new one
            if currentBucketIndex == nil || currentFaceIndex >= vertexPool._faceBucketSize() {
                // Position for sorting (chunk center)
                let chunkCenter = SIMD3<Float>(
                    Float(position.x) + 0.5,
                    Float(position.y) + 0.5,
                    Float(position.z) + 0.5
                )
                
                currentBucketIndex = vertexPool.requestBucket(position: chunkCenter, faceGroup: face.normal)
                if currentBucketIndex == nil {
                    print("Failed to allocate new bucket for chunk at \(position)")
                    break
                }
                
                bucketIndices.append(currentBucketIndex!)
                currentFaceIndex = 0
            }
            
            // Add face to the current bucket
            vertexPool.addFace(bucketIndex: currentBucketIndex!, faceIndex: currentFaceIndex, face: face)
            currentFaceIndex += 1
        }
        
        return bucketIndices
    }
    
    // Remove a chunk from the renderer
    func removeChunk(commandIndices: [UInt32]) {
        for index in commandIndices {
            vertexPool.releaseBucket(commandIndex: index)
        }
    }
    
    // Update camera position
    func updateCamera(position: SIMD3<Float>) {
        cameraPosition = position
    }
    
    // Draw all chunks using multi-draw-indirect
    func draw(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        // Create render encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Set render pipeline and depth state
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // Set up camera uniforms
        var cameraPos = cameraPosition
        renderEncoder.setVertexBytes(&cameraPos, length: MemoryLayout<SIMD3<Float>>.size, index: 1)
        
        // Perform true back-face culling with masking
        performBackFaceCulling()
        
        // Perform front-to-back ordering for optimal z-buffer usage
        performFrontToBackOrdering()
        
        // Draw using the vertex pool
        vertexPool.draw(commandEncoder: renderEncoder)
        
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
        vertexPool.mask { command in
            return visibleGroups.contains(command.group)
        }
    }
    
    // Sort faces from front to back for optimal rendering
    private func performFrontToBackOrdering() {
        vertexPool.order { a, b in
            // Calculate squared distance to camera
            let distA = distance_squared(a.position, cameraPosition)
            let distB = distance_squared(b.position, cameraPosition)
            
            // Sort by distance (closest first)
            return distA < distB
        }
    }
}

class MeshGenerator {
    let device: MTLDevice
    let pipelineState: MTLComputePipelineState

    private var nextCallId = 0
    private var trackingInfo = [Int: BufferTrackingInfo]()
    private var buffersByCallId = [Int: (faceBuffer: MTLBuffer, countBuffer: MTLBuffer)]()

    // Voxel data
    let chunkSize: SIMD3<UInt32>

    init(device: MTLDevice, chunkSize: SIMD3<UInt32>) {
        self.device = device
        self.chunkSize = chunkSize

        // Load the compute function
        guard let library = device.makeDefaultLibrary(),
            let computeFunction = library.makeFunction(name: "generateMesh")
        else {
            fatalError("Failed to load mesh generation compute function")
        }

        // Create the compute pipeline state
        do {
            pipelineState = try device.makeComputePipelineState(function: computeFunction)
        } catch {
            fatalError("Failed to create mesh compute pipeline state: \(error)")
        }
    }

    func generateMesh(
        commandBuffer: MTLCommandBuffer,
        voxelData: [UInt8],
        position: SIMD3<Int>,
        completion: @escaping (Int, [Face]?) -> Void
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

        // Create face count buffer (atomic counter)
        var initialCount: UInt32 = 0
        let countBuffer = device.makeBuffer(
            bytes: &initialCount, length: MemoryLayout<UInt32>.size, options: .storageModeShared)!

        // Create face buffer (with a conservative max size - worst case is one face per voxel per direction)
        // In practice, only the visible faces on the surface are generated
        let totalVoxels = Int(chunkSize.x * chunkSize.y * chunkSize.z)
        let maxFaces = totalVoxels * 6 // 6 faces per voxel (worst case)
        let faceBuffer = device.makeBuffer(
            length: maxFaces * MemoryLayout<Face>.stride, options: .storageModeShared)!

        // Store buffer references for later cleanup
        buffersByCallId[callId] = (faceBuffer, countBuffer)

        // Create a compute command encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            info.status = "Failed to create compute encoder"
            trackingInfo[callId] = info
            completion(callId, nil)
            return callId
        }

        // Set up compute pass
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setBuffer(mesherBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(voxelBuffer, offset: 0, index: 1)
        computeEncoder.setBuffer(countBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(faceBuffer, offset: 0, index: 3)

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

        // Set a completion handler
        commandBuffer.addCompletedHandler { [weak self] buffer in
            guard let self = self else { return }

            // Update tracking info
            var updatedInfo = self.trackingInfo[callId]!
            updatedInfo.complete()
            updatedInfo.additionalData["status"] = buffer.status.rawValue
            updatedInfo.additionalData["error"] = buffer.error?.localizedDescription ?? "None"
            self.trackingInfo[callId] = updatedInfo

            // Extract face data
            let faceCount = countBuffer.contents().load(as: UInt32.self)
            
            // Sanity check
            if faceCount > UInt32(maxFaces) {
                print("Warning: Generated more faces than expected: \(faceCount) > \(maxFaces)")
                DispatchQueue.main.async {
                    completion(callId, nil)
                }
                return
            }

            // Extract faces
            let facePtr = faceBuffer.contents().bindMemory(to: Face.self, capacity: Int(faceCount))
            var faces = [Face]()
            for i in 0..<Int(faceCount) {
                faces.append(facePtr[i])
            }

            // Call completion handler
            DispatchQueue.main.async {
                completion(callId, faces)
            }
        }

        // Update tracking info
        info.status = "Submitted"
        trackingInfo[callId] = info

        return callId
    }

    // Clean up resources for a call
    func cleanup(callId: Int) {
        buffersByCallId.removeValue(forKey: callId)
        trackingInfo.removeValue(forKey: callId)
    }
}

import MetalKit
import simd

// Store this with each chunk for rendering
struct ChunkRenderData {
    var position: SIMD3<Int>
    var commandIndices: [UInt32] // Indices into the vertex pool for this chunk
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
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
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
        let callId = voxelGenerator.generateVoxels(commandBuffer: commandBuffer, position: position) { [weak self] callId, voxelData in
            guard let self = self else { return }
            guard let voxelData = voxelData, let position = self.chunkVoxelGenIdMapping.removeValue(forKey: callId) else {
                print("Failed to generate voxel data for call ID \(callId)")
                return
            }
            
            // Store voxel data
            self.chunkVoxel[position] = VoxelChunk(position: position, voxelData: voxelData)
            
            // Queue mesh generation
            self.chunkMeshDirty.append(position)
        }
        
        chunkVoxelGenIdMapping[callId] = position
    }
    
    func generateMesh(commandBuffer: MTLCommandBuffer, chunk: VoxelChunk) {
        let callId = meshGenerator.generateMesh(
            commandBuffer: commandBuffer,
            voxelData: chunk.voxelData,
            position: chunk.position
        ) { [weak self] callId, faces in
            guard let self = self, let position = self.chunkMeshGenIdMapping.removeValue(forKey: callId) else { return }
            
            // Clean up old mesh if it exists
            if let oldRenderData = self.chunkRenderData[position] {
                for index in oldRenderData.commandIndices {
                    self.voxelRenderer.vertexPool.releaseBucket(commandIndex: index)
                }
            }
            
            guard let faces = faces, !faces.isEmpty else {
                // If there are no faces, we can skip adding to the renderer
                return
            }
            
            // Add faces to the renderer
            let commandIndices = self.voxelRenderer.addChunk(position: position, faces: faces)
            
            // Save render data for this chunk
            let renderData = ChunkRenderData(position: position, commandIndices: commandIndices.map { UInt32($0) })
            self.chunkRenderData[position] = renderData
        }
        
        chunkMeshGenIdMapping[callId] = chunk.position
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
