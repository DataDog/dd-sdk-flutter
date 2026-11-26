/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import assertk.assertThat
import assertk.assertions.isEqualTo
import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureScope
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.storage.EventBatchWriter
import com.datadog.android.api.storage.EventType
import com.datadog.android.api.storage.RawBatchEvent
import com.datadog.android.internal.FeatureContextKeys
import com.datadog.android.internal.rum.RumContext
import com.datadoghq.flutter.sessionreplay.models.ResourceEvent
import com.google.gson.JsonParser
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import io.mockk.verifyOrder
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
internal class ResourceWriterTest {
    val mockSdkCore = mockk<FeatureSdkCore>()
    val mockScope = mockk<FeatureScope>()
    val mockDataStoreManager = mockk<ResourceDataStoreManager>()
    private val mockContext = mockk<DatadogContext>()
    private val mockWriter = mockk<EventBatchWriter>(relaxed = true)

    @BeforeEach
    fun setUp() {
        every {
            mockSdkCore.getFeature(ResourceFeature.SESSION_REPLAY_RESOURCES_FEATURE_NAME)
        } returns mockScope
        every { mockContext.featuresContext } returns emptyMap()
        every { mockScope.withWriteContext(any(), any()) } answers {
            val callback = secondArg<(DatadogContext, ((EventBatchWriter) -> Unit) -> Unit) -> Unit>()
            callback(mockContext) { it(mockWriter) }
        }
        every { mockDataStoreManager.cacheResourceHash(any()) } just Runs
    }

    @Test
    fun `M write resource with the RUM application ID W write {new identifier, manager ready}`(
        @StringForgery identifier: String,
        @StringForgery resourceData: String,
        @StringForgery fakeApplicationId: String
    ) {
        // Given
        val rumContext = mockk<RumContext> {
            every { applicationId } returns fakeApplicationId
        }
        every { mockContext.featuresContext } returns mapOf(
            Feature.RUM_FEATURE_NAME to mapOf(FeatureContextKeys.RUM_CONTEXT to rumContext)
        )
        every { mockDataStoreManager.isPreviouslySentResource(identifier) } returns false
        every { mockDataStoreManager.isReady() } returns true
        val writer = DefaultResourceWriter(mockSdkCore, mockDataStoreManager)

        // When
        writer.write(identifier, resourceData.toByteArray())

        // Then
        verify(exactly = 1) { mockDataStoreManager.cacheResourceHash(identifier) }
        verify(exactly = 1) { mockScope.withWriteContext(setOf(Feature.RUM_FEATURE_NAME), any()) }

        val event = slot<RawBatchEvent>()
        verify { mockWriter.write(capture(event), null, EventType.DEFAULT) }
        val metadata = JsonParser.parseString(checkNotNull(event.captured.metadata).toString(Charsets.UTF_8))
        assertThat(metadata.asJsonObject.get(ResourceEvent.APPLICATION_ID_KEY).asString).isEqualTo(fakeApplicationId)
    }

    @Test
    fun `M cache identifier before writing resource W write {new identifier}`(
        @StringForgery identifier: String,
        @StringForgery resourceData: String
    ) {
        // Given
        every { mockDataStoreManager.isPreviouslySentResource(identifier) } returns false
        every { mockDataStoreManager.isReady() } returns true
        val writer = DefaultResourceWriter(mockSdkCore, mockDataStoreManager)

        // When
        writer.write(identifier, resourceData.toByteArray())

        // Then - mirrors native's mark-before-write ordering, rather than marking only
        // after the write succeeds
        verifyOrder {
            mockDataStoreManager.cacheResourceHash(identifier)
            mockScope.withWriteContext(any(), any())
        }
    }

    @Test
    fun `M not write resource W write {identifier already known}`(
        @StringForgery identifier: String,
        @StringForgery resourceData: String
    ) {
        // Given
        every { mockDataStoreManager.isPreviouslySentResource(identifier) } returns true

        val writer = DefaultResourceWriter(mockSdkCore, mockDataStoreManager)

        // When
        writer.write(identifier, resourceData.toByteArray())

        // Then
        verify(exactly = 0) { mockScope.withWriteContext(any(), any()) }
        verify(exactly = 0) { mockDataStoreManager.cacheResourceHash(any()) }
    }

    @Test
    fun `M write resource but not cache it W write {manager not ready yet}`(
        @StringForgery identifier: String,
        @StringForgery resourceData: String
    ) {
        // Given
        every { mockDataStoreManager.isPreviouslySentResource(identifier) } returns false
        every { mockDataStoreManager.isReady() } returns false

        val writer = DefaultResourceWriter(mockSdkCore, mockDataStoreManager)

        // When
        writer.write(identifier, resourceData.toByteArray())

        // Then - matches native: caching would overwrite the datastore entry before the
        // initial load has finished, so it's skipped, but the resource is still uploaded
        verify(exactly = 1) { mockScope.withWriteContext(any(), any()) }
        verify(exactly = 0) { mockDataStoreManager.cacheResourceHash(any()) }
    }
}
