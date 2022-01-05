// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import Datadog

public class DatadogRumPlugin: NSObject, FlutterPlugin {
  let rumInstance: DDRUMMonitor?

  private lazy var rum: DDRUMMonitor = {
    return rumInstance ?? Global.rum
  }()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.rum", binaryMessenger: registrar.messenger())
    let instance = DatadogRumPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public init(rumInstance: DDRUMMonitor? = nil) {
    self.rumInstance = rumInstance

    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "DatadogSDK:InvalidOperation",
                          message: "No arguments in call to \(call.method).",
                          details: nil))
      return
    }

    switch call.method {
    case "startView":
      if let key = arguments["key"] as? String,
         let name = arguments["name"] as? String,
         let attributes = arguments["attributes"] as? [String: Any?] {
        let encodedAttributes = castFlutterAttributesToSwift(attributes)
        rum.startView(key: key, name: name, attributes: encodedAttributes)
      }
      result(nil)
    case "stopView":
      if let key = arguments["key"] as? String,
         let attributes = arguments["attributes"] as? [String: Any?] {
        let encodedAttributes = castFlutterAttributesToSwift(attributes)
        rum.stopView(key: key, attributes: encodedAttributes)
      }
      result(nil)
    case "addTiming":
      if let name = arguments["name"] as? String {
        rum.addTiming(name: name)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
