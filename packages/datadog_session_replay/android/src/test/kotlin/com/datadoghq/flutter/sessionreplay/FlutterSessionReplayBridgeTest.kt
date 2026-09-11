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
import io.mockk.verify
import java.nio.ByteBuffer
import kotlin.test.Test
import org.junit.jupiter.api.extension.ExtendWith

/**
 * Tests the per-engine bridge.
 *
 * Every test builds its own manager, so no state leaks between tests and nothing touches
 * [FlutterSessionReplayManager.shared].
 */
@ExtendWith(ForgeExtension::class)
internal class FlutterSessionReplayBridgeTest {
    private val mockCore: FeatureSdkCore = mockk(relaxed = true)
    private val mockFeature: DefaultFlutterSessionReplayFeature = mockk(relaxed = true)
    private val embedded = EmbeddedSessionReplaySpy()
    private val manager = FlutterSessionReplayManager(mockFeature, embedded)
    private val bridge = FlutterSessionReplayBridge.create(manager)

    private val messenger = mockk<BinaryMessenger>()
    private val hostView = mockk<View>()

    /** Every segment the standalone path wrote to the feature, in order. */
    private val writtenSegments = mutableListOf<String>()

    /**
     * A record batch the manager will accept: `sendToNative(segment, slotId)` requires non-empty
     * `records` and a `viewID`.
     */
    private fun segment(viewId: String = "view-id", recordCount: Int = 1): String {
        val records = (0 until recordCount).joinToString(",") { """{"type":$it}""" }
        return """{"records":[$records],"viewID":"$viewId"}"""
    }

    /**
     * Enables the bridge against the mock core. The manager keeps the injected mock feature —
     * `enableFeature` returns early when one already exists — but still retains the core, which is
     * what the embedded path passes records to.
     */
    private fun enable(
        onContextChanged: (FlutterSessionReplayBridge.RumContext) -> Unit = {}
    ) {
        every { mockFeature.writeSegment(any()) } answers { writtenSegments.add(firstArg()) }
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
    }

    /**
     * Puts the bridge on the embedded path with a resolvable slot: the host registering its view,
     * the `registerEngine` handshake, and Dart declaring `isEmbedded`. Returns the slot ID the
     * records are expected to carry. Must be called after [enable], which is what puts the bridge in
     * the registry `bind` looks it up in.
     */
    private fun embed(): String {
        manager.registerSlot(hostView, messenger)
        manager.bind(bridge.engineToken, messenger)
        bridge.setEmbedded(true)
        return checkNotNull(manager.slotId(messenger))
    }

    private fun rumContext(viewId: String) = DefaultFlutterSessionReplayFeature.RumContext(
        applicationId = "application-id",
        sessionId = "session-id",
        viewId = viewId,
        viewServerTimeOffset = 0L
    )

    // region Enabling

    @Test
    fun `M register the feature in core W enable`() {
        // Given - a manager with no feature yet, unlike the injected-mock setup
        val manager = FlutterSessionReplayManager(embeddedSessionReplay = embedded)
        val bridge = FlutterSessionReplayBridge.create(manager)

        // When
        val feature = bridge.enable(
            FlutterSessionReplayBridge.Configuration(onContextChanged = mockk(relaxed = true)),
            core = mockCore
        )

        // Then
        assertThat(manager.feature).isNotNull()
        verify { mockCore.registerFeature(feature) }
    }

    @Test
    fun `M prime the engine with the current context W enable`(
        @StringForgery viewId: String
    ) {
        // Given - the native RUM view is already active, as in a hybrid app
        every { mockFeature.readCurrentContext() } returns rumContext(viewId)

        // When
        var receivedContext: FlutterSessionReplayBridge.RumContext? = null
        enable { receivedContext = it }

        // Then - the engine starts recording immediately instead of waiting for a context change
        assertThat(receivedContext?.applicationId).isEqualTo("application-id")
        assertThat(receivedContext?.sessionId).isEqualTo("session-id")
        assertThat(receivedContext?.viewId).isEqualTo(viewId)
    }

    @Test
    fun `M register the engine for context fan-out W enable`(
        @StringForgery viewId: String
    ) {
        // Given
        var receivedContext: FlutterSessionReplayBridge.RumContext? = null
        enable { receivedContext = it }

        // When - a later context change reaches the manager
        manager.broadcastContext(FlutterSessionReplayBridge.RumContext(rumContext(viewId)))

        // Then
        assertThat(receivedContext?.viewId).isEqualTo(viewId)
    }

    // endregion

    // region Segment routing

