/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import android.view.View
import com.datadog.android.api.SdkCore
import com.datadoghq.flutter.sessionreplay.embedded.EmbeddedSessionReplay

/**
 * Stands in for the native Session Replay module, recording what was handed to it.
 *
 * The real implementation calls into `dd-sdk-android-session-replay`, which is a `compileOnly`
 * dependency: it is not on the runtime classpath of these tests, and its behaviour is the native
 * SDK's to verify, not ours. What matters here is *what* we send it and *when*.
 */
internal class EmbeddedSessionReplaySpy(
    override var isAvailable: Boolean = true
) : EmbeddedSessionReplay {
    data class RecordBatch(
        val records: List<Map<String, Any?>>,
        val slotId: String,
        val viewId: String
    )

    data class Resource(
        val identifier: String,
        val data: ByteArray,
        val mimeType: String
    ) {
        // ByteArray identity would make every comparison false, so compare the bytes.
        override fun equals(other: Any?): Boolean {
            if (this === other) return true
            if (other !is Resource) return false
            return identifier == other.identifier &&
                data.contentEquals(other.data) &&
                mimeType == other.mimeType
        }

        override fun hashCode(): Int {
            var result = identifier.hashCode()
            result = 31 * result + data.contentHashCode()
            result = 31 * result + mimeType.hashCode()
            return result
        }
    }

    /** Every `setSlotId` call in order, including the `null`s that clear a slot. */
    val slotIdAssignments = mutableListOf<Pair<View, String?>>()

    val recordBatches = mutableListOf<RecordBatch>()
    val resources = mutableListOf<Resource>()

    /** The slot ID currently tagged on [view], as the native recorder would read it. */
    fun slotIdOf(view: View): String? =
        slotIdAssignments.lastOrNull { it.first === view }?.second

    override fun setSlotId(view: View, slotId: String?) {
        slotIdAssignments.add(view to slotId)
    }

    override fun addRecords(
        records: List<Map<String, Any?>>,
        slotId: String,
        viewId: String,
        sdkCore: SdkCore
    ) {
        recordBatches.add(RecordBatch(records, slotId, viewId))
    }

    override fun addResource(
        identifier: String,
        data: ByteArray,
        mimeType: String,
        sdkCore: SdkCore
    ) {
        resources.add(Resource(identifier, data, mimeType))
    }
}
