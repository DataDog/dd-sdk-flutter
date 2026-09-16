/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import android.view.View
import assertk.assertThat
import assertk.assertions.hasSize
import assertk.assertions.isEmpty
import assertk.assertions.isEqualTo
import assertk.assertions.isFalse
import assertk.assertions.isNotEqualTo
import assertk.assertions.isNotNull
import assertk.assertions.isNull
import assertk.assertions.isSameInstanceAs
import assertk.assertions.isTrue
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadoghq.flutter.sessionreplay.feature.DefaultFlutterSessionReplayFeature
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.plugin.common.BinaryMessenger
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import kotlin.test.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource

/**
 * Tests the process-wide coordinator: the shared feature, context fan-out across engines, the host
 * slot-ID registry, and the two native paths (records and resources).
 */
@ExtendWith(ForgeExtension::class)
internal class FlutterSessionReplayManagerTest {
    private val mockCore: FeatureSdkCore = mockk(relaxed = true)
    private val mockFeature: DefaultFlutterSessionReplayFeature = mockk(relaxed = true)
    private val embedded = EmbeddedSessionReplaySpy()
    private val manager = FlutterSessionReplayManager(mockFeature, embedded)

    /** Puts the manager in the embedded state and returns the messenger it was registered under. */
    private fun embed(): BinaryMessenger {
        val messenger = mockk<BinaryMessenger>()
        manager.registerSlot(mockk<View>(), messenger)
        return messenger
    }

    private fun rumContext(viewId: String) = DefaultFlutterSessionReplayFeature.RumContext(
        applicationId = "application-id",
        sessionId = "session-id",
        viewId = viewId,
        viewServerTimeOffset = 0L
    )

    /** An engine that has enabled against this manager, with its context callback recorded. */
    private fun enableEngine(
        onContextChanged: (FlutterSessionReplayBridge.RumContext?) -> Unit = {}
    ): FlutterSessionReplayBridge {
        val bridge = FlutterSessionReplayBridge.create(manager)
        bridge.enable(
            FlutterSessionReplayBridge.Configuration(
                customEndpointUrl = null,
                onContextChanged = object : FlutterSessionReplayBridge.ContextListener {
                    override fun onContextChanged(context: FlutterSessionReplayBridge.RumContext) {
                        onContextChanged(context)
                    }
                }
            ),
            core = mockCore
        )
        return bridge
    }

    // region Feature registration

    @Test
    fun `M register one feature for every engine W enableFeature`() {
        // Given - a manager with no feature yet
        val manager = FlutterSessionReplayManager(embeddedSessionReplay = embedded)

        // When - two engines enable, as in a hybrid app with an embedded panel and a full-screen route
        val firstFeature = manager.enableFeature(mockCore, null)
        val secondFeature = manager.enableFeature(mockCore, null)

        // Then - the second engine reuses the feature instead of registering a duplicate
        assertThat(secondFeature).isSameInstanceAs(firstFeature)
        verify(exactly = 1) { mockCore.registerFeature(firstFeature) }
    }

    // endregion

    // region Context fan-out

    @Test
    fun `M reach every registered engine W broadcastContext`(
        @StringForgery viewId: String
    ) {
        // Given - two engines, both enabled against the same manager
        var contextA: FlutterSessionReplayBridge.RumContext? = null
        var contextB: FlutterSessionReplayBridge.RumContext? = null
        enableEngine { contextA = it }
        enableEngine { contextB = it }

        // When
        manager.broadcastContext(FlutterSessionReplayBridge.RumContext(rumContext(viewId)))

        // Then - not just the engine that enabled last
        assertThat(contextA?.viewId).isEqualTo(viewId)
        assertThat(contextB?.viewId).isEqualTo(viewId)
    }

