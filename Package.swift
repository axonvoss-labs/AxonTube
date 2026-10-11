// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AxonTube",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PlayerCore", targets: ["PlayerCore"]),
        .executable(name: "AxonTube", targets: ["AxonTube"])
    ],
    targets: [
        .target(name: "PlayerCore"),
        .executableTarget(name: "AxonTube", dependencies: ["PlayerCore"]),
        .testTarget(name: "PlayerCoreTests", dependencies: ["PlayerCore"])
    ]
)
