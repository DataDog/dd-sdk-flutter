// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation

internal typealias JSONObject = [String: Any?]

internal struct RecordWrapper: Codable {
    enum CodingKeys: String, CodingKey {
        case recordJson
    }

    let recordJson: String

    func extractEnrichedRecord() throws -> EnrichedRecordJSON {
        if let data = recordJson.data(using: .utf8) {
            let record = try EnrichedRecordJSON(jsonObjectData: data)
            return record
        }
        throw InternalError(description: "Failed to convert jsonString")
    }
}

// NOTE: This code is pulled from dd-sdk-ios

/// A mirror of `EnrichedRecord` but providing decoding capability. Unlike encodable `EnrichedRecord`
/// it can be both encoded and decoded with `Foundation.JSONSerialization`.
///
/// `EnrichedRecordJSON` values are decoded from batched events (`[Data]`) upon request from `DatadogCore`.
/// They are mapped into one or many `SegmentJSONs`. Segments are then encoded in multipart-body of `URLRequests`
/// and sent by core on behalf of Session Replay.
///
/// Except containing original records created by `Processor` (in `records: [JSONObject]`), `EnrichedRecordJSON`
/// offers a typed meta information that facilitates grouping records into segments.
internal struct EnrichedRecordJSON {
    enum CodingKeys: String, CodingKey {
        case records
        case applicationID
        case sessionID
        case viewID
    }

    /// Records enriched with further information.
    let records: [JSONObject]

    /// The RUM application ID common to all records.
    let applicationID: String
    /// The RUM session ID common to all records.
    let sessionID: String
    /// The RUM view ID common to all records.
    let viewID: String
    /// If there is a Full Snapshot among records.

    init(jsonObjectData: Data) throws {
        let jsonObject: JSONObject = try decode(jsonObjectData)

        self.records = try read(codingKey: .records, from: jsonObject)
        self.applicationID = try read(codingKey: .applicationID, from: jsonObject)
        self.sessionID = try read(codingKey: .sessionID, from: jsonObject)
        self.viewID = try read(codingKey: .viewID, from: jsonObject)
    }
}

internal func decode<T>(_ data: Data) throws -> T {
    guard let value = try JSONSerialization.jsonObject(with: data) as? T else {
        throw InternalError(description: "Failed to decode \(type(of: T.self))")
    }
    return value
}

private func read<T>(codingKey: EnrichedRecordJSON.CodingKeys, from object: JSONObject) throws -> T {
    guard let value = object[codingKey.stringValue] as? T else {
        throw InternalError(description: "Failed to read attribute at key path '\(codingKey.stringValue)'")
    }
    return value
}

/// An exception thrown by the SDK.
///
/// It is always handled by SDK (keeps it functional) and never passed to the user unless SDK verbosity is configured
/// (then it might be printed in debugger console). `InternalError` might be thrown due to programmer error (API misuse)
/// or SDK internal inconsistency or external issues (e.g.  I/O errors).
///
/// The SDK should always recover from these failures (if it can not, `FatalError` should be used).
internal struct InternalError: Error, CustomStringConvertible {
    let description: String

    init(description: String, fileID: StaticString = #fileID, line: UInt = #line) {
        self.description = "\(description) (\(fileID):\(line))"
    }
}
