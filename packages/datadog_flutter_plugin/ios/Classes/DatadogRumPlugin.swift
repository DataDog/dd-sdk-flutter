// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.
// swiftlint:disable file_length

import Foundation
import Flutter
import DatadogCore
@_spi(Experimental) import DatadogRUM
import DatadogInternal
import DictionaryCoder

public extension RUM.Configuration {
    init?(fromEncoded encoded: [String: Any?]) {
        guard let applicationId: String = try? castUnwrap(encoded["applicationId"]) else {
            return nil
        }

        self.init(applicationID: applicationId)

        urlSessionTracking = .init()
        sessionSampleRate = (encoded["sessionSampleRate"] as? NSNumber)?.floatValue ?? 100.0
        longTaskThreshold = (encoded["longTaskThreshold"] as? NSNumber)?.doubleValue ?? 0.1
        trackFrustrations = (encoded["trackFrustrations"] as? NSNumber)?.boolValue ?? true
        if let appHangThreshold = (encoded["appHangThreshold"] as? NSNumber)?.doubleValue {
            self.appHangThreshold = appHangThreshold
        }

        if let customEndpoint = encoded["customEndpoint"] as? String {
            self.customEndpoint = URL(string: customEndpoint)
        }

        vitalsUpdateFrequency = convertOptional(encoded["vitalsUpdateFrequency"]) {
            .parseFromFlutter($0)
        }

        telemetrySampleRate = (encoded["telemetrySampleRate"] as? NSNumber)?.floatValue ?? 20.0

        if let additionalConfig = encoded["additionalConfig"] as? [String: Any?] {
            if let sampleRateArg = (additionalConfig["_dd.telemetry.configuration_sample_rate"] as? NSNumber) {
                self._internal_mutation({
                    $0.configurationTelemetrySampleRate = sampleRateArg.floatValue
                })
            }
        }
    }
}

// swiftlint:disable:next type_body_length
public class DatadogRumPlugin: NSObject, FlutterPlugin {
    private static var methodChannel: FlutterMethodChannel?

    public static let instance =  DatadogRumPlugin()
    public static func register(with registrar: FlutterPluginRegistrar) {
        methodChannel = FlutterMethodChannel(name: "datadog_sdk_flutter.rum", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: methodChannel!)
    }

    internal var rum: RUMMonitorProtocol?
    internal var trackMapperPerf = false
    internal var mapperPerf = PerformanceTracker()
    internal var mainThreadMapperPerf = PerformanceTracker()
    internal var mapperTimeouts = 0

    private var currentConfiguration: [AnyHashable: Any]?

    private override init() {
        super.init()
    }

