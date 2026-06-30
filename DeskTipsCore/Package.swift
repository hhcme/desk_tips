// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "DeskTipsCore",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "DeskTipsCore",
            targets: ["DeskTipsCore"]
        ),
    ],
    targets: [
        .target(
            name: "DeskTipsCore",
            path: "Sources/DeskTipsCore"
        ),
        .testTarget(
            name: "DeskTipsCoreTests",
            dependencies: ["DeskTipsCore"],
            path: "Tests/DeskTipsCoreTests"
        ),
    ]
)
