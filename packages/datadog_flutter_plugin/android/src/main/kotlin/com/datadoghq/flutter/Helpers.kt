/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import com.google.gson.JsonPrimitive
import io.flutter.plugin.common.MethodChannel
import java.util.Date

fun MethodChannel.Result.missingParameter(methodName: String, details: Any? = null) {
    this.error(
        DatadogSdkPlugin.CONTRACT_VIOLATION,
        "Missing required parameter in call to $methodName",
        details
    )
}

fun MethodChannel.Result.invalidOperation(message: String, details: Any? = null) {
    this.error(
        DatadogSdkPlugin.INVALID_OPERATION,
        message,
        details
    )
}

internal fun Any?.fromJsonElement(): Any? {
    return when (this) {
        is JsonNull -> null
        is JsonPrimitive -> {
            if (this.isBoolean) {
                this.asBoolean
            } else if (this.isNumber) {
                this.asNumber
            } else if (this.isString) {
                this.asString
            } else {
                this
            }
        }
        is JsonArray -> {
            val array = mutableListOf<Any?>()
            this.forEach {
                array.add(it.fromJsonElement())
            }
            array
        }
        is JsonObject -> this.asMap()
        else -> this
    }
}

internal fun JsonObject.asMap(): Map<String, Any?> {
    val map = mutableMapOf<String, Any?>()
    entrySet().forEach {
        map[it.key] = it.value.fromJsonElement()
    }
    return map
}

internal fun JsonElement?.asMap(): Map<String, Any?> {
    return if (this is JsonObject) {
        this.asMap()
    } else {
        emptyMap()
    }
}

internal fun Any?.toJsonElement(): JsonElement {
    return when (this) {
        null -> JsonNull.INSTANCE
        JsonNull.INSTANCE -> JsonNull.INSTANCE
        is Boolean -> JsonPrimitive(this)
        is Int -> JsonPrimitive(this)
        is Long -> JsonPrimitive(this)
        is Float -> JsonPrimitive(this)
        is Double -> JsonPrimitive(this)
        is String -> JsonPrimitive(this)
        is Date -> JsonPrimitive(this.time)
        is Iterable<*> -> this.toJsonArray()
        is Map<*, *> -> this.toJsonObject()
        else -> JsonPrimitive(toString())
    }
}

internal fun Iterable<*>.toJsonArray(): JsonElement {
    val array = JsonArray()
    forEach {
        array.add(it.toJsonElement())
    }
    return array
}

internal fun Map<*, *>.toJsonObject(): JsonObject {
    val obj = JsonObject()
    forEach {
        obj.add(it.key.toString(), it.value.toJsonElement())
    }
    return obj
}
