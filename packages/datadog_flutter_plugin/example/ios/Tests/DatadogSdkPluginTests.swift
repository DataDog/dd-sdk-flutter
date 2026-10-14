// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.
// swiftlint:disable file_length

import XCTest
import Flutter
@testable import DatadogCore
@testable import DatadogInternal
@testable import datadog_flutter_plugin

extension UserInfo: @retroactive Equatable {}
extension UserInfo: EquatableInTests { }
extension AccountInfo: @retroactive Equatable {}
extension AccountInfo: EquatableInTests { }

// Note: These tests are in the example app because Flutter does not provide a simple
// way to to include tests in the Podspec.
// swiftlint:disable:next type_body_length
class FlutterSdkTests: XCTestCase {

    override func setUp() {
        if Datadog.isInitialized() {
            // Somehow we ended up with an extra instance of Datadog?
            Datadog.internalFlushAndDeinitialize()
        }
    }

    override func tearDown() {
        if Datadog.isInitialized() {
            Datadog.internalFlushAndDeinitialize()
        }
    }

    let contracts = [
        Contract(methodName: "setSdkVerbosity", requiredParameters: [
            "value": .string
        ]),
        Contract(methodName: "setUserInfo", requiredParameters: [
            "id": .string,
            "extraInfo": .map
        ]),
        Contract(methodName: "clearUserInfo", requiredParameters: [:]),
        Contract(methodName: "addUserExtraInfo", requiredParameters: [
            "extraInfo": .map
        ]),
        Contract(methodName: "setAccountInfo", requiredParameters: [
            "id": .string,
            "extraInfo": .map
        ]),
        Contract(methodName: "addAccountExtraInfo", requiredParameters: [
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

    func testClearUserInfo_FromMethodChannel_ClearsUserInfo() {
        // Given
        let flutterConfig = Datadog.Configuration(
            clientToken: "fakeClientToken",
            env: "prod",
            service: "serviceName"
        )

        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig, trackingConsent: .granted)
        plugin.handle(FlutterMethodCall(
            methodName: "setUserInfo", arguments: [
                "id": "fakeUserId",
                "extraInfo": [
                    "attribute": NSNumber(23.3)
                ]
            ])) { _ in }

        // When
        let methodCall = FlutterMethodCall(methodName: "clearUserInfo", arguments: [:])
        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        // Then
        let expectedUserInfo = UserInfo()

        let core = plugin.core as? DatadogCore
        XCTAssertEqual(core?.userInfoPublisher.current, expectedUserInfo)
        XCTAssertEqual(callResult, .called(value: nil))
    }

    func testSetAccountInfo_FromMethodChannel_SetsAccountInfo() {
        let flutterConfig = Datadog.Configuration(
            clientToken: "fakeClientToken",
            env: "prod",
            service: "serviceName"
        )

        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig, trackingConsent: .granted)
        let methodCall = FlutterMethodCall(
            methodName: "setAccountInfo", arguments: [
                "id": "fakeAccountId",
                "name": "fakeAccountName",
                "extraInfo": [
                    "attribute": NSNumber(14141.3)
                ]
            ] as [String: Any?])

        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        let expectedAccountInfo = AccountInfo(id: "fakeAccountId", name: "fakeAccountName", extraInfo: [
            "attribute": 14141.3
        ])

        let core = plugin.core as? DatadogCore
        XCTAssertEqual(core?.accountInfoPublisher.current, expectedAccountInfo)
        XCTAssertEqual(callResult, .called(value: nil))
    }

    func testAddAccountExtraInfo_FromMethodChannel_AddsAccountInfo() {
        let flutterConfig = Datadog.Configuration(
            clientToken: "fakeClientToken",
            env: "prod",
            service: "serviceName"
        )

        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig, trackingConsent: .granted)

        plugin.handle(FlutterMethodCall(
            methodName: "setAccountInfo", arguments: [
                "id": "fakeAccountId",
                "extraInfo": [:]
            ])) { _ in

            }

        let methodCall = FlutterMethodCall(
            methodName: "addAccountExtraInfo", arguments: [
                "extraInfo": [
                    "attribute_1": NSNumber(23.3),
                    "attribute_2": "attribute_value"
                ] as [String: Any?]
            ] as [String: Any?])

        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        let expectedAccountInfo = AccountInfo(id: "fakeAccountId", extraInfo: [
            "attribute_1": 23.3,
            "attribute_2": "attribute_value"
        ])

        let core = plugin.core as? DatadogCore
        XCTAssertEqual(core?.accountInfoPublisher.current, expectedAccountInfo)
        XCTAssertEqual(callResult, .called(value: nil))
    }

