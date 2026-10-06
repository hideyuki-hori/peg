// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Peg",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PegCore"),
        .target(name: "PegSync", dependencies: ["PegCore"]),
        .target(name: "PegNotes"),
        .target(name: "PegAXShim"),
        .target(name: "PegMenu", dependencies: ["PegAXShim"]),
        .executableTarget(name: "Peg", dependencies: ["PegCore", "PegSync", "PegNotes", "PegMenu"]),
        .testTarget(name: "PegCoreTests", dependencies: ["PegCore"]),
        .testTarget(name: "PegSyncTests", dependencies: ["PegCore", "PegSync"]),
        .testTarget(name: "PegNotesTests", dependencies: ["PegNotes"]),
        .testTarget(name: "PegMenuTests", dependencies: ["PegMenu"])
    ]
)
