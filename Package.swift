// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipSafe",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ClipSafe", targets: ["ClipSafe"])
    ],
    targets: [
        .executableTarget(name: "ClipSafe"),
        .testTarget(name: "ClipSafeTests", dependencies: ["ClipSafe"])
    ],
    swiftLanguageVersions: [.v5]
)
