/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import android.os.Looper
import assertk.assertThat
import assertk.assertions.isNotNull
import assertk.assertions.isNull
import com.datadog.android.api.feature.FeatureSdkCore
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import kotlin.test.AfterTest
import kotlin.test.Test
import org.junit.jupiter.api.AfterAll
import org.junit.jupiter.api.BeforeAll
import org.junit.jupiter.api.TestInstance

@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class DatadogSessionReplayPluginTest {
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

    private fun makeBinding(messenger: BinaryMessenger): FlutterPlugin.FlutterPluginBinding {
        val binding = mockk<FlutterPlugin.FlutterPluginBinding>(relaxed = true)
        every { binding.binaryMessenger } returns messenger
        return binding
    }

    @Test
    fun `M null contextListener W onDetachedFromEngine with owning engine`() {
        // Given
        val mockMessenger = mockk<BinaryMessenger>(relaxed = true)
        val mockCore: FeatureSdkCore = mockk(relaxed = true)
        val configuration = FlutterSessionReplayBridge.Configuration(
            customEndpointUrl = null,
            onContextChanged = mockk(relaxed = true)
        )
        val plugin = DatadogSessionReplayPlugin()
        plugin.onAttachedToEngine(makeBinding(mockMessenger))
        FlutterSessionReplayBridge.enable(configuration, core = mockCore)
        // Simulate claimOwnership arriving from the Dart method channel
        FlutterSessionReplayBridge.claimOwnership(mockMessenger)

        // When
        plugin.onDetachedFromEngine(makeBinding(mockMessenger))

        // Then
        assertThat(FlutterSessionReplayBridge.contextListener).isNull()
    }

    @Test
    fun `M not null contextListener W onDetachedFromEngine with non-owning engine`() {
        // Given
        val owningMessenger = mockk<BinaryMessenger>(relaxed = true)
        val otherMessenger = mockk<BinaryMessenger>(relaxed = true)
        val mockCore: FeatureSdkCore = mockk(relaxed = true)
        val configuration = FlutterSessionReplayBridge.Configuration(
            customEndpointUrl = null,
            onContextChanged = mockk(relaxed = true)
        )
        val owningPlugin = DatadogSessionReplayPlugin()
        owningPlugin.onAttachedToEngine(makeBinding(owningMessenger))
        FlutterSessionReplayBridge.enable(configuration, core = mockCore)
        FlutterSessionReplayBridge.claimOwnership(owningMessenger)

        val otherPlugin = DatadogSessionReplayPlugin()
        otherPlugin.onAttachedToEngine(makeBinding(otherMessenger))

        // When — other engine detaches before the owning engine
        otherPlugin.onDetachedFromEngine(makeBinding(otherMessenger))

        // Then — owning engine's listener is preserved
        assertThat(FlutterSessionReplayBridge.contextListener).isNotNull()
    }
}
