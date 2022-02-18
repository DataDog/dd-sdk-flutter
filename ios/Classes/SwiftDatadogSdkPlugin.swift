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
  public private(set) var tracer: DatadogTracesPlugin?
  public private(set) var rum: DatadogRumPlugin?

  public init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "datadog_sdk_flutter", binaryMessenger: registrar.messenger())
    let instance = SwiftDatadogSdkPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)

    DatadogLogsPlugin.register(with: registrar)
    DatadogTracesPlugin.register(with: registrar)
    DatadogRumPlugin.register(with: registrar)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any] else {
      result(FlutterError(code: "DatadogSDK:InvalidOperation",
                          message: "No arguments in call to \(call.method)",
                          details: nil))
      return
    }

    switch call.method {
    case "initialize":
      let configArg = arguments["configuration"] as! [String: Any?]
      if let config = DatadogFlutterConfiguration(fromEncoded: configArg) {
        initialize(configuration: config)
      }
      result(nil)
    case "setSdkVerbosity":
      if let verbosityString = arguments["value"] as? String {
        let verbosity = LogLevel.parseFromFlutter(verbosityString)
        Datadog.verbosityLevel = verbosity
      }
      result(nil)
    case "setUserInfo":
      if let extraInfo = arguments["extraInfo"] as? [String: Any?] {
        let id = arguments["id"] as? String
        let name = arguments["name"] as? String
        let email = arguments["email"] as? String
        let encodedAttributes = castFlutterAttributesToSwift(extraInfo)
        Datadog.setUserInfo(id: id, name: name, email: email, extraInfo: encodedAttributes)
      }
      result(nil)
    case "setTrackingConsent":
      if let trackingConsentString = arguments["value"] as? String {
        let trackingConsent = TrackingConsent.parseFromFlutter(trackingConsentString)
        Datadog.set(trackingConsent: trackingConsent)
      }
      result(nil)
#if DD_SDK_COMPILED_FOR_TESTING
    case "flushAndDeinitialize":
      Datadog.flushAndDeinitialize()
      logs = nil
      tracer = nil
      rum = nil
      result(nil)
#endif
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  internal func initialize(configuration: DatadogFlutterConfiguration) {
    let ddConfiguration = SwiftDatadogSdkPlugin.buildConfiguration(from: configuration)

    Datadog.initialize(appContext: Datadog.AppContext(),
                       trackingConsent: configuration.trackingConsent,
                       configuration: ddConfiguration)

    if let loggingConfiguration = configuration.loggingConfiguration {
      logs = DatadogLogsPlugin.instance
      logs?.initialize(configuration: loggingConfiguration)
    }
    if let tracingConfiguration = configuration.tracingConfiguration {
      tracer = DatadogTracesPlugin.instance
      tracer?.initialize(configuration: tracingConfiguration)
    }
    if let rumConfiguration = configuration.rumConfiguration {
      rum = DatadogRumPlugin.instance
      rum?.initialize(configuration: rumConfiguration)
    }
  }

  internal static func buildConfiguration(from flutterConfig: DatadogFlutterConfiguration) -> Datadog.Configuration {
    let ddConfigBuilder: Datadog.Configuration.Builder
    if let rumConfig = flutterConfig.rumConfiguration {
      ddConfigBuilder = Datadog.Configuration.builderUsing(
        rumApplicationID: rumConfig.applicationId,
        clientToken: flutterConfig.clientToken,
        environment: flutterConfig.env
      )
        .set(rumSessionsSamplingRate: rumConfig.sampleRate)
    } else {
      ddConfigBuilder = Datadog.Configuration.builderUsing(
        clientToken: flutterConfig.clientToken,
        environment: flutterConfig.env
      )
    }

    if flutterConfig.nativeCrashReportingEnabled {
      _ = ddConfigBuilder.enableCrashReporting(using: DDCrashReportingPlugin())
    }

    if let site = flutterConfig.site {
      _ = ddConfigBuilder.set(endpoint: site)
    }

    if let batchSize = flutterConfig.batchSize {
      _ = ddConfigBuilder.set(batchSize: batchSize)
    }
    if let uploadFrequency = flutterConfig.uploadFrequency {
      _ = ddConfigBuilder.set(uploadFrequency: uploadFrequency)
    }

    if let customEndpoint = flutterConfig.customEndpoint,
       let customEndpointUrl = URL(string: customEndpoint) {
      _ = ddConfigBuilder
        .set(customLogsEndpoint: customEndpointUrl)
        .set(customTracesEndpoint: customEndpointUrl)
        .set(customRUMEndpoint: customEndpointUrl)
    }

    if let enableViewTracking = flutterConfig.additionalConfig["_dd.native_view_tracking"] as? Bool,
        enableViewTracking {
      _ = ddConfigBuilder.trackUIKitRUMViews()
    }

    if let serviceName = flutterConfig.additionalConfig["_dd.service_name"] as? String {
      _ = ddConfigBuilder.set(serviceName: serviceName)
    }

    if let threshold = flutterConfig.additionalConfig["_dd.long_task.threshold"] as? TimeInterval {
      // `_dd.long_task.threshold` attribute is in milliseconds
      _ = ddConfigBuilder.trackRUMLongTasks(threshold: threshold / 1_000)
    }
    _ = ddConfigBuilder.set(additionalConfiguration: flutterConfig.additionalConfig)

    return ddConfigBuilder.build()
  }
}
