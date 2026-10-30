/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2026-Present Datadog, Inc.
 */
package com.datadoghq.flutter.sessionreplay.feature

import assertk.assertThat
import assertk.assertions.hasSize
import assertk.assertions.isEqualTo
import assertk.assertions.isTrue
import com.datadog.android.api.context.DatadogContext
import com.datadoghq.flutter.sessionreplay.forge.SRForgeConfigurator
import fr.xgouchet.elmyr.annotation.Forgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeConfiguration
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.mockk
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
@ForgeConfiguration(SRForgeConfigurator::class)
internal class BatchesToSegmentsMapperTest {
    private val mapper = BatchesToSegmentsMapper(mockk(relaxed = true))

    private fun batch(
        applicationIdKey: String,
        sessionIdKey: String,
        viewIdKey: String,
        applicationId: String,
        sessionId: String,
        viewId: String,
        fullSnapshotType: Int
    ): ByteArray {
        val records = """[{"type":4,"timestamp":1000},{"type":$fullSnapshotType,"timestamp":1001}]"""
        return (
            """{"$applicationIdKey":"$applicationId","$sessionIdKey":"$sessionId",""" +
                """"$viewIdKey":"$viewId","records":$records}"""
            ).toByteArray()
    }

    @Test
    fun `M map Flutter records W map`(
        @StringForgery applicationId: String,
        @StringForgery sessionId: String,
        @StringForgery viewId: String,
        @Forgery fakeDatadogContext: DatadogContext
    ) {
        // When
        val segments = mapper.map(
            fakeDatadogContext,
            listOf(batch("applicationID", "sessionID", "viewID", applicationId, sessionId, viewId, 10))
        )

        // Then
        assertThat(segments).hasSize(1)
        val segment = segments[0].first
        assertThat(segment.application.id).isEqualTo(applicationId)
        assertThat(segment.session.id).isEqualTo(sessionId)
        assertThat(segment.view.id).isEqualTo(viewId)
    }

    @Test
    fun `M map WebView records W map {native WebView tracking keys}`(
        @StringForgery applicationId: String,
        @StringForgery sessionId: String,
        @StringForgery viewId: String,
        @Forgery fakeDatadogContext: DatadogContext
    ) {
        // When - native WebView tracking writes its records through this mapper with its own keys
        val segments = mapper.map(
            fakeDatadogContext,
            listOf(batch("application_id", "session_id", "view_id", applicationId, sessionId, viewId, 2))
        )

        // Then
        assertThat(segments).hasSize(1)
        val segment = segments[0].first
        assertThat(segment.application.id).isEqualTo(applicationId)
        assertThat(segment.session.id).isEqualTo(sessionId)
        assertThat(segment.view.id).isEqualTo(viewId)
        assertThat(segment.hasFullSnapshot == true).isTrue()
    }
}
