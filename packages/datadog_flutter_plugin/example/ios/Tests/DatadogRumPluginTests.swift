/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2022 Datadog, Inc.
 */

// swiftlint:disable file_length

import XCTest
import Flutter
import DatadogInternal
@testable import DatadogCore
@testable import DatadogRUM
import datadog_flutter_plugin

enum ResultStatus: EquatableInTests {
    case notCalled
    case called(value: Any?)
}

extension RUMAddLongTaskCommand: EquatableInTests {

}

// MARK: - Tests

// swiftlint:disable:next type_body_length
class DatadogRumPluginTests: XCTestCase {
    func testAllRumResourceTypes_AreParsedCorrectly() {
        let document = RUMResourceType.parseFromFlutter("RumResourceType.document")
        let image = RUMResourceType.parseFromFlutter("RumResourceType.image")
        let xhr = RUMResourceType.parseFromFlutter("RumResourceType.xhr")
        let beacon = RUMResourceType.parseFromFlutter("RumResourceType.beacon")
        let css = RUMResourceType.parseFromFlutter("RumResourceType.css")
        let fetch = RUMResourceType.parseFromFlutter("RumResourceType.fetch")
        let font = RUMResourceType.parseFromFlutter("RumResourceType.font")
        let jsx = RUMResourceType.parseFromFlutter("RumResourceType.js")
        let media = RUMResourceType.parseFromFlutter("RumResourceType.media")
        let other = RUMResourceType.parseFromFlutter("RumResourceType.other")
        let native = RUMResourceType.parseFromFlutter("RumResourceType.native")
        let unknown = RUMResourceType.parseFromFlutter("uknowntype")

        XCTAssertEqual(document, .document)
        XCTAssertEqual(image, .image)
        XCTAssertEqual(xhr, .xhr)
        XCTAssertEqual(beacon, .beacon)
        XCTAssertEqual(css, .css)
        XCTAssertEqual(fetch, .fetch)
        XCTAssertEqual(font, .font)
        XCTAssertEqual(jsx, .js)
        XCTAssertEqual(media, .media)
        XCTAssertEqual(other, .other)
        XCTAssertEqual(native, .native)
        XCTAssertEqual(unknown, .other)
    }

    func testAllRumHttpMethods_AreParsedCorrectly() {
        let post = RUMMethod.parseFromFlutter("RumHttpMethod.post")
        let get = RUMMethod.parseFromFlutter("RumHttpMethod.get")
        let head = RUMMethod.parseFromFlutter("RumHttpMethod.head")
        let put = RUMMethod.parseFromFlutter("RumHttpMethod.put")
        let delete = RUMMethod.parseFromFlutter("RumHttpMethod.delete")
        let patch = RUMMethod.parseFromFlutter("RumHttpMethod.patch")

        XCTAssertEqual(post, .post)
        XCTAssertEqual(get, .get)
        XCTAssertEqual(head, .head)
        XCTAssertEqual(put, .put)
        XCTAssertEqual(delete, .delete)
        XCTAssertEqual(patch, .patch)
    }

    func testAllUserActions_AreParsedCorrectly() {
        let tap = RUMActionType.parseFromFlutter("RumActionType.tap")
        let scroll = RUMActionType.parseFromFlutter("RumActionType.scroll")
        let swipe = RUMActionType.parseFromFlutter("RumActionType.swipe")
        let custom = RUMActionType.parseFromFlutter("RumActionType.custom")
        let unknown = RUMActionType.parseFromFlutter("unknowntype")

        XCTAssertEqual(tap, .tap)
        XCTAssertEqual(scroll, .scroll)
        XCTAssertEqual(swipe, .swipe)
        XCTAssertEqual(custom, .custom)
        XCTAssertEqual(unknown, .custom)
    }

