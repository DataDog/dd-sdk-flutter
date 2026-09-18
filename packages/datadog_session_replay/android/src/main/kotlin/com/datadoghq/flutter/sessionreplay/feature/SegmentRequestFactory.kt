/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.net.Request
import com.datadog.android.api.net.RequestExecutionContext
import com.datadog.android.api.net.RequestFactory
import com.datadog.android.api.storage.RawBatchEvent
import java.util.Locale
import java.util.UUID
import okhttp3.RequestBody
import okio.Buffer

internal class SegmentRequestFactory(
    private val customEndpointUrl: String?,
    private val batchesToSegmentsMapper: BatchesToSegmentsMapper,
    private val segmentRequestBodyFactory: SegmentRequestBodyFactory = SegmentRequestBodyFactory()
) : RequestFactory {
    override fun create(
        context: DatadogContext,
        executionContext: RequestExecutionContext,
        batchData: List<RawBatchEvent>,
        batchMetadata: ByteArray?
    ): Request {
        val serializedSegmentPair = batchesToSegmentsMapper.map(context, batchData.map { it.data })
        if (serializedSegmentPair.isEmpty()) {
            @Suppress("ThrowingInternalException")
            throw InvalidPayloadFormatException(
                "The payload format was broken and an upload" +
                    " request could not be created"
            )
        }
        val body = segmentRequestBodyFactory.create(serializedSegmentPair)
        return resolveRequest(context, body)
    }

    private fun buildUrl(datadogContext: DatadogContext): String {
        return String.format(
            Locale.US,
            UPLOAD_URL,
            customEndpointUrl ?: datadogContext.site.intakeEndpoint,
            "replay"
        )
    }

    private fun resolveHeaders(
        datadogContext: DatadogContext,
        requestId: String
    ): Map<String, String> {
        return mapOf(
            RequestFactory.HEADER_API_KEY to datadogContext.clientToken,
            RequestFactory.HEADER_EVP_ORIGIN to datadogContext.source,
            RequestFactory.HEADER_EVP_ORIGIN_VERSION to datadogContext.sdkVersion,
            RequestFactory.HEADER_REQUEST_ID to requestId
        )
    }

    private fun resolveRequest(context: DatadogContext, body: RequestBody): Request {
        val bodyAsByteArray = extractByteArrayFromBody(body)
        val requestId = UUID.randomUUID().toString()
        val description = "Session Replay Segment Upload Request"
        val headers = resolveHeaders(context, requestId)
        val requestUrl = buildUrl(context)
        return Request(
            requestId,
            description,
            requestUrl,
            headers,
            body = bodyAsByteArray,
            contentType = body.contentType().toString()
        )
    }

    private fun extractByteArrayFromBody(body: RequestBody): ByteArray {
        val buffer = Buffer()
        body.writeTo(buffer)
        return buffer.readByteArray()
    }

    companion object {
        private const val UPLOAD_URL = "%s/api/v2/%s"
    }
}
