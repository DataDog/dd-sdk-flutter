// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Testing
import DatadogInternal

@testable import datadog_session_replay

struct ResourcesWriterTest {

    @Test
    func write_WritesContentsToCore() throws {
        // Given
        var context: DatadogContext = .mockRandom()
        let rumApplicationId: String = .mockRandom()
        let rumContext = RUMCoreContext.mockWith(applicationID: rumApplicationId)
        context.set(additionalContext: rumContext)

        let mockCore = PassthroughCoreMock(context: context)
        let writer = ResourcesWriter(scope: mockCore)

        // When
        let id: String = .mockRandom()
        let data = Data([1, 2, 3])
        let mimeType: String = .mockRandom()
        writer.write(withIdentifier: id, data: data, mimeType: mimeType)

        // Then
        let events = mockCore.events
        try #require(events.count == 1)
        let resourceEvent = events[0] as! EnrichedResource
        #expect(resourceEvent.identifier == id)
        #expect(resourceEvent.data == data)
        #expect(resourceEvent.mimeType == mimeType)
        #expect(resourceEvent.context.type == "resource")
        #expect(resourceEvent.context.application.id == rumApplicationId)
    }

    @Test
    func write_WithDuplicateIdentifier_DoesNotWritesContents() throws {
        // Given
        var context: DatadogContext = .mockRandom()
        let rumApplicationId: String = .mockRandom()
        let rumContext = RUMCoreContext.mockWith(applicationID: rumApplicationId)
        context.set(additionalContext: rumContext)

        let mockCore = PassthroughCoreMock(context: context)
        let writer = ResourcesWriter(scope: mockCore)

        let id: String = .mockRandom()
        let data = Data([1, 2, 3])
        let mimeType: String = .mockRandom()
        writer.write(withIdentifier: id, data: data, mimeType: mimeType)

        // When a duplicate write occurs
        writer.write(withIdentifier: id, data: data, mimeType: mimeType)

        // We still only have the original write
        let events = mockCore.events
        #expect(events.count == 1)
    }

    @Test
    func write_WithDifferentIdentifiers_WritesToCore() throws {
        // Given
        var context: DatadogContext = .mockRandom()
        let rumApplicationId: String = .mockRandom()
        let rumContext = RUMCoreContext.mockWith(applicationID: rumApplicationId)
        context.set(additionalContext: rumContext)

        let mockCore = PassthroughCoreMock(context: context)
        let writer = ResourcesWriter(scope: mockCore)

        let idA: String = .mockRandom()
        let data = Data([1, 2, 3])
        let mimeType: String = .mockRandom()
        writer.write(withIdentifier: idA, data: data, mimeType: mimeType)

        // When a duplicate write occurs
        let idB: String = .mockRandom()
        writer.write(withIdentifier: idB, data: data, mimeType: mimeType)

        // We still only have the original write
        let events = mockCore.events
        try #require(events.count == 2)
        let resourceEvent = events[1] as! EnrichedResource
        #expect(resourceEvent.identifier == idB)
        #expect(resourceEvent.data == data)
        #expect(resourceEvent.mimeType == mimeType)
        #expect(resourceEvent.context.type == "resource")
        #expect(resourceEvent.context.application.id == rumApplicationId)
    }

    @Test
    func write_WithIdentifierKnownFromPreviousSession_DoesNotWriteToCore() throws {
        // Given
        let sharedDataStore = DataStoreMock()
        let firstSessionCore = PassthroughCoreMock(context: .mockRandom(), dataStore: sharedDataStore)
        let firstSessionWriter = ResourcesWriter(scope: firstSessionCore)

        let id: String = .mockRandom()
        let data = Data([1, 2, 3])
        let mimeType: String = .mockRandom()
        firstSessionWriter.write(withIdentifier: id, data: data, mimeType: mimeType)
        try #require(firstSessionCore.events.count == 1)

        // When a new writer instance (simulating a new app session) shares the same data store
        let secondSessionCore = PassthroughCoreMock(context: .mockRandom(), dataStore: sharedDataStore)
        let secondSessionWriter = ResourcesWriter(scope: secondSessionCore)
        secondSessionWriter.write(withIdentifier: id, data: data, mimeType: mimeType)

        // Then it does not write the already-known identifier again
        #expect(secondSessionCore.events.isEmpty)
    }

    @Test
    func write_WithStaleStoreCreation_ResetsKnownIdentifiers() throws {
        // Given
        let id: String = .mockRandom()
        let staleStoreCreation = Date().timeIntervalSince1970 - TimeInterval(31).days
        let sharedDataStore = DataStoreMock(
            storage: [
                ResourcesWriter.Constants.storeCreationKey: .value(staleStoreCreation.asData(), ResourcesWriter.Constants.currentStoreVersion),
                ResourcesWriter.Constants.knownResourcesKey: .value(Set([id]).asData(JSONEncoder())!, ResourcesWriter.Constants.currentStoreVersion)
            ]
        )
        let core = PassthroughCoreMock(context: .mockRandom(), dataStore: sharedDataStore)
        let writer = ResourcesWriter(scope: core)

        // When
        let data = Data([1, 2, 3])
        let mimeType: String = .mockRandom()
        writer.write(withIdentifier: id, data: data, mimeType: mimeType)

        // Then the stale store was reset, so the previously-known identifier is written again
        #expect(core.events.count == 1)
    }

    @Test
    func write_WithRecentStoreCreation_DoesNotResetKnownIdentifiers() throws {
        // Given
        let id: String = .mockRandom()
        let recentStoreCreation = Date().timeIntervalSince1970
        let sharedDataStore = DataStoreMock(
            storage: [
                ResourcesWriter.Constants.storeCreationKey: .value(recentStoreCreation.asData(), ResourcesWriter.Constants.currentStoreVersion),
                ResourcesWriter.Constants.knownResourcesKey: .value(Set([id]).asData(JSONEncoder())!, ResourcesWriter.Constants.currentStoreVersion)
            ]
        )
        let core = PassthroughCoreMock(context: .mockRandom(), dataStore: sharedDataStore)
        let writer = ResourcesWriter(scope: core)

        // When
        let data = Data([1, 2, 3])
        let mimeType: String = .mockRandom()
        writer.write(withIdentifier: id, data: data, mimeType: mimeType)

        // Then the identifier was seeded from the data store, so it's not written again
        #expect(core.events.isEmpty)
    }
}
