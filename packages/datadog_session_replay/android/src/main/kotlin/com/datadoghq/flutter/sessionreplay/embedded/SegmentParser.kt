/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.embedded

import com.datadoghq.flutter.sessionreplay.models.EnrichedRecord
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.JsonPrimitive

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
    fun parse(segmentJson: String): ParsedSegment? {
        val root = runCatching { JsonParser.parseString(segmentJson) }
            .getOrNull() as? JsonObject
            ?: return null

        val viewId = (root.get(EnrichedRecord.VIEW_ID_KEY) as? JsonPrimitive)
            ?.takeIf { it.isString }
            ?.asString
            ?: return null

        val records = (root.get(EnrichedRecord.RECORDS_KEY) as? JsonArray)
            ?.mapNotNull { element -> (element as? JsonObject)?.let { toMap(it) } }
            ?.takeIf { it.isNotEmpty() }
            ?: return null

        return ParsedSegment(records, viewId)
    }

    private fun toMap(source: JsonObject): Map<String, Any?> {
        return source.entrySet().associate { (key, value) -> key to toValue(value) }
    }

    private fun toValue(element: JsonElement): Any? {
        return when {
            element.isJsonObject -> toMap(element.asJsonObject)
            element.isJsonArray -> element.asJsonArray.map { toValue(it) }
            element.isJsonPrimitive -> toPrimitive(element.asJsonPrimitive)
            else -> null
        }
    }

    /**
     * Gson models every JSON number as a single `Number` type, so the integral ones have to be
     * recovered by inspecting the literal. Reading them all as `Double` would re-serialize record
     * timestamps in exponent form and lose precision past 2^53, and the player reads those
     * timestamps as integers.
     */
    private fun toPrimitive(primitive: JsonPrimitive): Any? {
        return when {
            primitive.isBoolean -> primitive.asBoolean
            primitive.isString -> primitive.asString
            primitive.isNumber -> {
                val literal = primitive.asString
                if (literal.any { it == '.' || it == 'e' || it == 'E' }) {
                    primitive.asDouble
                } else {
                    literal.toLongOrNull() ?: primitive.asDouble
                }
            }
            else -> null
        }
    }
}
