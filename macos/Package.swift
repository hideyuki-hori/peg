// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Peg",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PegCore"),
        .executableTarget(name: "Peg", dependencies: ["PegCore"]),
        .testTarget(name: "PegCoreTests", dependencies: ["PegCore"])
    ]
)
