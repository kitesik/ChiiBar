// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChiiBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ChiiCore"),
        .executableTarget(name: "ChiiBar", dependencies: ["ChiiCore"]),
        .testTarget(name: "ChiiCoreTests", dependencies: ["ChiiCore"]),
    ]
)
