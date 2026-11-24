/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import android.os.Handler
import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isInstanceOf
import assertk.assertions.isNotEqualTo
import assertk.assertions.isNotNull
import assertk.assertions.isSameInstanceAs
import com.datadog.android.api.InternalLogger
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureScope
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.feature.StorageBackedFeature
import com.datadog.android.internal.FeatureContextKeys
import com.datadog.android.internal.rum.RumContext
import fr.xgouchet.elmyr.annotation.BoolForgery
import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.every
import io.mockk.invoke
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
internal class DefaultFlutterSessionReplayFeatureTest {
    var mockCore: FeatureSdkCore = mockk(relaxed = true)
    val mockHandler: Handler = mockk()

    @BeforeEach
    fun beforeAll() {
        every {
            mockHandler.post(any())
        }.answers {
            val runnable = arg<Runnable>(0)
            runnable.run()
            true
        }
    }

    @Test
    fun `M forward typed RUM context W onContextUpdate`() {
        // Given
        val onContextChanged = mockk<(RumContext?) -> Unit>(relaxed = true)
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            onContextChanged,
            customEndpointUrl = null,
            mainThreadHandler = mockHandler
        )
        val rumContext = mockk<RumContext>()
        val featureContext = mapOf(FeatureContextKeys.RUM_CONTEXT to rumContext)

        // When
        feature.onContextUpdate(Feature.RUM_FEATURE_NAME, featureContext)

