/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import android.content.Context
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.feature.StorageBackedFeature
import com.datadog.android.api.net.RequestFactory
import com.datadog.android.api.storage.FeatureStorageConfiguration

class ResourceFeature(
    private val sdkCore: FeatureSdkCore,
    customEndpointUrl: String?
) : StorageBackedFeature {
    override val name: String = SESSION_REPLAY_RESOURCES_FEATURE_NAME

    override val requestFactory: RequestFactory = ResourceRequestFactory(
        customEndpointUrl,
        sdkCore.internalLogger
    )

    override val storageConfiguration: FeatureStorageConfiguration = STORAGE_CONFIGURATION

    override fun onInitialize(appContext: Context) {
    }

    override fun onStop() {
    }

    internal companion object {
        /**
         * Session Replay Resources storage configuration with the following parameters:
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

        internal const val SESSION_REPLAY_RESOURCES_FEATURE_NAME = "session-replay-resources"
    }
}
