/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import com.datadog.android.bridge.DdBridge
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DatadogLogs : MethodChannel.MethodCallHandler {
    companion object LogParameterNames {
        const val LOG_MESSAGE = "message"
        const val LOG_CONTEXT = "context"
    }

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    fun setup(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter.logs")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "debug" -> {
                val message = call.argument<String>(LogParameterNames.LOG_MESSAGE)!!
                val context = call.argument<Map<String, Any?>>(LogParameterNames.LOG_CONTEXT)!!

                DdBridge.getDdLogs(binding.applicationContext).debug(message, context)
                result.success(null)
            }
            "info" -> {
                val message = call.argument<String>(LogParameterNames.LOG_MESSAGE)!!
                val context = call.argument<Map<String, Any?>>(LogParameterNames.LOG_CONTEXT)!!

                DdBridge.getDdLogs(binding.applicationContext).info(message, context)
                result.success(null)
            }
            "warn" -> {
                val message = call.argument<String>(LogParameterNames.LOG_MESSAGE)!!
                val context = call.argument<Map<String, Any?>>(LogParameterNames.LOG_CONTEXT)!!

                DdBridge.getDdLogs(binding.applicationContext).warn(message, context)
                result.success(null)
            }
            "error" -> {
                val message = call.argument<String>(LogParameterNames.LOG_MESSAGE)!!
                val context = call.argument<Map<String, Any?>>(LogParameterNames.LOG_CONTEXT)!!

                DdBridge.getDdLogs(binding.applicationContext).error(message, context)
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    fun teardown(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
