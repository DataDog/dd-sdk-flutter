// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import Datadog
import DictionaryCoder

extension FlutterError {
    public enum DdErrorCodes {
        static let contractViolation = "DatadogSdk:ContractViolation"
        static let invalidOperation = "DatadogSdk:InvalidOperation"
    }

    static func missingParameter(methodName: String) -> FlutterError {
        return FlutterError(code: DdErrorCodes.contractViolation,
                            message: "Missing parameter in call to \(methodName)",
                            details: nil)
    }

    static func invalidOperation(message: String) -> FlutterError {
        return FlutterError(code: DdErrorCodes.invalidOperation,
                            message: message,
                            details: nil)
    }
}

public class DatadogRumPlugin: NSObject, FlutterPlugin {
    private static var methodChannel: FlutterMethodChannel?

    public static let instance =  DatadogRumPlugin()
    public static func register(with registrar: FlutterPluginRegistrar) {
        methodChannel = FlutterMethodChannel(name: "datadog_sdk_flutter.rum", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel!)
    }

    private var rumInstance: DDRUMMonitor?
    public var isInitialized: Bool { return rumInstance != nil }

    private override init() {
        super.init()
    }

    func initialize(configuration: DatadogFlutterConfiguration.RumConfiguration) {
        rumInstance = RUMMonitor.initialize()
        Global.rum = rumInstance!
    }

    func attachToExisting(rumInstance: DDRUMMonitor) {
        self.rumInstance = rumInstance
    }

    public func initialize(withRum rum: DDRUMMonitor) {
        rumInstance = rum
    }

    public func onDetach() {

    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any] else {
            result(
                FlutterError.invalidOperation(message: "No arguments in call to \(call.method).")
            )
            return
        }
        guard let rum = rumInstance else {
            result(
                FlutterError.invalidOperation(message: "RUM has not been initialized when calling \(call.method).")
            )
            return
        }

