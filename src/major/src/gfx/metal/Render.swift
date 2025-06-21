import Foundation
import Metal
import MetalKit
import AppKit
import QuartzCore
import simd

// MARK: - Data Structures and Protocols
struct Uniforms {
    var projectionMatrix: matrix_float4x4
    var viewMatrix: matrix_float4x4
}

private func createDefaultShaders() -> String {
    return """
    #include <metal_stdlib>
    #include <simd/simd.h>
    using namespace metal;

    struct Vertex {
        float3 position [[attribute(0)]];
        float3 normal [[attribute(1)]];
        float4 color [[attribute(2)]];
    };

    struct VertexOut {
        float4 position [[position]];
        float3 normal;
        float4 color;
    };

    struct Uniforms {
        matrix_float4x4 projectionMatrix;
        matrix_float4x4 viewMatrix;
    };

    vertex VertexOut vertexShader(Vertex in [[stage_in]],
                                 constant Uniforms &uniforms [[buffer(1)]]) {
        VertexOut out;

        float4 worldPosition = float4(in.position, 1.0);
        out.position = uniforms.projectionMatrix * uniforms.viewMatrix * worldPosition;
        out.normal = in.normal;
        out.color = in.color;

        return out;
    }

    fragment float4 fragmentShader(VertexOut in [[stage_in]],
                                  constant Uniforms &uniforms [[buffer(0)]]) {
        float3 lightDirection = normalize(float3(0.5, -1.0, 0.3));
        float3 normalDirection = normalize(in.normal);

        float diffuseIntensity = saturate(dot(-lightDirection, normalDirection));
        float ambientIntensity = 0.2;

        float3 lightIntensity = float3(ambientIntensity) + float3(diffuseIntensity);

        return float4(in.color.rgb * lightIntensity, in.color.a);
    }
    """
}
// Vertex structure with position, normal, and color
struct Vertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var color: SIMD4<Float>

    init(position: SIMD3<Float>, normal: SIMD3<Float>, color: SIMD3<Float>) {
        self.position = position
        self.normal = normal
        self.color = SIMD4<Float>(color.x, color.y, color.z, 1.0)
    }
}

// Draw command structure for indirect drawing
struct DrawCommand {
    var indexCount: UInt32
    var instanceCount: UInt32
    var indexStart: UInt32
    var baseVertex: UInt32
    var baseInstance: UInt32
    var commandIndex: UInt32
    var mesh: UnsafeMutableRawPointer?

    init(indexCount: UInt32, instanceCount: UInt32 = 1, indexStart: UInt32, baseVertex: UInt32, baseInstance: UInt32 = 0) {
        self.indexCount = indexCount
        self.instanceCount = instanceCount
        self.indexStart = indexStart
        self.baseVertex = baseVertex
        self.baseInstance = baseInstance
        self.commandIndex = 0
        self.mesh = nil
    }
}

// MARK: - Vertex Pool

// Vertex pool for efficient memory management
class VertexPool {
    private let device: MTLDevice
    private var vertexBuffer: MTLBuffer
    private var indirectBuffer: MTLBuffer
    private var indexBuffer: MTLBuffer

    private let bucketSize: Int // Maximum vertices per bucket
    private let maxBuckets: Int

    private var freeBuckets: [Int] = []
    private var drawCommands: [DrawCommand] = []

    private let indexFormat: MTLIndexType = .uint32
    private let vertexLength: Int

    init(device: MTLDevice, bucketSize: Int, maxBuckets: Int) {
        self.device = device
        self.bucketSize = bucketSize
        self.maxBuckets = maxBuckets

        // Calculate vertex buffer size
        vertexLength = MemoryLayout<Vertex>.stride
        let vertexBufferSize = bucketSize * maxBuckets * vertexLength

        // Create buffers with storage mode shared for CPU-GPU data sharing
        vertexBuffer = device.makeBuffer(length: vertexBufferSize, options: [.storageModeShared])!
        indirectBuffer = device.makeBuffer(length: maxBuckets * MemoryLayout<DrawCommand>.stride, options: [.storageModeShared])!

        // Create index buffer for triangles (6 indices per quad)
        let maxIndices = maxBuckets * bucketSize * 6
        indexBuffer = device.makeBuffer(length: maxIndices * MemoryLayout<UInt32>.stride, options: [.storageModeShared])!

        // Initialize free buckets
        for i in 0..<maxBuckets {
            freeBuckets.append(i)
        }

        // Initialize indices
        initializeIndices()
    }

