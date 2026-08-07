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

/// Tests the per-engine bridge.
///
/// Every test builds its own manager, so no state leaks between tests and nothing touches
/// `FlutterSessionReplayManager.shared`.
@Suite(.serialized)
@MainActor
class FlutterSessionReplayBridgeTests {
    /// A record batch the manager will accept: `sendToMessageBus(segment:slotId:)` requires
    /// non-empty `records` and a `viewID`.
    private static func segment(viewID: String = "view-id", recordCount: Int = 1) -> String {
        let records = (0..<recordCount).map { #"{"type":\#($0)}"# }.joined(separator: ",")
        return #"{"records":[\#(records)],"viewID":"\#(viewID)"}"#
    }

    private let core = PassthroughCoreMock()
    private let feature = FlutterSessionReplayFeatureMock()
    private let manager: FlutterSessionReplayManager
    private let bridge: FlutterSessionReplay

    /// Retained for the whole test: the manager's registries and the bridge's `boundMessenger` are
    /// all weak, so locals would be released and take the engine's slot with them.
    private let messenger = FlutterBinaryMessengerMock()
    private let hostViewController = UIViewController()

    init() {
        manager = FlutterSessionReplayManager(feature: feature)
        bridge = FlutterSessionReplay(manager: manager)
    }

    /// Enables the bridge against the mock core. The manager keeps the injected mock feature —
    /// `enableFeature` returns early when one already exists — but still retains the core, which
    /// is what the embedded path posts records to.
    private func enable(onContextChanged: ((FlutterRUMCoreContext?) -> Void)? = nil) throws {
        try bridge.enableOrThrow(with: .init(onContextChanged: onContextChanged), in: core)
    }

    /// Puts the bridge on the embedded path with a resolvable slot: the host registering its view
    /// controller, the `registerEngine` handshake, and Dart declaring `isEmbedded`. Returns the
    /// slot ID the records are expected to carry. Must be called after `enable()`, which is what
    /// puts the bridge in the registry `bind` looks it up in.
    @discardableResult
    private func embed() throws -> String {
        manager.registerSlot(for: hostViewController, messenger: messenger)
        manager.bind(engineToken: bridge.engineToken, to: messenger)
        bridge.setEmbedded(true)
        return try #require(manager.slotId(for: messenger))
    }

    private var recordBatches: [EmbeddedContentMessage.RecordBatch] {
        core.sentMessages.compactMap { message in
            guard case .embeddedContent(.records(let batch)) = message else {
                return nil
            }
            return batch
        }
    }

    // MARK: - Construction

    @Test
    func init_withoutAManager_usesTheProcessWideOne() {
        #expect(FlutterSessionReplay().manager === FlutterSessionReplayManager.shared)
    }

    // MARK: - Enabling

    @Test
    func enable_registersTheFeatureInCore() throws {
        // Given — a manager with no feature yet, unlike the injected-mock setup
        let manager = FlutterSessionReplayManager()
        let bridge = FlutterSessionReplay(manager: manager)

        // When
        try bridge.enableOrThrow(with: .init(), in: core)

        // Then
        #expect(core.get(feature: DefaultFlutterSessionReplayFeature.self) != nil)
    }

    @Test
    func enable_whenTheSDKIsNotInitialized_throws() {
        #expect(throws: ProgrammerError.self) {
            try bridge.enableOrThrow(with: .init(), in: NOPDatadogCore())
        }
    }

    @Test
    func enable_primesTheEngineWithTheCurrentContext() throws {
        // Given — the native RUM view is already active, as in a hybrid app
        let expectedContext: RUMCoreContext = .mockRandom()
        feature.currentContext = expectedContext

        // When
        var receivedContext: FlutterRUMCoreContext?
        try enable { receivedContext = $0 }

        // Then — the engine starts recording immediately instead of waiting for a context change
        #expect(receivedContext?.applicationID == expectedContext.applicationID)
        #expect(receivedContext?.sessionID == expectedContext.sessionID)
        #expect(receivedContext?.viewID == expectedContext.viewID)
    }

