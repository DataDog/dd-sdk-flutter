/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import android.content.Context
import android.os.Handler
import android.os.Looper
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
import com.datadoghq.flutter.sessionreplay.resource.EmbeddedResourceSink
import com.datadoghq.flutter.sessionreplay.resource.ResourceDataStoreManager
import com.datadoghq.flutter.sessionreplay.resource.ResourceFeature
import com.datadoghq.flutter.sessionreplay.resource.ResourceResolver
import com.datadoghq.flutter.sessionreplay.resource.RoutedResourceWriter

internal interface FlutterSessionReplayFeature : StorageBackedFeature {
    fun setHasReplay(viewId: String, hasReplay: Boolean)
    fun setRecordCount(viewId: String, recordCount: Int)
    fun writeSegment(segment: String)
    fun readCurrentContext(): DefaultFlutterSessionReplayFeature.RumContext?

    val resourceResolver: ResourceResolver
}

internal class DefaultFlutterSessionReplayFeature(
    private val sdkCore: FeatureSdkCore,
    private val onContextChanged: (RumContext) -> Unit,
    private val customEndpointUrl: String?,
    private val embeddedResourceSink: EmbeddedResourceSink = { _, _, _ -> false },
    private val mainThreadHandler: Handler = Handler(Looper.getMainLooper())
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

    override lateinit var resourceResolver: ResourceResolver

    override val name = FLUTTER_SESSION_REPLAY_FEATURE_NAME
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
            FLUTTER_SESSION_REPLAY_FEATURE_NAME,
            this
        )

        val resourcesFeature = ResourceFeature(
            sdkCore,
            customEndpointUrl
        )
        sdkCore.registerFeature(resourcesFeature)

        // ResourceDataStoreManager loads its known-resources entry eagerly on construction,
        // so it must be created after the resources feature above is registered.
        resourceResolver = DefaultResourceResolver(
            sdkCore.internalLogger,
            RoutedResourceWriter(
                DefaultResourceWriter(sdkCore, ResourceDataStoreManager(sdkCore)),
                embeddedResourceSink
            )
        )
    }

    /**
     * The RUM context as it stands right now, rather than at the next change.
     *
     * Used to prime an engine that enables while a RUM view is already active — see
     * `FlutterSessionReplayManager.primeContext`. Returns `null` when RUM has published no context
     * yet, in which case [onContextUpdate] delivers the first one soon enough.
     */
    override fun readCurrentContext(): RumContext? {
        val context = sdkCore.getFeatureContext(Feature.RUM_FEATURE_NAME)
        if (context.isEmpty()) {
            return null
        }
        return RumContext(context)
    }

    override fun onStop() {
    }

    override fun onReceive(event: Any) {
    }

    override fun onContextUpdate(featureName: String, context: Map<String, Any?>) {
        if (featureName == Feature.RUM_FEATURE_NAME) {
            val rumContext = RumContext(context)
            mainThreadHandler.post {
                onContextChanged(rumContext)
            }
        }
    }

    // Both of these stay on [Feature.SESSION_REPLAY_FEATURE_NAME], unlike the registration above:
    // that context is where RUM reads `has_replay` and the record counts from, regardless of which
    // feature wrote them. Only the standalone path reaches here, so there is no native Session
    // Replay to contend with — see `FlutterSessionReplayBridge.publishesReplayState`.
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
        sdkCore.getFeature(FLUTTER_SESSION_REPLAY_FEATURE_NAME)
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
         * The name this feature registers under, deliberately not [Feature.SESSION_REPLAY_FEATURE_NAME].
         *
         * The core keys features by name and a later registration replaces an earlier one, so
         * claiming the native module's name in a hybrid app would evict the native Session Replay
         * from the core — breaking its uploads, and with them the embedded-content path this plugin
         * hands Flutter records to. Matches the iOS plugin, which registers `flutter-session-replay`
         * for the same reason.
         */
        internal const val FLUTTER_SESSION_REPLAY_FEATURE_NAME = "flutter-session-replay"

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
