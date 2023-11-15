// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Flutter
import UIKit
import DatadogCore
import DatadogCrashReporting
import DatadogInternal
import DatadogRUM
import DatadogLogs

extension Datadog.Configuration {
    init?(fromEncoded encoded: [String: Any?]) {
        guard let clientToken: String = try? castUnwrap(encoded["clientToken"]),
              let env: String = try? castUnwrap(encoded["env"]) else {
            return nil
        }

        self.init(
            clientToken: clientToken,
            env: env
        )

        service = try? castUnwrap(encoded["service"])

        if let site = convertOptional(encoded["site"], DatadogSite.parseFromFlutter) {
            self.site = site
        }
        if let batchSize = convertOptional(encoded["batchSize"], Datadog.Configuration.BatchSize.parseFromFlutter) {
            self.batchSize = batchSize
        }
        if let uploadFrequency = convertOptional(encoded["uploadFrequency"],
                                                 Datadog.Configuration.UploadFrequency.parseFromFlutter) {
            self.uploadFrequency = uploadFrequency
        }

        _internal_mutation { config in
            config.additionalConfiguration = encoded["additionalConfig"] as? [String: Any] ?? [:]
        }
    }
}

// swiftlint:disable type_body_length
public class DatadogSdkPlugin: NSObject, FlutterPlugin {
    let channel: FlutterMethodChannel

    // NOTE: Although these are instances, they are still registered globally to
    // a method channel. That might be something we want to change in the future
    public private(set) var logs: DatadogLogsPlugin?
    public private(set) var rum: DatadogRumPlugin?

    var currentConfiguration: [AnyHashable: Any]?
    var core: DatadogCoreProtocol?
    var oldConsolePrint: ((String) -> Void)?

