// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AgenticUpdater",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "AgenticUpdater",
            targets: ["AgenticUpdater"]
        ),
    ],
    targets: [
        .target(
            name: "AgenticUpdater"
        ),
        .testTarget(
            name: "AgenticUpdaterTests",
            dependencies: ["AgenticUpdater"]
        ),
    ]
)
