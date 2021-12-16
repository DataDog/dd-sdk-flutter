/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import androidx.annotation.NonNull
import com.datadog.android.bridge.DdBridge
import com.datadog.android.bridge.DdSdkConfiguration
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

fun decodeDdSdkConfiguration(encoded: HashMap<String, Any?>): DdSdkConfiguration {
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

object LogParameterNames {
    const val LOG_MESSAGE = "message"
    const val LOG_CONTEXT = "context"
}

class DatadogSdkPlugin : FlutterPlugin, MethodCallHandler {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "DdSdk.initialize" -> {
                val configuration = call.argument<HashMap<String, Any?>>("configuration")
                    ?.let { decodeDdSdkConfiguration(it) }
                DdBridge.getDdSdk(binding.applicationContext).initialize(configuration!!)
            }
            "DdLogs.debug" -> {
                val message = call.argument<String>(LogParameterNames.LOG_MESSAGE)!!
                val context = call.argument<HashMap<String, Any?>>(LogParameterNames.LOG_CONTEXT)!!

                DdBridge.getDdLogs(binding.applicationContext).debug(message, context)
            }
            "DdLogs.info" -> {
                val message = call.argument<String>(LogParameterNames.LOG_MESSAGE)!!
                val context = call.argument<HashMap<String, Any?>>(LogParameterNames.LOG_CONTEXT)!!

                DdBridge.getDdLogs(binding.applicationContext).info(message, context)
            }
            "DdLogs.warn" -> {
                val message = call.argument<String>(LogParameterNames.LOG_MESSAGE)!!
                val context = call.argument<HashMap<String, Any?>>(LogParameterNames.LOG_CONTEXT)!!

                DdBridge.getDdLogs(binding.applicationContext).warn(message, context)
            }
            "DdLogs.error" -> {
                val message = call.argument<String>(LogParameterNames.LOG_MESSAGE)!!
                val context = call.argument<HashMap<String, Any?>>(LogParameterNames.LOG_CONTEXT)!!

                DdBridge.getDdLogs(binding.applicationContext).error(message, context)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
