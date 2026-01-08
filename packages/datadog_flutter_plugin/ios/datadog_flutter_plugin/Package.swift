// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "datadog_flutter_plugin",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "datadog-flutter-plugin", targets: ["datadog_flutter_plugin"])
    ],
    dependencies: [
        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", exact: "3.4.0"),
        .package(url: "https://github.com/almazrafi/DictionaryCoder.git", exact: "1.2.0")
    ],
    targets: [
        .systemLibrary(name: "datadog_flutter_plugin_c"),
        .target(
            name: "datadog_flutter_plugin",
            dependencies: [
                .product(name: "DatadogCore", package: "dd-sdk-ios"),
                .product(name: "DatadogLogs", package: "dd-sdk-ios"),
                .product(name: "DatadogCrashReporting", package: "dd-sdk-ios"),
                .product(name: "DatadogRUM", package: "dd-sdk-ios"),
                "datadog_flutter_plugin_c",
                "DictionaryCoder"
            ],
            resources: []
        )
    ]
)
