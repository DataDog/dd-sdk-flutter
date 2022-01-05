// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import Flutter
import UIKit
import Datadog
import DatadogSDKBridge

public class SwiftDatadogSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "datadog_sdk_flutter", binaryMessenger: registrar.messenger())
    let instance = SwiftDatadogSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    DatadogLogsPlugin.register(with: registrar)
    DatadogTracesPlugin.register(with: registrar)
    DatadogRumPlugin.register(with: registrar)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "DatadogSDK:InvalidOperation",
                            message: "No arguments in call to DdSdk.initialize.",
                            details: nil))
        return
      }

      let configArg = arguments["configuration"] as! [String: Any?]
      let configuration = SwiftDatadogSdkPlugin.buildConfiguration(from: configArg)
      let trackingConsent = TrackingConsent.parseFromFlutter(configArg["trackingConsent"] as! String)

      Datadog.initialize(appContext: Datadog.AppContext(),
                         trackingConsent: trackingConsent,
                         configuration: configuration)

      Global.rum = RUMMonitor.initialize()
      Global.sharedTracer = Tracer.initialize(configuration: Tracer.Configuration())

      Datadog.verbosityLevel = .debug

      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public static func buildConfiguration(from encodedConfig: [String: Any?]) -> Datadog.Configuration {
    let clientToken = encodedConfig["clientToken"] as! String
    let env = encodedConfig["env"] as! String

    let ddConfigBuilder: Datadog.Configuration.Builder
    if let rumAppId = encodedConfig["applicationId"] as? String {
      let sampleRate = (encodedConfig["sampleRate"] as? NSNumber)?.floatValue ?? 100.0
      ddConfigBuilder = Datadog.Configuration.builderUsing(
        rumApplicationID: rumAppId,
        clientToken: clientToken,
        environment: env
      )
        .set(rumSessionsSamplingRate: sampleRate)
    } else {
      ddConfigBuilder = Datadog.Configuration.builderUsing(
        clientToken: clientToken,
        environment: env
      )
    }

    if let site = encodedConfig["site"] as? String {
      _ = ddConfigBuilder.set(endpoint: .parseFromFlutter(site))
    }
    if let batchSize = encodedConfig["batchSize"] as? String {
      _ = ddConfigBuilder.set(batchSize: .parseFromFlutter(batchSize))
    }
    if let uploadFrequency = encodedConfig["uploadFrequency"] as? String {
      _ = ddConfigBuilder.set(uploadFrequency: .parseFromFlutter(uploadFrequency))
    }
    if let customEndpoint = encodedConfig["customEndpoint"] as? String {
      if let customEndpointUrl = URL(string: customEndpoint) {
        _ = ddConfigBuilder
          .set(customLogsEndpoint: customEndpointUrl)
          .set(customTracesEndpoint: customEndpointUrl)
          .set(customRUMEndpoint: customEndpointUrl)
      }
    }

    if let additionalConfiguration = encodedConfig["additionalConfig"] as? [String: Any] {
      _ = ddConfigBuilder.set(additionalConfiguration: additionalConfiguration)

      if let enableViewTracking = additionalConfiguration["_dd.native_view_tracking"] as? Bool, enableViewTracking {
        _ = ddConfigBuilder.trackUIKitRUMViews()
      }

      if let serviceName = additionalConfiguration["_dd.service_name"] as? String {
        _ = ddConfigBuilder.set(serviceName: serviceName)
      }

      if let threshold = additionalConfiguration["_dd.long_task.threshold"] as? TimeInterval {
        // `_dd.long_task.threshold` attribute is in milliseconds
        _ = ddConfigBuilder.trackRUMLongTasks(threshold: threshold / 1_000)
      }
    }

    return ddConfigBuilder.build()
  }
}

// MARK: - Flutter enum parsing extensions

public extension TrackingConsent {
  static func parseFromFlutter(_ value: String) -> Self {
    switch value {
    case "TrackingConsent.granted": return .granted
    case "TrackingConsent.notGranted": return .notGranted
    case "TrackingConsent.pending": return .pending
    default: return .pending
    }
  }
}

public extension Datadog.Configuration.BatchSize {
  static func parseFromFlutter(_ value: String) -> Self {
    switch value {
    case "BatchSize.small": return .small
    case "BatchSize.medium": return .medium
    case "BatchSize.large": return .large
    default: return .medium
    }
  }
}

public extension Datadog.Configuration.UploadFrequency {
  static func parseFromFlutter(_ value: String) -> Self {
    switch value {
    case "UploadFrequency.frequent": return .frequent
    case "UploadFrequency.average": return .average
    case "UploadFrequency.rare": return .rare
    default: return .average
    }
  }
}

public extension Datadog.Configuration.DatadogEndpoint {
  static func parseFromFlutter(_ value: String) -> Self {
    switch value {
    case "DatadogSite.us1": return .us1
    case "DatadogSite.us3": return .us3
    case "DatadogSite.us5": return .us5
    case "DatadogSite.eu1": return .eu1
    case "DatadogSite.us1Fed": return .us1_fed
    default: return .us1
    }
  }
}
