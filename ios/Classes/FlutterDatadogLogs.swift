// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import Foundation
import Datadog
import DatadogSDKBridge

public class FlutterDatadogLogs: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.logs", binaryMessenger: registrar.messenger())
    let instance = FlutterDatadogLogs()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private lazy var logger: Logger = {
    let builder = Logger.builder
      .sendNetworkInfo(true)
      .printLogsToConsole(true)
    return builder.build()
  }()

  public func initialize() {
    let builder = Logger.builder
      .sendNetworkInfo(true)
      .printLogsToConsole(true)
    self.logger = builder.build()
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "DatadogSDK:InvalidOperation",
                          message: "No arguments in call to DdSdk.initialize.",
                          details: nil))
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
      }
      result(nil)

    case "info":
      if let message = message {
        logger.info(message, error: nil, attributes: attributes)
      }
      result(nil)

    case "warn":
      if let message = message {
        logger.warn(message, error: nil, attributes: attributes)
      }
      result(nil)

    case "error":
      if let message = message {
        logger.error(message, error: nil, attributes: attributes)
      }
      result(nil)

    case "addAttribute":
      if let key = arguments["key"] as? String,
         let value = arguments["value"] {
        logger.addAttribute(forKey: key, value: DdFlutterEncodable(value))
      }
      result(nil)

    case "removeAttribute":
      if let key = arguments["key"] as? String {
        logger.removeAttribute(forKey: key)
      }
      result(nil)

    case "addTag":
      if let tag = arguments["tag"] as? String {
        if let keyValue = arguments["value"] as? String {
          logger.addTag(withKey: tag, value: keyValue)
        } else {
          logger.add(tag: tag)
        }
      }
      result(nil)

    case "removeTag":
      if let tag = arguments["tag"] as? String {
        logger.remove(tag: tag)
      }
      result(nil)

    case "removeTagWithKey":
      if let key = arguments["key"] as? String {
        logger.removeTag(withKey: key)
      }
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
