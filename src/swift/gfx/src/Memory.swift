import Metal
import Foundation

private var nextAllocationID: AllocationId = AllocationId(id: 0)
private func generateAllocationID() -> UInt32 {
    let id = nextAllocationID
    nextAllocationID.id += 1
    return id
}

struct AllocationId {
    let id: UInt32
    init(id: UInt32) {
        self.id = id
    }
}

struct Block {
    var offset: UInt64
    let size: UInt64
}

struct GpuAllocation {
    let block: Block
    let buffer: MTLBuffer
    let id: AllocationId 
}

enum GpuMemoryPoolType: Int, CaseIterable {
    case voxel
    case palette
    case face
    case indirect
    case metadata

    var initialSize: Int {
        switch self {
            case .voxel: return 1024 * 1024 * 1024 // 1 GB
            case .palette: return 64 * 1024 * 1024 // 64 MB
            case .face: return 1024 * 1024 * 1024 // 1 GB
            case .indirect: return 64 * 1024 * 1024 // 64 MB
            case .metadata: return 64 * 1024 * 1024 // 64 MB
        }
    }

    var alignment: Int {
        switch self {
            case .voxelData: return 16  // Align to 16 bytes (typical for SIMD)
            case .palette:   return 8   // Align to 8 bytes (64-bit values)
            case .faceMesh:  return 16  // Align to 16 bytes (for SIMD)
            case .indirect:  return 16  // Align to 16 bytes (for indirect commands)
            case .metadata:  return 8   // Align to 8 bytes (64-bit values)
        }
    }

    var storageMode: MTLResourceOptions {
        switch self {
            case .voxelData: return .storageModeManaged  // CPU writes, GPU reads
            case .palette:   return .storageModeManaged  // CPU writes, GPU reads
            case .faceMesh:  return .storageModePrivate  // GPU only for generated mesh
            case .indirect:  return .storageModePrivate  // GPU only for draw commands
            case .metadata:  return .storageModeShared   // CPU and GPU read/write for atomic updates
        }
    }

    var name: String {
        switch self {
            case .voxelData: return "VoxelData"
            case .palette:   return "Palette"
            case .faceMesh:  return "FaceMesh"
            case .indirect:  return "Indirect"
            case .metadata:  return "Metadata"
        }
    }
}

class GpuMemoryPool {
    private let device: MTLDevice
    private let poolType: GpuMemoryPoolType
    private var buffers: [MTLBuffer] = []
    private var freeBlocks: [Int : Block] = []

    private var totalUsed: UInt64 = 0
    private var totalFree: UInt64 = 0

    init(device: MTLDevice, poolType: GpuMemoryPoolType) {
        self.device = device
        self.poolType = poolType
        
        createNewBuffer(size: poolType.initialSize)
    }

    private func createNewBuffer(size: UInt64) {
        // Create buffer with the specified storage mode
        guard let buffer = device.makeBuffer(length: size, options: poolType.storageMode) else {
            fatalError("Failed to create buffer for \(poolType.name) pool")
        }
        
        // Set a label for debugging
        buffer.label = "MemoryPool_\(poolType.name)_\(buffers.count)"
        
        // Add to our list
        let bufferIndex = buffers.count
        buffers.append(buffer)
        
        // Initialize free blocks list for this buffer
        freeBlocks[bufferIndex] = [FreeBlock(offset: 0, size: size)]
        
        totalFree += size
        
        print("Created new \(poolType.name) buffer: \(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .memory))")
    }

    func allocate(size: UInt64) -> GpuAllocation? {
        let alignedSize = align(size: size, to: poolType.alignment)

        for (bufferIndex, blocks) in freeBlocks {
            for (blockIndex, block) in blocks.enumerated() {
                if block.size >= alignedSize {
                    let allocation = GpuAllocation(
                        offset: block.offset,
                        size: alignedSize,
                        buffer: buffers[bufferIndex],
                        id: generateAllocationId()
                    )

                    let newOffset = block.offset + alignedSize
                    let newSize = block.size - alignedSize

                    if newSize > 0 {
                        freeBlocks[bufferIndex]![blockIndex] = Block(offset: newOffset, size: newSize)
                    } else {
                        freeBlocks[bufferIndex]!.remove(at: blockIndex)
                    }

                    totalUsed += alignedSize
                    totalFree -= alignedSize

                    return allocation
                }
            }
        }

        createNewBuffer(size: poolType.initialSize)

        return allocate(size: size)
    }