    @Test
    fun `M deliver to that engine only W primeContext`(
        @StringForgery viewId: String
    ) {
        // Given - engine A is already recording; engine B enables later
        var callsToA = 0
        enableEngine { callsToA++ }
        val callsToAAfterEnable = callsToA

        // When
        var contextB: FlutterSessionReplayBridge.RumContext? = null
        every { mockFeature.readCurrentContext() } returns rumContext(viewId)
        enableEngine { contextB = it }

        // Then - priming is not a broadcast: A is not re-notified
        assertThat(contextB?.viewId).isEqualTo(viewId)
        assertThat(callsToA).isEqualTo(callsToAAfterEnable)
    }

    @Test
    fun `M not prime W enable and RUM has published no context`() {
        // Given
        every { mockFeature.readCurrentContext() } returns null

        // When
        var callCount = 0
        enableEngine { callCount++ }

        // Then - the engine waits for onContextUpdate rather than being handed an empty context
        assertThat(callCount).isEqualTo(0)
    }

    // endregion

    // region Detach

    @Test
    fun `M stop delivering context to that engine W detach after bind`(
        @StringForgery viewId: String
    ) {
        // Given - one engine, bound to its messenger the way `registerEngine` does
        var callsToEngine = 0
        val messenger = mockk<BinaryMessenger>()
        val engine = enableEngine { callsToEngine++ }
        manager.bind(engine.engineToken, messenger)
        val callsBeforeDetach = callsToEngine

        // When - the engine detaches while the bridge is still alive, as on force close
        manager.detach(messenger)
        manager.broadcastContext(FlutterSessionReplayBridge.RumContext(rumContext(viewId)))

        // Then - the Dart callback is gone, so this cannot call into a destroyed isolate
        assertThat(callsToEngine).isEqualTo(callsBeforeDetach)
    }

    @Test
    fun `M stop delivering context to previous bridge W bind replacement to same messenger`(
        @StringForgery viewId: String
    ) {
        // Given - a bridge bound to an engine before a Hot Restart creates its replacement
        var callsToPrevious = 0
        var contextForReplacement: FlutterSessionReplayBridge.RumContext? = null
        val messenger = mockk<BinaryMessenger>()
        val previous = enableEngine { callsToPrevious++ }
        val replacement = enableEngine { contextForReplacement = it }
        manager.bind(previous.engineToken, messenger)
        val callsBeforeRebind = callsToPrevious

        // When - the restarted Dart isolate binds its new bridge to the same native engine
        manager.bind(replacement.engineToken, messenger)
        manager.broadcastContext(FlutterSessionReplayBridge.RumContext(rumContext(viewId)))

        // Then - the destroyed isolate's callback is not invoked
        assertThat(callsToPrevious).isEqualTo(callsBeforeRebind)
        assertThat(contextForReplacement?.viewId).isEqualTo(viewId)
    }

    @Test
    fun `M leave other engines recording W detach`(
        @StringForgery viewId: String
    ) {
        // Given - two engines, as in a hybrid app with an embedded panel and a full-screen route
        var callsToA = 0
        var contextB: FlutterSessionReplayBridge.RumContext? = null
        val messengerA = mockk<BinaryMessenger>()
        val messengerB = mockk<BinaryMessenger>()
        val engineA = enableEngine { callsToA++ }
        val engineB = enableEngine { contextB = it }
        manager.bind(engineA.engineToken, messengerA)
        manager.bind(engineB.engineToken, messengerB)
        val callsToABeforeDetach = callsToA

        // When - only the secondary engine detaches
        manager.detach(messengerA)
        manager.broadcastContext(FlutterSessionReplayBridge.RumContext(rumContext(viewId)))

        // Then - B keeps receiving; a closing engine cannot clear a live one's callback
        assertThat(callsToA).isEqualTo(callsToABeforeDetach)
        assertThat(contextB?.viewId).isEqualTo(viewId)
    }

    @Test
    fun `M drop the engine's slot W detach`() {
        // Given - an embedded engine with a registered slot
        val messenger = embed()
        assertThat(manager.slotId(messenger)).isNotNull()

        // When
        manager.detach(messenger)

        // Then - the host must re-register on re-attach rather than reuse a dead view's slot
        assertThat(manager.slotId(messenger)).isNull()
    }

