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
        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", exact: "2.30.1")
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
