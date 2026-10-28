/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2026-Present Datadog, Inc.
 */

package com.datadoghq.flutter

import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isInstanceOf
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureScope
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.feature.StorageBackedFeature
import fr.xgouchet.elmyr.annotation.FloatForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.every
import io.mockk.invoke
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
class TracingContextFeatureTest {
    private val mockCore: FeatureSdkCore = mockk(relaxed = true)
    private val context = mutableMapOf<String, Any?>()

    private fun captureContextUpdates() {
        every { mockCore.updateFeatureContext(any(), any(), captureLambda()) } answers {
            lambda<(MutableMap<String, Any?>) -> Unit>().invoke(context)
        }
    }

    @Test
    fun `M register the feature and publish the rate W publishTraceSampleRate { no tracing feature }`(
        @FloatForgery(min = 0f, max = 100f) sampleRate: Float
    ) {
        // Given
        every { mockCore.getFeature(Feature.TRACING_FEATURE_NAME) } returns null
        captureContextUpdates()

        // When
        TracingContextFeature.publishTraceSampleRate(mockCore, sampleRate)

        // Then
        val registered = slot<Feature>()
        verify { mockCore.registerFeature(capture(registered)) }
        assertThat(registered.captured).isInstanceOf(TracingContextFeature::class)
        assertThat(registered.captured.name).isEqualTo(Feature.TRACING_FEATURE_NAME)
        verify { mockCore.updateFeatureContext(Feature.TRACING_FEATURE_NAME, true, any()) }
        assertThat(context["okhttp_interceptor_sample_rate"]).isEqualTo(sampleRate)
    }

    @Test
    fun `M neither register nor publish W publishTraceSampleRate { native tracing enabled }`(
        @FloatForgery(min = 0f, max = 100f) sampleRate: Float
    ) {
        // Given
        val nativeTracing = mockk<FeatureScope> {
            every { unwrap<Feature>() } returns mockk<StorageBackedFeature>(relaxed = true)
        }
        every { mockCore.getFeature(Feature.TRACING_FEATURE_NAME) } returns nativeTracing

        // When
        TracingContextFeature.publishTraceSampleRate(mockCore, sampleRate)

        // Then
        verify(exactly = 0) { mockCore.registerFeature(any()) }
        verify(exactly = 0) { mockCore.updateFeatureContext(any(), any(), any()) }
    }

    @Test
    fun `M publish without registering again W publishTraceSampleRate { already registered }`(
        @FloatForgery(min = 0f, max = 100f) sampleRate: Float
    ) {
        // Given
        val standIn = mockk<FeatureScope> {
            every { unwrap<Feature>() } returns TracingContextFeature()
        }
        every { mockCore.getFeature(Feature.TRACING_FEATURE_NAME) } returns standIn
        captureContextUpdates()

        // When
        TracingContextFeature.publishTraceSampleRate(mockCore, sampleRate)

        // Then
        verify(exactly = 0) { mockCore.registerFeature(any()) }
        assertThat(context["okhttp_interceptor_sample_rate"]).isEqualTo(sampleRate)
    }
}
