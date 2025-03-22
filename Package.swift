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
        // Math library
        .target(
            name: "Math",
            dependencies: [],
            path: "src/swift/math/src"
        ),

        // Graphics library
        .target(
            name: "Gfx",
            dependencies: ["Math"],
            path: "src/swift/gfx/src",
            resources: [
                .process("Shaders.metal")
            ]
        ),
    ]
)
