// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation
import DatadogInternal

internal struct RequestBuilder: FeatureRequestBuilder {
    private static let newlineByte = "\n".data(using: .utf8)! // swiftlint:disable:this force_unwrapping

    /// Custom URL for uploading data to.
    let customUploadURL: URL?
    /// Sends telemetry through sdk core.
    let telemetry: Telemetry
    /// Builds multipart form for request's body.
    var multipartBuilder: MultipartFormDataBuilder = MultipartFormData()

    func request(for events: [Event], with context: DatadogContext, execution: DatadogInternal.ExecutionContext) throws -> URLRequest {
        let source = context.source

        // If we can't decode `events: [Data]` there is no way to recover, so we throw an
        // error to let the core delete the batch:
        do {
            let decoder = JSONDecoder()
            let wrappers: [RecordWrapper] = try events.compactMap {
                try decoder.decode(RecordWrapper.self, from: $0.data)
            }
            let segments = try wrappers.map { try $0.extractEnrichedRecord() }
                .map { try SegmentJSON($0, source: source) }
                .merge()
            //let segment = try segmentBuilder.createSegmentJSON(from: records)

            return try createRequest(segments: segments, context: context)
        } catch let error {
            print("Error \(error)")
            throw error
        }
    }

    private func createRequest(segments: [SegmentJSON], context: DatadogContext) throws -> URLRequest {
        var multipart = multipartBuilder

        let builder = URLRequestBuilder(
            url: url(with: context),
            queryItems: [],
            headers: [
                .contentTypeHeader(contentType: .multipartFormData(boundary: multipart.boundary)),
                .userAgentHeader(appName: context.applicationName, appVersion: context.version, device: context.device),
                .ddAPIKeyHeader(clientToken: context.clientToken),
                .ddEVPOriginHeader(source: context.source),
                .ddEVPOriginVersionHeader(sdkVersion: context.sdkVersion),
                .ddRequestIDHeader(),
            ],
            telemetry: telemetry
        )

        let metadata = try segments.enumerated().map { index, segment in
            var json = segment.toJSONObject()
            // Session Replay BE accepts compressed segment data followed by newline character (before compression):
            let data = try JSONSerialization.data(withJSONObject: json) + RequestBuilder.newlineByte
            let compressedData = try SRCompression.compress(data: data)
            // Compressed segment is sent within multipart form data - with some of segment (metadata)
            // attributes listed as form fields:
            multipart.addFormData(
                name: "segment",
                filename: "file\(index)",
                data: compressedData,
                mimeType: "application/octet-stream"
            )
            // Remove the 'records' for the metadata
            json["records"] = nil
            json["raw_segment_size"] = data.count
            json["compressed_segment_size"] = compressedData.count
            return json
        }

        let data = try JSONSerialization.data(withJSONObject: metadata)
        multipart.addFormData(
            name: "event",
            filename: "blob",
            data: data,
            mimeType: "application/json"
        )

        // Data is already compressed, so request building request w/o compression:
        return builder.uploadRequest(with: multipart.build(), compress: false)
    }

    private func url(with context: DatadogContext) -> URL {
        customUploadURL ?? context.site.endpoint.appendingPathComponent("api/v2/replay")
    }
}
