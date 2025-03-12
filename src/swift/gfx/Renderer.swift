import Metal
import MetalKit

class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLRenderPipelineState
    let vertexBuffer: MTLBuffer
    
    // Define the vertex structure
    struct Vertex {
        var position: SIMD3<Float>
        var color: SIMD4<Float>
    }
    
    init(device: MTLDevice) {
        self.device = device
        
        // Create the command queue
        commandQueue = device.makeCommandQueue()!
        
        // Create triangle vertices (position and color)
        let vertices = [
            Vertex(position: SIMD3<Float>( 0,  1, 0), color: SIMD4<Float>(1, 0, 0, 1)),  // Top (red)
            Vertex(position: SIMD3<Float>(-1, -1, 0), color: SIMD4<Float>(0, 1, 0, 1)),  // Bottom left (green)
            Vertex(position: SIMD3<Float>( 1, -1, 0), color: SIMD4<Float>(0, 0, 1, 1))   // Bottom right (blue)
        ]
        
        // Create vertex buffer
        let bufferSize = MemoryLayout<Vertex>.stride * vertices.count
        vertexBuffer = device.makeBuffer(bytes: vertices, length: bufferSize, options: [])!
        
        // Load the shader functions from the library
        let library = device.makeDefaultLibrary()!
        let vertexFunction = library.makeFunction(name: "vertexShader")
        let fragmentFunction = library.makeFunction(name: "fragmentShader")
        
        // Set up the render pipeline
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        
        // Set up color attachments
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        // Create the pipeline state
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
        
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle window resize if needed
    }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor else { return }
        
        // Create command buffer for this frame
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        // Create render command encoder
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Set the vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Draw the triangle
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        
        // End encoding and commit
        renderEncoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
