/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import androidx.annotation.NonNull
import com.datadog.android.Datadog
import com.datadog.android.bridge.DdSdkConfiguration
import com.datadog.android.core.configuration.Configuration
import com.datadog.android.core.configuration.Credentials
import com.datadog.android.privacy.TrackingConsent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

fun decodeDdSdkConfiguration(encoded: Map<String, Any?>): DdSdkConfiguration {
    @Suppress("UNCHECKED_CAST")
    return DdSdkConfiguration(
        clientToken = encoded["clientToken"] as String,
        env = encoded["env"] as String,
        applicationId = encoded["applicationId"] as String?,
        nativeCrashReportEnabled = encoded["nativeCrashReportEnabled"] as Boolean,
        sampleRate = encoded["sampleRate"] as Double?,
        site = encoded["site"] as String?,
        trackingConsent = encoded["trackingConsent"] as String?,
        additionalConfig = encoded["additionalConfig"] as Map<String, Any?>?
    )
}

class DatadogSdkPlugin : FlutterPlugin, MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    private var logs: DatadogLogs? = null

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding

        logs = DatadogLogs()
        logs?.setup(flutterPluginBinding)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> {
                val configArg = call.argument<Map<String, Any?>>("configuration")
                if (configArg != null) {
                    val configuration = decodeDdSdkConfiguration(configArg)
                    val customEndpoint = configArg["customEndpoint"] as String?
                    initialize(configuration, customEndpoint)
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

        logs?.teardown(binding)
        logs = null
    }

    private fun initialize(configuration: DdSdkConfiguration, customEndpoint: String?) {
        val serviceName = configuration.additionalConfig?.get("_dd.service_name") as? String
        val credentials = Credentials(
            clientToken = configuration.clientToken,
            envName = configuration.env,
            rumApplicationId = configuration.applicationId,
            variant = "",
            serviceName = serviceName
        )

        val configBuilder = Configuration.Builder(
            logsEnabled = true,
            tracesEnabled = true,
            crashReportsEnabled = configuration.nativeCrashReportEnabled ?: false,
            rumEnabled = true
        )
            .setAdditionalConfiguration(
                configuration.additionalConfig
                    ?.filterValues { it != null }
                    ?.mapValues { it.value!! } ?: emptyMap()
            )
        if (configuration.sampleRate != null) {
            configBuilder.sampleRumSessions(configuration.sampleRate!!.toFloat())
        }
        if (customEndpoint != null) {
            configBuilder.useCustomLogsEndpoint(customEndpoint)
            configBuilder.useCustomTracesEndpoint(customEndpoint)
            configBuilder.useCustomRumEndpoint(customEndpoint)
        }

        val config = configBuilder.build()

        Datadog.initialize(binding.applicationContext, credentials, config, TrackingConsent.GRANTED)
    }
}
