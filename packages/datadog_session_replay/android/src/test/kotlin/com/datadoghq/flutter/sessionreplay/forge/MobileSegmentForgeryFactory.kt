/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.forge

import com.datadoghq.flutter.sessionreplay.models.MobileSegment
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.ForgeryFactory
import java.util.UUID

internal class MobileSegmentForgeryFactory : ForgeryFactory<MobileSegment> {
    override fun getForgery(forge: Forge): MobileSegment {
        val fakeRecords = JsonArray()
        forge.aList(size = forge.anInt(min = 1, max = 5)) {
            getForgery<JsonObject>()
        }.forEach {
            fakeRecords.add(it)
        }
        return MobileSegment(
            application = MobileSegment.Application(forge.getForgery<UUID>().toString()),
            session = MobileSegment.Session(forge.getForgery<UUID>().toString()),
            view = MobileSegment.View(forge.getForgery<UUID>().toString()),
            start = forge.aPositiveLong(),
            end = forge.aPositiveLong(),
            recordsCount = forge.aPositiveLong(),
            indexInView = forge.aNullable { aPositiveLong() },
            hasFullSnapshot = forge.aNullable { aBool() },
            source = forge.aString(),
            records = fakeRecords
        )
    }
}
