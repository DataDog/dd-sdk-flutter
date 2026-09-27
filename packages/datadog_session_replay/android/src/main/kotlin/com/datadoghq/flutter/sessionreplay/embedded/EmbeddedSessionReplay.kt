/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.embedded

import android.view.View
import com.datadog.android.Datadog
import com.datadog.android.api.SdkCore
import com.datadog.android.sessionreplay._SessionReplayInternalProxy
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap

/**
 * The slice of the native Session Replay module this plugin depends on in hybrid apps.
 *
 * Behind an interface so the manager can be tested without the native module on the classpath,
 * and so the availability guard below has a single place to live.
 */
internal interface EmbeddedSessionReplay {
    /**
     * Whether the native Session Replay module is present in this app.
     *
     * `false` in a pure-Flutter app, where nothing enables native Session Replay and the module is
     * therefore not packaged — see the `compileOnly` dependency in `build.gradle`.
     */
    val isAvailable: Boolean

    /**
     * Marks [view] as the host slot for this engine's Flutter content, or clears it when [slotId]
     * is `null`. Must be called on the UI thread.
     */
    fun setSlotId(view: View, slotId: String?)

    /** Hands a batch of Flutter records to the native recording, stamped with [slotId]. */
    fun addRecords(
        records: List<Map<String, Any?>>,
        slotId: String,
        viewId: String,
        sdkCore: SdkCore
    )

    /**
     * Hands a Flutter resource to the native recording.
     *
     * Returns whether it actually reached the native module, so a caller that has a fallback
     * (writing to the Flutter resources feature instead) can use it rather than assume success.
     */
    fun addResource(
        identifier: String,
        data: ByteArray,
        mimeType: String,
        sdkCore: SdkCore
    ): Boolean
}

/**
 * Calls the native Session Replay module, tolerating its absence.
 *
 * `dd-sdk-android-session-replay` is a `compileOnly` dependency, so in a pure-Flutter app these
 * symbols are missing at runtime and touching them raises [LinkageError] rather than an exception.
 * The class resolving does not by itself prove every member links, so each call is guarded
 * separately, with its own [LinkageError] flag — a version skew that drops one native method (say,
 * `addEmbeddedContentResource`) should degrade only that call, not the other two, which still link
 * fine.
 */
internal class DefaultEmbeddedSessionReplay : EmbeddedSessionReplay {
    private val isProxyClassAvailable: Boolean by lazy {
        try {
            Class.forName(PROXY_CLASS_NAME)
            true
        } catch (@Suppress("SwallowedException") e: ClassNotFoundException) {
            false
        } catch (@Suppress("SwallowedException") e: LinkageError) {
            false
        }
    }

    /** Identifies one of this class's calls into the native module, for [callsWithLinkageError]. */
    private enum class Call { SET_SLOT_ID, ADD_RECORDS, ADD_RESOURCE }

    /**
     * Which [Call]s have failed to link. A [ConcurrentHashMap]-backed set — [Collections.newSetFromMap]
     * rather than [ConcurrentHashMap.newKeySet], which needs API 24 and this module's minSdk is 21 —
     * so concurrent adds and lookups from different engines' threads are safe without a manual lock,
     * and so a version skew that drops one native method degrades only that call, not the other two,
     * which still link fine.
     */
    private val callsWithLinkageError: MutableSet<Call> =
        Collections.newSetFromMap(ConcurrentHashMap())

    /**
     * Whether a resource handed to [addResource] would reach the native module.
     *
     * The only caller — [FlutterSessionReplayManager.sendToNative] — uses this to decide whether to
     * route a resource natively or fall back to the Flutter resources feature, so this tracks
     * [addResource]'s own linkage rather than [setSlotId]'s or [addRecords]'s.
     */
    override val isAvailable: Boolean
        get() = Call.ADD_RESOURCE !in callsWithLinkageError && isProxyClassAvailable

    override fun setSlotId(view: View, slotId: String?) {
        guarded(Call.SET_SLOT_ID) {
            _SessionReplayInternalProxy.setEmbeddedContentSlotId(view, slotId)
        }
    }

    override fun addRecords(
        records: List<Map<String, Any?>>,
        slotId: String,
        viewId: String,
        sdkCore: SdkCore
    ) {
        guarded(Call.ADD_RECORDS) {
            _SessionReplayInternalProxy.addEmbeddedContentRecords(records, slotId, viewId, sdkCore)
        }
    }

    override fun addResource(
        identifier: String,
        data: ByteArray,
        mimeType: String,
        sdkCore: SdkCore
    ): Boolean {
        return guarded(Call.ADD_RESOURCE) {
            _SessionReplayInternalProxy.addEmbeddedContentResource(identifier, data, mimeType, sdkCore)
        }
    }

    /**
     * Runs [block] only when the native module is present and [call] has not already failed to
     * link, and absorbs the [LinkageError] it would raise if it turned out to be missing anyway — a
     * version skew between this plugin and the native SDK should degrade that one call to "no
     * embedded replay", never crash the host app, and never take the other calls down with it.
     *
     * Returns whether [block] actually ran to completion, so a caller that has a fallback path can
     * use it — [setSlotId] and [addRecords] have none, so they ignore it, but [addResource] does.
     *
     * Reports the degradation via telemetry exactly once per [call], right when the `LinkageError`
     * is first caught — a version skew is otherwise indistinguishable from silence.
     */
    private inline fun guarded(call: Call, block: () -> Unit): Boolean {
        if (call in callsWithLinkageError || !isProxyClassAvailable) {
            return false
        }
        return try {
            block()
            true
        } catch (@Suppress("SwallowedException") e: LinkageError) {
            // Native Session Replay is present but does not expose this member of the
            // embedded-content API.
            callsWithLinkageError.add(call)
            Datadog._internalProxy()._telemetry.debug(
                "DefaultEmbeddedSessionReplay: the native Session Replay module is missing a " +
                    "member of the embedded-content API; degrading that call to no embedded replay."
            )
            false
        }
    }

    private companion object {
        const val PROXY_CLASS_NAME = "com.datadog.android.sessionreplay._SessionReplayInternalProxy"
    }
}
