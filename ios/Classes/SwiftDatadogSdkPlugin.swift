// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import Flutter
import UIKit
import DatadogSDKBridge

extension DdSdkConfiguration {
    static func deccode(value: [String: Any?]) -> DdSdkConfiguration {
        return DdSdkConfiguration(
            clientToken: value["clientToken"] as! NSString,
            env: value["env"] as! NSString,
            applicationId: value["applicationId"] as? NSString,
            nativeCrashReportEnabled: (value["nativeCrashReportEnabled"] as? NSNumber)?.boolValue,
            sampleRate: (value["sampleRate"] as? NSNumber)?.doubleValue,
            site: value["site"] as? NSString,
            trackingConsent: value["trackingConsent"] as? NSString,
            additionalConfig: value["additionalConfig"] as? NSDictionary
        )
    }
}

public class SwiftDatadogSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "datadog_sdk_flutter", binaryMessenger: registrar.messenger())
    let instance = SwiftDatadogSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "DdSdk.initialize":
        guard let arguments = call.arguments as? [String: Any] else {
          result(FlutterError(code: "DatadogSDK:InvalidOperation",
                              message: "No arguments in call to DdSdk.initialize.",
                              details: nil))
          return
        }

        let configuration = DdSdkConfiguration.deccode(
            value: arguments["configuration"] as! [String: Any?]
        )
        Bridge.getDdSdk().initialize(configuration: configuration)
        result(nil)
    case "DdLogs.debug":
        let arguments = call.arguments as! [String: Any]

        let message = arguments["message"] as! NSString
        let context = arguments["context"] as! NSDictionary

        Bridge.getDdLogs().debug(message: message, context: context)
        result(nil)

    case "DdLogs.info":
        let arguments = call.arguments as! [String: Any]

        let message = arguments["message"] as! NSString
        let context = arguments["context"] as! NSDictionary

        Bridge.getDdLogs().debug(message: message, context: context)
        result(nil)

    case "DdLogs.warn":
        let arguments = call.arguments as! [String: Any]

        let message = arguments["message"] as! NSString
        let context = arguments["context"] as! NSDictionary

        Bridge.getDdLogs().debug(message: message, context: context)
        result(nil)

    case "DdLogs.error":
        let arguments = call.arguments as! [String: Any]

        let message = arguments["message"] as! NSString
        let context = arguments["context"] as! NSDictionary

        Bridge.getDdLogs().debug(message: message, context: context)
        result(nil)

    default:
        result(FlutterMethodNotImplemented)
    }
  }
}
