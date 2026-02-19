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
            name: "AgenticCore",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "AgenticCoreTests",
            dependencies: ["AgenticCore"]
        ),
    ]
)
