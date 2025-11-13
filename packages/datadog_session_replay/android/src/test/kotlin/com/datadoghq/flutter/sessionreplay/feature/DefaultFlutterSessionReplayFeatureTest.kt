/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isNotNull
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureSdkCore
import fr.xgouchet.elmyr.annotation.BoolForgery
import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.LongForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.every
import io.mockk.invoke
import io.mockk.mockk
import io.mockk.verify
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
internal class DefaultFlutterSessionReplayFeatureTest {
    var mockCore: FeatureSdkCore = mockk(relaxed = true)

    @Test
    fun `M call context changed callback W onContextUpdate`(
        @StringForgery customEndpoint: String,
        @StringForgery applicationId: String,
        @StringForgery sessionId: String,
        @StringForgery viewId: String,
        @LongForgery serverTimeOffset: Long
    ) {
        // Given
        val onContextChanged = mockk<(DefaultFlutterSessionReplayFeature.RumContext) -> Unit>(
            relaxed = true
        )
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            onContextChanged,
            customEndpoint
        )
        val contextValue = mapOf(
            "application_id" to applicationId,
            "session_id" to sessionId,
            "view_id" to viewId,
            "view_timestamp_offset" to serverTimeOffset
        )

        // When
        feature.onContextUpdate(Feature.RUM_FEATURE_NAME, contextValue)

        // Then - note the transform of property names
        val expectedContextValue = DefaultFlutterSessionReplayFeature.RumContext(
            applicationId,
            sessionId,
            viewId,
            serverTimeOffset
        )
        verify { onContextChanged(expectedContextValue) }
    }

    @Test
    fun `M set context W setHasReplay`(
        @StringForgery customEndpoint: String,
        @StringForgery viewId: String,
        @BoolForgery hasReplay: Boolean
    ) {
        // Given
        val onContextChanged = mockk<(DefaultFlutterSessionReplayFeature.RumContext) -> Unit>(
            relaxed = true
        )
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            onContextChanged,
            customEndpoint
        )
        var context = mutableMapOf<String, Any?>()
        every { mockCore.updateFeatureContext(any(), any(), captureLambda()) } answers {
            lambda<(MutableMap<String, Any?>) -> Unit>().invoke(context)
        }

        // When
        feature.setHasReplay(viewId, hasReplay)

        // Then
        verify {
            mockCore.updateFeatureContext(
                Feature.SESSION_REPLAY_FEATURE_NAME,
                true,
                any()
            )
        }
        val viewMap = context[viewId] as? MutableMap<*, *>
        assertThat(viewMap).isNotNull()
        assertThat(viewMap?.get("has_replay")).isEqualTo(hasReplay)
    }

    @Test
    fun `M set context W setRecordCount`(
        @StringForgery customEndpoint: String,
        @StringForgery viewId: String,
        @IntForgery recordCount: Int
    ) {
        // Given
        val onContextChanged = mockk<(DefaultFlutterSessionReplayFeature.RumContext) -> Unit>(
            relaxed = true
        )
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            onContextChanged,
            customEndpoint
        )
        var context = mutableMapOf<String, Any?>()
        every { mockCore.updateFeatureContext(any(), any(), captureLambda()) } answers {
            lambda<(MutableMap<String, Any?>) -> Unit>().invoke(context)
        }

        // When
        feature.setRecordCount(viewId, recordCount)

        // Then
        verify {
            mockCore.updateFeatureContext(
                Feature.SESSION_REPLAY_FEATURE_NAME,
                true,
                any()
            )
        }
        val viewMap = context[viewId] as? MutableMap<String, Any?>
        assertThat(viewMap).isNotNull()
        assertThat(viewMap?.get("has_replay")).isEqualTo(true)
        assertThat(viewMap?.get("records_count")).isEqualTo(recordCount)
    }
}
