/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.embedded

import android.view.View
import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isFalse
import assertk.assertions.isTrue
import com.datadog.android.api.SdkCore
import com.datadog.android.sessionreplay._SessionReplayInternalProxy
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.mockk
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

/**
 * Tests [DefaultEmbeddedSessionReplay] against a real (test-double) native proxy, rather than
 * [EmbeddedSessionReplaySpy] — every other test in this module substitutes the spy, so this class's
 * own `Class.forName`/`LinkageError`-guarding logic, including the split between
 * [DefaultEmbeddedSessionReplay]'s three independent failure flags, has never actually run. See
 * `_SessionReplayInternalProxy` in `src/test` for how the real proxy is stood in for.
 */
@ExtendWith(ForgeExtension::class)
internal class DefaultEmbeddedSessionReplayTest {
    private val view: View = mockk()
    private val sdkCore: SdkCore = mockk()

    private val embedded = DefaultEmbeddedSessionReplay()

    @BeforeEach
    fun setUp() {
        _SessionReplayInternalProxy.reset()
    }

    private fun Forge.aRecordsPayload(): List<Map<String, Any?>> =
        aList(size = anInt(min = 1, max = 5)) { mapOf(anAlphabeticalString() to anInt()) }

    private fun Forge.aResourceBytes(): ByteArray =
        ByteArray(anInt(min = 1, max = 32)) { anInt(min = 0, max = 256).toByte() }

    @Test
    fun `M be available W isAvailable and nothing has failed`() {
        assertThat(embedded.isAvailable).isTrue()
    }

    @Test
    fun `M call the native proxy W setSlotId`(forge: Forge) {
        // When
        embedded.setSlotId(view, forge.anAlphabeticalString())

        // Then
        assertThat(_SessionReplayInternalProxy.setSlotIdCallCount).isEqualTo(1)
    }

    @Test
    fun `M call the native proxy W addRecords`(forge: Forge) {
        // When
        embedded.addRecords(
            forge.aRecordsPayload(),
            forge.anAlphabeticalString(),
            forge.anAlphabeticalString(),
            sdkCore
        )

        // Then
        assertThat(_SessionReplayInternalProxy.addRecordsCallCount).isEqualTo(1)
    }

    @Test
    fun `M return true and call the native proxy W addResource succeeds`(forge: Forge) {
        // When
        val claimed = embedded.addResource(
            forge.anAlphabeticalString(),
            forge.aResourceBytes(),
            forge.anAlphabeticalString(),
            sdkCore
        )

        // Then
        assertThat(claimed).isTrue()
        assertThat(_SessionReplayInternalProxy.addResourceCallCount).isEqualTo(1)
    }

    @Test
    fun `M return false W addResource hits a LinkageError`(forge: Forge) {
        // Given - a version-skewed native SDK missing this specific member
        _SessionReplayInternalProxy.throwOnAddResource = true

        // When
        val claimed = embedded.addResource(
            forge.anAlphabeticalString(),
            forge.aResourceBytes(),
            forge.anAlphabeticalString(),
            sdkCore
        )

        // Then - the caller can fall back instead of assuming the resource was taken
        assertThat(claimed).isFalse()
    }

    @Test
    fun `M stop calling the native proxy W addResource keeps hitting a LinkageError`(forge: Forge) {
        // Given - the first call discovers the version skew
        _SessionReplayInternalProxy.throwOnAddResource = true
        embedded.addResource(
            forge.anAlphabeticalString(),
            forge.aResourceBytes(),
            forge.anAlphabeticalString(),
            sdkCore
        )

        // When - the native member would actually be reachable again, but the failure latched
        _SessionReplayInternalProxy.throwOnAddResource = false
        val claimed = embedded.addResource(
            forge.anAlphabeticalString(),
            forge.aResourceBytes(),
            forge.anAlphabeticalString(),
            sdkCore
        )

        // Then - never even attempted a second time
        assertThat(claimed).isFalse()
        assertThat(_SessionReplayInternalProxy.addResourceCallCount).isEqualTo(0)
    }

