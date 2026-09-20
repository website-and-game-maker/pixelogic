// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClueweaveKit",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
        .macOS(.v13),
    ],
    products: [
        .library(name: "ClueweaveKit", targets: ["ClueweaveKit"])
    ],
    targets: [
        .target(name: "ClueweaveKit"),
        // Full test suite (Swift Testing) — runs under Xcode's toolchain.
        .testTarget(name: "ClueweaveKitTests", dependencies: ["ClueweaveKit"]),
        // Framework-free verifier so the same checks run with bare Command
        // Line Tools (no Xcode):  swift run clueweave-verify
        .executableTarget(name: "clueweave-verify", dependencies: ["ClueweaveKit"]),
    ]
)
