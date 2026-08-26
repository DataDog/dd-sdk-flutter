// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import DatadogInternal
import Testing

@testable import datadog_session_replay

struct ResourceRequestBuilderTests {
    func createEvents(_ resources: [EnrichedResource]) throws -> [Event] {
        let encoder = JSONEncoder()
        return try resources.map({
            Event(data: try encoder.encode($0), metadata: nil)
        })
    }

    @Test
    func requestBuildsURLRequest_WithCorrectHeaders() throws {
        // Given
        let mockCore = PassthroughCoreMock()
        let requestBuilder = ResourceRequestBuilder(customUploadURL: nil, telemetry: mockCore.telemetry)
        let data: Data = [Int].mockRandom(count: 1024).asData()
        let events = try createEvents([
            EnrichedResource(
                identifier: .mockRandom(),
                data: data,
                mimeType: .mockRandom(),
                context: .init(.mockRandom())
            )
        ])

        // When
        var context: DatadogContext = .mockAny()
        context.set(additionalContext: RUMCoreContext.mockRandom())
        let request = try requestBuilder.request(
            for: events,
            with: context,
            execution: DatadogInternal.ExecutionContext(previousResponseCode: nil, attempt: 0)
        )

        // Then
        // .mockAny defaults to us1
        #expect(request.url?.absoluteURL.relativePath.hasSuffix("api/v2/replay") ?? false)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=\(requestBuilder.multipartBuilder.boundary)")
        let expectedUserAgent = "\(context.applicationName)/\(context.version) CFNetwork (\(context.device.name); \(context.os.name)/\(context.os.version))"
        #expect(request.value(forHTTPHeaderField: "User-Agent") == expectedUserAgent)
        #expect(request.value(forHTTPHeaderField: "DD-API-KEY") == context.clientToken)
        #expect(request.value(forHTTPHeaderField: "DD-EVP-ORIGIN") == context.source)
        #expect(request.value(forHTTPHeaderField: "DD-EVP-ORIGIN-VERSION") == context.sdkVersion)
        #expect(UUID(uuidString: request.value(forHTTPHeaderField: "DD-REQUEST-ID")!) != nil)
    }

    @Test
    func requestBuilder_BuildsFormData_WithMultipartBuilder() throws {
        // Given
        let mockCore = PassthroughCoreMock()
        let rumContext = RUMCoreContext.mockRandom()
        let multipartSpy = MultipartBuilderSpy()
        let requestBuilder = ResourceRequestBuilder(customUploadURL: nil, telemetry: mockCore.telemetry, multipartBuilder: multipartSpy)
        let resourceId: String = .mockRandom()
        let mimeType: String = .mockRandom()
        let data: Data = [Int].mockRandom(count: 1024).asData()
        let events = try createEvents([
            EnrichedResource(
                identifier: resourceId,
                data: data,
                mimeType: mimeType,
                context: .init(rumContext.applicationID)
            )
        ])

        // When
        var context: DatadogContext = .mockRandom()
        context.set(additionalContext: rumContext)
        _ = try requestBuilder.request(
            for: events,
            with: context,
            execution: DatadogInternal.ExecutionContext(previousResponseCode: nil, attempt: 0)
        )

        // Then
        try #require(multipartSpy.formFiles.count == 2)
        let file = multipartSpy.formFiles[0]
        #expect(file.name == "image")
        #expect(file.filename == resourceId)
        #expect(file.mimeType == mimeType)
        #expect(file.data == data)

        let contextFile = multipartSpy.formFiles[1]
        #expect(contextFile.name == "event")
        #expect(contextFile.filename == "blob")
        #expect(contextFile.mimeType == "application/json")

        let decoder = JSONDecoder()
        let metadata = try decoder.decode(EnrichedResource.Context.self, from: contextFile.data)
        #expect(metadata.type == "resource")
        #expect(metadata.application.id == rumContext.applicationID)
    }

    func requestBuilder_BuildsFormDataFromMultipleEvents_WithMultipartBuilder() throws {
        // Given
        let mockCore = PassthroughCoreMock()
        let rumContext = RUMCoreContext.mockRandom()
        let multipartSpy = MultipartBuilderSpy()
        let requestBuilder = ResourceRequestBuilder(customUploadURL: nil, telemetry: mockCore.telemetry, multipartBuilder: multipartSpy)
        let resources = [
            EnrichedResource(
                identifier: .mockRandom(),
                data: [Int].mockRandom(count: 1024).asData(),
                mimeType: .mockRandom(),
                context: .init(rumContext.applicationID)
            ),
            EnrichedResource(
                identifier: .mockRandom(),
                data: [Int].mockRandom(count: 1024).asData(),
                mimeType: .mockRandom(),
                context: .init(rumContext.applicationID)
            )
        ]
        let events = try createEvents(resources)

        // When
        var context: DatadogContext = .mockRandom()
        context.set(additionalContext: rumContext)
        _ = try requestBuilder.request(
            for: events,
            with: context,
            execution: DatadogInternal.ExecutionContext(previousResponseCode: nil, attempt: 0)
        )

        // Then
        try #require(multipartSpy.formFiles.count == 3)
        let fileA = multipartSpy.formFiles[0]
        #expect(fileA.name == "image")
        #expect(fileA.filename == resources[0].identifier)
        #expect(fileA.mimeType == resources[0].mimeType)
        #expect(fileA.data == resources[0].data)

        let fileB = multipartSpy.formFiles[1]
        #expect(fileB.name == "image")
        #expect(fileB.filename == resources[1].identifier)
        #expect(fileB.mimeType == resources[1].mimeType)
        #expect(fileB.data == resources[1].data)

        let contextFile = multipartSpy.formFiles[2]
        #expect(contextFile.name == "event")
        #expect(contextFile.filename == "blob")
        #expect(contextFile.mimeType == "application/json")

        let decoder = JSONDecoder()
        let metadata = try decoder.decode(EnrichedResource.Context.self, from: contextFile.data)
        #expect(metadata.type == "resource")
        #expect(metadata.application.id == rumContext.applicationID)
    }
}

extension Array<Int> {
    func asData() -> Data {
        var data = Data(capacity: count * MemoryLayout<Int>.size)
        for var element in self {
            data.append(Data(bytes: &element, count: MemoryLayout<Int>.size))
        }
        return data
    }
}
