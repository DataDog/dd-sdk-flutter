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

  private var logger: Logger?
  public var isInitialized: Bool { return logger != nil }

  override private init() {
    super.init()
  }

  func initialize(withLogger logger: Logger) {
    self.logger = logger
  }

  func initialize(configuration: DatadogFlutterConfiguration.LoggingConfiguration) {
    let builder = Logger.builder
      .sendNetworkInfo(configuration.sendNetworkInfo)
      .printLogsToConsole(configuration.printLogsToConsole)
      .bundleWithRUM(configuration.bundleWithRum)
      .bundleWithTrace(configuration.bundleWithTraces)
    logger = builder.build()
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(
        FlutterError.invalidOperation(message: "No arguments in call to \(call.method).")
      )
      return
    }
    guard let logger = logger else {
      result(
        FlutterError.invalidOperation(message: "Logger has not been initialized when calling \(call.method).")
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
