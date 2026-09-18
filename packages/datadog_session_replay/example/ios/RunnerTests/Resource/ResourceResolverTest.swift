// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import Testing

@testable import datadog_session_replay

@Suite(.serialized)
class ResourceResolverTest {
    let mockWriter: ResourcesWritingMock = .init()

    @Test
    func resolveResource_WithUnknownResource_ReturnsNil() {
        // Given
        let resolver = DefaultResourceResolver(writer: mockWriter)

        // When
        let result = resolver.resolveResource(withKey: 1000)

        // Then
        #expect(result == nil)
    }

    @Test
    func resolveResource_WithKnownResource_ReturnsHash() {
        // Given
        let resolver = DefaultResourceResolver(writer: mockWriter)

        // When
        let image = createMockImage(width: 25, height: 25)
        resolver.addResource(withKey: 1000, width: 25, height: 25, data: image)

        let result = resolver.resolveResource(withKey: 1000)

        // Then
        // This is the correct MD5 hash of an empty 25x25 image
        let expectedHash = "1919fe07a6f92e35f50fd2e42e0dd921"
        #expect(result == expectedHash)
    }

    @Test
    func resolveResource_WithSameImage_ReturnsSameHash() {
        // Given
        let resolver = DefaultResourceResolver(writer: mockWriter)

        // When
        let image = createMockImage(width: 25, height: 25)
        resolver.addResource(withKey: 1000, width: 25, height: 25, data: image)
        resolver.addResource(withKey: 1001, width: 25, height: 25, data: image)

        let resourceId1 = resolver.resolveResource(withKey: 1000)
        let resourceId2 = resolver.resolveResource(withKey: 1001)

        // Then
        #expect(resourceId1 == resourceId2)
    }

    @Test
    func resolveResource_WithDifferentImage_ReturnsDifferentHash() {
        // Given
        let resolver = DefaultResourceResolver(writer: mockWriter)

        // When
        let imageA = createMockImage(width: 25, height: 25)
        let imageB = createMockImage(width: 25, height: 25, filledWith: 0xFF)
        resolver.addResource(withKey: 1000, width: 25, height: 25, data: imageA)
        resolver.addResource(withKey: 1001, width: 25, height: 25, data: imageB)

        let resourceIdA = resolver.resolveResource(withKey: 1000)
        let resourceIdB = resolver.resolveResource(withKey: 1001)

        // Then
        #expect(resourceIdA != resourceIdB)
    }

    @Test
    func resolveResource_WritesResolvedImageToWriter() throws {
        // Given
        let resolver = DefaultResourceResolver(writer: mockWriter)
        let image = createMockImage(width: 25, height: 25)
        resolver.addResource(withKey: 1000, width: 25, height: 25, data: image)

        // When
        let resourceId = resolver.resolveResource(withKey: 1000)

        // Then
        try #require(mockWriter.writeRequests.count == 1)
        #expect(mockWriter.writeRequests[0].identifier == resourceId)
        #expect(mockWriter.writeRequests[0].mimeType == "image/png")
    }

    @Test
    func resolveResource_SameImage_WithDifferentKeys_WritesResolvedImageToWriter() throws {
        // Given
        let resolver = DefaultResourceResolver(writer: mockWriter)
        let imageA = createMockImage(width: 25, height: 25)
        let imageB = createMockImage(width: 25, height: 25, filledWith: 0xFF)
        resolver.addResource(withKey: 1000, width: 25, height: 25, data: imageA)
        resolver.addResource(withKey: 1001, width: 25, height: 25, data: imageB)

        // When
        let resourceIdA = resolver.resolveResource(withKey: 1000)
        let resourceIdB = resolver.resolveResource(withKey: 1001)

        // Then - Even though these have the same contents and the same hash, the
        // resource resolver writes them anyway. It is the responsibility of the writer
        // to cache which images have already been sent.
        try #require(mockWriter.writeRequests.count == 2)
        #expect(mockWriter.writeRequests[0].identifier == resourceIdA)
        #expect(mockWriter.writeRequests[0].mimeType == "image/png")

        #expect(mockWriter.writeRequests[1].identifier == resourceIdB)
        #expect(mockWriter.writeRequests[1].mimeType == "image/png")
    }

    @Test
    func resolveResource_WithDuplicateRequest_DoesNotWriteToWriter() throws {
        // Given
        let resolver = DefaultResourceResolver(writer: mockWriter)
        let image = createMockImage(width: 25, height: 25)
        resolver.addResource(withKey: 1000, width: 25, height: 25, data: image)
        let resourceId1 = resolver.resolveResource(withKey: 1000)

        // When
        let resourceId2 = resolver.resolveResource(withKey: 1000)

        // Then
        #expect(resourceId1 == resourceId2)
        try #require(mockWriter.writeRequests.count == 1)
        #expect(mockWriter.writeRequests[0].identifier == resourceId1)
    }

    func createMockImage(width: Int = 25, height: Int = 25, filledWith: UInt8 = 0) -> Data {
        // Essentially creates an image of the specified width and height
        return Data(repeating: filledWith, count: width * height * 4)
    }
}
