import Foundation
import AppKit

class Surface: NSObject, NSWindowDelegate {
     var window: NSWindow
     var contentView: NSView

     var resizeCallback: ((UnsafeMutableRawPointer, Int32, Int32) -> Void)?
     var focusCallback: ((UnsafeMutableRawPointer, Bool) -> Void)?
     var closeCallback: ((UnsafeMutableRawPointer) -> Bool)?

    // Store the raw pointer to self for callbacks

    init(width: Int, height: Int, title: String) {
        // Ensure the application is initialized
        let app = NSApplication.shared
        if !app.isRunning {
            app.setActivationPolicy(.regular)
        }

        let contentRect = NSRect(x: 0, y: 0, width: width, height: height)
        window = NSWindow(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.center();
        window.makeKeyAndOrderFront(nil)

        contentView = NSView(frame: contentRect)
        super.init();


        window.delegate = self

        window.contentView = contentView

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResignKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        Unmanaged.passUnretained(self).release()
    }

    @objc  func windowWillClose(_ notification: Notification) {
        if let callback = closeCallback {
            let shouldClose = callback(Unmanaged.passUnretained(self).toOpaque())
            // Note: Cannot prevent closing here in a standard way
        }
    }

    @objc  func windowDidResize(_ notification: Notification) {
        if let callback = resizeCallback {
            let size = window.contentView?.frame.size ?? .zero
            callback(Unmanaged.passUnretained(self).toOpaque(), Int32(size.width), Int32(size.height))
        }
    }

    @objc  func windowDidBecomeKey(_ notification: Notification) {
        if let callback = focusCallback {
            callback(Unmanaged.passUnretained(self).toOpaque(), true)
        }
    }

    @objc  func windowDidResignKey(_ notification: Notification) {
        if let callback = focusCallback {
            callback(Unmanaged.passUnretained(self).toOpaque(), false)
        }
    }
}


@_cdecl("surface_create")
public func surface_create(width: Int32, height: Int32, title: UnsafePointer<CChar>) -> UnsafeMutableRawPointer {
    // Initialize the application if needed
    let app = NSApplication.shared
    if !app.isRunning {
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        app.activate(ignoringOtherApps: true)
    }

    let swiftTitle = String(cString: title)
    let manager = Surface(width: Int(width), height: Int(height), title: swiftTitle)
    return Unmanaged.passRetained(manager).toOpaque()
}

@_cdecl("surface_destroy")
public func surface_destroy(surface: UnsafeMutableRawPointer) {
    Unmanaged<Surface>.fromOpaque(surface).release()
}

@_cdecl("surface_width")
public func surface_width(surface: UnsafeMutableRawPointer) -> Int32 {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    let size = manager.window.contentView?.frame.size ?? .zero
    return Int32(size.width)
}

@_cdecl("surface_height")
public func surface_height(surface: UnsafeMutableRawPointer) -> Int32 {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    let size = manager.window.contentView?.frame.size ?? .zero
    return Int32(size.height)
}

@_cdecl("surface_resize")
public func surface_resize(surface: UnsafeMutableRawPointer, width: Int32, height: Int32) {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    let newSize = NSSize(width: CGFloat(width), height: CGFloat(height))
    manager.window.setContentSize(newSize)
}

@_cdecl("surface_position_x")
public func surface_position_x(surface: UnsafeMutableRawPointer) -> Int32 {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    return Int32(manager.window.frame.origin.x)
}

@_cdecl("surface_position_y")
public func surface_position_y(surface: UnsafeMutableRawPointer) -> Int32 {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    return Int32(manager.window.frame.origin.y)
}

@_cdecl("surface_reposition")
public func surface_reposition(surface: UnsafeMutableRawPointer, x: Int32, y: Int32) {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    manager.window.setFrameOrigin(NSPoint(x: CGFloat(x), y: CGFloat(y)))
}

@_cdecl("surface_title")
public func surface_title(surface: UnsafeMutableRawPointer, title: UnsafePointer<CChar>) {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    let swiftTitle = String(cString: title)
    manager.window.title = swiftTitle
}

@_cdecl("surface_visibility")
public func surface_visibility(surface: UnsafeMutableRawPointer, visible: Bool) {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    if visible {
        manager.window.makeKeyAndOrderFront(nil)
    } else {
        manager.window.orderOut(nil)
    }
}

@_cdecl("surface_focused")
public func surface_focused(surface: UnsafeMutableRawPointer) -> Bool {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    return manager.window.isKeyWindow
}

@_cdecl("surface_visible")
public func surface_visible(surface: UnsafeMutableRawPointer) -> Bool {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    return manager.window.isVisible
}

@_cdecl("surface_minimized")
public func surface_minimized(surface: UnsafeMutableRawPointer) -> Bool {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    return manager.window.isMiniaturized
}

@_cdecl("surface_content_scale")
public func surface_content_scale(surface: UnsafeMutableRawPointer) -> Float {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    return Float(manager.window.backingScaleFactor)
}

@_cdecl("surface_on_resize")
public func surface_on_resize(surface: UnsafeMutableRawPointer, callback: @escaping @convention(c) (UnsafeMutableRawPointer, Int32, Int32) -> Void) {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    manager.resizeCallback = callback
}

@_cdecl("surface_on_focus")
public func surface_on_focus(surface: UnsafeMutableRawPointer, callback: @escaping @convention(c) (UnsafeMutableRawPointer, Bool) -> Void) {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    manager.focusCallback = callback
}

@_cdecl("surface_on_close")
public func surface_on_close(surface: UnsafeMutableRawPointer, callback: @escaping @convention(c) (UnsafeMutableRawPointer) -> Bool) {
    let manager = Unmanaged<Surface>.fromOpaque(surface).takeUnretainedValue()
    manager.closeCallback = callback
}

// Process events without blocking
@_cdecl("surface_process_events")
public func surface_process_events() {
    let app = NSApplication.shared

    // Process any pending events
    let distantFuture = NSDate.distantFuture
    let event = app.nextEvent(matching: .any, until: distantFuture, inMode: .default, dequeue: true)
    if let event = event {
        app.sendEvent(event)
    }

}

// Run the main event loop (will block until the application quits)
@_cdecl("surface_run")
public func surface_run() {
    let app = NSApplication.shared
    app.run()
}
