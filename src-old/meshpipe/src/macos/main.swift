import Cocoa

class MainWindowController: NSWindowController {
    override init(window: NSWindow?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        // Configure window
        window.title = "Techkit"
        window.isReleasedWhenClosed = false
        window.contentView?.wantsLayer = true

        // Center and show window
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create and show window
        windowController = MainWindowController(window: nil)

        // Activate app and bring window to front
        NSApp.activate(ignoringOtherApps: true)
    }
}

@_cdecl("editor_start")
public func editor_start() {
    autoreleasepool {
        let app = NSApplication.shared
        let delegate = AppDelegate()

        // Configure app
        app.setActivationPolicy(.regular)
        app.delegate = delegate

        // Initialize before running
        app.finishLaunching()

        // Show window and run
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        app.run()
    }
}