    func free(allocation: GpuAllocation) {
        guard let bufferIndex = buffers.firstIndex(where: { $0 === allocation.buffer }) else {
            print("Warning: Allocation buffer not found in pool")
            return
        }

        let newBlock = allocation.block

        if freeBlocks[bufferIndex] == nil {
            freeBlocks[bufferIndex] = [newBlock]
        } else {
            freeBlocks[bufferIndex]!.append(newBlock)
            freeBlocks[bufferIndex]!.sort { $0.offset < $1.offset }
            coaleseFreeBlocks(bufferIndex: bufferIndex)
        }

        totalUsed -= allocation.size
        totalFree += allocation.size
    }
    
    private func coalesceFreeBlocks(bufferIndex: Int) {
        guard var blocks = freeBlocks[bufferIndex], blocks.count > 1 else {
            return
        }
        
        var i = 0
        while i < blocks.count - 1 {
            let current = blocks[i]
            let next = blocks[i + 1]
            
            if current.offset + current.size == next.offset {
                // Blocks are adjacent, merge them
                blocks[i] = FreeBlock(offset: current.offset, size: current.size + next.size)
                blocks.remove(at: i + 1)
                // Don't increment i since we need to check again with the new next block
            } else {
                i += 1
            }
        }
        
        freeBlocks[bufferIndex] = blocks
    }

private func align(size: Int, to alignment: Int) -> Int {
        let remainder = size % alignment
        return remainder == 0 ? size : size + (alignment - remainder)
    }
    
    /// Generate a unique allocation ID
        func getStats() -> (totalSize: Int, allocated: Int, free: Int, fragmentation: Double) {
        lock.lock()
        defer { lock.unlock() }
        
        let totalSize = buffers.reduce(0) { $0 + $1.length }
        let fragmentation = totalFree > 0 ? 1.0 - (Double(largestFreeBlockSize()) / Double(totalFree)) : 0.0
        
        return (totalSize, totalAllocated, totalFree, fragmentation)
    }
    
    /// Find the largest free block size
    private func largestFreeBlockSize() -> Int {
        var largest = 0
        
        for (_, blocks) in freeBlocks {
            for block in blocks {
                largest = max(largest, block.size)
            }
        }
        
        return largest
    }
    
    /// Create a staging buffer for a particular allocation (if needed)
    func createStagingBuffer(for allocation: GPUAllocation) -> MTLBuffer? {
        // Only create staging buffers for private storage mode
        if poolType.storageMode == .storageModePrivate {
            return device.makeBuffer(length: allocation.size, options: .storageModeShared)
        }
        return nil
    }
    
    /// Copy from staging buffer to allocation (if needed)
    func copyFromStaging(stagingBuffer: MTLBuffer, to allocation: GPUAllocation, commandBuffer: MTLCommandBuffer) {
        // Only need to copy for private storage mode
        if poolType.storageMode == .storageModePrivate {
            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
            
            blitEncoder.copy(
                from: stagingBuffer,
                sourceOffset: 0,
                to: allocation.buffer,
                destinationOffset: allocation.offset,
                size: allocation.size
            )
            
            blitEncoder.endEncoding()
        }
    }
}

class TypedGpuAllocation {
    var poolType: GpuMemoryPoolType
    var allocation: GpuAllocation
}

class GpuMemoryAllocator {
    private let device: MTLDevice
    private var pools: [GpuMemoryPoolType : GpuMemoryPool] = [:] 

    private var allocations: [AllocationId : TypedGpuAllocation] = [:]
    private var needsCommit: [AllocationId : Bool] = [:]
    private var stagingBuffers: [UInt32 : MTLBuffer] = [:]

