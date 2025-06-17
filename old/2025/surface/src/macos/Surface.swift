import Cocoa
import Foundation
import Metal
import MetalKit

// MARK: - Data Structures

@frozen public struct Surface {
  public let id: UInt64  // u64 -> UInt64

  init(id: UInt64) {
    self.id = id
  }

  public class View: NSViewController {
    var metalView: MTKView!
    var device: MTLDevice!
    var window: NSWindow!
    var deltaTime: Float = 0.0
    var totalDeltaX: Float = 0.0
    var totalDeltaY: Float = 0.0
    var keysPressed: Set<Key> = []

    var inputHandler: InputHandler?

    public override func viewDidLoad() {
      super.viewDidLoad()

      print("View did load for surface controller")

      setenv("MTL_SHADER_VALIDATION", "1", 1)
      setenv("MTL_DEBUG_LAYER", "1", 1)

      // Check permissions early
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        let checkOptionsPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
        let options = [checkOptionsPrompt: true] as CFDictionary
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
      }

      // Create the Metal view
      metalView = MTKView(frame: view.bounds)
      metalView.device = MTLCreateSystemDefaultDevice()
      metalView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
      metalView.autoresizingMask = [.width, .height]
      view.addSubview(metalView)

      guard let metal_device = metalView.device else {
        fatalError("Device not created. Run on a physical device.")
      }

      device = metal_device

      // IMPORTANT: Store the window reference immediately after view loads
      if let windowObj = self.view.window {
        window = windowObj
        print("Window reference initialized successfully: \(windowObj)")
      } else {
        print("WARNING: Window reference is nil in viewDidLoad")
      }

      NSApp.setActivationPolicy(.regular)
      NSApp.activate(ignoringOtherApps: true)

      // Initialize inputHhandler
      inputHandler = InputHandler(viewController: self, metalView: metalView)

      // Make metalView a custom subclass of MTKView that can handle key events
      if let oldMetalView = metalView {
        class KeyHandlingMTKView: MTKView {
          var onKeyDown: ((NSEvent) -> Void)?
          var onKeyUp: ((NSEvent) -> Void)?
          // Added property for mouse movement
          var onMouseMoved: ((NSEvent) -> Void)?

          override var acceptsFirstResponder: Bool { return true }

          override func keyDown(with event: NSEvent) {
            print("KeyHandlingMTKView: keyDown \(event.keyCode)")
            onKeyDown?(event)
            super.keyDown(with: event)
          }

          override func keyUp(with event: NSEvent) {
            print("KeyHandlingMTKView: keyUp \(event.keyCode)")
            onKeyUp?(event)
            super.keyUp(with: event)
          }

          // Override mouseMoved to forward events
          override func mouseMoved(with event: NSEvent) {
            print("KeyHandlingMTKView: mouseMoved \(event.locationInWindow)")
            onMouseMoved?(event)
            super.mouseMoved(with: event)
          }
        }

        // Create custom view
        let keyMetalView = KeyHandlingMTKView(
          frame: oldMetalView.frame, device: oldMetalView.device)
        keyMetalView.clearColor = oldMetalView.clearColor
        keyMetalView.autoresizingMask = oldMetalView.autoresizingMask
        keyMetalView.depthStencilPixelFormat = oldMetalView.depthStencilPixelFormat

        // NEW: Add tracking area for mouse moved events
        let trackingArea = NSTrackingArea(
          rect: keyMetalView.bounds,
          options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
          owner: keyMetalView,
          userInfo: nil)
        keyMetalView.addTrackingArea(trackingArea)

        // Set key handlers
        keyMetalView.onKeyDown = { [weak self, weak inputHandler] event in
          print("Direct keyDown in MTKView: \(event.keyCode)")
          inputHandler?.handleKeyEvent(event)

        }

        keyMetalView.onKeyUp = { [weak self, weak inputHandler] event in
          print("Direct keyUp in MTKView: \(event.keyCode)")
          inputHandler?.handleKeyEvent(event)

        }

        // Added mouse moved callback to forward mouse movement events
        keyMetalView.onMouseMoved = { [weak self, weak inputHandler] event in
          print("Direct mouseMoved in MTKView: \(event.locationInWindow)")
          inputHandler?.handleMouseMovement(
            deltaX: Float(event.deltaX), deltaY: Float(event.deltaY))
        }

        // Replace the old view
        oldMetalView.removeFromSuperview()
        view.addSubview(keyMetalView)
        metalView = keyMetalView
      }