    private func initializeIndices() {
        let indexPtr = indexBuffer.contents().bindMemory(to: UInt32.self, capacity: bucketSize * 6 * maxBuckets)

        // For each potential quad in a bucket (bucketSize/4 quads)
        for bucketIndex in 0..<maxBuckets {
            for j in 0..<(bucketSize / 4) {
                let baseVertex = bucketIndex * bucketSize + j * 4
                let baseIndex = bucketIndex * (bucketSize / 4) * 6 + j * 6

                // Two triangles per quad (6 indices)
                indexPtr[baseIndex + 0] = UInt32(baseVertex + 0)
                indexPtr[baseIndex + 1] = UInt32(baseVertex + 1)
                indexPtr[baseIndex + 2] = UInt32(baseVertex + 2)
                indexPtr[baseIndex + 3] = UInt32(baseVertex + 0)
                indexPtr[baseIndex + 4] = UInt32(baseVertex + 2)
                indexPtr[baseIndex + 5] = UInt32(baseVertex + 3)
            }
        }
    }

    // Request a vertex bucket
    func requestBucket() -> (Int, UnsafeMutablePointer<Vertex>, UInt32)? {
        guard !freeBuckets.isEmpty else {
            return nil
        }

        let bucketIndex = freeBuckets.removeFirst()
        let baseVertex = bucketIndex * bucketSize

        let vertexPtr = vertexBuffer.contents().advanced(by: baseVertex * vertexLength)
            .bindMemory(to: Vertex.self, capacity: bucketSize)

        return (bucketIndex, vertexPtr, UInt32(baseVertex))
    }

    // Release a bucket
    func releaseBucket(bucketIndex: Int) {
        freeBuckets.insert(bucketIndex, at: 0) // Add back to the front for reuse
    }

    // Add a draw command
    func addDrawCommand(indexCount: UInt32, bucketIndex: Int) -> UInt32 {
        let baseVertex = UInt32(bucketIndex * bucketSize)
        let indexStart = UInt32(bucketIndex * (bucketSize / 4) * 6)

        let command = DrawCommand(
            indexCount: indexCount,
            indexStart: indexStart,
            baseVertex: baseVertex
        )

        let commandIndex = UInt32(drawCommands.count)
        drawCommands.append(command)

        // Update the command index
        drawCommands[Int(commandIndex)].commandIndex = commandIndex

        return commandIndex
    }

    // Remove a draw command
    func removeDrawCommand(commandIndex: UInt32) -> Int? {
        guard Int(commandIndex) < drawCommands.count else {
            return nil
        }

        let bucketIndex = Int(drawCommands[Int(commandIndex)].baseVertex) / bucketSize

        // Swap with the last command and update indices
        if Int(commandIndex) < drawCommands.count - 1 {
            drawCommands.swapAt(Int(commandIndex), drawCommands.count - 1)
            drawCommands[Int(commandIndex)].commandIndex = commandIndex
        }

        drawCommands.removeLast()
        return bucketIndex
    }