    public init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "datadog_sdk_flutter", binaryMessenger: registrar.messenger())
        let instance = DatadogSdkPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
        registrar.publish(instance)

        DatadogLogsPlugin.register(with: registrar)
        DatadogRumPlugin.register(with: registrar)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any] else {
            result(
                FlutterError.invalidOperation(message: "No arguments in call to \(call.method)")
            )
            return
        }

        switch call.method {
        case "initialize":
            // swiftlint:disable:next force_cast
            let configArg = arguments["configuration"] as! [String: Any?]
            if let config = Datadog.Configuration.init(fromEncoded: configArg),
               let trackingConsentString: String = try? castUnwrap(arguments["trackingConsent"]) {
                let trackingConsent = TrackingConsent.parseFromFlutter(trackingConsentString)
                if !Datadog.isInitialized() {
                    initialize(configuration: config, trackingConsent: trackingConsent)
                    currentConfiguration = configArg as [AnyHashable: Any]

                    core?.telemetry.configuration(
                        dartVersion: arguments["dartVersion"] as? String
                    )

                    if let crashReportingEnabled = (configArg["nativeCrashReportEnabled"] as? NSNumber)?.boolValue {
                        if crashReportingEnabled {
                            CrashReporting.enable()
                        }
                    }
                } else {
                    let dict = NSDictionary(dictionary: configArg as [AnyHashable: Any])
                    if !dict.isEqual(to: currentConfiguration!) {
                        consolePrint(
                            "🔥 Reinitialziing the DatadogSDK with different options, even after a hot restart," +
                            " is not supported. Cold restart your application to change your current configuation."
                        )
                    }
                }
                result(nil)
            } else {
                result(FlutterError.missingParameter(methodName: call.method))
            }
        case "attachToExisting":
            if Datadog.isInitialized() {
                let attachResult = attachToExisting()
                result(attachResult)
            } else {
                consolePrint(
                    "🔥 attachToExisting was called, but no existing instance of the Datadog SDK exists." +
                    " Make sure to initialize the Native Datadog SDK before calling attachToExisting.")
                result(nil)
            }
        case "setSdkVerbosity":
            if let verbosityString = arguments["value"] as? String {
                let verbosity = CoreLoggerLevel.parseFromFlutter(verbosityString)
                Datadog.verbosityLevel = verbosity
                result(nil)
            } else {
                result(FlutterError.missingParameter(methodName: call.method))
            }
        case "setUserInfo":
            if let extraInfo = arguments["extraInfo"] as? [String: Any?] {
                let id = arguments["id"] as? String
                let name = arguments["name"] as? String
                let email = arguments["email"] as? String
                let encodedAttributes = castFlutterAttributesToSwift(extraInfo)
                Datadog.setUserInfo(id: id, name: name, email: email, extraInfo: encodedAttributes)
                result(nil)
            } else {
                result(FlutterError.missingParameter(methodName: call.method))
            }
        case "addUserExtraInfo":
            if let extraInfo = arguments["extraInfo"] as? [String: Any?] {
                let encodedAttributes = castFlutterAttributesToSwift(extraInfo)
                Datadog.addUserExtraInfo(encodedAttributes)
                result(nil)
            } else {
                result(FlutterError.missingParameter(methodName: call.method))
            }
        case "setTrackingConsent":
            if let trackingConsentString = arguments["value"] as? String {
                let trackingConsent = TrackingConsent.parseFromFlutter(trackingConsentString)
                Datadog.set(trackingConsent: trackingConsent)
                result(nil)
            } else {
                result(FlutterError.missingParameter(methodName: call.method))
            }
        case "telemetryDebug":
            if let message = arguments["message"] as? String {
                Datadog._internal.telemetry.debug(id: "datadog_flutter:\(message)", message: message)
                result(nil)
            } else {
                result(FlutterError.missingParameter(methodName: call.method))
            }
        case "telemetryError":
            if let message = arguments["message"] as? String {
                let stack = arguments["stack"] as? String
                let kind = arguments["kind"] as? String
                Datadog._internal.telemetry.error(id: "datadog_flutter:\(String(describing: kind)):\(message)",
                                                  message: message, kind: kind, stack: stack)
                result(nil)
            } else {
                result(FlutterError.missingParameter(methodName: call.method))
            }
        case "updateTelemetryConfiguration":
            updateTelemetryConfiguration(arguments: arguments)
            result(nil)
        case "getInternalVar":
            guard let varName = arguments["name"] as? String else {
                result(nil)
                return
            }

            let value = getInternalVar(named: varName)
            result(value)
#if DD_SDK_COMPILED_FOR_TESTING
        case "flushAndDeinitialize":
            Datadog.flushAndDeinitialize()
            consolePrint = { value in print(value) }
            logs = nil
            rum = nil
            result(nil)
#endif
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    internal func initialize(configuration: Datadog.Configuration, trackingConsent: TrackingConsent) {
        core = Datadog.initialize(with: configuration, trackingConsent: trackingConsent)
    }

    private func updateTelemetryConfiguration(arguments: [String: Any]) {
        var wasValid = true
        let option = arguments["option"]
        let value = arguments["value"]

        if let option = option as? String,
           let value = value as? Bool {
            switch option {
            case "trackViewsManually":
                core?.telemetry.configuration(
                    trackViewsManually: value
                )
            case "trackInteractions":
                core?.telemetry.configuration(
                    trackInteractions: value
                )
            case "trackErrors":
                core?.telemetry.configuration(
                    trackErrors: value
                )
            case "trackNetworkRequests":
                core?.telemetry.configuration(
                    trackNetworkRequests: value
                )
            case "trackNativeViews":
                core?.telemetry.configuration(
                    trackNativeViews: value
                )
            case "trackCrossPlatformLongTasks":
                core?.telemetry.configuration(
                    trackCrossPlatformLongTasks: value
                )
            case "trackFlutterPerformance":
                core?.telemetry.configuration(
                    trackFlutterPerformance: value
                )
            default:
                wasValid = false
            }
        } else {
            wasValid = false
        }

        if !wasValid {
            Datadog._internal.telemetry.debug(
                id: "datadog_flutter:configuration_error",
                message: "Attempting to set telemetry configuration option '\(String(describing: option))'" +
                    " to '\(String(describing: value))', which is invalid.")
        }
    }

    private func getInternalVar(named name: String) -> Any? {
        switch name {
        case "mapperPerformance":
            let value: [String: Any?] = [
                "total": [
                    "minMs": rum?.mapperPerf.minInMs,
                    "maxMs": rum?.mapperPerf.maxInMs,
                    "avgMs": rum?.mapperPerf.avgInMs
                ],
                "mainThread": [
                    "minMs": rum?.mainThreadMapperPerf.minInMs,
                    "maxMs": rum?.mainThreadMapperPerf.maxInMs,
                    "avgMs": rum?.mainThreadMapperPerf.avgInMs
                ],
                "mapperTimeouts": rum?.mapperTimeouts
            ]
            return value
        default:
            return nil
        }
    }

    public func applicationWillTerminate(_ application: UIApplication) {
        _onDetach()
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        registrar.publish(NSNull())
        _onDetach()
    }

    private func _onDetach() {
        // Reset consolePrint during detach - any other methodChannel callbacks will
        // also need to be cleared as well
        if let oldConsolePrint = oldConsolePrint {
            consolePrint = oldConsolePrint
        }
        oldConsolePrint = nil

        logs?.onDetach()
        rum?.onDetach()
    }

    private func attachToExisting() -> [String: Any?] {
        var rumEnabled = false
        var logsEnabled = false

        core = Datadog.sdkInstance(named: CoreRegistry.defaultInstanceName)
        if Logs._internal.isEnabled() {
            logs = DatadogLogsPlugin.instance
            logsEnabled = true
        }

        if RUM._internal.isEnabled() {
            rum = DatadogRumPlugin.instance
            rum?.attachToExisting(rumInstance: RUMMonitor.shared())
            rumEnabled = true
        }

        return [
            "loggingEnabled": logsEnabled,
            "rumEnabled": rumEnabled
        ]
    }

    // This is a way to work around https://github.com/flutter/flutter/issues/126671
    private func callLogCallback(_ value: String) {
        // Dispatch to the main thread. This is partially to combat Flutter shutdown
        // occuring while we're still processing events
        DispatchQueue.main.async {
            // Second, check that the engine hasn't been destroyed, this is the
            // other work around for https://github.com/flutter/flutter/issues/126671
            if let flutterViewController =
                UIApplication.shared.keyWindow?.rootViewController as? FlutterViewController {
                let engine = flutterViewController.engine
                if engine?.isolateId == nil {
                    return
                }
            }

            self.channel.invokeMethod("logCallback", arguments: value)
        }
    }
}

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