    func testClearAccountInfo_FromMethodChannel_ClearsAccountInfo() {
        // Given
        let flutterConfig = Datadog.Configuration(
            clientToken: "fakeClientToken",
            env: "prod",
            service: "serviceName"
        )

        let plugin = DatadogSdkPlugin(channel: FlutterMethodChannel())
        plugin.initialize(configuration: flutterConfig, trackingConsent: .granted)
        plugin.handle(FlutterMethodCall(
            methodName: "setAccountInfo", arguments: [
                "id": "fakeAccountId",
                "extraInfo": [
                    "attribute": NSNumber(23.3)
                ]
            ])) { _ in }

        // When
        let methodCall = FlutterMethodCall(methodName: "clearAccountInfo", arguments: [:])
        var callResult = ResultStatus.notCalled
        plugin.handle(methodCall) { result in
            callResult = ResultStatus.called(value: result)
        }

        // Then
        let core = plugin.core as? DatadogCore
        XCTAssertNil(core?.accountInfoPublisher.current?.name)
        XCTAssert(core?.accountInfoPublisher.current?.extraInfo.isEmpty ?? true)
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

/// A messenger that does nothing. `FlutterMethodChannel` needs one to exist, but these tests only
/// care about whether the channel is still held, never about messages crossing it.
private class NoOpBinaryMessenger: NSObject, FlutterBinaryMessenger {
    func send(onChannel channel: String, message: Data?) { }

    func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply? = nil) { }

    func setMessageHandlerOnChannel(
        _ channel: String,
        binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
    ) -> FlutterBinaryMessengerConnection {
        return 0
    }

    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) { }
}

/// A messenger that records which channels were sent on, for asserting that nothing reached Dart.
private class RecordingBinaryMessenger: NSObject, FlutterBinaryMessenger {
    private(set) var sentChannels: [String] = []

    func send(onChannel channel: String, message: Data?) {
        sentChannels.append(channel)
    }

    func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply? = nil) {
        sentChannels.append(channel)
    }

    func setMessageHandlerOnChannel(
        _ channel: String,
        binaryMessageHandler handler: FlutterBinaryMessageHandler? = nil
    ) -> FlutterBinaryMessengerConnection {
        return 0
    }

    func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) { }
}

/// Teardown has to drop every channel the SDK can call Dart on. Flutter resets the engine's shell on
/// termination without notifying plugins (flutter/flutter#126671), and anything sent afterwards
/// asserts inside `-[FlutterEngine sendOnChannel:message:binaryReply:]` — see #1062.
class DatadogPluginDetachTests: XCTestCase {
    private let messenger = NoOpBinaryMessenger()

    private func makePlugin(notificationCenter: NotificationCenterProtocol = NotificationCenter.default) -> DatadogSdkPlugin {
        let plugin = DatadogSdkPlugin(
            channel: FlutterMethodChannel(
                name: "datadog_sdk_flutter",
                binaryMessenger: messenger
            ),
            notificationCenter: notificationCenter
        )
        plugin.rum.methodChannel = FlutterMethodChannel(
            name: "datadog_sdk_flutter.rum",
            binaryMessenger: messenger
        )
        plugin.logs.methodChannel = FlutterMethodChannel(
            name: "datadog_sdk_flutter.logs",
            binaryMessenger: messenger
        )
        return plugin
    }

