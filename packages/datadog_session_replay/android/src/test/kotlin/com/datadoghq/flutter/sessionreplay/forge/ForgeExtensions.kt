/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.forge

import com.google.gson.JsonArray
import com.google.gson.JsonObject
import fr.xgouchet.elmyr.Forge

/**
 * A fake `records` array — 1 to 5 forged JSON objects standing in for actual session replay
 * records — shared by every factory whose forgery carries one (`EnrichedRecord`, `MobileSegment`).
 */
internal fun Forge.aFakeRecordsArray(): JsonArray {
    val fakeRecords = JsonArray()
    aList(size = anInt(min = 1, max = 5)) {
        getForgery<JsonObject>()
    }.forEach {
        fakeRecords.add(it)
    }
    return fakeRecords
}
