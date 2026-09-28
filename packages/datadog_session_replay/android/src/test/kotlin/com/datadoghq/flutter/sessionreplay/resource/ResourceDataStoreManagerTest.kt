/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import assertk.assertThat
import assertk.assertions.isFalse
import assertk.assertions.isTrue
import com.datadog.android.api.feature.FeatureScope
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.storage.datastore.DataStoreHandler
import com.datadog.android.api.storage.datastore.DataStoreReadCallback
import com.datadog.android.api.storage.datastore.DataStoreWriteCallback
import com.datadog.android.core.internal.persistence.Deserializer
import com.datadog.android.core.persistence.Serializer
import com.datadog.android.core.persistence.datastore.DataStoreContent
import com.datadog.android.internal.time.TimeProvider
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.every
import io.mockk.mockk
import java.util.concurrent.TimeUnit
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
internal class ResourceDataStoreManagerTest {
    val mockSdkCore = mockk<FeatureSdkCore>(relaxed = true)
    val mockScope = mockk<FeatureScope>()
    private val fakeDataStore = FakeDataStoreHandler()
    private var fakeTimestampMs = TimeUnit.DAYS.toMillis(60)

    @BeforeEach
    fun setUp() {
        every {
            mockSdkCore.getFeature(ResourceFeature.SESSION_REPLAY_RESOURCES_FEATURE_NAME)
        } returns mockScope
        every { mockScope.dataStore } returns fakeDataStore
        every { mockSdkCore.timeProvider } returns FakeTimeProvider { fakeTimestampMs }
    }

    @Test
    fun `M return false W isPreviouslySentResource {resource was not sent}`(
        @StringForgery hash: String
    ) {
        // Given
        val manager = ResourceDataStoreManager(mockSdkCore)

        // Then
        assertThat(manager.isPreviouslySentResource(hash)).isFalse()
    }

    @Test
    fun `M return true W isPreviouslySentResource {after cacheResourceHash}`(
        @StringForgery hash: String
    ) {
        // Given
        val manager = ResourceDataStoreManager(mockSdkCore)

        // When
        manager.cacheResourceHash(hash)

        // Then
        assertThat(manager.isPreviouslySentResource(hash)).isTrue()
    }

    @Test
    fun `M persist to datastore W cacheResourceHash`(
        @StringForgery hash: String
    ) {
        // Given
        val manager = ResourceDataStoreManager(mockSdkCore)

        // When
        manager.cacheResourceHash(hash)

        // Then
        assertThat(
            fakeDataStore.storage.containsKey(ResourceDataStoreManager.Constants.DATASTORE_HASHES_ENTRY_KEY)
        ).isTrue()
    }

    @Test
    fun `M seed known hashes W init {recent store}`(
        @StringForgery hash: String
    ) {
        // Given
        fakeDataStore.storage[ResourceDataStoreManager.Constants.DATASTORE_HASHES_ENTRY_KEY] =
            ResourceDataStoreManager.Constants.CURRENT_STORE_VERSION to
            "{\"last_update_date_ms\":$fakeTimestampMs,\"resource_hashes\":[\"$hash\"]}"

        // When
        val manager = ResourceDataStoreManager(mockSdkCore)

        // Then
        assertThat(manager.isPreviouslySentResource(hash)).isTrue()
        assertThat(manager.isReady()).isTrue()
    }

    @Test
    fun `M not seed known hashes and reset store W init {stale store}`(
        @StringForgery hash: String
    ) {
        // Given
        val staleUpdateMs = fakeTimestampMs - TimeUnit.DAYS.toMillis(31)
        fakeDataStore.storage[ResourceDataStoreManager.Constants.DATASTORE_HASHES_ENTRY_KEY] =
            ResourceDataStoreManager.Constants.CURRENT_STORE_VERSION to
            "{\"last_update_date_ms\":$staleUpdateMs,\"resource_hashes\":[\"$hash\"]}"

        // When
        val manager = ResourceDataStoreManager(mockSdkCore)

        // Then
        assertThat(manager.isPreviouslySentResource(hash)).isFalse()
        assertThat(manager.isReady()).isTrue()
        assertThat(
            fakeDataStore.storage.containsKey(ResourceDataStoreManager.Constants.DATASTORE_HASHES_ENTRY_KEY)
        ).isFalse()
    }

