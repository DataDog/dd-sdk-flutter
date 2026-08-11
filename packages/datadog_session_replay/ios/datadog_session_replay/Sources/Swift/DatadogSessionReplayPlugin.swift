// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Foundation
import Flutter
import UIKit

@objc(DatadogSessionReplayPlugin)
public class DatadogSessionReplayPlugin: NSObject, FlutterPlugin {
    private let messenger: AnyObject

    /// The coordinator holding the engine and slot-ID registries. Injected so tests can
    /// substitute it.
    private let manager: FlutterSessionReplayManager

    internal init(messenger: AnyObject, manager: FlutterSessionReplayManager = .shared) {
        self.messenger = messenger
        self.manager = manager
        super.init()
        observeEngineTeardown()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let messenger = registrar.messenger() as AnyObject
        let instance = DatadogSessionReplayPlugin(messenger: messenger)
        // The FFI `enable()` call cannot determine which engine invoked it, so per-engine
        // Dart→native calls go through this method channel instead. Method channels route to
        // the plugin instance for their specific engine, giving us that engine's messenger —
        // which is what `registerEngine` pairs with the engine's bridge.
        let channel = FlutterMethodChannel(
            name: "datadog_session_replay/engine",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.publish(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "registerEngine":
            // Called from Dart right after `enable()`, carrying the token of the bridge that FFI
            // call created. Pairing it with this engine's messenger is both what lets
            // `detachFromEngine(for:)` find the right bridge to tear down, and what gives the
            // bridge the messenger it resolves slot IDs through on every segment write.
            guard let engineToken = call.arguments as? String else {
                result(FlutterError(
                    code: "invalid_arguments",
                    message: "registerEngine expects the engine token as a String",
                    details: nil
                ))
                return
            }
            manager.bind(engineToken: engineToken, to: messenger)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Covers teardown path `detachFromEngine(for:)` cannot see: app termination.
    ///
    /// Every other way an engine goes away ends in `-[FlutterEngine dealloc]`, which is the sole
    /// caller of `detachFromEngineForRegistrar:` — closing a scene, or a host releasing an engine,
    /// both land there. Termination does not: `-[FlutterViewController applicationWillTerminate:]`
    /// resets the engine's shell via `-appOrSceneWillTerminate` → `-destroyContext` while the engine
    /// object itself stays alive, so no plugin is ever notified (flutter/flutter#126671). Our Dart
    /// context callback would then outlive the isolate that shell owned and trap in
    /// `DLRT_GetFfiCallbackMetadata`.
    private func observeEngineTeardown() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(engineWillTearDown),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    /// Internal rather than private so tests can drive it without posting the real notification,
    /// which every plugin instance in the process observes — including those of suites running in
    /// parallel.
    @objc
    internal func engineWillTearDown() {
        _onDetach()
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        _onDetach()
    }

    private func _onDetach() {
        // Release this engine's Dart context callback before its isolate goes away —
        // invoking it afterwards traps in `DLRT_GetFfiCallbackMetadata` on force close.
        // Keyed by messenger, so a detaching secondary engine cannot clear a live one's.
        manager.detach(messenger: messenger)
    }
}
