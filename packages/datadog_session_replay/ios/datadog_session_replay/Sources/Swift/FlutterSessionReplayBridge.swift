// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Foundation
import DatadogCore
import DatadogInternal

// Force symbols to be retained during linking
@_silgen_name("__datadog_session_replay_keep_symbols")
// swiftlint:disable:next identifier_name
public func __datadog_session_replay_keep_symbols() {
    // Reference all classes to prevent dead code elimination
    _ = FlutterRUMCoreContext.self
    _ = FlutterSessionReplayConfiguration.self
    _ = FlutterSessionReplay.self
}

@objc(FlutterRUMCoreContext) public class FlutterRUMCoreContext: NSObject {
    @objc public var sessionID: String
    @objc public var viewID: String?
    @objc public var applicationID: String

    internal init(sessionID: String, viewID: String?, applicationID: String) {
        self.sessionID = sessionID
        self.viewID = viewID
        self.applicationID = applicationID
        super.init()
    }

    /// Maps the internal RUM context to the Flutter-facing type delivered to Dart.
    internal convenience init(_ context: RUMCoreContext) {
        self.init(
            sessionID: context.sessionID,
            viewID: context.viewID,
            applicationID: context.applicationID
        )
    }
}

@objc(FlutterSessionReplayConfiguration) public class FlutterSessionReplayConfiguration: NSObject {
    @objc public var customEndpoint: URL?

    public var onContextChanged: ((FlutterRUMCoreContext?) -> Void)?

    @objc public init(
        customEndpoint: URL? = nil,
        onContextChanged: ((FlutterRUMCoreContext?) -> Void)? = nil
    ) {
        self.customEndpoint = customEndpoint
        self.onContextChanged = onContextChanged
        super.init()
    }
}

/// The Session Replay bridge for a single Flutter engine.
///
/// One instance exists per engine. It owns only per-engine state — this engine's Dart
/// RUM-context callback and the routing of this engine's records — and delegates
/// everything shared (the feature, the core, the engine registry, host slot IDs) to
/// `FlutterSessionReplayManager`.
@objc(FlutterSessionReplay) public class FlutterSessionReplay: NSObject {
    /// The coordinator shared with every other engine's bridge.
    internal let manager: FlutterSessionReplayManager

    /// Identifies this bridge to its own engine.
    ///
    /// The FFI `enable()` call cannot tell which engine invoked it, and this bridge never sees a
    /// messenger. Dart reads this token after construction and passes it to the plugin instance
    /// for its engine over the engine method channel, which is the one place the messenger *is*
    /// known — letting the manager pair the two. See `FlutterSessionReplayManager.bind(engineToken:to:)`.
    @objc public let engineToken: String = UUID().uuidString

    /// Creates a bridge backed by the process-wide coordinator.
    @objc public override convenience init() {
        self.init(manager: .shared)
    }

    /// Creates a bridge backed by `manager`. Primarily used in tests, to substitute the
    /// coordinator.
    internal init(manager: FlutterSessionReplayManager) {
        self.manager = manager
        super.init()
    }

    /// This engine's Dart RUM-context callback, set in `enable()` and invoked by the
    /// manager's context fan-out.
    private var contextCallback: ((FlutterRUMCoreContext?) -> Void)?

    /// Tracks whether the Dart side has determined the embedding context. Records that
    /// arrive before `setSlotId` is called are buffered and flushed through the correct
    /// path once the embedding state is known.
    private enum EmbeddingState {
        case unknown            // `setSlotId` not yet called
        case embedded(String)   // Flutter is embedded — slotId is known
        case standalone         // Flutter is the host app — no slotId
    }

    private var embeddingState: EmbeddingState = .unknown
    /// Segments buffered while `embeddingState == .unknown`.
    private var pendingSegments: [String] = []

    /// Delivers a RUM context update to this engine's Dart callback.
    internal func receive(context: FlutterRUMCoreContext?) {
        contextCallback?(context)
    }

