/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.models

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParseException
import com.google.gson.JsonPrimitive
import java.lang.IllegalStateException
import java.lang.NullPointerException
import java.lang.NumberFormatException
import kotlin.jvm.Throws

/**
 * MobileSegment is what is sent to Datadog intake.
 *
 * Only a portion of the data is needed for processing, so only a portion is deserialized - the
 * rest is left as raw JSON.
 */
internal data class MobileSegment(
    val application: Application,
    val session: Session,
    val view: View,
    val start: Long,
    val end: Long,
    val recordsCount: Long,
    val indexInView: Long? = null,
    val hasFullSnapshot: Boolean? = null,
    val source: String,
    val records: JsonArray
) {
    fun toJson(): JsonElement {
        val json = JsonObject()
        json.add("application", application.toJson())
        json.add("session", session.toJson())
        json.add("view", view.toJson())
        json.addProperty("start", start)
        json.addProperty("end", end)
        json.addProperty("records_count", recordsCount)
        indexInView?.let { indexInViewNonNull ->
            json.addProperty("index_in_view", indexInViewNonNull)
        }
        hasFullSnapshot?.let { hasFullSnapshotNonNull ->
            json.addProperty("has_full_snapshot", hasFullSnapshotNonNull)
        }
        json.add("source", JsonPrimitive(source))
        json.add("records", records)
        return json
    }

    /**
     * Application properties.
     * @param id UUID of the application
     */
    data class Application(
        val id: String
    ) {
        fun toJson(): JsonElement {
            val json = JsonObject()
            json.addProperty("id", id)
            return json
        }

        companion object {
            @JvmStatic
            @Throws(JsonParseException::class)
            @Suppress("TooGenericExceptionCaught")
            fun fromJsonObject(jsonObject: JsonObject): Application {
                try {
                    val id = jsonObject.get("id").asString
                    return Application(id)
                } catch (e: IllegalStateException) {
                    throw JsonParseException(
                        PARSE_ERROR_MESSAGE,
                        e
                    )
                } catch (e: NumberFormatException) {
                    throw JsonParseException(
                        PARSE_ERROR_MESSAGE,
                        e
                    )
                } catch (e: NullPointerException) {
                    throw JsonParseException(
                        PARSE_ERROR_MESSAGE,
                        e
                    )
                }
            }
        }
    }

    /**
     * Session properties.
     * @param id UUID of the session
     */
    data class Session(
        val id: String
    ) {
        fun toJson(): JsonElement {
            val json = JsonObject()
            json.addProperty("id", id)
            return json
        }
    }

    /**
     * View properties.
     * @param id UUID of the view
     */
    data class View(
        val id: String
    ) {
        fun toJson(): JsonElement {
            val json = JsonObject()
            json.addProperty("id", id)
            return json
        }
    }

    companion object {
        const val PARSE_ERROR_MESSAGE: String = "Unable to parse json into type Application"
    }
}
