// main.swift
import Cocoa

func main() {
    // Create a simple entry point function
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    print("About to enter run loop")
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    app.run()
}
