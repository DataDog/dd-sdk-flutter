// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Foundation
import Flutter
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

@objc(FlutterSessionReplay) public class FlutterSessionReplay: NSObject {
    // Static properties so the callbacks and feature survive engine detach/re-attach cycles,
    // mirroring the Android FlutterSessionReplayBridge singleton pattern.
    /// This engine's Dart RUM-context callback. Set in `enable()` (one bridge instance
    /// exists per Flutter engine) and invoked by `broadcastContext`.
    private var contextCallback: ((FlutterRUMCoreContext?) -> Void)?
    internal static var feature: FlutterSessionReplayFeature?
    // Retained so embedded Flutter engines can post records to the native SR message bus.
    internal static var core: DatadogCoreProtocol?

    /// Weak set of every live bridge instance — one per Flutter engine. The single
    /// `RUMContextReceiver` fans out to all of them (see `broadcastContext`), so every
    /// engine — not just the last to enable — receives live RUM context updates.
    /// Registration happens synchronously in `enable()` (keyed by the instance), so it
    /// does not depend on any async method-channel round-trip (which is unreliable for
    /// pre-warmed secondary engines). Entries clear automatically when an engine's bridge
    /// instance is released.
    private static let activeInstances = NSHashTable<FlutterSessionReplay>.weakObjects()

    // Maps each engine's canonical messenger → the slotId (FlutterView.hash) of its
    // associated FlutterViewController. Populated by enableDatadogSessionReplay().
    // Weak key so the entry is cleared automatically when the engine is released.
    private static let slotIdByMessenger: NSMapTable<AnyObject, NSString> =
        NSMapTable(keyOptions: .weakMemory, valueOptions: .strongMemory)

    /// Returns the canonical underlying messenger used as a stable registry key.
    ///
    /// Flutter wraps the real engine messenger in `FlutterBinaryMessengerRelay` objects —
    /// `registrar.messenger()` and `engine.binaryMessenger` return different relay
    /// instances even for the same engine. KVC unwraps any relay to its `parent` without
    /// naming the private concrete type, so the key is always the same stable engine object.
    private static func canonical(_ messenger: AnyObject) -> AnyObject {
        let parentSel = NSSelectorFromString("parent")
        if messenger.responds(to: parentSel),
           let parent = messenger.value(forKey: "parent") as? NSObject {
            return parent
        }
        return messenger
    }

    static func registerSlotId(_ slotId: String, for messenger: FlutterBinaryMessenger) {
        slotIdByMessenger.setObject(slotId as NSString, forKey: canonical(messenger as AnyObject))
    }

    static func resolveSlotId(for messenger: AnyObject) -> String? {
        return slotIdByMessenger.object(forKey: canonical(messenger)) as String?
    }

    /// Delivers a context update to every live engine. Snapshots the instances first so an
    /// engine detaching mid-iteration can't mutate the table under us.
    static func broadcastContext(_ context: FlutterRUMCoreContext?) {
        for instance in activeInstances.allObjects {
            instance.contextCallback?(context)
        }
    }

