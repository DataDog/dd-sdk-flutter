/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.embedded

import com.datadoghq.flutter.sessionreplay.models.EnrichedRecord
import com.google.gson.GsonBuilder
import com.google.gson.ToNumberPolicy
import com.google.gson.reflect.TypeToken

/**
 * A segment produced by the Dart processor, unpacked into what the native embedded-content API
 * takes: the records as plain maps, plus the RUM view they belong to.
 */
internal data class ParsedSegment(
    val records: List<Map<String, Any?>>,
    val viewId: String
)

/**
 * Unpacks the JSON the Dart processor writes — an `EnrichedRecord` — for
 * `_SessionReplayInternalProxy.addEmbeddedContentRecords`, which takes records as maps rather than
 * as JSON.
 *
 * Returns `null` for anything that would produce an empty or unattributable batch: malformed JSON,
 * a missing `viewID`, or no records. The native receiver would drop those anyway, and stopping here
 * keeps the caller's buffering logic from treating a dud segment as delivered.
 */
internal object SegmentParser {
    
    private val gson = GsonBuilder()
        .setObjectToNumberStrategy(ToNumberPolicy.LONG_OR_DOUBLE)
        .create()

    private val segmentType = object : TypeToken<Map<String, Any?>>() {}.type

    fun parse(segmentJson: String): ParsedSegment? {
        val root: Map<String, Any?> = runCatching {
            gson.fromJson<Map<String, Any?>>(segmentJson, segmentType)
        }.getOrNull() ?: return null

        val viewId = root[EnrichedRecord.VIEW_ID_KEY] as? String ?: return null

        val records = (root[EnrichedRecord.RECORDS_KEY] as? List<*>)
            ?.mapNotNull { it.asRecord() }
            ?.takeIf { it.isNotEmpty() }
            ?: return null

        return ParsedSegment(records, viewId)
    }

    @Suppress("UNCHECKED_CAST")
    private fun Any?.asRecord(): Map<String, Any?>? = this as? Map<String, Any?>
}
