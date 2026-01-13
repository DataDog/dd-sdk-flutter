// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Flutter
import UIKit
import DatadogCore
import DatadogInternal
import DatadogWebViewTracking
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
                let webViewIdentifier = number.int64Value

                if let registry = getPluginRegistry(),
                   // FWFWebviewFlutterWKWebViewExternalAPI does a force cast, which can crash,
                   // so to try to avoid that, we're going to check to make sure the plugin is there first.
                   let _ = registry.valuePublished(byPlugin: "WebViewFlutterPlugin") as? WebViewFlutterPlugin,
                   let webview = FWFWebViewFlutterWKWebViewExternalAPI.webView(
                        forIdentifier: webViewIdentifier,
                        withPluginRegistry: registry) {
                    WebViewTracking.enable(webView: webview, hosts: Set(allowedHosts))
                } else {
                    Datadog._internal.telemetry.error(
                        id: "webview_tracking_init_failed",
                        message: "Failed to initialie WebViewTracking because a WebViewFlutterPlugin instance was not found",
                        kind: "DependencyFailure",
                        stack: nil
                    )
                }
                result(nil)
            } else {
                consolePrint(
                    "⚠️ Could not find WebViewFlutterPlugin to enable Datadog tracking. This may be because of a change in Flutter. " +
                    "Please report this issue to Datadog along with the version of flutter_webview and Flutter you are using.",
                    .warn)
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

    private func getPluginRegistry() -> FlutterPluginRegistry? {
        // swiftlint:disable:next todo
        // TODO: Add to app scenario, search for a FlutterViewController to get the
        // registry
        // Note, in Flutter 3.38, registrars expose `viewController` which will be the
        // correct way to get the plugin registry. To be compatibile with <= 3.37 and 3.38+,
        // we're going to first try to se if the RootViewController is a plugin registry (3.38+),
        // and if not, fall back to the delegate (<= 3.37).
        let delegate = UIApplication.shared.delegate as? FlutterAppDelegate
        if let rootViewController = delegate?.window?.rootViewController,
           let pluginRegistry = rootViewController as? FlutterPluginRegistry {
            return pluginRegistry
        } else if let delegate = UIApplication.shared.delegate as? FlutterPluginRegistry {
            return delegate
        }
        return nil
    }
}
