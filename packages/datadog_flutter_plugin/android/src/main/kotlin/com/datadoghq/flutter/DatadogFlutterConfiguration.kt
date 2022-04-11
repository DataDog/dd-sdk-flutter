/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.content.Context
import android.util.Log
import com.datadog.android.DatadogSite
import com.datadog.android.core.configuration.BatchSize
import com.datadog.android.core.configuration.Configuration
import com.datadog.android.core.configuration.Credentials
import com.datadog.android.core.configuration.UploadFrequency
import com.datadog.android.ndk.NdkCrashReportsPlugin
import com.datadog.android.plugin.Feature
import com.datadog.android.privacy.TrackingConsent
import com.datadog.android.rum.tracking.ViewTrackingStrategy

data class LoggingConfiguration(
    var sendNetworkInfo: Boolean,
    var printLogsToConsole: Boolean,
    var sendLogsToDatadog: Boolean,
    var bundleWithRum: Boolean,
    var bundleWithTraces: Boolean,
    var loggerName: String?
) {
    constructor(encoded: Map<String, Any?>) : this(
        (encoded["sendNetworkInfo"] as? Boolean) ?: false,
        (encoded["printLogsToConsole"] as? Boolean) ?: false,
        (encoded["sendLogsToDatadog"] as? Boolean) ?: true,
        (encoded["bundleWithRum"] as? Boolean) ?: true,
        (encoded["bundleWithTraces"] as? Boolean) ?: true,
        (encoded["loggerName"] as? String)
    )
}

// Duplicated strings in this file do not mean they are being used in the same context
@Suppress("StringLiteralDuplication")
data class DatadogFlutterConfiguration(
    var clientToken: String,
    var env: String,
    var nativeCrashReportEnabled: Boolean,
    var trackingConsent: TrackingConsent,
    var site: DatadogSite? = null,
    var batchSize: BatchSize? = null,
    var uploadFrequency: UploadFrequency? = null,
    var customEndpoint: String? = null,
    var additionalConfig: Map<String, Any?> = mapOf(),

    var tracingConfiguration: TracingConfiguration? = null,
    var rumConfiguration: RumConfiguration? = null
) {
    data class TracingConfiguration(
        var sendNetworkInfo: Boolean,
        var bundleWithRum: Boolean,
    ) {
        constructor(encoded: Map<String, Any?>) : this(
            encoded["sendNetworkInfo"] as? Boolean ?: false,
            encoded["bundleWithRum"] as? Boolean ?: true
        )
    }

    data class RumConfiguration(
        var applicationId: String,
        var sampleRate: Float
    ) {
        constructor(encoded: Map<String, Any?>) : this(
            (encoded["applicationId"] as? String) ?: "",
            (encoded["sampleRate"] as? Number)?.toFloat() ?: 100.0f
        )
    }

    constructor(encoded: Map<String, Any?>) : this(
        (encoded["clientToken"] as? String) ?: "",
        (encoded["env"] as? String) ?: "",
        (encoded["nativeCrashReportEnabled"] as? Boolean) ?: false,
        TrackingConsent.PENDING
    ) {
        (encoded["trackingConsent"] as? String)?.let {
            trackingConsent = parseTrackingConsent(it)
        }
        (encoded["site"] as? String)?.let {
            site = parseSite(it)
        }
        (encoded["batchSize"] as? String)?.let {
            batchSize = parseBatchSize(it)
        }
        (encoded["uploadFrequency"] as? String)?.let {
            uploadFrequency = parseUploadFrequency(it)
        }
        customEndpoint = encoded["customEndpoint"] as? String

        @Suppress("UNCHECKED_CAST")
        additionalConfig = (encoded["additionalConfig"] as? Map<String, Any?>) ?: mapOf()

        @Suppress("UNCHECKED_CAST")
        (encoded["tracingConfiguration"] as? Map<String, Any?>)?.let {
            tracingConfiguration = TracingConfiguration(it)
        }
        @Suppress("UNCHECKED_CAST")
        (encoded["rumConfiguration"] as? Map<String, Any?>)?.let {
            rumConfiguration = RumConfiguration(it)
        }
    }

    fun toCredentials(): Credentials {
        val serviceName = additionalConfig["_dd.service_name"] as? String
        return Credentials(
            clientToken = clientToken,
            envName = env,
            rumApplicationId = rumConfiguration?.applicationId,
            variant = Credentials.NO_VARIANT,
            serviceName = serviceName
        )
    }

    fun toSdkConfiguration(): Configuration {
        val configBuilder = Configuration.Builder(
            // Always enable logging as users can create logs post initialization
            logsEnabled = true,
            tracesEnabled = tracingConfiguration != null,
            crashReportsEnabled = nativeCrashReportEnabled,
            rumEnabled = rumConfiguration != null
        )
            .setAdditionalConfiguration(
                additionalConfig
                    ?.filterValues { it != null }
                    ?.mapValues { it.value!! } ?: emptyMap()
            )
        if (nativeCrashReportEnabled) {
            configBuilder.addPlugin(NdkCrashReportsPlugin(), Feature.CRASH)
        }

        site?.let { configBuilder.useSite(it) }
        batchSize?.let { configBuilder.setBatchSize(it) }
        uploadFrequency?.let { configBuilder.setUploadFrequency(it) }
        rumConfiguration?.let {
            configBuilder.sampleRumSessions(it.sampleRate)
            configBuilder.useViewTrackingStrategy(NoOpViewTrackingStrategy)
        }
        customEndpoint?.let {
            configBuilder.useCustomLogsEndpoint(it)
            configBuilder.useCustomTracesEndpoint(it)
            configBuilder.useCustomRumEndpoint(it)
        }

        return configBuilder.build()
    }
}

