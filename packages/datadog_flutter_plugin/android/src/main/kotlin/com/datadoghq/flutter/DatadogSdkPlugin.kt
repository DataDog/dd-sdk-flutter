/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import androidx.annotation.NonNull
import com.datadog.android.Datadog
import com.datadog.android.rum.GlobalRum
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ExecutorService
import java.util.concurrent.SynchronousQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class DatadogSdkPlugin : FlutterPlugin, MethodCallHandler {
    companion object ErrorCodes {
        const val CONTRACT_VIOLATION = "DatadogSdk:ContractViolation"
        const val INVALID_OPERATION = "DatadogSdk:InvalidOperation"
    }

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    // Only used to shutdown Datadog in debug builds
    private val executor: ExecutorService = ThreadPoolExecutor(
        0, 1, 30L,
        TimeUnit.SECONDS, SynchronousQueue<Runnable>()
    )

    var logsPlugin: DatadogLogsPlugin? = null
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
            "setUserInfo" -> {
                val id = call.argument<String>("id")
                val name = call.argument<String>("name")
                val email = call.argument<String>("email")
                val extraInfo = call.argument<Map<String, Any?>>("extraInfo")
                if (extraInfo != null) {
                    Datadog.setUserInfo(id, name, email, extraInfo)
                }
                result.success(null)
            }
            "flushAndDeinitialize" -> {
                invokePrivateShutdown(result)
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

        // Always setup logging as a user can create a log after initialization
        logsPlugin = DatadogLogsPlugin().apply { setup(binding) }

        if (config.rumConfiguration != null) {
            rumPlugin = DatadogRumPlugin().apply { setup(binding, config.rumConfiguration!!) }
        }
    }

    fun simpleInvokeOn(methodName: String, target: Any) {
        val klass = target.javaClass
        val method = klass.declaredMethods.firstOrNull {
            it.name == methodName || it.name == "$methodName\$dd_sdk_android_release"
        }
        method?.let {
            it.isAccessible = true
            it.invoke(target)
        }
    }

    fun invokePrivateShutdown(result: Result) {
        executor.execute {
            simpleInvokeOn("flushAndShutdownExecutors", Datadog)
            simpleInvokeOn("stop", Datadog)

            val rumRegisteredField = GlobalRum::class.java.getDeclaredField("isRegistered")
            rumRegisteredField.isAccessible = true
            val isRegistered: AtomicBoolean = rumRegisteredField.get(null) as AtomicBoolean
            isRegistered.set(false)

            logsPlugin?.teardown(binding)
            logsPlugin = null

            rumPlugin?.teardown(binding)
            rumPlugin = null

            result.success(null)
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)

        logsPlugin?.teardown(binding)
        logsPlugin = null

        rumPlugin?.teardown(binding)
        rumPlugin = null
    }
}
