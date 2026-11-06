// swift-tools-version:5.9
// FishoDex's rules (species data, XP, levels, patches) as a small package, so
// the logic tests run anywhere Swift runs, including a cheap Linux machine.
// The app itself is built from FishoDex.xcodeproj, which compiles these same files.
import PackageDescription

let package = Package(
    name: "FishoDexCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FishoDexCore", targets: ["FishoDexCore"]),
    ],
    targets: [
        .target(name: "FishoDexCore", path: "FishoDex/Core"),
        .testTarget(name: "FishoDexCoreTests", dependencies: ["FishoDexCore"], path: "Tests/FishoDexCoreTests"),
    ]
)
