// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import Datadog

public class DatadogLogsPlugin: NSObject, FlutterPlugin {
    public static let instance = DatadogLogsPlugin()
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.logs", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var loggerRegistry: [String: Logger] = [:]

    override private init() {
        super.init()
    }
    
    public func onDetach() {
        
    }

    func addLogger(logger: Logger, withHandle handle: String) {
        loggerRegistry[handle] = logger
    }

    func createLogger(loggerHandle: String, configuration: DatadogLoggingConfiguration) {
        let builder = Logger.builder
            .sendLogsToDatadog(configuration.sendLogsToDatadog)
            .sendNetworkInfo(configuration.sendNetworkInfo)
            .printLogsToConsole(configuration.printLogsToConsole)
            .bundleWithRUM(configuration.bundleWithRum)
        if let loggerName = configuration.loggerName {
            _ = builder.set(loggerName: loggerName)
        }
        let logger = builder.build()
        loggerRegistry[loggerHandle] = logger
    }

    internal func logger(withHandle handle: String) -> Logger? {
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

        guard let loggerHandle = arguments["loggerHandle"] as? String else {
            result(
                FlutterError.missingParameter(methodName: call.method)
            )
            return
        }

        // Before other functions, see if we want to create a logger. All other functions
        // require a logger already exist.
        if call.method == "createLogger" {
            guard let encodedConfiguration = arguments["configuration"] as? [String: Any?],
                  let configuration = DatadogLoggingConfiguration.init(fromEncoded: encodedConfiguration) else {
                result(FlutterError.invalidOperation(message: "Bad logging configuration sent to createLogger"))
                return
            }
            createLogger(loggerHandle: loggerHandle, configuration: configuration)
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

        let message = arguments["message"] as? String
        var attributes: [String: Encodable]?
        if let context = arguments["context"] as? [String: Any?] {
            attributes = castFlutterAttributesToSwift(context)
        }

        switch call.method {
        case "debug":
            if let message = message {
                logger.debug(message, error: nil, attributes: attributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }

        case "info":
            if let message = message {
                logger.info(message, error: nil, attributes: attributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }

        case "warn":
            if let message = message {
                logger.warn(message, error: nil, attributes: attributes)
                result(nil)
            } else {
                result(
                    FlutterError.missingParameter(methodName: call.method)
                )
            }

        case "error":
            if let message = message {
                logger.error(message, error: nil, attributes: attributes)
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
