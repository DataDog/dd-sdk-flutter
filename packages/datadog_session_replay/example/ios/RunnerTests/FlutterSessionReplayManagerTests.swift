// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Testing
import Flutter
import UIKit

// `sessionReplaySlotID` is exposed as SPI by `DatadogInternal`.
@_spi(Internal)
import DatadogInternal

@testable import datadog_session_replay

/// Tests the process-wide coordinator: the shared feature, context fan-out across engines, the
/// host slot-ID registry, and the two message-bus paths (records and resources).
@Suite
class FlutterSessionReplayManagerTests {
    private let core = PassthroughCoreMock()
    private let feature = FlutterSessionReplayFeatureMock()
    private let manager: FlutterSessionReplayManager

    init() {
        manager = FlutterSessionReplayManager(feature: feature)
    }

    /// A host view controller with a loaded view, as the native recorder would see it.
    private func hostViewController() -> UIViewController {
        let viewController = UIViewController()
        _ = viewController.view
        return viewController
    }

    /// Puts the manager in the embedded state and returns the messenger it was registered under.
    @discardableResult
    private func embed() -> FlutterBinaryMessengerMock {
        let messenger = FlutterBinaryMessengerMock()
        manager.registerSlot(for: hostViewController(), messenger: messenger)
        return messenger
    }

    private var recordBatches: [EmbeddedContentMessage.RecordBatch] {
        core.sentMessages.compactMap { message in
            guard case .embeddedContent(.records(let batch)) = message else {
                return nil
            }
            return batch
        }
    }

    private var resources: [EmbeddedContentMessage.Resource] {
        core.sentMessages.compactMap { message in
            guard case .embeddedContent(.resource(let resource)) = message else {
                return nil
            }
            return resource
        }
    }

    // MARK: - Feature registration

    @Test
    func enableFeature_registersOneFeatureForEveryEngine() throws {
        // Given — a manager with no feature yet
        let manager = FlutterSessionReplayManager()

        // When — two engines enable, as in a hybrid app with an embedded panel and a full-screen route
        try manager.enableFeature(in: core, customEndpoint: nil)
        let firstFeature = manager.feature
        try manager.enableFeature(in: core, customEndpoint: nil)

        // Then — the second engine reuses the feature instead of registering a duplicate
        #expect(manager.feature as AnyObject === firstFeature as AnyObject)
        #expect(core.registeredFeatures.filter { $0 is DefaultFlutterSessionReplayFeature }.count == 1)
    }

    // MARK: - Context fan-out

    @Test
    func broadcastContext_reachesEveryRegisteredEngine() throws {
        // Given — two engines, both enabled against the same manager
        var contextA: FlutterRUMCoreContext?
        var contextB: FlutterRUMCoreContext?
        let engineA = FlutterSessionReplay(manager: manager)
        let engineB = FlutterSessionReplay(manager: manager)
        try engineA.enableOrThrow(with: .init(onContextChanged: { contextA = $0 }), in: core)
        try engineB.enableOrThrow(with: .init(onContextChanged: { contextB = $0 }), in: core)

        // When
        let expectedContext: RUMCoreContext = .mockRandom()
        manager.broadcastContext(expectedContext)

        // Then — not just the engine that enabled last
        #expect(contextA?.viewID == expectedContext.viewID)
        #expect(contextB?.viewID == expectedContext.viewID)
    }

    @Test
    func broadcastContext_afterAnEngineIsReleased_skipsIt() throws {
        // Given — engine B is released after enabling, as on engine detach
        var contextA: FlutterRUMCoreContext?
        let engineA = FlutterSessionReplay(manager: manager)
        try engineA.enableOrThrow(with: .init(onContextChanged: { contextA = $0 }), in: core)

        var callsToB = 0
        do {
            let engineB = FlutterSessionReplay(manager: manager)
            try engineB.enableOrThrow(with: .init(onContextChanged: { _ in callsToB += 1 }), in: core)
            #expect(callsToB == 1)  // primed on enable
        }

        // When
        let expectedContext: RUMCoreContext = .mockRandom()
        manager.broadcastContext(expectedContext)

        // Then — the weak registry dropped B, so this never calls into a destroyed Dart isolate
        #expect(contextA?.viewID == expectedContext.viewID)
        #expect(callsToB == 1)
    }

