// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation
import Flutter
import XCTest
@testable import datadog_webview_tracking

enum ResultStatus: EquatableInTests {
    case notCalled
    case called(value: Any?)
}

class FlutterSdkTests: XCTestCase {
    func testInitWebView_MissingIdentifier_ReturnsError() {
        let plugin = DatadogWebViewTrackingPlugin(channel: .init())
        let call = FlutterMethodCall(methodName: "initWebView", arguments: [
            "allowedHosts": []
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call, result: { result in
            resultStatus = .called(value: result)
        })

        switch resultStatus {
        case .called(value: let value):
            let error = value as? FlutterError
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.code, "DatadogSdk:ContractViolation",
                           "initWebView did not throw a contact violation when missing parameter 'webViewIdentifier'")
            XCTAssertNotNil(error?.message)
        case .notCalled:
            XCTFail("result was not called during initWebView call")
        }
    }

    func testInitWebView_MissingAllowedHosts_ReturnsError() {
        let plugin = DatadogWebViewTrackingPlugin(channel: .init())
        let call = FlutterMethodCall(methodName: "initWebView", arguments: [
            "webViewIdentifier": 5
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call, result: { result in
            resultStatus = .called(value: result)
        })

        switch resultStatus {
        case .called(value: let value):
            let error = value as? FlutterError
            XCTAssertNotNil(error)
            XCTAssertEqual(error?.code, "DatadogSdk:ContractViolation",
                           "initWebView did not throw a contact violation when missing parameter 'allowedHosts'")
            XCTAssertNotNil(error?.message)
        case .notCalled:
            XCTFail("result was not called during initWebView call")
        }
    }

    func testInitWebView_WithValidParameters_ReturnsSuccess() {
        let plugin = DatadogWebViewTrackingPlugin(channel: .init())
        let call = FlutterMethodCall(methodName: "initWebView", arguments: [
            "webViewIdentifier": 5,
            "allowedHosts": []
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call, result: { result in
            resultStatus = .called(value: result)
        })

        XCTAssertEqual(resultStatus, .called(value: nil))
    }
}
