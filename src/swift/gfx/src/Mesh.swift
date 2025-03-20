import Metal
import MetalKit
import simd

struct GpuMesher {
  var size: SIMD3<UInt32>
}
struct GpuMesh {
  var vertexCount: UInt32 = 0
  var indexCount: UInt32 = 0
}
class MeshGenerator {
  let device: MTLDevice
  let pipelineState: MTLComputePipelineState
  let queue: MTLCommandQueue

  private let lock = NSLock()
  private var nextCallId = 0
  private var trackingInfo = [Int: BufferTrackingInfo]()
  private var buffersByCallId = [Int: (faceBuffer: MTLBuffer, countBuffer: MTLBuffer)]()

  // Voxel data
  let chunkSize: SIMD3<UInt32>

  init(device: MTLDevice, chunkSize: SIMD3<UInt32>) {
    self.device = device
    self.chunkSize = chunkSize
    self.queue = device.makeCommandQueue()!
    
    print("Initializing MeshGenerator...")

    // Load the compute function
    guard let library = device.makeDefaultLibrary(),
      let computeFunction = library.makeFunction(name: "generateMesh")
    else {
      fatalError("Failed to load mesh generation compute function")
    }

    // Create the compute pipeline state
    do {
      pipelineState = try device.makeComputePipelineState(function: computeFunction)
      print("Successfully created compute pipeline state for mesh generation")
    } catch {
      fatalError("Failed to create mesh compute pipeline state: \(error)")
    }
  }

  // Converted to use async/await
  func generateMesh(
    commandBuffer: MTLCommandBuffer?,
    voxelData: [UInt8],
    position: SIMD3<Int>
  ) async -> (Int, [Face]?) {
    // Thread-safe ID generation
    var callId = lock.withLock {
    let callId = nextCallId
    nextCallId += 1
    
    // Create tracking info for this call
    var info = BufferTrackingInfo(callId: callId)
    trackingInfo[callId] = info
    return callId;
    };
    
    print("MeshGenerator: Starting mesh generation for callId: \(callId), position: \(position)")

    // Create our own command buffer
    guard let localCommandBuffer = queue.makeCommandBuffer() else {
      print("MeshGenerator: Failed to create command buffer for callId: \(callId)")
      return (callId, nil)
    }

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
    let maxFaces = totalVoxels * 6  // 6 faces per voxel (worst case)
    let faceBuffer = device.makeBuffer(
      length: maxFaces * MemoryLayout<Face>.stride, options: .storageModeShared)!

    // Store buffer references for later cleanup (thread-safe)
    lock.withLock {
        buffersByCallId[callId] = (faceBuffer, countBuffer)
    }
    // Create a compute command encoder
    guard let computeEncoder = localCommandBuffer.makeComputeCommandEncoder() else {
      print("MeshGenerator: Failed to create compute encoder for callId: \(callId)")
      return (callId, nil)
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

    // Use withCheckedContinuation to bridge between callback-based API and async/await
    return await withCheckedContinuation { continuation in
      // Set a completion handler before committing
      localCommandBuffer.addCompletedHandler { [weak self] buffer in
        guard let self = self else {
          print("MeshGenerator: self is nil in completion handler for callId: \(callId)")
          continuation.resume(returning: (callId, nil))
          return
        }

        print("MeshGenerator: Command buffer completed for callId: \(callId) with status: \(buffer.status.rawValue)")
        
        // Thread-safe updates
        self.lock.lock()
        // Check if we still have the tracking info and buffers
        guard var updatedInfo = self.trackingInfo[callId],
              let buffers = self.buffersByCallId[callId] else {
          self.lock.unlock()
          print("MeshGenerator: Tracking info or buffers missing for callId: \(callId)")
          continuation.resume(returning: (callId, nil))
          return
        }
        
        // Update tracking info
        updatedInfo.complete()
        updatedInfo.additionalData["status"] = buffer.status.rawValue
        updatedInfo.additionalData["error"] = buffer.error?.localizedDescription ?? "None"
        self.trackingInfo[callId] = updatedInfo
        
        // Get buffer references before releasing lock
        let faceBuffer = buffers.faceBuffer
        let countBuffer = buffers.countBuffer
        self.lock.unlock()

        // Extract face data
        let faceCount = countBuffer.contents().load(as: UInt32.self)
        print("MeshGenerator: Generated \(faceCount) faces for callId: \(callId)")

        // Sanity check
        if faceCount > UInt32(maxFaces) {
          print("Warning: Generated more faces than expected: \(faceCount) > \(maxFaces)")
          continuation.resume(returning: (callId, nil))
          return
        }
        
        if faceCount == 0 {
          print("MeshGenerator: No faces generated for callId: \(callId)")
          continuation.resume(returning: (callId, []))
          return
        }

        // Extract faces
        let facePtr = faceBuffer.contents().bindMemory(to: Face.self, capacity: Int(faceCount))
        var faces = [Face]()
        faces.reserveCapacity(Int(faceCount))
        
        for i in 0..<Int(faceCount) {
          faces.append(facePtr[i])
        }

        print("MeshGenerator: Successfully extracted \(faces.count) faces for callId: \(callId)")
        
        // Resume the continuation with the result
        continuation.resume(returning: (callId, faces))
      }
      
      // Commit the command buffer
      localCommandBuffer.commit()
      print("MeshGenerator: Command buffer committed for callId: \(callId)")
    }
  }

  // Clean up resources for a call
  func cleanup(callId: Int) {
        lock.lock()
        defer { lock.unlock() }
        
        print("MeshGenerator: Cleaning up resources for callId: \(callId)")
        buffersByCallId.removeValue(forKey: callId)
        trackingInfo.removeValue(forKey: callId)
    }
}