/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import android.content.Context
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureEventReceiver
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.feature.StorageBackedFeature
import com.datadog.android.api.net.RequestFactory
import com.datadog.android.api.storage.FeatureStorageConfiguration

/**
 * Stands in for the native Session Replay feature under [Feature.SESSION_REPLAY_FEATURE_NAME] when
 * Flutter Session Replay runs standalone, so that the replay state Flutter publishes in that context
 * (`has_replay`, record counts) reaches RUM — the core drops updates to the context of an
 * unregistered feature.
 *
 * Only registered when no native Session Replay is present.
 */
internal class SessionReplayContextFeature(
    private val sdkCore: FeatureSdkCore,
    private val delegate: StorageBackedFeature
) : StorageBackedFeature, FeatureEventReceiver {

    override val name: String = Feature.SESSION_REPLAY_FEATURE_NAME

    override val requestFactory: RequestFactory
        get() = delegate.requestFactory

    override val storageConfiguration: FeatureStorageConfiguration
        get() = delegate.storageConfiguration

    override fun onInitialize(appContext: Context) {
        sdkCore.setEventReceiver(name, this)
    }

    override fun onStop() {
        sdkCore.removeEventReceiver(name)
    }

    override fun onReceive(event: Any) {
    }
}