    @Test
    fun `M clear the host view's slot W detach`() {
        // Given - an embedded engine whose host view is still on screen, as when a cached engine is
        // destroyed out from under the view showing it
        val messenger = mockk<BinaryMessenger>()
        val view = mockk<View>()
        manager.registerSlot(view, messenger)

        // When
        manager.detach(messenger)

        // Then - the tag has to go too: the native recorder draws the placeholder from the view, so
        // leaving it set would keep a slot on screen that nothing can fill
        assertThat(embedded.slotIdOf(view)).isNull()
    }

    @Test
    fun `M do nothing W detach with an unbound messenger`(
        @StringForgery viewId: String
    ) {
        // Given - an engine that never completed the `registerEngine` handshake
        var contextForEngine: FlutterSessionReplayBridge.RumContext? = null
        enableEngine { contextForEngine = it }

        // When - an unrelated messenger detaches
        manager.detach(mockk())
        manager.broadcastContext(FlutterSessionReplayBridge.RumContext(rumContext(viewId)))

        // Then
        assertThat(contextForEngine?.viewId).isEqualTo(viewId)
    }

    @Test
    fun `M ignore W bind with an unknown token`(
        @StringForgery viewId: String,
        @StringForgery unknownToken: String
    ) {
        // Given
        var contextForEngine: FlutterSessionReplayBridge.RumContext? = null
        val messenger = mockk<BinaryMessenger>()
        enableEngine { contextForEngine = it }

        // When - a token no bridge claims, then that messenger detaches
        manager.bind(unknownToken, messenger)
        manager.detach(messenger)
        manager.broadcastContext(FlutterSessionReplayBridge.RumContext(rumContext(viewId)))

        // Then - no bridge was associated, so nothing was torn down
        assertThat(contextForEngine?.viewId).isEqualTo(viewId)
    }

    // endregion

    // region Slot IDs

    @Test
    fun `M assign a slot id to the host view W registerSlot`() {
        // Given
        val view = mockk<View>()

        // When
        manager.registerSlot(view, mockk())

        // Then - the native recorder only emits the embedded-content placeholder for views that
        // already carry an ID, so it must be assigned before the host is first snapshotted
        assertThat(embedded.slotIdOf(view)).isNotNull()
    }

    @Test
    fun `M return the id assigned to the engine's host view W slotId`() {
        // Given
        val messenger = mockk<BinaryMessenger>()
        val view = mockk<View>()
        manager.registerSlot(view, messenger)

        // When
        val slotId = manager.slotId(messenger)

        // Then
        assertThat(slotId).isNotNull()
        assertThat(slotId).isEqualTo(embedded.slotIdOf(view))
    }

    @Test
    fun `M be stable across repeated queries W slotId`() {
        // Given - the bridge resolves the slot on every segment write
        val messenger = embed()

        // When
        val first = manager.slotId(messenger)
        val second = manager.slotId(messenger)

        // Then - a new ID per query would orphan the records already stamped with the old one
        assertThat(first).isNotNull()
        assertThat(second).isEqualTo(first)
    }

    @Test
    fun `M keep the existing slot id W registerSlot called twice`() {
        // Given
        val messenger = mockk<BinaryMessenger>()
        val view = mockk<View>()
        manager.registerSlot(view, messenger)
        val firstSlotId = manager.slotId(messenger)

        // When - the host calls enableSessionReplay() again, or the host restarts
        manager.registerSlot(view, messenger)

        // Then - and the view is not re-tagged, since nothing about it changed
        assertThat(manager.slotId(messenger)).isEqualTo(firstSlotId)
        assertThat(embedded.slotIdAssignments).hasSize(1)
    }