    // Update the indirect buffer
    func updateIndirectBuffer() {
        guard !drawCommands.isEmpty else { return }

        // Get raw buffer
        let commandPtr = indirectBuffer.contents()

        // Create a struct that matches Metal's draw arguments
        struct MTLDrawArgs {
            var indexCount: UInt32
            var instanceCount: UInt32
            var indexStart: UInt32
            var baseVertex: UInt32
            var baseInstance: UInt32
        }

        // Copy our commands to the buffer
        for (i, cmd) in drawCommands.enumerated() {
            let offset = i * MemoryLayout<MTLDrawArgs>.stride
            var args = MTLDrawArgs(
                indexCount: cmd.indexCount,
                instanceCount: cmd.instanceCount,
                indexStart: cmd.indexStart,
                baseVertex: cmd.baseVertex,
                baseInstance: cmd.baseInstance
            )

            withUnsafePointer(to: &args) { ptr in
                commandPtr.advanced(by: offset).copyMemory(from: ptr, byteCount: MemoryLayout<MTLDrawArgs>.stride)
            }
        }
    }

    // Apply mask to draw commands - keep only commands that satisfy the predicate
    func mask(_ predicate: (DrawCommand) -> Bool) {
        var left = 0
        var right = drawCommands.count - 1

        while left <= right {
            while left <= right && predicate(drawCommands[left]) {
                left += 1
            }
            while left <= right && !predicate(drawCommands[right]) {
                right -= 1
            }

            if left < right {
                drawCommands.swapAt(left, right)
                drawCommands[left].commandIndex = UInt32(left)
                drawCommands[right].commandIndex = UInt32(right)
                left += 1
                right -= 1
            }
        }

        // Update effective number of commands
        drawCommands = Array(drawCommands[0..<left])
        updateIndirectBuffer()
    }

    // Order draw commands based on a comparison function
    func order(_ compare: (DrawCommand, DrawCommand) -> Bool) {
        drawCommands.sort(by: compare)

        // Update indices
        for (i, _) in drawCommands.enumerated() {
            drawCommands[i].commandIndex = UInt32(i)
        }

        updateIndirectBuffer()
    }

    // Draw all commands
    func draw(commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder) {
        guard !drawCommands.isEmpty else { return }

        updateIndirectBuffer()
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        // Draw all commands
        for i in 0..<drawCommands.count {
            guard drawCommands[i].indexCount > 0 else { continue }

            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: Int(drawCommands[i].indexCount),
                indexType: indexFormat,
                indexBuffer: indexBuffer,
                indexBufferOffset: Int(drawCommands[i].indexStart) * MemoryLayout<UInt32>.stride,
                instanceCount: Int(drawCommands[i].instanceCount),
                baseVertex: Int(drawCommands[i].baseVertex),
                baseInstance: Int(drawCommands[i].baseInstance)
            )
        }
    }

    // Getters for buffers
    func getVertexBuffer() -> MTLBuffer { return vertexBuffer }
    func getIndexBuffer() -> MTLBuffer { return indexBuffer }
    func getIndirectBuffer() -> MTLBuffer { return indirectBuffer }
    func getDrawCommandCount() -> Int { return drawCommands.count }
}

// MARK: - Metal objects for Mesh, Batch, Camera

class MetalMesh {
    private var bucketIndex: Int?
    private var drawCommandIndex: UInt32?
    private var vertexPointer: UnsafeMutablePointer<Vertex>?
    private var vertexCount: Int = 0
    private weak var renderer: MetalRenderer?

    init(renderer: MetalRenderer) {
        self.renderer = renderer
    }

    deinit {
        // Clean up resources
        if let bucketIndex = bucketIndex, let drawCommandIndex = drawCommandIndex, let renderer = renderer {
            _ = renderer.vertexPool.removeDrawCommand(commandIndex: drawCommandIndex)
            renderer.vertexPool.releaseBucket(bucketIndex: bucketIndex)
        }
    }

