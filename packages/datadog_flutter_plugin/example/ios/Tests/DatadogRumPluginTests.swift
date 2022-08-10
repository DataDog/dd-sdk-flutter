/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-2022 Datadog, Inc.
 */

// swiftlint:disable file_length

import XCTest
@testable import Datadog
import datadog_flutter_plugin

enum ResultStatus: EquatableInTests {
    case notCalled
    case called(value: Any?)
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
        let tap = RUMUserActionType.parseFromFlutter("RumUserActionType.tap")
        let scroll = RUMUserActionType.parseFromFlutter("RumUserActionType.scroll")
        let swipe = RUMUserActionType.parseFromFlutter("RumUserActionType.swipe")
        let custom = RUMUserActionType.parseFromFlutter("RumUserActionType.custom")
        let unknown = RUMUserActionType.parseFromFlutter("unknowntype")

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
        plugin.initialize(withRum: mock)
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
        Contract(methodName: "startResourceLoading", requiredParameters: [
            "key": .string, "url": .string, "httpMethod": .string, "attributes": .map
        ]),
        Contract(methodName: "stopResourceLoading", requiredParameters: [
            "key": .string, "kind": .string, "attributes": .map
        ]),
        Contract(methodName: "stopResourceLoadingWithError", requiredParameters: [
            "key": .string, "message": .string, "type": .string, "attributes": .map
        ]),
        Contract(methodName: "addError", requiredParameters: [
            "message": .string, "source": .string, "attributes": .map
        ]),
        Contract(methodName: "addUserAction", requiredParameters: [
            "type": .string, "name": .string, "attributes": .map
        ]),
        Contract(methodName: "startUserAction", requiredParameters: [
            "type": .string, "name": .string, "attributes": .map
        ]),
        Contract(methodName: "stopUserAction", requiredParameters: [
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
        ])
    ]

    func testRumPlugin_ContractViolationsThrowErrors() {
        testContracts(contracts: contracts, plugin: plugin)
    }

    func testStartViewCall_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "startView", arguments: [
            "key": "view_key",
            "name": "view_name",
            "attributes": ["my_attribute": "my_value"]
        ])

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
        ])

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

    func testStartResourceLoading_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "startResourceLoading", arguments: [
            "key": "resource_key",
            "httpMethod": "RumHttpMethod.get",
            "url": "https://fakeresource.com/url",
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .startResourceLoading(key: "resource_key",
                                  httpMethod: .get,
                                  urlString: "https://fakeresource.com/url",
                                  attributes: ["attribute_key": "attribute_value"])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStopResourceLoading_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "stopResourceLoading", arguments: [
            "key": "resource_key",
            "statusCode": 200,
            "kind": "RumResourceType.image",
            "size": nil,
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .stopResourceLoading(key: "resource_key", statusCode: 200, kind: .image, size: nil, attributes: [
                "attribute_key": "attribute_value"
            ])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStopResourceLoading_WithSize_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "stopResourceLoading", arguments: [
            "key": "resource_key",
            "statusCode": 200,
            "kind": "RumResourceType.image",
            "size": 12_408_812,
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = .called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .stopResourceLoading(key: "resource_key", statusCode: 200, kind: .image,
                                 size: 12_408_812, attributes: [
                                    "attribute_key": "attribute_value"
                                 ])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStopResourceLoadingWithError_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "stopResourceLoadingWithError", arguments: [
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
            .stopResourceLoadingWithErrorMessage(key: "resource_key",
                                                 errorMessage: "error message",
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
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .addError(message: "Error message", type: nil, source: RUMErrorSource.network, stack: nil,
                      attributes: ["attribute_key": "attribute_value"], file: nil, line: nil)
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testAddUserAction_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "addUserAction", arguments: [
            "type": "RumUserActionType.tap",
            "name": "Action Name",
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .addUserAction(type: .tap, name: "Action Name", attributes: [
                "attribute_key": "attribute_value"
            ])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStartUserAction_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "startUserAction", arguments: [
            "type": "RumUserActionType.scroll",
            "name": "Action Name",
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .startUserAction(type: .scroll, name: "Action Name", attributes: [
                "attribute_key": "attribute_value"
            ])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }

    func testStopUserAction_CallsRumMonitor() {
        let call = FlutterMethodCall(methodName: "stopUserAction", arguments: [
            "type": "RumUserActionType.swipe",
            "name": "Action Name",
            "attributes": [
                "attribute_key": "attribute_value"
            ]
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        XCTAssertEqual(mock.callLog, [
            .stopUserAction(type: .swipe, name: "Action Name", attributes: [
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
        let duration = 340124

        let call = FlutterMethodCall(methodName: "reportLongTask", arguments: [
            "at": startTime.timeIntervalSince1970 * 1000.0,
            "duration": duration
        ])

        var resultStatus = ResultStatus.notCalled
        plugin.handle(call) { result in
            resultStatus = ResultStatus.called(value: result)
        }

        let mockInternal = mock._internal as! MockRumInternalProxy
        XCTAssertEqual(mockInternal.callLog, [
            .addLongTask(at: startTime, duration: TimeInterval(Double(duration) / 1000.0), attributes: [:])
        ])
        XCTAssertEqual(resultStatus, .called(value: nil))
    }
}

// MARK: - MockRUMMonitor

class MockRUMMonitor: DDRUMMonitor {
    enum MethodCall: EquatableInTests {
        case startView(key: String, name: String?, attributes: [AttributeKey: AttributeValue])
        case stopView(key: String, attributes: [AttributeKey: AttributeValue])
        case addTiming(name: String)

        case startResourceLoading(key: String, httpMethod: RUMMethod, urlString: String,
                                  attributes: [AttributeKey: AttributeValue])
        case stopResourceLoading(key: String, statusCode: Int?, kind: RUMResourceType, size: Int64?,
                                 attributes: [AttributeKey: AttributeValue])
        case stopResourceLoadingWithError(key: String, error: Error, response: URLResponse?,
                                          attributes: [AttributeKey: AttributeValue])
        case stopResourceLoadingWithErrorMessage(key: String, errorMessage: String, type: String?,
                                                 response: URLResponse?, attributes: [AttributeKey: AttributeValue])
        case addError(message: String, type: String?, source: RUMErrorSource, stack: String?,
                      attributes: [AttributeKey: AttributeValue], file: StaticString?, line: UInt?)
        case addUserAction(type: RUMUserActionType, name: String, attributes: [AttributeKey: AttributeValue])
        case startUserAction(type: RUMUserActionType, name: String, attributes: [AttributeKey: AttributeValue])
        case stopUserAction(type: RUMUserActionType, name: String?, attributes: [AttributeKey: AttributeValue])
        case addAttribute(forKey: AttributeKey, value: AttributeValue)
        case removeAttribute(forKey: AttributeKey)

    }

    var callLog: [MethodCall] = []

    override init() {
        super.init()

        _internal = MockRumInternalProxy(subscriber: NOOPCommandSubscriber())
    }

    override func startView(key: String, name: String? = nil, attributes: [AttributeKey: AttributeValue] = [:]) {
        callLog.append(.startView(key: key, name: name, attributes: attributes))
    }

    override func stopView(key: String, attributes: [AttributeKey: AttributeValue] = [:]) {
        callLog.append(.stopView(key: key, attributes: attributes))
    }

    override func addTiming(name: String) {
        callLog.append(.addTiming(name: name))
    }

    override func startResourceLoading(resourceKey: String, httpMethod: RUMMethod,
                                       urlString: String, attributes: [AttributeKey: AttributeValue] = [:]) {
        callLog.append(
            .startResourceLoading(key: resourceKey, httpMethod: httpMethod, urlString: urlString,
                                  attributes: attributes)
        )
    }

    override func stopResourceLoading(resourceKey: String, statusCode: Int?, kind: RUMResourceType,
                                      size: Int64? = nil, attributes: [AttributeKey: AttributeValue] = [:]) {
        callLog.append(
            .stopResourceLoading(key: resourceKey, statusCode: statusCode, kind: kind, size: size,
                                 attributes: attributes)
        )
    }

    override public func stopResourceLoadingWithError(
        resourceKey: String,
        error: Error,
        response: URLResponse? = nil,
        attributes: [AttributeKey: AttributeValue] = [:]
    ) {
        callLog.append(.stopResourceLoadingWithError(key: resourceKey, error: error,
                                                     response: response, attributes: attributes))
    }

    override func stopResourceLoadingWithError(resourceKey: String,
                                               errorMessage: String,
                                               type: String? = nil,
                                               response: URLResponse? = nil,
                                               attributes: [AttributeKey: AttributeValue] = [:]) {
        callLog.append(
            .stopResourceLoadingWithErrorMessage(key: resourceKey, errorMessage: errorMessage, type: type,
                                                 response: response, attributes: attributes)
        )
    }

    override func addError(message: String, type: String? = nil, source: RUMErrorSource = .custom, stack: String? = nil,
                           attributes: [AttributeKey: AttributeValue] = [:],
                           file: StaticString? = #file, line: UInt? = #line) {
        callLog.append(
            .addError(message: message, type: type, source: source, stack: stack,
                      attributes: attributes, file: file, line: line)
        )
    }

    override func addAttribute(forKey key: AttributeKey, value: AttributeValue) {
        callLog.append(.addAttribute(forKey: key, value: value))
    }

    override func removeAttribute(forKey key: AttributeKey) {
        callLog.append(.removeAttribute(forKey: key))
    }

    override func addUserAction(type: RUMUserActionType, name: String,
                                attributes: [AttributeKey: AttributeValue] = [:]) {
        callLog.append(.addUserAction(type: type, name: name, attributes: attributes))
    }

    override func startUserAction(type: RUMUserActionType, name: String,
                                  attributes: [AttributeKey: AttributeValue] = [:]) {
        callLog.append(.startUserAction(type: type, name: name, attributes: attributes))
    }

    override func stopUserAction(type: RUMUserActionType, name: String? = nil,
                                 attributes: [AttributeKey: AttributeValue] = [:]) {
        callLog.append(.stopUserAction(type: type, name: name, attributes: attributes))
    }
}

class NOOPCommandSubscriber: RUMCommandSubscriber {
    func process(command: RUMCommand) {
        // NOOP
    }
}

class MockRumInternalProxy: _RUMInternalProxy {
    enum MethodCall: EquatableInTests {
        // swiftlint:disable:next identifier_name
        case addLongTask(at: Date, duration: TimeInterval, attributes: [AttributeKey: AttributeValue])
    }

    var callLog: [MethodCall] = []

    // swiftlint:disable:next identifier_name
    override func addLongTask(at: Date, duration: TimeInterval, attributes: [AttributeKey: AttributeValue]) {
        callLog.append(.addLongTask(at: at, duration: duration, attributes: attributes))
    }
}
