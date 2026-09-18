/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isNotNull
import com.datadog.android.DatadogSite
import com.datadog.android.api.InternalLogger
import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.net.RequestFactory
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import java.util.UUID
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody
import okio.BufferedSink
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow
import org.junit.jupiter.api.extension.ExtendWith
import org.junit.jupiter.api.extension.Extensions

@Extensions(ExtendWith(ForgeExtension::class))
class ResourceRequestFactoryTest {
    val mockInteralLogger = mockk<InternalLogger>()
    var mockBodyFactory = mockk<ResourceRequestBodyFactory>()
    var mockBody = mockk<RequestBody>()

    @BeforeEach
    fun `set up`() {
        mockBody = mockk<RequestBody>()
        every { mockBody.contentType() } returns "application/json".toMediaTypeOrNull()
        every { mockBody.writeTo(any()) } returns Unit

        mockBodyFactory = mockk()
        every { mockBodyFactory.create(any()) } returns mockBody
    }

    @Test
    fun `M create a request W create()`(
        forge: Forge
    ) {
        // Given
        val mockContext = mockk<DatadogContext>()
        every { mockContext.site } returns DatadogSite.US1
        every { mockContext.clientToken } returns forge.aString()
        every { mockContext.source } returns forge.aString()
        every { mockContext.sdkVersion } returns forge.aString()

        val factory = ResourceRequestFactory(
            customEndpointUrl = null,
            internalLogger = mockInteralLogger,
            requestBodyFactory = mockBodyFactory
        )

        // When
        val request = factory.create(
            context = mockContext,
            executionContext = mockk(),
            batchData = listOf(),
            batchMetadata = null
        )

        // Then
        assertThat(request).isNotNull()
        assertDoesNotThrow {
            UUID.fromString(request!!.id)
        }
        assertThat(request!!.url).isEqualTo("${DatadogSite.US1.intakeEndpoint}/api/v2/replay")
    }

    @Test
    fun `M create request with correct headers W create()`(
        @StringForgery clientToken: String,
        @StringForgery source: String,
        @StringForgery sdkVersion: String,
        forge: Forge
    ) {
        // Given
        val mockContext = mockk<DatadogContext>()
        every { mockContext.site } returns DatadogSite.US1
        every { mockContext.clientToken } returns clientToken
        every { mockContext.source } returns source
        every { mockContext.sdkVersion } returns sdkVersion

        val factory = ResourceRequestFactory(
            customEndpointUrl = null,
            internalLogger = mockInteralLogger,
            requestBodyFactory = mockBodyFactory
        )

        // When
        val request = factory.create(
            context = mockContext,
            executionContext = mockk(),
            batchData = listOf(),
            batchMetadata = null
        )

        val headers = request!!.headers
        assertThat(headers[RequestFactory.HEADER_API_KEY]).isEqualTo(clientToken)
        assertThat(headers[RequestFactory.HEADER_EVP_ORIGIN]).isEqualTo(source)
        assertThat(headers[RequestFactory.HEADER_EVP_ORIGIN_VERSION]).isEqualTo(sdkVersion)
        assertThat(headers[RequestFactory.HEADER_REQUEST_ID]).isNotNull()
    }

    @Test
    fun `M write body bytes to request W create()`(
        forge: Forge
    ) {
        // Given
        val mockContext = mockk<DatadogContext>()
        every { mockContext.site } returns DatadogSite.US1
        every { mockContext.clientToken } returns forge.aString()
        every { mockContext.source } returns forge.aString()
        every { mockContext.sdkVersion } returns forge.aString()

        val byteValues = ByteArray(10) { forge.anInt(min = 0, max = 255).toByte() }
        val bufferSlot = slot<BufferedSink>()
        every { mockBody.writeTo(capture(bufferSlot)) } answers {
            bufferSlot.captured.write(byteValues)
        }

        val factory = ResourceRequestFactory(
            customEndpointUrl = null,
            internalLogger = mockInteralLogger,
            requestBodyFactory = mockBodyFactory
        )

        // When
        val request = factory.create(
            context = mockContext,
            executionContext = mockk(),
            batchData = listOf(),
            batchMetadata = null
        )

        assertThat(request!!.body).isEqualTo(byteValues)
    }
}
