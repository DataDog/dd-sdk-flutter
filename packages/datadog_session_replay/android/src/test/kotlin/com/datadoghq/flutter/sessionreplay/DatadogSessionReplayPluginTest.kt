/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import android.view.View
import assertk.assertThat
import assertk.assertions.containsExactly
import assertk.assertions.hasSize
import assertk.assertions.isEmpty
import assertk.assertions.isEqualTo
import assertk.assertions.isFalse
import assertk.assertions.isNull
import assertk.assertions.isTrue
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadoghq.flutter.sessionreplay.feature.DefaultFlutterSessionReplayFeature
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import io.mockk.CapturingSlot
import io.mockk.every
import io.mockk.mockk
import java.nio.ByteBuffer
import kotlin.test.Test
import org.junit.jupiter.api.extension.ExtendWith

/**
 * Tests the plugin's only job: pairing an engine's messenger with the bridge that engine created
 * over FFI, and releasing it again on detach.
 *
 * Each case builds its own manager and injects it, so nothing touches
 * [FlutterSessionReplayManager.shared].
 */
@ExtendWith(ForgeExtension::class)
internal class DatadogSessionReplayPluginTest {
    private val mockCore: FeatureSdkCore = mockk(relaxed = true)
    private val mockFeature: DefaultFlutterSessionReplayFeature = mockk(relaxed = true)
    private val embedded = EmbeddedSessionReplaySpy()
    private val manager = FlutterSessionReplayManager(mockFeature, embedded)

    /**
     * One engine: a messenger, the plugin attached to it, and the handler that plugin installed on
     * the engine channel.
     *
     * The handler is captured off the messenger rather than the channel being driven directly,
     * because sending an encoded call through it is exactly what the real engine does when Dart
     * invokes `registerEngine`.
     */
    private inner class Engine {
        val messenger = mockk<BinaryMessenger>(relaxed = true)
        val plugin = DatadogSessionReplayPlugin.create(manager)
        private var handler: BinaryMessenger.BinaryMessageHandler? = null

        init {
            // Nullable, because `setMethodCallHandler(null)` on detach comes through here too.
            val handlerSlot = CapturingSlot<BinaryMessenger.BinaryMessageHandler?>()
            every {
                messenger.setMessageHandler(
                    DatadogSessionReplayPlugin.ENGINE_CHANNEL_NAME,
                    captureNullable(handlerSlot)
                )
            } answers { handler = handlerSlot.captured }
            plugin.onAttachedToEngine(binding())
        }

        fun binding(): FlutterPlugin.FlutterPluginBinding {
            val binding = mockk<FlutterPlugin.FlutterPluginBinding>(relaxed = true)
            every { binding.binaryMessenger } returns messenger
            return binding
        }

        /** Delivers a call over the engine channel, as Dart invoking it would. */
        fun invoke(method: String, arguments: Any?): ByteBuffer? {
            val message = StandardMethodCodec.INSTANCE
                .encodeMethodCall(MethodCall(method, arguments))
                .also { it.flip() }
            var reply: ByteBuffer? = null
            val channelHandler = checkNotNull(handler) {
                "The plugin did not install a handler on the engine channel."
            }
            channelHandler.onMessage(message) { reply = it }
            return reply
        }

        /** A bridge that has enabled against the shared manager, as Dart's `enable()` does. */
        fun enableBridge(): FlutterSessionReplayBridge {
            val bridge = FlutterSessionReplayBridge.create(manager)
            bridge.enable(
                FlutterSessionReplayBridge.Configuration(onContextChanged = mockk(relaxed = true)),
                core = mockCore
            )
            bridge.setEmbedded(true)
            return bridge
        }
    }

    /** Whether the encoded [reply] is an error envelope rather than a success one. */
    private fun isError(reply: ByteBuffer?): Boolean {
        val buffer = checkNotNull(reply) { "The plugin did not reply." }
        buffer.position(0)
        // StandardMethodCodec tags a success envelope with 0 and an error envelope with 1.
        return buffer.get() != 0.toByte()
    }

    private fun segment(viewId: String, type: Int) =
        """{"records":[{"type":$type}],"viewID":"$viewId"}"""

