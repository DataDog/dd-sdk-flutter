/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2022 Datadog, Inc.
 */

import XCTest
@testable import Datadog
@testable import datadog_flutter_plugin

class DatadogTracesPluginTests: XCTestCase {

  var plugin: DatadogTracesPlugin!
  var nextSpanId: Int64 = 1

  override func setUp() {
    nextSpanId += 1
    plugin = DatadogTracesPlugin.instance
    plugin.initialize(withTracer: DDNoopTracer())
  }

  let contracts = [
    Contract(methodName: "startRootSpan", requiredParameters: [
      "spanHandle": .int64,
      "operationName": .string,
      "startTime": .int64
    ]),
    Contract(methodName: "startSpan", requiredParameters: [
      "spanHandle": .int64,
      "operationName": .string,
      "startTime": .int64
    ])
  ]

  func testTracesPlugin_ContractViolationsThrowErrors() {
    testContracts(contracts: contracts, plugin: plugin)
  }

  let spanContracts = [
    Contract(methodName: "span.setError", requiredParameters: [
      "kind": .string, "message": .string
    ]),
    Contract(methodName: "span.setTag", requiredParameters: [
      "key": .string, "value": .string
    ]),
    Contract(methodName: "span.setBaggageItem", requiredParameters: [
      "key": .string, "value": .string
    ]),
    Contract(methodName: "span.log", requiredParameters: [
      "fields": .map
    ])
  ]

  func createSpan(operationName: String) -> Int64 {
    let spanId = nextSpanId
    nextSpanId += 1

    let startTime = Date.now.timeIntervalSince1970 * 1_000_000
    let call = FlutterMethodCall(methodName: "startRootSpan", arguments: [
      "spanHandle": spanId,
      "operationName": operationName,
      "startTime": startTime
    ])
    plugin.handle(call) { _ in

    }

    return spanId
  }

  func testSpan_ContractViolationsThrowErrors() {
    let spanHandle = createSpan(operationName: "testSpanOperation")
    testContracts(contracts: spanContracts, plugin: plugin, additionalArguments: [
      "spanHandle": spanHandle
    ])
  }

  func testSpanSetError_WithMissingParameter_FailsWithContractViolation() {
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
      XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation)
      XCTAssertNotNil(error?.message)

    case .notCalled:
      XCTFail("result was not called")
    }
  }

  func testSpanSetTag_WithMissingParameter_FailsWithContractViolation() {
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
      XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation)
      XCTAssertNotNil(error?.message)

    case .notCalled:
      XCTFail("result was not called")
    }
  }

  func testSpanSetBaggageItem_WithMissingParameter_FailsWithContractViolation() {
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
      XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation)
      XCTAssertNotNil(error?.message)

    case .notCalled:
      XCTFail("result was not called")
    }
  }

  func testSpanLog_WithMissingParameter_FailsWithContractViolation() {
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
      XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation)
      XCTAssertNotNil(error?.message)

    case .notCalled:
      XCTFail("result was not called")
    }
  }

  func testSpanFinish_WithMissingParameters_FailsWithContractViolation() {
    // Can't test this with previous contract testing because finishing the span removes it
    // from the handle map, which the valid call does.
    let spanHandle = createSpan(operationName: "spanFinishOperation")
    let call = FlutterMethodCall(methodName: "span.finish", arguments: [
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
      XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation)
      XCTAssertNotNil(error?.message)

    case .notCalled:
      XCTFail("result was not called")
    }
  }
}