    @Test
    fun `M keep the slot id W unregisterSlot then registerSlot with a recreated view`() {
        // Given - a fragment recreated on a configuration change gets a new FlutterView
        val messenger = mockk<BinaryMessenger>()
        val firstView = mockk<View>()
        manager.registerSlot(firstView, messenger)
        val firstSlotId = manager.slotId(messenger)

        // When - the old view detaches before the replacement attaches
        manager.unregisterSlot(messenger, firstView)
        assertThat(manager.slotId(messenger)).isNull()
        val secondView = mockk<View>()
        manager.registerSlot(secondView, messenger)

        // Then - the same slot moves to the new view, so the player sees one continuous slot...
        assertThat(manager.slotId(messenger)).isEqualTo(firstSlotId)
        assertThat(embedded.slotIdOf(secondView)).isEqualTo(firstSlotId)
        // ...and the old view stops being tracked, so nothing renders into a slot twice
        assertThat(embedded.slotIdOf(firstView)).isNull()
    }

    @Test
    fun `M be null W slotId for an unregistered messenger`() {
        assertThat(manager.slotId(mockk())).isNull()
    }

    @Test
    fun `M clear the view's slot W unregisterSlot`() {
        // Given
        val messenger = mockk<BinaryMessenger>()
        val view = mockk<View>()
        manager.registerSlot(view, messenger)

        // When - the host view detaches from its engine
        manager.unregisterSlot(messenger, view)

        // Then - records go back to buffering rather than naming a slot with no placeholder
        assertThat(manager.slotId(messenger)).isNull()
        assertThat(embedded.slotIdOf(view)).isNull()
    }

    @Test
    fun `M keep the new registration W unregisterSlot for a view already replaced`() {
        // Given - a cached engine handed from one host view to the next, the new view registering
        // before the old one reports its detach
        val messenger = mockk<BinaryMessenger>()
        val oldView = mockk<View>()
        val newView = mockk<View>()
        manager.registerSlot(oldView, messenger)
        manager.registerSlot(newView, messenger)

        // When - the old view's detach arrives late
        manager.unregisterSlot(messenger, oldView)

        // Then - it must not tear down the registration that replaced it
        assertThat(manager.slotId(messenger)).isNotNull()
        assertThat(embedded.slotIdOf(newView)).isEqualTo(manager.slotId(messenger))
    }

    @Test
    fun `M keep slots per engine W registerSlot for several engines`() {
        // Given
        val messengerA = mockk<BinaryMessenger>()
        val messengerB = mockk<BinaryMessenger>()

        // When
        manager.registerSlot(mockk<View>(), messengerA)
        manager.registerSlot(mockk<View>(), messengerB)

        // Then - sharing a slot would composite both engines into the same placeholder
        assertThat(manager.slotId(messengerA)).isNotNull()
        assertThat(manager.slotId(messengerA)).isNotEqualTo(manager.slotId(messengerB))
    }

    @Test
    fun `M deliver what the engine buffered W registerSlot`() {
        // Given - a pre-warmed engine: it enables, binds and records before the host has a view to
        // host it, so its segments have nowhere to go yet
        manager.enableFeature(mockCore, null)
        val bridge = enableEngine()
        val messenger = mockk<BinaryMessenger>()
        manager.bind(bridge.engineToken, messenger)
        bridge.setEmbedded(true)
        bridge.writeSegment("""{"records":[{"type":1}],"viewID":"view-id"}""")
        assertThat(embedded.recordBatches).isEmpty()

        // When - the host finally registers its view
        val view = mockk<View>()
        manager.registerSlot(view, messenger)

        // Then - the buffer is drained rather than left waiting on a segment that a static UI may
        // never produce, and that detach would discard
        assertThat(embedded.recordBatches).hasSize(1)
        assertThat(embedded.recordBatches[0].slotId).isEqualTo(embedded.slotIdOf(view))
    }

    // endregion

    // region Records

