//// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import Foundation

@testable import datadog_session_replay

class FlutterSessionReplayFeatureMock: FlutterSessionReplayFeature {
    var resourceResolver: ResourceResolver = ResourceResolverMock()

    var hasReplay: Bool?
    var recordCount: [String: Int64] = [:]
    var writtenSegments: [String] = []

    func setHasReplay(_ hasReplay: Bool) {
        self.hasReplay = hasReplay
    }

    func setRecordCount(for viewId: String, count: Int64) {
        recordCount[viewId] = count
    }

    func writeSegment(segment: String) {
        writtenSegments.append(segment)
    }

}
