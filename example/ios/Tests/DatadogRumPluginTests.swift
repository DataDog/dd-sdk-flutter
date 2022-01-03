/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2022 Datadog, Inc.
 */

import XCTest
@testable import Datadog
import datadog_sdk

class MockRUMMonitor: DDRUMMonitor {
  enum MethodCallType {
    case startView
    case stopView
    case addTiming
  }

  struct MethodCall {
    let callType: MethodCallType
    let arguments: [String: Any?]

    init(callType: MethodCallType, arguments: [String: Any?]) {
      self.callType = callType
      self.arguments = arguments
    }
  }

  var callLog: [MethodCall] = []

  override func startView(key: String, name: String? = nil, attributes: [AttributeKey: AttributeValue] = [:]) {
    let call = MethodCall(callType: .startView, arguments: [
      "key": key,
      "name": name,
      "attributes": attributes
    ])
    callLog.append(call)
  }

  override func stopView(key: String, attributes: [AttributeKey: AttributeValue] = [:]) {
    let call = MethodCall(callType: .stopView, arguments: [
      "key": key,
      "attributes": attributes
    ])
    callLog.append(call)
  }

  override func addTiming(name: String) {
    let call = MethodCall(callType: .addTiming, arguments: [
      "name": name
    ])
    callLog.append(call)
  }
}

class DatadogRumPluginTests: XCTestCase {
  func testStartViewCall_CallsRumMonitor() {
    let mock = MockRUMMonitor()
    let plugin = DatadogRumPlugin(rumInstance: mock)

    let call = FlutterMethodCall(methodName: "startView", arguments: [
      "key": "view_key",
      "name": "view_name",
      "attributes": ["my_attribute": "my_value"]
    ])

    var resultCalled = false
    var resultValue: Any?
    plugin.handle(call) { result in
      resultCalled = true
      resultValue = result
    }

    XCTAssertEqual(mock.callLog.count, 1)
    if mock.callLog.count == 1 {
      XCTAssertEqual(mock.callLog[0].callType, .startView)
      XCTAssertEqual(mock.callLog[0].arguments["key"] as! String, "view_key")
      XCTAssertEqual(mock.callLog[0].arguments["name"] as! String, "view_name")
      let callAttributes = mock.callLog[0].arguments["attributes"] as! [AttributeKey: AttributeValue]
      XCTAssertEqual(callAttributes["my_attribute"] as! String, "my_value")
    }

    XCTAssertTrue(resultCalled)
    XCTAssertNil(resultValue)
  }

  func testStopViewCall_CallsRumMonitor() {
    let mock = MockRUMMonitor()
    let plugin = DatadogRumPlugin(rumInstance: mock)

    let call = FlutterMethodCall(methodName: "stopView", arguments: [
      "key": "view_key",
      "attributes": ["my_attribute": "my_value"]
    ])

    var resultCalled = false
    var resultValue: Any?
    plugin.handle(call) { result in
      resultCalled = true
      resultValue = result
    }

    XCTAssertEqual(mock.callLog.count, 1)
    if mock.callLog.count == 1 {
      XCTAssertEqual(mock.callLog[0].callType, .stopView)
      XCTAssertEqual(mock.callLog[0].arguments["key"] as! String, "view_key")
      let callAttributes = mock.callLog[0].arguments["attributes"] as! [AttributeKey: AttributeValue]
      XCTAssertEqual(callAttributes["my_attribute"] as! String, "my_value")
    }

    XCTAssertTrue(resultCalled)
    XCTAssertNil(resultValue)
  }

  func testAddTimeingCall_CallsRumMonitor() {
    let mock = MockRUMMonitor()
    let plugin = DatadogRumPlugin(rumInstance: mock)

    let call = FlutterMethodCall(methodName: "addTiming", arguments: [
      "name": "timing name"
    ])

    var resultCalled = false
    var resultValue: Any?
    plugin.handle(call) { result in
      resultCalled = true
      resultValue = result
    }

    XCTAssertEqual(mock.callLog.count, 1)
    if mock.callLog.count == 1 {
      XCTAssertEqual(mock.callLog[0].callType, .addTiming)
      XCTAssertEqual(mock.callLog[0].arguments["name"] as! String, "timing name")
    }

    XCTAssertTrue(resultCalled)
    XCTAssertNil(resultValue)

  }
}
