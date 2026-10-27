/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isSameInstanceAs
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.feature.StorageBackedFeature
import com.datadog.android.api.net.RequestFactory
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.jupiter.api.Test

internal class SessionReplayContextFeatureTest {
    private val mockCore: FeatureSdkCore = mockk(relaxed = true)
    private val mockDelegate: StorageBackedFeature = mockk(relaxed = true)
    private val feature = SessionReplayContextFeature(mockCore, mockDelegate)

    @Test
    fun `M use the native Session Replay feature name W name`() {
        // Then
        assertThat(feature.name).isEqualTo(Feature.SESSION_REPLAY_FEATURE_NAME)
    }

    @Test
    fun `M route to the Flutter feature W requestFactory and storageConfiguration`() {
        // Given
        val requestFactory = mockk<RequestFactory>()
        every { mockDelegate.requestFactory } returns requestFactory
        every { mockDelegate.storageConfiguration } returns
            DefaultFlutterSessionReplayFeature.STORAGE_CONFIGURATION

        // Then
        assertThat(feature.requestFactory).isSameInstanceAs(requestFactory)
        assertThat(feature.storageConfiguration)
            .isEqualTo(DefaultFlutterSessionReplayFeature.STORAGE_CONFIGURATION)
    }

    @Test
    fun `M handle RUM messages W onInitialize and onStop`() {
        // When
        feature.onInitialize(mockk(relaxed = true))
        feature.onStop()

        // Then
        verify { mockCore.setEventReceiver(Feature.SESSION_REPLAY_FEATURE_NAME, feature) }
        verify { mockCore.removeEventReceiver(Feature.SESSION_REPLAY_FEATURE_NAME) }
    }
}
