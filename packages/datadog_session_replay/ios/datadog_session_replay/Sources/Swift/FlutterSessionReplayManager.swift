// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Foundation
import Flutter
import DatadogInternal

/// Process-wide coordinator for Flutter Session Replay.
///
/// A `FlutterSessionReplay` bridge exists once per Flutter engine, but everything that
/// must be shared across engines lives here: the single registered
/// `FlutterSessionReplayFeature`, the core it is registered in, the registry of live
/// engines used to fan RUM context out to all of them, and the slot IDs the native host
/// registers for its embedded Flutter views.
///
/// This state also has to outlive engine detach/re-attach cycles, which is why it is held
/// by a singleton rather than by the bridges themselves — mirroring the Android
/// `FlutterSessionReplayBridge` singleton pattern.
internal final class FlutterSessionReplayManager {
    internal static let shared = FlutterSessionReplayManager()

    /// The shared feature, registered on the first engine to enable.
    internal private(set) var feature: FlutterSessionReplayFeature?

    /// Retained so embedded engines can post records to the native SR message bus.
    private var core: DatadogCoreProtocol?

    /// Weak set of every live engine bridge. The single `RUMContextReceiver` fans out to all
    /// of them (see `broadcastContext`), so every engine — not just the last to enable —
    /// receives live RUM context updates. Entries clear automatically when an engine's
    /// bridge is released.
    private let engines = NSHashTable<FlutterSessionReplay>.weakObjects()

    /// Maps each engine's canonical messenger → the slotId (`FlutterView.hash`) of its
    /// associated `FlutterViewController`. Populated by `enableDatadogSessionReplay()`.
    /// Weak keys so entries clear automatically when an engine is released.
    private let slotIdsByMessenger = NSMapTable<AnyObject, NSString>(
        keyOptions: .weakMemory,
        valueOptions: .strongMemory
    )

    private init() { }

    // MARK: - Engines

    /// Registers an engine's bridge for RUM context fan-out.
    ///
    /// Registration is synchronous — it does not depend on any method-channel round-trip,
    /// which is unreliable for pre-warmed secondary engines.
    internal func register(engine: FlutterSessionReplay) {
        engines.add(engine)
    }

    /// Delivers a context update to every live engine. Snapshots the engines first so one
    /// detaching mid-iteration can't mutate the table under us. Engines that already
    /// detached are simply absent, so this never calls into a destroyed Dart isolate.
    internal func broadcastContext(_ context: RUMCoreContext?) {
        let flutterContext = context.map(FlutterRUMCoreContext.init)
        for engine in engines.allObjects {
            engine.receive(context: flutterContext)
        }
    }

    /// Reads the current RUM context and delivers it to `engine` alone.
    ///
    /// In hybrid apps the native RUM view is already active before an engine enables, so
    /// `RUMContextReceiver` won't fire until the next change. Priming lets that engine start
    /// recording immediately instead of waiting for a context change.
    internal func primeContext(for engine: FlutterSessionReplay) {
        feature?.readCurrentContext { [weak engine] context in
            engine?.receive(context: context.map(FlutterRUMCoreContext.init))
        }
    }

    // MARK: - Feature

    /// Registers the shared Session Replay feature in `core`. Subsequent calls reuse the
    /// already-registered feature (every engine calls this, but only one feature exists).
    internal func enableFeature(in core: DatadogCoreProtocol, customEndpoint: URL?) throws {
        self.core = core

        guard feature == nil else {
            return
        }

        let feature = try DefaultFlutterSessionReplayFeature(
            core: core,
            configuration: .init(
                customEndpoint: customEndpoint,
                onContextChanged: { [weak self] context in
                    self?.broadcastContext(context)
                }
            ),
            resourceResolver: nil   // Use the default resource resolver
        )
        try core.register(feature: feature)
        self.feature = feature
    }

    // MARK: - Slot IDs

    internal func registerSlotId(_ slotId: String, for messenger: FlutterBinaryMessenger) {
        slotIdsByMessenger.setObject(slotId as NSString, forKey: canonical(messenger as AnyObject))
    }

    internal func slotId(for messenger: AnyObject) -> String? {
        return slotIdsByMessenger.object(forKey: canonical(messenger)) as String?
    }

    /// Returns the canonical underlying messenger used as a stable registry key.
    ///
    /// Flutter wraps the real engine messenger in `FlutterBinaryMessengerRelay` objects —
    /// `registrar.messenger()` and `engine.binaryMessenger` return different relay
    /// instances even for the same engine. KVC unwraps any relay to its `parent` without
    /// naming the private concrete type, so the key is always the same stable engine object.
    private func canonical(_ messenger: AnyObject) -> AnyObject {
        let parentSel = NSSelectorFromString("parent")
        if messenger.responds(to: parentSel),
           let parent = messenger.value(forKey: "parent") as? NSObject {
            return parent
        }
        return messenger
    }

    // MARK: - Records

    /// Parses `segment`, injects `slotId` into each record, and posts the records to the
    /// native SDK message bus as `FeatureMessage.flutterView(.record(…))`, where
    /// `FlutterRecordReceiver` (inside the native `SessionReplayFeature`) picks them up.
    /// This follows the same pattern used for web-view records.
    internal func sendToMessageBus(segment: String, slotId: String) {
        guard
            let data = segment.data(using: .utf8),
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let records = object["records"] as? [[String: Any]],
            let viewID = object["viewID"] as? String,
            let viewData = try? JSONSerialization.data(withJSONObject: ["id": viewID]),
            let view = try? JSONDecoder().decode(FlutterMessage.View.self, from: viewData)
        else {
            return
        }

        for var record in records {
            record["slotId"] = slotId
            core?.send(message: .flutterView(.record(record, view)))
        }
    }

    // MARK: - Testing

    /// Only used in testing.
    internal func shutdown() {
        feature = nil
        core = nil
        engines.removeAllObjects()
        slotIdsByMessenger.removeAllObjects()
    }
}
