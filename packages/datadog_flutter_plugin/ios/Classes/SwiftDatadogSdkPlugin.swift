// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Flutter
import UIKit
import Datadog
import DatadogCrashReporting
import DictionaryCoder
import webview_flutter_wkwebview

public class SwiftDatadogSdkPlugin: NSObject, FlutterPlugin {
    struct ConfigurationTelemetryOverrides {
        var trackViewsManually: Bool = true
        var trackInteractions: Bool = false
        var trackErrors: Bool = false
        var trackNetworkRequests: Bool = false
        var trackNativeViews: Bool = false
        var trackCrossPlatformLongTasks: Bool = false
        var trackFlutterPerformance: Bool = false
    }

    let channel: FlutterMethodChannel

    // NOTE: Although these are instances, they are still registered globally to
    // a method channel. That might be something we want to change in the future
    public private(set) var logs: DatadogLogsPlugin?
    public private(set) var rum: DatadogRumPlugin?

    var currentConfiguration: [AnyHashable: Any]?
    var configurationTelemetryOverrides: ConfigurationTelemetryOverrides = .init()
    var oldConsolePrint: ((String) -> Void)?

    public init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "datadog_sdk_flutter", binaryMessenger: registrar.messenger())
        let instance = SwiftDatadogSdkPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
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
            let configArg = arguments["configuration"] as! [String: Any?]
            if let config = DatadogFlutterConfiguration(fromEncoded: configArg) {
                if !Datadog.isInitialized {
                    // Set log callback before initialization so errors in initialization
                    // get printed
                    if let setLogCallback = arguments["setLogCallback"] as? Bool,
                       setLogCallback {
                        oldConsolePrint = consolePrint
                        consolePrint = { value in
                            self.channel.invokeMethod("logCallback", arguments: value)
                        }
                    }

                    initialize(configuration: config)
                    currentConfiguration = configArg as [AnyHashable: Any]
                } else {
                    let dict = NSDictionary(dictionary: configArg as [AnyHashable: Any])
                    if !dict.isEqual(to: currentConfiguration!) {
                        consolePrint(
                            "🔥 Reinitialziing the DatadogSDK with different options, even after a hot restart," +
                            " is not supported. Cold restart your application to change your current configuation."
                        )
                    }
                }
            }
            result(nil)
        case "attachToExisting":
            if Datadog.isInitialized {
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
                let verbosity = LogLevel.parseVerbosityFromFlutter(verbosityString)
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
        case "initWebView":
            if let number = arguments["webViewIdentifier"] as? NSNumber,
               let allowedHosts = arguments["allowedHosts"] as? [String] {
                let webViewIdentifier = number.intValue

                // TODO: Add to app scenario, search for a FlutterViewController to get the
                // registry
                if let pluginRegistry = UIApplication.shared.delegate as? FlutterPluginRegistry,
                   let webview = FWFWebViewFlutterWKWebViewExternalAPI.webView(forIdentifier: webViewIdentifier, with: pluginRegistry) {
                    webview.configuration.userContentController.trackDatadogEvents(in: Set(allowedHosts))
                }
                result(nil)
            } else {
                result(FlutterError.missingParameter(methodName: call.method))
            }
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

    internal func initialize(configuration: DatadogFlutterConfiguration) {
        let ddConfiguration = configuration.toDdConfigBuilder()

        if configuration.attachLogMapper {
            _ = ddConfiguration._internal.setLogEventMapper(FlutterLogEventMapper(channel: channel))
        }

        if configuration.rumConfiguration?.attachViewEventMapper == true {
            _ = ddConfiguration.setRUMViewEventMapper(DatadogRumPlugin.instance.viewEventMapper)
        }
        if configuration.rumConfiguration?.attachActionEventMapper == true {
            _ = ddConfiguration.setRUMActionEventMapper(DatadogRumPlugin.instance.actionEventMapper)
        }
        if configuration.rumConfiguration?.attachResourceEventMapper == true {
            _ = ddConfiguration.setRUMResourceEventMapper(DatadogRumPlugin.instance.resourceEventMapper)
        }
        if configuration.rumConfiguration?.attachErrorEventMapper == true {
            _ = ddConfiguration.setRUMErrorEventMapper(DatadogRumPlugin.instance.errorEventMapper)
        }
        if configuration.rumConfiguration?.attachLongTaskMapper == true {
            _ = ddConfiguration.setRUMLongTaskEventMapper(DatadogRumPlugin.instance.longTaskEventMapper)
        }

        Datadog.initialize(appContext: Datadog.AppContext(),
                           trackingConsent: configuration.trackingConsent,
                           configuration: ddConfiguration.build())

        if let rumConfiguration = configuration.rumConfiguration {
            rum = DatadogRumPlugin.instance
            rum?.initialize(configuration: rumConfiguration)

            if configuration.additionalConfig["_dd.track_mapper_performance"] as? Bool == true {
                rum?.trackMapperPerf = true
            }
        }

        Datadog._internal.telemetry.setConfigurationMapper { [weak self] event in
            guard let self = self else {
                return event
            }

            // Supply configuration overrides
            var event = event
            var configuration = event.telemetry.configuration
            configuration.trackViewsManually = self.configurationTelemetryOverrides.trackViewsManually
            configuration.trackInteractions = self.configurationTelemetryOverrides.trackInteractions
            configuration.trackErrors = self.configurationTelemetryOverrides.trackErrors
            configuration.trackNetworkRequests = self.configurationTelemetryOverrides.trackNetworkRequests
            configuration.trackNativeViews = self.configurationTelemetryOverrides.trackNativeViews
            configuration.trackCrossPlatformLongTasks = self.configurationTelemetryOverrides.trackCrossPlatformLongTasks
            configuration.trackFlutterPerformance = self.configurationTelemetryOverrides.trackFlutterPerformance
            event.telemetry.configuration = configuration

            return event
        }
    }

    private func updateTelemetryConfiguration(arguments: [String: Any]) {
        var wasValid = true
        let option = arguments["option"]
        let value = arguments["value"]

        if let option = option as? String,
           let value = value as? Bool {
            switch option {
            case "trackViewsManually":
                configurationTelemetryOverrides.trackViewsManually = value
            case "trackInteractions":
                configurationTelemetryOverrides.trackInteractions = value
            case "trackErrors":
                configurationTelemetryOverrides.trackErrors = value
            case "trackNetworkRequests":
                configurationTelemetryOverrides.trackNetworkRequests = value
            case "trackNativeViews":
                configurationTelemetryOverrides.trackNativeViews = value
            case "trackCrossPlatformLongTasks":
                configurationTelemetryOverrides.trackCrossPlatformLongTasks = value
            case "trackFlutterPerformance":
                configurationTelemetryOverrides.trackFlutterPerformance = value
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
        if Global.rum is RUMMonitor {
            rum = DatadogRumPlugin.instance
            rum?.attachToExisting(rumInstance: Global.rum)
            rumEnabled = true
        }

        return [
            "rumEnabled": rumEnabled
        ]
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