    @Test
    func broadcastContext_withNoContext_forwardsNil() throws {
        // Given
        var received: FlutterRUMCoreContext?
        var callCount = 0
        let engine = FlutterSessionReplay(manager: manager)
        feature.currentContext = .mockRandom()
        try engine.enableOrThrow(with: .init(onContextChanged: {
            received = $0
            callCount += 1
        }), in: core)

        // When — RUM has no active view
        manager.broadcastContext(nil)

        // Then
        #expect(callCount == 2)
        #expect(received == nil)
    }

    @Test
    func primeContext_deliversToThatEngineOnly() throws {
        // Given — engine A is already recording; engine B enables later
        var callsToA = 0
        let engineA = FlutterSessionReplay(manager: manager)
        try engineA.enableOrThrow(with: .init(onContextChanged: { _ in callsToA += 1 }), in: core)
        let callsToAAfterEnable = callsToA

        // When
        var contextB: FlutterRUMCoreContext?
        let engineB = FlutterSessionReplay(manager: manager)
        feature.currentContext = .mockRandom()
        try engineB.enableOrThrow(with: .init(onContextChanged: { contextB = $0 }), in: core)

        // Then — priming is not a broadcast: A is not re-notified
        #expect(contextB?.viewID == feature.currentContext?.viewID)
        #expect(callsToA == callsToAAfterEnable)
    }

    // MARK: - Slot IDs

    @Test
    func registerSlot_assignsASlotIdToTheHostView() {
        // Given
        let viewController = hostViewController()

        // When
        manager.registerSlot(for: viewController, messenger: FlutterBinaryMessengerMock())

        // Then — the native recorder only emits the `embedded_view` placeholder for views that
        // already carry an ID, so it must be assigned before the host is first snapshotted
        #expect(viewController.view.dd.sessionReplaySlotID != nil)
    }

    @Test
    func slotId_returnsTheIdAssignedToTheEnginesHostView() {
        // Given
        let messenger = FlutterBinaryMessengerMock()
        let viewController = hostViewController()
        manager.registerSlot(for: viewController, messenger: messenger)

        // When
        let slotId = manager.slotId(for: messenger)

        // Then
        #expect(slotId != nil)
        #expect(slotId == viewController.view.dd.sessionReplaySlotID)
    }

    @Test
    func slotId_isStableAcrossRepeatedQueries() {
        // Given — Dart re-resolves on every `didChangeMetrics`
        let messenger = embed()

        // When
        let first = manager.slotId(for: messenger)
        let second = manager.slotId(for: messenger)

        // Then — a new ID per query would orphan the records already stamped with the old one
        #expect(first != nil)
        #expect(first == second)
    }

    @Test
    func registerSlot_calledTwice_keepsTheExistingSlotId() {
        // Given
        let messenger = FlutterBinaryMessengerMock()
        let viewController = hostViewController()
        manager.registerSlot(for: viewController, messenger: messenger)
        let firstSlotId = manager.slotId(for: messenger)

        // When — the host calls `enableDatadogSessionReplay()` again
        manager.registerSlot(for: viewController, messenger: messenger)

        // Then
        #expect(manager.slotId(for: messenger) == firstSlotId)
    }

    @Test
    func slotId_whenTheFlutterViewWasRecreated_assignsAFreshId() {
        // Given — a pre-warmed engine reused across open/close gets a new `FlutterView`
        let messenger = FlutterBinaryMessengerMock()
        let viewController = hostViewController()
        manager.registerSlot(for: viewController, messenger: messenger)
        let firstSlotId = manager.slotId(for: messenger)

        // When
        viewController.view = UIView()

        // Then — the ID lives on the view, so the new view gets its own rather than reusing a
        // stale one the recorder would no longer emit a placeholder for
        let secondSlotId = manager.slotId(for: messenger)
        #expect(secondSlotId != nil)
        #expect(secondSlotId != firstSlotId)
    }

    @Test
    func slotId_forAnUnregisteredMessenger_isNil() {
        #expect(manager.slotId(for: FlutterBinaryMessengerMock()) == nil)
    }