    /// Maps the internal RUM context to the Flutter-facing type delivered to Dart.
    static func flutterContext(from context: RUMCoreContext?) -> FlutterRUMCoreContext? {
        context.map {
            FlutterRUMCoreContext(
                sessionID: $0.sessionID,
                viewID: $0.viewID,
                applicationID: $0.applicationID
            )
        }
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

        let onContextChanged = configuration.onContextChanged

        // Register this engine for live RUM context fan-out. Done synchronously and keyed
        // by the bridge instance (one per engine) so live updates reach every engine — not
        // just the last to enable — without depending on any async method-channel message.
        self.contextCallback = onContextChanged
        FlutterSessionReplay.activeInstances.add(self)
        FlutterSessionReplay.core = core

        // If already initialized, reuse the existing feature (don't re-register with core),
        // but prime THIS engine immediately with the current RUM context (see below).
        if let existingFeature = FlutterSessionReplay.feature as? DefaultFlutterSessionReplayFeature {
            existingFeature.readCurrentContext { onContextChanged?(FlutterSessionReplay.flutterContext(from: $0)) }
            return
        } else if FlutterSessionReplay.feature != nil {
            return
        }

        let mappedConfiguration = DefaultFlutterSessionReplayFeature.Configuration(
            customEndpoint: configuration.customEndpoint,
            onContextChanged: { context in
                // Fan out to every registered engine. Reads the callback table at call
                // time so an engine that detached is simply absent — no calls into a
                // destroyed Dart isolate.
                FlutterSessionReplay.broadcastContext(FlutterSessionReplay.flutterContext(from: context))
            }
        )

        let sessionReplay = try DefaultFlutterSessionReplayFeature(
            core: core,
            configuration: mappedConfiguration,
            resourceResolver: nil   // Use the default resource resolver
        )
        try core.register(feature: sessionReplay)
        FlutterSessionReplay.feature = sessionReplay

        // In hybrid apps the native RUM view is active before this feature registers, so
        // RUMContextReceiver won't fire until the next change. Prime this engine with the
        // current context now so recording starts without waiting for a context change.
        sessionReplay.readCurrentContext { onContextChanged?(FlutterSessionReplay.flutterContext(from: $0)) }
    }

    // Only used in testing
    internal static func shutdown() {
        feature = nil
        activeInstances.removeAllObjects()
        core = nil
    }

    @objc public func setHasReplay(hasReplay: Bool) {
        FlutterSessionReplay.feature?.setHasReplay(hasReplay)
    }

    @objc public func setRecordCount(for viewId: String, count: Int) {
        FlutterSessionReplay.feature?.setRecordCount(for: viewId, count: Int64(count))
    }

    /// Tracks whether the Dart side has determined the embedding context.
    ///
    /// Records that arrive before `setSlotId` is called are buffered here and
    /// flushed through the correct path once the embedding state is known.
    private enum EmbeddingState: CustomStringConvertible {
        case unknown    // `setSlotId` not yet called
        case embedded(String)   // Flutter is embedded — slotId is known
        case standalone         // Flutter is the host app — no slotId

        var description: String {
            switch self {
            case .unknown: return "unknown"
            case .embedded(let s): return "embedded(\(s))"
            case .standalone: return "standalone"
            }
        }
    }

    private var embeddingState: EmbeddingState = .unknown
    /// Segments buffered while `embeddingState == .unknown`.
    private var pendingSegments: [String] = []

    @objc public func setSlotId(_ slotId: String?) {
        NSLog("[DD-SR-F] Flutter SDK resolved slotId=\(slotId ?? "nil") pendingSegments=\(pendingSegments.count)")
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
            // Route Flutter records through the native SR message bus so they are
            // processed by `FlutterRecordReceiver` inside `SessionReplayFeature`,
            // following the same pattern used for web-view records.
            FlutterSessionReplay.sendViaMessageBus(segmentJson: segmentJson, slotId: slotId)
        case .standalone:
            // Flutter is the host app — write directly to the Flutter SR feature scope.
            FlutterSessionReplay.feature?.writeSegment(segment: segmentJson)
        }
    }

    /// Parses `segmentJson`, injects `slotId` into each record, and posts the records
    /// to the native SDK message bus as `FeatureMessage.flutterView(.record(…))`.
    private static func sendViaMessageBus(segmentJson: String, slotId: String) {
        guard
            let data = segmentJson.data(using: .utf8),
            var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            var records = object["records"] as? [[String: Any]],
            let viewID = object["viewID"] as? String
        else {
            return
        }

        records = records.map { record in
            var r = record
            r["slotId"] = slotId
            return r
        }

        for record in records {
            FlutterSessionReplay.core?.send(message: .flutterView(.record(record, viewID)))
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
        FlutterSessionReplay.feature?.resourceResolver.addResource(withKey: resourceKey, width: width, height: height, data: data)
    }

    @objc public func resourceId(forKey key: Int) -> String? {
        return FlutterSessionReplay.feature?.resourceResolver.resolveResource(withKey: key)
    }
}
