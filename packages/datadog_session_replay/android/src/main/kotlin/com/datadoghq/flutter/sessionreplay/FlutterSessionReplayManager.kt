/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import android.view.View
import com.datadog.android.Datadog
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadoghq.flutter.sessionreplay.embedded.DefaultEmbeddedSessionReplay
import com.datadoghq.flutter.sessionreplay.embedded.EmbeddedSessionReplay
import com.datadoghq.flutter.sessionreplay.embedded.SegmentParser
import com.datadoghq.flutter.sessionreplay.feature.DefaultFlutterSessionReplayFeature
import io.flutter.plugin.common.BinaryMessenger
import java.lang.ref.WeakReference
import java.util.Collections
import java.util.UUID
import java.util.WeakHashMap

/**
 * Process-wide coordinator for Flutter Session Replay.
 *
 * A [FlutterSessionReplayBridge] exists once per Flutter engine, but everything that must be shared
 * across engines lives here: the single registered [DefaultFlutterSessionReplayFeature], the core it
 * is registered in, the registry of live engines used to fan RUM context out to all of them, and the
 * slot IDs minted for the native host's embedded Flutter views.
 *
 * This state also has to outlive engine detach/re-attach cycles, which is why it is held by
 * [shared] rather than by the bridges themselves.
 *
 * Every registry is guarded by [lock]. Unlike the iOS counterpart, segments arrive here from the
 * Dart processor isolate over JNI while slots are registered on the UI thread, so the two genuinely
 * race.
 *
 * Its constructor is not private so tests can build an isolated instance and inject it into
 * `FlutterSessionReplayBridge(manager = …)` instead of sharing process-wide state between cases.
 */
