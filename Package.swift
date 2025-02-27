// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Angelite",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "Base",
            targets: ["Base"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Base",
            dependencies: ["Angelite"],
            path: "src/swift/base",
            exclude: []
        ),
        .target(
            name: "Angelite",
            dependencies: [],
            path: "src/c",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath(".")
            ]
        ),
    ]
)
