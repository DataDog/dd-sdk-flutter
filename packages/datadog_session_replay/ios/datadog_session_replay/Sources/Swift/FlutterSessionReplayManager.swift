// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import Foundation
import Flutter
import UIKit

// `sessionReplaySlotID` is exposed as SPI by `DatadogInternal`.
@_spi(Internal)
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
///
/// Not `final`, and its initializer is not private, so tests can build an isolated instance —
/// or a subclass spying on it — and inject it into `FlutterSessionReplay(manager:)` instead of
/// sharing process-wide state between test cases.
internal class FlutterSessionReplayManager {
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

    /// Maps each engine's canonical messenger → that engine's bridge, so a detaching engine can be
    /// torn down (see `detach(messenger:)`). Populated by `bind(engineToken:to:)`, because neither
    /// side knows both halves on its own: the bridge is created over FFI without a messenger, and
    /// the plugin instance that has the messenger never sees the bridge.
    ///
    /// Values are weak, so an entry disappears with its bridge even if the engine never detaches
    /// cleanly.
    private let bridgesByMessenger = NSMapTable<AnyObject, FlutterSessionReplay>(
        keyOptions: .weakMemory,
        valueOptions: .weakMemory
    )

    /// Maps each engine's canonical messenger → the `FlutterViewController` hosting its embedded
    /// view. Populated by `enableDatadogSessionReplay()`. Both sides are weak, so entries clear
    /// automatically when an engine or its view controller is released.
    ///
    /// The slot ID itself is deliberately *not* stored here: it lives on the view as
    /// `view.dd.sessionReplaySlotID` and is read on demand, so an engine whose `FlutterView` was
    /// recreated resolves the current view's ID instead of a stale snapshot.
    private let viewControllersByMessenger = NSMapTable<AnyObject, UIViewController>(
        keyOptions: .weakMemory,
        valueOptions: .weakMemory
    )

    /// Whether Flutter is embedded in a native host, and therefore whether resources belong to the
    /// native Session Replay rather than the Flutter `ResourcesFeature`.
    private var isEmbedded = false

    /// Creates a coordinator. `feature` is only passed by tests, to stand a mock feature in
    /// place of the one `enableFeature(in:customEndpoint:)` would register.
    internal init(feature: FlutterSessionReplayFeature? = nil) {
        self.feature = feature
    }

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

    /// Pairs the bridge holding `engineToken` with the engine `messenger` belongs to.
    ///
    /// Called from the engine method channel, so it runs once per engine, after that engine's
    /// bridge has registered.
    internal func bind(engineToken: String, to messenger: AnyObject) {
        guard let bridge = engines.allObjects.first(where: { $0.engineToken == engineToken }) else {
            return
        }
        let key = canonical(messenger)
        bridgesByMessenger.setObject(bridge, forKey: key)
        // The bridge needs the messenger too — it resolves this engine's slot ID through it on
        // every segment write, so records always carry the current view's ID.
        bridge.bind(messenger: key)
    }