    @Test
    fun `M use a fresh creation time W cacheResourceHash {after a stale-store reset}`(
        @StringForgery hash: String,
        @StringForgery staleHash: String
    ) {
        // Given
        val staleUpdateMs = fakeTimestampMs - TimeUnit.DAYS.toMillis(31)
        fakeDataStore.storage[ResourceDataStoreManager.Constants.DATASTORE_HASHES_ENTRY_KEY] =
            ResourceDataStoreManager.Constants.CURRENT_STORE_VERSION to
            "{\"last_update_date_ms\":$staleUpdateMs,\"resource_hashes\":[\"$staleHash\"]}"
        val manager = ResourceDataStoreManager(mockSdkCore)

        // When
        manager.cacheResourceHash(hash)

        // Then
        val persisted = fakeDataStore.storage[ResourceDataStoreManager.Constants.DATASTORE_HASHES_ENTRY_KEY]
        assertThat(persisted?.second?.contains("\"last_update_date_ms\":$staleUpdateMs") ?: false).isFalse()
    }

    @Test
    fun `M return isReady true W init {no data to fetch}`() {
        // When
        val manager = ResourceDataStoreManager(mockSdkCore)

        // Then
        assertThat(manager.isReady()).isTrue()
    }

    @Test
    fun `M return isReady true W init {failed to fetch entry}`(
        @StringForgery hash: String
    ) {
        // Given
        every { mockScope.dataStore } returns FailingReadDataStoreHandler()

        // When
        val manager = ResourceDataStoreManager(mockSdkCore)

        // Then
        assertThat(manager.isReady()).isTrue()
        assertThat(manager.isPreviouslySentResource(hash)).isFalse()
    }

    @Test
    fun `M return isReady true W init {got expired entry, failed deleting}`(
        @StringForgery hash: String
    ) {
        // Given
        val staleUpdateMs = fakeTimestampMs - TimeUnit.DAYS.toMillis(31)
        fakeDataStore.storage[ResourceDataStoreManager.Constants.DATASTORE_HASHES_ENTRY_KEY] =
            ResourceDataStoreManager.Constants.CURRENT_STORE_VERSION to
            "{\"last_update_date_ms\":$staleUpdateMs,\"resource_hashes\":[\"$hash\"]}"
        fakeDataStore.failOnRemove = true

        // When
        val manager = ResourceDataStoreManager(mockSdkCore)

        // Then
        assertThat(manager.isReady()).isTrue()
    }

    /**
     * In-memory fake mirroring the real DataStoreHandler contract, so tests can exercise
     * seeding/persistence/reset behavior without mocking every generic serializer/deserializer.
     */
    private class FakeDataStoreHandler : DataStoreHandler {
        val storage = mutableMapOf<String, Pair<Int, String>>()
        var failOnRemove = false

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
            if (failOnRemove) {
                callback?.onFailure()
                return
            }
            storage.remove(key)
            callback?.onSuccess()
        }

        override fun clearAllData() {
            storage.clear()
        }
    }

    private class FakeTimeProvider(private val timestampMs: () -> Long) : TimeProvider {
        override fun getDeviceTimestampMillis(): Long = timestampMs()
        override fun getServerTimestampMillis(): Long = 0L
        override fun getDeviceElapsedTimeNanos(): Long = 0L
        override fun getServerOffsetNanos(): Long = 0L
        override fun getServerOffsetMillis(): Long = 0L
        override fun getDeviceElapsedRealtimeMillis(): Long = 0L
        override fun getDeviceUptimeMillis(): Long = 0L
    }

    /** Fake that always fails to read, to exercise the `onFetchFailure` path of `init`. */
    private class FailingReadDataStoreHandler : DataStoreHandler {
        override fun <T : Any> setValue(
            key: String,
            data: T,
            version: Int,
            callback: DataStoreWriteCallback?,
            serializer: Serializer<T>
        ) {
            callback?.onSuccess()
        }

        override fun <T : Any> value(
            key: String,
            version: Int?,
            callback: DataStoreReadCallback<T>,
            deserializer: Deserializer<String, T>
        ) {
            callback.onFailure()
        }

        override fun removeValue(key: String, callback: DataStoreWriteCallback?) {
            callback?.onSuccess()
        }

        override fun clearAllData() {
            // no-op
        }
    }
}
