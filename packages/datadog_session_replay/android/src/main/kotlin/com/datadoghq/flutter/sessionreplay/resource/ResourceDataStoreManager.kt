/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.storage.datastore.DataStoreReadCallback
import com.datadog.android.api.storage.datastore.DataStoreWriteCallback
import com.datadog.android.core.internal.persistence.Deserializer
import com.datadog.android.core.persistence.Serializer
import com.datadog.android.core.persistence.datastore.DataStoreContent
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong

internal class ResourceDataStoreManager(
    private val featureSdkCore: FeatureSdkCore,
    private val gson: Gson = Gson(),
    private val dataStoreResetTimeNs: Long = TimeUnit.DAYS.toNanos(30)
) {
    @Suppress("UnsafeThirdPartyFunctionCall") // map is initialized empty
    private val knownResources = Collections.newSetFromMap(ConcurrentHashMap<String, Boolean>())
    private val storedLastUpdateDateNs = AtomicLong(featureSdkCore.timeProvider.getDeviceElapsedTimeNanos())
    private val isInitialized = AtomicBoolean(false) // has init finished executing its async actions

    init {
        fetchStoredResourceHashes(
            onFetchSuccessful = lambda@{ storedEntry ->
                val storedData = storedEntry?.data

                if (storedData == null) {
                    finishedInitializingManager()
                    return@lambda
                }

                val lastUpdateDateNs = storedData.lastUpdateDateNs
                val storedHashes = storedData.resourceHashes

                if (didDataStoreExpire(lastUpdateDateNs)) {
                    deleteStoredHashesEntry(
                        callback = object : DataStoreWriteCallback {
                            override fun onSuccess() {
                                finishedInitializingManager()
                            }

                            override fun onFailure() {
                                finishedInitializingManager()
                            }
                        }
                    )
                } else {
                    storedLastUpdateDateNs.set(lastUpdateDateNs)
                    knownResources.addAll(storedHashes)
                    finishedInitializingManager()
                }
            },
            onFetchFailure = {
                finishedInitializingManager()
            }
        )
    }

    internal fun isPreviouslySentResource(resourceHash: String): Boolean =
        knownResources.contains(resourceHash)

    internal fun cacheResourceHash(resourceHash: String) {
        knownResources.add(resourceHash)
        writeResourcesToStore()
    }

    internal fun isReady(): Boolean =
        isInitialized.get()

    // region internal

    private fun finishedInitializingManager() {
        isInitialized.set(true)
    }

    private fun writeResourcesToStore() {
        val data = ResourceHashesEntry(
            lastUpdateDateNs = storedLastUpdateDateNs.get(),
            resourceHashes = knownResources.toList()
        )

        dataStoreOrNull()?.setValue(
            Constants.DATASTORE_HASHES_ENTRY_KEY,
            data,
            Constants.CURRENT_STORE_VERSION,
            null,
            object : Serializer<ResourceHashesEntry> {
                override fun serialize(model: ResourceHashesEntry): String = gson.toJson(model)
            }
        )
    }

    private fun fetchStoredResourceHashes(
        onFetchSuccessful: (dataStoreContent: DataStoreContent<ResourceHashesEntry>?) -> Unit,
        onFetchFailure: () -> Unit
    ) {
        dataStoreOrNull()?.value(
            Constants.DATASTORE_HASHES_ENTRY_KEY,
            Constants.CURRENT_STORE_VERSION,
            object : DataStoreReadCallback<ResourceHashesEntry> {
                override fun onSuccess(dataStoreContent: DataStoreContent<ResourceHashesEntry>?) {
                    onFetchSuccessful(dataStoreContent)
                }

                override fun onFailure() {
                    onFetchFailure()
                }
            },
            object : Deserializer<String, ResourceHashesEntry> {
                override fun deserialize(model: String): ResourceHashesEntry? =
                    runCatching { gson.fromJson(model, ResourceHashesEntry::class.java) }.getOrNull()
            }
        )
    }

    private fun deleteStoredHashesEntry(callback: DataStoreWriteCallback) =
        dataStoreOrNull()?.removeValue(
            Constants.DATASTORE_HASHES_ENTRY_KEY,
            callback
        )

    private fun didDataStoreExpire(lastUpdateDate: Long): Boolean =
        featureSdkCore.timeProvider.getDeviceElapsedTimeNanos() - lastUpdateDate > dataStoreResetTimeNs

    // endregion

    private fun dataStoreOrNull() =
        featureSdkCore.getFeature(
            ResourceFeature.SESSION_REPLAY_RESOURCES_FEATURE_NAME
        )?.dataStore

    internal data class ResourceHashesEntry(
        @SerializedName("last_update_date_ns") val lastUpdateDateNs: Long,
        @SerializedName("resource_hashes") val resourceHashes: List<String>
    )

    internal object Constants {
        const val DATASTORE_HASHES_ENTRY_KEY = "resource-hash-store"
        const val CURRENT_STORE_VERSION = 1
    }
}
