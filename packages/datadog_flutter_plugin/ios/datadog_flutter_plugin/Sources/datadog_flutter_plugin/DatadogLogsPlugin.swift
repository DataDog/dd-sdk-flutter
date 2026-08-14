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
    /// No-op: registration now happens per-instance via `attachToEngine(registrar:)`, called by
    /// `DatadogSdkPlugin`, which owns one `DatadogLogsPlugin` instance per engine. This static method
    /// only exists to satisfy `FlutterPlugin` conformance and is never actually invoked, since this
    /// type is not listed in `GeneratedPluginRegistrant` (only `DatadogSdkPlugin` is).
    public static func register(with registrar: FlutterPluginRegistrar) {}

    func attachToEngine(registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.logs", binaryMessenger: registrar.messenger())
        methodChannel = channel
        registrar.addMethodCallDelegate(self, channel: channel)
    }

    private let methodChannelLock = NSLock()
    private var _methodChannel: FlutterMethodChannel?
    /// Cleared on teardown, so `FlutterLogEventMapper` — which lives inside the SDK for the rest of the
    /// process — can re-read it per event rather than holding a channel that outlives its engine.
    /// Lock-backed because it's read on Datadog worker threads while `onDetach()` clears it on the
    /// main thread.
    internal var methodChannel: FlutterMethodChannel? {
        get {
            methodChannelLock.lock()
            defer { methodChannelLock.unlock() }
            return _methodChannel
        }
        set {
            methodChannelLock.lock()
            defer { methodChannelLock.unlock() }
            _methodChannel = newValue
        }
    }

    private static var previousConfiguration: [AnyHashable: Any]?
    private var loggerRegistry: [String: LoggerProtocol] = [:]

    override init() {
        super.init()
    }

    /// Drops the channel so a log mapper cannot reach an engine that can no longer receive it.
    ///
    /// `FlutterLogEventMapper` is handed to `Logs.enable` and lives inside the SDK for the rest of the
    /// process, mapping events on Datadog worker threads. Once the engine resets its shell,
    /// `-[FlutterEngine sendOnChannel:message:binaryReply:]` asserts and the app dies — the same crash
    /// as #1062 in RUM.
    ///
    /// Called by `DatadogSdkPlugin`, which owns this plugin's registration.
    public func onDetach() {
        methodChannel = nil
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
    private func handleGlobalMethod(
        call: FlutterMethodCall,
        arguments: [String: Any?],
        result: @escaping FlutterResult
    ) -> Bool {
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
        guard let configArg = arguments["configuration"] as? [String: Any?] else {
            result(FlutterError.missingParameter(methodName: "enable"))
            return
        }

        if Self.previousConfiguration == nil {
            if Logs._internal.isEnabled() {
                // Another engine's instance already configured Logs; nothing more to configure.
                Self.previousConfiguration = configArg as [AnyHashable: Any]
            } else {
                var config = Logs.Configuration(fromEncoded: configArg)
                let attachLogMapper = (configArg["attachLogMapper"] as? NSNumber)?.boolValue ?? false
                if attachLogMapper {
                    config._internal_mutation {
                        $0.setLogEventMapper(FlutterLogEventMapper(owner: self))
                    }
                }
                Logs.enable(with: config)
                Self.previousConfiguration = configArg as [AnyHashable: Any]
            }
        } else {
            let dict = NSDictionary(dictionary: configArg as [AnyHashable: Any])
            if !dict.isEqual(to: Self.previousConfiguration!) {
                consolePrint(
                    "🔥 Calling Logging `enable` with different options, even after a hot restart," +
                    " is not supported. Cold restart your application to change your current configuation.",
                    .error)
            }
        }
        result(nil)
    }

    private func deinitialize(arguments: [String: Any?], result: @escaping FlutterResult) {
        result(nil)
    }
}

 struct FlutterLogEventMapper: LogEventMapper {
    static let reservedAttributeNames: Set<String> = [
        "host", "message", "status", "service", "source", "ddtags",
        "dd.trace_id", "dd.span_id",
        "application_id", "session_id", "view.id", "user_action.id"
    ]

    /// Weak because the native SDK retains this mapper for the life of the process — a strong
    /// reference here would keep a torn-down engine's plugin (and its channel) alive indefinitely.
    weak var owner: DatadogLogsPlugin?

    func map(event: LogEvent, callback: @escaping (LogEvent) -> Void) {
        guard let encoded = logEventToFlutterDictionary(event: event) else {
            // TELEMETRY
            callback(event)
            return
        }

        DispatchQueue.main.async {
            // Re-read the channel instead of holding it: this mapper lives inside the SDK for the rest
            // of the process, so the engine can tear down — and `onDetach` clear the channel — between
            // `Logs.enable` and this block being drained. Sending after that asserts on a reset shell.
            guard let channel = owner?.methodChannel else {
                callback(event)
                return
            }
            channel.invokeMethod("mapLogEvent", arguments: ["event": encoded]) { result in
                guard let result = result as? [String: Any] else {
                    // Don't call the callback, this event was discarded
                    return
                }

                if result["_dd.mapper_error"] != nil {
                    // Error in the mapper, return the unmapped event
                    callback(event)
                    return
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
