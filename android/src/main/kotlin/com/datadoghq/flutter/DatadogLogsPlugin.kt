/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import com.datadog.android.log.Logger
import com.google.gson.Gson
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class DatadogLogsPlugin : MethodChannel.MethodCallHandler {
    companion object LogParameterNames {
        const val LOG_MESSAGE = "message"
        const val LOG_CONTEXT = "context"
        const val LOG_KEY = "key"
        const val LOG_TAG = "tag"
        const val LOG_VALUE = "value"
    }

    private val gson: Gson = Gson()
    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    private val log: Logger by lazy {
        Logger.Builder()
            .setDatadogLogsEnabled(true)
            .setLogcatLogsEnabled(true)
            .setLoggerName("DdLogs")
            .build()
    }

    fun setup(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter.logs")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding
    }

    @Suppress("LongMethod")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "debug" -> {
                val message = call.argument<String>(LOG_MESSAGE)!!
                val context = call.argument<Map<String, Any?>>(LOG_CONTEXT)!!

                log.d(message, attributes = context)
                result.success(null)
            }
            "info" -> {
                val message = call.argument<String>(LOG_MESSAGE)!!
                val context = call.argument<Map<String, Any?>>(LOG_CONTEXT)!!

                log.i(message, attributes = context)
                result.success(null)
            }
            "warn" -> {
                val message = call.argument<String>(LOG_MESSAGE)!!
                val context = call.argument<Map<String, Any?>>(LOG_CONTEXT)!!

                log.w(message, attributes = context)
                result.success(null)
            }
            "error" -> {
                val message = call.argument<String>(LOG_MESSAGE)!!
                val context = call.argument<Map<String, Any?>>(LOG_CONTEXT)!!

                log.e(message, attributes = context)
                result.success(null)
            }
            "addAttribute" -> {
                val key = call.argument<String>(LOG_KEY)
                val value = call.argument<Any>(LOG_VALUE)
                if (key != null && value != null) {
                    addAttributeInternal(key, value)
                }
                result.success(null)
            }
            "addTag" -> {
                call.argument<String>(LOG_TAG)?.let {
                    val value = call.argument<String>(LOG_VALUE)
                    if (value != null) {
                        log.addTag(it, value)
                    } else {
                        log.addTag(it)
                    }
                }
                result.success(null)
            }
            "removeAttribute" -> {
                call.argument<String>(LOG_KEY)?.let {
                    log.removeAttribute(it)
                }
                result.success(null)
            }
            "removeTag" -> {
                call.argument<String>(LOG_TAG)?.let {
                    log.removeTag(it)
                }
                result.success(null)
            }
            "removeTagWithKey" -> {
                call.argument<String>(LOG_KEY)?.let {
                    log.removeTagsWithKey(it)
                }
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    @Suppress("UNUSED_PARAMETER")
    fun teardown(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun addAttributeInternal(key: String, value: Any) {
        when (value) {
            is Boolean -> log.addAttribute(key, value)
            is Int -> log.addAttribute(key, value)
            is Long -> log.addAttribute(key, value)
            is String -> log.addAttribute(key, value)
            is Double -> log.addAttribute(key, value)
            is List<*> -> {
                val jsonList = gson.toJsonTree(value).asJsonArray
                log.addAttribute(key, jsonList)
            }
            is Map<*, *> -> {
                val jsonObject = gson.toJsonTree(value).asJsonObject
                log.addAttribute(key, jsonObject)
            }
        }
    }
}
