/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import androidx.annotation.NonNull
import com.datadog.android.Datadog
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class DatadogSdkPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    var logsPlugin: DatadogLogsPlugin? = null
        private set
    var tracesPlugin: DatadogTracesPlugin? = null
        private set
    var rumPlugin: DatadogRumPlugin? = null
        private set

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> {
                val configArg = call.argument<Map<String, Any?>>("configuration")
                if (configArg != null) {
                    val config = DatadogFlutterConfiguration(configArg)
                    initialize(config)
                }
                result.success(null)
            }
            "setSdkVerbosity" -> {
                call.argument<String>("value")?.let {
                    val verbosity = parseVerbosity(it)
                    Datadog.setVerbosity(verbosity)
                }
                result.success(null)
            }
            "setTrackingConsent" -> {
                call.argument<String>("value")?.let {
                    val trackingConsent = parseTrackingConsent(it)
                    Datadog.setTrackingConsent(trackingConsent)
                }
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    fun initialize(config: DatadogFlutterConfiguration) {
        val configuration = config.toSdkConfiguration()
        val credentials = config.toCredentials()

        Datadog.initialize(
            binding.applicationContext, credentials, configuration,
            config.trackingConsent
        )

        if (config.loggingConfiguration != null) {
            logsPlugin = DatadogLogsPlugin()
            logsPlugin?.setup(binding, config.loggingConfiguration!!)
        }

        if (config.tracingConfiguration != null) {
            tracesPlugin = DatadogTracesPlugin()
            tracesPlugin?.setup(binding, config.tracingConfiguration!!)
        }

        if (config.rumConfiguration != null) {
            rumPlugin = DatadogRumPlugin()
            rumPlugin?.setup(binding, config.rumConfiguration!!)
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
}