        // Then
        verify { onContextChanged(rumContext) }
    }

    @Test
    fun `M read typed RUM context W readCurrentContext`() {
        // Given
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            mockk(relaxed = true),
            customEndpointUrl = null,
            mainThreadHandler = mockHandler
        )
        val rumContext = mockk<RumContext>()
        every { mockCore.getFeatureContext(Feature.RUM_FEATURE_NAME, any()) } returns
            mapOf(FeatureContextKeys.RUM_CONTEXT to rumContext)

        // When
        val context = feature.readCurrentContext()

        // Then
        assertThat(context).isSameInstanceAs(rumContext)
    }

    @Test
    fun `M report no RUM context W onContextUpdate {RUM context cleared}`() {
        // Given
        val onContextChanged = mockk<(RumContext?) -> Unit>(relaxed = true)
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            onContextChanged,
            customEndpointUrl = null,
            mainThreadHandler = mockHandler
        )

        // When
        feature.onContextUpdate(Feature.RUM_FEATURE_NAME, emptyMap())

        // Then
        verify { onContextChanged(null) }
    }

    @Test
    fun `M set context W setHasReplay`(
        @StringForgery customEndpoint: String,
        @StringForgery viewId: String,
        @BoolForgery hasReplay: Boolean
    ) {
        // Given
        val onContextChanged = mockk<(RumContext?) -> Unit>(
            relaxed = true
        )
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            onContextChanged,
            customEndpoint,
            mainThreadHandler = mockHandler
        )
        var context = mutableMapOf<String, Any?>()
        every { mockCore.updateFeatureContext(any(), any(), captureLambda()) } answers {
            lambda<(MutableMap<String, Any?>) -> Unit>().invoke(context)
        }
        every { mockCore.getFeature(Feature.SESSION_REPLAY_FEATURE_NAME) } returns null
        feature.registerSessionReplayContext()

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
        val onContextChanged = mockk<(RumContext?) -> Unit>(
            relaxed = true
        )
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            onContextChanged,
            customEndpoint,
            mainThreadHandler = mockHandler
        )
        var context = mutableMapOf<String, Any?>()
        every { mockCore.updateFeatureContext(any(), any(), captureLambda()) } answers {
            lambda<(MutableMap<String, Any?>) -> Unit>().invoke(context)
        }
        every { mockCore.getFeature(Feature.SESSION_REPLAY_FEATURE_NAME) } returns null
        feature.registerSessionReplayContext()

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
        assertThat(viewMap?.get("records_count")).isEqualTo(recordCount.toLong())
    }

    @Test
    fun `M register the session replay context feature W registerSessionReplayContext {name free}`(
        @StringForgery customEndpoint: String
    ) {
        // Given
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            mockk(relaxed = true),
            customEndpoint,
            mainThreadHandler = mockHandler
        )
        every { mockCore.getFeature(Feature.SESSION_REPLAY_FEATURE_NAME) } returns null

        // When
        feature.registerSessionReplayContext()

        // Then
        val registered = slot<Feature>()
        verify { mockCore.registerFeature(capture(registered)) }
        assertThat(registered.captured).isInstanceOf(SessionReplayContextFeature::class)
        assertThat(registered.captured.name).isEqualTo(Feature.SESSION_REPLAY_FEATURE_NAME)
    }

    @Test
    fun `M publish the privacy levels W registerSessionReplayContext {name free}`(
        @StringForgery customEndpoint: String
    ) {
        // Given
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            mockk(relaxed = true),
            customEndpoint,
            privacyLevels = PrivacyLevels(
                textAndInput = "mask_sensitive_inputs",
                image = "mask_none",
                touch = "show"
            ),
            mainThreadHandler = mockHandler
        )
        val context = mutableMapOf<String, Any?>()
        every { mockCore.updateFeatureContext(any(), any(), captureLambda()) } answers {
            lambda<(MutableMap<String, Any?>) -> Unit>().invoke(context)
        }
        every { mockCore.getFeature(Feature.SESSION_REPLAY_FEATURE_NAME) } returns null

        // When
        feature.registerSessionReplayContext()

        // Then - native WebView tracking reads these when a WebView is tracked
        assertThat(context["session_replay_text_and_input_privacy"]).isEqualTo("mask_sensitive_inputs")
        assertThat(context["session_replay_image_privacy"]).isEqualTo("mask_none")
        assertThat(context["session_replay_touch_privacy"]).isEqualTo("show")
    }

    @Test
    fun `M set session_replay_is_enabled W setSessionSampled`(
        @StringForgery customEndpoint: String,
        @StringForgery sessionId: String,
        @BoolForgery sampled: Boolean
    ) {
        // Given
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            mockk(relaxed = true),
            customEndpoint,
            mainThreadHandler = mockHandler
        )
        val context = mutableMapOf<String, Any?>()
        every { mockCore.updateFeatureContext(any(), any(), captureLambda()) } answers {
            lambda<(MutableMap<String, Any?>) -> Unit>().invoke(context)
        }
        every { mockCore.getFeature(Feature.SESSION_REPLAY_FEATURE_NAME) } returns null
        feature.registerSessionReplayContext()

        // When
        feature.setSessionSampled(sessionId, sampled)

        // Then - native WebView tracking only writes WebView records while this is true
        assertThat(context["session_replay_is_enabled"]).isEqualTo(sampled)
    }

    @Test
    fun `M not register nor publish W registerSessionReplayContext {native Session Replay present}`(
        @StringForgery customEndpoint: String,
        @StringForgery viewId: String
    ) {
        // Given
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            mockk(relaxed = true),
            customEndpoint,
            mainThreadHandler = mockHandler
        )
        val nativeScope = mockk<FeatureScope> {
            every { unwrap<Feature>() } returns mockk<StorageBackedFeature>(relaxed = true)
        }
        every { mockCore.getFeature(Feature.SESSION_REPLAY_FEATURE_NAME) } returns nativeScope

        // When
        feature.registerSessionReplayContext()
        feature.setHasReplay(viewId, true)
        feature.setRecordCount(viewId, 1)
        feature.setSessionSampled(viewId, true)

        // Then
        verify(exactly = 0) { mockCore.registerFeature(any()) }
        verify(exactly = 0) { mockCore.updateFeatureContext(any(), any(), any()) }
        val message = slot<() -> String>()
        verify {
            mockCore.internalLogger.log(
                InternalLogger.Level.WARN,
                InternalLogger.Target.USER,
                capture(message),
                any(),
                any(),
                any()
            )
        }
        assertThat(message.captured())
            .isEqualTo(DefaultFlutterSessionReplayFeature.NATIVE_SESSION_REPLAY_PRESENT_WARNING)
    }

    @Test
    fun `M publish without registering again W registerSessionReplayContext {already registered by Flutter}`(
        @StringForgery customEndpoint: String,
        @StringForgery viewId: String
    ) {
        // Given
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            mockk(relaxed = true),
            customEndpoint,
            mainThreadHandler = mockHandler
        )
        val contextScope = mockk<FeatureScope> {
            every { unwrap<Feature>() } returns SessionReplayContextFeature(mockCore, feature)
        }
        every { mockCore.getFeature(Feature.SESSION_REPLAY_FEATURE_NAME) } returns contextScope

        // When
        feature.registerSessionReplayContext()
        feature.setHasReplay(viewId, true)

        // Then
        verify(exactly = 0) { mockCore.registerFeature(any()) }
        verify { mockCore.updateFeatureContext(Feature.SESSION_REPLAY_FEATURE_NAME, true, any()) }
    }

    @Test
    fun `M not claim the native feature name W registered {hybrid apps}`(
        @StringForgery customEndpoint: String
    ) {
        // Given
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            mockk(relaxed = true),
            customEndpoint,
            mainThreadHandler = mockHandler
        )

        // Then
        // The core keys features by name and the last registration wins, so sharing the native
        // module's name would evict the native Session Replay in a hybrid app — taking its uploads
        // and the embedded-content path with it.
        assertThat(feature.name).isNotEqualTo(Feature.SESSION_REPLAY_FEATURE_NAME)
        assertThat(feature.name)
            .isEqualTo(DefaultFlutterSessionReplayFeature.FLUTTER_SESSION_REPLAY_FEATURE_NAME)
    }
}