    @Test
    fun `M report unavailable W isAvailable after addResource hits a LinkageError`(forge: Forge) {
        // Given
        _SessionReplayInternalProxy.throwOnAddResource = true
        embedded.addResource(
            forge.anAlphabeticalString(),
            forge.aResourceBytes(),
            forge.anAlphabeticalString(),
            sdkCore
        )

        // Then - the only caller (the manager's resource routing) reads this to fall back
        assertThat(embedded.isAvailable).isFalse()
    }

    @Test
    fun `M keep publishing replay state W setSlotId hits a LinkageError but addResource has not`(
        forge: Forge
    ) {
        // Given - isAvailable is scoped to addResource specifically, not the module as a whole
        _SessionReplayInternalProxy.throwOnSetSlotId = true
        embedded.setSlotId(view, forge.anAlphabeticalString())

        // Then
        assertThat(embedded.isAvailable).isTrue()
    }

    @Test
    fun `M keep calling addRecords and addResource W setSlotId hits a LinkageError`(forge: Forge) {
        // Given - a version skew that only drops setEmbeddedContentSlotId
        _SessionReplayInternalProxy.throwOnSetSlotId = true
        embedded.setSlotId(view, forge.anAlphabeticalString())

        // When - the other two calls, which still link fine
        embedded.addRecords(
            forge.aRecordsPayload(),
            forge.anAlphabeticalString(),
            forge.anAlphabeticalString(),
            sdkCore
        )
        val claimed = embedded.addResource(
            forge.anAlphabeticalString(),
            forge.aResourceBytes(),
            forge.anAlphabeticalString(),
            sdkCore
        )

        // Then - neither is disabled by setSlotId's failure
        assertThat(_SessionReplayInternalProxy.addRecordsCallCount).isEqualTo(1)
        assertThat(claimed).isTrue()
    }

    @Test
    fun `M keep calling setSlotId and addResource W addRecords hits a LinkageError`(forge: Forge) {
        // Given - a version skew that only drops addEmbeddedContentRecords
        _SessionReplayInternalProxy.throwOnAddRecords = true
        embedded.addRecords(
            forge.aRecordsPayload(),
            forge.anAlphabeticalString(),
            forge.anAlphabeticalString(),
            sdkCore
        )

        // When - the other two calls, which still link fine
        embedded.setSlotId(view, forge.anAlphabeticalString())
        val claimed = embedded.addResource(
            forge.anAlphabeticalString(),
            forge.aResourceBytes(),
            forge.anAlphabeticalString(),
            sdkCore
        )

        // Then - neither is disabled by addRecords' failure
        assertThat(_SessionReplayInternalProxy.setSlotIdCallCount).isEqualTo(1)
        assertThat(claimed).isTrue()
    }

    @Test
    fun `M keep calling setSlotId and addRecords W addResource hits a LinkageError`(forge: Forge) {
        // Given - a version skew that only drops addEmbeddedContentResource
        _SessionReplayInternalProxy.throwOnAddResource = true
        embedded.addResource(
            forge.anAlphabeticalString(),
            forge.aResourceBytes(),
            forge.anAlphabeticalString(),
            sdkCore
        )

        // When - the other two calls, which still link fine
        embedded.setSlotId(view, forge.anAlphabeticalString())
        embedded.addRecords(
            forge.aRecordsPayload(),
            forge.anAlphabeticalString(),
            forge.anAlphabeticalString(),
            sdkCore
        )

        // Then - neither is disabled by addResource's failure
        assertThat(_SessionReplayInternalProxy.setSlotIdCallCount).isEqualTo(1)
        assertThat(_SessionReplayInternalProxy.addRecordsCallCount).isEqualTo(1)
    }
}
