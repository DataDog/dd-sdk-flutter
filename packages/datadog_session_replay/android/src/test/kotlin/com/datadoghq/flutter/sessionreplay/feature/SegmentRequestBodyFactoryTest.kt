/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import assertk.assertThat
import assertk.assertions.hasSize
import assertk.assertions.isEqualTo
import assertk.assertions.isInstanceOf
import com.datadoghq.flutter.sessionreplay.forge.SRForgeConfigurator
import com.datadoghq.flutter.sessionreplay.models.MobileSegment
import com.google.gson.JsonArray
import com.google.gson.JsonObject
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.junit5.ForgeConfiguration
import fr.xgouchet.elmyr.junit5.ForgeExtension
import okhttp3.MultipartBody
import okhttp3.MultipartBody.Part
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okio.Buffer
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
@ForgeConfiguration(SRForgeConfigurator::class)
internal class SegmentRequestBodyFactoryTest {
    @Test
    fun `M return a multipart body W create`(
        forge: Forge
    ) {
        // Given
        val fakeGroupedSegments = forge.aList(size = forge.anInt(min = 1, max = 10)) {
            val mobileSegment = forge.getForgery<MobileSegment>()
            Pair(mobileSegment, mobileSegment.toJson() as JsonObject)
        }
        val compressedData = fakeGroupedSegments.map {
            BytesCompressor.compressBytes((it.second.toString() + "\n").toByteArray())
        }
        val expectedFormMetadata = fakeGroupedSegments
            .mapIndexed { index, pair ->
                pair.first.toJson().asJsonObject.apply {
                    addProperty(
                        SegmentRequestBodyFactory.COMPRESSED_SEGMENT_SIZE_FORM_KEY,
                        compressedData[index].size
                    )
                    addProperty(
                        SegmentRequestBodyFactory.RAW_SEGMENT_SIZE_FORM_KEY,
                        (pair.second.toString() + "\n").toByteArray().size
                    )
                }
            }.fold(JsonArray()) { acc, element ->
                acc.add(element)
                acc
            }

        // When
        val requestBodyFactory = SegmentRequestBodyFactory()
        val body = requestBodyFactory.create(fakeGroupedSegments)

        // Then
        assertThat(body).isInstanceOf(MultipartBody::class.java)
        val multipartBody = body as MultipartBody
        assertThat(multipartBody.type).isEqualTo(MultipartBody.FORM)
        val parts = multipartBody.parts

        val compressedSegmentParts = compressedData.mapIndexed { index, bytes ->
            Part.createFormData(
                SegmentRequestBodyFactory.SEGMENT_DATA_FORM_KEY,
                "${SegmentRequestBodyFactory.BINARY_FILENAME_PREFIX}$index",
                bytes.toRequestBody(SegmentRequestBodyFactory.CONTENT_TYPE_BINARY_TYPE)
            )
        }
        val metadataPart = Part.createFormData(
            SegmentRequestBodyFactory.EVENT_NAME_FORM_KEY,
            filename = SegmentRequestBodyFactory.BLOB_FILENAME,
            expectedFormMetadata.toString()
                .toRequestBody(SegmentRequestBodyFactory.CONTENT_TYPE_JSON_TYPE)
        )

        assertThat(parts).hasSize(compressedData.size + 1)
        for (i in compressedSegmentParts.indices) {
            val part = parts[i]
            val expectedPart = if (i < compressedSegmentParts.size) {
                compressedSegmentParts[i]
            } else {
                metadataPart
            }
            assertThat(part.headers).isEqualTo(expectedPart.headers)
            assertThat(part.body.toByteArray()).isEqualTo(expectedPart.body.toByteArray())
        }
    }

    private fun RequestBody.toByteArray(): ByteArray {
        val buffer = Buffer()
        writeTo(buffer)
        return buffer.readByteArray()
    }
}
