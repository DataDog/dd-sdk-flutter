// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Testing
import Flutter
import UIKit

@_spi(Internal)
import DatadogInternal

@testable import datadog_session_replay

/// Tests the `registerEngine` method channel.
///
/// The FFI `enable()` call cannot tell which engine invoked it, so Dart pairs its bridge with its
/// engine over a method channel instead: channels route to the plugin instance registered for that
/// specific engine, which is how the plugin knows which messenger to pair the token with.
@Suite(.serialized)
@MainActor
class DatadogSessionReplayPluginTests {
    private let manager = FlutterSessionReplayManager()

    /// Retained for the whole test: the manager's registries and the bridge's `boundMessenger` are
    /// all weak, so locals would be released and take the engine's slot with them.
    private let messenger = FlutterBinaryMessengerMock()
    private let hostViewController = UIViewController()

    /// Calls `handle` and returns whatever the plugin passed to its `FlutterResult`.
    private func handle(
        _ plugin: DatadogSessionReplayPlugin,
        method: String,
        arguments: Any? = nil
    ) -> Any? {
        var result: Any?
        plugin.handle(FlutterMethodCall(methodName: method, arguments: arguments)) { result = $0 }
        return result
    }

    @Test
    func registerEngine_letsTheBridgeResolveThisEnginesSlot() throws {
        // Given — an embedded engine whose host registered its view controller. The bridge is
        // created over FFI and never sees a messenger, so until the handshake lands it has no way
        // to reach the slot its records must be stamped with.
        let core = PassthroughCoreMock()
        let engine = FlutterSessionReplay(manager: manager)
        try engine.enableOrThrow(with: .init(), in: core)
        engine.setEmbedded(true)
        manager.registerSlot(for: hostViewController, messenger: messenger)
        let expectedSlotId = try #require(manager.slotId(for: messenger))
        let plugin = DatadogSessionReplayPlugin(messenger: messenger, manager: manager)

        // When
        let result = handle(plugin, method: "registerEngine", arguments: engine.engineToken)
        engine.writeSegment(segment: #"{"records":[{"type":1}],"viewID":"view-id"}"#)

        // Then — the records reach the native recording carrying this engine's slot
        #expect(result == nil)
        let batches: [EmbeddedContentMessage.RecordBatch] = core.sentMessages.compactMap {
            guard case .embeddedContent(.records(let batch)) = $0 else {
                return nil
            }
            return batch
        }
        try #require(batches.count == 1)
        #expect(batches[0].slotID == expectedSlotId)
    }

    @Test
    func registerEngine_pairsTheBridgeWithThisEnginesMessenger() throws {
        // Given — a bridge created over FFI, which never sees a messenger
        var callsToEngine = 0
        let core = PassthroughCoreMock()
        let engine = FlutterSessionReplay(manager: manager)
        try engine.enableOrThrow(with: .init(onContextChanged: { _ in callsToEngine += 1 }), in: core)
        let plugin = DatadogSessionReplayPlugin(messenger: messenger, manager: manager)

        // When — Dart hands the plugin its bridge's token, then the engine detaches
        let result = handle(plugin, method: "registerEngine", arguments: engine.engineToken)
        manager.detach(messenger: messenger)
        manager.broadcastContext(.mockRandom())

        // Then — the pairing is what let detach find and release this engine's Dart callback
        #expect(result == nil)
        #expect(callsToEngine == 1)  // primed on enable, nothing after
    }

    @Test
    func registerEngine_withoutAToken_returnsAnError() {
        // Given
        let plugin = DatadogSessionReplayPlugin(messenger: FlutterBinaryMessengerMock(), manager: manager)

        // When
        let result = handle(plugin, method: "registerEngine", arguments: nil)

        // Then
        #expect((result as? FlutterError)?.code == "invalid_arguments")
    }

    @Test
    func handle_withAnUnknownMethod_returnsNotImplemented() {
        // Given
        let plugin = DatadogSessionReplayPlugin(messenger: FlutterBinaryMessengerMock(), manager: manager)

        // When
        let result = handle(plugin, method: "someUnimplementedMethod")

        // Then
        #expect((result as? NSObject) === FlutterMethodNotImplemented)
    }
} // extension SessionReplayTestContainer
