/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */

// This file is copied from the `dd-sdk-android`.
package com.datadoghq.flutter.sessionreplay.gson

import com.datadog.android.api.InternalLogger
import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import java.util.Locale

internal const val BROKEN_JSON_ERROR_MESSAGE_FORMAT =
    "SR GsonExt: Unable parse the batch data into a JsonObject: expected to parse [%s] as %s"
internal const val JSON_OBJECT_TYPE = "JsonObject"
internal const val JSON_ARRAY_TYPE = "JsonArray"
internal const val JSON_STRING_TYPE = "JsonString"
internal const val JSON_PRIMITIVE_TYPE = "JsonPrimitive"

internal fun JsonElement.safeAsJsonObject(internalLogger: InternalLogger): JsonObject? {
    return if (isJsonObject) {
        asJsonObject
    } else {
        internalLogger.log(
            InternalLogger.Level.ERROR,
            InternalLogger.Target.TELEMETRY,
            {
                BROKEN_JSON_ERROR_MESSAGE_FORMAT.format(
                    Locale.US,
                    this.toString(),
                    JSON_OBJECT_TYPE
                )
            }
        )
        null
    }
}

internal fun JsonObject.safeGetAsLong(internalLogger: InternalLogger, key: String): Long? {
    return try {
        get(key)?.asLong
    } catch (e: NumberFormatException) {
        internalLogger.log(
            InternalLogger.Level.ERROR,
            InternalLogger.Target.TELEMETRY,
            {
                BROKEN_JSON_ERROR_MESSAGE_FORMAT.format(
                    Locale.US,
                    this.toString(),
                    JSON_PRIMITIVE_TYPE
                )
            },
            e
        )
        null
    }
}

internal fun JsonObject.safeGetAsJsonArray(
    internalLogger: InternalLogger,
    key: String
): JsonArray? {
    return get(key)?.let { jsonElement ->
        return if (jsonElement.isJsonArray) {
            jsonElement.asJsonArray
        } else {
            internalLogger.log(
                InternalLogger.Level.ERROR,
                InternalLogger.Target.TELEMETRY,
                {
                    BROKEN_JSON_ERROR_MESSAGE_FORMAT.format(
                        Locale.US,
                        this.toString(),
                        JSON_ARRAY_TYPE
                    )
                }
            )
            null
        }
    }
}

internal fun JsonObject.safeGetAsString(internalLogger: InternalLogger, key: String): String? {
    return try {
        get(key)?.asString
    } catch (e: ClassCastException) {
        // this should never happen - element is a valid json already
        internalLogger.log(
            level = InternalLogger.Level.ERROR,
            target = InternalLogger.Target.MAINTAINER,
            messageBuilder = {
                BROKEN_JSON_ERROR_MESSAGE_FORMAT.format(
                    Locale.US,
                    this.toString(),
                    JSON_STRING_TYPE
                )
            },
            throwable = e
        )
        null
    } catch (e: IllegalStateException) {
        internalLogger.log(
            level = InternalLogger.Level.ERROR,
            target = InternalLogger.Target.MAINTAINER,
            messageBuilder = {
                BROKEN_JSON_ERROR_MESSAGE_FORMAT.format(
                    Locale.US,
                    this.toString(),
                    JSON_STRING_TYPE
                )
            },
            throwable = e
        )
        null
    }
}
