// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Testing

@testable import datadog_session_replay

struct RoutedResourcesWriterTest {
    /// Records what the native sink was offered, and answers whether it took it.
    private final class SinkSpy {
        private let accepts: Bool
        var offers: [ResourcesWritingMock.WriteRequest] = []

        init(accepts: Bool) {
            self.accepts = accepts
        }

        func sink(identifier: String, data: Data, mimeType: String) -> Bool {
            offers.append(.init(identifier: identifier, data: data, mimeType: mimeType))
            return accepts
        }
    }

    @Test
    func write_WhenNativeAcceptsIt_DoesNotWriteToStandaloneWriter() throws {
        // Given — the embedded case: the native Session Replay takes the resource.
        let standaloneWriter = ResourcesWritingMock()
        let spy = SinkSpy(accepts: true)
        let writer = RoutedResourcesWriter(standaloneWriter: standaloneWriter, sendToNative: spy.sink)

        // When
        let data = Data([1, 2, 3])
        writer.write(withIdentifier: "identifier", data: data, mimeType: "image/png")

        // Then
        try #require(spy.offers.count == 1)
        #expect(spy.offers[0].identifier == "identifier")
        #expect(spy.offers[0].data == data)
        #expect(spy.offers[0].mimeType == "image/png")
        #expect(standaloneWriter.writeRequests.isEmpty)
    }

    @Test
    func write_WhenNativeRefusesIt_WritesToStandaloneWriter() throws {
        // Given — the standalone case: there is no native Session Replay to take it.
        let standaloneWriter = ResourcesWritingMock()
        let spy = SinkSpy(accepts: false)
        let writer = RoutedResourcesWriter(standaloneWriter: standaloneWriter, sendToNative: spy.sink)

        // When
        let data = Data([1, 2, 3])
        writer.write(withIdentifier: "identifier", data: data, mimeType: "image/png")

        // Then
        #expect(spy.offers.count == 1)
        try #require(standaloneWriter.writeRequests.count == 1)
        #expect(standaloneWriter.writeRequests[0].identifier == "identifier")
        #expect(standaloneWriter.writeRequests[0].data == data)
        #expect(standaloneWriter.writeRequests[0].mimeType == "image/png")
    }

    @Test
    func write_RoutesEachResourceIndependently() throws {
        // Given
        let standaloneWriter = ResourcesWritingMock()
        let spy = SinkSpy(accepts: false)
        let writer = RoutedResourcesWriter(standaloneWriter: standaloneWriter, sendToNative: spy.sink)

        // When — the routed writer does no deduping of its own: that is the destination
        // writer's job (persisted natively, in memory in the Flutter feature).
        writer.write(withIdentifier: "identifier", data: Data([1]), mimeType: "image/png")
        writer.write(withIdentifier: "identifier", data: Data([1]), mimeType: "image/png")

        // Then
        #expect(spy.offers.count == 2)
        #expect(standaloneWriter.writeRequests.count == 2)
    }

    @Test
    func resolveResource_WhenNativeAcceptsIt_StillReturnsTheResourceIdentifier() throws {
        // Given — the identifier goes into the image wireframe, so it must be returned
        // regardless of which pipeline the bytes took.
        let standaloneWriter = ResourcesWritingMock()
        let spy = SinkSpy(accepts: true)
        let resolver = DefaultResourceResolver(
            writer: RoutedResourcesWriter(standaloneWriter: standaloneWriter, sendToNative: spy.sink)
        )
        resolver.addResource(withKey: 1000, width: 25, height: 25, data: Data(repeating: 0, count: 25 * 25 * 4))

        // When
        let resourceId = resolver.resolveResource(withKey: 1000)

        // Then
        #expect(resourceId == "1919fe07a6f92e35f50fd2e42e0dd921")
        try #require(spy.offers.count == 1)
        #expect(spy.offers[0].identifier == resourceId)
        #expect(standaloneWriter.writeRequests.isEmpty)
    }
}