    func updateVertices(_ vertices: [Float]) {
        guard let renderer = renderer else { return }

        // Calculate how many vertices we need
        let vertexCount = vertices.count / 3 // Assuming 3 floats per position

        // Check if we need to request a new bucket
        if bucketIndex == nil || vertexCount > renderer.getMaxVerticesPerBucket() {
            // Release old bucket if we had one
            if let oldIndex = bucketIndex, let oldCmd = drawCommandIndex {
                _ = renderer.vertexPool.removeDrawCommand(commandIndex: oldCmd)
                renderer.vertexPool.releaseBucket(bucketIndex: oldIndex)
                bucketIndex = nil
                drawCommandIndex = nil
            }

            // Request new bucket
            if let (newBucketIndex, newVertexPtr, _) = renderer.vertexPool.requestBucket() {
                bucketIndex = newBucketIndex
                vertexPointer = newVertexPtr

                // Create vertices with positions from input
                for i in 0..<min(vertexCount, renderer.getMaxVerticesPerBucket()) {
                    let baseIdx = i * 3
                    if baseIdx + 2 < vertices.count {
                        let position = SIMD3<Float>(
                            vertices[baseIdx],
                            vertices[baseIdx + 1],
                            vertices[baseIdx + 2]
                        )
                        let normal = SIMD3<Float>(0, 1, 0) // Default normal
                        let color = SIMD3<Float>(1, 1, 1) // Default color

                        newVertexPtr[i] = Vertex(position: position, normal: normal, color: color)
                    }
                }

                // Add draw command
                let indexCount = UInt32((vertexCount / 4) * 6) // Assuming quads (6 indices per 4 vertices)
                drawCommandIndex = renderer.vertexPool.addDrawCommand(
                    indexCount: indexCount,
                    bucketIndex: newBucketIndex
                )

                self.vertexCount = vertexCount
            }
        } else {
            // Update existing bucket
            guard let vertexPtr = vertexPointer else { return }

            // Update vertices
            for i in 0..<min(vertexCount, renderer.getMaxVerticesPerBucket()) {
                let baseIdx = i * 3
                if baseIdx + 2 < vertices.count {
                    let position = SIMD3<Float>(
                        vertices[baseIdx],
                        vertices[baseIdx + 1],
                        vertices[baseIdx + 2]
                    )
                    let normal = SIMD3<Float>(0, 1, 0) // Default normal
                    let color = SIMD3<Float>(1, 1, 1) // Default color

                    vertexPtr[i] = Vertex(position: position, normal: normal, color: color)
                }
            }

            self.vertexCount = vertexCount
        }
    }

    // Handle different index types
    func updateIndices(_ indicesU8: [UInt8]? = nil, _ indicesU16: [UInt16]? = nil, _ indicesU32: [UInt32]? = nil) {
        // In this implementation, indices are pre-configured in the vertex pool
        // We only need to adjust the index count
        var indexCount: UInt32 = 0

        if let indices = indicesU8 {
            indexCount = UInt32(indices.count)
        } else if let indices = indicesU16 {
            indexCount = UInt32(indices.count)
        } else if let indices = indicesU32 {
            indexCount = UInt32(indices.count)
        }

        // Update the draw command with new index count if needed
        if indexCount > 0, let cmdIdx = drawCommandIndex, let bucketIndex = bucketIndex, let renderer = renderer {
            if renderer.vertexPool.removeDrawCommand(commandIndex: cmdIdx) != nil {
                drawCommandIndex = renderer.vertexPool.addDrawCommand(
                    indexCount: indexCount,
                    bucketIndex: bucketIndex
                )
            }
        }
    }
}

class MetalBatch {
    private var meshes: [UnsafeMutableRawPointer] = []
    private let renderer: MetalRenderer
    private var isDirty: Bool = false

    init(renderer: MetalRenderer) {
        self.renderer = renderer
    }

    func addMesh(_ mesh: UnsafeMutableRawPointer) {
        if !meshes.contains(where: { $0 == mesh }) {
            meshes.append(mesh)
            isDirty = true
        }
    }

    func removeMesh(_ mesh: UnsafeMutableRawPointer) {
        let count = meshes.count
        meshes.removeAll { $0 == mesh }
        if count != meshes.count {
            isDirty = true
        }
    }

    func queueDraw() {
        // Mark the batch for drawing in the next frame
        if isDirty {
            // The meshes are already in the vertex pool's draw commands
            // Just update the pool's state to ensure these meshes are drawn
            renderer.vertexPool.updateIndirectBuffer()
            isDirty = false
        }
    }
}

