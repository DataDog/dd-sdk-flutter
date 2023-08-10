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
import com.datadog.android.core.configuration.VitalsUpdateFrequency
import com.datadog.android.ndk.NdkCrashReportsPlugin
import com.datadog.android.plugin.Feature
import com.datadog.android.privacy.TrackingConsent
import com.datadog.android.rum.tracking.ViewTrackingStrategy

data class LoggingConfiguration(
    var sendNetworkInfo: Boolean,
    var printLogsToConsole: Boolean,
    var sendLogsToDatadog: Boolean,
    var bundleWithRum: Boolean,
    var loggerName: String?
) {
    constructor(encoded: Map<String, Any?>) : this(
        (encoded["sendNetworkInfo"] as? Boolean) ?: false,
        (encoded["printLogsToConsole"] as? Boolean) ?: false,
        (encoded["sendLogsToDatadog"] as? Boolean) ?: true,
        (encoded["bundleWithRum"] as? Boolean) ?: true,
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
    var telemetrySampleRate: Float? = null,
    var site: DatadogSite? = null,
    var serviceName: String? = null,
    var batchSize: BatchSize? = null,
    var uploadFrequency: UploadFrequency? = null,
    var customLogsEndpoint: String? = null,
    var firstPartyHosts: List<String> = listOf(),
    var additionalConfig: Map<String, Any?> = mapOf(),
    var attachLogMapper: Boolean = false,

    var rumConfiguration: RumConfiguration? = null
) {
    data class RumConfiguration(
        var applicationId: String,
        var sampleRate: Float,
        var detectLongTasks: Boolean,
        var longTaskThreshold: Float,
        var customEndpoint: String?,
        var attachViewEventMapper: Boolean = false,
        var attachActionEventMapper: Boolean = false,
        var attachResourceEventMapper: Boolean = false,
        var attachErrorEventMapper: Boolean = false,
        var attachLongTaskEventMapper: Boolean = false,
        var vitalsFrequency: VitalsUpdateFrequency? = null
    ) {
        constructor(encoded: Map<String, Any?>) : this(
            (encoded["applicationId"] as? String) ?: "",
            (encoded["sampleRate"] as? Number)?.toFloat() ?: 100.0f,
            (encoded["detectLongTasks"] as? Boolean) ?: true,
            (encoded["longTaskThreshold"] as? Number?)?.toFloat() ?: 0.1f,
            encoded["customEndpoint"] as? String,
            encoded["attachViewEventMapper"] as? Boolean ?: false,
            encoded["attachActionEventMapper"] as? Boolean ?: false,
            encoded["attachResourceEventMapper"] as? Boolean ?: false,
            encoded["attachErrorEventMapper"] as? Boolean ?: false,
            encoded["attachLongTaskEventMapper"] as? Boolean ?: false,
        ) {
            (encoded["vitalsFrequency"] as? String)?.let {
                vitalsFrequency = parseVitalsFrequency(it)
            }
        }
    }

    constructor(encoded: Map<String, Any?>) : this(
        (encoded["clientToken"] as? String) ?: "",
        (encoded["env"] as? String) ?: "",
        (encoded["nativeCrashReportEnabled"] as? Boolean) ?: false,
        TrackingConsent.PENDING
    ) {
        telemetrySampleRate = (encoded["telemetrySampleRate"] as? Number)?.toFloat()
        (encoded["trackingConsent"] as? String)?.let {
            trackingConsent = parseTrackingConsent(it)
        }
        (encoded["site"] as? String)?.let {
            site = parseSite(it)
        }
        (encoded["serviceName"] as? String)?.let {
            serviceName = it
        }
        (encoded["batchSize"] as? String)?.let {
            batchSize = parseBatchSize(it)
        }
        (encoded["uploadFrequency"] as? String)?.let {
            uploadFrequency = parseUploadFrequency(it)
        }
        customLogsEndpoint = encoded["customLogsEndpoint"] as? String
        @Suppress("UNCHECKED_CAST")
        (encoded["firstPartyHosts"] as? List<String>)?.let {
            firstPartyHosts = it
        }

        @Suppress("UNCHECKED_CAST")
        additionalConfig = (encoded["additionalConfig"] as? Map<String, Any?>) ?: mapOf()

        attachLogMapper = (encoded["attachLogMapper"] as? Boolean) ?: false

        @Suppress("UNCHECKED_CAST")
        (encoded["rumConfiguration"] as? Map<String, Any?>)?.let {
            rumConfiguration = RumConfiguration(it)
        }
    }

    fun toCredentials(): Credentials {
        val variant = additionalConfig["_dd.variant"] as? String

        return Credentials(
            clientToken = clientToken,
            envName = env,
            rumApplicationId = rumConfiguration?.applicationId,
            variant = variant ?: Credentials.NO_VARIANT,
            serviceName = serviceName
        )
    }

    @Suppress("ComplexMethod")
    fun toSdkConfigurationBuilder(): Configuration.Builder {
        val configBuilder = Configuration.Builder(
            // Always enable logging as users can create logs post initialization
            logsEnabled = true,
            crashReportsEnabled = nativeCrashReportEnabled,
            tracesEnabled = false,
            rumEnabled = rumConfiguration != null
        )
            .setAdditionalConfiguration(
                additionalConfig
                    .filterValues { it != null }
                    .mapValues { it.value!! }
            )
        if (nativeCrashReportEnabled) {
            configBuilder.addPlugin(NdkCrashReportsPlugin(), Feature.CRASH)
        }

        site?.let { configBuilder.useSite(it) }
        batchSize?.let { configBuilder.setBatchSize(it) }
        uploadFrequency?.let { configBuilder.setUploadFrequency(it) }
        telemetrySampleRate?.let { configBuilder.sampleTelemetry(it) }
        rumConfiguration?.let {
            configBuilder.sampleRumSessions(it.sampleRate)
            // Always disable user action tracking and view tracking for Flutter
            configBuilder.disableInteractionTracking()
            configBuilder.useViewTrackingStrategy(NoOpViewTrackingStrategy)
            // Native Android always has long task reporting - only sync the threshold
            configBuilder.trackLongTasks((it.longTaskThreshold * 1000).toLong())
            it.customEndpoint?.let { ce ->
                configBuilder.useCustomRumEndpoint(ce)
            }
            it.vitalsFrequency?.let { vf ->
                configBuilder.setVitalsUpdateFrequency(vf)
            }
        }

        customLogsEndpoint?.let {
            configBuilder.useCustomLogsEndpoint(it)
        }
        configBuilder.setFirstPartyHosts(firstPartyHosts)

        return configBuilder
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
        "DatadogSite.ap1" -> DatadogSite.AP1
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

internal fun parseVitalsFrequency(vitalsFrequency: String): VitalsUpdateFrequency {
    return when (vitalsFrequency) {
        "VitalsFrequency.frequent" -> VitalsUpdateFrequency.FREQUENT
        "VitalsFrequency.average" -> VitalsUpdateFrequency.AVERAGE
        "VitalsFrequency.rare" -> VitalsUpdateFrequency.RARE
        "VitalsFrequency.never" -> VitalsUpdateFrequency.NEVER
        else -> VitalsUpdateFrequency.AVERAGE
    }
}
