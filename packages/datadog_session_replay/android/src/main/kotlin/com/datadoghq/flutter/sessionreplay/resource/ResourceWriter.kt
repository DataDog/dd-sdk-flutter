/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.resource

import com.datadog.android.api.context.DatadogContext
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureSdkCore
import com.datadog.android.api.storage.EventType
import com.datadog.android.api.storage.RawBatchEvent
import com.datadog.android.api.storage.datastore.DataStoreHandler
import com.datadog.android.api.storage.datastore.DataStoreReadCallback
import com.datadog.android.core.internal.persistence.Deserializer
import com.datadog.android.core.persistence.Serializer
import com.datadog.android.core.persistence.datastore.DataStoreContent
import com.datadoghq.flutter.sessionreplay.models.ResourceEvent
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

internal interface ResourceWriter {
    fun write(identifier: String, resourceData: ByteArray)
}

/**
 * Writes resolved image resources to the Session Replay resources feature, caching which
 * MD5 identifiers have already been sent (in-memory, then seeded/persisted through the
 * feature's [DataStoreHandler]) so the same image isn't re-uploaded across app sessions.
 */
internal class DefaultResourceWriter(
    private val sdkCore: FeatureSdkCore,
    private val gson: Gson = Gson(),
    private val dataStoreResetTimeMs: Long = TimeUnit.DAYS.toMillis(30)
) : ResourceWriter {
    private val knownIdentifiers: MutableSet<String> = mutableSetOf()
    private val hasLoadedFromDataStore = AtomicBoolean(false)

    override fun write(identifier: String, resourceData: ByteArray) {
        loadKnownIdentifiersIfNeeded()

        val alreadyKnown = synchronized(knownIdentifiers) { knownIdentifiers.contains(identifier) }
        if (alreadyKnown) {
            return
        }

        sdkCore.getFeature(ResourceFeature.SESSION_REPLAY_RESOURCES_FEATURE_NAME)
            ?.withWriteContext(
                withFeatureContexts = setOf(Feature.RUM_FEATURE_NAME)
            ) { datadogContext, writeScope ->
                synchronized(this) {
                    val resourceEvent = ResourceEvent(
                        identifier = identifier,
                        resourceData = resourceData,
                        applicationId = datadogContext.rumApplicationId
                    )

                    writeScope {
                        it.write(
                            event = RawBatchEvent(
                                data = resourceEvent.resourceData,
                                metadata = resourceEvent.createBinaryMetadata()
                            ),
                            batchMetadata = null,
                            eventType = EventType.DEFAULT
                        )
                    }
                }

                synchronized(knownIdentifiers) { knownIdentifiers.add(identifier) }
                persistKnownIdentifiers()
            }
    }

    private fun dataStoreOrNull(): DataStoreHandler? =
        sdkCore.getFeature(ResourceFeature.SESSION_REPLAY_RESOURCES_FEATURE_NAME)?.dataStore

    /**
     * [ResourceFeature] is registered after this writer is constructed (see
     * `FlutterSessionReplayFeature.onInitialize`), so the data store can't be seeded eagerly
     * in `init`. Instead, seed it lazily on first write, retrying on later writes until the
     * feature is registered.
     */
    private fun loadKnownIdentifiersIfNeeded() {
        if (!hasLoadedFromDataStore.compareAndSet(false, true)) {
            return
        }

        val dataStore = dataStoreOrNull()
        if (dataStore == null) {
            hasLoadedFromDataStore.set(false)
            return
        }

        dataStore.value(
            Constants.STORE_CREATION_KEY,
            Constants.CURRENT_STORE_VERSION,
            object : DataStoreReadCallback<Long> {
                override fun onSuccess(dataStoreContent: DataStoreContent<Long>?) {
                    val storeCreation = dataStoreContent?.data
                    if (storeCreation != null &&
                        System.currentTimeMillis() - storeCreation < dataStoreResetTimeMs
                    ) {
                        loadKnownResources(dataStore)
                    } else {
                        // Missing or older than the reset window - start a fresh store.
                        resetDataStore(dataStore)
                    }
                }

                override fun onFailure() {
                    // Leave knownIdentifiers empty; a future write will retry via persistKnownIdentifiers.
                }
            },
            object : Deserializer<String, Long> {
                override fun deserialize(model: String): Long? = model.toLongOrNull()
            }
        )
    }

    private fun loadKnownResources(dataStore: DataStoreHandler) {
        dataStore.value(
            Constants.KNOWN_RESOURCES_KEY,
            Constants.CURRENT_STORE_VERSION,
            object : DataStoreReadCallback<Set<String>> {
                override fun onSuccess(dataStoreContent: DataStoreContent<Set<String>>?) {
                    dataStoreContent?.data?.let {
                        synchronized(knownIdentifiers) { knownIdentifiers.addAll(it) }
                    }
                }

                override fun onFailure() {
                    // No previously known resources to seed with.
                }
            },
            object : Deserializer<String, Set<String>> {
                override fun deserialize(model: String): Set<String>? =
                    runCatching { gson.fromJson<Set<String>>(model, KNOWN_RESOURCES_TYPE) }.getOrNull()
            }
        )
    }

    private fun resetDataStore(dataStore: DataStoreHandler) {
        dataStore.setValue(
            Constants.STORE_CREATION_KEY,
            System.currentTimeMillis(),
            Constants.CURRENT_STORE_VERSION,
            null,
            object : Serializer<Long> {
                override fun serialize(model: Long): String = model.toString()
            }
        )
        dataStore.removeValue(Constants.KNOWN_RESOURCES_KEY, null)
    }

    private fun persistKnownIdentifiers() {
        val dataStore = dataStoreOrNull() ?: return
        val snapshot = synchronized(knownIdentifiers) { knownIdentifiers.toSet() }
        dataStore.setValue(
            Constants.KNOWN_RESOURCES_KEY,
            snapshot,
            Constants.CURRENT_STORE_VERSION,
            null,
            object : Serializer<Set<String>> {
                override fun serialize(model: Set<String>): String = gson.toJson(model)
            }
        )
    }

    private val DatadogContext.rumApplicationId: String
        get() = (
            featuresContext[Feature.RUM_FEATURE_NAME]
                ?.get("application_id") as? String
            ).orEmpty()

    private companion object {
        val KNOWN_RESOURCES_TYPE = object : TypeToken<Set<String>>() {}.type
    }

    internal object Constants {
        const val KNOWN_RESOURCES_KEY = "known-resources"
        const val STORE_CREATION_KEY = "store-creation"
        const val CURRENT_STORE_VERSION = 1
    }
}
