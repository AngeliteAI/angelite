import Cocoa
import Metal
import MetalKit

enum Key: UInt16 {
  // Letter keys
  case a = 0
  case s = 1
  case d = 2
  case w = 13
  case c = 8  // Adding the 'c' key
  
  // Special keys
  case lShift = 56
  case rShift = 60
  case space = 49
  case escape = 53
  
  // Arrow keys
  case leftArrow = 123
  case rightArrow = 124
  case downArrow = 125
  case upArrow = 126
}


class InputHandler {
  // Dictionary to map raw key codes to Key enum values
  private let keyMapping: [UInt16: Key] = [
    0: .a,
    1: .s,
    2: .d,
    13: .w,
    8: .c,  // Add 'c' key mapping
    56: .lShift,
    60: .rShift,
    49: .space,
    53: .escape,
    123: .leftArrow,
    124: .rightArrow,
    125: .downArrow,
    126: .upArrow
  ]
  
  private var lastMouseLocation: NSPoint?
  var isMouseCaptured = false
  private weak var metalView: MTKView?
  private weak var viewController: NSViewController?
  private var onKeyPress: ((Key, Bool) -> Void)?
  private var onMouseMove: ((Float, Float) -> Void)?

  // Store a reference to the event monitors
  private var localKeyMonitor: Any?
  private var mouseMonitor: Any?
  private var localMouseMonitor: Any?
  private var globalMouseMonitor: Any?  // Add a global mouse monitor

  // Mouse movement smoothing
  var movementBuffer: [(Float, Float)] = []
  private let bufferSize = 3  // Number of samples to average
  var mouseDeltaX: Float = 0
  var mouseDeltaY: Float = 0

  var keysPressed: Set<Key> = []
  
  init(viewController: NSViewController, metalView: MTKView) {
    self.viewController = viewController
    self.metalView = metalView
    setupInputHandling()
    print("InputHandler initialized - click in the window to capture mouse")
  }

  func setKeyPressCallback(_ callback: @escaping (Key, Bool) -> Void) {
    self.onKeyPress = callback
  }

  func setMouseMoveCallback(_ callback: @escaping (Float, Float) -> Void) {
    self.onMouseMove = callback
  }


    // Public method for handling mouse clicks
    public func handleMouseClick(at point: NSPoint) {
      if !isMouseCaptured {
       
            print("Mouse click detected in game area - capturing mouse")
            Task {
              await self.captureMouse()
            }
      }
    }

    // Public method for handling mouse movement
    public func handleMouseMovement(deltaX: Float, deltaY: Float) {
      if isMouseCaptured {
        // Get raw delta values
        let dx = deltaX
        let dy = deltaY

        // Apply different sensitivity for X and Y axis
        let maxDeltaX: Float = 20.0
        let maxDeltaY: Float = 15.0  // More restrictive for Y-axis
        let clampedDx = max(-maxDeltaX, min(dx, maxDeltaX))
        let clampedDy = max(-maxDeltaY, min(dy, maxDeltaY))

        // Add to movement buffer for smoothing
        self.movementBuffer.append((clampedDx, clampedDy))
        if self.movementBuffer.count > self.bufferSize {
          self.movementBuffer.removeFirst()
        }

        // Calculate smoothed movement
        var totalDx: Float = 0
        var totalDy: Float = 0

        for (dx, dy) in self.movementBuffer {
          totalDx += dx
          totalDy += dy
        }

        // Calculate average
        let avgDx = totalDx / Float(self.movementBuffer.count)
        let avgDy = totalDy / Float(self.movementBuffer.count)

        // Apply different sensitivity for X and Y
        let sensitivityX: Float = 0.003
        let sensitivityY: Float = 0.0015
        self.mouseDeltaX = avgDx * sensitivityX
        self.mouseDeltaY = avgDy * sensitivityY

        // Notify about mouse movement
        self.onMouseMove?(self.mouseDeltaX, self.mouseDeltaY)

        // Center the mouse
        if abs(totalDx) + abs(totalDy) > 5 {
          Task {
            await self.centerMouseInWindow()
          }
        }
      }
    }

  private func setupInputHandling() {
    print("Setting up input handling - SIMPLIFIED VERSION")
    
    // Make sure we're the first responder
    metalView?.window?.makeFirstResponder(metalView)
    // Keep keyboard event monitor but replace mouse monitors with public methods
    // Add public methods for mouse event handling that can be called externally

    // Keyboard monitoring with local monitor only
    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) {
      [weak self] event in
      guard let self = self else { return event }
      
      // Handle Escape key specially for exiting mouse capture mode
      if event.type == .keyDown && event.keyCode == Key.escape.rawValue && self.isMouseCaptured {
          print("Escape pressed while mouse captured - releasing mouse")
          self.releaseMouse()
      }
      
      self.handleKeyEvent(event)
      return event
    }

    
    // Remove global mouse monitoring completely
    
