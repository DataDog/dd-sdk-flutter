// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Foundation
import Flutter
import UIKit

public class DatadogSessionReplayPlugin: NSObject, FlutterPlugin {
    private let messenger: AnyObject

    private init(messenger: AnyObject) {
        self.messenger = messenger
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger() as AnyObject
        let instance = DatadogSessionReplayPlugin(messenger: messenger)
        // FFI plugins do not receive engine lifecycle events, so we cannot determine
        // which engine called enable() from within the FFI call itself. Instead, after
        // calling enable() via FFI, Dart fires a non-awaited 'claimOwnership' message
        // through this method channel. Because method channels route to the plugin
        // instance for their specific engine, we can reliably associate the enable()
        // call with this engine's messenger and set listenerOwner correctly.
        // See: https://github.com/flutter/flutter/issues/184124
        let channel = FlutterMethodChannel(
            name: "datadog_session_replay/engine",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "claimOwnership" {
            FlutterSessionReplay.claimOwnership(messenger: messenger)
            result(nil)
        } else if call.method == "resolveSlotId" {
            // Called once from Dart after the first frame when isEmbedded = true.
            // Returns the FlutterView.hash used as slotId, or nil if the view is not
            // yet attached (should not happen after the first frame).
            result(Self.resolveSlotId(from: messenger))
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    /// Returns the slot ID associated with a Flutter view's messenger.
    /// Returns the slotId registered for this engine's messenger via
    /// `FlutterViewController.enableDatadogSessionReplay()`, or `nil` if the
    /// host app has not called it (i.e. Flutter is full-screen, not embedded).
    private static func resolveSlotId(from messenger: AnyObject) -> String? {
        return FlutterSessionReplay.resolveSlotId(for: messenger)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        // Null out the context callback only if this engine is the registered owner.
        // Prevents a detaching secondary engine from clearing a live engine's callback,
        // which would cause DLRT_GetFfiCallbackMetadata crashes on the next context update.
        FlutterSessionReplay.detachFromEngine(messenger: registrar.messenger() as AnyObject)
    }
}