    func testAllRumErrorSource_AreParsedCorrectly() {
        let source = RUMErrorSource.parseFromFlutter("RumErrorSource.source")
        let network = RUMErrorSource.parseFromFlutter("RumErrorSource.network")
        let webview = RUMErrorSource.parseFromFlutter("RumErrorSource.webview")
        let console = RUMErrorSource.parseFromFlutter("RumErrorSource.console")
        let custom = RUMErrorSource.parseFromFlutter("RumErrorSource.custom")
        let unknown = RUMErrorSource.parseFromFlutter("unknown")

        XCTAssertEqual(source, .source)
        XCTAssertEqual(network, .network)
        XCTAssertEqual(webview, .webview)
        XCTAssertEqual(console, .console)
        XCTAssertEqual(custom, .custom)
        XCTAssertEqual(unknown, .custom)
    }

    var mock: MockRUMMonitor!
    var plugin: DatadogRumPlugin!

    override func setUp() {
        mock = MockRUMMonitor()
        plugin = DatadogRumPlugin.instance
        plugin.inject(rum: mock)
    }

    let contracts = [
        Contract(methodName: "startView", requiredParameters: [
            "key": .string, "name": .string, "attributes": .map
        ]),
        Contract(methodName: "stopView", requiredParameters: [
            "key": .string, "attributes": .map
        ]),
        Contract(methodName: "addTiming", requiredParameters: [
            "name": .string
        ]),
        Contract(methodName: "addViewLoadingTime", requiredParameters: [
            "overwrite": .bool
        ]),
        Contract(methodName: "startResource", requiredParameters: [
            "key": .string, "url": .string, "httpMethod": .string, "attributes": .map
        ]),
        Contract(methodName: "stopResource", requiredParameters: [
            "key": .string, "kind": .string, "attributes": .map
        ]),
        Contract(methodName: "stopResourceWithError", requiredParameters: [
            "key": .string, "message": .string, "type": .string, "attributes": .map
        ]),
        Contract(methodName: "addError", requiredParameters: [
            "message": .string, "source": .string, "attributes": .map
        ]),
        Contract(methodName: "addAction", requiredParameters: [
            "type": .string, "name": .string, "attributes": .map
        ]),
        Contract(methodName: "startAction", requiredParameters: [
            "type": .string, "name": .string, "attributes": .map
        ]),
        Contract(methodName: "stopAction", requiredParameters: [
            "type": .string, "name": .string, "attributes": .map
        ]),
        Contract(methodName: "addAttribute", requiredParameters: [
            "key": .string, "value": .string
        ]),
        Contract(methodName: "removeAttribute", requiredParameters: [
            "key": .string
        ]),
        Contract(methodName: "reportLongTask", requiredParameters: [
            "at": .int64,
            "duration": .int
        ]),
        Contract(methodName: "updatePerformanceMetrics", requiredParameters: [
            "buildTimes": .list,
            "rasterTimes": .list
        ]),
        Contract(methodName: "addFeatureFlagEvaluation", requiredParameters: [
            "name": .string,
            "value": .string
        ]),
        Contract(methodName: "stopSession", requiredParameters: [:])
    ]

    func testRumPlugin_ContractViolationsThrowErrors() {
        testContracts(contracts: contracts, plugin: plugin)
    }

    func testRumConfiguration_WithAppHangThreshold_IsSetCorrectly() {
        let appHangThreshold = Double.mockRandom()
        let encoded: [String: Any?] = [
            "applicationId": "fake-application-id",
            "appHangThreshold": appHangThreshold
        ]

        let config = RUM.Configuration.init(fromEncoded: encoded)
        XCTAssertEqual(config?.appHangThreshold, appHangThreshold)
    }

    func testRepeatEnable_FromMethodChannelSameOptions_DoesNothing() {
        // Uninitialize plugin
        plugin?.inject(rum: nil)

        let configuration: [String: Any?] = [
            "applicationId": "fake-application-id"
        ]

        let methodCallA = FlutterMethodCall(
            methodName: "enable",
            arguments: [
                "configuration": configuration
            ] as [String: Any]
        )
        plugin.handle(methodCallA) { _ in }

        let printMock = PrintFunctionMock()
        consolePrint = printMock.print

        let methodCallB = FlutterMethodCall(
            methodName: "initialize",
            arguments: [
                "configuration": configuration
            ] as [String: Any]
        )
        plugin.handle(methodCallB) { _ in }

        XCTAssertTrue(printMock.printedMessages.isEmpty)
    }