class MetalCamera {
    var projectionMatrix = matrix_identity_float4x4
    var transformMatrix = matrix_identity_float4x4

    weak var renderer: MetalRenderer?

    init(renderer: MetalRenderer) {
        self.renderer = renderer
    }

    func setProjection(_ projectionData: [Float]) {
        guard projectionData.count >= 16 else { return }

        var matrix = matrix_identity_float4x4
        for i in 0..<4 {
            for j in 0..<4 {
                matrix[i][j] = projectionData[i*4 + j]
            }
        }

        projectionMatrix = matrix

        if let renderer = renderer {
            renderer.updateCameraUniforms()
        }
    }

    func setTransform(_ transformData: [Float]) {
        guard transformData.count >= 16 else { return }

        var matrix = matrix_identity_float4x4
        for i in 0..<4 {
            for j in 0..<4 {
                matrix[i][j] = transformData[i*4 + j]
            }
        }

        transformMatrix = matrix

        if let renderer = renderer {
            renderer.updateCameraUniforms()
        }
    }
}

// MARK: - Metal Renderer

class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
     let metalView: MTKView
    
    private let bucketSize: Int = 1024 // Maximum vertices per bucket
    private let maxBuckets: Int = 256  // Maximum number of buckets

    let vertexPool: VertexPool
    var mainCamera: MetalCamera?
    private var uniformsBuffer: MTLBuffer
    private var depthStencilState: MTLDepthStencilState?

    struct Uniforms {
        var projectionMatrix: matrix_float4x4
        var viewMatrix: matrix_float4x4
    }

    // MTKViewDelegate methods
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle window resize
    }
    
    func draw(in view: MTKView) {
        guard let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        if let depthState = depthStencilState {
            renderEncoder.setDepthStencilState(depthState)
        }
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(uniformsBuffer, offset: 0, index: 0)
        
        // Draw using vertex pool
        vertexPool.draw(commandBuffer: commandBuffer, renderEncoder: renderEncoder)
        
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }

    init(view: MTKView) {
        metalView = view

        // Set up Metal device
        self.device = MTLCreateSystemDefaultDevice() ?? {
            fatalError("Failed to create Metal device")
        }()
        
        // Configure the view with our device
        view.device = self.device
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        view.depthStencilPixelFormat = .depth32Float
        view.sampleCount = 1
        view.preferredFramesPerSecond = 60
        
        // Configure drawable size to match view size
        if let window = view.window {
            let scale = window.screen?.backingScaleFactor ?? 1.0
            
        }

        // Create command queue
        guard let queue = device.makeCommandQueue() else {
            fatalError("Failed to create command queue")
        }
        self.commandQueue = queue

        // Create vertex pool
        vertexPool = VertexPool(device: device, bucketSize: bucketSize, maxBuckets: maxBuckets)

        // Create uniforms buffer
        uniformsBuffer = device.makeBuffer(
            length: MemoryLayout<Uniforms>.stride,
            options: [.storageModeShared]
        )!

        // Create Metal shader library
        let shaderSource = createDefaultShaders()
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            print("Failed to create Metal library: \(error)")
            fatalError("Metal shader compilation failed")
        }

        // Create pipeline state
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Create depth stencil state
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        self.depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)

        // Create vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()

        // Position attribute
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        // Normal attribute
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0

        // Color attribute
        vertexDescriptor.attributes[2].format = .float4
        vertexDescriptor.attributes[2].offset = MemoryLayout<SIMD3<Float>>.stride * 2
        vertexDescriptor.attributes[2].bufferIndex = 0

        // Vertex layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    func getMaxVerticesPerBucket() -> Int {
        return bucketSize
    }

    func updateCameraUniforms() {
        guard let camera = mainCamera else { return }

        let uniforms = uniformsBuffer.contents().bindMemory(to: Uniforms.self, capacity: 1)
        uniforms.pointee.projectionMatrix = camera.projectionMatrix
        uniforms.pointee.viewMatrix = camera.transformMatrix
    }

    private func createDepthTexture(width: Int, height: Int) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .depth32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .private

        return device.makeTexture(descriptor: descriptor)!
    }
}

