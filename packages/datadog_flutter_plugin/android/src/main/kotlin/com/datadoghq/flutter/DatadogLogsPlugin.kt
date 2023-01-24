/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.util.Log
import com.datadog.android.log.Logger
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ClassCastException
import java.lang.NullPointerException
import org.json.JSONArray
import org.json.JSONObject

class DatadogLogsPlugin : MethodChannel.MethodCallHandler {
    companion object LogParameterNames {
        const val LOG_LEVEL = "logLevel"
        const val LOG_MESSAGE = "message"
        const val LOG_CONTEXT = "context"
        const val LOG_ERROR_MESSAGE = "errorMessage"
        const val LOG_ERROR_KIND = "errorKind"
        const val LOG_STACK_TRACE = "stackTrace"
        const val LOG_KEY = "key"
        const val LOG_TAG = "tag"
        const val LOG_VALUE = "value"
    }

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    private val loggerRegistry: MutableMap<String, Logger> = mutableMapOf()

    fun attachToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter.logs")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding
    }

    fun detachFromEngine() {
        channel.setMethodCallHandler(null)
    }

    internal fun addLogger(loggerHandle: String, logger: Logger) {
        loggerRegistry[loggerHandle] = logger
    }

    fun getLogger(loggerHandle: String): Logger? {
        return loggerRegistry[loggerHandle]
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val loggerHandle = call.argument<String>("loggerHandle")
        if (loggerHandle == null) {
            result.missingParameter(call.method)
            return
        }

        if (call.method == "createLogger") {
            val encodedConfig = call.argument<Map<String, Any?>>("configuration")
            if (encodedConfig != null) {
                createLogger(loggerHandle, LoggingConfiguration(encodedConfig))
                result.success(null)
            } else {
                result.invalidOperation("Bad logging configuration creating a logger")
            }
            return
        }

        getLogger(loggerHandle)?.let { logger ->
            try {
                callLoggingMethod(logger, call, result)
            } catch (e: ClassCastException) {
                result.error(
                    DatadogSdkPlugin.CONTRACT_VIOLATION, e.toString(),
                    mapOf(
                        "methodName" to call.method
                    )
                )
            }
        }
    }

    @Suppress("LongMethod", "ComplexMethod", "NestedBlockDepth")
    private fun callLoggingMethod(logger: Logger, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "log" -> {
                internalLog(logger, call, result)
            }
            "addAttribute" -> {
                val key = call.argument<String>(LOG_KEY)
                val value = call.argument<Any>(LOG_VALUE)
                if (key != null && value != null) {
                    addAttributeInternal(logger, key, value)
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            "addTag" -> {
                val tag = call.argument<String>(LOG_TAG)
                if (tag != null) {
                    val value = call.argument<String>(LOG_VALUE)
                    if (value != null) {
                        logger.addTag(tag, value)
                    } else {
                        logger.addTag(tag)
                    }
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            "removeAttribute" -> {
                val key = call.argument<String>(LOG_KEY)
                if (key != null) {
                    logger.removeAttribute(key)
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            "removeTag" -> {
                val tag = call.argument<String>(LOG_TAG)
                if (tag != null) {
                    logger.removeTag(tag)
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            "removeTagWithKey" -> {
                val key = call.argument<String>(LOG_KEY)
                if (key != null) {
                    logger.removeTagsWithKey(key)
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun createLogger(loggerHandle: String, configuration: LoggingConfiguration) {
        val logBuilder = Logger.Builder()
            .setDatadogLogsEnabled(configuration.sendLogsToDatadog)
            .setLogcatLogsEnabled(configuration.printLogsToConsole)
            .setNetworkInfoEnabled(configuration.sendNetworkInfo)
            .setBundleWithRumEnabled(configuration.bundleWithRum)

        configuration.loggerName?.let {
            logBuilder.setLoggerName(it)
        }
        val logger = logBuilder.build()
        loggerRegistry[loggerHandle] = logger
    }

    @Suppress("TooGenericExceptionCaught")
    private fun internalLog(
        logger: Logger,
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        try {
            val message = call.argument<String>(LOG_MESSAGE)!!
            val level = parseLogLevel(call.argument<String>(LOG_LEVEL)!!)
            val context = call.argument<Map<String, Any?>>(LOG_CONTEXT)!!

            // Optional parameters
            val errorKind = call.argument<String>(LOG_ERROR_KIND)
            val errorMessage = call.argument<String>(LOG_ERROR_MESSAGE)
            val stackTrace = call.argument<String>(LOG_STACK_TRACE)

            logger.log(level, message, errorKind, errorMessage, stackTrace, context)

            result.success(null)
        } catch (e: ClassCastException) {
            result.error(DatadogSdkPlugin.CONTRACT_VIOLATION, e.stackTraceToString(), null)
        } catch (e: NullPointerException) {
            result.error(DatadogSdkPlugin.CONTRACT_VIOLATION, e.stackTraceToString(), null)
        }
    }

    private fun addAttributeInternal(logger: Logger, key: String, value: Any) {
        when (value) {
            is Boolean -> logger.addAttribute(key, value)
            is Int -> logger.addAttribute(key, value)
            is Long -> logger.addAttribute(key, value)
            is String -> logger.addAttribute(key, value)
            is Double -> logger.addAttribute(key, value)
            is List<*> -> {
                val jsonList = JSONArray(value)
                logger.addAttribute(key, jsonList)
            }
            is Map<*, *> -> {
                val jsonObject = JSONObject(value)
                logger.addAttribute(key, jsonObject)
            }
        }
    }
}

internal fun parseLogLevel(logLevel: String): Int {
    return when (logLevel) {
        "LogLevel.debug" -> Log.DEBUG
        "LogLevel.info" -> Log.INFO
        "LogLevel.notice" -> Log.WARN
        "LogLevel.warning" -> Log.WARN
        "LogLevel.error" -> Log.ERROR
        "LogLevel.critical" -> Log.ASSERT
        "LogLevel.alert" -> Log.ASSERT
        "LogLevel.emergency" -> Log.ASSERT
        else -> Log.INFO
    }
}