    print("Input handlers set up successfully")
  }

  // Override NSResponder methods in our view controller
  func registerViewForKeyEvents() {
    // Instead of swapping views (which causes crashes), let's use event monitor approach
    print("Setting up key event handling using event monitors only")
    
    // Make sure the metalView is the first responder
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let metalView = self.metalView else { return }
      
      // Make the view or window first responder
      if let window = metalView.window {
        print("Setting metal view as first responder")
        window.makeFirstResponder(metalView)
        
        // Add app-level handlers for keys for redundancy
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
          self?.handleKeyEvent(event)
          return event
        }
        
        print("Added app-level key event monitor")
      } else {
        print("Warning: Metal view has no window, can't set first responder")
      }
    }
  }

  public func handleKeyEvent(_ event: NSEvent) {
    // Direct key handling approach like in the old code
    let isKeyDown = event.type == .keyDown
    
    // Use a direct approach for the common keys we care about
    
      if let key = keyMapping[event.keyCode] ?? Key(rawValue: event.keyCode) {
        // Update the keysPressed set based on key state
        if isKeyDown {
          keysPressed.insert(key)
        } else {
          keysPressed.remove(key)
        }
        
        onKeyPress?(key, isKeyDown)
      } else {
        // Handle other keys if needed
        print("Unhandled key event: \(event.keyCode) - \(isKeyDown ? "down" : "up")")
      }
      
    }

  // Add a dedicated method for handling mouse movement
  private func handleMouseMovement(_ event: NSEvent) {
    // Get raw delta values directly from the event
    let dx = Float(event.deltaX)
    let dy = Float(event.deltaY)
    
    // Skip tiny movements that might be noise
    if abs(dx) < 0.1 && abs(dy) < 0.1 {
        return
    }
    
    print("Mouse movement: dx=\(dx), dy=\(dy)")
    
    // Apply directly to the delta values without the complex buffering
    // Set a much higher sensitivity since we'll apply a smaller one in the renderer
    let sensitivity: Float = 5.0
    mouseDeltaX += dx * sensitivity
    mouseDeltaY += dy * sensitivity
    
    print("Updated deltas: x=\(mouseDeltaX), y=\(mouseDeltaY)")
    
    // Center the mouse more aggressively to prevent hitting screen edges
    Task {
        await self.centerMouseInWindow()
    }
  }

  private func centerMouseInWindow() async {
    guard let window = await metalView?.window else {
      print("Warning: Cannot center mouse - no window found")
      return
    }

    // Get the window's content view bounds
    guard let contentView = await window.contentView else {
      print("Warning: Cannot center mouse - no content view found")
      return
    }

    // Calculate center like in old implementation
    let centerInWindow = NSPoint(
      x: await MainActor.run { contentView.bounds.midX },
      y: await MainActor.run {
        contentView.bounds.midY + (window.frame.height - contentView.frame.height)
      }
    )

    // Convert window coordinates to screen coordinates 
    let centerInScreen = await window.convertPoint(toScreen: centerInWindow)

    // Warp cursor position - this requires accessibility permissions!
    let success = CGWarpMouseCursorPosition(CGPoint(x: centerInScreen.x, y: centerInScreen.y)) == .success
    if !success {
        print("⚠️ Failed to warp cursor position - check permissions!")
    }
  }

  func captureMouse() async {
    print("⚠️ CAPTURING MOUSE ⚠️")
    
    // Check for accessibility permissions - this may be required for mouse capture
    let checkOptionsPrompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString
    let options = [checkOptionsPrompt: true] as CFDictionary
    let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
    
    print("Accessibility permissions status: \(accessibilityEnabled ? "Granted" : "Not granted - mouse capture may not work")")
    
    isMouseCaptured = true
    lastMouseLocation = nil
    movementBuffer.removeAll()
    mouseDeltaX = 0
    mouseDeltaY = 0

    await MainActor.run {
      // Hide cursor
      NSCursor.hide()

      // Visual indicator of mouse capture
      metalView?.clearColor = MTLClearColor(red: 0.2, green: 0.1, blue: 0.1, alpha: 1.0)

      // Only make the window key, no forced activation
      metalView?.window?.makeFirstResponder(metalView)
      
      // Try to give our window focus if we have permissions
      metalView?.window?.makeKey()
    }

    // Center the mouse in window - this needs accessibility permissions!
    await centerMouseInWindow()

    // This requires accessibility permissions to work properly
    let success = CGAssociateMouseAndMouseCursorPosition(0) == .success
    if !success {
        print("⚠️ Failed to dissociate cursor from mouse - check permissions!")
    }
    
    // Try multiple centers to ensure proper capture
    for i in 0...2 {
        usleep(5000) // 5ms delay
        await centerMouseInWindow()
    }
    
    // Print permission troubleshooting info
    if !accessibilityEnabled {
        print("PERMISSION TROUBLESHOOTING:")
        print("1. Make sure your app has Accessibility permissions")
        print("2. Go to System Preferences > Security & Privacy > Privacy > Accessibility")
        print("3. Add your application to the list and ensure it's checked")
        print("4. If running from Xcode, you may need to add Xcode too")
    }
  }

  func releaseMouse() {
    print("🔓 RELEASING MOUSE 🔓")
    isMouseCaptured = false
    lastMouseLocation = nil
    movementBuffer.removeAll()

    // Show cursor
    NSCursor.unhide()

    // Visual indicator of mouse release
    metalView?.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)

    // Restore normal mouse behavior
    CGAssociateMouseAndMouseCursorPosition(1)
  }

  func cleanup() {
    // Clean up event monitors
    if let localKeyMonitor = localKeyMonitor {
      NSEvent.removeMonitor(localKeyMonitor)
      self.localKeyMonitor = nil
    }

    if let mouseMonitor = mouseMonitor {
      NSEvent.removeMonitor(mouseMonitor)
      self.mouseMonitor = nil
    }

    if let localMouseMonitor = localMouseMonitor {
      NSEvent.removeMonitor(localMouseMonitor)
      self.localMouseMonitor = nil
    }
    
    // Also clean up global monitor if present
    if let globalMouseMonitor = globalMouseMonitor {
      NSEvent.removeMonitor(globalMouseMonitor)
      self.globalMouseMonitor = nil
    }

    if isMouseCaptured {
      releaseMouse()
    }
  }
}

