// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import XCTest
@testable import Datadog
@testable import datadog_sdk

class MockLogger: Logger {
  init() {
    super.init(logBuilder: nil,
               logOutput: nil,
               dateProvider: SystemDateProvider(),
               identifier: "MockLogger",
               rumContextIntegration: nil,
               activeSpanIntegration: nil)
  }
}

class DatadogLogsPlugihnTests: XCTestCase {
  var plugin: DatadogLogsPlugin!

  override func setUp() {
    plugin = DatadogLogsPlugin.instance
    plugin.logger = MockLogger()
  }

  func testLogCalls_WithMissingParameter_FailsWithContractViolation() {
    let logMethods = ["debug", "info", "warn", "error"]

    for method in logMethods {
      let call = FlutterMethodCall(methodName: method, arguments: [:])

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

  func testLogCalls_WithBadParameter_FailsWithContractViolation() {
    let logMethods = ["debug", "info", "warn", "error"]

    for method in logMethods {
      let call = FlutterMethodCall(methodName: method, arguments: [
        "message": 123
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

  func testLogAddAttribute_WithMissingKey_FailsWithContractViolation() {
    let call = FlutterMethodCall(methodName: "addAttribute", arguments: [
      "key": "fake key"
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

  func testLogAddAttribute_WithMissingValue_FailsWithContractViolation() {
    let call = FlutterMethodCall(methodName: "addAttribute", arguments: [
      "key": "fake key"
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

  func testLogAddAttribute_WithBadKey_FailsWithContractViolation() {
    let call = FlutterMethodCall(methodName: "addAttribute", arguments: [
      "key": 12315
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

  func testLogRemoveAttribute_WithMissingKey_FailsWithContractViolation() {
    let call = FlutterMethodCall(methodName: "removeAttribute", arguments: [:])

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

  func testLogRemoveAttribute_WithBadKey_FailsWithContractViolation() {
    let call = FlutterMethodCall(methodName: "removeAttribute", arguments: [
      "key": 1213
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

  func testLogAddTag_WithMissingKey_FailsWithContractViolation() {
    let call = FlutterMethodCall(methodName: "addTag", arguments: [:])

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

  func testLogAddTag_WithBadKey_FailsWithContractViolation() {
    let call = FlutterMethodCall(methodName: "addTag", arguments: [
      "key": 12315
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

  func testLogRemoveTag_WithMissingTag_FailsWithContractViolation() {
    let call = FlutterMethodCall(methodName: "removeTag", arguments: [:])

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

  func testLogRemoveTag_WithBadTag_FailsWithContractViolation() {
    let call = FlutterMethodCall(methodName: "removeTag", arguments: [
      "tag": 1213
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

  func testLogRemoveTagWithKey_WithMissingKey_FailsWithContractViolation() {
    let call = FlutterMethodCall(methodName: "removeTagWithKey", arguments: [:])

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

  func testLogRemoveTagWithKey_WithBadKey_FailsWithContractViolation() {
    let call = FlutterMethodCall(methodName: "removeTagWithKey", arguments: [
      "key": 1213
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