    @Test
    func enable_registersTheEngineForContextFanOut() throws {
        // Given
        var receivedContext: FlutterRUMCoreContext?
        try enable { receivedContext = $0 }

        // When — a later context change reaches the manager
        let expectedContext: RUMCoreContext = .mockRandom()
        manager.broadcastContext(expectedContext)

        // Then
        #expect(receivedContext?.viewID == expectedContext.viewID)
    }

    // MARK: - Segment routing

    @Test
    func writeSegment_beforeTheEmbeddingIsKnown_buffersInsteadOfGuessing() throws {
        // Given
        try enable()

        // When — Dart has not called `setEmbedded` yet
        bridge.writeSegment(segment: Self.segment())

        // Then — the records go nowhere rather than down the wrong path
        #expect(feature.writtenSegments.isEmpty)
        #expect(recordBatches.isEmpty)
    }

    @Test
    func setEmbedded_whenStandalone_flushesBufferedSegmentsToTheFeature() throws {
        // Given
        try enable()
        let first = Self.segment(viewID: "view-1")
        let second = Self.segment(viewID: "view-2")
        bridge.writeSegment(segment: first)
        bridge.writeSegment(segment: second)

        // When — Flutter is the host app
        bridge.setEmbedded(false)

        // Then — buffered segments replay in order
        #expect(feature.writtenSegments == [first, second])
        #expect(recordBatches.isEmpty)
    }

    @Test
    func setEmbedded_whenEmbedded_flushesBufferedSegmentsToTheMessageBus() throws {
        // Given
        try enable()
        bridge.writeSegment(segment: Self.segment(viewID: "view-1"))
        bridge.writeSegment(segment: Self.segment(viewID: "view-2"))

        // When
        let expectedSlotId = try embed()

        // Then
        #expect(feature.writtenSegments.isEmpty)
        #expect(recordBatches.map(\.viewID) == ["view-1", "view-2"])
        #expect(recordBatches.allSatisfy { $0.slotID == expectedSlotId })
    }

    @Test
    func writeSegment_whenStandalone_writesToTheFeature() throws {
        // Given
        try enable()
        bridge.setEmbedded(false)

        // When
        let segment = Self.segment()
        bridge.writeSegment(segment: segment)

        // Then
        #expect(feature.writtenSegments == [segment])
        #expect(recordBatches.isEmpty)
    }

    @Test
    func writeSegment_whenEmbedded_stampsTheRecordsWithTheSlotId() throws {
        // Given
        try enable()
        let expectedSlotId = try embed()

        // When
        bridge.writeSegment(segment: Self.segment(viewID: "view-id", recordCount: 3))

        // Then — the player needs the slot to composite these into the host's placeholder, and
        // RUM keys record counts off the *native* view ID the records were stamped with
        try #require(recordBatches.count == 1)
        #expect(recordBatches[0].slotID == expectedSlotId)
        #expect(recordBatches[0].viewID == "view-id")
        #expect(recordBatches[0].records.count == 3)
        #expect(feature.writtenSegments.isEmpty)
    }

    @Test
    func writeSegment_whenEmbeddedBeforeTheHostRegistersItsView_buffersUntilItDoes() throws {
        // Given — a pre-warmed engine: Dart declared `isEmbedded` and started recording before the
        // host called `dd.enableSessionReplay()`, so there is no slot to stamp records with
        try enable()
        bridge.setEmbedded(true)
        let first = Self.segment(viewID: "view-1")
        let second = Self.segment(viewID: "view-2")
        bridge.writeSegment(segment: first)
        bridge.writeSegment(segment: second)
        #expect(recordBatches.isEmpty)

        // When — the host presents the engine's view controller
        let expectedSlotId = try embed()
        bridge.writeSegment(segment: Self.segment(viewID: "view-3"))

        // Then — nothing was written to a slot the player has no placeholder for, and the buffered
        // segments replay in order once one exists
        #expect(recordBatches.map(\.viewID) == ["view-1", "view-2", "view-3"])
        #expect(recordBatches.allSatisfy { $0.slotID == expectedSlotId })
        #expect(feature.writtenSegments.isEmpty)
    }

