// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Flutter
import UIKit
import Datadog
import DatadogCrashReporting

public class SwiftDatadogSdkPlugin: NSObject, FlutterPlugin {
    let channel: FlutterMethodChannel

    // NOTE: Although these are instances, they are still registered globally to
    // a method channel. That might be something we want to change in the future
    public private(set) var logs: DatadogLogsPlugin?
    public private(set) var rum: DatadogRumPlugin?

    var currentConfiguration: [AnyHashable: Any]?

    public init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "datadog_sdk_flutter", binaryMessenger: registrar.messenger())
        let instance = SwiftDatadogSdkPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)

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
                    initialize(configuration: config)
                    currentConfiguration = configArg as [AnyHashable: Any]

                    if let setLogCallback = arguments["setLogCallback"] as? Bool,
                       setLogCallback {
                        consolePrint = { value in
                            self.channel.invokeMethod("logCallback", arguments: value)
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
            }
            result(nil)
        case "setSdkVerbosity":
            if let verbosityString = arguments["value"] as? String {
                let verbosity = LogLevel.parseFromFlutter(verbosityString)
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
                Datadog._internal._telemetry.debug(id: "datadog_flutter:\(message)", message: message)
                result(nil)
            } else {
                result(FlutterError.missingParameter(methodName: call.method))
            }
        case "telemetryError":
            if let message = arguments["message"] as? String {
                let stack = arguments["stack"] as? String
                let kind = arguments["kind"] as? String
                Datadog._internal._telemetry.error(id: "datadog_flutter:\(String(describing: kind)):\(message)",
                                                  message: message, kind: kind, stack: stack)
                result(nil)
            } else {
                result(FlutterError.missingParameter(methodName: call.method))
            }
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
        let ddConfiguration = configuration.toDdConfig()

        Datadog.initialize(appContext: Datadog.AppContext(),
                           trackingConsent: configuration.trackingConsent,
                           configuration: ddConfiguration)

        if let rumConfiguration = configuration.rumConfiguration {
            rum = DatadogRumPlugin.instance
            rum?.initialize(configuration: rumConfiguration)
        }
    }
}
