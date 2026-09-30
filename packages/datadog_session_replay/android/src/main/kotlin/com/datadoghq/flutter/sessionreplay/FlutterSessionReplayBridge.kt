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
         * 100ms cadence. See [writeSegment] for the telemetry emitted when this triggers, so the
         * drop is diagnosable rather than silent.
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
     * The latest [setHasReplay]/[setRecordCount] call made while [embeddingState] was still
     * [EmbeddingState.UNKNOWN], so it can be published once [setEmbedded] resolves the state
     * instead of being lost — the native RUM view priming in [enable] means a call can arrive
     * before Dart's own `setEmbedded` even runs. Only the latest of each matters, since both are
     * "current value" signals, not an ordered log like segments.
     */
    private var pendingHasReplay: Pair<String, Boolean>? = null
    private var pendingRecordCount: Pair<String, Int>? = null

    /**
     * Whether [writeSegment] has already reported dropping a segment to the [MAX_PENDING_SEGMENTS]
     * cap. A permanently-unresolvable engine (see [MAX_PENDING_SEGMENTS]) hits that cap on every
     * single write for the rest of its life; latched so it is reported once per engine lifetime
     * rather than on every one of those writes.
     */
    private var hasReportedSegmentOverflow = false

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

    /**
     * Retries delivery of this engine's buffered segments, called once the host has registered the
     * view that hosts its content.
     */
    fun onSlotRegistered() {
        flushPendingSegments()
    }

    /** Tears down everything tied to this engine's Dart isolate, called when the engine detaches. */
    fun detach() {
        contextListener = null
        // The resolver is shared and keeps entries indefinitely, so this engine's resources have to
        // be dropped explicitly or they outlive the isolate that issued their keys.
        manager.feature?.resourceResolver?.releaseEngine(engineToken)
        synchronized(lock) {
            boundMessenger = null
            embeddingState = EmbeddingState.UNKNOWN
            pendingSegments.clear()
            pendingHasReplay = null
            pendingRecordCount = null
            hasReportedSegmentOverflow = false
        }
    }

    // endregion

    fun enable(
        configuration: Configuration,
        core: FeatureSdkCore? = null
    ): DefaultFlutterSessionReplayFeature? {
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
     * Only the standalone path publishes replay state (`has_replay`, record counts) to the core:
     * when embedded, the native Session Replay publishes both — its embedded-content receiver
     * counts our records — and publishing from here too would have the two fight over the same
     * core-context keys, making the value RUM reads depend on which wrote last.
     *
     * While [embeddingState] is still [EmbeddingState.UNKNOWN], the call is remembered instead of
     * dropped — see [pendingHasReplay]/[pendingRecordCount] — and published if [setEmbedded]
     * resolves it to standalone.
     */
    fun setHasReplay(viewId: String, hasReplay: Boolean) {
        val shouldPublish = synchronized(lock) {
            when (embeddingState) {
                EmbeddingState.UNKNOWN -> {
                    pendingHasReplay = viewId to hasReplay
                    false
                }
                EmbeddingState.STANDALONE -> true
                EmbeddingState.EMBEDDED -> false
            }
        }
        if (shouldPublish) {
            manager.feature?.setHasReplay(viewId, hasReplay)
        }
    }

    fun setRecordCount(viewId: String, recordCount: Int) {
        val shouldPublish = synchronized(lock) {
            when (embeddingState) {
                EmbeddingState.UNKNOWN -> {
                    pendingRecordCount = viewId to recordCount
                    false
                }
                EmbeddingState.STANDALONE -> true
                EmbeddingState.EMBEDDED -> false
            }
        }
        if (shouldPublish) {
            manager.feature?.setRecordCount(viewId, recordCount)
        }
    }

    // endregion

    // region Segments

    /**
     * Declares which recording path this engine writes to. Called once by Dart, straight after
     * [enable], from the `isEmbedded` it was configured with.
     *
     * Also publishes whatever [setHasReplay]/[setRecordCount] call arrived too early to publish
     * itself, if this resolves to standalone — see [pendingHasReplay]/[pendingRecordCount].
     */
    fun setEmbedded(isEmbedded: Boolean) {
        val (hasReplay, recordCount) = synchronized(lock) {
            embeddingState = if (isEmbedded) EmbeddingState.EMBEDDED else EmbeddingState.STANDALONE
            if (embeddingState == EmbeddingState.STANDALONE) {
                val flushed = pendingHasReplay to pendingRecordCount
                pendingHasReplay = null
                pendingRecordCount = null
                flushed
            } else {
                null to null
            }
        }

        hasReplay?.let { (viewId, value) -> manager.feature?.setHasReplay(viewId, value) }
        recordCount?.let { (viewId, value) -> manager.feature?.setRecordCount(viewId, value) }

        flushPendingSegments()
    }

    fun writeSegment(segment: String) {
        var droppedCount = 0
        var shouldReport = false
        synchronized(lock) {
            pendingSegments.addLast(segment)
            while (pendingSegments.size > MAX_PENDING_SEGMENTS) {
                pendingSegments.removeFirst()
                droppedCount++
            }
            // Latched: a permanently-unresolvable engine hits this on every single write for the
            // rest of its life, so only the first drop is reported — not necessarily a stuck engine
            // (flushPendingSegments retries on every write, so a slot or embedding state that
            // resolves moments later would have drained these anyway), but worth surfacing once.
            if (droppedCount > 0 && !hasReportedSegmentOverflow) {
                hasReportedSegmentOverflow = true
                shouldReport = true
            }
        }
        if (shouldReport) {
            telemetryDebug(
                "FlutterSessionReplayBridge dropped $droppedCount buffered segment(s): still " +
                    "unresolvable after $MAX_PENDING_SEGMENTS pending"
            )
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
        val (resolvedSlotId, drained) = synchronized(lock) {
            if (pendingSegments.isEmpty()) {
                return
            }

            // An expression, not a statement, so the compiler forces every branch to be handled if
            // EmbeddingState ever grows a case — a statement `when` here would instead compile
            // silently and fall through to the STANDALONE write path for anything unhandled.
            val slotId: String? = when (embeddingState) {
                // Dart has not declared the embedding state yet.
                EmbeddingState.UNKNOWN -> return

                // Flutter is the host app — write directly to the Flutter SR feature scope.
                EmbeddingState.STANDALONE -> null

                // Flutter is embedded — hand the records to the native recording so the player can
                // composite them into the host's embedded-content placeholder.
                EmbeddingState.EMBEDDED -> {
                    val messenger = boundMessenger?.get()
                    // Either `registerEngine` has not landed yet, or the host has not registered
                    // this engine's view. Keep buffering and retry on the next segment.
                    messenger?.let { manager.slotId(it) } ?: return
                }
            }

            slotId to pendingSegments.toList().also { pendingSegments.clear() }
        }

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
            engineToken = engineToken,
            resourceKey = resourceId,
            width = width,
            height = height,
            resourceBytes = imageData
        )
    }

    fun resourceIdForKey(resourceId: Int): String? {
        return manager.feature?.resourceResolver?.resolveResource(engineToken, resourceId)
    }

    // endregion
}
