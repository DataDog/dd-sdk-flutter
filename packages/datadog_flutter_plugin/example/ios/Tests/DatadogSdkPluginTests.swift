// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.
// swiftlint:disable file_length

import XCTest
import Flutter
@testable import DatadogCore
@testable import DatadogInternal
@testable import datadog_flutter_plugin

extension UserInfo: EquatableInTests { }

// Note: These tests are in the example app because Flutter does not provide a simple
// way to to include tests in the Podspec.
class FlutterSdkTests: XCTestCase {

    override func setUp() {
        if Datadog.isInitialized() {
            // Somehow we ended up with an extra instance of Datadog?
            Datadog.flushAndDeinitialize()
        }
    }

    override func tearDown() {
        if Datadog.isInitialized() {
            Datadog.flushAndDeinitialize()
        }
    }

    let contracts = [
        Contract(methodName: "setSdkVerbosity", requiredParameters: [
            "value": .string
        ]),
        Contract(methodName: "setUserInfo", requiredParameters: [
            "extraInfo": .map
        ]),
        Contract(methodName: "addUserExtraInfo", requiredParameters: [
            "extraInfo": .map
        ]),
        Contract(methodName: "setTrackingConsent", requiredParameters: [
            "value": .string
        ]),
        Contract(methodName: "telemetryDebug", requiredParameters: [
            "message": .string
        ]),
        Contract(methodName: "telemetryError", requiredParameters: [
            "message": .string
        ]),
        Contract(methodName: "clearAllData", requiredParameters: [:])
    ]

    func testDatadogSdkCalls_FollowContracts() {
        let config = Datadog.Configuration(
            clientToken: "fakeClientToken",
            env: "prod",
            service: "serviceName"
        )

        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: config, trackingConsent: .granted)

        testContracts(contracts: contracts, plugin: plugin)
    }

    func testInitialization_FromMethodChannel_InitializesDatadog() {
        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        let methodCall = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "trackingConsent": "TrackingConsent.granted",
                "configuration": [
                    "clientToken": "fakeClientToken",
                    "env": "prod"
                ] as [String: Any]
            ] as [String: Any]
        )
        plugin.handle(methodCall) { _ in }

        XCTAssertTrue(Datadog.isInitialized())
    }

    func testRepeatInitialization_FromMethodChannelSameOptions_DoesNothing() {
        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        let configuration: [String: Any?] = [
            "clientToken": "fakeClientToken",
            "env": "prod"
        ]

        let methodCallA = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "trackingConsent": "TrackingConsent.granted",
                "configuration": configuration
            ] as [String: Any]
        )
        plugin.handle(methodCallA) { _ in }

        XCTAssertTrue(Datadog.isInitialized())

        let printMock = PrintFunctionMock()
        consolePrint = printMock.print

        let methodCallB = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "trackingConsent": "TrackingConsent.granted",
                "configuration": configuration
            ] as [String: Any]
        )
        plugin.handle(methodCallB) { _ in }

        XCTAssertTrue(printMock.printedMessages.isEmpty)
    }

    func testRepeatInitialization_FromMethodChannelDifferentOptions_PrintsError() {
        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        let methodCallA = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "trackingConsent": "TrackingConsent.granted",
                "configuration": [
                    "clientToken": "fakeClientToken",
                    "env": "prod"
                ] as [String: Any?]
            ] as [String: Any]
        )
        plugin.handle(methodCallA) { _ in }

        XCTAssertTrue(Datadog.isInitialized())

        let printMock = PrintFunctionMock()
        consolePrint = printMock.print

        let methodCallB = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "trackingConsent": "TrackingConsent.granted",
                "configuration": [
                    "clientToken": "changedClientToken",
                    "env": "debug"
                ] as [String: Any?]
            ] as [String: Any]
        )
        plugin.handle(methodCallB) { _ in }

        XCTAssertFalse(printMock.printedMessages.isEmpty)
        XCTAssertTrue(printMock.printedMessages.first?.contains("🔥") == true)
    }

//    func testAttachToExisting_WithNoExisting_PrintsError() {
//        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
//        let methodCall = FlutterMethodCall(
//            methodName: "attachToExisting", arguments: [:] as [String: Any?]
//        )
//
//        var loggedConsoleLines: [String] = []
//        consolePrint = { str in loggedConsoleLines.append(str) }
//
//        plugin.handle(methodCall) { _ in }
//
//        XCTAssertFalse(loggedConsoleLines.isEmpty)
//        XCTAssertTrue(loggedConsoleLines.first?.contains("🔥") == true)
//    }

