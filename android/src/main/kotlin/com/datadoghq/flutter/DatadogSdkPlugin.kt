/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.util.Log
import androidx.annotation.NonNull
import com.datadog.android.Datadog
import com.datadog.android.DatadogSite
import com.datadog.android.core.configuration.BatchSize
import com.datadog.android.core.configuration.Configuration
import com.datadog.android.core.configuration.Credentials
import com.datadog.android.core.configuration.UploadFrequency
import com.datadog.android.privacy.TrackingConsent
import com.datadog.android.rum.GlobalRum
import com.datadog.android.rum.RumMonitor
import com.datadog.android.tracing.AndroidTracer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.opentracing.util.GlobalTracer

class DatadogSdkPlugin : FlutterPlugin, MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    private var logsPlugin: DatadogLogsPlugin? = null
    private var tracesPlugin: DatadogTracesPlugin? = null
    private var rumPlugin: DatadogRumPlugin? = null

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding

        logsPlugin = DatadogLogsPlugin()
        logsPlugin?.setup(flutterPluginBinding)

        tracesPlugin = DatadogTracesPlugin()
        tracesPlugin?.setup(flutterPluginBinding)

        rumPlugin = DatadogRumPlugin()
        rumPlugin?.setup(flutterPluginBinding)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> {
                val configArg = call.argument<Map<String, Any?>>("configuration")
                if (configArg != null) {
                    initialize(configArg)
                }
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)

        logsPlugin?.teardown(binding)
        logsPlugin = null

        tracesPlugin?.teardown(binding)
        tracesPlugin = null

        rumPlugin?.teardown(binding)
        rumPlugin = null
    }

    private fun initialize(encodedConfiguration: Map<String, Any?>) {
        val credentials = buildCredentials(encodedConfiguration)
        val configuration = buildSdkConfiguration(encodedConfiguration)
        val trackingConsent = parseTrackingConsent(
            encodedConfiguration["trackingConsent"] as String
        )

        Datadog.initialize(binding.applicationContext, credentials, configuration, trackingConsent)
        Datadog.setVerbosity(Log.VERBOSE)

        GlobalTracer.registerIfAbsent(AndroidTracer.Builder().build())
        GlobalRum.registerIfAbsent(RumMonitor.Builder().build())
    }
}

internal fun buildSdkConfiguration(encoded: Map<String, Any?>): Configuration {
    @Suppress("UNCHECKED_CAST")
    val additionalConfig = encoded["additionalConfig"] as Map<String, Any?>?
    val configBuilder = Configuration.Builder(
        logsEnabled = true,
        tracesEnabled = true,
        crashReportsEnabled = false,
        rumEnabled = true
    )
        .setAdditionalConfiguration(
            additionalConfig
                ?.filterValues { it != null }
                ?.mapValues { it.value!! } ?: emptyMap()
        )

    encoded["site"]?.let {
        configBuilder.useSite(parseSite(it as String))
    }
    encoded["batchSize"]?.let {
        configBuilder.setBatchSize(parseBatchSize(it as String))
    }
    encoded["uploadFrequency"]?.let {
        configBuilder.setUploadFrequency(parseUploadFrequency(it as String))
    }
    encoded["sampleRate"]?.let {
        configBuilder.sampleRumSessions((it as Double).toFloat())
    }

    encoded["customEndpoint"]?.let {
        val customEndpoint = it as String
        configBuilder.useCustomLogsEndpoint(customEndpoint)
        configBuilder.useCustomTracesEndpoint(customEndpoint)
        configBuilder.useCustomRumEndpoint(customEndpoint)
    }

    return configBuilder.build()
}

internal fun buildCredentials(encoded: Map<String, Any?>): Credentials {
    @Suppress("UNCHECKED_CAST")
    val additionalConfig = encoded["additionalConfig"] as Map<String, Any?>?
    val serviceName = additionalConfig?.get("_dd.service_name") as? String

    return Credentials(
        clientToken = encoded["clientToken"] as String,
        envName = encoded["env"] as String,
        rumApplicationId = encoded["applicationId"] as String?,
        variant = Credentials.NO_VARIANT,
        serviceName = serviceName
    )
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
