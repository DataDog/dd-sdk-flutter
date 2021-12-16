// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import Foundation
import DatadogSDKBridge

public class SwiftDatadogLogs: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.logs", binaryMessenger: registrar.messenger())
    let instance = SwiftDatadogLogs()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "DatadogSDK:InvalidOperation",
                          message: "No arguments in call to DdSdk.initialize.",
                          details: nil))
      return
    }

    let message = arguments["message"] as? NSString
    let context = arguments["context"] as? NSDictionary

    switch call.method {
    case "debug":
      if let message = message, let context = context {
        Bridge.getDdLogs().debug(message: message, context: context)
      }
      result(nil)

    case "info":
      if let message = message, let context = context {
        Bridge.getDdLogs().info(message: message, context: context)
      }
      result(nil)

    case "warn":
      if let message = message, let context = context {
        Bridge.getDdLogs().warn(message: message, context: context)
      }
      result(nil)

    case "error":
      if let message = message, let context = context {
        Bridge.getDdLogs().error(message: message, context: context)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
