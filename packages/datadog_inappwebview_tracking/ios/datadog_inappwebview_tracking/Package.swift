// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "datadog_inappwebview_tracking",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "datadog-inappwebview-tracking", targets: ["datadog_inappwebview_tracking"])
    ],
    dependencies: [
        .package(url: "https://github.com/Datadog/dd-sdk-ios.git", exact: "2.30.1")
    ],
    targets: [
        .target(
            name: "datadog_inappwebview_tracking",
            dependencies: [
                .product(name: "DatadogCore", package: "dd-sdk-ios")
            ],
            resources: []
        )
    ]
)