    func testRepeatEnable_FromMethodChannelDifferentOptions_PrintsError() {
        // Uninitialize plugin
        plugin?.inject(rum: nil)

        let methodCallA = FlutterMethodCall(
            methodName: "enable",
            arguments: [
                "configuration": [
                    "applicationId": "fake-application-id"
                ] as [String: Any?]
            ] as [String: Any]
        )
        plugin.handle(methodCallA) { _ in }

        let printMock = PrintFunctionMock()
        consolePrint = printMock.print

        let methodCallB = FlutterMethodCall(
            methodName: "enable",
            arguments: [
                "configuration": [
                    "applicationId": "fake-application-id",
                    "customEndpoint": "http://localhost"
                ] as [String: Any?]
            ] as [String: Any]
        )
        plugin.handle(methodCallB) { _ in }

        XCTAssertFalse(printMock.printedMessages.isEmpty)
        XCTAssertTrue(printMock.printedMessages.first?.contains("🔥") == true)
    }

    func testStartViewCall_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "startView", arguments: [
            "key": "view_key",
            "name": "view_name",
            "attributes": ["my_attribute": "my_value"]
        ] as [String: Any])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .startView(key: "view_key", name: "view_name", attributes: ["my_attribute": "my_value"])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStopViewCall_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "stopView", arguments: [
            "key": "view_key",
            "attributes": ["my_attribute": "my_value"]
        ] as [String: Any])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(mock.callLog, [.stopView(key: "view_key", attributes: ["my_attribute": "my_value"])])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testAddTimingCall_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "addTiming", arguments: [
            "name": "timing name"
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(mock.callLog, [ .addTiming(name: "timing name") ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testAddViewLoadingTime_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "addViewLoadingTime", arguments: [
            "overwrite": true
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(mock.callLog, [ .addViewLoadingTime(overwrite: true) ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStartResource_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "startResource", arguments: [
            "key": "resource_key",
            "httpMethod": "RumHttpMethod.get",
            "url": "https://fakeresource.com/url",
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ] as [String: Any?])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .startResource(key: "resource_key",
                           httpMethod: .get,
                           urlString: "https://fakeresource.com/url",
                           attributes: ["attribute_key": "attribute_value"])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStopResource_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "stopResource", arguments: [
            "key": "resource_key",
            "statusCode": 200,
            "kind": "RumResourceType.image",
            "size": nil,
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ] as [String: Any?])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .stopResource(key: "resource_key", statusCode: 200, kind: .image, size: nil, attributes: [
                "attribute_key": "attribute_value"
            ])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStopResource_WithSize_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "stopResource", arguments: [
            "key": "resource_key",
            "statusCode": 200,
            "kind": "RumResourceType.image",
            "size": 12_408_812,
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ] as [String: Any?])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .stopResource(key: "resource_key", statusCode: 200, kind: .image,
                          size: 12_408_812, attributes: [
                            "attribute_key": "attribute_value"
                          ])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStopResourceWithError_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "stopResourceWithError", arguments: [
            "key": "resource_key",
            "message": "error message",
            "type": "error kind",
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .stopResourceWithErrorMessage(key: "resource_key",
                                          message: "error message",
                                          type: "error kind",
                                          response: nil,
                                          attributes: [
                                            "attribute_key": "attribute_value"
                                          ])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testAddError_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "addError", arguments: [
            "message": "Error message",
            "source": "RumErrorSource.network",
            "stackTrace": nil,
            "errorType": "MyErrorType",
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ] as [String: Any?])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .addError(message: "Error message", type: "MyErrorType", source: RUMErrorSource.network,
                      stack: nil, attributes: ["attribute_key": "attribute_value"], file: nil, line: nil)
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testAddAction_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "addAction", arguments: [
            "type": "RumActionType.tap",
            "name": "Action Name",
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ] as [String: Any?])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .addAction(type: .tap, name: "Action Name", attributes: [
                "attribute_key": "attribute_value"
            ])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStartAction_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "startAction", arguments: [
            "type": "RumActionType.scroll",
            "name": "Action Name",
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ] as [String: Any?])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .startAction(type: .scroll, name: "Action Name", attributes: [
                "attribute_key": "attribute_value"
            ])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStopAction_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "stopAction", arguments: [
            "type": "RumActionType.swipe",
            "name": "Action Name",
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ] as [String: Any?])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .stopAction(type: .swipe, name: "Action Name", attributes: [
                "attribute_key": "attribute_value"
            ])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testAddAttribute_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "addAttribute", arguments: [
            "key": "My key",
            "value": "My value"
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .addAttribute(forKey: "My key", value: "My value")
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testRemoveAttribute_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "removeAttribute", arguments: [
            "key": "remove_key"
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .removeAttribute(forKey: "remove_key")
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testReportLongTask_CallsInternal() {
        let startTime = Date.now
        let startTimeInterval = startTime.timeIntervalSince1970
        let duration = 340124

        let call = FlutterMethodCall(methodName: "reportLongTask", arguments: [
            "at": startTimeInterval * 1000.0,
            "duration": duration
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        let command = mock.commands.first as? RUMAddLongTaskCommand
        XCTAssertNotNil(command)
        XCTAssertEqual(command, RUMAddLongTaskCommand(time: Date(timeIntervalSince1970: startTimeInterval),
                                                      attributes: [:],
                                                      duration: TimeInterval(Double(duration) / 1000.0))
        )
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testUpdatePerformanceMetrics_CallsInternal() {
        let buildTimes = [ 0.44, 1.23, 6.5 ]
        let rasterTimes = [ 11.2, 68.1, 0.223 ]

        let call = FlutterMethodCall(methodName: "updatePerformanceMetrics", arguments: [
            "buildTimes": buildTimes,
            "rasterTimes": rasterTimes
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        let commands = mock.commands
        XCTAssertEqual(commands.count, 6)
        if commands.count == 6 {
            XCTAssertEqual((commands[0] as! RUMUpdatePerformanceMetric).metric, .flutterBuildTime)
            XCTAssertEqual((commands[0] as! RUMUpdatePerformanceMetric).value, 0.44)
            XCTAssertEqual((commands[1] as! RUMUpdatePerformanceMetric).metric, .flutterBuildTime)
            XCTAssertEqual((commands[1] as! RUMUpdatePerformanceMetric).value, 1.23)
            XCTAssertEqual((commands[2] as! RUMUpdatePerformanceMetric).metric, .flutterBuildTime)
            XCTAssertEqual((commands[2] as! RUMUpdatePerformanceMetric).value, 6.5)

            XCTAssertEqual((commands[3] as! RUMUpdatePerformanceMetric).metric, .flutterRasterTime)
            XCTAssertEqual((commands[3] as! RUMUpdatePerformanceMetric).value, 11.2)
            XCTAssertEqual((commands[4] as! RUMUpdatePerformanceMetric).metric, .flutterRasterTime)
            XCTAssertEqual((commands[4] as! RUMUpdatePerformanceMetric).value, 68.1)
            XCTAssertEqual((commands[5] as! RUMUpdatePerformanceMetric).metric, .flutterRasterTime)
            XCTAssertEqual((commands[5] as! RUMUpdatePerformanceMetric).value, 0.223)
        }
        XCTAssertEqual(resultStatus, .called(value: nil))
    }
}

// MARK: - MockRUMMonitor

class MockRUMMonitor: RUMMonitorProtocol, RUMCommandSubscriber {
    var debug: Bool

    enum MethodCall: EquatableInTests {
        case currentSessionID
        case startView(key: String, name: String?, attributes: [AttributeKey: AttributeValue])
        case stopView(key: String, attributes: [AttributeKey: AttributeValue])
        case addTiming(name: String)
        case addViewLoadingTime(overwrite: Bool)

        case startResource(key: String, httpMethod: RUMMethod, urlString: String,
                           attributes: [AttributeKey: AttributeValue])
        case stopResource(key: String, statusCode: Int?, kind: RUMResourceType, size: Int64?,
                          attributes: [AttributeKey: AttributeValue])
        case stopResourceWithError(key: String, error: Error, response: URLResponse?,
                                   attributes: [AttributeKey: AttributeValue])
        case stopResourceWithErrorMessage(key: String, message: String, type: String?,
                                   response: URLResponse?, attributes: [AttributeKey: AttributeValue])
        case addError(message: String, type: String?, source: RUMErrorSource, stack: String?,
                      attributes: [AttributeKey: AttributeValue], file: StaticString?, line: UInt?)
        case addAction(type: RUMActionType, name: String, attributes: [AttributeKey: AttributeValue])
        case startAction(type: RUMActionType, name: String, attributes: [AttributeKey: AttributeValue])
        case stopAction(type: RUMActionType, name: String?, attributes: [AttributeKey: AttributeValue])
        case addAttribute(forKey: AttributeKey, value: AttributeValue)
        case removeAttribute(forKey: AttributeKey)
    }

    var callLog: [MethodCall] = []
    var commands: [RUMCommand] = []

    init() {
        debug = true
    }

    func currentSessionID(completion: @escaping (String?) -> Void) {
        callLog.append(.currentSessionID)
        completion(nil)
    }

    func startView(key: String, name: String?, attributes: [AttributeKey: AttributeValue]) {
        callLog.append(.startView(key: key, name: name, attributes: attributes))
    }

    func stopView(key: String, attributes: [AttributeKey: AttributeValue]) {
        callLog.append(.stopView(key: key, attributes: attributes))
    }

    func addTiming(name: String) {
        callLog.append(.addTiming(name: name))
    }

    func startResource(resourceKey: String, httpMethod: RUMMethod,
                       urlString: String, attributes: [AttributeKey: AttributeValue]) {
        callLog.append(
            .startResource(key: resourceKey, httpMethod: httpMethod, urlString: urlString,
                           attributes: attributes)
        )
    }

    func stopResource(resourceKey: String, statusCode: Int?, kind: RUMResourceType,
                      size: Int64?, attributes: [AttributeKey: AttributeValue]) {
        callLog.append(
            .stopResource(key: resourceKey, statusCode: statusCode, kind: kind, size: size,
                          attributes: attributes)
        )
    }

    func stopResourceWithError(
        resourceKey: String,
        error: Error,
        response: URLResponse?,
        attributes: [AttributeKey: AttributeValue]
    ) {
        callLog.append(.stopResourceWithError(key: resourceKey, error: error,
                                              response: response, attributes: attributes))
    }

    func stopResourceWithError(resourceKey: String,
                               message: String,
                               type: String?,
                               response: URLResponse?,
                               attributes: [AttributeKey: AttributeValue]) {
        callLog.append(
            .stopResourceWithErrorMessage(key: resourceKey, message: message, type: type,
                                          response: response, attributes: attributes)
        )
    }

    // swiftlint:ignore function_parameter_count
    func addError(message: String, type: String?, stack: String?, source: RUMErrorSource,
                  attributes: [AttributeKey: AttributeValue], file: StaticString?, line: UInt?) {
        callLog.append(
            .addError(message: message, type: type, source: source, stack: stack,
                      attributes: attributes, file: file, line: line)
        )
    }

    func addViewLoadingTime(overwrite: Bool) {
        callLog.append(.addViewLoadingTime(overwrite: overwrite))
    }

    func addAttribute(forKey key: AttributeKey, value: AttributeValue) {
        callLog.append(.addAttribute(forKey: key, value: value))
    }

    func removeAttribute(forKey key: AttributeKey) {
        callLog.append(.removeAttribute(forKey: key))
    }

    func addAction(type: RUMActionType, name: String,
                   attributes: [AttributeKey: AttributeValue]) {
        callLog.append(.addAction(type: type, name: name, attributes: attributes))
    }

    func startAction(type: RUMActionType, name: String,
                     attributes: [AttributeKey: AttributeValue]) {
        callLog.append(.startAction(type: type, name: name, attributes: attributes))
    }

    func stopAction(type: RUMActionType, name: String?, attributes: [AttributeKey: AttributeValue]) {
        callLog.append(.stopAction(type: type, name: name, attributes: attributes))
    }

    func stopSession() {

    }

    func addFeatureFlagEvaluation(name: String, value: Encodable) {

    }

    /// Processes the given RUM Command.
    ///
    /// - Parameter command: The RUM command to process.
    func process(command: RUMCommand) {
        commands.append(command)
    }
}
