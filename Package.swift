// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NotchBox",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NotchBoxCore"),
        .executableTarget(name: "NotchBox", dependencies: ["NotchBoxCore"]),
        .testTarget(name: "NotchBoxCoreTests", dependencies: ["NotchBoxCore"]),
    ],
    swiftLanguageModes: [.v5]
)
