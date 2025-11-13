// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation
import DatadogInternal
import Testing
import Compression

@testable import datadog_session_replay

// Records are encoded by Flutter, so the models aren't in
// the Flutter SR feature for flutter, so we encode JSON manually.
func createEnrichedRecordJson(context: RUMCoreContext, records: [String] = []) -> String {
    let viewId = context.viewID ?? "null"
    let recordsString = "[\(records.joined(separator: ","))]"
    return """
{
    "applicationID": "\(context.applicationID)",
    "sessionID": "\(context.sessionID)",
    "viewID": "\(viewId)",
    "records": \(recordsString)
}
"""
}

func mockRecord() -> String {
    // Return a full snapshot record always for now.
    return """
{
    "timestamp": \(Int.mockRandom()),
    "data": {
        "wireframes": []
    }
}
"""
}

func createEvents(_ records: [RecordWrapper]) throws -> [Event] {
    let encoder = JSONEncoder()
    return try records.map({
        Event(data: try encoder.encode($0), metadata: nil)
    })
}

@Test
func requestBuildsURLRequest_WithCorrectHeaders() throws {
    // Given
    let mockCore = PassthroughCoreMock()
    let rumContext = RUMCoreContext.mockRandom()
    let requestBuilder = RequestBuilder(customUploadURL: nil, telemetry: mockCore.telemetry)
    let events = try createEvents([
        RecordWrapper(
            recordJson: createEnrichedRecordJson(context: rumContext)
        )
    ])

    // When
    var context: DatadogContext = .mockRandom()
    context.set(additionalContext: RUMCoreContext.mockRandom())
    let request = try requestBuilder.request(
        for: events,
        with: context,
        execution: DatadogInternal.ExecutionContext(previousResponseCode: nil, attempt: 0)
    )

    // Then
    // .mockAny defaults to us1
    #expect(request.url?.absoluteString.hasSuffix("api/v2/replay") ?? false)
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
    let requestBuilder = RequestBuilder(customUploadURL: nil, telemetry: mockCore.telemetry, multipartBuilder: multipartSpy)
    let events = try createEvents([
        RecordWrapper(
            recordJson: createEnrichedRecordJson(context: rumContext)
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
    let decoder = JSONDecoder()
    try #require(multipartSpy.formFiles.count == 2)
    let file = multipartSpy.formFiles[0]
    #expect(file.filename == "file0")
    #expect(file.mimeType == "application/octet-stream")

    let segmentData = try #require(try zlibDecode(file.data))
    let segment = try #require(try JSONSerialization.jsonObject(with: segmentData) as? [String: Any])
    #expect((segment["application"] as! JSONObject)["id"] as? String == rumContext.applicationID)
    #expect((segment["session"] as! JSONObject)["id"] as? String == rumContext.sessionID)
    #expect((segment["view"] as! JSONObject)["id"] as? String == rumContext.viewID)
    #expect(segment["source"] as? String == context.source)
    #expect(segment["records_count"] as? Int == 0)

    let metadataFile = multipartSpy.formFiles[1]
    #expect(metadataFile.filename == "blob")
    #expect(metadataFile.mimeType == "application/json")

    let metadata = try decoder.decode([Metadata].self, from: metadataFile.data)
    try #require(metadata.count == 1)
    #expect(metadata[0].application.id == rumContext.applicationID)
    #expect(metadata[0].session.id == rumContext.sessionID)
    #expect(metadata[0].view.id == rumContext.viewID)
    #expect(metadata[0].rawSegmentSize >= metadata[0].compressedSegmentSize)
}

@Test
func requestBuilder_BuildsFormDataWithRecords_WithMultipartBuilder() throws {
    // Given
    let mockCore = PassthroughCoreMock()
    let rumContext = RUMCoreContext.mockRandom()
    let multipartSpy = MultipartBuilderSpy()
    let requestBuilder = RequestBuilder(customUploadURL: nil, telemetry: mockCore.telemetry, multipartBuilder: multipartSpy)
    let events = try createEvents([
        RecordWrapper(
            recordJson: createEnrichedRecordJson(
                context: rumContext,
                records: [ mockRecord(), mockRecord(), mockRecord() ]
            )
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
    let decoder = JSONDecoder()
    try #require(multipartSpy.formFiles.count == 2)
    let file = multipartSpy.formFiles[0]
    #expect(file.filename == "file0")
    #expect(file.mimeType == "application/octet-stream")

    let segmentData = try #require(try zlibDecode(file.data))
    let segment = try #require(try JSONSerialization.jsonObject(with: segmentData) as? [String: Any])
    #expect(segment["records_count"] as? Int == 3)

    let metadataFile = multipartSpy.formFiles[1]
    #expect(metadataFile.filename == "blob")
    #expect(metadataFile.mimeType == "application/json")

    let metadata = try decoder.decode([Metadata].self, from: metadataFile.data)
    try #require(metadata.count == 1)
    #expect(metadata[0].application.id == rumContext.applicationID)
    #expect(metadata[0].session.id == rumContext.sessionID)
    #expect(metadata[0].view.id == rumContext.viewID)
    #expect(metadata[0].rawSegmentSize >= metadata[0].compressedSegmentSize)
}

@Test
func requestBuilder_BuildsFormDataWithMultipleContexts_WithMultipartBuilder() throws {
    // Given
    let mockCore = PassthroughCoreMock()
    let context0 = RUMCoreContext.mockRandom()
    let context1 = RUMCoreContext.mockRandom()
    let multipartSpy = MultipartBuilderSpy()
    let requestBuilder = RequestBuilder(customUploadURL: nil, telemetry: mockCore.telemetry, multipartBuilder: multipartSpy)
    let events = try createEvents([
        RecordWrapper(
            recordJson: createEnrichedRecordJson(
                context: context0,
                records: [ mockRecord(), mockRecord(), mockRecord() ]
            )
        ),
        RecordWrapper(
            recordJson: createEnrichedRecordJson(
                context: context0,
                records: [ mockRecord() ]
            )
        ),
        RecordWrapper(
            recordJson: createEnrichedRecordJson(
                context: context1,
                records: [ mockRecord(), mockRecord(), mockRecord() ]
            )
        ),
        RecordWrapper(
            recordJson: createEnrichedRecordJson(
                context: context1,
                records: [ mockRecord(), mockRecord() ]
            )
        )
    ])

    // When
    var context: DatadogContext = .mockRandom()
    context.set(additionalContext: context0)
    _ = try requestBuilder.request(
        for: events,
        with: context,
        execution: DatadogInternal.ExecutionContext(previousResponseCode: nil, attempt: 0)
    )

    // Then
    let decoder = JSONDecoder()
    try #require(multipartSpy.formFiles.count == 3)
    let file0 = multipartSpy.formFiles[0]
    #expect(file0.filename == "file0")
    #expect(file0.mimeType == "application/octet-stream")

    let segmentData0 = try #require(try zlibDecode(file0.data))
    let segment0 = try #require(try JSONSerialization.jsonObject(with: segmentData0) as? [String: Any])
    #expect((segment0["application"] as! JSONObject)["id"] as? String == context0.applicationID)
    #expect((segment0["session"] as! JSONObject)["id"] as? String == context0.sessionID)
    #expect((segment0["view"] as! JSONObject)["id"] as? String == context0.viewID)
    #expect(segment0["source"] as? String == context.source)
    #expect(segment0["records_count"] as? Int == 4)

    let file1 = multipartSpy.formFiles[1]
    #expect(file1.filename == "file1")
    #expect(file1.mimeType == "application/octet-stream")

    let segmentData1 = try #require(try zlibDecode(file1.data))
    let segment1 = try #require(try JSONSerialization.jsonObject(with: segmentData1) as? [String: Any])
    #expect((segment1["application"] as! JSONObject)["id"] as? String == context1.applicationID)
    #expect((segment1["session"] as! JSONObject)["id"] as? String == context1.sessionID)
    #expect((segment1["view"] as! JSONObject)["id"] as? String == context1.viewID)
    #expect(segment1["source"] as? String == context.source)
    #expect(segment1["records_count"] as? Int == 5)

    let metadataFile = multipartSpy.formFiles[2]
    #expect(metadataFile.filename == "blob")
    #expect(metadataFile.mimeType == "application/json")

    let metadata = try decoder.decode([Metadata].self, from: metadataFile.data)
    try #require(metadata.count == 2)
    #expect(metadata[0].application.id == context0.applicationID)
    #expect(metadata[0].session.id == context0.sessionID)
    #expect(metadata[0].view.id == context0.viewID)
    #expect(metadata[0].rawSegmentSize >= metadata[0].compressedSegmentSize)

    #expect(metadata[1].application.id == context1.applicationID)
    #expect(metadata[1].session.id == context1.sessionID)
    #expect(metadata[1].view.id == context1.viewID)
    #expect(metadata[1].rawSegmentSize >= metadata[0].compressedSegmentSize)
}

func zlibDecode(_ data: Data, capacity: Int = 1_000_000) -> Data? {
    // Skip `deflate` header (2 bytes) and checksum (4 bytes)
    // validations and inflate raw deflated data.
    let range = 2..<data.count - 4
    let subdata = data.subdata(in: range)

    return subdata.withUnsafeBytes {
        guard let ptr = $0.bindMemory(to: UInt8.self).baseAddress else {
            return nil
        }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: capacity)
        defer { buffer.deallocate() }

        // Returns the number of bytes written to the destination buffer after
        // decompressing the input. If there is not enough space in the destination
        // buffer to hold the entire decompressed output, the function writes the
        // first dst_size bytes to the buffer and returns dst_size. Note that this
        // behavior differs from that of `compression_encode_buffer(_:_:_:_:_:_:)`.
        let size = compression_decode_buffer(buffer, capacity, ptr, data.count, nil, COMPRESSION_ZLIB)
        return Data(bytes: buffer, count: size)
    }
}
