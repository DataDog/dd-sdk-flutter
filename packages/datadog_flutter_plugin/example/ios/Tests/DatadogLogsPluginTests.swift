// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import XCTest
@testable import Datadog
@testable import datadog_flutter_plugin

class MockV2Logger: LoggerProtocol {
    enum Method: EquatableInTests {
        case log(level: LogLevel, message: String, error: Error?, attributes: [String: Encodable]?)
        case logError(
            level: LogLevel,
            message: String,
            errorKind: String?,
            errorMessage: String?,
            stackTrace: String?,
            attributes: [String: Encodable]?
        )
        case addAttribute(key: AttributeKey, value: AttributeValue)
        case removeAttribute(key: AttributeKey)
        case addTag(key: String, value: String)
        case removeTag(key: String)
        case add(tag: String)
        case remove(tag: String)
    }

    var calls: [Method] = []

    func log(level: LogLevel, message: String, error: Error?, attributes: [String: Encodable]?) {
        calls.append(.log(level: level, message: message, error: error, attributes: attributes))
    }

    // swiftlint:disable:next function_parameter_count
    func log(
        level: LogLevel,
        message: String,
        errorKind: String?,
        errorMessage: String?,
        stackTrace: String?,
        attributes: [String: Encodable]?
    ) {
        calls.append(
            .logError(
                level: level,
                message: message,
                errorKind: errorKind,
                errorMessage: errorMessage,
                stackTrace: stackTrace,
                attributes: attributes
            )
        )
    }

    func addAttribute(forKey key: AttributeKey, value: AttributeValue) {
        calls.append(.addAttribute(key: key, value: value))
    }

    func removeAttribute(forKey key: AttributeKey) {
        calls.append(.removeAttribute(key: key))
    }

    func addTag(withKey key: String, value: String) {
        calls.append(.addTag(key: key, value: value))
    }

    func removeTag(withKey key: String) {
        calls.append(.removeTag(key: key))
    }

    func add(tag: String) {
        calls.append(.add(tag: tag))
    }

    func remove(tag: String) {
        calls.append(.remove(tag: tag))
    }
}

class DatadogLogsPluginTests: XCTestCase {
    var plugin: DatadogLogsPlugin!
    var mockV2Logger: MockV2Logger?

    override func setUp() {
        plugin = DatadogLogsPlugin.instance
        mockV2Logger = MockV2Logger()
        // "fake string" is the string that the contract tests will send
        plugin.addLogger(logger: Logger(v2Logger: mockV2Logger!), withHandle: "fake string")
        // Non-contract tests get the same logger with a different it
        plugin.addLogger(logger: Logger(v2Logger: mockV2Logger!), withHandle: "fake-uuid")
    }

    let contracts = [
        Contract(methodName: "log", requiredParameters: [
            "loggerHandle": .string,
            "logLevel": .string,
            "message": .string
        ]),
        Contract(methodName: "addAttribute", requiredParameters: [
            "loggerHandle": .string,
            "key": .string, "value": .map
        ]),
        Contract(methodName: "addTag", requiredParameters: [
            "loggerHandle": .string,
            "tag": .string
        ]),
        Contract(methodName: "removeAttribute", requiredParameters: [
            "loggerHandle": .string,
            "key": .string
        ]),
        Contract(methodName: "removeTag", requiredParameters: [
            "loggerHandle": .string,
            "tag": .string
        ]),
        Contract(methodName: "removeTagWithKey", requiredParameters: [
            "loggerHandle": .string,
            "key": .string
        ])
    ]

    func defaultConfigArgs() -> [String: Any] {
        return [
            "sendNetworkInfo": true,
            "printLogsToConsole": true,
            "sendLogsToDatadog": false,
            "bundleWithRum": true,
            "loggerName": "my_logger"
        ]
    }

    func testLoggingConfiguration_DecodesCorrectly() {
        let loggingConfig = DatadogLoggingConfiguration.init(fromEncoded: defaultConfigArgs())
        XCTAssertNotNil(loggingConfig)
        XCTAssertTrue(loggingConfig!.sendNetworkInfo)
        XCTAssertTrue(loggingConfig!.printLogsToConsole)
        XCTAssertFalse(loggingConfig!.sendLogsToDatadog)
        XCTAssertTrue(loggingConfig!.bundleWithRum)
        XCTAssertEqual(loggingConfig!.loggerName, "my_logger")
    }

