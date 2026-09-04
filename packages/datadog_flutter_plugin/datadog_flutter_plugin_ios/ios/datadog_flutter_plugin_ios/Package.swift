// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "datadog_flutter_plugin_ios",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "datadog-flutter-plugin-ios", targets: ["datadog_flutter_plugin_ios"])
    ],
    dependencies: [
        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", branch: "develop"),
        .package(url: "https://github.com/almazrafi/DictionaryCoder.git", exact: "1.2.0")
    ],
    targets: [
        .target(
            name: "datadog_flutter_plugin_ios",
            dependencies: [
                .product(name: "DatadogCore", package: "dd-sdk-ios"),
                .product(name: "DatadogLogs", package: "dd-sdk-ios"),
                .product(name: "DatadogCrashReporting", package: "dd-sdk-ios"),
                .product(name: "DatadogRUM", package: "dd-sdk-ios"),
                "DictionaryCoder"
            ],
            resources: []
        )
    ]
)
