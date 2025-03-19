import Cocoa

@main
class MyApp {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    print("About to enter run loop")
    app.run()
  }
}
