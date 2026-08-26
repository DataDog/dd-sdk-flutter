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

public class DatadogSessionReplayPlugin: NSObject, FlutterPlugin {
    private let messenger: AnyObject

    /// Injected so tests can drive termination through a fake center instead of posting the real,
    /// process-wide notification.
    private let notificationCenter: NotificationCenterProtocol

    internal init(
        messenger: AnyObject,
        notificationCenter: NotificationCenterProtocol = NotificationCenter.default
    ) {
        self.messenger = messenger
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
        registrar.publish(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "claimOwnership" {
            FlutterSessionReplay.claimOwnership(messenger: messenger)
            result(nil)
        } else {
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
        // Null out the context callback only if this engine is the registered owner.
        // Prevents a detaching secondary engine from clearing a live engine's callback,
        // which would cause DLRT_GetFfiCallbackMetadata crashes on the next context update.
        FlutterSessionReplay.detachFromEngine(messenger: messenger)
    }
}
