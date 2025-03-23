import Cocoa
import Metal
import MetalKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let windowRect = NSRect(x: 100, y: 100, width: 800, height: 600)
        window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Metal Hello Triangle"

        let viewController = ViewController()
        window.contentViewController = viewController
        window.makeKeyAndOrderFront(nil)
    }
}

class ViewController: NSViewController {
    var metalView: MTKView!
    var renderer: Renderer!

    private var mouseHandler: MouseHandler?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create the Metal view
        metalView = MTKView(frame: view.bounds)
        metalView.device = MTLCreateSystemDefaultDevice()
        metalView.clearColor = MTLClearColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        metalView.autoresizingMask = [.width, .height]
        view.addSubview(metalView)

        guard let device = metalView.device else {
            fatalError("Device not created. Run on a physical device.")
        }

        // Create renderer with the Metal view's device
        renderer = Renderer(device: device)
        metalView.delegate = renderer

        // Initialize mouse handler
        mouseHandler = MouseHandler(viewController: self, metalView: metalView)

        // Set up callbacks
        mouseHandler?.setKeyPressCallback { [weak self] key, isPressed in
            guard let self = self else { return }

            switch key {
            case .w:
                if isPressed {
                    self.renderer.keysPressed.insert(.w)
                } else {
                    self.renderer.keysPressed.remove(.w)
                }
            case .a:
                if isPressed {
                    self.renderer.keysPressed.insert(.a)
                } else {
                    self.renderer.keysPressed.remove(.a)
                }
            case .s:
                if isPressed {
                    self.renderer.keysPressed.insert(.s)
                } else {
                    self.renderer.keysPressed.remove(.s)
                }
            case .d:
                if isPressed {
                    self.renderer.keysPressed.insert(.d)
                } else {
                    self.renderer.keysPressed.remove(.d)
                }
            default:
                break
            }
        }

        mouseHandler?.setMouseMoveCallback { [weak self] deltaX, deltaY in
            let deltaTime = 1.0 / Float(self?.metalView.preferredFramesPerSecond ?? Int(60))
            self?.renderer.rotateCamera(deltaX: deltaX, deltaY: deltaY, deltaTime: deltaTime)
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()

        // Clean up mouse handler
        mouseHandler?.cleanup()
        mouseHandler = nil
    }
}

enum MouseKey: UInt16 {
    case w = 13
    case a = 0
    case s = 1
    case d = 2
    case escape = 53
}

class MouseHandler {
    private var lastMouseLocation: NSPoint?
    private var isMouseCaptured = false
    private weak var metalView: MTKView?
    private weak var viewController: NSViewController?
    private var onKeyPress: ((MouseKey, Bool) -> Void)?
    private var onMouseMove: ((Float, Float) -> Void)?

    // Store a reference to the event monitors
    private var localKeyMonitor: Any?
    private var mouseMonitor: Any?
    private var localMouseMonitor: Any?

    // Mouse movement smoothing
    private var movementBuffer: [(Float, Float)] = []
    private let bufferSize = 3  // Number of samples to average
    private var mouseDeltaX: Float = 0
    private var mouseDeltaY: Float = 0
    private var frameCount = 0  // For debug logging

    init(viewController: NSViewController, metalView: MTKView) {
        self.viewController = viewController
        self.metalView = metalView
        setupInputHandling()
        print("MouseHandler initialized - click in the window to capture mouse")
    }

    func setKeyPressCallback(_ callback: @escaping (MouseKey, Bool) -> Void) {
        self.onKeyPress = callback
    }

    func setMouseMoveCallback(_ callback: @escaping (Float, Float) -> Void) {
        self.onMouseMove = callback
    }

    private func setupInputHandling() {
        // Setup keyboard monitoring
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) {
            [weak self] event in
            guard let self = self else { return event }
            print("YOOOOOOOO!2312312123")
            self.handleKeyEvent(event)
            return event
        }

        // Setup mouse click monitoring to capture mouse initially
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) {
            [weak self] event in
            if let self = self, !self.isMouseCaptured {
                            // Only capture the mouse if we're clicking in the game area,
                            // not when clicking window controls
                            if let view = self.metalView,
                               let window = view.window,
                               let clickLocation = window.contentView?.convert(event.locationInWindow, from: nil) {
                                // Check if click is inside the view area
                                if view.bounds.contains(clickLocation) {
                                    print("Mouse click detected in game area - capturing mouse")
                                    Task {
                                        await self.captureMouse()
                                    }
                                }
                            }
                        }
            return event
        }

        // Use local mouse monitoring instead of global for better reliability
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) {
            [weak self] event in
            if let self = self, self.isMouseCaptured {
                // Get raw delta values from the event
                let dx = Float(event.deltaX)
                let dy = Float(event.deltaY)

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
                let sensitivityY: Float = 0.0015  // Reduced for pitch to prevent jumping
                self.mouseDeltaX = avgDx * sensitivityX
                self.mouseDeltaY = avgDy * sensitivityY

                // Notify about mouse movement
                self.onMouseMove?(self.mouseDeltaX, self.mouseDeltaY)

                // Center the mouse within the window instead of the screen
                if abs(totalDx) + abs(totalDy) > 5 {
                    Task {
                        await self.centerMouseInWindow()
                    }

                }

                // Debug logging
                self.frameCount += 1
                if self.frameCount % 1 == 0 {  // Log every ~5 seconds
                    print("Mouse deltas - X: \(self.mouseDeltaX), Y: \(self.mouseDeltaY)")
                }
            }
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            switch event.keyCode {
            case MouseKey.a.rawValue:
                self.onKeyPress?(.a, true)
            case MouseKey.s.rawValue:
                self.onKeyPress?(.s, true)
            case MouseKey.d.rawValue:
                self.onKeyPress?(.d, true)
            case MouseKey.w.rawValue:
                self.onKeyPress?(.w, true)
            case MouseKey.escape.rawValue:
                if self.isMouseCaptured {
                    Task {
                        await self.releaseMouse()
                    }
                }
            default:
                break
            }
        case .keyUp:
            switch event.keyCode {
            case MouseKey.a.rawValue:
                self.onKeyPress?(.a, false)
            case MouseKey.s.rawValue:
                self.onKeyPress?(.s, false)
            case MouseKey.d.rawValue:
                self.onKeyPress?(.d, false)
            case MouseKey.w.rawValue:
                self.onKeyPress?(.w, false)
            default:
                break
            }
        default:
            break
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

        // Calculate center of content view in window coordinates
        let centerInWindow = NSPoint(
            x: await MainActor.run { contentView.bounds.midX },
            y: await MainActor.run {
                contentView.bounds.midY + (window.frame.height - contentView.frame.height)
            }
        )

        // Convert window coordinates to screen coordinates (required by CGWarpMouseCursorPosition)
        let centerInScreen = await window.convertPoint(toScreen: centerInWindow)

        // Warp cursor to window center
        CGWarpMouseCursorPosition(CGPoint(x: centerInScreen.x, y: centerInScreen.y))
    }
    func captureMouse() async {

        print("⚠️ CAPTURING MOUSE ⚠️")
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

            // IMPORTANT: Make sure the window stays as key window
            metalView?.window?.makeKey()
        }

        // Center the mouse in window instead of screen
        await centerMouseInWindow()

        // Use CGAssociateMouseAndMouseCursorPosition to decouple mouse and cursor
        CGAssociateMouseAndMouseCursorPosition(0)
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

        if isMouseCaptured {
            releaseMouse()
        }
    }
}
