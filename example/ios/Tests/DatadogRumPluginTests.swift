/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2022 Datadog, Inc.
 */

import XCTest
@testable import Datadog
import datadog_sdk

func ==(lhs: [AttributeKey: AttributeValue], rhs: [AttributeKey: AttributeValue]) -> Bool {
  return NSDictionary(dictionary: lhs).isEqual(rhs)
}

class MockRUMMonitor: DDRUMMonitor {
  enum MethodCall: Equatable {
    case startView(key: String, name: String?, attributes: [AttributeKey: AttributeValue])
    case stopView(key: String, attributes: [AttributeKey: AttributeValue])
    case addTiming(name: String)

    static func == (lhs: MockRUMMonitor.MethodCall, rhs: MockRUMMonitor.MethodCall) -> Bool {
      switch(lhs, rhs) {
      case(.startView(let lhsKey, let lhsName, let lhsAttributes), .startView(let rhsKey, let rhsName, let rhsAttributes)):
        return lhsKey == rhsKey
          && lhsName == rhsName
          && lhsAttributes == rhsAttributes
      case(.stopView(let lhsKey, let lhsAttributes), .stopView(let rhsKey, let rhsAttributes)):
        return lhsKey == rhsKey
          && lhsAttributes == rhsAttributes
      case(.addTiming(let lhsName), .addTiming(let rhsName)):
        return lhsName == rhsName
      default:
        return false;
      }
    }
  }

  var callLog: [MethodCall] = []

  override func startView(key: String, name: String? = nil, attributes: [AttributeKey: AttributeValue] = [:]) {
    callLog.append(.startView(key: key, name: name, attributes: attributes))
  }

  override func stopView(key: String, attributes: [AttributeKey: AttributeValue] = [:]) {
    callLog.append(.stopView(key: key, attributes: attributes))
  }

  override func addTiming(name: String) {
    callLog.append(.addTiming(name: name))
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
      XCTAssertEqual(mock.callLog[0], .startView(key: "view_key",
                                                 name: "view_name",
                                                 attributes: ["my_attribute": "my_value"]))
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
      XCTAssertEqual(mock.callLog[0], .stopView(key: "view_key", attributes: ["my_attribute": "my_value"]))
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
      XCTAssertEqual(mock.callLog[0], .addTiming(name: "timing name"))
    }

    XCTAssertTrue(resultCalled)
    XCTAssertNil(resultValue)

  }
}
