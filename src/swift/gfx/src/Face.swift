import Metal
import MetalKit
import simd

struct Face {
  var position: SIMD3<UInt32>  // Base position
  var normal: UInt8  // Face direction/normal (0-5)

  init(position: SIMD3<UInt32>, normal: UInt8) {
    self.position = position
    self.normal = normal
  }
}

struct FaceChunk {
  var position: SIMD3<Int>
  var faces: [Face]

  init(position: SIMD3<Int>, faces: [Face]) {
    self.position = position
    self.faces = faces
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
  var position: SIMD3<Float>  // Position for sorting
  var group: UInt8  // Group for masking (e.g., face direction)
  var index: UnsafeMutablePointer<UInt32>?  // Pointer to track index in buffer

  init(
    indexCount: UInt32, instanceCount: UInt32, indexStart: UInt32, baseVertex: UInt32,
    baseInstance: UInt32,
    position: SIMD3<Float>, group: UInt8, index: UnsafeMutablePointer<UInt32>?
  ) {
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

class FacePool {
  private let device: MTLDevice

  // Buffers
  private var faceBuffer: MTLBuffer  // Pool of faces
  private var indirectBuffer: MTLBuffer  // Buffer of draw commands
  private var indexBuffer: MTLBuffer  // Shared index buffer

  // Pool management
   var faceBucketSize: Int  // K in the paper
  private var maxBuckets: Int  // N in the paper
  private var freeBuckets: [Int] = []  // Queue of free buckets
  private var drawCommands: [FaceDrawCommand] = []  // Buffer of draw commands

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
    let indirectBufferSize =
      maxBuckets * MemoryLayout<MTLDrawIndexedPrimitivesIndirectArguments>.stride
    self.indirectBuffer = device.makeBuffer(
      length: indirectBufferSize, options: .storageModeShared)!

    // Create shared index buffer
    // For a quad (face), we need 6 indices (2 triangles)
    // We use the same pattern for all faces, just with different offsets
    var indices: [UInt16] = []
    for i in 0..<faceBucketSize {
      let baseVertex = UInt16(i * 4)  // 4 vertices per face
      indices.append(baseVertex)
      indices.append(baseVertex + 1)
      indices.append(baseVertex + 2)
      indices.append(baseVertex)
      indices.append(baseVertex + 2)
      indices.append(baseVertex + 3)
    }
    self.indexBuffer = device.makeBuffer(
      bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride,
      options: .storageModeShared)!

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
      indexCount: UInt32(faceBucketSize * 6),  // 6 indices per face (2 triangles)
      instanceCount: 1,
      indexStart: UInt32(baseVertex * 6),  // 6 indices per face
      baseVertex: UInt32(baseVertex * 4),  // 4 vertices per face
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
