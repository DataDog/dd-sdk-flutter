// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Testing
import Flutter
import UIKit

@testable import datadog_session_replay

/// Tests the `resolveSlotId` method channel.
///
/// The FFI `enable()` call cannot tell which engine invoked it, so Dart asks for its slot ID over
/// a method channel instead: channels route to the plugin instance registered for that specific
/// engine, which is how the plugin knows whose messenger to look up.
@Suite
class DatadogSessionReplayPluginTests {
    private let manager = FlutterSessionReplayManager()

    /// Registers a host view controller for `messenger` and returns the slot ID assigned to it.
    private func registerSlot(for messenger: FlutterBinaryMessengerMock) throws -> String {
        let viewController = UIViewController()
        _ = viewController.view  // load the view — an unloaded view gets no slot ID
        manager.registerSlot(for: viewController, messenger: messenger)
        return try #require(manager.slotId(for: messenger))
    }

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
    func resolveSlotId_forAnEmbeddedEngine_returnsItsSlotId() throws {
        // Given — the host called `enableDatadogSessionReplay()` for this engine
        let messenger = FlutterBinaryMessengerMock()
        let expectedSlotId = try registerSlot(for: messenger)
        let plugin = DatadogSessionReplayPlugin(messenger: messenger, manager: manager)

        // When
        let result = handle(plugin, method: "resolveSlotId")

        // Then
        #expect(result as? String == expectedSlotId)
    }

    @Test
    func resolveSlotId_whenTheHostNeverRegisteredThisEngine_isNil() {
        // Given — Flutter is full-screen rather than embedded
        let plugin = DatadogSessionReplayPlugin(messenger: FlutterBinaryMessengerMock(), manager: manager)

        // When
        let result = handle(plugin, method: "resolveSlotId")

        // Then — Dart reads this as "standalone" and writes records to the Flutter feature
        #expect(result == nil)
    }

    @Test
    func resolveSlotId_forAnotherEnginesMessenger_isNil() throws {
        // Given — engine A is embedded, engine B is not
        let messengerA = FlutterBinaryMessengerMock()
        _ = try registerSlot(for: messengerA)
        let messengerB = FlutterBinaryMessengerMock()
        let pluginB = DatadogSessionReplayPlugin(messenger: messengerB, manager: manager)

        // When
        let result = handle(pluginB, method: "resolveSlotId")

        // Then — engine B must not inherit engine A's slot, or their records would collide
        #expect(result == nil)
    }

    @Test
    func registerEngine_pairsTheBridgeWithThisEnginesMessenger() throws {
        // Given — a bridge created over FFI, which never sees a messenger
        var callsToEngine = 0
        let core = PassthroughCoreMock()
        let messenger = FlutterBinaryMessengerMock()
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
