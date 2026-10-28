// swift-tools-version: 6.0
import PackageDescription

// Pure Run rules for Paceprint: no SwiftUI, SwiftData, Core Location or HealthKit (ADR 0003).
let package = Package(
    name: "PaceprintCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "PaceprintCore", targets: ["PaceprintCore"]),
    ],
    targets: [
        .target(name: "PaceprintCore"),
        .testTarget(name: "PaceprintCoreTests", dependencies: ["PaceprintCore"]),
    ]
)
