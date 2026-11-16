// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NotchBox",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "NotchBoxCore"),
        // One Objective-C function: catching the exceptions that system frameworks raise.
        .target(name: "NotchBoxObjC"),
        .executableTarget(name: "NotchBox", dependencies: ["NotchBoxCore", "NotchBoxObjC"]),
        .testTarget(name: "NotchBoxCoreTests", dependencies: ["NotchBoxCore"]),
    ],
    swiftLanguageModes: [.v5]
)
