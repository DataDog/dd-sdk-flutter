/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import assertk.assertThat
import assertk.assertions.isEqualTo
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.mockk
import io.mockk.verify
import kotlin.test.Test
import org.junit.jupiter.api.extension.ExtendWith

/**
 * Tests the fork in the resource path: an embedded app's images belong to the native Session Replay,
 * a standalone app's to the Flutter resources feature.
 */
@ExtendWith(ForgeExtension::class)
internal class RoutedResourceWriterTest {
    private val standaloneWriter = mockk<ResourceWriter>(relaxed = true)

    @Test
    fun `M write only to the native Session Replay W embedded`(
        @StringForgery identifier: String
    ) {
        // Given - the sink accepts, which is what the manager does once Flutter is embedded
        var received: Triple<String, ByteArray, String>? = null
        val writer = RoutedResourceWriter(standaloneWriter) { id, data, mimeType ->
            received = Triple(id, data, mimeType)
            true
        }
        val data = byteArrayOf(1, 2, 3)

        // When
        writer.write(identifier, data)

        // Then - writing to both would upload the same image twice under two different features
        assertThat(received?.first).isEqualTo(identifier)
        assertThat(received?.second).isEqualTo(data)
        assertThat(received?.third).isEqualTo(RoutedResourceWriter.MIME_TYPE)
        verify(exactly = 0) { standaloneWriter.write(any(), any()) }
    }

    @Test
    fun `M fall back to the Flutter resources feature W the sink declines`(
        @StringForgery identifier: String
    ) {
        // Given - the sink declines when Flutter is the host app, or when the native Session Replay
        // module is not on the runtime classpath at all
        val writer = RoutedResourceWriter(standaloneWriter) { _, _, _ -> false }
        val data = byteArrayOf(1, 2, 3)

        // When
        writer.write(identifier, data)

        // Then
        verify { standaloneWriter.write(identifier, data) }
    }
}
