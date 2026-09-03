/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.embedded

import android.view.View
import com.datadog.android.api.SdkCore
import com.datadog.android.sessionreplay._SessionReplayInternalProxy

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

    /** Hands a Flutter resource to the native recording. */
    fun addResource(
        identifier: String,
        data: ByteArray,
        mimeType: String,
        sdkCore: SdkCore
    )
}

/**
 * Calls the native Session Replay module, tolerating its absence.
 *
 * `dd-sdk-android-session-replay` is a `compileOnly` dependency, so in a pure-Flutter app these
 * symbols are missing at runtime and touching them raises [LinkageError] rather than an exception.
 * [isAvailable] resolves the class once up front so the common path is a boolean check, and each
 * call is still guarded — the class resolving does not by itself prove every member links.
 */
internal object DefaultEmbeddedSessionReplay : EmbeddedSessionReplay {
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

    @Volatile
    private var hasLinkageError = false

    override val isAvailable: Boolean
        get() = !hasLinkageError && isProxyClassAvailable

    override fun setSlotId(view: View, slotId: String?) {
        guarded {
            _SessionReplayInternalProxy.setEmbeddedContentSlotId(view, slotId)
        }
    }

    override fun addRecords(
        records: List<Map<String, Any?>>,
        slotId: String,
        viewId: String,
        sdkCore: SdkCore
    ) {
        guarded {
            _SessionReplayInternalProxy.addEmbeddedContentRecords(records, slotId, viewId, sdkCore)
        }
    }

    override fun addResource(
        identifier: String,
        data: ByteArray,
        mimeType: String,
        sdkCore: SdkCore
    ) {
        guarded {
            _SessionReplayInternalProxy.addEmbeddedContentResource(identifier, data, mimeType, sdkCore)
        }
    }

    /**
     * Runs [block] only when the native module is present, and absorbs the [LinkageError] it would
     * raise if a member turned out to be missing anyway — a version skew between this plugin and
     * the native SDK should degrade to "no embedded replay", never crash the host app.
     */
    private inline fun guarded(block: () -> Unit) {
        if (!isAvailable) {
            return
        }
        try {
            block()
        } catch (@Suppress("SwallowedException") e: LinkageError) {
            // Native Session Replay is present but does not expose the embedded-content API.
            hasLinkageError = true
        }
    }

    private const val PROXY_CLASS_NAME = "com.datadog.android.sessionreplay._SessionReplayInternalProxy"
}
