// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Angelite",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "Gfx",
            targets: ["Gfx"]
        ),
    ],
    dependencies: [],
    targets: [
        // Graphics library
        .target(
            name: "Gfx",
            dependencies: [],
            path: "src/swift/gfx/src",
            resources: [
                .process("Shaders.metal")
            ]
        ),
    ]
)