    @Test
    func slotId_whenTheViewIsNotLoadedYet_isNil() {
        // Given — a view controller whose view has not been loaded
        let messenger = FlutterBinaryMessengerMock()
        manager.registerSlot(for: UIViewController(), messenger: messenger)

        // Then — Dart retries on the next `didChangeMetrics`
        #expect(manager.slotId(for: messenger) == nil)
    }

    @Test
    func slotId_unwrapsAMessengerRelayToItsEngine() {
        // Given — `registrar.messenger()` and `engine.binaryMessenger` are different relays
        // wrapping the same engine messenger
        let engineMessenger = FlutterBinaryMessengerMock()
        let relayUsedToRegister = FlutterBinaryMessengerRelayMock(parent: engineMessenger)
        let relayUsedToQuery = FlutterBinaryMessengerRelayMock(parent: engineMessenger)
        manager.registerSlot(for: hostViewController(), messenger: relayUsedToRegister)

        // When
        let slotId = manager.slotId(for: relayUsedToQuery)

        // Then — both relays resolve to the same registry key
        #expect(slotId != nil)
        #expect(slotId == manager.slotId(for: relayUsedToRegister))
    }

    // MARK: - Records over the message bus

    @Test
    func sendToMessageBus_postsTheRecordsToTheNativeRecording() throws {
        // Given
        try manager.enableFeature(in: core, customEndpoint: nil)

        // When
        let segment = #"{"records":[{"type":1},{"type":2}],"viewID":"view-id"}"#
        manager.sendToMessageBus(segment: segment, slotId: "slot-id")

        // Then
        try #require(recordBatches.count == 1)
        #expect(recordBatches[0].records.count == 2)
        #expect(recordBatches[0].slotID == "slot-id")
        #expect(recordBatches[0].viewID == "view-id")
    }

    @Test(arguments: [
        #"not json at all"#,
        #"{"records":[{"type":1}]}"#,                    // no viewID
        #"{"viewID":"view-id"}"#,                        // no records
        #"{"records":[],"viewID":"view-id"}"#,           // empty records
        #"{"records":"not-an-array","viewID":"v"}"#
    ])
    func sendToMessageBus_withAnUnusableSegment_postsNothing(segment: String) throws {
        // Given
        try manager.enableFeature(in: core, customEndpoint: nil)

        // When
        manager.sendToMessageBus(segment: segment, slotId: "slot-id")

        // Then — a malformed batch would be unplayable, so it is dropped rather than forwarded
        #expect(recordBatches.isEmpty)
    }

    // MARK: - Resources over the message bus

    @Test
    func sendToMessageBus_whenEmbedded_postsTheResourceAndClaimsIt() throws {
        // Given
        try manager.enableFeature(in: core, customEndpoint: nil)
        embed()

        // When
        let data = Data([1, 2, 3])
        let claimed = manager.sendToMessageBus(
            resourceWithIdentifier: "identifier",
            data: data,
            mimeType: "image/png"
        )

        // Then — routed to the native writer, whose dedup is shared with the host and persisted
        #expect(claimed)
        try #require(resources.count == 1)
        #expect(resources[0].identifier == "identifier")
        #expect(resources[0].data == data)
        #expect(resources[0].mimeType == "image/png")
    }

    @Test
    func sendToMessageBus_whenStandalone_declinesTheResource() throws {
        // Given — no host ever registered a slot, so Flutter is not embedded
        try manager.enableFeature(in: core, customEndpoint: nil)

        // When
        let claimed = manager.sendToMessageBus(
            resourceWithIdentifier: "identifier",
            data: Data([1, 2, 3]),
            mimeType: "image/png"
        )

        // Then — declining sends it to the Flutter `ResourcesFeature` instead
        #expect(!claimed)
        #expect(resources.isEmpty)
    }

    @Test
    func sendToMessageBus_beforeAnyEngineEnabled_declinesTheResource() {
        // Given — embedded, but no core retained yet
        embed()

        // When
        let claimed = manager.sendToMessageBus(
            resourceWithIdentifier: "identifier",
            data: Data([1, 2, 3]),
            mimeType: "image/png"
        )

        // Then
        #expect(!claimed)
    }
}