    func testLogs_CreateLogger_CreatesLoggerWithHandle() {
        let call = FlutterMethodCall(methodName: "createLogger", arguments: [
            "loggerHandle": "fake-uuid",
            "configuration": defaultConfigArgs()
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(resultStatus, .called(value: nil))

        let log = plugin.logger(withHandle: "fake-uuid")
        XCTAssertNotNil(log)
    }

    func testLogCalls_WithMissingParameter_FailsWithContractViolation() {
        testContracts(contracts: contracts, plugin: plugin)
    }

    func testLogCalls_WithBadParameter_FailsWithContractViolation() {
        let logLevels = ["LogLevel.debug", "LogLevel.info", "LogLevel.warn", "LogLevel.error"]

        for level in logLevels {
            let call = FlutterMethodCall(methodName: "log", arguments: [
                "loggerHandle": "fake-uuid",
                "logLevel": level,
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
                XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation)
                XCTAssertNotNil(error?.message)

            case .notCalled:
                XCTFail("result was not called")
            }
        }
    }

    func testParseLogLevel_ParsesLevelsCorrectly() {
        let debug = LogLevel.parseLogLevelFromFlutter("LogLevel.debug")
        let info = LogLevel.parseLogLevelFromFlutter("LogLevel.info")
        let notice = LogLevel.parseLogLevelFromFlutter("LogLevel.notice")
        let warning = LogLevel.parseLogLevelFromFlutter("LogLevel.warning")
        let error = LogLevel.parseLogLevelFromFlutter("LogLevel.error")
        let critical = LogLevel.parseLogLevelFromFlutter("LogLevel.critical")
        let alert = LogLevel.parseLogLevelFromFlutter("LogLevel.alert")
        let emergency = LogLevel.parseLogLevelFromFlutter("LogLevel.emergency")
        let unknown = LogLevel.parseLogLevelFromFlutter("unknown")

        XCTAssertEqual(debug, .debug)
        XCTAssertEqual(info, .info)
        XCTAssertEqual(notice, .notice)
        XCTAssertEqual(warning, .warn)
        XCTAssertEqual(error, .error)
        XCTAssertEqual(critical, .critical)
        XCTAssertEqual(alert, .critical)
        XCTAssertEqual(emergency, .critical)
        XCTAssertEqual(unknown, .info)
    }

    func testCallsToLog_CallThroughToLogger() {
        let logLevels = ["LogLevel.debug", "LogLevel.info", "LogLevel.warning", "LogLevel.error"]

        let context = [
            "test_attribute": "attribute value"
        ]

        for level in logLevels {
            let call = FlutterMethodCall(methodName: "log", arguments: [
                "loggerHandle": "fake-uuid",
                "logLevel": level,
                "message": "\(level) message",
                "errorKind": nil,
                "errorMessage": nil,
                "stackTrace": nil,
                "context": context
            ])

            var resultStatus = ResultStatus.notCalled
            plugin.handle(call) { result in
                resultStatus = .called(value: result)
            }

            let parsedLevel = LogLevel.parseLogLevelFromFlutter(level)
            XCTAssertEqual(resultStatus, .called(value: nil))
            XCTAssertEqual(mockV2Logger?.calls.count, 1)
            XCTAssertEqual(
                mockV2Logger?.calls.first,
                    .logError(
                        level: parsedLevel,
                        message: "\(level) message",
                        errorKind: nil,
                        errorMessage: nil,
                        stackTrace: nil,
                        attributes: [
                            "test_attribute": "attribute value"
                        ]
                    )
            )
            mockV2Logger?.calls.removeAll()
        }
    }

    func testCallsToLogWithErrors_CallThroughToLogger() {
        let logLevels = ["LogLevel.debug", "LogLevel.info", "LogLevel.warning", "LogLevel.error"]

        let context = [
            "test_attribute": "attribute value"
        ]

        for level in logLevels {
            let call = FlutterMethodCall(methodName: "log", arguments: [
                "loggerHandle": "fake-uuid",
                "logLevel": level,
                "message": "\(level) message",
                "errorKind": "\(level) kind",
                "errorMessage": "\(level) error message",
                "stackTrace": "# ----0 Fake stack trace (package:/flutter)",
                "context": context
            ])

            var resultStatus = ResultStatus.notCalled
            plugin.handle(call) { result in
                resultStatus = .called(value: result)
            }

            let parsedLevel = LogLevel.parseLogLevelFromFlutter(level)
            XCTAssertEqual(resultStatus, .called(value: nil))
            XCTAssertEqual(mockV2Logger?.calls.count, 1)
            XCTAssertEqual(
                mockV2Logger?.calls.first,
                    .logError(
                        level: parsedLevel,
                        message: "\(level) message",
                        errorKind: "\(level) kind",
                        errorMessage: "\(level) error message",
                        stackTrace: "# ----0 Fake stack trace (package:/flutter)",
                        attributes: [
                            "test_attribute": "attribute value"
                        ]
                    )
            )
            mockV2Logger?.calls.removeAll()
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
            XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation)
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
            XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation)
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
            XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation)
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
            XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation)
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
            XCTAssertEqual(error?.code, FlutterError.DdErrorCodes.contractViolation)
            XCTAssertNotNil(error?.message)

        case .notCalled:
            XCTFail("result was not called")
        }
    }
}