    /// Tears down the engine `messenger` belongs to, called when its plugin detaches.
    ///
    /// Drops the engine's bridge from the fan-out registry and releases its Dart context callback,
    /// so a context update arriving after the isolate is gone cannot trap in
    /// `DLRT_GetFfiCallbackMetadata`. The weak tables would clear these entries eventually; doing
    /// it here closes the window where the bridge outlives its isolate.
    ///
    /// Only ever affects the detaching engine, so a secondary engine closing cannot disturb a live
    /// one.
    internal func detach(messenger: AnyObject) {
        let key = canonical(messenger)
        if let bridge = bridgesByMessenger.object(forKey: key) {
            bridge.detach()
            engines.remove(bridge)
        }
        bridgesByMessenger.removeObject(forKey: key)
        viewControllersByMessenger.removeObject(forKey: key)
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
            resourceResolver: nil,  // Use the default resource resolver
            embeddedResourceSink: { [weak self] identifier, data, mimeType in
                self?.sendToMessageBus(
                    resourceWithIdentifier: identifier,
                    data: data,
                    mimeType: mimeType
                ) ?? false
            }
        )
        try core.register(feature: feature)
        self.feature = feature
    }

    // MARK: - Slot IDs

    /// Registers the view controller hosting `messenger`'s embedded Flutter view and assigns its
    /// slot ID.
    ///
    /// This is the only place a slot ID is minted. Reading one — which happens on every segment
    /// write — deliberately does not assign, so a write can never be what brings a slot into
    /// existence: the native recorder emits the `embedded_view` placeholder only for views that
    /// already carry an ID when a snapshot is taken, and minting on write would let records reach
    /// the player ahead of the placeholder they belong to. Assigning here instead means the ID is
    /// in place before Dart records anything, and assignment posts
    /// `ddSessionReplaySlotIDDidChange`, which makes Session Replay snapshot the placeholder.
    ///
    /// The view is loaded on purpose. Hosts call `enableDatadogSessionReplay()` straight after
    /// `FlutterViewController(engine:)` and before presenting it, so `viewIfLoaded` is still `nil`
    /// here while the host is about to load the view anyway — loading it now is what gives the
    /// assignment a view to attach to.
    internal func registerSlot(for viewController: UIViewController, messenger: FlutterBinaryMessenger) {
        isEmbedded = true
        viewControllersByMessenger.setObject(viewController, forKey: canonical(messenger as AnyObject))
        viewController.loadViewIfNeeded()
        assignSlotId(to: viewController.viewIfLoaded)
    }

    /// Returns the slot ID of the view hosting `messenger`'s embedded Flutter content, or `nil` if
    /// the host has not registered one — Flutter is not embedded, or its view controller is gone.
    ///
    /// Read-only, and read from the view rather than cached, so a re-registered view controller is
    /// picked up without anything having to notice it changed. Callers keep their segments buffered
    /// while this is `nil`.
    internal func slotId(for messenger: AnyObject) -> String? {
        let viewController = viewControllersByMessenger.object(forKey: canonical(messenger))
        return viewController?.viewIfLoaded?.dd.sessionReplaySlotID
    }

    /// Gives `view` a slot ID, unless it already has one.
    ///
    /// `sessionReplaySlotID` is an associated object with no default — the embedding SDK mints the
    /// value and the native recorder reads it back, skipping any view without one. The value is
    /// arbitrary, so a UUID is used: nothing on either side derives it from the view.
    private func assignSlotId(to view: UIView?) {
        guard let view = view, view.dd.sessionReplaySlotID == nil else {
            return
        }
        view.dd.sessionReplaySlotID = UUID().uuidString
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

    /// Parses `segment` and posts its records to the native SDK message bus as
    /// `FeatureMessage.embeddedContent(.records(…))`, where `EmbeddedContentReceiver` (inside the
    /// native `SessionReplayFeature`) picks them up, stamps each record with `slotID`, and writes
    /// them to the native Session Replay scope so the player can composite them into the host's
    /// `embedded_view` placeholder.
    ///
    /// `viewID` must be the *native* RUM view ID: the receiver pairs it with the native
    /// application and session IDs, and uses it as the key it increments in
    /// `sr_records_count_by_view_id`, which RUM reads back per view. It is — the Dart side stamps
    /// records with the RUM context this manager fans out, which originates natively.
    internal func sendToMessageBus(segment: String, slotId: String) {
        guard
            let data = segment.data(using: .utf8),
            let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
            let records = object["records"] as? [EmbeddedContentMessage.RecordBatch.Record],
            let viewID = object["viewID"] as? String,
            !records.isEmpty
        else {
            return
        }

        core?.send(
            message: .embeddedContent(
                .records(.init(records: records, slotID: slotId, viewID: viewID))
            )
        )
    }

    // MARK: - Resources

    /// Posts a resource to the native SR message bus as `FeatureMessage.embeddedContent(.resource(…))`,
    /// where `EmbeddedContentReceiver` writes it through the *native* `ResourcesWriter` — the same one
    /// the host's own resources go through, so identifiers are deduped across both and that dedup
    /// survives app launches.
    ///
    /// Returns `false` when Flutter is not embedded, so the caller writes to the Flutter
    /// `ResourcesFeature` instead.
    internal func sendToMessageBus(resourceWithIdentifier identifier: String, data: Data, mimeType: String) -> Bool {
        guard isEmbedded, let core = core else {
            return false
        }

        core.send(
            message: .embeddedContent(
                .resource(.init(identifier: identifier, data: data, mimeType: mimeType))
            )
        )
        return true
    }

    // MARK: - Testing

    /// Only used in testing.
    internal func shutdown() {
        feature = nil
        core = nil
        isEmbedded = false
        engines.removeAllObjects()
        bridgesByMessenger.removeAllObjects()
        viewControllersByMessenger.removeAllObjects()
    }
}
