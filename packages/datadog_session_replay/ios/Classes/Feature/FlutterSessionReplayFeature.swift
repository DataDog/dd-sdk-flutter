// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import Foundation
import DatadogInternal

class FlutterSessionReplayFeature: DatadogRemoteFeature {
    static var name: String = "session-replay"

    let requestBuilder: DatadogInternal.FeatureRequestBuilder
    let messageReceiver: DatadogInternal.FeatureMessageReceiver

    let writer: Writer
    var recordCountByViewId: [String: Int] = [:]

    private weak var core: DatadogCoreProtocol?

    init(
        core: DatadogCoreProtocol,
        configuration: FlutterSessionReplay.Configuration
    ) throws {
        self.requestBuilder = RequestBuilder(
            customUploadURL: configuration.customEndpoint,
            telemetry: core.telemetry
        )
        
        self.core = core
        self.messageReceiver = RUMContextReceiver()

        self.writer = Writer()
    }

    func setHasReplay(_ hasReplay: Bool) {
        core?.set(baggage: hasReplay, forKey: RUMDependency.hasReplay)
    }

    func setRecordCount(for viewId: String, count: Int) {
        recordCountByViewId[viewId] = count
        core?.set(baggage: recordCountByViewId, forKey: RUMDependency.recordsCountByViewID)
    }
}

class Writer {
    private weak var core: DatadogCoreProtocol?
    private var lastViewId: String?

    func startWriting(to core: DatadogCoreProtocol) {
        self.core = core
    }

    func write(record: String, viewId: String) {
        let forceNewBatch = lastViewId != viewId
        lastViewId = viewId

        guard let scope = core?.scope(for: FlutterSessionReplayFeature.name) else {
            return
        }
        
        // TODO: Find a better way to do this. We're decoding JSON just to re-encode it in the writer.
        // May want to add a "writeRaw" to writer
        let wrapper = RecordWrapper(recordJson: record)

        scope.eventWriteContext(bypassConsent: false, forceNewBatch: forceNewBatch) { _, writer in
            writer.write(value: wrapper)
        }
    }
}