//    func testAttachToExisting_RumDisabled_ReturnsRumDisabled() {
//        let config = Datadog.Configuration.builderUsing(
//                    clientToken: "mock_client_token",
//                    environment: "mock"
//                )
//                .set(serviceName: "app-name")
//                .set(endpoint: .us1)
//                .build()
//        Datadog.initialize(appContext: .init(),
//            trackingConsent: .granted, configuration: config)
//
//        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
//        let methodCall = FlutterMethodCall(
//            methodName: "attachToExisting", arguments: [:] as [String: Any]
//        )
//
//        var callResult: [String: Any?]?
//        plugin.handle(methodCall) { result in
//            callResult = result as? [String: Any?]
//        }
//
//        XCTAssertNotNil(callResult)
//        XCTAssertEqual(callResult?["rumEnabled"] as? Bool, false)
//    }

//    func testAttachToExisting_RumEnabled_ReturnsRumEnabled() {
//        let config = Datadog.Configuration.builderUsing(
//                    rumApplicationID: "mock_application_id",
//                    clientToken: "mock_client_token",
//                    environment: "mock"
//                )
//                .set(serviceName: "app-name")
//                .set(endpoint: .us1)
//                .build()
//        Datadog.initialize(appContext: .init(),
//            trackingConsent: .granted, configuration: config)
//        Global.rum = RUMMonitor.initialize()
//
//        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
//        let methodCall = FlutterMethodCall(
//            methodName: "attachToExisting", arguments: [:] as [String: Any]
//        )
//
//        var callResult: [String: Any?]?
//        plugin.handle(methodCall) { result in
//            callResult = result as? [String: Any?]
//        }
//
//        XCTAssertNotNil(callResult)
//        XCTAssertEqual(callResult?["rumEnabled"] as? Bool, true)
//    }

    func testSetVerbosity_FromMethodChannel_SetsVerbosity() {
        let flutterConfig = Datadog.Configuration(
            clientToken: "fakeClientToken",
            env: "prod",
            service: "serviceName"
        )

        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig, trackingConsent: .granted)
        let methodCall = FlutterMethodCall(
            methodName: "setSdkVerbosity", arguments: [
                "value": "CoreLoggerLevel.warn"
            ])

        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        XCTAssertEqual(Datadog.verbosityLevel, .warn)
        XCTAssertEqual(callResult, .called(value: nil))
    }

    func testSetTrackingConsent_FromMethodChannel_SetsTrackingConsent() {
        let flutterConfig = Datadog.Configuration(
            clientToken: "fakeClientToken",
            env: "prod",
            service: "serviceName"
        )

        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig, trackingConsent: .pending)
        let methodCall = FlutterMethodCall(
            methodName: "setTrackingConsent", arguments: [
                "value": "TrackingConsent.notGranted"
            ])

        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        let core = plugin.core as? DatadogCore
        XCTAssertEqual(core?.consentPublisher.consent, .notGranted)
        XCTAssertEqual(callResult, .called(value: nil))
    }

    func testSetUserInfo_FromMethodChannel_SetsUserInfo() {
        let flutterConfig = Datadog.Configuration(
            clientToken: "fakeClientToken",
            env: "prod",
            service: "serviceName"
        )

        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig, trackingConsent: .granted)
        let methodCall = FlutterMethodCall(
            methodName: "setUserInfo", arguments: [
                "id": "fakeUserId",
                "name": "fake user name",
                "email": "fake email",
                "extraInfo": [:] as [String: Any?]
            ] as [String: Any?])

        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        let core = plugin.core as? DatadogCore
        let expectedUserInfo = UserInfo(id: "fakeUserId", name: "fake user name", email: "fake email", extraInfo: [:])
        XCTAssertEqual(core?.userInfoPublisher.current, expectedUserInfo)
        XCTAssertEqual(callResult, .called(value: nil))
    }

    func testSetUserInfo_FromMethodChannelWithNils_SetsUserInfo() {
        let flutterConfig = Datadog.Configuration(
            clientToken: "fakeClientToken",
            env: "prod",
            service: "serviceName"
        )

        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig, trackingConsent: .granted)
        let methodCall = FlutterMethodCall(
            methodName: "setUserInfo", arguments: [
                "id": "fakeUserId",
                "name": nil,
                "email": nil,
                "extraInfo": [
                    "attribute": NSNumber(23.3)
                ]
            ] as [String: Any?])

        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        let expectedUserInfo = UserInfo(id: "fakeUserId",
                                        name: nil,
                                        email: nil,
                                        extraInfo: [
                                            "attribute": 23.3
                                        ])

        let core = plugin.core as? DatadogCore
        XCTAssertEqual(core?.userInfoPublisher.current, expectedUserInfo)
        XCTAssertEqual(callResult, .called(value: nil))
    }

    func testAddUserExtraInfo_FromMethodChannel_AddsUserInfo() {
        let flutterConfig = Datadog.Configuration(
            clientToken: "fakeClientToken",
            env: "prod",
            service: "serviceName"
        )

        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig, trackingConsent: .granted)
        let methodCall = FlutterMethodCall(
            methodName: "addUserExtraInfo", arguments: [
                "extraInfo": [
                    "attribute_1": NSNumber(23.3),
                    "attribute_2": "attribute_value"
                ] as [String: Any?]
            ] as [String: Any?])

        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        let expectedUserInfo = UserInfo(
            id: nil,
            name: nil,
            email: nil,
            extraInfo: [
                "attribute_1": 23.3,
                "attribute_2": "attribute_value"
            ])

        let core = plugin.core as? DatadogCore
        XCTAssertEqual(core?.userInfoPublisher.current, expectedUserInfo)
        XCTAssertEqual(callResult, .called(value: nil))
    }

    // Not sure how to check what changes have been made to the Configuraiton Telemetry in v2
