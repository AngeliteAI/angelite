import Foundation
import Metal

/// Error types for pipeline operations
enum PipelineError: Error {
  case libraryNotFound
  case functionNotFound(name: String)
  case pipelineCreationFailed(name: String, error: Error)
  case pipelineNotFound(name: String)
  case invalidPipelineType
}

/// A type-erased wrapper for any Metal pipeline state
class AnyPipelineState {
  let name: String
  private let _object: Any

  init(name: String, object: Any) {
    self.name = name
    self._object = object
  }

  // Modified to include explicit type parameter
  func object<T>(as type: T.Type) -> T? {
    return _object as? T
  }
}

/// Manager for handling Metal pipelines with hot-reloading capability
class PipelineManager {
  private let device: MTLDevice
  private var pipelines: [String: AnyPipelineState] = [:]
  private var libraryURL: URL?
  private var lastModificationDate: Date?
  private var libraryWatcher: DispatchSourceFileSystemObject?
  let shaderSource: String
  let library: MTLLibrary
  // File monitoring queue
  private let monitorQueue = DispatchQueue(label: "com.pipeline.monitor", qos: .utility)

  init(device: MTLDevice) {
    self.device = device
    do {
      let path = URL(
        fileURLWithPath: "/Users/solmidnight/work/angelite/src/gfx/src/macos/Shaders.metal")

      // Check if file exists before attempting to load
      guard FileManager.default.fileExists(atPath: path.path) else {
        print("Metal library file not found at: \(path.path)")
        throw PipelineError.libraryNotFound
      }

      // Load the library from the specified path
      do {
        shaderSource = try String(contentsOf: path, encoding: .utf8)
      } catch {
        print("Error loading Metal library source: \(error)")
        throw PipelineError.libraryNotFound
      }
      /*
        guard let buffer = device.makeBuffer(bytes: &amp;array64Bit, length: MemoryLayout&lt;UInt64>.stride * array64Bit.count) else {
                    throw InitError.bufferIsNil
        }
        self.bufferResult = buffer
        [...]
        commandEncoder.setBuffer(bufferResult, offset: 0, index: 0)
        [...]
        let bufferResultPtr = bufferResult.contents().assumingMemoryBound(to: UInt64.self)
        let bufferResultArray = UnsafeMutableBufferPointer(start: bufferResultPtr, count: array64Bit.count)
        */
      let compileOptions = MTLCompileOptions()
      print("Compiling Metal shader with options: \(compileOptions)")
      compileOptions.languageVersion = .version3_2

      compileOptions.fastMathEnabled = false
      compileOptions.mathMode = .relaxed
      print("Updated compile options: \(compileOptions)")

      library = try device.makeLibrary(source: shaderSource, options: compileOptions)
    } catch {
      fatalError("Failed to create Metal library: \(error)")
    }
    // Try to find the default library's URL for monitoring
    if let libraryPath = Bundle.main.path(forResource: "default", ofType: "metallib") {
      libraryURL = URL(fileURLWithPath: libraryPath)
      lastModificationDate = try? libraryURL?.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate
      setupLibraryWatcher()
    }

  }

  // Setup file monitoring for auto-reloading
  private func setupLibraryWatcher() {
    guard let url = libraryURL else { return }

    let fileDescriptor = open(url.path, O_EVTONLY)
    guard fileDescriptor >= 0 else { return }

    libraryWatcher = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fileDescriptor,
      eventMask: .write,
      queue: monitorQueue
    )

    libraryWatcher?.setEventHandler { [weak self] in
      self?.checkForLibraryChanges()
    }

    libraryWatcher?.setCancelHandler {
      close(fileDescriptor)
    }