@Suppress("TooManyFunctions")
internal class FlutterSessionReplayManager(
    feature: DefaultFlutterSessionReplayFeature? = null,
    private val embeddedSessionReplay: EmbeddedSessionReplay = DefaultEmbeddedSessionReplay
) {
    companion object {
        val shared = FlutterSessionReplayManager()
    }

    private val lock = Any()

    /** The shared feature, registered by the first engine to enable. */
    @Volatile
    var feature: DefaultFlutterSessionReplayFeature? = feature
        private set

    /** Retained so embedded engines can hand records to the native Session Replay. */
    @Volatile
    private var core: FeatureSdkCore? = null

    /**
     * Whether Flutter is embedded in a native host, and therefore whether resources belong to the
     * native Session Replay rather than the Flutter resources feature.
     */
    @Volatile
    private var isEmbedded = false

    /**
     * Every live engine bridge, weakly held. The single context listener fans out to all of them
     * (see [broadcastContext]), so every engine — not just the last to enable — receives live RUM
     * context updates. Entries clear automatically when an engine's bridge is released.
     */
    private val engines: MutableSet<FlutterSessionReplayBridge> =
        Collections.newSetFromMap(WeakHashMap())

    /**
     * Maps each engine's messenger to that engine's bridge, so a detaching engine can be torn down
     * (see [detach]). Populated by [bind], because neither side knows both halves on its own: the
     * bridge is created over FFI without a messenger, and the plugin instance that has the
     * messenger never sees the bridge.
     */
    private val bridgesByMessenger =
        WeakHashMap<BinaryMessenger, WeakReference<FlutterSessionReplayBridge>>()

    /**
     * Maps each engine's messenger to the slot registered for its embedded Flutter view.
     *
     * Unlike iOS — which reads the slot back off the view because the native SDK owns the
     * associated object — the ID is kept here. The native module is a `compileOnly` dependency, so
     * its resources are not merged into a pure-Flutter app and `R.id.datadog_session_replay_slot_id`
     * cannot be resolved to read the tag back. Since this class is what mints the ID in the first
     * place, holding it costs nothing.
     */
    private val slotsByMessenger = WeakHashMap<BinaryMessenger, SlotRegistration>()

    /**
     * A slot minted for one engine's Flutter view. The view is weak so a released host view does not
     * keep its tree alive. The slot ID remains after the view detaches, so a cached engine can reuse
     * it when its replacement view registers; the missing view keeps the slot unresolvable and
     * callers buffer in the meantime.
     */
    private class SlotRegistration(
        val slotId: String,
        view: View?
    ) {
        private val viewRef = view?.let { WeakReference(it) }
        val view: View? get() = viewRef?.get()
    }

    // region Engines

    /**
     * Registers an engine's bridge for RUM context fan-out.
     *
     * Synchronous — it does not depend on any method-channel round trip, which is unreliable for
     * pre-warmed secondary engines.
     */
    fun register(engine: FlutterSessionReplayBridge) {
        synchronized(lock) {
            engines.add(engine)
        }
    }

    /**
     * Delivers a context update to every live engine. Snapshots the engines under [lock] first, so
     * one detaching mid-iteration cannot mutate the set underneath us, and so a Dart callback never
     * runs while the lock is held. Engines that already detached are simply absent, so this never
     * calls into a destroyed Dart isolate.
     */
    fun broadcastContext(context: FlutterSessionReplayBridge.RumContext?) {
        val snapshot = synchronized(lock) { engines.toList() }
        snapshot.forEach { it.receive(context) }
    }

    /**
     * Pairs the bridge holding [engineToken] with the engine [messenger] belongs to.
     *
     * Called from the engine method channel, so it runs once per engine, after that engine's bridge
     * has registered.
     */
    fun bind(engineToken: String, messenger: BinaryMessenger) {
        val binding = synchronized(lock) {
            val match = engines.firstOrNull { it.engineToken == engineToken }
                ?: return@synchronized null
            val previous = bridgesByMessenger.put(messenger, WeakReference(match))?.get()
                ?.takeUnless { it === match }
            previous?.let { engines.remove(it) }
            match to previous
        } ?: return

        val (bridge, previous) = binding
        previous?.detach()

        // The bridge needs the messenger too — it resolves this engine's slot ID through it on
        // every segment write, so records always carry the slot the host registered.
        bridge.bind(messenger)
    }

    /**
     * Tears down the engine [messenger] belongs to, called when its plugin detaches.
     *
     * Drops the engine's bridge from the fan-out registry and releases its Dart context callback, so
     * a context update arriving after the isolate is gone cannot call into it. The weak maps would
     * clear these entries eventually; doing it here closes the window where the bridge outlives its
     * isolate.
     *
     * Only ever affects the detaching engine, so a secondary engine closing cannot disturb a live one.
     */
    fun detach(messenger: BinaryMessenger) {
        var slotView: View? = null
        val bridge = synchronized(lock) {
            val existing = bridgesByMessenger.remove(messenger)?.get()
            if (existing != null) {
                engines.remove(existing)
            }
            slotView = slotsByMessenger.remove(messenger)?.view
            existing
        }

        slotView?.let { embeddedSessionReplay.setSlotId(it, null) }
        bridge?.detach()
    }

    /**
     * Reads the current RUM context and delivers it to [engine] alone.
     *
     * In hybrid apps the native RUM view is already active before an engine enables, and the feature
     * only reports context *changes* — so without this the engine would wait for the next change
     * before it could stamp records with a view ID. Priming lets it start recording immediately.
     */
    fun primeContext(engine: FlutterSessionReplayBridge) {
        val context = feature?.readCurrentContext() ?: return
        engine.receive(FlutterSessionReplayBridge.RumContext(context))
    }

    // endregion

    // region Feature

    /**
     * Registers the shared Session Replay feature in [sdkCore]. Subsequent calls reuse the
     * already-registered feature: every engine calls this, but only one feature exists.
     */
    fun enableFeature(
        sdkCore: FeatureSdkCore?,
        customEndpointUrl: String?
    ): DefaultFlutterSessionReplayFeature {
        val featureSdkCore = sdkCore ?: Datadog.getInstance() as FeatureSdkCore
        core = featureSdkCore

        feature?.let { return it }

        val newFeature = DefaultFlutterSessionReplayFeature(
            sdkCore = featureSdkCore,
            onContextChanged = { context ->
                broadcastContext(FlutterSessionReplayBridge.RumContext(context))
            },
            customEndpointUrl = customEndpointUrl,
            embeddedResourceSink = { identifier, data, mimeType ->
                sendToNative(identifier, data, mimeType)
            }
        )
        featureSdkCore.registerFeature(newFeature)
        feature = newFeature
        return newFeature
    }

    // endregion

    // region Slots

    /**
     * Registers [view] as the host slot for [messenger]'s embedded Flutter content and assigns it a
     * slot ID.
     *
     * This is the only place a slot ID is minted. Reading one — which happens on every segment
     * write — deliberately does not assign, so a write can never be what brings a slot into
     * existence: the native recorder emits the embedded-content wireframe only for views that
     * already carry an ID when a snapshot is taken, and minting on write would let records reach the
     * player ahead of the placeholder they belong to.
     *
     * Re-registering a view for the same engine keeps the existing ID, including when the old view
     * detached first, so the player sees one continuous slot across recreation. Must be called on
     * the UI thread, as [EmbeddedSessionReplay.setSlotId] tags the view.
     */
    fun registerSlot(view: View, messenger: BinaryMessenger) {
        isEmbedded = true

        var bridge: FlutterSessionReplayBridge? = null
        val registration = synchronized(lock) {
            val existing = slotsByMessenger[messenger]
            if (existing != null && existing.view === view) {
                return@synchronized null
            }
            // A previous view for this engine is being replaced — clear its tag so the native
            // registry stops tracking a slot nothing renders into any more.
            existing?.view?.let { embeddedSessionReplay.setSlotId(it, null) }

            bridge = bridgesByMessenger[messenger]?.get()
            val slotId = existing?.slotId ?: UUID.randomUUID().toString()
            SlotRegistration(slotId, view).also { slotsByMessenger[messenger] = it }
        } ?: return

        embeddedSessionReplay.setSlotId(view, registration.slotId)
        
        bridge?.onSlotRegistered()
    }

    /**
     * Detaches the slot registered for [messenger], if [view] is still the one registered.
     *
     * Called when a host view detaches from its engine. The view is cleared so records go back to
     * buffering instead of naming a slot the native recorder no longer emits a placeholder for. The
     * ID stays with the engine so its replacement view can continue the same replay.
     *
     * Scoped to [view] rather than dropping whatever [messenger] currently points at, because a
     * cached engine can be handed from one host view to the next: if the new view registers before
     * the old one reports its detach, dropping by messenger alone would tear down the registration
     * that just replaced this one.
     */
    fun unregisterSlot(messenger: BinaryMessenger, view: View) {
        synchronized(lock) {
            val registration = slotsByMessenger[messenger]
            if (registration?.view !== view) {
                return
            }
            slotsByMessenger[messenger] = SlotRegistration(registration.slotId, null)
        }
        embeddedSessionReplay.setSlotId(view, null)
    }

    /**
     * Returns the slot ID of the view hosting [messenger]'s embedded Flutter content, or `null` if
     * the host has not registered one — Flutter is not embedded, or the registered view has been
     * released. Callers keep their segments buffered while this is `null`.
     */
    fun slotId(messenger: BinaryMessenger): String? {
        return synchronized(lock) {
            val registration = slotsByMessenger[messenger] ?: return@synchronized null
            registration.view?.let { registration.slotId }
        }
    }

    // endregion

    // region Records

    /**
     * Parses [segment] and hands its records to the native Session Replay, stamped with [slotId], so
     * the player can composite them into the host's embedded-content wireframe.
     *
     * The view ID carried by the segment is the *native* RUM view ID: the native receiver pairs it
     * with the native application and session IDs and counts records against it, which RUM reads
     * back per view. It is native because the Dart side stamps records with the RUM context this
     * class fans out, which originates natively.
     */
    fun sendToNative(segment: String, slotId: String) {
        val sdkCore = core ?: return
        val parsed = SegmentParser.parse(segment) ?: return
        embeddedSessionReplay.addRecords(parsed.records, slotId, parsed.viewId, sdkCore)
    }

    // endregion

    // region Resources

    /**
     * Hands a resource to the native Session Replay, so it is deduplicated against the host's own
     * resources and that deduplication survives app launches.
     *
     * Returns `false` when Flutter is not embedded — or the native module is absent — so the caller
     * writes to the Flutter resources feature instead.
     */
    fun sendToNative(identifier: String, data: ByteArray, mimeType: String): Boolean {
        val sdkCore = core
        if (!isEmbedded || sdkCore == null || !embeddedSessionReplay.isAvailable) {
            return false
        }
        embeddedSessionReplay.addResource(identifier, data, mimeType, sdkCore)
        return true
    }

    // endregion

    /** Only used in testing. */
    fun shutdown() {
        synchronized(lock) {
            feature = null
            core = null
            isEmbedded = false
            engines.clear()
            bridgesByMessenger.clear()
            slotsByMessenger.clear()
        }
    }
}