    @Test
    fun `M route the engine's segments to its slot W registerEngine`(
        @StringForgery viewId: String
    ) {
        // Given - an engine whose host has registered its Flutter view
        val engine = Engine()
        val bridge = engine.enableBridge()
        val hostView = mockk<View>()
        manager.registerSlot(hostView, engine.messenger)

        // When - Dart hands over the token of the bridge it just created
        val reply = engine.invoke(
            DatadogSessionReplayPlugin.REGISTER_ENGINE_METHOD,
            bridge.engineToken
        )
        bridge.writeSegment(segment(viewId, type = 1))

        // Then - the bridge can resolve this engine's slot, which is the whole point of the pairing
        assertThat(isError(reply)).isFalse()
        assertThat(embedded.recordBatches).hasSize(1)
        assertThat(embedded.recordBatches[0].slotId).isEqualTo(embedded.slotIdOf(hostView))
        assertThat(embedded.recordBatches[0].viewId).isEqualTo(viewId)
    }

    @Test
    fun `M error W registerEngine without a token`() {
        // Given
        val engine = Engine()

        // When
        val reply = engine.invoke(DatadogSessionReplayPlugin.REGISTER_ENGINE_METHOD, null)

        // Then - failing loudly beats silently leaving the engine unpaired and its records buffering
        assertThat(isError(reply)).isTrue()
    }

    @Test
    fun `M reply notImplemented W an unknown method`(
        @StringForgery method: String
    ) {
        // Given
        val engine = Engine()

        // When
        val reply = engine.invoke(method, null)

        // Then - notImplemented is encoded as a null reply
        assertThat(reply).isNull()
    }

    @Test
    fun `M stop routing this engine's segments W onDetachedFromEngine`(
        @StringForgery viewId: String
    ) {
        // Given - a paired engine that has been recording into its slot
        val engine = Engine()
        val bridge = engine.enableBridge()
        manager.registerSlot(mockk<View>(), engine.messenger)
        engine.invoke(DatadogSessionReplayPlugin.REGISTER_ENGINE_METHOD, bridge.engineToken)
        bridge.writeSegment(segment(viewId, type = 1))
        val batchesBeforeDetach = embedded.recordBatches.size

        // When - the engine goes away and a segment already in flight lands
        engine.plugin.onDetachedFromEngine(engine.binding())
        bridge.writeSegment(segment(viewId, type = 2))

        // Then - nothing more reaches the native recording. This is the same teardown that releases
        // the Dart context callback, so a later context update cannot call into a destroyed isolate.
        assertThat(embedded.recordBatches).hasSize(batchesBeforeDetach)
    }

    @Test
    fun `M leave other engines recording W onDetachedFromEngine`(
        @StringForgery viewId: String
    ) {
        // Given - two engines, as in a host with a pre-warmed secondary engine
        val first = Engine()
        val firstBridge = first.enableBridge()
        manager.registerSlot(mockk<View>(), first.messenger)
        first.invoke(DatadogSessionReplayPlugin.REGISTER_ENGINE_METHOD, firstBridge.engineToken)

        val second = Engine()
        val secondBridge = second.enableBridge()
        manager.registerSlot(mockk<View>(), second.messenger)
        second.invoke(DatadogSessionReplayPlugin.REGISTER_ENGINE_METHOD, secondBridge.engineToken)

        // When - only the second engine detaches
        second.plugin.onDetachedFromEngine(second.binding())
        firstBridge.writeSegment(segment(viewId, type = 1))
        secondBridge.writeSegment(segment(viewId, type = 2))

        // Then - the still-live engine is undisturbed
        assertThat(embedded.recordBatches).hasSize(1)
        assertThat(embedded.recordBatches.map { it.slotId })
            .containsExactly(manager.slotId(first.messenger))
    }

    @Test
    fun `M ignore an unknown token W registerEngine`(
        @StringForgery unknownToken: String,
        @StringForgery viewId: String
    ) {
        // Given - a stale token, e.g. from a bridge replaced by a Hot Restart
        val engine = Engine()
        val bridge = engine.enableBridge()
        manager.registerSlot(mockk<View>(), engine.messenger)

        // When
        engine.invoke(DatadogSessionReplayPlugin.REGISTER_ENGINE_METHOD, unknownToken)
        bridge.writeSegment(segment(viewId, type = 1))

        // Then - the bridge stays unpaired and keeps buffering, rather than being handed a messenger
        // that belongs to some other engine
        assertThat(embedded.recordBatches).isEmpty()
    }
}
