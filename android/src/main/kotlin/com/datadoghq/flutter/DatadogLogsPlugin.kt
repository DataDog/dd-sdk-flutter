/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import com.datadog.android.log.Logger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ClassCastException
import java.lang.NullPointerException
import org.json.JSONArray
import org.json.JSONObject

class DatadogLogsPlugin(
    logInstance: Logger? = null
) : MethodChannel.MethodCallHandler {
    companion object LogParameterNames {
        const val LOG_MESSAGE = "message"
        const val LOG_CONTEXT = "context"
        const val LOG_KEY = "key"
        const val LOG_TAG = "tag"
        const val LOG_VALUE = "value"
    }

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    lateinit var log: Logger
        private set

    init {
        if (logInstance != null) {
            log = logInstance
        }
    }

    fun setup(
        flutterPluginBinding: FlutterPlugin.FlutterPluginBinding,
        configuration: DatadogFlutterConfiguration.LoggingConfiguration
    ) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter.logs")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding

        log = Logger.Builder()
            .setDatadogLogsEnabled(true)
            .setLogcatLogsEnabled(configuration.printLogsToConsole)
            .setNetworkInfoEnabled(configuration.sendNetworkInfo)
            .setBundleWithTraceEnabled(configuration.bundleWithTraces)
            .setBundleWithRumEnabled(configuration.bundleWithRum)
            .setLoggerName("DdLogs")
            .build()
    }

    @Suppress("LongMethod", "ComplexMethod", "NestedBlockDepth")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "debug" -> {
                    internalLog(call, result) { message, context ->
                        log.d(message, attributes = context)
                    }
                }
                "info" -> {
                    internalLog(call, result) { message, context ->
                        log.i(message, attributes = context)
                    }
                }
                "warn" -> {
                    internalLog(call, result) { message, context ->
                        log.w(message, attributes = context)
                    }
                }
                "error" -> {
                    internalLog(call, result) { message, context ->
                        log.e(message, attributes = context)
                    }
                }
                "addAttribute" -> {
                    val key = call.argument<String>(LOG_KEY)
                    val value = call.argument<Any>(LOG_VALUE)
                    if (key != null && value != null) {
                        addAttributeInternal(key, value)
                        result.success(null)
                    } else {
                        result.error(
                            DatadogSdkPlugin.CONTRACT_VIOLATION,
                            "Null parameter in addAttribute",
                            null
                        )
                    }
                }
                "addTag" -> {
                    val tag = call.argument<String>(LOG_TAG)
                    if (tag != null) {
                        val value = call.argument<String>(LOG_VALUE)
                        if (value != null) {
                            log.addTag(tag, value)
                        } else {
                            log.addTag(tag)
                        }
                        result.success(null)
                    } else {
                        result.error(
                            DatadogSdkPlugin.CONTRACT_VIOLATION,
                            "Null parameter in addTag",
                            null
                        )
                    }
                }
                "removeAttribute" -> {
                    val key = call.argument<String>(LOG_KEY)
                    if (key != null) {
                        log.removeAttribute(key)
                        result.success(null)
                    } else {
                        result.error(
                            DatadogSdkPlugin.CONTRACT_VIOLATION,
                            "Null parameter in remoteAttribute",
                            null
                        )
                    }
                }
                "removeTag" -> {
                    val tag = call.argument<String>(LOG_TAG)
                    if (tag != null) {
                        log.removeTag(tag)
                        result.success(null)
                    } else {
                        result.error(
                            DatadogSdkPlugin.CONTRACT_VIOLATION,
                            "Null parameter in removeTag",
                            null
                        )
                    }
                }
                "removeTagWithKey" -> {
                    val key = call.argument<String>(LOG_KEY)
                    if (key != null) {
                        log.removeTagsWithKey(key)
                        result.success(null)
                    } else {
                        result.error(
                            DatadogSdkPlugin.CONTRACT_VIOLATION,
                            "Null parameter in removeTagWithKey",
                            null
                        )
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: ClassCastException) {
            result.error(
                DatadogSdkPlugin.CONTRACT_VIOLATION, e.toString(),
                mapOf(
                    "methodName" to call.method
                )
            )
        }
    }

    @Suppress("UNUSED_PARAMETER")
    fun teardown(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    @Suppress("TooGenericExceptionCaught")
    private fun internalLog(
        call: MethodCall,
        result: MethodChannel.Result,
        logFunction: (message: String, attributes: Map<String, Any?>) -> Unit
    ) {
        try {
            val message = call.argument<String>(LOG_MESSAGE)!!
            val context = call.argument<Map<String, Any?>>(LOG_CONTEXT)!!

            logFunction(message, context)

            result.success(null)
        } catch (e: ClassCastException) {
            result.error(DatadogSdkPlugin.CONTRACT_VIOLATION, e.toString(), null)
        } catch (e: NullPointerException) {
            result.error(DatadogSdkPlugin.CONTRACT_VIOLATION, e.toString(), null)
        }
    }

    private fun addAttributeInternal(key: String, value: Any) {
        when (value) {
            is Boolean -> log.addAttribute(key, value)
            is Int -> log.addAttribute(key, value)
            is Long -> log.addAttribute(key, value)
            is String -> log.addAttribute(key, value)
            is Double -> log.addAttribute(key, value)
            is List<*> -> {
                val jsonList = JSONArray(value)
                log.addAttribute(key, jsonList)
            }
            is Map<*, *> -> {
                val jsonObject = JSONObject(value)
                log.addAttribute(key, jsonObject)
            }
        }
    }
}
