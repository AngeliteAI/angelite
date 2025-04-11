import Cocoa

@main
class MyApp {
  static func main() {
    let app = NSApplication.shared

    app.setActivationPolicy(.regular)
    let delegate = AppDelegate()
    app.delegate = delegate

    NSApp.activate(ignoringOtherApps: true)
    print("About to enter run loop")
    app.run()
  }
}
