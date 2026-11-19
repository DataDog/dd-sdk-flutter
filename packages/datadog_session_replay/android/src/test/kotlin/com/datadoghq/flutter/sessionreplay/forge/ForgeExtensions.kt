/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.forge

import com.datadoghq.flutter.sessionreplay.models.EnrichedRecord
import com.datadoghq.flutter.sessionreplay.models.MobileSegment
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import fr.xgouchet.elmyr.Forge
import java.util.UUID

internal fun Forge.anEnrichedRecord(): EnrichedRecord {
    return EnrichedRecord(
        applicationId = getForgery<UUID>().toString(),
        sessionId = getForgery<UUID>().toString(),
        viewId = getForgery<UUID>().toString(),
        records = aFakeRecordsArray()
    )
}

internal fun Forge.aMobileSegment(): MobileSegment {
    return MobileSegment(
        application = MobileSegment.Application(getForgery<UUID>().toString()),
        session = MobileSegment.Session(getForgery<UUID>().toString()),
        view = MobileSegment.View(getForgery<UUID>().toString()),
        start = aPositiveLong(),
        end = aPositiveLong(),
        recordsCount = aPositiveLong(),
        indexInView = aNullable { aPositiveLong() },
        hasFullSnapshot = aNullable { aBool() },
        source = aString(),
        records = aFakeRecordsArray()
    )
}

private fun Forge.aFakeRecordsArray(): JsonArray {
    val records = JsonArray()
    repeat(anInt(min = 1, max = 5)) {
        records.add(getForgery<JsonObject>())
    }
    return records
}
