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
    public static let instance = DatadogLogsPlugin()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.logs", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var loggerRegistry: [String: LoggerProtocol] = [:]

    override private init() {
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

        if call.method == "enable" {
            // When we support multiple cores / instances, pass it in here
            if let configArg = arguments["configuration"] as? [String: Any?] {
                let config = Logs.Configuration(fromEncoded: configArg)
                Logs.enable(with: config)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }
            return
        }

        guard let loggerHandle = arguments["loggerHandle"] as? String else {
            result(
                FlutterError.missingParameter(methodName: call.method)
            )
            return
        }

        // Before other functions, see if we want to create a logger. All other functions
        // require a logger already exist.
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
