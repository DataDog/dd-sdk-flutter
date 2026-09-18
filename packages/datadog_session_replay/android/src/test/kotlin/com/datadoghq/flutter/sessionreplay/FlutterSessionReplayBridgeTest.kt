/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import android.os.Looper
import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isNotNull
import assertk.assertions.isNull
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadoghq.flutter.sessionreplay.feature.DefaultFlutterSessionReplayFeature
import com.datadoghq.flutter.sessionreplay.resource.ResourceResolver
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.annotation.BoolForgery
import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.plugin.common.BinaryMessenger
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import java.nio.ByteBuffer
import kotlin.test.AfterTest
import kotlin.test.Test
import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.TestInstance
import org.junit.jupiter.api.extension.ExtendWith

internal fun FlutterSessionReplayBridge.enableWithMock(
    mockFeature: DefaultFlutterSessionReplayFeature
) {
    this.feature = mockFeature
}

@ExtendWith(ForgeExtension::class)
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class FlutterSessionReplayBridgeTest {
    @BeforeAll
    fun beforeAll() {
        val mockLooper = mockk<Looper>()
        mockkStatic(Looper::class)
        every { Looper.getMainLooper() }.returns(mockLooper)
    }

    @AfterAll
    fun afterAll() {
        unmockkStatic(Looper::class)
    }

    @AfterTest
    fun afterEach() {
        FlutterSessionReplayBridge.shutdown()
    }

    @Test
    fun `M register the feature W enable`() {
        // Given
        var mockCore: FeatureSdkCore = mockk(relaxed = true)
        val configuration = FlutterSessionReplayBridge.Configuration(
            customEndpointUrl = null,
            onContextChanged = mockk(relaxed = true)
        )

        // When
        FlutterSessionReplayBridge.enable(configuration, core = mockCore)

        // Then
        assertThat(FlutterSessionReplayBridge.feature).isNotNull()
        verify { mockCore.registerFeature(FlutterSessionReplayBridge.feature!!) }
    }

    @Test
    fun `M clear listenerOwner W enable`() {
        // Given — pre-seed a stale owner
        val staleMessenger = mockk<BinaryMessenger>()
        FlutterSessionReplayBridge.claimOwnership(staleMessenger)
        val mockCore: FeatureSdkCore = mockk(relaxed = true)
        val configuration = FlutterSessionReplayBridge.Configuration(
            customEndpointUrl = null,
            onContextChanged = mockk(relaxed = true)
        )

        // When
        FlutterSessionReplayBridge.enable(configuration, core = mockCore)

        // Then — listenerOwner is cleared; claimOwnership() will re-establish it
        assertThat(FlutterSessionReplayBridge.listenerOwner).isNull()
    }

    @Test
    fun `M set listenerOwner W claimOwnership`() {
        // Given
        val mockMessenger = mockk<BinaryMessenger>()

        // When
        FlutterSessionReplayBridge.claimOwnership(mockMessenger)

        // Then
        assertThat(FlutterSessionReplayBridge.listenerOwner).isEqualTo(mockMessenger)
    }

    @Test
    fun `M call setHasReplay on the feature W setHasReplay`(
        @StringForgery viewId: String,
        @BoolForgery hasReplay: Boolean
    ) {
        // Given
        val mockFeature = mockk<DefaultFlutterSessionReplayFeature>(relaxed = true)
        FlutterSessionReplayBridge.enableWithMock(mockFeature)

        // When
        FlutterSessionReplayBridge.setHasReplay(viewId, hasReplay)

        // Then
        verify { mockFeature.setHasReplay(viewId, hasReplay) }
    }

    @Test
    fun `M call setRecordCount on the feature W setRecordCount`(
        @StringForgery viewId: String,
        @IntForgery recordCount: Int
    ) {
        // Given
        val mockFeature = mockk<DefaultFlutterSessionReplayFeature>(relaxed = true)
        FlutterSessionReplayBridge.enableWithMock(mockFeature)

        // When
        FlutterSessionReplayBridge.setRecordCount(viewId, recordCount)

        // Then
        verify { mockFeature.setRecordCount(viewId, recordCount) }
    }

    @Test
    fun `M call writeSegment on the feature W writeSegment`(
        @StringForgery segment: String
    ) {
        // Given
        val mockFeature = mockk<DefaultFlutterSessionReplayFeature>(relaxed = true)
        FlutterSessionReplayBridge.enableWithMock(mockFeature)

        // When
        FlutterSessionReplayBridge.writeSegment(segment)

        // Then
        verify { mockFeature.writeSegment(segment) }
    }

    @Test
    fun `M addResource W saveImageForProcessing`(
        forge: Forge,
        @IntForgery key: Int,
        @IntForgery width: Int,
        @IntForgery height: Int
    ) {
        // Given
        val mockFeature = mockk<DefaultFlutterSessionReplayFeature>(relaxed = true)
        val mockResourceResolver = mockk<ResourceResolver>(relaxed = true)
        every { mockFeature.resourceResolver } returns mockResourceResolver

        FlutterSessionReplayBridge.enableWithMock(mockFeature)

        // When
        val data = ByteBuffer.allocate(forge.anInt(1, 100))
        FlutterSessionReplayBridge.saveImageForProcessing(key, data, width, height)

        // Then
        verify { mockResourceResolver.addResource(key, width, height, data) }
    }

    @Test
    fun `M resolveResource W resourceIdForKey`(
        @IntForgery key: Int,
        @StringForgery resolvedKey: String
    ) {
        // Given
        val mockFeature = mockk<DefaultFlutterSessionReplayFeature>(relaxed = true)
        val mockResourceResolver = mockk<ResourceResolver>(relaxed = true)
        every { mockFeature.resourceResolver } returns mockResourceResolver
        every { mockResourceResolver.resolveResource(key) } returns resolvedKey

        FlutterSessionReplayBridge.enableWithMock(mockFeature)

        // When
        val result = FlutterSessionReplayBridge.resourceIdForKey(key)

        // Then
        verify { mockResourceResolver.resolveResource(key) }
        assertThat(result).isEqualTo(resolvedKey)
    }

    @Test
    fun `M null contextListener only W detachFromEngine with owning messenger`() {
        // Given
        val mockMessenger = mockk<BinaryMessenger>()
        val mockCore: FeatureSdkCore = mockk(relaxed = true)
        val configuration = FlutterSessionReplayBridge.Configuration(
            customEndpointUrl = null,
            onContextChanged = mockk(relaxed = true)
        )
        FlutterSessionReplayBridge.enable(configuration, core = mockCore)
        FlutterSessionReplayBridge.claimOwnership(mockMessenger)

        // When
        FlutterSessionReplayBridge.detachFromEngine(mockMessenger)

        // Then
        assertThat(FlutterSessionReplayBridge.contextListener).isNull()
        assertThat(FlutterSessionReplayBridge.feature).isNotNull()
    }

    @Test
    fun `M not null contextListener W detachFromEngine with non-owning messenger`() {
        // Given
        val owningMessenger = mockk<BinaryMessenger>()
        val otherMessenger = mockk<BinaryMessenger>()
        val mockCore: FeatureSdkCore = mockk(relaxed = true)
        val configuration = FlutterSessionReplayBridge.Configuration(
            customEndpointUrl = null,
            onContextChanged = mockk(relaxed = true)
        )
        FlutterSessionReplayBridge.enable(configuration, core = mockCore)
        FlutterSessionReplayBridge.claimOwnership(owningMessenger)

        // When — a different engine detaches
        FlutterSessionReplayBridge.detachFromEngine(otherMessenger)

        // Then — listener is preserved
        assertThat(FlutterSessionReplayBridge.contextListener).isNotNull()
        assertThat(FlutterSessionReplayBridge.feature).isNotNull()
    }
}