    @Test
    fun `M pass the records to the native recording W sendToNative`() {
        // Given
        manager.enableFeature(mockCore, null)

        // When
        val segment = """{"records":[{"type":1},{"type":2}],"viewID":"view-id"}"""
        manager.sendToNative(segment, "slot-id")

        // Then
        assertThat(embedded.recordBatches).hasSize(1)
        assertThat(embedded.recordBatches[0].records).hasSize(2)
        assertThat(embedded.recordBatches[0].slotId).isEqualTo("slot-id")
        assertThat(embedded.recordBatches[0].viewId).isEqualTo("view-id")
    }

    @ParameterizedTest
    @ValueSource(
        strings = [
            "not json at all",
            """{"records":[{"type":1}]}""", // no viewID
            """{"viewID":"view-id"}""", // no records
            """{"records":[],"viewID":"view-id"}""", // empty records
            """{"records":"not-an-array","viewID":"v"}"""
        ]
    )
    fun `M pass nothing W sendToNative with an unusable segment`(segment: String) {
        // Given
        manager.enableFeature(mockCore, null)

        // When
        manager.sendToNative(segment, "slot-id")

        // Then - a malformed batch would be unplayable, so it is dropped rather than forwarded
        assertThat(embedded.recordBatches).isEmpty()
    }

    @Test
    fun `M pass nothing W sendToNative before any engine enabled`() {
        // Given - no core retained yet

        // When
        manager.sendToNative("""{"records":[{"type":1}],"viewID":"view-id"}""", "slot-id")

        // Then
        assertThat(embedded.recordBatches).isEmpty()
    }

    // endregion

    // region Resources

    @Test
    fun `M pass the resource to the native recording and claim it W sendToNative when embedded`() {
        // Given
        manager.enableFeature(mockCore, null)
        embed()

        // When
        val data = byteArrayOf(1, 2, 3)
        val claimed = manager.sendToNative("identifier", data, "image/png")

        // Then - routed to the native writer, whose dedup is shared with the host and persisted
        assertThat(claimed).isTrue()
        assertThat(embedded.resources).hasSize(1)
        assertThat(embedded.resources[0])
            .isEqualTo(EmbeddedSessionReplaySpy.Resource("identifier", data, "image/png"))
    }

    @Test
    fun `M decline the resource W sendToNative when standalone`() {
        // Given - no host ever registered a slot, so Flutter is not embedded
        manager.enableFeature(mockCore, null)

        // When
        val claimed = manager.sendToNative("identifier", byteArrayOf(1, 2, 3), "image/png")

        // Then - declining sends it to the Flutter resources feature instead
        assertThat(claimed).isFalse()
        assertThat(embedded.resources).isEmpty()
    }

    @Test
    fun `M decline the resource W sendToNative before any engine enabled`() {
        // Given - embedded, but no core retained yet
        embed()

        // When
        val claimed = manager.sendToNative("identifier", byteArrayOf(1, 2, 3), "image/png")

        // Then
        assertThat(claimed).isFalse()
    }

    @Test
    fun `M decline the resource W sendToNative and the native module is absent`() {
        // Given - a pure-Flutter app, where dd-sdk-android-session-replay is not packaged
        embedded.isAvailable = false
        manager.enableFeature(mockCore, null)
        embed()

        // When
        val claimed = manager.sendToNative("identifier", byteArrayOf(1, 2, 3), "image/png")

        // Then - the resource must still reach the Flutter resources feature
        assertThat(claimed).isFalse()
    }

    // endregion

    @Test
    fun `M read the RUM feature context W enableFeature and prime`() {
        // Given - a real feature, to check which core context priming reads
        val manager = FlutterSessionReplayManager(embeddedSessionReplay = embedded)
        every { mockCore.getFeatureContext(Feature.RUM_FEATURE_NAME, any()) } returns emptyMap()

        // When
        val engine = FlutterSessionReplayBridge.create(manager)
        engine.enable(
            FlutterSessionReplayBridge.Configuration(
                customEndpointUrl = null,
                onContextChanged = mockk(relaxed = true)
            ),
            core = mockCore
        )

        // Then
        verify { mockCore.getFeatureContext(Feature.RUM_FEATURE_NAME, any()) }
    }
}
