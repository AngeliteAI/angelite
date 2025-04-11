import Foundation

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/swiftc")

let currentDir = FileManager.default.currentDirectoryPath
let outputPath = "\(currentDir)/target"

// Ensure output directory exists
try? FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true)

process.arguments = [
    "src/macos/main.swift",
    "-emit-library",
    "-o", "\(outputPath)/libeditor.dylib",
    "-Xlinker", "-install_name", "-Xlinker", "@rpath/libeditor.dylib",
    "-import-objc-header", "src/macos/bridge.h",
    "-framework", "Cocoa",
]

try process.run()
process.waitUntilExit()
