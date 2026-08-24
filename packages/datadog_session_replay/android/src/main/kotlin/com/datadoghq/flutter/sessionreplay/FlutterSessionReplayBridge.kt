/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import com.datadog.android.Datadog
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadoghq.flutter.sessionreplay.feature.DefaultFlutterSessionReplayFeature
import io.flutter.plugin.common.BinaryMessenger
import java.lang.ref.WeakReference
import java.nio.ByteBuffer
import java.util.UUID

/**
 * The Session Replay bridge for a single Flutter engine.
 *
 * One instance exists per engine. It owns only per-engine state — this engine's Dart RUM-context
 * callback and the routing of this engine's records — and delegates everything shared (the feature,
 * the core, the engine registry, host slot IDs) to [FlutterSessionReplayManager].
 */
@Suppress("TooManyFunctions")
internal class FlutterSessionReplayBridge private constructor(
    /** The coordinator shared with every other engine's bridge. */
    private val manager: FlutterSessionReplayManager
) {
    /** Creates a bridge backed by the process-wide coordinator. This is what Dart constructs. */
    constructor() : this(FlutterSessionReplayManager.shared)

    companion object {
        /**
         * Cap on [pendingSegments], so an engine that never becomes resolvable — a host that
         * configured `isEmbedded: true` but never called `dd.enableSessionReplay()` — drops the
         * oldest segments rather than growing without bound. Two seconds of capture at the default
         * 100ms cadence.
         */
        internal const val MAX_PENDING_SEGMENTS = 20

        /** Creates a bridge backed by [manager]. Used in tests, to substitute the coordinator. */
        internal fun create(manager: FlutterSessionReplayManager) = FlutterSessionReplayBridge(manager)
    }

    data class RumContext(
        val applicationId: String?,
        val sessionId: String?,
        val viewId: String?,
        val viewServerTimeOffset: Long?
    ) {
        constructor(context: DefaultFlutterSessionReplayFeature.RumContext) : this(
            applicationId = context.applicationId,
            sessionId = context.sessionId,
            viewId = context.viewId,
            viewServerTimeOffset = context.viewServerTimeOffset
        )
    }

    interface ContextListener {
        fun onContextChanged(context: RumContext)
    }

    data class Configuration(
        val customEndpointUrl: String? = null,
        val onContextChanged: ContextListener
    )

    /**
     * Identifies this bridge to its own engine.
     *
     * The FFI `enable()` call cannot tell which engine invoked it, and this bridge never sees a
     * messenger. Dart reads this token after construction and passes it to the plugin instance for
     * its engine over the engine method channel, which is the one place the messenger *is* known —
     * letting the manager pair the two. See [FlutterSessionReplayManager.bind].
     */
    val engineToken: String = UUID.randomUUID().toString()

    /**
     * This engine's Dart RUM-context callback, set in [enable] and invoked by the manager's context
     * fan-out.
     */
    @Volatile
    private var contextListener: ContextListener? = null

    /**
     * The messenger of the engine this bridge serves, set by [FlutterSessionReplayManager.bind] once
     * `registerEngine` has paired the two. Needed to resolve this engine's slot ID at write time.
     * Weak — the engine owns it.
     */
    private var boundMessenger: WeakReference<BinaryMessenger>? = null

    /**
     * Which recording path this engine's segments belong to, as declared by Dart in [setEmbedded].
     * Deliberately does *not* carry the slot ID: that is resolved per segment from the engine's
     * current view, so a re-registered host view is picked up without anything on the Dart side
     * having to notice it changed.
     */
    private enum class EmbeddingState {
        /** [setEmbedded] not yet called. */
        UNKNOWN,

        /** Flutter is embedded in a native host. */
        EMBEDDED,

        /** Flutter is the host app. */
        STANDALONE
    }

    private var embeddingState = EmbeddingState.UNKNOWN

    /**
     * Segments with nowhere to go yet — either Dart has not declared the embedding state, or the
     * embedded slot cannot be resolved because the host has not registered this engine's view yet
     * (a pre-warmed engine). Drained by [flushPendingSegments].
     */
    private val pendingSegments = ArrayDeque<String>()

    /**
     * Guards everything the segment path touches. Segments arrive from the Dart processor isolate
     * over JNI, while binding and embedding state are set from the platform thread.
     */
    private val lock = Any()

    // region Engine lifecycle

    /** Delivers a RUM context update to this engine's Dart callback. */
    fun receive(context: RumContext?) {
        if (context == null) {
            return
        }
        contextListener?.onContextChanged(context)
    }

    /**
     * Records the messenger of the engine this bridge belongs to, and drains anything that was
     * waiting on it. See [boundMessenger].
     */
    fun bind(messenger: BinaryMessenger) {
        synchronized(lock) {
            boundMessenger = WeakReference(messenger)
        }
        flushPendingSegments()
    }

    /** Tears down everything tied to this engine's Dart isolate, called when the engine detaches. */
    fun detach() {
        contextListener = null
        synchronized(lock) {
            boundMessenger = null
            embeddingState = EmbeddingState.UNKNOWN
            pendingSegments.clear()
        }
    }

    // endregion

    fun enable(
        configuration: Configuration,
        core: FeatureSdkCore? = null
    ): DefaultFlutterSessionReplayFeature {
        // Register this engine for live RUM context fan-out before anything else, so it receives
        // updates even if the feature was already registered by another engine. Always replaces the
        // context listener, which also covers a Hot Restart, where the previously created listener
        // has been destroyed.
        contextListener = configuration.onContextChanged
        manager.register(this)

        val feature = manager.enableFeature(core, configuration.customEndpointUrl)

        // The feature only reports context *changes*, and in hybrid apps the native RUM view is
        // usually already active by now — so prime this engine with the current context instead of
        // waiting for the next change.
        manager.primeContext(this)

        return feature
    }

    // region Replay state

    /**
     * Whether this engine should publish replay state (`has_replay`, record counts) to the core.
     *
     * Only the standalone path may: when embedded, the native Session Replay publishes both — its
     * embedded-content receiver counts our records — and publishing from here too would have the
     * two fight over the same core-context keys, making the value RUM reads depend on which wrote
     * last.
     */
    private val publishesReplayState: Boolean
        get() = synchronized(lock) { embeddingState == EmbeddingState.STANDALONE }

    fun setHasReplay(viewId: String, hasReplay: Boolean) {
        if (!publishesReplayState) {
            return
        }
        manager.feature?.setHasReplay(viewId, hasReplay)
    }

    fun setRecordCount(viewId: String, recordCount: Int) {
        if (!publishesReplayState) {
            return
        }
        manager.feature?.setRecordCount(viewId, recordCount)
    }

    // endregion

    // region Segments

    /**
     * Declares which recording path this engine writes to. Called once by Dart, straight after
     * [enable], from the `isEmbedded` it was configured with.
     */
    fun setEmbedded(isEmbedded: Boolean) {
        synchronized(lock) {
            embeddingState = if (isEmbedded) EmbeddingState.EMBEDDED else EmbeddingState.STANDALONE
        }
        flushPendingSegments()
    }

    fun writeSegment(segment: String) {
        synchronized(lock) {
            pendingSegments.addLast(segment)
            while (pendingSegments.size > MAX_PENDING_SEGMENTS) {
                pendingSegments.removeFirst()
            }
        }
        flushPendingSegments()
    }

    /**
     * Writes every buffered segment, if a destination can be resolved right now.
     *
     * The embedded slot is resolved here — per flush, from the engine's current view — rather than
     * cached when the engine enables. That is what removes the need for Dart to observe its view:
     * each segment simply picks up whatever slot ID the host's registered view carries now.
     *
     * Segments are drained under [lock] but written outside it, so a write never holds the lock
     * against the Dart thread appending the next segment.
     */
    private fun flushPendingSegments() {
        var slotId: String? = null

        val drained = synchronized(lock) {
            if (pendingSegments.isEmpty()) {
                return
            }

            when (embeddingState) {
                // Dart has not declared the embedding state yet.
                EmbeddingState.UNKNOWN -> return

                // Flutter is the host app — write directly to the Flutter SR feature scope.
                EmbeddingState.STANDALONE -> Unit

                // Flutter is embedded — hand the records to the native recording so the player can
                // composite them into the host's embedded-content placeholder.
                EmbeddingState.EMBEDDED -> {
                    val messenger = boundMessenger?.get()
                    // Either `registerEngine` has not landed yet, or the host has not registered
                    // this engine's view. Keep buffering and retry on the next segment.
                    slotId = messenger?.let { manager.slotId(it) } ?: return
                }
            }

            pendingSegments.toList().also { pendingSegments.clear() }
        }

        val resolvedSlotId = slotId
        if (resolvedSlotId == null) {
            drained.forEach { manager.feature?.writeSegment(it) }
        } else {
            drained.forEach { manager.sendToNative(it, resolvedSlotId) }
        }
    }

    // endregion

    // region Telemetry

    fun telemetryDebug(message: String) {
        Datadog._internalProxy()._telemetry.debug(message)
    }

    fun telemetryError(message: String, stack: String, kind: String) {
        Datadog._internalProxy()._telemetry.error(message, stack, kind)
    }

    // endregion

    // region Resources

    fun saveImageForProcessing(
        resourceId: Int,
        imageData: ByteBuffer,
        width: Int,
        height: Int
    ) {
        manager.feature?.resourceResolver?.addResource(
            resourceKey = resourceId,
            width = width,
            height = height,
            resourceBytes = imageData
        )
    }

    fun resourceIdForKey(resourceId: Int): String? {
        return manager.feature?.resourceResolver?.resolveResource(resourceId)
    }

    // endregion
}
