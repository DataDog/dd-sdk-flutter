/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import android.content.Context
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureContextUpdateReceiver
import com.datadog.android.api.feature.FeatureEventReceiver
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.feature.StorageBackedFeature
import com.datadog.android.api.net.RequestFactory
import com.datadog.android.api.storage.EventType
import com.datadog.android.api.storage.FeatureStorageConfiguration
import com.datadog.android.api.storage.RawBatchEvent
import com.datadoghq.flutter.sessionreplay.resource.DefaultResourceResolver
import com.datadoghq.flutter.sessionreplay.resource.DefaultResourceWriter
import com.datadoghq.flutter.sessionreplay.resource.ResourceFeature
import com.datadoghq.flutter.sessionreplay.resource.ResourceResolver

internal interface FlutterSessionReplayFeature : StorageBackedFeature {
    fun setHasReplay(viewId: String, hasReplay: Boolean)
    fun setRecordCount(viewId: String, recordCount: Int)
    fun writeSegment(segment: String)

    val resourceResolver: ResourceResolver
}

internal class DefaultFlutterSessionReplayFeature(
    private val sdkCore: FeatureSdkCore,
    private val onContextChanged: (RumContext) -> Unit,
    private val customEndpointUrl: String?
) : FlutterSessionReplayFeature,
    StorageBackedFeature,
    FeatureEventReceiver,
    FeatureContextUpdateReceiver {
    data class RumContext(
        val applicationId: String?,
        val sessionId: String?,
        val viewId: String?,
        val viewServerTimeOffset: Long?
    ) {
        constructor(event: Map<String, Any?>) : this(
            applicationId = event[APPLICATION_ID_KEY] as? String,
            sessionId = event[SESSION_ID_KEY] as? String,
            viewId = event[VIEW_ID_KEY] as? String,
            viewServerTimeOffset = event[VIEW_SERVER_TIME_OFFSET_KEY] as? Long
        )
    }

    override val resourceResolver = DefaultResourceResolver(
        sdkCore.internalLogger,
        DefaultResourceWriter(sdkCore)
    )

    override val name = Feature.SESSION_REPLAY_FEATURE_NAME
    override val storageConfiguration = STORAGE_CONFIGURATION

    override val requestFactory: RequestFactory by lazy {
        SegmentRequestFactory(
            customEndpointUrl,
            BatchesToSegmentsMapper(sdkCore.internalLogger)
        )
    }

    override fun onInitialize(appContext: Context) {
        sdkCore.setContextUpdateReceiver(
            this
        )
        sdkCore.setEventReceiver(
            Feature.SESSION_REPLAY_FEATURE_NAME,
            this
        )

        val resourcesFeature = ResourceFeature(
            sdkCore,
            customEndpointUrl
        )
        sdkCore.registerFeature(resourcesFeature)
    }

    override fun onStop() {
    }

    override fun onReceive(event: Any) {
    }

    override fun onContextUpdate(featureName: String, event: Map<String, Any?>) {
        if (featureName == Feature.RUM_FEATURE_NAME) {
            val context = RumContext(event)
            onContextChanged(context)
        }
    }

    override fun setHasReplay(viewId: String, hasReplay: Boolean) {
        sdkCore.updateFeatureContext(Feature.SESSION_REPLAY_FEATURE_NAME) {
            @Suppress("UNCHECKED_CAST")
            val viewMetadata: MutableMap<String, Any?> =
                (it[viewId] as? MutableMap<String, Any?>) ?: mutableMapOf()
            viewMetadata[HAS_REPLAY_KEY] = hasReplay
            it[viewId] = viewMetadata
        }
    }

    override fun setRecordCount(viewId: String, recordCount: Int) {
        sdkCore.updateFeatureContext(Feature.SESSION_REPLAY_FEATURE_NAME) {
            @Suppress("UNCHECKED_CAST")
            val viewMetadata: MutableMap<String, Any?> =
                (it[viewId] as? MutableMap<String, Any?>) ?: mutableMapOf()
            viewMetadata[HAS_REPLAY_KEY] = true
            viewMetadata[VIEW_RECORDS_COUNT_KEY] = recordCount
            it[viewId] = viewMetadata
        }
    }

    override fun writeSegment(segment: String) {
        sdkCore.getFeature(Feature.SESSION_REPLAY_FEATURE_NAME)
            ?.withWriteContext { _, writeScope ->
                synchronized(this) {
                    val serializedSegment = segment.toByteArray(Charsets.UTF_8)
                    val rawBatchEvent = RawBatchEvent(data = serializedSegment)
                    writeScope {
                        it.write(
                            event = rawBatchEvent,
                            batchMetadata = null,
                            eventType = EventType.DEFAULT
                        )
                    }
                }
            }
    }

    companion object {
        /**
         * Session Replay storage configuration with the following parameters:
         * max item size = 10 MB,
         * max items per batch = 500,
         * max batch size = 10 MB, SR intake batch limit is 10MB
         * old batch threshold = 18 hours.
         */
        internal val STORAGE_CONFIGURATION: FeatureStorageConfiguration =
            FeatureStorageConfiguration.DEFAULT.copy(
                maxItemSize = 10 * 1024 * 1024,
                maxBatchSize = 10 * 1024 * 1024
            )

        const val HAS_REPLAY_KEY = "has_replay"
        const val VIEW_RECORDS_COUNT_KEY = "records_count"

        const val APPLICATION_ID_KEY = "application_id"
        const val SESSION_ID_KEY = "session_id"
        const val VIEW_ID_KEY = "view_id"
        const val VIEW_SERVER_TIME_OFFSET_KEY = "view_timestamp_offset"
    }
}
