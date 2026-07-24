/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import assertk.assertThat
import assertk.assertions.isEqualTo
import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.feature.FeatureScope
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.storage.EventBatchWriter
import com.datadog.android.api.storage.datastore.DataStoreHandler
import com.datadog.android.api.storage.datastore.DataStoreReadCallback
import com.datadog.android.api.storage.datastore.DataStoreWriteCallback
import com.datadog.android.core.internal.persistence.Deserializer
import com.datadog.android.core.persistence.Serializer
import com.datadog.android.core.persistence.datastore.DataStoreContent
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import java.util.concurrent.TimeUnit
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
internal class ResourceWriterTest {
    val mockSdkCore = mockk<FeatureSdkCore>()
    val mockScope = mockk<FeatureScope>()
    private val fakeDataStore = FakeDataStoreHandler()

    fun setUp() {
        every {
            mockSdkCore.getFeature(ResourceFeature.SESSION_REPLAY_RESOURCES_FEATURE_NAME)
        } returns mockScope
        every { mockScope.dataStore } returns fakeDataStore
        every { mockScope.withWriteContext(any(), any()) } answers {
            val callback = secondArg<(DatadogContext, ((EventBatchWriter) -> Unit) -> Unit) -> Unit>()
            val mockContext = mockk<DatadogContext>()
            every { mockContext.featuresContext } returns emptyMap()
            val mockWriter = mockk<EventBatchWriter>(relaxed = true)
            callback(mockContext) { it(mockWriter) }
        }
    }

    @Test
    fun `M write resource W write {new identifier}`(
        @StringForgery identifier: String,
        @StringForgery resourceData: String
    ) {
        // Given
        setUp()
        val writer = DefaultResourceWriter(mockSdkCore)

        // When
        writer.write(identifier, resourceData.toByteArray())

        // Then
        verify(exactly = 1) { mockScope.withWriteContext(any(), any()) }
    }

    @Test
    fun `M write resource only once W write {same identifier, same instance}`(
        @StringForgery identifier: String,
        @StringForgery resourceData: String
    ) {
        // Given
        setUp()
        val writer = DefaultResourceWriter(mockSdkCore)

        // When
        writer.write(identifier, resourceData.toByteArray())
        writer.write(identifier, resourceData.toByteArray())

        // Then
        verify(exactly = 1) { mockScope.withWriteContext(any(), any()) }
    }

    @Test
    fun `M not write resource W write {identifier known from previous session}`(
        @StringForgery identifier: String,
        @StringForgery resourceData: String
    ) {
        // Given
        setUp()
        val firstSessionWriter = DefaultResourceWriter(mockSdkCore)
        firstSessionWriter.write(identifier, resourceData.toByteArray())

        // When - a new writer instance simulates a new app session sharing the same data store
        val secondSessionWriter = DefaultResourceWriter(mockSdkCore)
        secondSessionWriter.write(identifier, resourceData.toByteArray())

        // Then
        verify(exactly = 1) { mockScope.withWriteContext(any(), any()) }
    }

    @Test
    fun `M write resource W write {identifier known, but store creation is stale}`(
        @StringForgery identifier: String,
        @StringForgery resourceData: String
    ) {
        // Given
        setUp()
        val resetTimeMs = TimeUnit.SECONDS.toMillis(1)
        val staleStoreCreation = System.currentTimeMillis() - resetTimeMs * 2
        fakeDataStore.storage[DefaultResourceWriter.Constants.STORE_CREATION_KEY] =
            DefaultResourceWriter.Constants.CURRENT_STORE_VERSION to staleStoreCreation.toString()
        fakeDataStore.storage[DefaultResourceWriter.Constants.KNOWN_RESOURCES_KEY] =
            DefaultResourceWriter.Constants.CURRENT_STORE_VERSION to "[\"$identifier\"]"
        val writer = DefaultResourceWriter(mockSdkCore, dataStoreResetTimeMs = resetTimeMs)

        // When
        writer.write(identifier, resourceData.toByteArray())

        // Then
        verify(exactly = 1) { mockScope.withWriteContext(any(), any()) }
        assertThat(fakeDataStore.storage.containsKey(DefaultResourceWriter.Constants.KNOWN_RESOURCES_KEY))
            .isEqualTo(true)
    }

    @Test
    fun `M not write resource W write {identifier known, store creation is recent}`(
        @StringForgery identifier: String,
        @StringForgery resourceData: String
    ) {
        // Given
        setUp()
        val resetTimeMs = TimeUnit.DAYS.toMillis(30)
        fakeDataStore.storage[DefaultResourceWriter.Constants.STORE_CREATION_KEY] =
            DefaultResourceWriter.Constants.CURRENT_STORE_VERSION to System.currentTimeMillis().toString()
        fakeDataStore.storage[DefaultResourceWriter.Constants.KNOWN_RESOURCES_KEY] =
            DefaultResourceWriter.Constants.CURRENT_STORE_VERSION to "[\"$identifier\"]"
        val writer = DefaultResourceWriter(mockSdkCore, dataStoreResetTimeMs = resetTimeMs)

        // When
        writer.write(identifier, resourceData.toByteArray())

        // Then
        verify(exactly = 0) { mockScope.withWriteContext(any(), any()) }
    }

    /**
     * In-memory fake mirroring the real DataStoreHandler contract, so tests can exercise
     * seeding/persistence/reset behavior without mocking every generic serializer/deserializer.
     */
    private class FakeDataStoreHandler : DataStoreHandler {
        val storage = mutableMapOf<String, Pair<Int, String>>()

        override fun <T : Any> setValue(
            key: String,
            data: T,
            version: Int,
            callback: DataStoreWriteCallback?,
            serializer: Serializer<T>
        ) {
            val serialized = serializer.serialize(data)
            if (serialized != null) {
                storage[key] = version to serialized
            }
            callback?.onSuccess()
        }

        override fun <T : Any> value(
            key: String,
            version: Int?,
            callback: DataStoreReadCallback<T>,
            deserializer: Deserializer<String, T>
        ) {
            val stored = storage[key]
            if (stored == null) {
                callback.onSuccess(null)
                return
            }
            val (storedVersion, raw) = stored
            callback.onSuccess(DataStoreContent(storedVersion, deserializer.deserialize(raw)))
        }

        override fun removeValue(key: String, callback: DataStoreWriteCallback?) {
            storage.remove(key)
            callback?.onSuccess()
        }

        override fun clearAllData() {
            storage.clear()
        }
    }
}