    @Test
    fun `M buffer instead of guessing W writeSegment before the embedding is known`() {
        // Given
        enable()

        // When - Dart has not called setEmbedded yet
        bridge.writeSegment(segment())

        // Then - the records go nowhere rather than down the wrong path
        assertThat(writtenSegments).isEmpty()
        assertThat(embedded.recordBatches).isEmpty()
    }

    @Test
    fun `M flush buffered segments to the feature W setEmbedded false`() {
        // Given
        enable()
        val first = segment(viewId = "view-1")
        val second = segment(viewId = "view-2")
        bridge.writeSegment(first)
        bridge.writeSegment(second)

        // When - Flutter is the host app
        bridge.setEmbedded(false)

        // Then - buffered segments replay in order
        assertThat(writtenSegments).containsExactly(first, second)
        assertThat(embedded.recordBatches).isEmpty()
    }

    @Test
    fun `M flush buffered segments to the native recording W setEmbedded true`() {
        // Given
        enable()
        bridge.writeSegment(segment(viewId = "view-1"))
        bridge.writeSegment(segment(viewId = "view-2"))

        // When
        val expectedSlotId = embed()

        // Then
        assertThat(writtenSegments).isEmpty()
        assertThat(embedded.recordBatches.map { it.viewId }).containsExactly("view-1", "view-2")
        assertThat(embedded.recordBatches.map { it.slotId }.distinct())
            .containsExactly(expectedSlotId)
    }

    @Test
    fun `M write to the feature W writeSegment when standalone`() {
        // Given
        enable()
        bridge.setEmbedded(false)

        // When
        val segment = segment()
        bridge.writeSegment(segment)

        // Then
        assertThat(writtenSegments).containsExactly(segment)
        assertThat(embedded.recordBatches).isEmpty()
    }

    @Test
    fun `M stamp the records with the slot id W writeSegment when embedded`() {
        // Given
        enable()
        val expectedSlotId = embed()

        // When
        bridge.writeSegment(segment(viewId = "view-id", recordCount = 3))

        // Then - the player needs the slot to composite these into the host's placeholder, and RUM
        // keys record counts off the *native* view ID the records were stamped with
        assertThat(embedded.recordBatches).hasSize(1)
        assertThat(embedded.recordBatches[0].slotId).isEqualTo(expectedSlotId)
        assertThat(embedded.recordBatches[0].viewId).isEqualTo("view-id")
        assertThat(embedded.recordBatches[0].records).hasSize(3)
        assertThat(writtenSegments).isEmpty()
    }

    @Test
    fun `M buffer until the host registers its view W writeSegment when embedded`() {
        // Given - a pre-warmed engine: Dart declared isEmbedded and started recording before the
        // host called enableSessionReplay(), so there is no slot to stamp records with
        enable()
        bridge.setEmbedded(true)
        bridge.writeSegment(segment(viewId = "view-1"))
        bridge.writeSegment(segment(viewId = "view-2"))
        assertThat(embedded.recordBatches).isEmpty()

        // When - the host presents the engine's view
        val expectedSlotId = embed()
        bridge.writeSegment(segment(viewId = "view-3"))

        // Then - nothing was written to a slot the player has no placeholder for, and the buffered
        // segments replay in order once one exists
        assertThat(embedded.recordBatches.map { it.viewId })
            .containsExactly("view-1", "view-2", "view-3")
        assertThat(embedded.recordBatches.map { it.slotId }.distinct())
            .containsExactly(expectedSlotId)
        assertThat(writtenSegments).isEmpty()
    }

    @Test
    fun `M drop the oldest segments W writeSegment and the slot never resolves`() {
        // Given - a host that configured isEmbedded but never registered a view
        enable()
        bridge.setEmbedded(true)
        val overflow = FlutterSessionReplayBridge.MAX_PENDING_SEGMENTS + 5
        repeat(overflow) { bridge.writeSegment(segment(viewId = "view-$it")) }

        // When - a slot finally appears
        embed()

        // Then - the buffer is capped, so an unresolvable engine cannot grow it without bound; what
        // survives is the most recent capture rather than a stale prefix
        val expectedCount = FlutterSessionReplayBridge.MAX_PENDING_SEGMENTS
        assertThat(embedded.recordBatches).hasSize(expectedCount)
        assertThat(embedded.recordBatches.first().viewId)
            .isEqualTo("view-${overflow - expectedCount}")
        assertThat(embedded.recordBatches.last().viewId).isEqualTo("view-${overflow - 1}")
    }

    @Test
    fun `M stop routing segments W detach`() {
        // Given - an embedded engine that has been recording
        enable()
        embed()
        bridge.writeSegment(segment())
        val batchesBeforeDetach = embedded.recordBatches.size

        // When - the engine detaches, then a segment already in flight lands
        manager.detach(messenger)
        bridge.writeSegment(segment())

        // Then - the embedding state was reset, so the segment buffers rather than naming a slot
        // that no longer belongs to this engine
        assertThat(embedded.recordBatches).hasSize(batchesBeforeDetach)
        assertThat(writtenSegments).isEmpty()
    }

