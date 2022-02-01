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

  func initialize(configuration: DatadogFlutterConfiguration.TracingConfiguration) {
    tracer = Tracer.initialize(configuration: Tracer.Configuration(
      serviceName: nil,
      sendNetworkInfo: configuration.sendNetworkInfo,
      bundleWithRUM: configuration.bundleWithRum,
      globalTags: nil
    ))
    Global.sharedTracer = tracer!
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "DatadogSDK:InvalidOperation",
                          message: "No arguments in call to \(call.method).",
                          details: nil))
      return
    }
    guard let tracer = tracer else {
      result(FlutterError(code: "DatadogSDK:InvalidOperation",
                         message: "Tracer has not been initialized when calling \(call.method).",
                         details: nil))
      return
    }

    let calledSpan = findCallingSpan(arguments)

    switch call.method {
    case "startRootSpan":
      let operationName = arguments["operationName"] as! String

      var tags: [String: Encodable]?
      if let flutterTags = arguments["tags"] as? [String: Any] {
        tags = castFlutterAttributesToSwift(flutterTags)
      }

      var startTime: Date?
      if let startTimeMs = arguments["startTime"] as? NSNumber {
        startTime = Date(timeIntervalSince1970: startTimeMs.doubleValue / 1_000)
      }

      let span = tracer.startRootSpan(
        operationName: operationName,
        tags: tags,
        startTime: startTime)

      let spanHandle = storeSpan(span)
      result(spanHandle)

    case "startSpan":
      let operationName = arguments["operationName"] as! String

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

      let span = tracer.startSpan(
        operationName: operationName,
        childOf: parentSpan?.context,
        tags: tags,
        startTime: startTime)

      let spanHandle = storeSpan(span)
      result(spanHandle)

    case "getTracePropagationHeaders":
      var headers: [String: String] = [:]

      if let calledSpan = calledSpan {

        let writer = HTTPHeadersWriter()
        tracer.inject(spanContext: calledSpan.span.context, writer: writer)
        headers = writer.tracePropagationHTTPHeaders
      }
      result(headers)

    case "span.setActive":
      if let calledSpan = calledSpan {
        calledSpan.span.setActive()
      }
      result(nil)

    case "span.setError":
      if let calledSpan = calledSpan,
         let kind = arguments["kind"] as? String,
         let message = arguments["message"] as? String {
        if let stackTrace = arguments["stackTrace"] as? String {
          calledSpan.span.setError(kind: kind, message: message, stack: stackTrace)
        } else {
          calledSpan.span.setError(kind: kind, message: message)
        }
      }
      result(nil)

    case "span.setTag":
      if let calledSpan = calledSpan,
         let key = arguments["key"] as? String,
         let value = arguments["value"] {
        let encoded = castAnyToEncodable(value)
        calledSpan.span.setTag(key: key, value: encoded)
      }
      result(nil)

    case "span.setBaggageItem":
      if let calledSpan = calledSpan,
         let key = arguments["key"] as? String,
         let value = arguments["value"] as? String {
        calledSpan.span.setBaggageItem(key: key, value: value)
      }
      result(nil)

    case "span.log":
      if let fields = arguments["fields"] as? [String: Any?] {
        let encoded = castFlutterAttributesToSwift(fields)
        calledSpan?.span.log(fields: encoded)
      }
      result(nil)

    case "span.finish":
      if let calledSpan = calledSpan {
        calledSpan.span.finish()
        spanRegistry[calledSpan.handle] = nil
      }
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
