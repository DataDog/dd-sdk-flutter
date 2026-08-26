// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Testing
import Flutter
@testable import datadog_session_replay

/// Tests the `DatadogSessionReplayPlugin` engine-lifecycle methods.
///
/// The plugin uses a method channel to establish ownership after `enable()` is called via FFI,
/// because FFI plugins do not receive engine lifecycle events (Flutter issue #184124).
/// We exercise the ownership flow via the underlying static API since creating a real
/// `FlutterPluginRegistrar` requires a running engine.
extension SessionReplayTestContainer {
@Suite
class DatadogSessionReplayPluginTests {
    init() { FlutterSessionReplay.shutdown() }
    deinit { FlutterSessionReplay.shutdown() }

    @Test
    func detach_withOwningEngine_nullsCallback() {
        // Given — simulate enable() + claimOwnership arriving for engine A
        let messengerA = NSObject()
        FlutterSessionReplay.contextCallback = { _ in }
        FlutterSessionReplay.claimOwnership(messenger: messengerA)

        // When — simulate detachFromEngine(for:) for engine A
        FlutterSessionReplay.detachFromEngine(messenger: messengerA)

        // Then
        #expect(FlutterSessionReplay.contextCallback == nil)
        #expect(FlutterSessionReplay.listenerOwner == nil)
    }

    @Test
    func detach_withNonOwningEngine_preservesCallback() {
        // Given — engine A owns the callback; engine B attaches but never enables
        let messengerA = NSObject()
        let messengerB = NSObject()
        FlutterSessionReplay.contextCallback = { _ in }
        FlutterSessionReplay.claimOwnership(messenger: messengerA)

        // When — engine B detaches (non-owner)
        FlutterSessionReplay.detachFromEngine(messenger: messengerB)

        // Then — engine A's callback is preserved
        #expect(FlutterSessionReplay.contextCallback != nil)
        #expect(FlutterSessionReplay.listenerOwner === messengerA)
    }

    /// Flutter never calls `detachFromEngine(for:)` on termination — it resets the engine's shell and
    /// leaves the engine object, and therefore the plugin registry, alone (flutter/flutter#126671) —
    /// so the plugin observes `UIApplication.willTerminateNotification` itself. Otherwise the Dart
    /// context callback outlives the isolate that shell owned.
    ///
    /// Posts to an injected `NotificationCenterMock` instead of the real, process-wide center: this
    /// exercises the actual observer registration (name, selector) rather than calling a test-only
    /// escape hatch, without the risk of tearing down another suite's engine.
    @Test
    func engineWillTearDown_releasesThisEnginesDartCallback() {
        // Given — engine A owns the callback
        let messengerA = NSObject()
        FlutterSessionReplay.contextCallback = { _ in }
        FlutterSessionReplay.claimOwnership(messenger: messengerA)
        let notificationCenter = NotificationCenterMock()
        let plugin = DatadogSessionReplayPlugin(messenger: messengerA, notificationCenter: notificationCenter)

        // When — the app terminates without ever detaching the plugin
        withExtendedLifetime(plugin) {
            notificationCenter.post(name: UIApplication.willTerminateNotification)
        }

        // Then
        #expect(FlutterSessionReplay.contextCallback == nil)
        #expect(FlutterSessionReplay.listenerOwner == nil)
    }
}
} // extension SessionReplayTestContainer