      // Set up simplified callbacks (more like the old working code)
      inputHandler?.setKeyPressCallback { [weak self] key, isPressed in
        guard let self = self else { return }
        print("Key callback: \(key) \(isPressed ? "pressed" : "released")")

        // Directly modify our local set
        if isPressed {
          self.keysPressed.insert(key)
        } else {
          self.keysPressed.remove(key)
        }

      }

      // Add a timer to process input regularly
      let timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) {
        [weak self] _ in
        guard let self = self else { return }
        self.processInput()
      }
      RunLoop.current.add(timer, forMode: .common)

      inputHandler?.setMouseMoveCallback { [weak self] deltaX, deltaY in
        self?.deltaTime = 1.0 / Float(self?.metalView.preferredFramesPerSecond ?? Int(60))
        self?.totalDeltaX += deltaX
        self?.totalDeltaY += deltaY
        print("Mouse moved: deltaX = \(deltaX), deltaY = \(deltaY)")
      }

      // Register for key events directly
      inputHandler?.registerViewForKeyEvents()

      // Make sure our view responds to key events
      view.window?.makeFirstResponder(metalView)

    }

    // Override responder methods to catch key events
    public override var acceptsFirstResponder: Bool { return true }

    public override func keyDown(with event: NSEvent) {
      print("Direct keyDown in ViewController: \(event.keyCode)")

      super.keyDown(with: event)
    }

    public override func keyUp(with event: NSEvent) {
      print("Direct keyUp in ViewController: \(event.keyCode)")

      super.keyUp(with: event)
    }

    func processInput() {

    }

    public override func mouseDown(with event: NSEvent) {
      print("Mouse down")
      super.mouseDown(with: event)
      self.inputHandler?.handleMouseClick(at: event.locationInWindow)
    }

    public override func mouseMoved(with event: NSEvent) {
      print("Mouse moved")
      super.mouseMoved(with: event)
      self.inputHandler?.handleMouseMovement(
        deltaX: Float(event.deltaX), deltaY: Float(event.deltaY))
    }

    public override func viewWillAppear() {
      super.viewWillAppear()

      // Another chance to grab the window reference if it wasn't available in viewDidLoad
      if window == nil, let windowObj = self.view.window {
        window = windowObj
        window.acceptsMouseMovedEvents = true
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(metalView)
        window.ignoresMouseEvents = false
        print("Window reference initialized in viewWillAppear: \(windowObj)")
      }
    }
  }
}

public var surfaceViews: [UInt64: UnsafeMutablePointer<Surface.View>] = [:]
@_cdecl("createSurface")
public func createSurface() -> UnsafeMutableRawPointer? {
  // Placeholder: In a real implementation, you would allocate
  // memory for the Surface struct *and* any underlying platform-specific
  // data.  You would then return a pointer to the Swift struct.
  // For this stub, we just create a unique ID.

  // IMPORTANT:  This example leaks memory!  A *real* implementation
  // would need to carefully manage the memory allocated here, and free
  // it in the `destroy` function.  This example is *only* for illustrating
  // the Swift/C function signatures and data structure usage.

  let surfaceId = UInt64(arc4random())  // Generate a random ID.  Don't do this in real code.
  let surface = Surface(id: surfaceId)

  //Create a pointer to pass back
  let surfaceRawPointer = UnsafeMutableRawPointer.allocate(byteCount: 8, alignment: 8)
  let surfacePointer = surfaceRawPointer.bindMemory(to: Surface.self, capacity: 1)
  surfacePointer.pointee = surface

  let windowRect = NSRect(x: 100, y: 100, width: 800, height: 600)
  let window = NSWindow(
    contentRect: windowRect,
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false)

  window.title = "Metal Hello Triangle"

  // Simplified window creation - no forced activation
  window.makeKeyAndOrderFront(nil)

  let viewRawPointer = UnsafeMutablePointer<Surface.View>.allocate(capacity: 1)
  viewRawPointer.initialize(to: Surface.View())  // Initialize the view with a default coder

  window.contentViewController = viewRawPointer.pointee

  surfaceViews.updateValue(viewRawPointer, forKey: surfaceId)

  print("Surface created (Swift): id = \(surfaceId)")
  return surfaceRawPointer
}

