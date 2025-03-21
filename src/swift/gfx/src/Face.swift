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
// Replace the FaceDrawCommand struct with this more robust version:

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
  var indexPointer: UInt64 = 0  // Store pointer as integer value instead
  
  init(
    indexCount: UInt32, instanceCount: UInt32, indexStart: UInt32, baseVertex: UInt32,
    baseInstance: UInt32,
    position: SIMD3<Float>, group: UInt8, index: UInt32
  ) {
    self.indexCount = indexCount
    self.instanceCount = instanceCount
    self.indexStart = indexStart
    self.baseVertex = baseVertex
    self.baseInstance = baseInstance
    self.position = position
    self.group = group
    self.indexPointer = 0  // Don't store pointer directly
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
  private var commandIndices: [UInt32] = []  // Simple array of command indices instead of pointers

  // Effective draw count (for masking)
  private var effectiveDrawCount: Int = 0
  private let lock = NSLock() // Add thread safety

  // Add this to the FacePool initialization
init(device: MTLDevice, faceBucketSize: Int, maxBuckets: Int) {
    print("Initializing FacePool: bucket size \(faceBucketSize), max buckets \(maxBuckets)")
    self.device = device
    self.faceBucketSize = faceBucketSize
    self.maxBuckets = maxBuckets

    // Create face buffer pool
    let faceBufferSize = faceBucketSize * maxBuckets * MemoryLayout<Face>.stride
    print("Creating face buffer with size: \(faceBufferSize) bytes")
    self.faceBuffer = device.makeBuffer(length: faceBufferSize, options: .storageModeShared)!

    // Create indirect command buffer
    let indirectBufferSize =
      maxBuckets * MemoryLayout<MTLDrawIndexedPrimitivesIndirectArguments>.stride
    print("Creating indirect buffer with size: \(indirectBufferSize) bytes")
    self.indirectBuffer = device.makeBuffer(
      length: indirectBufferSize, options: .storageModeShared)!

    // Create shared index buffer - THIS IS THE FIXED PART
    // Instead of creating unique indices for each face, 
    // we'll create one set of indices for a single quad and reuse it
    // Each face is a quad made of 2 triangles (6 indices total)
    var indices: [UInt16] = [
        0, 1, 2,  // First triangle
        0, 2, 3   // Second triangle
    ]
    
    let indexBufferSize = indices.count * MemoryLayout<UInt16>.stride
    print("Creating index buffer with \(indices.count) indices, size: \(indexBufferSize) bytes")
    self.indexBuffer = device.makeBuffer(
      bytes: indices, length: indexBufferSize, options: .storageModeShared)!

    // Initialize free buckets
    print("Initializing \(maxBuckets) free buckets")
    for i in 0..<maxBuckets {
      freeBuckets.append(i)
    }
    
    // Initialize command indices array
    commandIndices = Array(repeating: 0, count: maxBuckets)
    
    print("FacePool initialization complete")
}

  func _faceBucketSize() -> Int {
    return faceBucketSize
  }

  // Request a bucket for faces
  func requestBucket(position: SIMD3<Float>, faceGroup: UInt8) -> Int? {
    lock.lock()
    defer { lock.unlock() }
    
    guard !freeBuckets.isEmpty else {
      print("WARNING: No free buckets available!")
      return nil
    }

    let bucketIndex = freeBuckets.removeLast()
    let baseVertex = bucketIndex * faceBucketSize

    // No unsafe pointers - just use the index directly
    let commandIndex = UInt32(drawCommands.count)
    
    // Create draw command without unsafe pointers
    let command = FaceDrawCommand(
      indexCount: UInt32(faceBucketSize * 6),  // 6 indices per face (2 triangles)
      instanceCount: 1,
      indexStart: UInt32(baseVertex * 6),  // 6 indices per face
      baseVertex: UInt32(baseVertex * 4),  // 4 vertices per face
      baseInstance: 0,
      position: position,
      group: faceGroup,
      index: commandIndex
    )

    drawCommands.append(command)
    
    // Update the command index array
    if bucketIndex < commandIndices.count {
      commandIndices[bucketIndex] = commandIndex
    }
    
    if drawCommands.count % 10 == 0 {
      print("Allocated bucket \(bucketIndex), total commands: \(drawCommands.count), free buckets: \(freeBuckets.count)")
    }
    
    return bucketIndex
  }

  // Add a face to a bucket
  func addFace(bucketIndex: Int, faceIndex: Int, face: Face) {
    guard bucketIndex < maxBuckets && faceIndex < faceBucketSize else {
        print("WARNING: Invalid bucket (\(bucketIndex)) or face index (\(faceIndex))")
        return
    }

    // Calculate offset for this face in the face buffer
    let offset = (bucketIndex * faceBucketSize + faceIndex) * MemoryLayout<Face>.stride
    
    // Write the face data to the buffer
    let facesPtr = faceBuffer.contents().advanced(by: offset).bindMemory(to: Face.self, capacity: 1)
    facesPtr.pointee = face
}
  // Release a bucket
  func releaseBucket(commandIndex: UInt32) {
    lock.lock()
    defer { lock.unlock() }
    
    guard commandIndex < drawCommands.count else {
      print("WARNING: Invalid command index \(commandIndex), max is \(drawCommands.count - 1)")
      return
    }

    let bucketIndex = Int(drawCommands[Int(commandIndex)].baseVertex) / (faceBucketSize * 4)
    
    // Add bucket back to free list only if it's a valid index
    if bucketIndex < maxBuckets {
      freeBuckets.append(bucketIndex)
    } else {
      print("WARNING: Invalid bucket index \(bucketIndex) to free")
    }
    
    // Swap with last command and update indices
    let lastIndex = drawCommands.count - 1
    if Int(commandIndex) != lastIndex && lastIndex >= 0 {
      // Move the last command to this position
      drawCommands[Int(commandIndex)] = drawCommands[lastIndex]
      
      // Update the commandIndices entry for this bucket
      if bucketIndex < commandIndices.count {
        commandIndices[bucketIndex] = UInt32.max  // Mark as invalid
      }
      
      // Find which bucket corresponds to the moved command
      let movedBucketIndex = Int(drawCommands[Int(commandIndex)].baseVertex) / (faceBucketSize * 4)
      if movedBucketIndex < commandIndices.count {
        commandIndices[movedBucketIndex] = commandIndex
      }
    }

    if !drawCommands.isEmpty {
      drawCommands.removeLast()
    }
    
    if effectiveDrawCount > drawCommands.count {
      effectiveDrawCount = drawCommands.count
    }
    
    if drawCommands.count % 10 == 0 {
      print("Released bucket \(bucketIndex), remaining commands: \(drawCommands.count), free buckets: \(freeBuckets.count)")
    }
  }

  // Mask draw commands based on a predicate function
  func mask(_ predicate: (FaceDrawCommand) -> Bool) {
    lock.lock()
    defer { lock.unlock() }
    
    guard !drawCommands.isEmpty else {
      return
    }
    
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
        // Get the bucket indices for both commands
        let frontBucketIndex = Int(drawCommands[frontIndex].baseVertex) / (faceBucketSize * 4)
        let backBucketIndex = Int(drawCommands[backIndex].baseVertex) / (faceBucketSize * 4)
        
        // Update commandIndices
        if frontBucketIndex < commandIndices.count {
          commandIndices[frontBucketIndex] = UInt32(backIndex)
        }
        if backBucketIndex < commandIndices.count {
          commandIndices[backBucketIndex] = UInt32(frontIndex)
        }
        
        // Swap the commands
        drawCommands.swapAt(frontIndex, backIndex)
        
        frontIndex += 1
        backIndex -= 1
      }
    }

    effectiveDrawCount = frontIndex
  }

  // Order the masked portion of draw commands
  func order(_ comparator: (FaceDrawCommand, FaceDrawCommand) -> Bool) {
    lock.lock()
    defer { lock.unlock() }
    
    guard effectiveDrawCount > 0 else {
      return
    }
    
    // Extract bucket indices and their command indices before sorting
    var bucketToCommandIndex = [Int: Int]()
    for i in 0..<effectiveDrawCount {
      let bucketIndex = Int(drawCommands[i].baseVertex) / (faceBucketSize * 4)
      bucketToCommandIndex[bucketIndex] = i
    }
    
    // Sort only the effective (masked) portion
    let sortedPortion = drawCommands[0..<effectiveDrawCount].sorted(by: comparator)
    for i in 0..<effectiveDrawCount {
      drawCommands[i] = sortedPortion[i]
      
      // Update the command indices
      let bucketIndex = Int(drawCommands[i].baseVertex) / (faceBucketSize * 4)
      if bucketIndex < commandIndices.count {
        commandIndices[bucketIndex] = UInt32(i)
      }
    }
  }

  // Update the indirect buffer with the current draw commands
  func updateIndirectBuffer() {
    lock.lock()
    defer { lock.unlock() }
    
    guard !drawCommands.isEmpty else {
      return
    }
    
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
// Replace the draw method in FacePool
func draw(commandEncoder: MTLRenderCommandEncoder, maskAndSort: Bool = true) {
    lock.lock()
    let drawCount = drawCommands.count
    lock.unlock()
    
    // No draw commands to render
    if drawCount == 0 {
        print("No draw commands to render")
        return
    }
    
    // Update indirect buffer before drawing
    updateIndirectBuffer()

    // Set vertex buffer with all the face data
    commandEncoder.setVertexBuffer(faceBuffer, offset: 0, index: 0)
    
    // Draw each bucket directly, reusing the same index pattern
    for i in 0..<drawCount {
        let cmd = drawCommands[i]
        
        // Get the actual face count for this bucket
        let faceCount = Int(cmd.indexCount) / 6  // Each face uses 6 indices
        
        // Draw each face in this bucket separately
        for faceIndex in 0..<faceCount {
            // Draw this face using the shared index pattern
            commandEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: 6,  // Always 6 indices (2 triangles)
                indexType: .uint16,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0, // Always start at the beginning of the index buffer
                instanceCount: 1,
                baseVertex: Int(cmd.baseVertex) + (faceIndex * 4), // 4 vertices per face
                baseInstance: 0
            )
        }
    }
    
    print("Drew \(drawCount) command buckets")
}
    

  // Get resources
  func getFaceBuffer() -> MTLBuffer { return faceBuffer }
  func getIndexBuffer() -> MTLBuffer { return indexBuffer }
  func getIndirectBuffer() -> MTLBuffer { return indirectBuffer }
  func getDrawCount() -> Int { 
    lock.lock()
    defer { lock.unlock() }
    return effectiveDrawCount 
  }
  func getTotalDrawCount() -> Int { 
    lock.lock()
    defer { lock.unlock() }
    return drawCommands.count 
  }
}