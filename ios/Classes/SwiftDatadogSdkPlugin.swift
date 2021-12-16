// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import Flutter
import UIKit
import Datadog
import DatadogSDKBridge

extension DdSdkConfiguration {
  static func decode(value: [String: Any?]) -> DdSdkConfiguration {
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
      guard let arguments = call.arguments as? [String:Any] else {
        result(FlutterError(code: "DatadogSDK:InvalidOperation", message: "No arguments in call to DdSdk.initialize.", details: nil))
        return
      }

      let configArg = arguments["configuration"] as! [String: Any?]
      let bridgeConfiguration = DdSdkConfiguration.decode(value: configArg)
      let configurationBuilder = buildConfiguration(configuration: bridgeConfiguration)

      if let customEndpointArg = configArg["customEndpoint"] as? String {
        if let customEndpoint = URL(string: customEndpointArg) {
          _ = configurationBuilder
            .set(customLogsEndpoint: customEndpoint)
            .set(customTracesEndpoint: customEndpoint)
            .set(customRUMEndpoint: customEndpoint)
        } else {
          print("Error parsing custom endpoint url: \(String(describing: configArg["customEndpoint"])). Defaulting to regular endpoint")
        }
      }

      Datadog.initialize(appContext: Datadog.AppContext(),
                         trackingConsent: .granted,
                         configuration: configurationBuilder.build())

      Global.rum = RUMMonitor.initialize()

      result(nil)
    case "DdLogs.debug":
      let arguments = call.arguments as! [String:Any];

      let message = arguments["message"] as! NSString
      let context = arguments["context"] as! NSDictionary

      Bridge.getDdLogs().debug(message: message, context: context)
      result(nil)

    case "DdLogs.info":
      let arguments = call.arguments as! [String:Any];

      let message = arguments["message"] as! NSString
      let context = arguments["context"] as! NSDictionary

      Bridge.getDdLogs().info(message: message, context: context)
      result(nil)

    case "DdLogs.warn":
      let arguments = call.arguments as! [String:Any];

      let message = arguments["message"] as! NSString
      let context = arguments["context"] as! NSDictionary

      Bridge.getDdLogs().warn(message: message, context: context)
      result(nil)

    case "DdLogs.error":
      let arguments = call.arguments as! [String:Any];

      let message = arguments["message"] as! NSString
      let context = arguments["context"] as! NSDictionary

      Bridge.getDdLogs().error(message: message, context: context)
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Copied from dd-brdige-ios/DdSdkImplementation
  func buildConfiguration(configuration: DdSdkConfiguration) -> Datadog.Configuration.Builder {
    let ddConfigBuilder: Datadog.Configuration.Builder
    if let rumAppID = configuration.applicationId as String? {
      ddConfigBuilder = Datadog.Configuration.builderUsing(
        rumApplicationID: rumAppID,
        clientToken: configuration.clientToken as String,
        environment: configuration.env as String
      )
        .set(rumSessionsSamplingRate: Float(configuration.sampleRate ?? 100.0))
    } else {
      ddConfigBuilder = Datadog.Configuration.builderUsing(
        clientToken: configuration.clientToken as String,
        environment: configuration.env as String
      )
    }

    switch configuration.site?.lowercased ?? "us" {
    case "us1", "us":
      _ = ddConfigBuilder.set(endpoint: .us1)
    case "eu1", "eu":
      _ = ddConfigBuilder.set(endpoint: .eu1)
    case "us3":
      _ = ddConfigBuilder.set(endpoint: .us3)
    case "us5":
      _ = ddConfigBuilder.set(endpoint: .us5)
    case "us1_fed", "gov":
      _ = ddConfigBuilder.set(endpoint: .us1_fed)
    default:
      _ = ddConfigBuilder.set(endpoint: .us1)
    }

    let additionalConfig = configuration.additionalConfig

    if let additionalConfiguration = additionalConfig as? [String: Any] {
      _ = ddConfigBuilder.set(additionalConfiguration: additionalConfiguration)
    }

    if let enableViewTracking = additionalConfig?["_dd.native_view_tracking"] as? Bool, enableViewTracking {
      _ = ddConfigBuilder.trackUIKitRUMViews()
    }

    if let serviceName = additionalConfig?["_dd.service_name"] as? String {
      _ = ddConfigBuilder.set(serviceName: serviceName)
    }

    if let threshold = additionalConfig?["_dd.long_task.threshold"] as? TimeInterval {
      // `_dd.long_task.threshold` attribute is in milliseconds
      _ = ddConfigBuilder.trackRUMLongTasks(threshold: threshold / 1_000)
    }

    // TODO: Proxy configuration
//    if let proxyConfiguration = buildProxyConfiguration(config: additionalConfig) {
//      _ = ddConfigBuilder.set(proxyConfiguration: proxyConfiguration)
//    }

    return ddConfigBuilder
  }
}