@_cdecl("destroySurface")
public func destroySurface(s: UnsafeMutableRawPointer?) {
  guard let surfacePtr = s else {
    print("destroy called with null pointer")
    return
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  surfaceViews[id]?.deinitialize(count: 1)  // Deinitialize the view
  surfacePtr.deallocate()
  print("Surface destroyed (Swift): id = \(surfacePtr)")

}

@_cdecl("supportsMultiple")
public func supportsMultiple() -> Bool {
  print("supportsMultiple (Swift)")
  return false  // Or true, depending on your implementation.
}

@_cdecl("poll")
public func poll() {
  print("poll (Swift)")
}

@_cdecl("setName")
public func setName(s: UnsafeMutableRawPointer?, name: UnsafeRawPointer?) {
  guard let surfacePtr = s, let namePtr = name else {
    return
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee {
    // Convert C string to Swift string
    let nameString = String(cString: namePtr.assumingMemoryBound(to: CChar.self))
    print("setName (Swift): id = \(id), name = \(nameString)")
    // Update window title on main thread
    DispatchQueue.main.async {
      view.window?.title = nameString
    }
  }
}

@_cdecl("getName")
public func getName(s: UnsafeMutableRawPointer?) -> UnsafeRawPointer? {
  guard let surfacePtr = s else {
    print("getName called with null pointer")
    return nil
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee, let windowTitle = view.window?.title {
    // Allocate memory that will be owned by the caller - they MUST free this
    if let cString = windowTitle.withCString(strdup) {
      return UnsafeRawPointer(cString)
    }
  }

  // Return default name if no window or title found
  return UnsafeRawPointer(strdup("Unnamed Surface"))
}

@_cdecl("setSize")
public func setSize(s: UnsafeMutableRawPointer?, width: UInt32, height: UInt32) {
  guard let surfacePtr = s else {
    print("setSize called with null pointer")
    return
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee {
    DispatchQueue.main.async {
      let newSize = NSSize(width: CGFloat(width), height: CGFloat(height))
      view.window?.setContentSize(newSize)
    }
  }

  print("setSize (Swift): id = \(id), width = \(width), height = \(height)")
}

@_cdecl("getSize")
public func getSize(
  s: UnsafeMutableRawPointer?, out_width: UnsafeMutablePointer<UInt32>?,
  out_height: UnsafeMutablePointer<UInt32>?
) {
  guard let surfacePtr = s, let widthPtr = out_width, let heightPtr = out_height else {
    print("getSize called with null pointer")
    return
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee, let window = view.window {
    let size = window.contentView?.frame.size ?? NSSize(width: 800, height: 600)
    widthPtr.pointee = UInt32(size.width)
    heightPtr.pointee = UInt32(size.height)
  } else {
    // Default values if no window found
    widthPtr.pointee = 800
    heightPtr.pointee = 600
  }
}

@_cdecl("setResizable")
public func setResizable(s: UnsafeMutableRawPointer?, resizable: Bool) {
  guard let surfacePtr = s else {
    print("setResizable called with null pointer")
    return
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee {
    DispatchQueue.main.async {
      var styleMask = view.window?.styleMask ?? []

      if resizable {
        styleMask.insert(.resizable)
      } else {
        styleMask.remove(.resizable)
      }

      view.window?.styleMask = styleMask
    }
  }

  print("setResizable (Swift): id = \(id), resizable = \(resizable)")
}

@_cdecl("isResizable")
public func isResizable(s: UnsafeMutableRawPointer?) -> Bool {
  guard let surfacePtr = s else {
    print("isResizable called with null pointer")
    return false
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee {
    return (view.window?.styleMask.contains(.resizable)) ?? false
  }

  return false
}

@_cdecl("setFullscreen")
public func setFullscreen(s: UnsafeMutableRawPointer?, fullscreen: Bool) {
  guard let surfacePtr = s else {
    print("setFullScreen called with null pointer")
    return
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee, let window = view.window {
    DispatchQueue.main.async {
      if fullscreen && !window.styleMask.contains(.fullScreen) {
        window.toggleFullScreen(nil)
      } else if !fullscreen && window.styleMask.contains(.fullScreen) {
        window.toggleFullScreen(nil)
      }
    }
  }

  print("setFullscreen (Swift): id = \(id), fullscreen = \(fullscreen)")
}

@_cdecl("isFullscreen")
public func isFullscreen(s: UnsafeMutableRawPointer?) -> Bool {
  guard let surfacePtr = s else {
    print("isFullscreen called with null pointer")
    return false
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee {
    return (view.window?.styleMask.contains(.fullScreen)) ?? false
  }

  return false
}

@_cdecl("setVSync")
public func setVSync(s: UnsafeMutableRawPointer?, vsync: Bool) {
  guard let surfacePtr = s else {
    print("setVsync called with null pointer")
    return
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee {
    DispatchQueue.main.async {
      view.metalView?.isPaused = !vsync
      view.metalView?.enableSetNeedsDisplay = !vsync
    }
  }

  print("setVSync (Swift): id = \(id), vsync = \(vsync)")
}

@_cdecl("isVSync")
public func isVSync(s: UnsafeMutableRawPointer?) -> Bool {
  guard let surfacePtr = s else {
    print("isVSync called with null pointer")
    return false
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee {
    return !(view.metalView?.isPaused ?? true)
  }

  return false
}

@_cdecl("showCursor")
public func showCursor(s: UnsafeMutableRawPointer?, show: Bool) {
  DispatchQueue.main.async {
    if show {
      NSCursor.unhide()
    } else {
      NSCursor.hide()
    }
  }
}

@_cdecl("confineCursor")
public func confineCursor(s: UnsafeMutableRawPointer?, confine: Bool) {
  guard let surfacePtr = s else {
    print("confineCursor called with null pointer")
    return
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  // Note: macOS doesn't have a simple API for cursor confinement
  // A more complete implementation would use CGEventTap to monitor and reposition the cursor

  print("confineCursor (Swift): id = \(id), confine = \(confine)")
}

@_cdecl("focus")
public func focus(s: UnsafeMutableRawPointer?) {
  guard let surfacePtr = s else {
    print("focus called with null pointer")
    return
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee {
    DispatchQueue.main.async {
      view.window?.makeKeyAndOrderFront(nil)
    }
  }

  print("focus (Swift): id = \(id)")
}

@_cdecl("isFocused")
public func isFocused(s: UnsafeMutableRawPointer?) -> Bool {
  guard let surfacePtr = s else {
    print("isFocused called with null pointer")
    return false
  }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  if let view = surfaceViews[id]?.pointee {
    return view.window?.isKeyWindow ?? false
  }

  return false
}

@_cdecl("pollEvents")
public func pollEvents(s: UnsafeMutableRawPointer?) {
  guard let surfacePtr = s else { return }

  let surface = surfacePtr.bindMemory(to: Surface.self, capacity: 1)
  let id = surface.pointee.id

  // Process pending events without forcing window activation
  if Thread.isMainThread {
    processEventsOnMainThread()
  } else {
    // If not on main thread, dispatch to main thread
    DispatchQueue.main.async {
      processEventsOnMainThread()
    }
  }
}

// Helper function to process events on the main thread
private func processEventsOnMainThread() {
  autoreleasepool {
    let currentEvent = NSApp.currentEvent
    print("Current event: \(String(describing: currentEvent))")

    // Force event processing
    while let event = NSApp.nextEvent(matching: .any, until: nil, inMode: .default, dequeue: true) {
      print("Processing event: \(event)")
      NSApp.sendEvent(event)
    }
  }
}
