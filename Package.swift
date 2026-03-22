// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlazeWMIndicator",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "GlazeWMIndicator",
            path: "GlazeWMIndicator"
        ),
        .testTarget(
            name: "GlazeWMIndicatorTests",
            dependencies: ["GlazeWMIndicator"],
            path: "GlazeWMIndicatorTests"
        ),
    ]
)
