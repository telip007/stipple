// swift-tools-version: 6.2

import PackageDescription

/// Compiler settings for every target. Every warning is an error and the
/// upcoming Swift features are enabled early so the compiler pushes back as
/// hard as it can. See wiki/concepts/backpressure-setup.md.
let strictSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .strictMemorySafety(),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "Stipple",
    platforms: [.macOS(.v15)],
    products: [
        // SwiftUI-shaped terminal UI: `import Stipple`.
        .library(name: "Stipple", targets: ["Stipple"])
    ],
    targets: [
        .target(
            name: "Stipple",
            swiftSettings: strictSettings,
        ),
        // Runnable examples: `swift run counter`, `swift run tasks`, `swift run chat`.
        .executableTarget(
            name: "counter", dependencies: ["Stipple"], path: "Examples/Counter", swiftSettings: strictSettings),
        .executableTarget(
            name: "tasks", dependencies: ["Stipple"], path: "Examples/Tasks", swiftSettings: strictSettings),
        .executableTarget(
            name: "chat", dependencies: ["Stipple"], path: "Examples/Chat", swiftSettings: strictSettings),
        .testTarget(
            name: "StippleTests",
            dependencies: ["Stipple"],
            swiftSettings: strictSettings,
        ),
    ],
)
