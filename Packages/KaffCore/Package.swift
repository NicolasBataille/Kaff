// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KaffCore",
    platforms: [.watchOS("26.0"), .macOS("15.0")],
    products: [.library(name: "KaffCore", targets: ["KaffCore"])],
    targets: [
        .target(name: "KaffCore", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "KaffCoreTests", dependencies: ["KaffCore"]),
    ]
)
