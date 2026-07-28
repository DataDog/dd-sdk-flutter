/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.feature.FeatureScope
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.storage.EventBatchWriter
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
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

    @BeforeEach
    fun setUp() {
        every {
            mockSdkCore.getFeature(ResourceFeature.SESSION_REPLAY_RESOURCES_FEATURE_NAME)
        } returns mockScope
        every { mockScope.withWriteContext(any(), any()) } answers {
            val callback = secondArg<(DatadogContext, ((EventBatchWriter) -> Unit) -> Unit) -> Unit>()
            val mockContext = mockk<DatadogContext>()
            every { mockContext.featuresContext } returns emptyMap()
            val mockWriter = mockk<EventBatchWriter>(relaxed = true)
            callback(mockContext) { it(mockWriter) }
        }
        every { mockDataStoreManager.cacheResourceHash(any()) } just Runs
    }

    @Test
    fun `M write resource W write {new identifier, manager ready}`(
        @StringForgery identifier: String,
        @StringForgery resourceData: String
    ) {
        // Given
        every { mockDataStoreManager.isPreviouslySentResource(identifier) } returns false
        every { mockDataStoreManager.isReady() } returns true
        val writer = DefaultResourceWriter(mockSdkCore, mockDataStoreManager)

        // When
        writer.write(identifier, resourceData.toByteArray())

        // Then
        verify(exactly = 1) { mockDataStoreManager.cacheResourceHash(identifier) }
        verify(exactly = 1) { mockScope.withWriteContext(any(), any()) }
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