    @Test
    func writeSegment_whenTheSlotNeverResolves_dropsTheOldestSegments() throws {
        // Given — a host that configured `isEmbedded: true` but never registered a view
        try enable()
        bridge.setEmbedded(true)
        let overflow = FlutterSessionReplay.maxPendingSegments + 5
        for index in 0..<overflow {
            bridge.writeSegment(segment: Self.segment(viewID: "view-\(index)"))
        }

        // When — a slot finally appears
        try embed()

        // Then — the buffer is capped, so an unresolvable engine cannot grow it without bound; what
        // survives is the most recent capture rather than a stale prefix
        #expect(recordBatches.count == FlutterSessionReplay.maxPendingSegments)
        #expect(recordBatches.first?.viewID == "view-\(overflow - FlutterSessionReplay.maxPendingSegments)")
        #expect(recordBatches.last?.viewID == "view-\(overflow - 1)")
    }

    // MARK: - Replay state publishing

    @Test
    func setHasReplay_whenStandalone_publishesToTheFeature() throws {
        // Given
        try enable()
        bridge.setEmbedded(false)

        // When
        let expectedValue: Bool = .mockRandom()
        bridge.setHasReplay(hasReplay: expectedValue)

        // Then
        #expect(feature.hasReplay == expectedValue)
    }

    @Test
    func setHasReplay_whenEmbedded_staysQuiet() throws {
        // Given
        try enable()
        bridge.setEmbedded(true)

        // When
        bridge.setHasReplay(hasReplay: true)

        // Then — the native SessionReplayFeature owns this core-context key when embedded;
        // publishing from here too would make the value depend on which side wrote last
        #expect(feature.hasReplay == nil)
    }

    @Test
    func setHasReplay_beforeTheEmbeddingIsKnown_staysQuiet() throws {
        // Given
        try enable()

        // When
        bridge.setHasReplay(hasReplay: true)

        // Then — publishing would be a guess, and guessing wrong corrupts the native value
        #expect(feature.hasReplay == nil)
    }

    @Test
    func setRecordCount_whenStandalone_publishesToTheFeature() throws {
        // Given
        try enable()
        bridge.setEmbedded(false)

        // When
        let viewId: String = .mockRandom()
        let count: Int = .mockRandom(min: 0, max: 1_000)
        bridge.setRecordCount(for: viewId, count: count)

        // Then
        #expect(feature.recordCount[viewId] == Int64(count))
    }

    @Test
    func setRecordCount_whenEmbedded_staysQuiet() throws {
        // Given
        try enable()
        bridge.setEmbedded(true)

        // When
        bridge.setRecordCount(for: .mockRandom(), count: 1)

        // Then — EmbeddedContentReceiver counts our records natively instead
        #expect(feature.recordCount.isEmpty)
    }

    // MARK: - Resources

    @Test
    func saveImageForProcessing_forwardsToTheResourceResolver() throws {
        // Given
        try enable()

        // When
        let key: Int = .mockRandom(min: 0, max: 1_000)
        let width: Int = .mockRandom(min: 1, max: 100)
        let height: Int = .mockRandom(min: 1, max: 100)
        let data = Data([1, 2, 3, 4])
        bridge.saveImageForProcessing(resourceKey: key, width: width, height: height, data: data)

        // Then
        let resolver = try #require(feature.resourceResolver as? ResourceResolverMock)
        try #require(resolver.trackedResources.count == 1)
        #expect(resolver.trackedResources[0].key == key)
        #expect(resolver.trackedResources[0].width == width)
        #expect(resolver.trackedResources[0].height == height)
        #expect(resolver.trackedResources[0].data == data)
    }

    @Test
    func resourceId_returnsTheIdentifierTheResolverMinted() throws {
        // Given
        try enable()
        let key: Int = .mockRandom(min: 0, max: 1_000)
        bridge.saveImageForProcessing(resourceKey: key, width: 1, height: 1, data: Data([1, 2, 3, 4]))

        // When
        let resourceId = bridge.resourceId(forKey: key)

        // Then — this is the value that goes into the image wireframe
        let resolver = try #require(feature.resourceResolver as? ResourceResolverMock)
        #expect(resourceId == resolver.trackedResources[0].resourceId)
    }

    @Test
    func resourceId_forAnUntrackedKey_isNil() throws {
        try enable()
        #expect(bridge.resourceId(forKey: 42) == nil)
    }
}
