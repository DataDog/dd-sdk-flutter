// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import Datadog

public class DatadogRumPlugin: NSObject, FlutterPlugin {
  public static let instance =  DatadogRumPlugin()
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.rum", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private var rumInstance: DDRUMMonitor?
  public var isInitialized: Bool { return rumInstance != nil }

  private override init() {
    super.init()
  }

  func initialize(configuration: DatadogFlutterConfiguration.RumConfiguration) {
    rumInstance = RUMMonitor.initialize()
    Global.rum = rumInstance!
  }

  public func initialize(withRum rum: DDRUMMonitor) {
    rumInstance = rum
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "DatadogSDK:InvalidOperation",
                          message: "No arguments in call to \(call.method).",
                          details: nil))
      return
    }
    guard let rum = rumInstance else {
      result(FlutterError(code: "DatadogSDK:InvalidOperation",
                         message: "RUM has not been initialized when calling \(call.method).",
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
    case "startResourceLoading":
      if let key = arguments["key"] as? String,
         let methodString = arguments["httpMethod"] as? String,
         let url = arguments["url"] as? String,
         let attributes = arguments["attributes"] as? [String: Any?] {
        let encodedAttributes = castFlutterAttributesToSwift(attributes)
        let method = RUMMethod.parseFromFlutter(methodString)
        rum.startResourceLoading(resourceKey: key, httpMethod: method, urlString: url, attributes: encodedAttributes)
      }
      result(nil)
    case "stopResourceLoading":
      if let key = arguments["key"] as? String,
         let kindString = arguments["kind"] as? String,
         let attributes = arguments["attributes"] as? [String: Any?] {
        let encodedAttributes = castFlutterAttributesToSwift(attributes)
        let kind = RUMResourceType.parseFromFlutter(kindString)

        let statusCode = arguments["statusCode"] as? NSNumber
        let size = arguments["size"] as? NSNumber

        rum.stopResourceLoading(resourceKey: key, statusCode: statusCode?.intValue,
                                kind: kind, size: size?.int64Value, attributes: encodedAttributes)
      }
      result(nil)
    case "stopResourceLoadingWithError":
      if let key = arguments["key"] as? String,
         let message = arguments["message"] as? String,
         let attributes = arguments["attributes"] as? [String: Any?] {
        let encodedAttributes = castFlutterAttributesToSwift(attributes)
        rum.stopResourceLoadingWithError(resourceKey: key, errorMessage: message, response: nil,
                                         attributes: encodedAttributes)
      }
      result(nil)
    case "addError":
      if let message = arguments["message"] as? String,
         let sourceString = arguments["source"] as? String,
         let attributes = arguments["attributes"] as? [String: Any?] {
        let encodedAttributes = castFlutterAttributesToSwift(attributes)
        let source = RUMErrorSource.parseFromFlutter(sourceString)
        let stackTrace = arguments["stackTrace"] as? String

        rum.addError(message: message, source: source, stack: stackTrace, attributes: encodedAttributes,
                     file: nil, line: nil)
      }
      result(nil)
    case "addUserAction":
      if let typeString = arguments["type"] as? String,
         let name = arguments["name"] as? String,
         let attributes = arguments["attributes"] as? [String: Any?] {
        let type = RUMUserActionType.parseFromFlutter(typeString)
        let encodedAttributes = castFlutterAttributesToSwift(attributes)
        rum.addUserAction(type: type, name: name, attributes: encodedAttributes)
      }
      result(nil)
    case "startUserAction":
      if let typeString = arguments["type"] as? String,
         let name = arguments["name"] as? String,
         let attributes = arguments["attributes"] as? [String: Any?] {
        let type = RUMUserActionType.parseFromFlutter(typeString)
        let encodedAttributes = castFlutterAttributesToSwift(attributes)
        rum.startUserAction(type: type, name: name, attributes: encodedAttributes)
      }
      result(nil)
    case "stopUserAction":
      if let typeString = arguments["type"] as? String,
         let name = arguments["name"] as? String,
         let attributes = arguments["attributes"] as? [String: Any?] {
        let type = RUMUserActionType.parseFromFlutter(typeString)
        let encodedAttributes = castFlutterAttributesToSwift(attributes)
        rum.stopUserAction(type: type, name: name, attributes: encodedAttributes)
      }
      result(nil)
    case "addAttribute":
      if let key = arguments["key"] as? String,
         let value = arguments["value"] {
        let encodedValue = castAnyToEncodable(value)
        rum.addAttribute(forKey: key, value: encodedValue)
      }
      result(nil)
    case "removeAttribute":
      if let key = arguments["key"] as? String {
        rum.removeAttribute(forKey: key)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

public extension RUMResourceType {
  // swiftlint:disable:next cyclomatic_complexity
  static func parseFromFlutter(_ value: String) -> RUMResourceType {
    switch value {
    case "RumResourceType.document": return .document
    case "RumResourceType.image": return .image
    case "RumResourceType.xhr": return .xhr
    case "RumResourceType.beacon": return .beacon
    case "RumResourceType.css": return .css
    case "RumResourceType.fetch": return .fetch
    case "RumResourceType.font": return .font
    case "RumResourceType.js": return .js
    case "RumResourceType.media": return .media
    case "RumResourceType.native": return .native
    default: return .other
    }
  }
}

public extension RUMMethod {
  static func parseFromFlutter(_ value: String) -> RUMMethod {
    switch value {
    case "RumHttpMethod.get": return .get
    case "RumHttpMethod.post": return .post
    case "RumHttpMethod.head": return .head
    case "RumHttpMethod.put": return .put
    case "RumHttpMethod.delete": return .delete
    case "RumHttpMethod.patch": return .patch
    default: return .get
    }
  }
}

public extension RUMUserActionType {
  static func parseFromFlutter(_ value: String) -> RUMUserActionType {
    switch value {
    case "RumUserActionType.tap": return .tap
    case "RumUserActionType.scroll": return .scroll
    case "RumUserActionType.swipe": return .swipe
    default: return .custom
    }
  }
}

public extension RUMErrorSource {
  static func parseFromFlutter(_ value: String) -> RUMErrorSource {
    switch value {
    case "RumErrorSource.source": return .source
    case "RumErrorSource.network": return .network
    case "RumErrorSource.webview": return .webview
    case "RumErrorSource.console": return .console
    case "RumErrorSource.custom": return .custom
    default: return .custom
    }
  }
}