object NoOpViewTrackingStrategy : ViewTrackingStrategy {
    override fun register(context: Context) {
        // Nop
    }

    override fun unregister(context: Context?) {
        // Nop
    }
}

internal fun parseBatchSize(batchSize: String): BatchSize {
    return when (batchSize) {
        "BatchSize.small" -> BatchSize.SMALL
        "BatchSize.medium" -> BatchSize.MEDIUM
        "BatchSize.large" -> BatchSize.LARGE
        else -> BatchSize.MEDIUM
    }
}

internal fun parseUploadFrequency(uploadFrequency: String): UploadFrequency {
    return when (uploadFrequency) {
        "UploadFrequency.frequent" -> UploadFrequency.FREQUENT
        "UploadFrequency.average" -> UploadFrequency.AVERAGE
        "UploadFrequency.rare" -> UploadFrequency.RARE
        else -> UploadFrequency.AVERAGE
    }
}

internal fun parseTrackingConsent(trackingConsent: String): TrackingConsent {
    return when (trackingConsent) {
        "TrackingConsent.granted" -> TrackingConsent.GRANTED
        "TrackingConsent.notGranted" -> TrackingConsent.NOT_GRANTED
        "TrackingConsent.pending" -> TrackingConsent.PENDING
        else -> TrackingConsent.PENDING
    }
}

internal fun parseSite(site: String): DatadogSite {
    return when (site) {
        "DatadogSite.us1" -> DatadogSite.US1
        "DatadogSite.us3" -> DatadogSite.US3
        "DatadogSite.us5" -> DatadogSite.US5
        "DatadogSite.eu1" -> DatadogSite.EU1
        "DatadogSite.us1Fed" -> DatadogSite.US1_FED
        else -> DatadogSite.US1
    }
}

internal fun parseVerbosity(verbosity: String): Int {
    return when (verbosity) {
        "Verbosity.verbose" -> Log.VERBOSE
        "Verbosity.debug" -> Log.DEBUG
        "Verbosity.info" -> Log.INFO
        "Verbosity.warn" -> Log.WARN
        "Verbosity.error" -> Log.ERROR
        "Verbosity.none" -> Int.MAX_VALUE
        else -> Int.MAX_VALUE
    }
}