// MARK: - FFI Interface

// Helper to convert C pointers to Swift objects
extension UnsafeMutableRawPointer {
    func toObject<T: AnyObject>(as type: T.Type) -> T? {
        return Unmanaged<T>.fromOpaque(self).takeUnretainedValue()
    }

    static func fromObject<T: AnyObject>(_ object: T) -> UnsafeMutableRawPointer {
        return Unmanaged.passRetained(object).toOpaque()
    }

    func releaseObject<T: AnyObject>(_ type: T.Type) {
        _ = Unmanaged<T>.fromOpaque(self).takeRetainedValue()
    }
}

// FFI functions
@_cdecl("metal_renderer_create")
public func metal_renderer_create(surface_ptr: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
    print("Creating Metal renderer with provided surface \(surface_ptr)")

    let surface = surface_ptr.toObject(as: Surface.self)
    guard let metalView = surface?.contentView else {
        print("Failed to get Metal view from surface")
        return UnsafeMutableRawPointer(bitPattern: 0)!
    }

    let renderer = MetalRenderer(view: metalView)
    return UnsafeMutableRawPointer.fromObject(renderer)
}

@_cdecl("metal_renderer_destroy")
public func metal_renderer_destroy(renderer_ptr: UnsafeMutableRawPointer) {
    let renderer = Unmanaged<MetalRenderer>.fromOpaque(renderer_ptr).takeRetainedValue()
    renderer.metalView.delegate = nil
}

@_cdecl("metal_mesh_create")
public func metal_mesh_create(renderer_ptr: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
    guard let renderer = renderer_ptr.toObject(as: MetalRenderer.self) else {
        return UnsafeMutableRawPointer(bitPattern: 0)!
    }

    let mesh = MetalMesh(renderer: renderer)
    return UnsafeMutableRawPointer.fromObject(mesh)
}

@_cdecl("metal_mesh_destroy")
public func metal_mesh_destroy(renderer_ptr: UnsafeMutableRawPointer, mesh_ptr: UnsafeMutableRawPointer) {
    mesh_ptr.releaseObject(MetalMesh.self)
}

@_cdecl("metal_mesh_update_vertices")
public func metal_mesh_update_vertices(renderer_ptr: UnsafeMutableRawPointer, mesh_ptr: UnsafeMutableRawPointer, vertices: UnsafePointer<Float>, count: Int) {
    guard let mesh = mesh_ptr.toObject(as: MetalMesh.self) else { return }

    let verticesArray = Array(UnsafeBufferPointer(start: vertices, count: count))
    mesh.updateVertices(verticesArray)
}

@_cdecl("metal_mesh_update_indices_u8")
public func metal_mesh_update_indices_u8(renderer_ptr: UnsafeMutableRawPointer, mesh_ptr: UnsafeMutableRawPointer, indices: UnsafePointer<UInt8>, count: Int) {
    guard let mesh = mesh_ptr.toObject(as: MetalMesh.self) else { return }

    let indicesArray = Array(UnsafeBufferPointer(start: indices, count: count))
    mesh.updateIndices(indicesArray, nil, nil)
}

@_cdecl("metal_mesh_update_indices_u16")
public func metal_mesh_update_indices_u16(renderer_ptr: UnsafeMutableRawPointer, mesh_ptr: UnsafeMutableRawPointer, indices: UnsafePointer<UInt16>, count: Int) {
    guard let mesh = mesh_ptr.toObject(as: MetalMesh.self) else { return }

    let indicesArray = Array(UnsafeBufferPointer(start: indices, count: count))
    mesh.updateIndices(nil, indicesArray, nil)
}

@_cdecl("metal_mesh_update_indices_u32")
public func metal_mesh_update_indices_u32(renderer_ptr: UnsafeMutableRawPointer, mesh_ptr: UnsafeMutableRawPointer, indices: UnsafePointer<UInt32>, count: Int) {
    guard let mesh = mesh_ptr.toObject(as: MetalMesh.self) else { return }

    let indicesArray = Array(UnsafeBufferPointer(start: indices, count: count))
    mesh.updateIndices(nil, nil, indicesArray)
}

