// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Peg",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PegCore"),
        .target(name: "PegSync", dependencies: ["PegCore"]),
        .executableTarget(name: "Peg", dependencies: ["PegCore", "PegSync"]),
        .testTarget(name: "PegCoreTests", dependencies: ["PegCore"]),
        .testTarget(name: "PegSyncTests", dependencies: ["PegCore", "PegSync"])
    ]
)
