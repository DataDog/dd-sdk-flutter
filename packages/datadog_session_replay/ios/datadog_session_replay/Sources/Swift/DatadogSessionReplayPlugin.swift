// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Foundation
import Flutter
import UIKit

@objc(DatadogSessionReplayPlugin)
public class DatadogSessionReplayPlugin: NSObject, FlutterPlugin {
    private let messenger: AnyObject

    private init(messenger: AnyObject) {
        self.messenger = messenger
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger() as AnyObject
        let instance = DatadogSessionReplayPlugin(messenger: messenger)
        // The FFI `enable()` call cannot determine which engine invoked it, so per-engine
        // Dart→native lookups go through this method channel instead. Method channels route
        // to the plugin instance for their specific engine, giving us that engine's
        // messenger — used to resolve the engine's embedded slotId (see `resolveSlotId`).
        let channel = FlutterMethodChannel(
            name: "datadog_session_replay/engine",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "resolveSlotId" {
            // Called from Dart when isEmbedded = true (on first frame and whenever the view
            // re-attaches). Returns the slotId registered for this engine's messenger via
            // `FlutterViewController.enableDatadogSessionReplay()`, or `nil` if the host app
            // has not called it (i.e. Flutter is full-screen, not embedded, or the view is
            // not yet attached).
            result(FlutterSessionReplayManager.shared.slotId(for: messenger))
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
}