    init(device: MTLDevice) {
        self.device = device

        for poolType in GpuMemoryPoolType.allCases {
            pools[poolType] = GpuMemoryPool(device: device, poolType: poolType)
        }
    }

    func allocate(size: UInt64, type: GpuMemoryPoolType) -> TypedGpuAllocation? {
        guard let pool = pools[type] else {
            print("Warning: Memory pool not found for type \(type)")
            return nil
        }

        guard let allocation = pool.allocate(size: size) else {
            print("Warning: Failed to allocate \(size) bytes from pool \(type)")
            return nil
        }

        let typedAllocation = TypedGpuAllocation(poolType: type, allocation: allocation)
        let id = allocation.id
        allocations[id] = typedAllocation

        if type.storageMode == .storageModePrivate {
            let stagingBuffer = pool.createStagingBuffer(for: allocation)
            if let buffer = stagingBuffer {
                stagingBuffers[allocation.id] = buffer
            }
        }

        return typedAllocation
    }

    func free(allocation: TypedGpuAllocation) {
        guard let pool = pools[allocation.poolType] else {
            print("Warning: Memory pool not found for type \(allocation.poolType)")
            return
        }

        pool.free(allocation: allocation.allocation)
        allocations.removeValue(forKey: allocation.allocation.id)
        stagingBuffers.removeValue(forKey: allocation.allocation.id)
    }

    func write<T>(data: [T], to allocationID: AllocationId, offset: Int = 0) -> Bool {
        guard let allocation = allocations[allocationID] else {
            print("Warning: Allocation not found for ID \(allocationID)")
            return false
        }

        let size = data.count * MemoryLayout<T>.stride
        let buffer = stagingBuffers[allocationID.id]

        if poolType.storageMode == .storageModePrivate {
            // Write to staging buffer
            guard let stagingBuffer = stagingBuffers[allocationID] else {
                print("Error: Staging buffer not found for allocation \(allocationID)")
                return false
            }
            lock.unlock()
            
            let bufferPtr = stagingBuffer.contents().advanced(by: offset)
            
            data.withUnsafeBytes { rawBufferPointer in
                memcpy(bufferPtr, rawBufferPointer.baseAddress!, dataSize)
            }
        } else {
            // Write directly to allocation
            let bufferPtr = allocation.buffer.contents().advanced(by: allocation.offset + offset)
            
            data.withUnsafeBytes { rawBufferPointer in
                memcpy(bufferPtr, rawBufferPointer.baseAddress!, dataSize)
            }
        }

        return true 
    }


    func read<T>(from allocationID: AllocationId, count: Int, offset: Int = 0) -> [T]? {
        guard let allocation = allocations[allocationID] else {
            print("Warning: Allocation not found for ID \(allocationID)")
            return nil
        }

        let size = count * MemoryLayout<T>.stride
        let buffer = stagingBuffers[allocationID.id]

        if poolType.storageMode == .storageModePrivate {
            print("Error: Cannot read directly from private memory allocation")
            return nil
        }
        // Read directly from allocation
        let bufferPtr = allocation.buffer.contents().advanced(by: allocation.offset + offset)
        return bufferPtr.bindMemory(to: T.self, capacity: count).map { $0 }
    }

    func getStats() -> [(poolType: GpuMemoryPoolType, stats: (totalSize: Int, allocated: Int, free: Int, fragmentation: Double))] {
        return pools.map { ($0.key, $0.value.getStats()) }
    }

    func commitWrites(commandBuffer: MTLCommandBuffer) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
        
        for (id, stagingBuffer) in stagingCopy {
            if !needsCommit[id] {
                continue
            }
            if let (allocation, _) = allocations[id] {
                blitEncoder.copy(
                    from: stagingBuffer,
                    sourceOffset: 0,
                    to: allocation.buffer,
                    destinationOffset: allocation.offset,
                    size: min(stagingBuffer.length, allocation.size)
                )
            }
        }
        
        blitEncoder.endEncoding()
    }
}