@_cdecl("metal_batch_create")
public func metal_batch_create(renderer_ptr: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
    guard let renderer = renderer_ptr.toObject(as: MetalRenderer.self) else {
        return UnsafeMutableRawPointer(bitPattern: 0)!
    }

    let batch = MetalBatch(renderer: renderer)
    return UnsafeMutableRawPointer.fromObject(batch)
}

@_cdecl("metal_batch_destroy")
public func metal_batch_destroy(renderer_ptr: UnsafeMutableRawPointer, batch_ptr: UnsafeMutableRawPointer) {
    batch_ptr.releaseObject(MetalBatch.self)
}

@_cdecl("metal_batch_add_mesh")
public func metal_batch_add_mesh(renderer_ptr: UnsafeMutableRawPointer, batch_ptr: UnsafeMutableRawPointer, mesh_ptr: UnsafeMutableRawPointer) {
    guard let batch = batch_ptr.toObject(as: MetalBatch.self) else { return }
    batch.addMesh(mesh_ptr)
}

@_cdecl("metal_batch_remove_mesh")
public func metal_batch_remove_mesh(renderer_ptr: UnsafeMutableRawPointer, batch_ptr: UnsafeMutableRawPointer, mesh_ptr: UnsafeMutableRawPointer) {
    guard let batch = batch_ptr.toObject(as: MetalBatch.self) else { return }
    batch.removeMesh(mesh_ptr)
}

@_cdecl("metal_batch_queue_draw")
public func metal_batch_queue_draw(renderer_ptr: UnsafeMutableRawPointer, batch_ptr: UnsafeMutableRawPointer) {
    guard let batch = batch_ptr.toObject(as: MetalBatch.self) else { return }
    batch.queueDraw()
}

@_cdecl("metal_camera_create")
public func metal_camera_create(renderer_ptr: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer {
    guard let renderer = renderer_ptr.toObject(as: MetalRenderer.self) else {
        return UnsafeMutableRawPointer(bitPattern: 0)!
    }

    let camera = MetalCamera(renderer: renderer)
    return UnsafeMutableRawPointer.fromObject(camera)
}

@_cdecl("metal_camera_set_projection")
public func metal_camera_set_projection(renderer_ptr: UnsafeMutableRawPointer, camera_ptr: UnsafeMutableRawPointer, projection: UnsafePointer<Float>) {
    guard let camera = camera_ptr.toObject(as: MetalCamera.self) else { return }

    let projectionArray = Array(UnsafeBufferPointer(start: projection, count: 16))
    camera.setProjection(projectionArray)
}

@_cdecl("metal_camera_set_transform")
public func metal_camera_set_transform(renderer_ptr: UnsafeMutableRawPointer, camera_ptr: UnsafeMutableRawPointer, transform: UnsafePointer<Float>) {
    guard let camera = camera_ptr.toObject(as: MetalCamera.self) else { return }

    let transformArray = Array(UnsafeBufferPointer(start: transform, count: 16))
    camera.setTransform(transformArray)
}

@_cdecl("metal_camera_set_main")
public func metal_camera_set_main(renderer_ptr: UnsafeMutableRawPointer, camera_ptr: UnsafeMutableRawPointer) {
    guard let renderer = renderer_ptr.toObject(as: MetalRenderer.self),
          let camera = camera_ptr.toObject(as: MetalCamera.self) else { return }

    renderer.mainCamera = camera
}

@_cdecl("metal_frame_begin")
public func metal_frame_begin(renderer_ptr: UnsafeMutableRawPointer) {
}

@_cdecl("metal_frame_commit_draw")
public func metal_frame_commit_draw(renderer_ptr: UnsafeMutableRawPointer) {
}

@_cdecl("metal_frame_end")
public func metal_frame_end(renderer_ptr: UnsafeMutableRawPointer) {
}
