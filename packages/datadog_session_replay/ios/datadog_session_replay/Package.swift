// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "datadog_session_replay",
    platforms: [
        .iOS("13.0"),
        .macOS("13.0")
    ],
    products: [
        .library(name: "datadog-session-replay", targets: ["datadog_session_replay", "datadog_session_replay_objc"])
    ],
    dependencies: [
        // TEMP (local dev): point at local dd-sdk-ios checkout to pick up
        // the in-progress `flutterView` FeatureMessage case. Revert to the
        // remote git dependency before committing/releasing.
        //
        // Absolute path is used because Flutter's SPM plugin integration
        // references this package through a symlink, and SwiftPM resolves
        // relative `path:` values lexically against the symlink's location
        // rather than its target — a relative path here resolves wrong.
        .package(path: "/Users/juancarlos.naranjojaramillo/Development/sdk-flutter-workspace/dd-sdk-ios")
    ],
    targets: [
        .target(
            name: "datadog_session_replay",
            dependencies: [
                .product(name: "DatadogCore", package: "dd-sdk-ios")
            ],
            path: "Sources/Swift",
            resources: [],
            swiftSettings: [
                // Enable automatic Objective-C header generation
                .define("SWIFT_PACKAGE"),
                .unsafeFlags([
                    "-emit-objc-header",
                    "-emit-objc-header-path", "Sources/ObjC/include/datadog_session_replay_bridge.h"
                ])
            ]
        ),
        .target(
            name: "datadog_session_replay_objc",
            dependencies: [
                .product(name: "DatadogCore", package: "dd-sdk-ios")
            ],
            path: "Sources/ObjC",
            resources: []
        )
    ]
)