        switch call.method {
        case "startView":
            if let key = arguments["key"] as? String,
               let name = arguments["name"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                rum.startView(key: key, name: name, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }

        case "stopView":
            if let key = arguments["key"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                rum.stopView(key: key, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "addTiming":
            if let name = arguments["name"] as? String {
                rum.addTiming(name: name)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "startResourceLoading":
            if let key = arguments["key"] as? String,
               let methodString = arguments["httpMethod"] as? String,
               let url = arguments["url"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                let method = RUMMethod.parseFromFlutter(methodString)
                rum.startResourceLoading(resourceKey: key, httpMethod: method, urlString: url,
                                         attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "stopResourceLoading":
            if let key = arguments["key"] as? String,
               let kindString = arguments["kind"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                let kind = RUMResourceType.parseFromFlutter(kindString)

                let statusCode = arguments["statusCode"] as? NSNumber
                let size = arguments["size"] as? NSNumber

                rum.stopResourceLoading(resourceKey: key, statusCode: statusCode?.intValue,
                                        kind: kind, size: size?.int64Value, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }

        case "stopResourceLoadingWithError":
            if let key = arguments["key"] as? String,
               let message = arguments["message"] as? String,
               let errorType = arguments["type"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                rum.stopResourceLoadingWithError(resourceKey: key, errorMessage: message, type: errorType,
                                                 response: nil, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "addError":
            if let message = arguments["message"] as? String,
               let sourceString = arguments["source"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                let source = RUMErrorSource.parseFromFlutter(sourceString)
                let stackTrace = arguments["stackTrace"] as? String

                rum.addError(message: message, source: source, stack: stackTrace, attributes: encodedAttributes,
                             file: nil, line: nil)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "addUserAction":
            if let typeString = arguments["type"] as? String,
               let name = arguments["name"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let type = RUMUserActionType.parseFromFlutter(typeString)
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                rum.addUserAction(type: type, name: name, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "startUserAction":
            if let typeString = arguments["type"] as? String,
               let name = arguments["name"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let type = RUMUserActionType.parseFromFlutter(typeString)
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                rum.startUserAction(type: type, name: name, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "stopUserAction":
            if let typeString = arguments["type"] as? String,
               let name = arguments["name"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let type = RUMUserActionType.parseFromFlutter(typeString)
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                rum.stopUserAction(type: type, name: name, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "addAttribute":
            if let key = arguments["key"] as? String,
               let value = arguments["value"] {
                let encodedValue = castAnyToEncodable(value)
                rum.addAttribute(forKey: key, value: encodedValue)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "removeAttribute":
            if let key = arguments["key"] as? String {
                rum.removeAttribute(forKey: key)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "reportLongTask":
            if let atTime = arguments["at"] as? NSNumber,
               let duration = arguments["duration"] as? NSNumber {
                let atDate = Date(timeIntervalSince1970: TimeInterval(atTime.doubleValue / 1000.0))
                rum._internal.addLongTask(at: atDate, duration: TimeInterval(duration.doubleValue / 1000.0))
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "updatePerformanceMetrics":
            if let buildTimes = arguments["buildTimes"] as? [Double],
               let rasterTimes = arguments["rasterTimes"] as? [Double] {
                // TODO: Time isn't that important here, but in the future we should get it either
                // from Flutter or from the timeProvider anyway
                let date = Date()
                buildTimes.forEach { val in
                    rum._internal.updatePerformanceMetric(at: date, metric: .flutterBuildTime, value: val)
                }
                rasterTimes.forEach { val in
                    rum._internal.updatePerformanceMetric(at: date, metric: .flutterRasterTime, value: val)
                }
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func callEventMapper<T>(mapperName: String, event: T, encodedEvent: [String: Any?], completion: ([String: Any?]?) -> T?) -> T?{
        guard let methodChannel = DatadogRumPlugin.methodChannel else {
            return event
        }

        var encodedResult: [String: Any?]? = encodedEvent
        let semaphore = DispatchSemaphore(value: 0)

        methodChannel.invokeMethod(mapperName, arguments: ["event": encodedEvent]) { result in
            if result == nil {
                encodedResult = nil
            } else if let result = result as? [String: Any] {
                encodedResult = result
            }

            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + DispatchTimeInterval.milliseconds(250)) == .timedOut {
            return event
        }

        if encodedResult?["_dd.mapper_error"] != nil {
            // Error in the mapper, return the unmapped event
            return event
        }

        return completion(encodedResult);
    }

    func extractUserExtraInfo(usrMember: [String: Any]?) -> [String: Any]? {
        // Move user attributes into 'usr_info' member
        if var usrMember = usrMember {
            let reservedKeys = ["email", "id", "name"]
            var userExtraInfo: [String: Any?] = [:]
            usrMember.filter { !reservedKeys.contains($0.key) }.forEach {
                userExtraInfo[$0] = $1
                usrMember.removeValue(forKey: $0)
            }

            usrMember["usr_info"] = userExtraInfo
        }

        return usrMember
    }

    func viewEventMapper(rumViewEvent: RUMViewEvent) -> RUMViewEvent {
        let encoder = DictionaryEncoder()
        guard var encoded = try? encoder.encode(rumViewEvent) else {
            Datadog._internal.telemetry.error(
                id: "datadog_flutter:view_mapping_encoding",
                message: "Encoding a RUMViewEvent failed",
                kind: "EncodingError",
                stack: nil
            )
            return rumViewEvent
        }

        encoded["usr"] = extractUserExtraInfo(usrMember: encoded["usr"] as? [String: Any])

        let result = callEventMapper(mapperName: "mapViewEvent", event: rumViewEvent, encodedEvent: encoded) { encodedResult in
            guard let encodedResult = encodedResult else {
                return rumViewEvent
            }

            // Pull modifyable properties
            var rumViewEvent = rumViewEvent
            if let encodedView = encodedResult["view"] as? [String: Any?] {
                rumViewEvent.view.name = encodedView["name"] as? String
                rumViewEvent.view.referrer = encodedView["referrer"] as? String
                rumViewEvent.view.url = encodedView["url"] as! String
            }

            return rumViewEvent
        }

        guard let result = result else {
            Datadog._internal.telemetry.error(
                id: "datadog_flutter:null",
                message: "A Flutter viewEventMapper somehow returned null",
                kind: nil,
                stack: nil
            )
            return rumViewEvent
        }
        
        return result
    }

    func actionEventMapper(rumActionEvent: RUMActionEvent) -> RUMActionEvent? {
        let encoder = DictionaryEncoder()
        guard var encoded = try? encoder.encode(rumActionEvent) else {
            Datadog._internal.telemetry.error(
                id: "datadog_flutter:action_mapping_encoding",
                message: "Encoding a RUMActionEvent failed",
                kind: "EncodingError",
                stack: nil
            )
            return rumActionEvent
        }

        encoded["usr"] = extractUserExtraInfo(usrMember: encoded["usr"] as? [String: Any])

        return callEventMapper(mapperName: "mapActionEvent", event: rumActionEvent, encodedEvent: encoded) { encodedResult in
            guard let encodedResult = encodedResult else {
                return nil
            }

            var rumActionEvent = rumActionEvent
            if let encodedAction = encodedResult["action"] as? [String: Any?] {
                if let encodedTarget = encodedAction["target"] as? [String: Any?] {
                    rumActionEvent.action.target?.name = encodedTarget["name"] as! String
                } else {
                    rumActionEvent.action.target = nil
                }
            }

            if let encodedView = encodedResult["view"] as? [String: Any?] {
                rumActionEvent.view.name = encodedView["name"] as? String
                rumActionEvent.view.referrer = encodedView["referrer"] as? String
                rumActionEvent.view.url = encodedView["url"] as! String
            }
            return rumActionEvent
        }
    }
}

public extension RUMResourceType {
    // swiftlint:disable:next cyclomatic_complexity
    static func parseFromFlutter(_ value: String) -> RUMResourceType {
        switch value {
        case "RumResourceType.document": return .document
        case "RumResourceType.image": return .image
        case "RumResourceType.xhr": return .xhr
        case "RumResourceType.beacon": return .beacon
        case "RumResourceType.css": return .css
        case "RumResourceType.fetch": return .fetch
        case "RumResourceType.font": return .font
        case "RumResourceType.js": return .js
        case "RumResourceType.media": return .media
        case "RumResourceType.native": return .native
        default: return .other
        }
    }
}

public extension RUMMethod {
    static func parseFromFlutter(_ value: String) -> RUMMethod {
        switch value {
        case "RumHttpMethod.get": return .get
        case "RumHttpMethod.post": return .post
        case "RumHttpMethod.head": return .head
        case "RumHttpMethod.put": return .put
        case "RumHttpMethod.delete": return .delete
        case "RumHttpMethod.patch": return .patch
        default: return .get
        }
    }
}

public extension RUMUserActionType {
    static func parseFromFlutter(_ value: String) -> RUMUserActionType {
        switch value {
        case "RumUserActionType.tap": return .tap
        case "RumUserActionType.scroll": return .scroll
        case "RumUserActionType.swipe": return .swipe
        default: return .custom
        }
    }
}

public extension RUMErrorSource {
    static func parseFromFlutter(_ value: String) -> RUMErrorSource {
        switch value {
        case "RumErrorSource.source": return .source
        case "RumErrorSource.network": return .network
        case "RumErrorSource.webview": return .webview
        case "RumErrorSource.console": return .console
        case "RumErrorSource.custom": return .custom
        default: return .custom
        }
    }
}

public extension Datadog.Configuration.VitalsFrequency {
    static func parseFromFlutter(_ value: String) -> Datadog.Configuration.VitalsFrequency {
        switch value {
        case "VitalsFrequency.frequent": return .frequent
        case "VitalsFrequency.average": return .average
        case "VitalsFrequency.rare": return .rare
        case "VitalsFrequency.never": return .never
        default: return .average
        }
    }
}
