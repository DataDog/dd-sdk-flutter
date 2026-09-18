/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.forge

import com.datadoghq.flutter.sessionreplay.models.EnrichedRecord
import com.google.gson.JsonArray
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.ForgeryFactory
import java.util.UUID

internal class EnrichedRecordForgeryFactory : ForgeryFactory<EnrichedRecord> {
    override fun getForgery(forge: Forge): EnrichedRecord {
        return EnrichedRecord(
            applicationId = forge.getForgery<UUID>().toString(),
            sessionId = forge.getForgery<UUID>().toString(),
            viewId = forge.getForgery<UUID>().toString(),
            JsonArray()
        )
    }
}