    func testApplicationWillTerminate_releasesEveryMethodChannel() {
        // Posts to an injected `NotificationCenterMock` instead of the real, process-wide center:
        // a real post would tear down every other live `DatadogSdkPlugin` in the process too,
        // including the Runner's own registered plugin and other suites' engines.
        let notificationCenter = NotificationCenterMock()
        let plugin = makePlugin(notificationCenter: notificationCenter)

        // Termination arrives as a notification, not as a plugin callback
        notificationCenter.post(name: UIApplication.willTerminateNotification)

        XCTAssertNil(plugin.rum.methodChannel)
        XCTAssertNil(plugin.logs.methodChannel)
    }

    func testLogCallbackQueuedBeforeTermination_isDropped() {
        // The SDK can log from any thread right before termination: `callLogCallback` hops to main,
        // and by the time that block runs the engine's shell is gone. The guard must not depend on
        // finding the engine through `keyWindow`, which is nil under the UIScene lifecycle.
        let messenger = RecordingBinaryMessenger()
        let notificationCenter = NotificationCenterMock()
        let plugin = DatadogSdkPlugin(
            channel: FlutterMethodChannel(name: "datadog_sdk_flutter", binaryMessenger: messenger),
            notificationCenter: notificationCenter
        )

        plugin.callLogCallback("queued before termination")
        notificationCenter.post(name: UIApplication.willTerminateNotification)
        drainMainQueue()

        XCTAssertEqual(messenger.sentChannels, [])
    }

    func testLogCallback_withoutTeardown_isSent() {
        let messenger = RecordingBinaryMessenger()
        let plugin = DatadogSdkPlugin(
            channel: FlutterMethodChannel(name: "datadog_sdk_flutter", binaryMessenger: messenger),
            notificationCenter: NotificationCenterMock()
        )

        plugin.callLogCallback("regular log line")
        drainMainQueue()

        XCTAssertEqual(messenger.sentChannels, ["datadog_sdk_flutter"])
    }

