// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Foundation
import Flutter
import UIKit

/// Thin abstraction over `NotificationCenter` so tests can inject a fake that never broadcasts
/// process-wide, instead of every test posting the real `UIApplication.willTerminateNotification`
/// (which every live plugin instance in the process would observe, including other suites' engines).
protocol NotificationCenterProtocol {
    func addObserver(_ observer: Any, selector: Selector, name: NSNotification.Name?, object: Any?)
    func removeObserver(_ observer: Any)
}

extension NotificationCenter: NotificationCenterProtocol {}

@objc(DatadogSessionReplayPlugin)
public class DatadogSessionReplayPlugin: NSObject, FlutterPlugin {
    private let messenger: AnyObject

    /// The coordinator holding the engine and slot-ID registries. Injected so tests can
    /// substitute it.
    private let manager: FlutterSessionReplayManager

    /// Injected so tests can drive termination through a fake center instead of posting the real,
    /// process-wide notification.
    private let notificationCenter: NotificationCenterProtocol

    internal init(
        messenger: AnyObject,
        manager: FlutterSessionReplayManager = .shared,
        notificationCenter: NotificationCenterProtocol = NotificationCenter.default
    ) {
        self.messenger = messenger
        self.manager = manager
        self.notificationCenter = notificationCenter
        super.init()
        observeEngineTeardown()
    }

    deinit {
        notificationCenter.removeObserver(self)
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
        notificationCenter.addObserver(
            self,
            selector: #selector(engineWillTearDown),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc
    private func engineWillTearDown() {
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
