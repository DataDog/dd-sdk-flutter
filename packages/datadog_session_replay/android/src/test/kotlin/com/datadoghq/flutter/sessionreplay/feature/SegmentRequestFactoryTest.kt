/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import assertk.assertFailure
import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isInstanceOf
import assertk.assertions.isNotNull
import assertk.assertions.startsWith
import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.net.RequestFactory
import com.datadoghq.flutter.sessionreplay.forge.SRForgeConfigurator
import com.datadoghq.flutter.sessionreplay.models.MobileSegment
import com.google.gson.JsonObject
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.annotation.Forgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeConfiguration
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import java.nio.charset.Charset
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody
import okio.Buffer
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
@ForgeConfiguration(SRForgeConfigurator::class)
internal class SegmentRequestFactoryTest {
    @Test
    fun `M throw InvalidPayloadException W empty batchData`(
        @Forgery fakeDatadogContext: DatadogContext
    ) {
        // Given
        val mockBatchesToSegmentsMapper = mockk<BatchesToSegmentsMapper>(relaxed = true)
        every { mockBatchesToSegmentsMapper.map(any(), any()) } answers {
            listOf()
        }

        // When
        val requestFactory = SegmentRequestFactory(
            customEndpointUrl = null,
            batchesToSegmentsMapper = mockBatchesToSegmentsMapper
        )

        // Then
        assertFailure {
            requestFactory.create(
                context = fakeDatadogContext,
                executionContext = mockk(),
                batchData = emptyList(),
                batchMetadata = null
            )
        }.isInstanceOf(InvalidPayloadFormatException::class.java)
    }

    @Test
    fun `M return valid Request W create`(
        forge: Forge,
        @StringForgery fakeBody: String,
        @Forgery fakeDatadogContext: DatadogContext
    ) {
        // Given
        val mockBatchesToSegmentsMapper = mockk<BatchesToSegmentsMapper>()
        every { mockBatchesToSegmentsMapper.map(any(), any()) } answers {
            listOf(
                fakeMobileSegment(forge)
            )
        }
        val mockRequestBodyFactory = mockk<SegmentRequestBodyFactory>()
        val mockRequestBody = mockk<RequestBody>(relaxed = true)
        every { mockRequestBodyFactory.create(any()) } answers {
            mockRequestBody
        }
        every { mockRequestBody.contentType() } returns
            "multipart/form-data; charset=utf-8".toMediaTypeOrNull()
        val bufferSlot = slot<Buffer>()
        every { mockRequestBody.writeTo(capture(bufferSlot)) } answers {
            bufferSlot.captured.writeString(fakeBody, Charset.defaultCharset())
        }

        // When
        val requestFactory = SegmentRequestFactory(
            customEndpointUrl = null,
            batchesToSegmentsMapper = mockBatchesToSegmentsMapper,
            segmentRequestBodyFactory = mockRequestBodyFactory
        )
        val request = requestFactory.create(
            context = fakeDatadogContext,
            executionContext = mockk(),
            batchData = listOf(),
            batchMetadata = null
        )

        // Then
        assertThat(request.url).isEqualTo(expectedUrl(fakeDatadogContext.site.intakeEndpoint))
        assertThat(request.contentType).isNotNull().startsWith("multipart/form-data;")
        assertThat(request.headers.minus(RequestFactory.HEADER_REQUEST_ID)).isEqualTo(
            mapOf(
                RequestFactory.HEADER_API_KEY to fakeDatadogContext.clientToken,
                RequestFactory.HEADER_EVP_ORIGIN to fakeDatadogContext.source,
                RequestFactory.HEADER_EVP_ORIGIN_VERSION to fakeDatadogContext.sdkVersion
            )
        )
        assertThat(request.headers[RequestFactory.HEADER_REQUEST_ID]?.isNotEmpty()).isEqualTo(true)
        assertThat(request.id).isEqualTo(request.headers[RequestFactory.HEADER_REQUEST_ID])
        assertThat(request.description).isEqualTo("Session Replay Segment Upload Request")
        assertThat(request.body).isEqualTo(mockRequestBody.toByteArray())
    }

    @Test
    fun `M return valid Request W create { custom endpoint }`(
        forge: Forge,
        @StringForgery(regex = "https://[a-z]+\\.com") fakeEndpoint: String,
        @Forgery fakeDatadogContext: DatadogContext
    ) {
        // Given
        val mockBatchesToSegmentsMapper = mockk<BatchesToSegmentsMapper>()
        every { mockBatchesToSegmentsMapper.map(any(), any()) } answers {
            listOf(
                fakeMobileSegment(forge)
            )
        }

        // When
        val requestFactory = SegmentRequestFactory(
            customEndpointUrl = fakeEndpoint,
            batchesToSegmentsMapper = mockBatchesToSegmentsMapper
        )
        val request = requestFactory.create(
            context = fakeDatadogContext,
            executionContext = mockk(),
            batchData = listOf(),
            batchMetadata = null
        )

        // Then
        assertThat(request.url).isEqualTo(expectedUrl(fakeEndpoint))
    }

    // region Internal

    private fun expectedUrl(endpointUrl: String): String {
        return "$endpointUrl/api/v2/replay"
    }

    private fun RequestBody.toByteArray(): ByteArray {
        val buffer = Buffer()
        writeTo(buffer)
        return buffer.readByteArray()
    }

    private fun fakeMobileSegment(forge: Forge): Pair<MobileSegment, JsonObject> {
        val mobileSegment = forge.getForgery<MobileSegment>()

        // This is not actually what's stored in the Pair, but for testing purposes it should work.
        return Pair(mobileSegment, mobileSegment.toJson() as JsonObject)
    }

    // endregion
}
