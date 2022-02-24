// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Foundation
import Datadog

internal protocol DateFormatterType {
  func string(from date: Date) -> String
  func date(from string: String) -> Date?
}

extension ISO8601DateFormatter: DateFormatterType {}
extension DateFormatter: DateFormatterType {}

public class DatadogTracesPlugin: NSObject, FlutterPlugin {
  public static let instance = DatadogTracesPlugin()
  public static func register(with register: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "datadog_sdk_flutter.traces", binaryMessenger: register.messenger())
    register.addMethodCallDelegate(instance, channel: channel)
  }

  private var nextSpanId: Int64 = 1
  private var spanRegistry: [Int64: OTSpan] = [:]

  public private(set) var tracer: OTTracer?
  public var isInitialized: Bool { return tracer != nil }

  private override init() {
    super.init()
  }

  func initialize(withTracer tracer: OTTracer) {
    self.tracer = tracer
  }

  func initialize(configuration: DatadogFlutterConfiguration.TracingConfiguration) {
    tracer = Tracer.initialize(configuration: Tracer.Configuration(
      serviceName: nil,
      sendNetworkInfo: configuration.sendNetworkInfo,
      bundleWithRUM: configuration.bundleWithRum,
      globalTags: nil
    ))
    Global.sharedTracer = tracer!
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(
        FlutterError.invalidOperation(message: "No arguments in call to \(call.method).")
      )
      return
    }
    guard let tracer = tracer else {
      result(
        FlutterError.invalidOperation(message: "Tracer has not been initialized when calling \(call.method).")
      )
      return
    }

    if call.method.starts(with: "span.") {
      callSpanMethod(method: call.method, arguments: arguments, result: result)
      return
    }

    switch call.method {
    case "startRootSpan":
      createSpan(arguments: arguments, isRootSpan: true, result: result)

    case "startSpan":
      createSpan(arguments: arguments, isRootSpan: false, result: result)

    case "getTracePropagationHeaders":
      var headers: [String: String] = [:]

      if let calledSpan = findCallingSpan(arguments) {
        let writer = HTTPHeadersWriter()
        tracer.inject(spanContext: calledSpan.span.context, writer: writer)
        headers = writer.tracePropagationHTTPHeaders
      }
      result(headers)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func createSpan(arguments: [String: Any], isRootSpan: Bool, result: @escaping FlutterResult) {
    guard let tracer = tracer else {
      return
    }

    guard let operationName = arguments["operationName"] as? String else {
      result(
        FlutterError.missingParameter(methodName: isRootSpan ? "startRootSpan" : "startSpan")
      )
      return
    }

    var tags: [String: Encodable]?
    if let flutterTags = arguments["tags"] as? [String: Any] {
      tags = castFlutterAttributesToSwift(flutterTags)
    }

    var startTime: Date?
    if let startTimeMs = arguments["startTime"] as? NSNumber {
      startTime = Date(timeIntervalSince1970: startTimeMs.doubleValue / 1_000)
    }

    var parentSpan: OTSpan?
    if let parentSpanId = (arguments["parentSpan"] as? NSNumber)?.int64Value {
      parentSpan = spanRegistry[parentSpanId]
    }

    let span = isRootSpan
      ? tracer.startRootSpan(
          operationName: operationName,
          tags: tags,
          startTime: startTime)
      : tracer.startSpan(
          operationName: operationName,
          childOf: parentSpan?.context,
          tags: tags,
          startTime: startTime)

	if let resourceName = arguments["resourceName"] as? String {
      span.setTag(key: DDTags.resource, value: resourceName)
    }

    let spanHandle = storeSpan(span)
    result(spanHandle)
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private func callSpanMethod(method: String, arguments: [String: Any], result: @escaping FlutterResult) {
    guard let calledSpan = findCallingSpan(arguments) else {
      result(nil)
      return
    }

    switch method {
    case "span.setActive":
      calledSpan.span.setActive()
      result(nil)

    case "span.setError":
      if let kind = arguments["kind"] as? String,
         let message = arguments["message"] as? String {
        if let stackTrace = arguments["stackTrace"] as? String {
          calledSpan.span.setError(kind: kind, message: message, stack: stackTrace)
        } else {
          calledSpan.span.setError(kind: kind, message: message)
        }
        result(nil)
      } else {
        result(
          FlutterError.missingParameter(methodName: method)
        )
      }

    case "span.setTag":
      if let key = arguments["key"] as? String,
         let value = arguments["value"] {
        let encoded = castAnyToEncodable(value)
        calledSpan.span.setTag(key: key, value: encoded)
        result(nil)
      } else {
        result(
          FlutterError.missingParameter(methodName: method)
        )
      }

    case "span.setBaggageItem":
      if let key = arguments["key"] as? String,
         let value = arguments["value"] as? String {
        calledSpan.span.setBaggageItem(key: key, value: value)
        result(nil)
      } else {
        result(
          FlutterError.missingParameter(methodName: method)
        )
      }

    case "span.log":
      if let fields = arguments["fields"] as? [String: Any?] {
        let encoded = castFlutterAttributesToSwift(fields)
        calledSpan.span.log(fields: encoded)
        result(nil)
      } else {
        result(
          FlutterError.missingParameter(methodName: method)
        )
      }

    case "span.finish":
      calledSpan.span.finish()
      spanRegistry[calledSpan.handle] = nil
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func findCallingSpan(_ arguments: [String: Any]) -> (span: OTSpan, handle: Int64)? {
    if let spanHandle = arguments["spanHandle"] as? NSNumber {
      let spanId = spanHandle.int64Value
      if let span = spanRegistry[spanId] {
        return (span: span, handle: spanId)
      }
    }
    return nil
  }

  private func storeSpan(_ span: OTSpan) -> Int64 {
    let spanId = nextSpanId
    nextSpanId += 1
    spanRegistry[spanId] = span
    return spanId
  }
}
