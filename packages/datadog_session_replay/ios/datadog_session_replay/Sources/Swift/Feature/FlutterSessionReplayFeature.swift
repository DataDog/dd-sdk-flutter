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

    func readCurrentContext(_ completion: @escaping (RUMCoreContext?) -> Void)
    func registerSessionReplayContext()
    func setHasReplay(_ hasReplay: Bool)
    func setSessionSampled(for sessionID: String, sampled: Bool)
    func setRecordCount(for viewId: String, count: Int64)
    func writeSegment(segment: String)
}

class DefaultFlutterSessionReplayFeature:
    FlutterSessionReplayFeature,
    DatadogRemoteFeature,
    SessionReplayConfiguration {
    static var name: String = "flutter-session-replay"

    public struct Configuration {
        public var customEndpoint: URL?
        public var onContextChanged: ((RUMCoreContext?) -> Void)?

        public var textAndInputPrivacyLevel: TextAndInputPrivacyLevel
        public var imagePrivacyLevel: ImagePrivacyLevel
        public var touchPrivacyLevel: TouchPrivacyLevel

        public init(
            customEndpoint: URL? = nil,
            onContextChanged: ((RUMCoreContext?) -> Void)? = nil,
            textAndInputPrivacyLevel: TextAndInputPrivacyLevel = .maskAll,
            imagePrivacyLevel: ImagePrivacyLevel = .maskAll,
            touchPrivacyLevel: TouchPrivacyLevel = .hide
        ) {
            self.customEndpoint = customEndpoint
            self.onContextChanged = onContextChanged
            self.textAndInputPrivacyLevel = textAndInputPrivacyLevel
            self.imagePrivacyLevel = imagePrivacyLevel
            self.touchPrivacyLevel = touchPrivacyLevel
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
    private let sessionReplayContextLock = NSLock()
    private var ownsSessionReplayContext = false
    private var featureScope: FeatureScope?
    private let sampledSessionID = ReadWriteLock<String?>(wrappedValue: nil)

    let performanceOverride: DatadogInternal.PerformancePresetOverride?

    let requestBuilder: DatadogInternal.FeatureRequestBuilder
    let messageReceiver: DatadogInternal.FeatureMessageReceiver

    let textAndInputPrivacyLevel: TextAndInputPrivacyLevel
    let imagePrivacyLevel: ImagePrivacyLevel
    let touchPrivacyLevel: TouchPrivacyLevel

    private let resourcesFeature: ResourcesFeature
    let resourceResolver: ResourceResolver

    private var recordCountByViewId: [String: Int64] = [:]

    init(
        core: DatadogCoreProtocol,
        configuration: Configuration,
        resourceResolver: ResourceResolver?,
        embeddedResourceSink: @escaping EmbeddedResourceSink = { _, _, _ in false },
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
        self.messageReceiver = CombinedFeatureMessageReceiver(
            contextReciever,
            WebViewRecordReceiver(
                scope: core.scope(for: DefaultFlutterSessionReplayFeature.self),
                sampledSessionID: self.sampledSessionID
            )
        )

        self.textAndInputPrivacyLevel = configuration.textAndInputPrivacyLevel
        self.imagePrivacyLevel = configuration.imagePrivacyLevel
        self.touchPrivacyLevel = configuration.touchPrivacyLevel

        resourcesFeature = ResourcesFeature(core: core, configuration: configuration)
        try core.register(feature: resourcesFeature)

        self.resourceResolver = resourceResolver ?? DefaultResourceResolver(
            writer: RoutedResourcesWriter(
                standaloneWriter: ResourcesWriter(scope: core.scope(for: ResourcesFeature.self)),
                sendToNative: embeddedResourceSink
            )
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
    static let nativeSessionReplayPresentWarning =
        "Flutter Session Replay is configured as standalone, but the native Session Replay is enabled. " +
        "Flutter Session Replay will not report replay state to RUM; configure it as embedded in hybrid apps."

    private var isOwningSessionReplayContext: Bool {
        sessionReplayContextLock.lock()
        defer { sessionReplayContextLock.unlock() }
        return ownsSessionReplayContext
    }

    /// Call this once right after a Flutter engine enables to prime it immediately.
    func readCurrentContext(_ completion: @escaping (RUMCoreContext?) -> Void) {
        featureScope?.context { context in
            completion(context.additionalContext(ofType: RUMCoreContext.self))
        }
    }

    /// Registers a `SessionReplayContextFeature` under the native Session Replay name, unless a
    /// feature already holds it. Called once the engine is known to run standalone; until then,
    /// `FlutterSessionReplayBridge` holds replay state back.
    ///
    /// When the native Session Replay holds the name, the app is hybrid even though Flutter Session
    /// Replay was configured as standalone: the native one owns the replay state, so nothing is
    /// published.
    func registerSessionReplayContext() {
        sessionReplayContextLock.lock()
        defer { sessionReplayContextLock.unlock() }
        guard let core = core else {
            return
        }
        let name = SessionReplayContextFeature.name
        if core.feature(named: name, type: SessionReplayContextFeature.self) != nil {
            ownsSessionReplayContext = true
        } else if core.isNativeSessionReplayRegistered {
            ownsSessionReplayContext = false
            consolePrint(Self.nativeSessionReplayPresentWarning, .warn)
        } else {
            do {
                try core.register(feature: SessionReplayContextFeature(configuration: self))
                ownsSessionReplayContext = true
            } catch {
                ownsSessionReplayContext = false
                consolePrint("Failed to register the Session Replay context: \(error)", .error)
            }
        }
    }

    func setHasReplay(_ hasReplay: Bool) {
        guard isOwningSessionReplayContext else {
            return
        }
        core?.set(context: SessionReplayCoreContext.HasReplay(value: hasReplay))
    }

    func setSessionSampled(for sessionID: String, sampled: Bool) {
        sampledSessionID.wrappedValue = sampled ? sessionID : nil
    }

    func setRecordCount(for viewId: String, count: Int64) {
        guard isOwningSessionReplayContext else {
            return
        }
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
