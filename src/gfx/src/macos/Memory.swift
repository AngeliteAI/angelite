import Metal
import Foundation

private var nextAllocationID: AllocationId = AllocationId(id: 0)
private func generateAllocationId() -> AllocationId {
    let id = nextAllocationID
    nextAllocationID.id += 1
    return id
}

struct AllocationId: Hashable {
    var id: UInt32
    init(id: UInt32) {
        self.id = id
    }
}

enum HeapResourceType: Int {
    case voxel = 0
    case palette = 1
    case face = 2
    case indirect = 3
    case metadata = 4
}

@frozen public struct HeapBlock {
    let offset: UInt64
    let size: UInt64
}

public struct HeapAllocation {
    let buffer: MTLBuffer
    let block: HeapBlock
    let type: HeapResourceType
    let id: AllocationId
}

// Ring buffer for staging operations
class StagingRingBuffer {
    private let buffer: MTLBuffer
    private let size: Int
    private var head: Int = 0
    private var tail: Int = 0
    private var allocations: [Range<Int>: AllocationId] = [:]
    
    init(device: MTLDevice, size: Int) {
        guard let buffer = device.makeBuffer(length: size, options: .storageModeShared) else {
            fatalError("Failed to create staging ring buffer")
        }
        self.buffer = buffer
        self.size = size
        buffer.label = "StagingRingBuffer"
    }
    
    func allocate(size: Int, alignment: Int = 256) -> (buffer: MTLBuffer, offset: Int, id: AllocationId)? {
        let alignedSize = (size + alignment - 1) & ~(alignment - 1)
        var availableSpace = 0
        
        if head >= tail {
            // Space available from head to end of buffer and from start to tail
            availableSpace = (size - head) + tail
        } else {
            // Space available between tail and head
            availableSpace = tail - head
        }
        
        if availableSpace < alignedSize {
            print("Staging buffer full, cannot allocate \(alignedSize) bytes")
            return nil
        }
        
        var allocOffset = head
        // Align offset
        allocOffset = (allocOffset + alignment - 1) & ~(alignment - 1)
        
        // Handle wrapping
        if allocOffset + alignedSize > size {
            // Not enough space at the end, wrap to beginning
            allocOffset = 0
            allocOffset = (allocOffset + alignment - 1) & ~(alignment - 1)
        }
        
        // Update head
        head = (allocOffset + alignedSize) % size
        
        let allocationId = generateAllocationId()
        allocations[allocOffset..<(allocOffset + alignedSize)] = allocationId
        
        return (buffer, allocOffset, allocationId)
    }
    
    func free(id: AllocationId) {
        // Find allocation by ID
        if let range = allocations.first(where: { $0.value == id })?.key {
            allocations.removeValue(forKey: range)
            
            // Update tail if this was the oldest allocation
            if range.lowerBound == tail {
                tail = range.upperBound
                
                // Find next allocation
                while let nextRange = allocations.keys.sorted(by: { $0.lowerBound < $1.lowerBound }).first(where: { $0.lowerBound == tail }) {
                    tail = nextRange.upperBound
                }
            }
        }
    }
    
    func reset() {
        head = 0
        tail = 0
        allocations.removeAll()
    }
}

public class GpuAllocator {
    private let device: MTLDevice
    private let heap: MTLHeap
    private let stagingBuffer: StagingRingBuffer
    private var allocations: [AllocationId: HeapAllocation] = [:]
    private var pendingTransfers: [(source: MTLBuffer, sourceOffset: Int, destination: MTLBuffer, destinationOffset: Int, size: Int)] = []
    
    // Resource tracking
    private var resourceOffsets: [HeapResourceType: Int] = [:]
    
    init(device: MTLDevice, heapSize: Int = 2 * 1024 * 1024 * 1024, stagingSize: Int = 256 * 1024 * 1024) {
        self.device = device
        
        // Create heap descriptor
        let heapDescriptor = MTLHeapDescriptor()
        heapDescriptor.size = heapSize
        heapDescriptor.storageMode = .private // GPU-only memory for performance
        heapDescriptor.hazardTrackingMode = .tracked
        
        // Create heap
        guard let heap = device.makeHeap(descriptor: heapDescriptor) else {
            fatalError("Failed to create GPU heap")
        }
        self.heap = heap
        heap.label = "MainGPUHeap"
        
        // Create staging buffer
        self.stagingBuffer = StagingRingBuffer(device: device, size: stagingSize)
        
        // Initialize resource offsets
        for type in HeapResourceType.allCases {
            resourceOffsets[type] = 0
        }
    }
    
    func allocate(size: Int, type: HeapResourceType, options: MTLResourceOptions = []) -> HeapAllocation? {
        // Create buffer from heap
        guard let buffer = heap.makeBuffer(length: size, options: [.storageModePrivate]) else {
            print("Failed to allocate \(size) bytes from heap for \(type)")
            return nil
        }
        buffer.label = "Heap_\(type)_Buffer"
        
        // Create allocation
        let id = generateAllocationId()
        let allocation = HeapAllocation(
            buffer: buffer,
            block: HeapBlock(offset: 0, size: UInt64(size)),
            type: type,
            id: id
        )
        
        // Store allocation
        allocations[id] = allocation
        
        return allocation
    }
    
    func free(id: AllocationId) {
        guard let allocation = allocations[id] else {
            print("Warning: Allocation not found for ID \(id)")
            return
        }
        
        // Remove allocation
        allocations.removeValue(forKey: id)
    }
    
    func write<T>(data: [T], to allocation: HeapAllocation) -> Bool {
        let size = data.count * MemoryLayout<T>.stride
        
        // Allocate space in staging buffer
        guard let staging = stagingBuffer.allocate(size: size) else {
            print("Failed to allocate staging buffer for write operation")
            return false
        }
        
        // Copy data to staging buffer
        let stagingPtr = staging.buffer.contents().advanced(by: staging.offset)
        data.withUnsafeBytes { rawBufferPointer in
            memcpy(stagingPtr, rawBufferPointer.baseAddress!, size)
        }
        
        // Queue transfer operation
        pendingTransfers.append((
            source: staging.buffer,
            sourceOffset: staging.offset,
            destination: allocation.buffer,
            destinationOffset: 0,
            size: size
        ))
        
        return true
    }
    
    func commitWrites(commandBuffer: MTLCommandBuffer) {
        guard !pendingTransfers.isEmpty else { return }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { 
            print("Failed to create blit encoder for transfers")
            return 
        }
        
        for transfer in pendingTransfers {
            blitEncoder.copy(
                from: transfer.source,
                sourceOffset: transfer.sourceOffset,
                to: transfer.destination,
                destinationOffset: transfer.destinationOffset,
                size: transfer.size
            )
        }
        
        blitEncoder.endEncoding()
        
        // Clear pending transfers
        pendingTransfers.removeAll()
    }
    
    // Helper to get the heap pointer for offset calculations
    func getHeapBufferOffsets() -> [UInt64] {
        var offsets: [UInt64] = []
        for type in HeapResourceType.allCases {
            let buffers = allocations.values.filter { $0.type == type }.map { $0.buffer }
            if let buffer = buffers.first {
                offsets.append(UInt64(buffer.gpuAddress))
            } else {
                offsets.append(0)
            }
        }
        return offsets
    }
}

extension HeapResourceType: CaseIterable {
    static var allCases: [HeapResourceType] {
        return [.voxel, .palette, .face, .indirect, .metadata]
    }
}