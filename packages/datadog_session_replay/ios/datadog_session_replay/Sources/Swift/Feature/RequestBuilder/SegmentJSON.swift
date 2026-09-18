// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation

// NOTE: This code is pulled from dd-sdk-ios

internal struct SegmentJSON {
    // swiftlint:disable line_length
    enum Constants {
        /// The `timestamp` is common to all records.
        /// see. https://github.com/DataDog/rum-events-format/blob/master/schemas/session-replay/common/_common-record-schema.json#L9
        static let timestampKey = "timestamp"
        /// The `type` key can be used to identify the type of record.
        static let typeKey = "type"
        /// The constant type value for browser full snapshot is `2`.
        /// see. https://github.com/DataDog/rum-events-format/blob/master/schemas/session-replay/browser/full-snapshot-record-schema.json#L14L19
        static let browserFullsnapshotValue = 2
        /// The constant type value for mobile full snapshot is `10`.
        /// see. https://github.com/DataDog/rum-events-format/blob/master/schemas/session-replay/mobile/full-snapshot-record-schema.json#L14L19
        static let nativeFullsnapshotValue = 10
    }
    // swiftlint:enable line_length

    enum CodingKeys: String, CodingKey {
        case applicationID = "application"
        case end = "end"
        case hasFullSnapshot = "has_full_snapshot"
        case indexInView = "index_in_view"
        case records = "records"
        case recordsCount = "records_count"
        case sessionID = "session"
        case source = "source"
        case start = "start"
        case viewID = "view"
    }

    /// The RUM application ID common to all records.
    let applicationID: String
    /// The RUM session ID common to all records.
    let sessionID: String
    /// The RUM view ID common to all records.
    let viewID: String
    /// The `source` of SDK in which the segment was recorded (e.g. `"flutter"`).
    let source: String
    /// The timestamp of the earliest record.
    let start: Int64
    /// The timestamp of the latest record.
    let end: Int64
    /// Records to be sent in this segment.
    let records: [JSONObject]
    /// Number of records.
    let recordsCount: Int64
    /// If there is a Full Snapshot among records.
    let hasFullSnapshot: Bool
    /// The index of this Segment in the segments list that was recorded for this view ID. Starts from 0.
    let indexInView: Int64?

    init(
            applicationID: String,
            sessionID: String,
            viewID: String,
            source: String,
            start: Int64,
            end: Int64,
            records: [JSONObject],
            recordsCount: Int64,
            hasFullSnapshot: Bool,
            indexInView: Int64?
    ) {
        self.applicationID = applicationID
        self.sessionID = sessionID
        self.viewID = viewID
        self.source = source
        self.start = start
        self.end = end
        self.records = records
        self.recordsCount = recordsCount
        self.hasFullSnapshot = hasFullSnapshot
        self.indexInView = indexInView
    }

    init(_ enrichedRecord: EnrichedRecordJSON, source: String) throws {
        self.records = enrichedRecord.records
        self.recordsCount = Int64(records.count)

        var hasFullSnapshot = false
        var start: Int64 = .max
        var end: Int64 = .min

        for record in records {
            guard let timestamp = record[Constants.timestampKey] as? Int64 else {
                // records must contain a timestamp
                throw InternalError(description: "Record is missing timestamp")
            }

            start = min(timestamp, start)
            end = max(timestamp, end)

            guard let type = record[Constants.typeKey] as? Int64 else {
                continue // ignore records with no type
            }

            // check for native or browser full snapshot
            if type == Constants.nativeFullsnapshotValue || type == Constants.browserFullsnapshotValue {
                hasFullSnapshot = true
            }
        }

        self.applicationID = enrichedRecord.applicationID
        self.sessionID = enrichedRecord.sessionID
        self.viewID = enrichedRecord.viewID
        self.hasFullSnapshot = hasFullSnapshot
        self.start = start
        self.end = end
        self.source = source
        self.indexInView = nil
    }

    func toJSONObject() -> JSONObject {
        return [
            segmentKey(.applicationID): ["id": applicationID],
            segmentKey(.sessionID): ["id": sessionID],
            segmentKey(.viewID): ["id": viewID],
            segmentKey(.source): source,
            segmentKey(.start): start,
            segmentKey(.end): end,
            segmentKey(.hasFullSnapshot): hasFullSnapshot,
            segmentKey(.indexInView): indexInView,
            segmentKey(.records): records,
            segmentKey(.recordsCount): recordsCount
        ]
    }
}

private func segmentKey(_ codingKey: SegmentJSON.CodingKeys) -> String { codingKey.stringValue }

extension Array where Element == SegmentJSON {
    /// Merges Segments from the same `view.id`
    ///
    /// - Returns: The new list of segments grouped by view id.
    func merge() -> [SegmentJSON] {
        var indexes: [String: Int] = [:]
        return reduce(into: []) { segments, segment in
            if let index = indexes[segment.viewID] {
                let current = segments[index]
                segments[index] = SegmentJSON(
                    applicationID: current.applicationID,
                    sessionID: current.sessionID,
                    viewID: current.viewID,
                    source: current.source,
                    start: Swift.min(current.start, segment.start),
                    end: Swift.max(current.end, segment.end),
                    records: current.records + segment.records,
                    recordsCount: current.recordsCount + segment.recordsCount,
                    hasFullSnapshot: current.hasFullSnapshot || segment.hasFullSnapshot,
                    indexInView: nil
                )
            } else {
                indexes[segment.viewID] = segments.count
                segments.append(segment)
            }
        }
    }
}
