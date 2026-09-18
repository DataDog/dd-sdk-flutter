/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import assertk.assertThat
import assertk.assertions.hasSize
import assertk.assertions.isEqualTo
import assertk.assertions.isInstanceOf
import com.datadog.android.api.InternalLogger
import com.datadog.android.api.storage.RawBatchEvent
import com.datadoghq.flutter.sessionreplay.forge.SRForgeConfigurator
import com.datadoghq.flutter.sessionreplay.models.ResourceEvent
import com.datadoghq.flutter.sessionreplay.resource.ResourceRequestBodyFactory.Companion.APPLICATION_KEY
import com.datadoghq.flutter.sessionreplay.resource.ResourceRequestBodyFactory.Companion.CONTENT_TYPE_IMAGE
import com.datadoghq.flutter.sessionreplay.resource.ResourceRequestBodyFactory.Companion.ID_KEY
import com.datadoghq.flutter.sessionreplay.resource.ResourceRequestBodyFactory.Companion.TYPE_KEY
import com.datadoghq.flutter.sessionreplay.resource.ResourceRequestBodyFactory.Companion.TYPE_RESOURCE
import com.google.gson.JsonObject
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeConfiguration
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.mockk
import java.util.UUID
import okhttp3.MultipartBody
import okhttp3.MultipartBody.Part
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okio.Buffer
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
@ForgeConfiguration(SRForgeConfigurator::class)
class ResourceRequestBodyFactoryTest {
    val mockInteralLogger = mockk<InternalLogger>(relaxed = true)

    @StringForgery
    lateinit var fakeApplicationId: String

    @Test
    fun `M create valid requestBody W create()`(forge: Forge) {
        // Given
        val resourcePairs = forge.aList { generateValidRawBatchEvent(forge) }
        val factory = ResourceRequestBodyFactory(
            internalLogger = mockInteralLogger
        )
        val resources = resourcePairs.map { it.first }

        val applicationIdOuter = JsonObject()
        val applicationIdInner = JsonObject()
        applicationIdInner.addProperty(ID_KEY, fakeApplicationId)
        applicationIdOuter.add(APPLICATION_KEY, applicationIdInner)
        applicationIdOuter.addProperty(TYPE_KEY, TYPE_RESOURCE)
        val expectedFormMetadata = applicationIdOuter.toString()

        // When
        val requestBody = factory.create(resources)

        // Then
        requireNotNull(requestBody)
        assertThat(requestBody).isInstanceOf(MultipartBody::class.java)

        val contentType = requestBody.contentType()
        requireNotNull(contentType)

        assertThat(contentType.type).isEqualTo(MultipartBody.FORM.type)
        assertThat(contentType.subtype).isEqualTo(MultipartBody.FORM.subtype)

        val body = requestBody as MultipartBody
        val parts = body.parts

        val resourceParts = resourcePairs.mapIndexed { index, pair ->
            Part.createFormData(
                ResourceRequestBodyFactory.NAME_IMAGE,
                pair.second,
                pair.first.data.toRequestBody(CONTENT_TYPE_IMAGE)
            )
        }
        val metadataPart = Part.createFormData(
            ResourceRequestBodyFactory.NAME_EVENT,
            filename = ResourceRequestBodyFactory.FILENAME_BLOB,
            expectedFormMetadata.toString()
                .toRequestBody(ResourceRequestBodyFactory.CONTENT_TYPE_APPLICATION_JSON)
        )

        val expectedList = resourceParts + metadataPart

        assertThat(parts).hasSize(resourceParts.size + 1)
        for (i in expectedList.indices) {
            val part = parts[i]
            val expectedPart = expectedList[i]
            assertThat(part.headers).isEqualTo(expectedPart.headers)
            assertThat(part.body.toByteArray()).isEqualTo(expectedPart.body.toByteArray())
        }
    }

    private fun generateValidRawBatchEvent(forge: Forge): Pair<RawBatchEvent, String> {
        val fakeEvent = forge.getForgery<RawBatchEvent>()
        val fakeMetadata = JsonObject()
        val filename = forge.getForgery<UUID>().toString()
        fakeMetadata.addProperty(ResourceEvent.APPLICATION_ID_KEY, fakeApplicationId)
        fakeMetadata.addProperty(ResourceEvent.FILENAME_KEY, filename)
        return Pair(
            fakeEvent.copy(
                metadata = fakeMetadata.toString().toByteArray(Charsets.UTF_8)
            ),
            filename
        )
    }

    private fun RequestBody.toByteArray(): ByteArray {
        val buffer = Buffer()
        writeTo(buffer)
        return buffer.readByteArray()
    }
}