    /// Tears down everything tied to this engine's Dart isolate, called when the engine detaches.
    internal func detach() {
        contextCallback = nil
        embeddingState = .unknown
        pendingSegments = []
    }

    @objc public func enable(with configuration: FlutterSessionReplayConfiguration) {
        do {
            try enableOrThrow(with: configuration, in: CoreRegistry.default)
        } catch let error {
            consolePrint("\(error)", .error)
        }
    }

    internal func enableOrThrow(
        with configuration: FlutterSessionReplayConfiguration,
        in core: DatadogCoreProtocol
    ) throws {
        guard !(core is NOPDatadogCore) else {
            throw ProgrammerError(
                description: "Datadog SDK must be initialized before calling `SessionReplay.enable(with:)`."
            )
        }

        // Register this engine for live RUM context fan-out before anything else, so it
        // receives updates even if the feature was already registered by another engine.
        contextCallback = configuration.onContextChanged
        manager.register(engine: self)

        try manager.enableFeature(in: core, customEndpoint: configuration.customEndpoint)

        // The feature only reports context *changes*, and in hybrid apps the native RUM
        // view is usually already active by now — so prime this engine with the current
        // context instead of waiting for the next change.
        manager.primeContext(for: self)
    }

    /// Whether this engine should publish replay state (`has_replay`, record counts) to the core.
    ///
    /// Only the standalone path may: when embedded, the native `SessionReplayFeature` publishes
    /// both — `EmbeddedContentReceiver` counts our records through its `SRContextPublisher` —
    /// and publishing from here too would have the two fight over the same core-context keys,
    /// making the value RUM reads depend on which wrote last.
    private var publishesReplayState: Bool {
        if case .standalone = embeddingState {
            return true
        }
        return false
    }

    @objc public func setHasReplay(hasReplay: Bool) {
        guard publishesReplayState else {
            return
        }
        manager.feature?.setHasReplay(hasReplay)
    }

    @objc public func setRecordCount(for viewId: String, count: Int) {
        guard publishesReplayState else {
            return
        }
        manager.feature?.setRecordCount(for: viewId, count: Int64(count))
    }

    @objc public func setSlotId(_ slotId: String?) {
        embeddingState = slotId.map { .embedded($0) } ?? .standalone

        // Replay buffered segments through `writeSegment`, which now routes them
        // according to the resolved `embeddingState` (single source of truth).
        let pending = pendingSegments
        pendingSegments = []
        pending.forEach { writeSegment(segment: $0) }
    }

    @objc public func writeSegment(segment segmentJson: String) {
        switch embeddingState {
        case .unknown:
            // Embedding not yet determined — buffer until `setSlotId` is called.
            pendingSegments.append(segmentJson)
        case .embedded(let slotId):
            // Flutter is embedded — hand the records to the native recording so the player
            // can composite them into the host's `embedded_view` placeholder.
            manager.sendToMessageBus(segment: segmentJson, slotId: slotId)
        case .standalone:
            // Flutter is the host app — write directly to the Flutter SR feature scope.
            manager.feature?.writeSegment(segment: segmentJson)
        }
    }

    @objc public func postTelemetryDebug(id: String, message: String) {
        Datadog._internal.telemetry.debug(id: "datadog_flutter:\(id)", message: message)
    }

    @objc public func postTelemetryError(message: String, kind: String, stackTrace: String) {
        Datadog._internal.telemetry.error(id: "datadog_flutter:\(String(describing: kind)):\(message)",
                                          message: message, kind: kind, stack: stackTrace)
    }

    @objc public func saveImageForProcessing(resourceKey: Int, width: Int, height: Int, data: Data) {
        manager.feature?.resourceResolver.addResource(withKey: resourceKey, width: width, height: height, data: data)
    }

    @objc public func resourceId(forKey key: Int) -> String? {
        return manager.feature?.resourceResolver.resolveResource(withKey: key)
    }
}
