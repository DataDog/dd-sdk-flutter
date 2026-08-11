/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.storage.EventType
import com.datadog.android.api.storage.RawBatchEvent
import com.datadoghq.flutter.sessionreplay.models.ResourceEvent

internal interface ResourceWriter {
    fun write(identifier: String, resourceData: ByteArray)
}

internal class DefaultResourceWriter(
    private val sdkCore: FeatureSdkCore,
    private val resourceDataStoreManager: ResourceDataStoreManager
) : ResourceWriter {
    override fun write(identifier: String, resourceData: ByteArray) {
        if (resourceDataStoreManager.isPreviouslySentResource(identifier)) {
            return
        }

        // cacheResourceHash overwrites the datastore entry, so don't call it until the
        // manager has finished its initial load - otherwise we'd stomp on data we haven't
        // read yet.
        if (resourceDataStoreManager.isReady()) {
            resourceDataStoreManager.cacheResourceHash(identifier)
        }

        sdkCore.getFeature(ResourceFeature.SESSION_REPLAY_RESOURCES_FEATURE_NAME)
            ?.withWriteContext(
                withFeatureContexts = setOf(Feature.RUM_FEATURE_NAME)
            ) { datadogContext, writeScope ->
                synchronized(this) {
                    val resourceEvent = ResourceEvent(
                        identifier = identifier,
                        resourceData = resourceData,
                        applicationId = datadogContext.rumApplicationId
                    )

                    writeScope {
                        it.write(
                            event = RawBatchEvent(
                                data = resourceEvent.resourceData,
                                metadata = resourceEvent.createBinaryMetadata()
                            ),
                            batchMetadata = null,
                            eventType = EventType.DEFAULT
                        )
                    }
                }
            }
    }

    private val DatadogContext.rumApplicationId: String
        get() = (
            featuresContext[Feature.RUM_FEATURE_NAME]
                ?.get("application_id") as? String
            ).orEmpty()
}
