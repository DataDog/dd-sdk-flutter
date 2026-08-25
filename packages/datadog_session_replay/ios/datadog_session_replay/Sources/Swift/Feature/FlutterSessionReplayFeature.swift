// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import Foundation
import DatadogInternal

protocol FlutterSessionReplayFeature {
    var resourceResolver: ResourceResolver {
        get
    }

    func setHasReplay(_ hasReplay: Bool)
    func setRecordCount(for viewId: String, count: Int64)
    func writeSegment(segment: String)
}

class DefaultFlutterSessionReplayFeature: FlutterSessionReplayFeature, DatadogRemoteFeature {
    static var name: String = "session-replay"

    public struct Configuration {
        public var customEndpoint: URL?
        public var onContextChanged: ((RUMCoreContext?) -> Void)?

        public init(
            customEndpoint: URL? = nil,
            onContextChanged: ((RUMCoreContext?) -> Void)? = nil
        ) {
            self.customEndpoint = customEndpoint
            self.onContextChanged = onContextChanged
        }

        public init?(fromEncoded encoded: [String: Any?]) {
            var customEndpoint: URL?
            if let customEndpointString = encoded["customEndpoint"] as? String {
                customEndpoint = URL(string: customEndpointString)
            }

            self.init(customEndpoint: customEndpoint)
        }
    }

    private var core: DatadogCoreProtocol?
    private var featureScope: FeatureScope?

    let performanceOverride: DatadogInternal.PerformancePresetOverride?

    let requestBuilder: DatadogInternal.FeatureRequestBuilder
    let messageReceiver: DatadogInternal.FeatureMessageReceiver

    private let resourcesFeature: ResourcesFeature
    let resourceResolver: ResourceResolver

    private var recordCountByViewId: [String: Int64] = [:]

    init(
        core: DatadogCoreProtocol,
        configuration: Configuration,
        resourceResolver: ResourceResolver?,
        performanceOverride: PerformancePresetOverride? = nil
    ) throws {
        self.core = core
        self.featureScope = core.scope(for: DefaultFlutterSessionReplayFeature.self)

        self.requestBuilder = RequestBuilder(
            customUploadURL: configuration.customEndpoint,
            telemetry: core.telemetry
        )

        let contextReciever = RUMContextReceiver()
        if let onContextChanged = configuration.onContextChanged {
            contextReciever.observe(notify: { context in
                onContextChanged(context)
            })
        }
        self.messageReceiver = contextReciever

        resourcesFeature = ResourcesFeature(core: core, configuration: configuration)
        try core.register(feature: resourcesFeature)

        self.resourceResolver = resourceResolver ?? DefaultResourceResolver(
            writer: ResourcesWriter(scope: core.scope(for: ResourcesFeature.self))
        )

        self.performanceOverride = performanceOverride
    }

    func setHasReplay(_ hasReplay: Bool) {
        core?.set(context: SessionReplayCoreContext.HasReplay(value: hasReplay))
    }

    func setRecordCount(for viewId: String, count: Int64) {
        recordCountByViewId[viewId] = count
        core?.set(context: SessionReplayCoreContext.RecordsCount(value: recordCountByViewId))
    }

    func writeSegment(segment: String) {
        let wrapper = RecordWrapper(recordJson: segment)
        featureScope?.eventWriteContext(bypassConsent: true) { _, writer in
            writer.write(value: wrapper)
        }
    }
}
