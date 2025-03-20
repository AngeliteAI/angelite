import Metal
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
        commandBuffer: MTLCommandBuffer, 
        position: SIMD3<Int>
    ) async -> (Int, [UInt8]?) {
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

        // Create a compute command encoder
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            info.status = "Failed to create compute encoder"
            trackingInfo[callId] = info
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
            commandBuffer.addCompletedHandler { [weak self] buffer in
                guard let self = self else {
                    continuation.resume(returning: (callId, nil))
                    return
                }

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

                // Resume the continuation with the result
                continuation.resume(returning: (callId, voxelData))
            }
        }
    }
    
    // Clean up resources for a call
    func cleanup(callId: Int) {
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
    var cameraPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
    
    init(device: MTLDevice, faceBucketSize: Int = 256, maxBuckets: Int = 1024) {
        self.device = device
        
        // Initialize vertex pool
        self.facePool = FacePool(device: device, faceBucketSize: faceBucketSize, maxBuckets: maxBuckets)
        
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
            if currentBucketIndex == nil || currentFaceIndex >= facePool.faceBucketSize {
                // Position for sorting (chunk center)
                let chunkCenter = SIMD3<Float>(
                    Float(position.x) + 0.5,
                    Float(position.y) + 0.5,
                    Float(position.z) + 0.5
                )
                
                currentBucketIndex = facePool.requestBucket(position: chunkCenter, faceGroup: face.normal)
                if currentBucketIndex == nil {
                    print("Failed to allocate new bucket for chunk at \(position)")
                    break
                }
                
                bucketIndices.append(currentBucketIndex!)
                currentFaceIndex = 0
            }
            
            // Add face to the current bucket
            facePool.addFace(bucketIndex: currentBucketIndex!, faceIndex: currentFaceIndex, face: face)
            currentFaceIndex += 1
        }
        
        return bucketIndices
    }
    
    // Remove a chunk from the renderer
    func removeChunk(commandIndices: [UInt32]) {
        for index in commandIndices {
            facePool.releaseBucket(commandIndex: index)
        }
    }
    
    // Update camera position
    func updateCamera(position: SIMD3<Float>) {
        cameraPosition = position
    }
    
    // Draw all chunks using multi-draw-indirect
    func draw(commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor, cameraData: inout CameraData) {
        // Create render encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Set render pipeline and depth state
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // Set up camera uniforms
        renderEncoder.setVertexBytes(&cameraData, length: MemoryLayout<CameraData>.size, index: 1)
        renderEncoder.setFragmentBytes(&cameraData, length: MemoryLayout<CameraData>.size, index: 1)
        
        // Perform true back-face culling with masking
        performBackFaceCulling()
        
        // Perform front-to-back ordering for optimal z-buffer usage
        performFrontToBackOrdering()
        
        // Draw using the vertex pool
        facePool.draw(commandEncoder: renderEncoder)
        
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
            let distA = distance_squared(a.position, cameraPosition)
            let distB = distance_squared(b.position, cameraPosition)
            
            // Sort by distance (closest first)
            return distA < distB
        }
    }
}