// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import Flutter
import DatadogCore
import DatadogLogs
import DatadogInternal

extension Logs.Configuration {
    init(fromEncoded encoded: [String: Any?]) {
        self.init()

        customEndpoint = convertOptional(encoded["customEndpoint"] as? String, {
            return URL(string: $0)
        })
    }
}

extension Logger.Configuration {
    init(fromEncoded encoded: [String: Any?]) {
        self.init()

        service = encoded["service"] as? String
        name = encoded["name"] as? String
        networkInfoEnabled = (encoded["networkInfoEnabled"] as? NSNumber)?.boolValue ?? false
        bundleWithRumEnabled = (encoded["bundleWithRumEnabled"] as? NSNumber)?.boolValue ?? true
        bundleWithTraceEnabled = (encoded["bundleWithTraceEnabled"] as? NSNumber)?.boolValue ?? true
        // Flutter SDK handles sampling and threshold, so set these to their most accepting all the time
        remoteSampleRate = 100.0
        remoteLogThreshold = .debug
    }
}

public class DatadogLogsPlugin: NSObject, FlutterPlugin {
    public static var instance: DatadogLogsPlugin?
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.logs", binaryMessenger: registrar.messenger())
        instance = DatadogLogsPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance!, channel: channel)

    }

    private let channel: FlutterMethodChannel
    private var currentConfiguration: [AnyHashable: Any]?
    private var loggerRegistry: [String: LoggerProtocol] = [:]

    private init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    public func onDetach() {

    }

    func addLogger(logger: LoggerProtocol, withHandle handle: String) {
        loggerRegistry[handle] = logger
    }

    func createLogger(loggerHandle: String, configuration: [String: Any?]) {
        let config = Logger.Configuration(fromEncoded: configuration)
        let logger = Logger.create(with: config)
        loggerRegistry[loggerHandle] = logger
    }

    internal func logger(withHandle handle: String) -> LoggerProtocol? {
        return loggerRegistry[handle]
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any] else {
            result(
                FlutterError.invalidOperation(message: "No arguments in call to \(call.method).")
            )
            return
        }

        if handleGlobalMethod(call: call, arguments: arguments, result: result) {
            return
        }

        guard let loggerHandle = arguments["loggerHandle"] as? String else {
            result(
                FlutterError.missingParameter(methodName: call.method)
            )
            return
        }

        // Global 'logs' functions don't require a logger, all others do
        if call.method == "createLogger" {
            guard let encodedConfiguration = arguments["configuration"] as? [String: Any?] else {
                result(FlutterError.invalidOperation(message: "Bad logging configuration sent to createLogger"))
                return
            }
            createLogger(loggerHandle: loggerHandle, configuration: encodedConfiguration)
            result(nil)
            return
        }

        guard let logger = loggerRegistry[loggerHandle] else {
            result(
                FlutterError.invalidOperation(
                    message: "No logger available with handle \(loggerHandle) in call to \(call.method).")
            )
            return
        }

        var attributes: [String: Encodable]?
        if let context = arguments["context"] as? [String: Any?] {
            attributes = castFlutterAttributesToSwift(context)
        }

        switch call.method {
        case "destroyLogger":
            loggerRegistry.removeValue(forKey: loggerHandle)
            result(nil)

        case "log":
            if let message = arguments["message"] as? String,
                let levelString = arguments["logLevel"] as? String {
                let level = LogLevel.parseLogLevelFromFlutter(levelString)

                // Optional args
                let errorKind = arguments["errorKind"] as? String
                let errorMessage = arguments["errorMessage"] as? String
                let stackTrace = arguments["stackTrace"] as? String

                logger._internal.log(
                    level: level,
                    message: message,
                    errorKind: errorKind,
                    errorMessage: errorMessage,
                    stackTrace: stackTrace,
                    attributes: attributes
                )

                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }

        case "addAttribute":
            if let key = arguments["key"] as? String,
               let value = arguments["value"] {
                logger.addAttribute(forKey: key, value: DdFlutterEncodable(value))
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }

        case "removeAttribute":
            if let key = arguments["key"] as? String {
                logger.removeAttribute(forKey: key)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }

        case "addTag":
            if let tag = arguments["tag"] as? String {
                if let keyValue = arguments["value"] as? String {
                    logger.addTag(withKey: tag, value: keyValue)
                } else {
                    logger.add(tag: tag)
                }
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }

        case "removeTag":
            if let tag = arguments["tag"] as? String {
                logger.remove(tag: tag)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }

        case "removeTagWithKey":
            if let key = arguments["key"] as? String {
                logger.removeTag(withKey: key)
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

    // Returns true if this method was handled
    private func handleGlobalMethod(call: FlutterMethodCall, arguments: [String: Any?], result: @escaping FlutterResult) -> Bool {
        if call.method == "enable" {
            enable(arguments: arguments, result: result)
            return true
        } else if call.method == "deinitialize" {
            deinitialize(arguments: arguments, result: result)
            return true
        } else if call.method == "addGlobalAttribute" {
            if let key = arguments["key"] as? String,
               let value = arguments["value"] {
                Logs.addAttribute(forKey: key, value: DdFlutterEncodable(value))
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
            return true
        } else if call.method == "removeGlobalAttribute" {
            if let key = arguments["key"] as? String {
                Logs.removeAttribute(forKey: key)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
            return true
        }
        return false
    }

    private func enable(arguments: [String: Any?], result: @escaping FlutterResult) {
        if let configArg = arguments["configuration"] as? [String: Any?] {
            if currentConfiguration == nil {
                var config = Logs.Configuration(fromEncoded: configArg)
                let attachLogMapper = (configArg["attachLogMapper"] as? NSNumber)?.boolValue ?? false
                if attachLogMapper {
                    config._internal_mutation {
                        $0.setLogEventMapper(FlutterLogEventMapper(channel: channel))
                    }
                }
                Logs.enable(with: config)
                currentConfiguration = configArg as [AnyHashable: Any]
            } else {
                let dict = NSDictionary(dictionary: configArg as [AnyHashable: Any])
                if !dict.isEqual(to: currentConfiguration!) {
                    consolePrint(
                        "🔥 Calling Logging `enable` with different options, even after a hot restart," +
                        " is not supported. Cold restart your application to change your current configuation.",
                        .error)
                }
            }
            result(nil)
        } else {
            result(
                FlutterError.missingParameter(methodName: "enable")
            )
        }
    }

    private func deinitialize(arguments: [String: Any?], result: @escaping FlutterResult) {
        currentConfiguration = nil
        result(nil)
    }
}

 struct FlutterLogEventMapper: LogEventMapper {
    static let reservedAttributeNames: Set<String> = [
        "host", "message", "status", "service", "source", "ddtags",
        "dd.trace_id", "dd.span_id",
        "application_id", "session_id", "view.id", "user_action.id"
    ]

    let channel: FlutterMethodChannel

    public init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    func map(event: LogEvent, callback: @escaping (LogEvent) -> Void) {
        guard let encoded = logEventToFlutterDictionary(event: event) else {
            // TELEMETRY
            callback(event)
            return
        }

        DispatchQueue.main.async {
            channel.invokeMethod("mapLogEvent", arguments: ["event": encoded]) { result in
                guard let result = result as? [String: Any] else {
                    // Don't call the callback, this event was discarded
                    return
                }

                if result["_dd.mapper_error"] != nil {
                    // Error in the mapper, return the unmapped event
                    callback(event)
                }

                // Don't bother to decode, just pull modifiable properties straight from the
                // dictionary.
                var event = event
                if let message = result["message"] as? String {
                    event.message = message
                }
                if let tags = result["ddtags"] as? String {
                    let splitTags = tags.split(separator: ",").map { String($0) }
                    event.tags = splitTags
                }
                if let error = result["error"] as? [String: Any], 
                   let fingerprint = error["fingerprint"] as? String {
                    event.error?.fingerprint = fingerprint
                }

                // Go through all remaining attributes and add them on to the user
                // attibutes so long as they aren't reserved
                event.attributes.userAttributes.removeAll()
                for (key, value) in result {
                    if FlutterLogEventMapper.reservedAttributeNames.contains(key) {
                        continue
                    }
                    event.attributes.userAttributes[key] = castAnyToEncodable(value)
                }

                callback(event)
            }
        }
    }
 }

public extension LogLevel {
    static func parseLogLevelFromFlutter(_ value: String) -> Self {
        switch value {
        case "LogLevel.debug": return .debug
        case "LogLevel.info": return .info
        case "LogLevel.notice": return .notice
        case "LogLevel.warning": return .warn
        case "LogLevel.error": return .error
        case "LogLevel.critical": return .critical
        case "LogLevel.alert": return .critical
        case "LogLevel.emergency": return .critical
        default: return .info
        }
    }
}
