// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PixelogicKit",
    platforms: [
        .iOS(.v16),
        .watchOS(.v9),
        .macOS(.v13),
    ],
    products: [
        .library(name: "PixelogicKit", targets: ["PixelogicKit"])
    ],
    targets: [
        .target(name: "PixelogicKit"),
        // Full test suite (Swift Testing) — runs under Xcode's toolchain.
        .testTarget(name: "PixelogicKitTests", dependencies: ["PixelogicKit"]),
        // Framework-free verifier so the same checks run with bare Command
        // Line Tools (no Xcode):  swift run pixelogic-verify
        .executableTarget(name: "pixelogic-verify", dependencies: ["PixelogicKit"]),
    ]
)
