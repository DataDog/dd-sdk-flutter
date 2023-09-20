// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Flutter
import UIKit
import Datadog
import webview_flutter_wkwebview

public class DatadogWebViewTrackingPlugin: NSObject, FlutterPlugin {
    let channel: FlutterMethodChannel

    public init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "datadog_webview_tracking", binaryMessenger: registrar.messenger())
        let instance = DatadogWebViewTrackingPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let arguments = call.arguments as? [String: Any] else {
            result(
                FlutterError(code: "DatadogSdk:InvalidOperation",
                             message: "No arguments in call to \(call.method)",
                             details: nil)
            )
            return
        }

        if call.method == "initWebView" {
            if let number = arguments["webViewIdentifier"] as? NSNumber,
               let allowedHosts = arguments["allowedHosts"] as? [String] {
                let webViewIdentifier = number.intValue

                // swiftlint:disable:next todo
                // TODO: Add to app scenario, search for a FlutterViewController to get the
                // registry
                if let pluginRegistry = UIApplication.shared.delegate as? FlutterPluginRegistry,
                   let webview = FWFWebViewFlutterWKWebViewExternalAPI.webView(
                        forIdentifier: webViewIdentifier,
                        with: pluginRegistry) {
                    webview.configuration.userContentController.trackDatadogEvents(in: Set(allowedHosts))
                }
                result(nil)
            } else {
                result(
                    FlutterError(code: "DatadogSdk:ContractViolation",
                                 message: "Missing parameter in call to \(call.method)",
                                 details: nil)
                )
            }
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}
