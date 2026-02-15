// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AgenticCore",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "AgenticCore",
            targets: ["AgenticCore"]
        ),
    ],
    targets: [
        .target(
            name: "AgenticCore"
        ),
        .testTarget(
            name: "AgenticCoreTests",
            dependencies: ["AgenticCore"]
        ),
    ]
)