    libraryWatcher?.resume()
  }

  // Check if the library file has been modified
  private func checkForLibraryChanges() {
    guard let url = libraryURL else { return }

    do {
      let newDate = try url.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate

      if let lastDate = lastModificationDate, let newDate = newDate, newDate > lastDate {
        lastModificationDate = newDate

        // Reload all pipelines on the main thread
        DispatchQueue.main.async { [weak self] in
          self?.reloadAllPipelines()
        }
      }
    } catch {
      print("Error checking library modification date: \(error)")
    }
  }

  // Reload all registered pipelines
  private func reloadAllPipelines() {
    print("🔄 Metal library changed, reloading pipelines...")

    // Store current pipeline names and definitions
    let currentPipelines = pipelines

    // Clear pipeline cache
    pipelines.removeAll()

    // Recreate each pipeline
    for (name, pipeline) in currentPipelines {
      do {
        // FIX: Use explicit type parameter with object(as:)
        if pipeline.object(as: MTLComputePipelineState.self) != nil {
          if let funcName = extractFunctionName(fromPipelineName: name) {
            _ = try createComputePipeline(name: name, functionName: funcName)
            print("✅ Reloaded compute pipeline: \(name)")
          }
        } else if pipeline.object(as: MTLRenderPipelineState.self) != nil {
          // For render pipelines, we need to store more metadata for recreation
          // This is a simplified example, you might need more parameters
          print("⚠️ Render pipeline reloading not fully implemented for: \(name)")
        }
      } catch {
        print("❌ Failed to reload pipeline \(name): \(error)")
      }
    }
  }

  // Helper to extract the function name from a pipeline name
  // This assumes pipelines are named with convention "purpose_functionName"
  private func extractFunctionName(fromPipelineName name: String) -> String? {
    let components = name.split(separator: "_")
    if components.count >= 2 {
      return String(components[1])
    }
    return name  // Fallback to using the full name
  }

  func getFunction(name: String) throws -> MTLFunction {
    guard let function = library.makeFunction(name: name) else {
      throw PipelineError.functionNotFound(name: name)
    }
    return function
  }

  // Create a compute pipeline with specified name and function
  func createComputePipeline(name: String, functionName: String) throws -> MTLComputePipelineState {
    let function = try getFunction(name: functionName)
    do {
      let pipelineState = try device.makeComputePipelineState(function: function)
      let anyPipeline = AnyPipelineState(name: name, object: pipelineState)
      pipelines[name] = anyPipeline
      return pipelineState
    } catch {
      throw PipelineError.pipelineCreationFailed(name: name, error: error)
    }
  }

  // Create a render pipeline with a descriptor
  func createRenderPipeline(name: String, descriptor: MTLRenderPipelineDescriptor) throws
    -> MTLRenderPipelineState
  {
    do {
      let pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
      let anyPipeline = AnyPipelineState(name: name, object: pipelineState)
      pipelines[name] = anyPipeline
      return pipelineState
    } catch {
      throw PipelineError.pipelineCreationFailed(name: name, error: error)
    }
  }

  // Get a compute pipeline by name
  func getComputePipeline(name: String) throws -> MTLComputePipelineState {
    guard let pipeline = pipelines[name] else {
      throw PipelineError.pipelineNotFound(name: name)
    }

    // FIX: Use explicit type parameter with object(as:)
    guard let computePipeline = pipeline.object(as: MTLComputePipelineState.self) else {
      throw PipelineError.invalidPipelineType
    }

    return computePipeline
  }

  // Get a render pipeline by name
  func getRenderPipeline(name: String) throws -> MTLRenderPipelineState {
    guard let pipeline = pipelines[name] else {
      throw PipelineError.pipelineNotFound(name: name)
    }

    // FIX: Use explicit type parameter with object(as:)
    guard let renderPipeline = pipeline.object(as: MTLRenderPipelineState.self) else {
      throw PipelineError.invalidPipelineType
    }

    return renderPipeline
  }

  // Create a compute pipeline if it doesn't exist, otherwise return the existing one
  func getOrCreateComputePipeline(name: String, functionName: String) throws
    -> MTLComputePipelineState
  {
    if let pipeline = pipelines[name] {
      // FIX: Use explicit type parameter with object(as:)
      if let computePipeline = pipeline.object(as: MTLComputePipelineState.self) {
        return computePipeline
      } else {
        throw PipelineError.invalidPipelineType
      }
    } else {
      return try createComputePipeline(name: name, functionName: functionName)
    }
  }

  // Check if a pipeline with the given name exists
  func hasPipeline(name: String) -> Bool {
    return pipelines[name] != nil
  }

  // Remove a pipeline from the cache
  func removePipeline(name: String) {
    pipelines.removeValue(forKey: name)
  }

  // Clear all cached pipelines
  func clearPipelines() {
    pipelines.removeAll()
  }

  // Cleanup resources
  deinit {
    libraryWatcher?.cancel()
  }
}

// Extension with convenience methods for common pipeline descriptors
extension PipelineManager {
  // Create a basic render pipeline descriptor with vertex and fragment functions
  func createBasicRenderPipelineDescriptor(
    vertexFunction: String,
    fragmentFunction: String,
    pixelFormat: MTLPixelFormat = .bgra8Unorm,
    depthFormat: MTLPixelFormat = .depth32Float
  ) throws -> MTLRenderPipelineDescriptor {
    guard let library = device.makeDefaultLibrary() else {
      throw PipelineError.libraryNotFound
    }

    guard let vertexFunc = library.makeFunction(name: vertexFunction) else {
      throw PipelineError.functionNotFound(name: vertexFunction)
    }

    guard let fragmentFunc = library.makeFunction(name: fragmentFunction) else {
      throw PipelineError.functionNotFound(name: fragmentFunction)
    }

    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = vertexFunc
    descriptor.fragmentFunction = fragmentFunc
    descriptor.colorAttachments[0].pixelFormat = pixelFormat
    descriptor.depthAttachmentPixelFormat = depthFormat

    return descriptor
  }
}