    // for unit testing
    public func inject(rum: RUMMonitorProtocol?) {
        self.rum = rum
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

        if call.method != "enable" && rum == nil {
            result(
                FlutterError.invalidOperation(
                    message: "Attempting to call RUM method (\(call.method)) when RUM has not been enabled."
                )
            )
            return
        }

        switch call.method {
        case "enable":
            enable(arguments: arguments, call: call)
            result(nil)

        case "deinitialize":
            deinitialize(arguments: arguments, call: call)
            result(nil)

        case "getCurrentSessionId":
            getCurrentSessionId(result: result)

        case "startView":
            if let key = arguments["key"] as? String,
               let name = arguments["name"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                rum?.startView(key: key, name: name, attributes: encodedAttributes)
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
                rum?.stopView(key: key, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "addTiming":
            if let name = arguments["name"] as? String {
                rum?.addTiming(name: name)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "addViewLoadingTime":
            if let overwrite = arguments["overwrite"] as? Bool {
                rum?.addViewLoadingTime(overwrite: overwrite)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "startResource":
            if let key = arguments["key"] as? String,
               let methodString = arguments["httpMethod"] as? String,
               let url = arguments["url"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                let method = RUMMethod.parseFromFlutter(methodString)
                rum?.startResource(resourceKey: key, httpMethod: method, urlString: url, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "stopResource":
            if let key = arguments["key"] as? String,
               let kindString = arguments["kind"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                let kind = RUMResourceType.parseFromFlutter(kindString)

                let statusCode = arguments["statusCode"] as? NSNumber
                let size = arguments["size"] as? NSNumber

                rum?.stopResource(resourceKey: key, statusCode: statusCode?.intValue,
                                  kind: kind, size: size?.int64Value, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }

        case "stopResourceWithError":
            if let key = arguments["key"] as? String,
               let message = arguments["message"] as? String,
               let errorType = arguments["type"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                rum?.stopResourceWithError(resourceKey: key, message: message, type: errorType,
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
                let errorType = arguments["errorType"] as? String

                rum?.addError(message: message, type: errorType, stack: stackTrace, source: source,
                              attributes: encodedAttributes, file: nil, line: nil)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "addAction":
            if let typeString = arguments["type"] as? String,
               let name = arguments["name"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let type = RUMActionType.parseFromFlutter(typeString)
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                rum?.addAction(type: type, name: name, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "startAction":
            if let typeString = arguments["type"] as? String,
               let name = arguments["name"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let type = RUMActionType.parseFromFlutter(typeString)
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                rum?.startAction(type: type, name: name, attributes: encodedAttributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "stopAction":
            if let typeString = arguments["type"] as? String,
               let name = arguments["name"] as? String,
               let attributes = arguments["attributes"] as? [String: Any?] {
                let type = RUMActionType.parseFromFlutter(typeString)
                let encodedAttributes = castFlutterAttributesToSwift(attributes)
                rum?.stopAction(type: type, name: name, attributes: encodedAttributes)
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
                rum?.addAttribute(forKey: key, value: encodedValue)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "removeAttribute":
            if let key = arguments["key"] as? String {
                rum?.removeAttribute(forKey: key)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "addFeatureFlagEvaluation":
            if let name = arguments["name"] as? String,
               let value = arguments["value"] {
                let encodableValue = castAnyToEncodable(value)
                rum?.addFeatureFlagEvaluation(name: name, value: encodableValue)
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
                rum?._internal?.addLongTask(at: atDate, duration: TimeInterval(duration.doubleValue / 1000.0))
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "updatePerformanceMetrics":
            if let buildTimes = arguments["buildTimes"] as? [Double],
               let rasterTimes = arguments["rasterTimes"] as? [Double] {
                // swiftlint:disable:next todo
                // TODO: Time isn't that important here, but in the future we should get it either
                // from Flutter or from the timeProvider anyway
                let date = Date()
                buildTimes.forEach { val in
                    rum?._internal?.updatePerformanceMetric(at: date, metric: .flutterBuildTime, value: val)
                }
                rasterTimes.forEach { val in
                    rum?._internal?.updatePerformanceMetric(at: date, metric: .flutterRasterTime, value: val)
                }
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
        case "stopSession":
            rum?.stopSession()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    internal func attachToExisting(rumInstance: RUMMonitorProtocol) {
        rum = rumInstance
    }

    private func enable(arguments: [String: Any?], call: FlutterMethodCall) {
        let configArg = arguments["configuration"] as? [String: Any?]
        if rum == nil {
            if let configArg = configArg,
               var config = RUM.Configuration(fromEncoded: configArg) {
                attachEventMappers(configArg: configArg, config: &config)

                RUM.enable(with: config)
                rum = RUMMonitor.shared()

                currentConfiguration = configArg as [AnyHashable: Any]
            }
        } else if currentConfiguration != nil,
                    let configArg = configArg {
            let dict = NSDictionary(dictionary: configArg as [AnyHashable: Any])
            if !dict.isEqual(to: currentConfiguration!) {
                consolePrint(
                    "🔥 Calling RUM `enable` with different options, even after a hot restart," +
                    " is not supported. Cold restart your application to change your current configuation.",
                    .error
                )
            }
        }
    }

    private func deinitialize(arguments: [String: Any?], call: FlutterMethodCall) {
        if rum != nil {
            currentConfiguration = nil
            rum = nil
        }
    }

    private func getCurrentSessionId(result: @escaping FlutterResult) {
        if let rum = rum {
            rum.currentSessionID(completion: { sessionId in
                DispatchQueue.main.async {
                    result(sessionId)
                }
            })
        } else {
            result(nil)
        }
    }

    private func attachEventMappers(configArg: [String: Any?], config: inout RUM.Configuration) {
        func isOptionSet(_ flag: String) -> Bool {
            return (configArg[flag] as? NSNumber)?.boolValue ?? false
        }

        if isOptionSet("attachViewEventMapper") {
            config.viewEventMapper = viewEventMapper
        }
        if isOptionSet("attachActionEventMapper") {
            config.actionEventMapper = actionEventMapper
        }
        if isOptionSet("attachResourceEventMapper") {
            config.resourceEventMapper = resourceEventMapper
        }
        if isOptionSet("attachErrorEventMapper") {
            config.errorEventMapper = errorEventMapper
        }
        if isOptionSet("attachLongTaskEventMapper") {
            config.longTaskEventMapper = longTaskEventMapper
        }
    }

    func callEventMapper<T>(
        mapperName: String,
        event: T,
        encodedEvent: [String: Any?],
        completion: ([String: Any?]?) -> T?) -> T? {
        guard let methodChannel = DatadogRumPlugin.methodChannel else {
            return event
        }

        var encodedResult: [String: Any?]? = encodedEvent
        let semaphore = DispatchSemaphore(value: 0)

        mainThreadMapperPerf.start()
        DispatchQueue.main.async {
            methodChannel.invokeMethod(mapperName, arguments: ["event": encodedEvent]) { result in
                if result == nil {
                    encodedResult = nil
                } else if let result = result as? [String: Any] {
                    encodedResult = result
                } else if (result as? NSObject) == FlutterMethodNotImplemented {
                    Datadog._internal.telemetry.error(
                        id: "event_mapper_not_implemented",
                        message: "\(mapperName) returned notImplemented.",
                        kind: nil,
                        stack: nil
                    )
                }

                semaphore.signal()
            }
        }

        if semaphore.wait(timeout: .now() + DispatchTimeInterval.milliseconds(500)) == .timedOut {
            Datadog._internal.telemetry.debug(id: "event_mapper_timeout", message: "\(mapperName) timed out.")
            mapperTimeouts += 1
            mainThreadMapperPerf.finishUnsampled()
            return event
        }
        mainThreadMapperPerf.finish()

        if encodedResult?["_dd.mapper_error"] != nil {
            // Error in the mapper, return the unmapped event
            return event
        }

        return completion(encodedResult)
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
        if trackMapperPerf {
            mapperPerf.start()
        }

        let encoder = DictionaryEncoder()
        var encoded: [String: Any]
        do {
            encoded = try encoder.encode(rumViewEvent)
        } catch let error {
            Datadog._internal.telemetry.error(
                id: "datadog_flutter:view_mapping_encoding",
                message: "Encoding a RUMViewEvent failed: \(error)",
                kind: "EncodingError",
                stack: nil
            )
            mapperPerf.finishUnsampled()
            return rumViewEvent
        }

        encoded["usr"] = extractUserExtraInfo(usrMember: encoded["usr"] as? [String: Any])

        let result = callEventMapper(mapperName: "mapViewEvent",
                                     event: rumViewEvent,
                                     encodedEvent: encoded) { encodedResult in
            guard let encodedResult = encodedResult else {
                return rumViewEvent
            }

            // Pull modifyable properties
            var rumViewEvent = rumViewEvent
            if let encodedView = encodedResult["view"] as? [String: Any?] {
                rumViewEvent.view.name = encodedView["name"] as? String
                rumViewEvent.view.referrer = encodedView["referrer"] as? String
                rumViewEvent.view.url = encodedView["url"] as? String ?? ""
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

        if trackMapperPerf {
            mapperPerf.finish()
        }

        return result
    }

    func actionEventMapper(rumActionEvent: RUMActionEvent) -> RUMActionEvent? {
        if trackMapperPerf {
            mapperPerf.start()
        }

        let encoder = DictionaryEncoder()
        guard var encoded = try? encoder.encode(rumActionEvent) else {
            Datadog._internal.telemetry.error(
                id: "datadog_flutter:action_mapping_encoding",
                message: "Encoding a RUMActionEvent failed",
                kind: "EncodingError",
                stack: nil
            )
            mapperPerf.finishUnsampled()
            return rumActionEvent
        }

        encoded["usr"] = extractUserExtraInfo(usrMember: encoded["usr"] as? [String: Any])

        let result = callEventMapper(mapperName: "mapActionEvent",
                                     event: rumActionEvent,
                                     encodedEvent: encoded) { encodedResult in
            guard let encodedResult = encodedResult else {
                return nil
            }

            var rumActionEvent = rumActionEvent
            if let encodedAction = encodedResult["action"] as? [String: Any?] {
                if let encodedTarget = encodedAction["target"] as? [String: Any?] {
                    rumActionEvent.action.target?.name = encodedTarget["name"] as? String ?? ""
                } else {
                    rumActionEvent.action.target = nil
                }
            }

            if let encodedView = encodedResult["view"] as? [String: Any?] {
                rumActionEvent.view.name = encodedView["name"] as? String
                rumActionEvent.view.referrer = encodedView["referrer"] as? String
                rumActionEvent.view.url = encodedView["url"] as? String ?? ""
            }

            return rumActionEvent
        }

        if trackMapperPerf {
            mapperPerf.finish()
        }

        return result
    }

    func resourceEventMapper(rumResourceEvent: RUMResourceEvent) -> RUMResourceEvent? {
        if trackMapperPerf {
            mapperPerf.start()
        }

        let encoder = DictionaryEncoder()
        guard var encoded = try? encoder.encode(rumResourceEvent) else {
            Datadog._internal.telemetry.error(
                id: "datadog_flutter:resource_mapping_encoding",
                message: "Encoding a RUMResourceEvent failed",
                kind: "EncodingError",
                stack: nil
            )
            mapperPerf.finishUnsampled()
            return rumResourceEvent
        }

        encoded["usr"] = extractUserExtraInfo(usrMember: encoded["usr"] as? [String: Any])

        let result = callEventMapper(mapperName: "mapResourceEvent",
                                     event: rumResourceEvent,
                                     encodedEvent: encoded) { encodedResult in
            guard let encodedResult = encodedResult else {
                return nil
            }

            var rumResourceEvent = rumResourceEvent

            if let encodedResource = encodedResult["resource"] as? [String: Any?] {
                rumResourceEvent.resource.url = encodedResource["url"] as? String ?? ""
            }

            if let encodedView = encodedResult["view"] as? [String: Any?] {
                rumResourceEvent.view.name = encodedView["name"] as? String
                rumResourceEvent.view.referrer = encodedView["referrer"] as? String
                rumResourceEvent.view.url = encodedView["url"] as? String ?? ""
            }

            return rumResourceEvent
        }

        if trackMapperPerf {
            mapperPerf.finish()
        }

        return result
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func errorEventMapper(rumErrorEvent: RUMErrorEvent) -> RUMErrorEvent? {
        if trackMapperPerf {
            mapperPerf.start()
        }

        let encoder = DictionaryEncoder()
        guard var encoded = try? encoder.encode(rumErrorEvent) else {
            Datadog._internal.telemetry.error(
                id: "datadog_flutter:error_mapping_encoding",
                message: "Encoding a RUMErrorEvent failed",
                kind: "EncodingError",
                stack: nil
            )
            mapperPerf.finishUnsampled()
            return rumErrorEvent
        }

        encoded["usr"] = extractUserExtraInfo(usrMember: encoded["usr"] as? [String: Any])

        let result = callEventMapper(mapperName: "mapErrorEvent",
                                     event: rumErrorEvent,
                                     encodedEvent: encoded) { encodedResult in
            guard let encodedResult = encodedResult else {
                return nil
            }

            var rumErrorEvent = rumErrorEvent

            if let encodedError = encodedResult["error"] as? [String: Any?] {
                if var causes = rumErrorEvent.error.causes,
                   let encodedCauses = encodedError["causes"] as? [Any] {
                    if encodedCauses.count == causes.count {
                        for index in 0...causes.count {
                            if let encodedCause = encodedCauses[index] as? [String: Any?] {
                                causes[index].message = encodedCause["message"] as? String ?? ""
                                causes[index].stack = encodedCause["stack"] as? String
                            }
                        }
                        rumErrorEvent.error.causes = causes
                    } else {
                        consolePrint(
                            "🔥 Adding or removing RumErrorCauses to 'errorEvent.error.causes'" +
                            " in the rumErrorEventMapper is not supported." +
                            " You can modify individual causes, but do not modify the array.",
                            .error)
                    }
                } else {
                    rumErrorEvent.error.causes = nil
                }

                if let encodedResource = encodedError["resource"] as? [String: Any?] {
                    rumErrorEvent.error.resource?.url = encodedResource["url"] as? String ?? ""
                }

                rumErrorEvent.error.stack = encodedError["stack"] as? String
                rumErrorEvent.error.fingerprint = encodedError["fingerprint"] as? String
            }

            if let encodedView = encodedResult["view"] as? [String: Any?] {
                rumErrorEvent.view.name = encodedView["name"] as? String
                rumErrorEvent.view.referrer = encodedView["referrer"] as? String
                rumErrorEvent.view.url = encodedView["url"] as? String ?? ""
            }

            return rumErrorEvent
        }

        if trackMapperPerf {
            mapperPerf.finish()
        }

        return result
    }

    func longTaskEventMapper(longTaskEvent: RUMLongTaskEvent) -> RUMLongTaskEvent? {
        if trackMapperPerf {
            mapperPerf.start()
        }

        let encoder = DictionaryEncoder()
        guard var encoded = try? encoder.encode(longTaskEvent) else {
            Datadog._internal.telemetry.error(
                id: "datadog_flutter:long_task_mapping_encoding",
                message: "Encoding a RUMLongTaskEvent failed",
                kind: "EncodingError",
                stack: nil
            )
            mapperPerf.finishUnsampled()
            return longTaskEvent
        }

        encoded["usr"] = extractUserExtraInfo(usrMember: encoded["usr"] as? [String: Any])

        let result = callEventMapper(mapperName: "mapLongTaskEvent",
                                     event: longTaskEvent,
                                     encodedEvent: encoded) { encodedResult in
            guard let encodedResult = encodedResult else {
                return nil
            }

            var longTaskEvent = longTaskEvent

            if let encodedView = encodedResult["view"] as? [String: Any?] {
                longTaskEvent.view.name = encodedView["name"] as? String
                longTaskEvent.view.referrer = encodedView["referrer"] as? String
                longTaskEvent.view.url = encodedView["url"] as? String ?? ""
            }

            return longTaskEvent
        }

        if trackMapperPerf {
            mapperPerf.finish()
        }

        return result
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

public extension RUMActionType {
    static func parseFromFlutter(_ value: String) -> RUMActionType {
        switch value {
        case "RumActionType.tap": return .tap
        case "RumActionType.scroll": return .scroll
        case "RumActionType.swipe": return .swipe
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

public extension RUM.Configuration.VitalsFrequency {
    static func parseFromFlutter(_ value: String) -> RUM.Configuration.VitalsFrequency? {
        switch value {
        case "VitalsFrequency.frequent": return .frequent
        case "VitalsFrequency.average": return .average
        case "VitalsFrequency.rare": return .rare
        default: return nil
        }
    }
}

internal class PerformanceTracker {
    private(set) var minInMs = Double.infinity
    private(set) var maxInMs = 0.0
    private(set) var avgInMs = 0.0
    private(set) var samples = 0.0

    private var lastStart = 0.0

    func start() {
        lastStart = CACurrentMediaTime()
    }

    func finish() {
        // Check for bad call to finish
        if lastStart > 0 {
            let endTime = CACurrentMediaTime()
            let perfInMs = (endTime - lastStart) * 1000.0

            minInMs = min(perfInMs, minInMs)
            maxInMs = max(perfInMs, maxInMs)
            avgInMs = (perfInMs + (samples * avgInMs)) / (samples + 1.0)
            samples += 1.0
        }

        lastStart = 0.0
    }

    func finishUnsampled() {
        lastStart = 0.0
    }
}
