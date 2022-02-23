/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2022 Datadog, Inc.
 */

import XCTest
@testable import Datadog
@testable import datadog_sdk

class DatadogTracesPluginTests: XCTestCase {

  var plugin: DatadogTracesPlugin!

  override func setUp() {
    plugin = DatadogTracesPlugin.instance
    plugin.initialize(withTracer: DDNoopTracer())
  }

  func testTracesStartRootSpan_WithMissingParameter_FailsWithContractViolation() {
    let tags: [String: Any] = [:]
    let call = FlutterMethodCall(methodName: "startRootSpan", arguments: [
      "tags": tags
    ])

    var resultStatus = ResultStatus.notCalled
    plugin.handle(call) { result in
      resultStatus = .called(value: result)
    }

    switch resultStatus {
    case .called(let value):
      let error = value as? FlutterError
      XCTAssertNotNil(error)
      XCTAssertEqual(error?.code, DdFlutterErrorCodes.contractViolation)
      XCTAssertNotNil(error?.message)

    case .notCalled:
      XCTFail("result was not called")
    }
  }

  func testTracesStartSpan_WithMissingParameter_FailsWithContractViolation() {
    let tags: [String: Any] = [:]
    let call = FlutterMethodCall(methodName: "startSpan", arguments: [
      "tags": tags
    ])

    var resultStatus = ResultStatus.notCalled
    plugin.handle(call) { result in
      resultStatus = .called(value: result)
    }

    switch resultStatus {
    case .called(let value):
      let error = value as? FlutterError
      XCTAssertNotNil(error)
      XCTAssertEqual(error?.code, DdFlutterErrorCodes.contractViolation)
      XCTAssertNotNil(error?.message)

    case .notCalled:
      XCTFail("result was not called")
    }
  }

  func createSpan(operationName: String) -> Int64 {
    var result: Int64!
    let call = FlutterMethodCall(methodName: "startRootSpan", arguments: [
      "operationName": operationName
    ])
    plugin.handle(call) { spanHandle in
      result = (spanHandle as! Int64)
    }

    return result
  }

  func testSpanSetError_WithMissingParameter_FailsWithCOntractViolation() {
    let spanHandle = createSpan(operationName: "spanSetErrorOperation")
    let call = FlutterMethodCall(methodName: "span.setError", arguments: [
      "spanHandle": spanHandle,
      "message": "fake message"
    ])

    var resultStatus = ResultStatus.notCalled
    plugin.handle(call) { result in
      resultStatus = .called(value: result)
    }

    switch resultStatus {
    case .called(let value):
      let error = value as? FlutterError
      XCTAssertNotNil(error)
      XCTAssertEqual(error?.code, DdFlutterErrorCodes.contractViolation)
      XCTAssertNotNil(error?.message)

    case .notCalled:
      XCTFail("result was not called")
    }
  }

  func testSpanSetTag_WithMissingParameter_FailsWithCOntractViolation() {
    let spanHandle = createSpan(operationName: "spanSetTagOperation")
    let call = FlutterMethodCall(methodName: "span.setTag", arguments: [
      "spanHandle": spanHandle,
      "key": "key"
    ])

    var resultStatus = ResultStatus.notCalled
    plugin.handle(call) { result in
      resultStatus = .called(value: result)
    }

    switch resultStatus {
    case .called(let value):
      let error = value as? FlutterError
      XCTAssertNotNil(error)
      XCTAssertEqual(error?.code, DdFlutterErrorCodes.contractViolation)
      XCTAssertNotNil(error?.message)

    case .notCalled:
      XCTFail("result was not called")
    }
  }

  func testSpanSetBaggageItem_WithMissingParameter_FailsWithCOntractViolation() {
    let spanHandle = createSpan(operationName: "spanSetBaggageItemOperation")
    let call = FlutterMethodCall(methodName: "span.setBaggageItem", arguments: [
      "spanHandle": spanHandle,
      "key": "key"
    ])

    var resultStatus = ResultStatus.notCalled
    plugin.handle(call) { result in
      resultStatus = .called(value: result)
    }

    switch resultStatus {
    case .called(let value):
      let error = value as? FlutterError
      XCTAssertNotNil(error)
      XCTAssertEqual(error?.code, DdFlutterErrorCodes.contractViolation)
      XCTAssertNotNil(error?.message)

    case .notCalled:
      XCTFail("result was not called")
    }
  }

  func testSpanLog_WithMissingParameter_FailsWithCOntractViolation() {
    let spanHandle = createSpan(operationName: "spanLogOperation")
    let call = FlutterMethodCall(methodName: "span.log", arguments: [
      "spanHandle": spanHandle
    ])

    var resultStatus = ResultStatus.notCalled
    plugin.handle(call) { result in
      resultStatus = .called(value: result)
    }

    switch resultStatus {
    case .called(let value):
      let error = value as? FlutterError
      XCTAssertNotNil(error)
      XCTAssertEqual(error?.code, DdFlutterErrorCodes.contractViolation)
      XCTAssertNotNil(error?.message)

    case .notCalled:
      XCTFail("result was not called")
    }
  }
}