//    func testConfigurationOverrides_FromMethodChannel_AreOverridden() {
//        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
//        plugin.core?.
//
//        let trackViewsManually: Bool = .random()
//        let trackInteractions: Bool = .random()
//        let trackErrors: Bool = .random()
//        let trackNetworkRequests: Bool = .random()
//        let trackNativeViews: Bool = .random()
//        let trackCrossPlatformLongTasks: Bool = .random()
//        let trackFlutterPerformance: Bool = .random()
//
//        func callAndCheck(property: String, value: Bool, check: () -> Void) {
//            var callResult = ResultStatus.notCalled
//            let call = FlutterMethodCall(methodName: "updateTelemetryConfiguration", arguments: [
//                "option": property,
//                "value": value
//            ] as [String: Any?])
//            plugin.handle(call) { result in
//                callResult = .called(value: result)
//            }
//
//            XCTAssertEqual(callResult, .called(value: nil))
//            check()
//        }
//
//        callAndCheck(property: "trackViewsManually", value: trackViewsManually) {
//            XCTAssertEqual(plugin.configurationTelemetryOverrides.trackViewsManually, trackViewsManually)
//        }
//        callAndCheck(property: "trackInteractions", value: trackInteractions) {
//            XCTAssertEqual(plugin.configurationTelemetryOverrides.trackInteractions, trackInteractions)
//        }
//        callAndCheck(property: "trackErrors", value: trackErrors) {
//            XCTAssertEqual(plugin.configurationTelemetryOverrides.trackErrors, trackErrors)
//        }
//        callAndCheck(property: "trackNetworkRequests", value: trackNetworkRequests) {
//            XCTAssertEqual(plugin.configurationTelemetryOverrides.trackNetworkRequests, trackNetworkRequests)
//        }
//        callAndCheck(property: "trackNativeViews", value: trackNativeViews) {
//            XCTAssertEqual(plugin.configurationTelemetryOverrides.trackNativeViews, trackNativeViews)
//        }
//        callAndCheck(property: "trackCrossPlatformLongTasks", value: trackCrossPlatformLongTasks) {
//            XCTAssertEqual(
//                plugin.configurationTelemetryOverrides.trackCrossPlatformLongTasks,
//                trackCrossPlatformLongTasks)
//        }
//        callAndCheck(property: "trackFlutterPerformance", value: trackFlutterPerformance) {
//            XCTAssertEqual(plugin.configurationTelemetryOverrides.trackFlutterPerformance, trackFlutterPerformance)
//        }
//    }
}
