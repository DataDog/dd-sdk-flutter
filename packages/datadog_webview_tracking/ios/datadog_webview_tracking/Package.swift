// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "datadog_webview_tracking",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "datadog-webview-tracking", targets: ["datadog_webview_tracking"])
    ],
    dependencies: [
        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", from: "2.20.0"),
    ],
    targets: [
        .target(
            name: "datadog_webview_tracking",
            dependencies: [
                .product(name: "DatadogCore", package: "dd-sdk-ios"),
                .product(name: "DatadogWebViewTracking", package: "dd-sdk-ios")
            ],
            resources: []
        )
    ]
)
