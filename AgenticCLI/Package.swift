// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AgenticCLI",
    platforms: [
        .macOS(.v15),
    ],
    dependencies: [
        .package(path: "../Packages/AgenticCore"),
        .package(path: "../Packages/AgenticUpdater"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "AgenticCLI",
            dependencies: [
                "AgenticCore",
                "AgenticUpdater",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
