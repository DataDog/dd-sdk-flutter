// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2020 Datadog, Inc.

import Foundation
import DatadogInternal

/// Constants shared across the Flutter Session Replay feature.
internal enum FlutterSessionReplayConstants {
    /// The `source` reported to the intake for all Flutter SR uploads. Hardcoded
    /// (rather than derived from `context.source`) because these records always
    /// originate from the Flutter SDK, even when embedded in a native host app.
    static let source = "flutter"
}

protocol FlutterSessionReplayFeature {
    var resourceResolver: ResourceResolver {
        get
    }

    func setHasReplay(_ hasReplay: Bool)
    func setRecordCount(for viewId: String, count: Int64)
    func writeSegment(segment: String)
}

class DefaultFlutterSessionReplayFeature: FlutterSessionReplayFeature, DatadogRemoteFeature {
    static var name: String = "flutter-session-replay"

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

    /// Reads the current RUM context off the feature scope and passes it to `completion`.
    ///
    /// `RUMContextReceiver` only fires `onContextChanged` when the native RUM context
    /// *changes*. In hybrid apps the native RUM view is already active before an engine
    /// enables, so without an explicit read the engine never receives the initial context
    /// and `viewId` stays nil — deferring the first full snapshot until the next change.
    ///
    /// Call this once right after a Flutter engine enables to prime it immediately.
    func readCurrentContext(_ completion: @escaping (RUMCoreContext?) -> Void) {
        featureScope?.eventWriteContext(bypassConsent: true) { context, _ in
            completion(context.additionalContext(ofType: RUMCoreContext.self))
        }
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
