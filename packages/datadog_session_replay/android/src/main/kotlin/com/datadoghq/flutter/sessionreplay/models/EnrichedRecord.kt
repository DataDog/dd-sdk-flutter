/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.models

import com.google.gson.JsonArray
import com.google.gson.JsonObject

/**
 * Wraps the Session Replay records together with the related Rum Context.
 * Intended for internal usage.
 */
internal data class EnrichedRecord(
    val applicationId: String,
    val sessionId: String,
    val viewId: String,
    val records: JsonArray
) {

    /**
     * Returns the JSON string equivalent of this object.
     */
    fun toJson(): String {
        val json = JsonObject()
        json.addProperty(APPLICATION_ID_KEY, applicationId)
        json.addProperty(SESSION_ID_KEY, sessionId)
        json.addProperty(VIEW_ID_KEY, viewId)
        json.add(RECORDS_KEY, records)
        return json.toString()
    }

    // These keys are different from Android native, in order to be the same as the keys used iOS
    companion object {
        const val APPLICATION_ID_KEY: String = "applicationID"
        const val SESSION_ID_KEY: String = "sessionID"
        const val VIEW_ID_KEY: String = "viewID"
        const val RECORDS_KEY: String = "records"
    }
}
