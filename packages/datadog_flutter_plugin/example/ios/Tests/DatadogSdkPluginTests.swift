// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import XCTest
@testable import Datadog
@testable import datadog_flutter_plugin

extension UserInfo: EquatableInTests { }

// Note: These tests are in the example app because Flutter does not provide a simple
// way to to include tests in the Podspec.
class FlutterSdkTests: XCTestCase {

    override func setUp() {
        if Datadog.instance != nil {
            // Somehow we ended up with an extra instance of Datadog?
            Datadog.flushAndDeinitialize()
        }
    }

    override func tearDown() {
        Datadog.flushAndDeinitialize()
    }

    func testInitialziation_MissingConfiguration_DoesNotInitFeatures() {
        let flutterConfig = DatadogFlutterConfiguration(
            clientToken: "fakeClientToken",
            env: "prod",
            serviceName: "serviceName",
            trackingConsent: TrackingConsent.granted,
            nativeCrashReportingEnabled: false
        )

        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig)

        XCTAssertTrue(Datadog.isInitialized)

        XCTAssertNotNil(Global.rum as? DDNoopRUMMonitor)
        XCTAssertNotNil(Global.sharedTracer as? DDNoopTracer)

        XCTAssertNil(plugin.logs)
        XCTAssertNil(plugin.rum)
    }

    func testInitialization_RumConfiguration_InitializesRum() {
        let flutterConfig = DatadogFlutterConfiguration(
            clientToken: "fakeClientToken",
            env: "prod",
            serviceName: "serviceName",
            trackingConsent: TrackingConsent.granted,
            nativeCrashReportingEnabled: true,
            rumConfiguration: DatadogFlutterConfiguration.RumConfiguration(
                applicationId: "fakeApplicationId",
                sampleRate: 100.0
            )
        )

        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig)

        XCTAssertNotNil(plugin.rum)
        XCTAssertEqual(plugin.rum?.isInitialized, true)
        XCTAssertNotNil(Global.rum)
        XCTAssertNil(Global.rum as? DDNoopRUMMonitor)
    }

    func testInitialization_FromMethodChannel_InitializesDatadog() {
        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
        let methodCall = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "configuration": [
                    "clientToken": "fakeClientToken",
                    "env": "prod",
                    "trackingConsent": "TrackingConsent.granted",
                    "nativeCrashReportEnabled": false
                ]
            ]
        )
        plugin.handle(methodCall) { _ in }

        XCTAssertTrue(Datadog.isInitialized)

        XCTAssertNotNil(Global.rum as? DDNoopRUMMonitor)
        XCTAssertNotNil(Global.sharedTracer as? DDNoopTracer)
    }

    func testRepeatInitialization_FromMethodChannelSameOptions_DoesNothing() {
        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
        let configuration: [String: Any?] = [
            "clientToken": "fakeClientToken",
            "env": "prod",
            "trackingConsent": "TrackingConsent.granted",
            "nativeCrashReportEnabled": false,
            "loggingConfiguration": nil
        ]

        let methodCallA = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "configuration": configuration
            ]
        )
        plugin.handle(methodCallA) { _ in }

        XCTAssertTrue(Datadog.isInitialized)

        var loggedConsoleLines: [String] = []
        consolePrint = { str in loggedConsoleLines.append(str) }

        let methodCallB = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "configuration": configuration
            ]
        )
        plugin.handle(methodCallB) { _ in }

        print(loggedConsoleLines)

        XCTAssertTrue(loggedConsoleLines.isEmpty)
    }

    func testRepeatInitialization_FromMethodChannelDifferentOptions_PrintsError() {
        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
        let methodCallA = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "configuration": [
                    "clientToken": "fakeClientToken",
                    "env": "prod",
                    "trackingConsent": "TrackingConsent.granted",
                    "nativeCrashReportEnabled": false,
                    "loggingConfiguration": nil
                ]
            ]
        )
        plugin.handle(methodCallA) { _ in }

        XCTAssertTrue(Datadog.isInitialized)

        var loggedConsoleLines: [String] = []
        consolePrint = { str in loggedConsoleLines.append(str) }

        let methodCallB = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "configuration": [
                    "clientToken": "changedClientToken",
                    "env": "debug",
                    "trackingConsent": "TrackingConsent.granted",
                    "nativeCrashReportEnabled": false,
                    "loggingConfiguration": nil
                ]
            ]
        )
        plugin.handle(methodCallB) { _ in }

        print(loggedConsoleLines)

        XCTAssertFalse(loggedConsoleLines.isEmpty)
        XCTAssertTrue(loggedConsoleLines.first?.contains("🔥") == true)
    }

    func testSetVerbosity_FromMethodChannel_SetsVerbosity() {
        let flutterConfig = DatadogFlutterConfiguration(
            clientToken: "fakeClientToken",
            env: "prod",
            serviceName: "serviceName",
            trackingConsent: TrackingConsent.granted,
            nativeCrashReportingEnabled: false
        )

        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig)
        let methodCall = FlutterMethodCall(
            methodName: "setSdkVerbosity", arguments: [
                "value": "Verbosity.info"
            ])

        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        XCTAssertEqual(Datadog.verbosityLevel, .info)
        XCTAssertEqual(callResult, .called(value: nil))
    }

    func testSetTrackingConsent_FromMethodChannel_SetsTrackingConsent() {
        let flutterConfig = DatadogFlutterConfiguration(
            clientToken: "fakeClientToken",
            env: "prod",
            serviceName: "serviceName",
            trackingConsent: TrackingConsent.granted,
            nativeCrashReportingEnabled: false
        )

        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig)
        let methodCall = FlutterMethodCall(
            methodName: "setTrackingConsent", arguments: [
                "value": "TrackingConsent.notGranted"
            ])

        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        XCTAssertEqual(Datadog.instance?.consentProvider.currentValue, .notGranted)
        XCTAssertEqual(callResult, .called(value: nil))
    }

    func testSetUserInfo_FromMethodChannel_SetsUserInfo() {
        let flutterConfig = DatadogFlutterConfiguration(
            clientToken: "fakeClientToken",
            env: "prod",
            serviceName: "serviceName",
            trackingConsent: TrackingConsent.granted,
            nativeCrashReportingEnabled: false
        )

        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig)
        let methodCall = FlutterMethodCall(
            methodName: "setUserInfo", arguments: [
                "id": "fakeUserId",
                "name": "fake user name",
                "email": "fake email",
                "extraInfo": [:]
            ])

        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        let expectedUserInfo = UserInfo(id: "fakeUserId", name: "fake user name", email: "fake email", extraInfo: [:])
        XCTAssertEqual(Datadog.instance?.userInfoProvider.value, expectedUserInfo)
        XCTAssertEqual(callResult, .called(value: nil))
    }

    func testSetUserInfo_FromMethodChannelWithNils_SetsUserInfo() {
        let flutterConfig = DatadogFlutterConfiguration(
            clientToken: "fakeClientToken",
            env: "prod",
            serviceName: "serviceName",
            trackingConsent: TrackingConsent.granted,
            nativeCrashReportingEnabled: false
        )

        let plugin = SwiftDatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig)
        let methodCall = FlutterMethodCall(
            methodName: "setUserInfo", arguments: [
                "id": "fakeUserId",
                "name": nil,
                "email": nil,
                "extraInfo": [
                    "attribute": NSNumber(23.3)
                ]
            ])

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
        XCTAssertEqual(Datadog.instance?.userInfoProvider.value, expectedUserInfo)
        XCTAssertEqual(callResult, .called(value: nil))
    }
}