    // endregion

    // region Replay state publishing

    @Test
    fun `M publish to the feature W setHasReplay when standalone`(
        @StringForgery viewId: String,
        @BoolForgery hasReplay: Boolean
    ) {
        // Given
        enable()
        bridge.setEmbedded(false)

        // When
        bridge.setHasReplay(viewId, hasReplay)

        // Then
        verify { mockFeature.setHasReplay(viewId, hasReplay) }
    }

    @Test
    fun `M stay quiet W setHasReplay when embedded`(
        @StringForgery viewId: String
    ) {
        // Given
        enable()
        bridge.setEmbedded(true)

        // When
        bridge.setHasReplay(viewId, true)

        // Then - the native Session Replay owns this core-context key when embedded; publishing
        // from here too would make the value depend on which side wrote last
        verify(exactly = 0) { mockFeature.setHasReplay(any(), any()) }
    }

    @Test
    fun `M stay quiet W setHasReplay before the embedding is known`(
        @StringForgery viewId: String
    ) {
        // Given
        enable()

        // When
        bridge.setHasReplay(viewId, true)

        // Then - publishing would be a guess, and guessing wrong corrupts the native value
        verify(exactly = 0) { mockFeature.setHasReplay(any(), any()) }
    }

    @Test
    fun `M publish to the feature W setRecordCount when standalone`(
        @StringForgery viewId: String,
        @IntForgery(min = 0, max = 1000) recordCount: Int
    ) {
        // Given
        enable()
        bridge.setEmbedded(false)

        // When
        bridge.setRecordCount(viewId, recordCount)

        // Then
        verify { mockFeature.setRecordCount(viewId, recordCount) }
    }

    @Test
    fun `M stay quiet W setRecordCount when embedded`(
        @StringForgery viewId: String,
        @IntForgery(min = 0, max = 1000) recordCount: Int
    ) {
        // Given
        enable()
        bridge.setEmbedded(true)

        // When
        bridge.setRecordCount(viewId, recordCount)

        // Then - the native embedded-content receiver counts our records instead
        verify(exactly = 0) { mockFeature.setRecordCount(any(), any()) }
    }

    // endregion

    // region Resources

    @Test
    fun `M forward to the resource resolver W saveImageForProcessing`(
        forge: Forge,
        @IntForgery key: Int,
        @IntForgery width: Int,
        @IntForgery height: Int
    ) {
        // Given
        val mockResourceResolver = mockk<ResourceResolver>(relaxed = true)
        every { mockFeature.resourceResolver } returns mockResourceResolver
        enable()

        // When
        val data = ByteBuffer.allocate(forge.anInt(1, 100))
        bridge.saveImageForProcessing(key, data, width, height)

        // Then
        verify { mockResourceResolver.addResource(bridge.engineToken, key, width, height, data) }
    }

    @Test
    fun `M return the identifier the resolver minted W resourceIdForKey`(
        @IntForgery key: Int,
        @StringForgery resolvedId: String
    ) {
        // Given
        val mockResourceResolver = mockk<ResourceResolver>(relaxed = true)
        every { mockFeature.resourceResolver } returns mockResourceResolver
        every { mockResourceResolver.resolveResource(bridge.engineToken, key) } returns resolvedId
        enable()

        // When
        val result = bridge.resourceIdForKey(key)

        // Then - this is the value that goes into the image wireframe
        assertThat(result).isEqualTo(resolvedId)
    }

    @Test
    fun `M be null W resourceIdForKey for an untracked key`(
        @IntForgery key: Int
    ) {
        // Given
        val mockResourceResolver = mockk<ResourceResolver>(relaxed = true)
        every { mockFeature.resourceResolver } returns mockResourceResolver
        every { mockResourceResolver.resolveResource(bridge.engineToken, key) } returns null
        enable()

        // Then
        assertThat(bridge.resourceIdForKey(key)).isNull()
    }

    @Test
    fun `M release the engine's resources W detach`() {
        // Given
        val mockResourceResolver = mockk<ResourceResolver>(relaxed = true)
        every { mockFeature.resourceResolver } returns mockResourceResolver
        enable()

        // When
        bridge.detach()

        // Then - the resolver is shared and never evicts on its own, so the entries this engine's
        // keys point at would otherwise outlive its isolate
        verify { mockResourceResolver.releaseEngine(bridge.engineToken) }
    }

    // endregion
}