    /// Lets every block already queued on main (e.g. by `callLogCallback`) run before asserting.
    private func drainMainQueue() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }

    // The tests below use real engines and the real `NotificationCenter.default`: Flutter itself posts
    // `FlutterViewControllerWillDealloc` from `-[FlutterViewController dealloc]`, so it can't be faked
    // faithfully. Safe to observe process-wide, since the plugin ignores other engines' view controllers.

    /// A plugin attached to `engine` whose sends are recorded instead of reaching the engine.
    /// `findingEngine: false` simulates a Flutter version where the engine can't be found behind its
    /// messenger, leaving only the view controller dealloc fallback.
    private func makePlugin(
        attachedTo engine: FlutterEngine,
        recordingInto messenger: RecordingBinaryMessenger,
        findingEngine: Bool = true
    ) -> DatadogSdkPlugin {
        let plugin = DatadogSdkPlugin(
            channel: FlutterMethodChannel(name: "datadog_sdk_flutter", binaryMessenger: messenger),
            notificationCenter: NotificationCenter.default
        )
        if findingEngine {
            plugin.watchEngine(behind: engine.binaryMessenger)
        } else {
            plugin.engineMessenger = engine.binaryMessenger
        }
        plugin.rum.methodChannel = FlutterMethodChannel(name: "datadog_sdk_flutter.rum", binaryMessenger: messenger)
        plugin.logs.methodChannel = FlutterMethodChannel(name: "datadog_sdk_flutter.logs", binaryMessenger: messenger)
        return plugin
    }

    /// Attaches a view controller to `engine` and releases it, which posts `FlutterViewControllerWillDealloc`.
    private func attachAndDeallocViewController(to engine: FlutterEngine) {
        weak var weakViewController: FlutterViewController?
        autoreleasepool {
            let viewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
            weakViewController = viewController
        }
        XCTAssertNil(weakViewController, "the view controller must deallocate for this test to mean anything")
        // No main-queue drain: the plugin must react synchronously, before anything already queued on
        // the main thread (a RUM mapper, a log callback) can reach the torn-down engine.
    }

    private func waitForIsolate(of engine: FlutterEngine) {
        let started = expectation(for: NSPredicate { _, _ in engine.isolateId != nil }, evaluatedWith: nil)
        wait(for: [started], timeout: 10)
    }

    // Both private Flutter hooks the plugin relies on. If a Flutter release changes either, these fail
    // in CI (including the nightly beta run) instead of the protection silently degrading.

    func testFlutterHook_engineIsReachableFromItsRegistrarMessenger() {
        let engine = FlutterEngine(name: "lookup", project: nil, allowHeadlessExecution: true)
        XCTAssertTrue(engine.run())
        let registrar = engine.registrar(forPlugin: "DatadogSdkPluginTests.lookup")

        XCTAssertTrue(DatadogSdkPlugin.engine(behind: registrar!.messenger()) === engine)
    }

    func testFlutterHook_viewControllerDeallocIsPosted() {
        let engine = FlutterEngine(name: "dealloc-notification", project: nil, allowHeadlessExecution: true)
        XCTAssertTrue(engine.run())
        let posted = expectation(forNotification: DatadogSdkPlugin.flutterViewControllerWillDealloc, object: nil)

        attachAndDeallocViewController(to: engine)

        wait(for: [posted], timeout: 1)
    }

    func testDirectDestroyContext_whileViewControllerIsAlive_detachesSynchronously() {
        // The view controller stays alive, so no dealloc notification and no termination: what the
        // plugin sees when a scene disconnects in an app extension, or the host tears the engine down.
        let engine = FlutterEngine(name: "destroyed-with-vc", project: nil, allowHeadlessExecution: false)
        XCTAssertTrue(engine.run())
        let viewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        let messenger = RecordingBinaryMessenger()
        let plugin = makePlugin(attachedTo: engine, recordingInto: messenger)

        engine.destroyContext()

        XCTAssertNil(viewController.engine.isolateId)
        XCTAssertNil(plugin.rum.methodChannel)
        XCTAssertNil(plugin.logs.methodChannel)
        plugin.callLogCallback("sent after the engine was destroyed")
        drainMainQueue()
        XCTAssertEqual(messenger.sentChannels, [])
    }

    func testNonHeadlessEngineLosesItsViewController_withoutEngineLookup_detachesThroughFallback() {
        let engine = FlutterEngine(name: "fallback", project: nil, allowHeadlessExecution: false)
        XCTAssertTrue(engine.run())
        let messenger = RecordingBinaryMessenger()
        let plugin = makePlugin(attachedTo: engine, recordingInto: messenger, findingEngine: false)

        attachAndDeallocViewController(to: engine)

        XCTAssertNil(engine.isolateId)
        XCTAssertNil(plugin.rum.methodChannel)
        XCTAssertNil(plugin.logs.methodChannel)
    }

    func testLogCallback_afterNonHeadlessEngineLosesItsViewController_isDropped() {
        // The host keeps the engine alive, so it never deallocates and `detachFromEngine(for:)` never runs
        let engine = FlutterEngine(name: "non-headless", project: nil, allowHeadlessExecution: false)
        XCTAssertTrue(engine.run())
        let messenger = RecordingBinaryMessenger()
        let plugin = makePlugin(attachedTo: engine, recordingInto: messenger)

        attachAndDeallocViewController(to: engine)
        XCTAssertNil(engine.isolateId, "Flutter should have called destroyContext()")
        // Detached as if the engine had been released: RUM and Logs can no longer call Dart either
        XCTAssertNil(plugin.rum.methodChannel)
        XCTAssertNil(plugin.logs.methodChannel)

        plugin.callLogCallback("sent after the shell was destroyed")
        drainMainQueue()

        XCTAssertEqual(messenger.sentChannels, [])
    }

    func testLogCallback_afterHeadlessEngineLosesItsViewController_isSent() {
        // A headless engine keeps running without a view controller, so logs must keep flowing
        let engine = FlutterEngine(name: "headless", project: nil, allowHeadlessExecution: true)
        XCTAssertTrue(engine.run())
        waitForIsolate(of: engine)
        let messenger = RecordingBinaryMessenger()
        let plugin = makePlugin(attachedTo: engine, recordingInto: messenger)

        attachAndDeallocViewController(to: engine)
        XCTAssertNotNil(engine.isolateId)
        XCTAssertNotNil(plugin.rum.methodChannel)
        XCTAssertNotNil(plugin.logs.methodChannel)

        plugin.callLogCallback("sent to a still-running engine")
        drainMainQueue()

        XCTAssertEqual(messenger.sentChannels, ["datadog_sdk_flutter"])
    }

    func testDirectDestroyContext_afterHeadlessEngineLostItsViewController_detachesSynchronously() {
        // Headless: losing the view controller leaves the engine running, so the plugin stays attached
        // and watches it. When the host later tears it down itself, nothing else tells the plugin.
        let engine = FlutterEngine(name: "headless-then-destroyed", project: nil, allowHeadlessExecution: true)
        XCTAssertTrue(engine.run())
        waitForIsolate(of: engine)
        let messenger = RecordingBinaryMessenger()
        let plugin = makePlugin(attachedTo: engine, recordingInto: messenger)
        attachAndDeallocViewController(to: engine)
        XCTAssertNotNil(plugin.rum.methodChannel)

        engine.destroyContext()

        XCTAssertNil(plugin.rum.methodChannel)
        XCTAssertNil(plugin.logs.methodChannel)
        plugin.callLogCallback("sent after the host destroyed the engine")
        drainMainQueue()
        XCTAssertEqual(messenger.sentChannels, [])
    }

    func testLogCallback_afterAnotherEngineLosesItsViewController_isSent() {
        let ownEngine = FlutterEngine(name: "own", project: nil, allowHeadlessExecution: false)
        let otherEngine = FlutterEngine(name: "other", project: nil, allowHeadlessExecution: false)
        XCTAssertTrue(otherEngine.run())
        let messenger = RecordingBinaryMessenger()
        let plugin = makePlugin(attachedTo: ownEngine, recordingInto: messenger)

        attachAndDeallocViewController(to: otherEngine)
        XCTAssertNil(otherEngine.isolateId)
        XCTAssertNotNil(plugin.rum.methodChannel)
        XCTAssertNotNil(plugin.logs.methodChannel)

        plugin.callLogCallback("sent to an unaffected engine")
        drainMainQueue()

        XCTAssertEqual(messenger.sentChannels, ["datadog_sdk_flutter"])
    }

    func testDetach_isIdempotent() {
        // Both teardown paths can run for the same engine: termination fires the notification, and a
        // host releasing the engine afterwards still calls `detachFromEngine(for:)`.
        let plugin = makePlugin()
        plugin.rum.onDetach()
        plugin.logs.onDetach()
        plugin.rum.onDetach()
        plugin.logs.onDetach()

        XCTAssertNil(plugin.rum.methodChannel)
        XCTAssertNil(plugin.logs.methodChannel)
    }

    func testWithoutAChannel_eventMappersReturnTheEventUnmapped() {
        let plugin = makePlugin()
        plugin.rum.onDetach()

        // Would otherwise hop to the main queue and block on a semaphore until it times out
        let event = plugin.rum.callEventMapper(
            mapperName: "mapViewEvent",
            event: "unmapped",
            encodedEvent: [:],
            completion: { _ in "mapped" }
        )

        XCTAssertEqual(event, "unmapped")
        XCTAssertEqual(plugin.rum.mapperTimeouts, 0)
    }

    func testEngineATeardown_doesNotAffectEngineB() {
        // Regression test for the original multi-engine bug: engine A detaching must not clear
        // engine B's still-live channel (they used to share one process-wide singleton).
        let pluginA = makePlugin()
        let pluginB = makePlugin()

        pluginA.rum.onDetach()
        pluginA.logs.onDetach()

        XCTAssertNil(pluginA.rum.methodChannel)
        XCTAssertNil(pluginA.logs.methodChannel)
        XCTAssertNotNil(pluginB.rum.methodChannel)
        XCTAssertNotNil(pluginB.logs.methodChannel)
    }
}
