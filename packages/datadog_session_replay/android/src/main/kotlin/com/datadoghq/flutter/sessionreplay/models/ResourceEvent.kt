/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.models

import com.google.gson.JsonObject

/**
 * Copied from dd-sdk-android.
 */
internal data class ResourceEvent(
    val applicationId: String,
    val identifier: String,
    val resourceData: ByteArray
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as ResourceEvent

        if (applicationId != other.applicationId) return false
        if (identifier != other.identifier) return false
        return resourceData.contentEquals(other.resourceData)
    }

    override fun hashCode(): Int {
        var result = applicationId.hashCode()
        result = 31 * result + identifier.hashCode()
        result = 31 * result + resourceData.contentHashCode()
        return result
    }

    fun createBinaryMetadata(): ByteArray {
        val jsonObject = JsonObject()
        jsonObject.addProperty(APPLICATION_ID_KEY, applicationId)
        jsonObject.addProperty(FILENAME_KEY, identifier)
        return jsonObject.toString().toByteArray(Charsets.UTF_8)
    }

    internal companion object {
        internal const val APPLICATION_ID_KEY = "applicationId"
        internal const val FILENAME_KEY = "filename"
    }
}
