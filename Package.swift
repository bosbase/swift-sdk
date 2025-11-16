// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BosBase",
    platforms: [
        .macOS(.v12),
        .iOS(.v14),
        .tvOS(.v14),
        .watchOS(.v7)
    ],
    products: [
        .library(
            name: "BosBase",
            targets: ["BosBase"]
        )
    ],
    targets: [
        .target(
            name: "BosBase",
            path: "Sources"
        ),
        .testTarget(
            name: "BosBaseTests",
            dependencies: ["BosBase"],
            path: "Tests"
        )
    ]
)
