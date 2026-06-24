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
    // Box so a Swift closure can be stored as an NSMapTable value (requires NSObject).
    private class ContextCallbackBox: NSObject {
        let callback: (FlutterRUMCoreContext?) -> Void
        init(_ callback: @escaping (FlutterRUMCoreContext?) -> Void) {
            self.callback = callback
        }
    }

    // Static properties so the feature and core survive engine detach/re-attach cycles.
    internal static var feature: FlutterSessionReplayFeature?
    // Retained so embedded Flutter engines can post records to the native SR message bus.
    internal static var core: DatadogCoreProtocol?

    // Per-engine RUM context callbacks, keyed by canonical messenger.
    // Weak key so entries are cleared automatically when an engine is released.
    private static let engineCallbacks: NSMapTable<AnyObject, ContextCallbackBox> =
        NSMapTable(keyOptions: .weakMemory, valueOptions: .strongMemory)

    // FIFO queue of callbacks set in enable() before claimOwnership() has associated
    // the messenger. Each enable() appends; each claimOwnership() pops from the front.
    // Using a queue instead of a single slot prevents the race where two engines call
    // enable() concurrently — the second enable() would overwrite the single slot and
    // the first engine's claimOwnership() would commit the wrong callback.
    private static var stagedCallbacks: [(FlutterRUMCoreContext?) -> Void] = []

    // Delivers the RUM context to every registered engine and to any newly staged engine
    // that has not yet called claimOwnership().
    private static func deliverContextToAll(_ context: FlutterRUMCoreContext?) {
        let viewID = context?.viewID ?? "nil"
        let cbCount = engineCallbacks.count
        NSLog("[DD-SR-F] deliverContextToAll viewID=\(viewID) engineCallbacks=\(cbCount) staged=\(stagedCallbacks.count)")
        let enumerator = engineCallbacks.objectEnumerator()
        while let box = enumerator?.nextObject() as? ContextCallbackBox {
            box.callback(context)
        }
        for cb in stagedCallbacks {
            cb(context)
        }
    }

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

    static func claimOwnership(messenger: AnyObject) {
        guard !stagedCallbacks.isEmpty else {
            NSLog("[DD-SR-F] claimOwnership: NO staged callbacks (queue empty), engineCallbacks=\(engineCallbacks.count)")
            return
        }
        let cb = stagedCallbacks.removeFirst()
        engineCallbacks.setObject(ContextCallbackBox(cb), forKey: canonical(messenger))
        NSLog("[DD-SR-F] claimOwnership: FIFO pop→map, engineCallbacks now=\(engineCallbacks.count) staged remaining=\(stagedCallbacks.count)")
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

        // Enqueue this engine's callback. claimOwnership(messenger:) pops FIFO from the
        // queue and stores the callback keyed by that engine's messenger. Using a queue
        // rather than a single slot means two engines initializing concurrently no longer
        // race: both callbacks are preserved and each claimOwnership() pops its own entry.
        if let cb = configuration.onContextChanged {
            FlutterSessionReplay.stagedCallbacks.append(cb)
        }

        FlutterSessionReplay.core = core

        // If already initialized, reuse the existing feature (don't re-register with core),
        // but re-prime the new Dart callback with the current RUM context so the new
        // DatadogSessionReplay instance (created on Hot Restart or engine re-attach) has
        // a valid context immediately.
        if let existingFeature = FlutterSessionReplay.feature as? DefaultFlutterSessionReplayFeature {
            existingFeature.deliverCurrentContext()
            return
        } else if FlutterSessionReplay.feature != nil {
            return
        }

        let mappedConfiguration = DefaultFlutterSessionReplayFeature.Configuration(
            customEndpoint: configuration.customEndpoint,
            onContextChanged: { context in
                if let context = context {
                    FlutterSessionReplay.deliverContextToAll(FlutterRUMCoreContext(
                        sessionID: context.sessionID,
                        viewID: context.viewID,
                        applicationID: context.applicationID
                    ))
                } else {
                    FlutterSessionReplay.deliverContextToAll(nil)
                }
            }
        )

        let sessionReplay = try DefaultFlutterSessionReplayFeature(
            core: core,
            configuration: mappedConfiguration,
            resourceResolver: nil   // Use the default resource resolver
        )
        try core.register(feature: sessionReplay)
        FlutterSessionReplay.feature = sessionReplay

        // In hybrid apps the native RUM view is active before this feature registers,
        // so RUMContextReceiver won't fire until the next context change. Prime Dart
        // with the current context now so recording starts without waiting for a new
        // context change.
        sessionReplay.deliverCurrentContext()
    }

    /// Removes this engine's RUM context callback. Each engine only removes its own entry,
    /// so a detaching secondary engine cannot clear a live engine's callback.
    static func detachFromEngine(messenger: AnyObject) {
        engineCallbacks.removeObject(forKey: canonical(messenger))
        NSLog("[DD-SR-F] detachFromEngine: engineCallbacks now=\(engineCallbacks.count)")
    }

    // Only used in testing
    internal static func shutdown() {
        feature = nil
        engineCallbacks.removeAllObjects()
        stagedCallbacks.removeAll()
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
        let pending = pendingSegments
        pendingSegments = []

        if let slotId = slotId {
            embeddingState = .embedded(slotId)
            for segment in pending {
                FlutterSessionReplay.sendViaMessageBus(segmentJson: segment, slotId: slotId)
            }
        } else {
            embeddingState = .standalone
            for segment in pending {
                FlutterSessionReplay.feature?.writeSegment(segment: segment)
            }
        }
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

        FlutterSessionReplay.core?.send(message: .flutterView(.record(records, viewID)))
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
