import Metal
import MetalKit

struct GpuGenerator {
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

    private var nextCallId = 0;
    private var trackingInfo = [Int: BufferTrackingInfo]()
    private var buffersByCallId = [Int: MTLBuffer]()

// Voxel data
    let chunkSize: SIMD3<UInt32>
    
    init(device: MTLDevice, chunkSize: SIMD3<UInt32>) {
        self.device = device
        self.chunkSize = chunkSize
        
        // Load the compute function
        guard let library = device.makeDefaultLibrary(),
              let computeFunction = library.makeFunction(name: "baseTerrain") else {
            fatalError("Failed to load compute function")
        }
        
        // Create the compute pipeline state
        do {
            pipelineState = try device.makeComputePipelineState(function: computeFunction)
        } catch {
            fatalError("Failed to create compute pipeline state: \(error)")
        }
    }

    func generateVoxels(commandBuffer: MTLCommandBuffer, position: SIMD3<Int>, completion: @escaping (Int, [UInt8]?) -> Void) -> Int {
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

class MeshGenerator {
    let device: MTLDevice
    let pipelineState: MTLComputePipelineState

    private var nextCallId = 0;
    private var trackingInfo = [Int: BufferTrackingInfo]()
    private var buffersByCallId = [Int: MTLBuffer]()

// Voxel data
    let chunkSize: SIMD3<UInt32>
    
    init(device: MTLDevice, chunkSize: SIMD3<UInt32>) {
        self.device = device
        self.chunkSize = chunkSize
        
        // Load the compute function
        guard let library = device.makeDefaultLibrary(),
              let computeFunction = library.makeFunction(name: "generateMesh") else {
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
        voxelData: [UInt8],
        position: SIMD3<Int>,
        completion: @escaping (Int, [SIMD3<Float>]?, [UInt32]?) -> Void) -> Int {
        return []
    }
}

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let voxelGenerator: VoxelGenerator
    let meshGenerator: MeshGenerator
    let commandQueue: MTLCommandQueue
    var chunkVoxel: [SIMD3<Int> : VoxelChunk] = [SIMD3<Int> : VoxelChunk]()
    var chunkVoxelDirty: [SIMD3<Int>] = [] 
    var chunkVoxelGenIdMapping = [Int : SIMD3<Int>]()
    var chunkMesh: [SIMD3<Int> : VertexChunk] = [SIMD3<Int> : VertexChunk]()
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
        let renderPassDescriptor = view.currentRenderPassDescriptor else { return }


        // Create a command buffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("DEez")
            return;
        }

        for i in 0..<[10, chunkVoxelDirty.count].min()! {
            let position = chunkVoxelDirty.popLast()!
            generateChunk(commandBuffer: commandBuffer, position: position)
        }

        for i in 0..<[10, chunkMeshDirty.count].min()! {
            let position = chunkMeshDirty.popLast()!
            let chunk = chunkVoxel[position]!
            generateMesh(chunk: chunk);
        }

        commandBuffer.commit()
    }

    func generateMesh( chunk: VoxelChunk) {
        let callId = meshGenerator.generateMesh(voxelData: chunk.voxelData, position: chunk.position) { callId, vertices, indices in
            guard let vertices = vertices, let indices = indices else {
                print("Failed to generate mesh data for call ID \(callId)")
                return
            }
            self.chunkMesh[chunk.position] = VertexChunk(position: chunk.position, vertices: vertices, indices: indices)
        }

    }

    func generateChunk(commandBuffer: MTLCommandBuffer, position: SIMD3<Int>)
    {
       let callId = voxelGenerator.generateVoxels (commandBuffer: commandBuffer, position: position) { callId, voxelData in
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
