/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.app.Notification.Action
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import com.datadog.android.Datadog
import com.datadog.android._InternalProxy
import com.datadog.android.core.configuration.Configuration
import com.datadog.android.event.EventMapper
import com.datadog.android.event.ViewEventMapper
import com.datadog.android.log.model.LogEvent
import com.datadog.android.rum.GlobalRum
import com.datadog.android.rum.model.ActionEvent
import com.datadog.android.rum.model.ResourceEvent
import com.datadog.android.rum.model.ViewEvent
import com.datadog.android.telemetry.model.TelemetryConfigurationEvent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.SynchronousQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class DatadogSdkPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        const val CONTRACT_VIOLATION = "DatadogSdk:ContractViolation"
        const val INVALID_OPERATION = "DatadogSdk:InvalidOperation"
        const val ARG_VALUE = "value"

        // Flutter can destroy / recreate the plugin object if the engine detaches. If you use the
        // back button on the first screen, for example, this will detach the Flutter engine
        // but the application will still be running. We keep the configuration separate
        // from the plugin to warn about reinitialization.
        var previousConfiguration: DatadogFlutterConfiguration? = null
    }

    data class ConfigurationTelemetryOverrides(
        var trackViewsManually: Boolean = true,
        var trackInteractions: Boolean = false,
        var trackErrors: Boolean = false,
        var trackNetworkRequests: Boolean = false,
        var trackNativeViews: Boolean = false,
        var trackCrossPlatformLongTasks: Boolean = false,
        var trackFlutterPerformance: Boolean = false
    )

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    internal val telemetryOverrides = ConfigurationTelemetryOverrides()

    // Only used to shutdown Datadog in debug builds
    private val executor: ExecutorService = ThreadPoolExecutor(
        0, 1, 30L,
        TimeUnit.SECONDS, SynchronousQueue<Runnable>()
    )

    val logsPlugin: DatadogLogsPlugin = DatadogLogsPlugin()
    val rumPlugin: DatadogRumPlugin = DatadogRumPlugin()

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding

        logsPlugin.attachToEngine(flutterPluginBinding)
        rumPlugin.attachToEngine(flutterPluginBinding)
    }

    @Suppress("LongMethod")
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "initialize" -> {
                val configArg = call.argument<Map<String, Any?>>("configuration")
                if (configArg != null) {
                    val config = DatadogFlutterConfiguration(configArg)
                    if (!Datadog.isInitialized()) {
                        initialize(config)
                        previousConfiguration = config
                    } else if (config != previousConfiguration) {
                        // Maybe use DevLogger instead?
                        Log.e(DATADOG_FLUTTER_TAG, MESSAGE_INVALID_REINITIALIZATION)
                    }
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            "attachToExisting" -> {
                if (Datadog.isInitialized()) {
                    val attachResult = attachToExising()
                    result.success(attachResult)
                } else {
                    Log.e(DATADOG_FLUTTER_TAG, MESSAGE_NO_EXISTING_INSTANCE)
                    result.success(null)
                }
            }
            "setSdkVerbosity" -> {
                val value = call.argument<String>(ARG_VALUE)
                if (value != null) {
                    val verbosity = parseVerbosity(value)
                    Datadog.setVerbosity(verbosity)
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            "setTrackingConsent" -> {
                val value = call.argument<String>(ARG_VALUE)
                if (value != null) {
                    val trackingConsent = parseTrackingConsent(value)
                    Datadog.setTrackingConsent(trackingConsent)
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            "setUserInfo" -> {
                val id = call.argument<String>("id")
                val name = call.argument<String>("name")
                val email = call.argument<String>("email")
                val extraInfo = call.argument<Map<String, Any?>>("extraInfo")
                if (extraInfo != null) {
                    Datadog.setUserInfo(id, name, email, extraInfo)
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            "addUserExtraInfo" -> {
                val extraInfo = call.argument<Map<String, Any?>>("extraInfo")
                if (extraInfo != null) {
                    Datadog.addUserExtraInfo(extraInfo)
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            "telemetryDebug" -> {
                val message = call.argument<String>("message")
                if (message != null) {
                    Datadog._internal._telemetry.debug(message)
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            "telemetryError" -> {
                val message = call.argument<String>("message")
                if (message != null) {
                    val stack = call.argument<String>("stack")
                    val kind = call.argument<String>("kind")
                    Datadog._internal._telemetry.error(message, stack, kind)
                    result.success(null)
                } else {
                    result.missingParameter(call.method)
                }
            }
            "updateTelemetryConfiguration" -> {
                updateTelemetryConfiguration(call)
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
        val configBuilder = config.toSdkConfigurationBuilder()
        val credentials = config.toCredentials()

        _InternalProxy.setTelemetryConfigurationEventMapper(
            configBuilder,
            object : EventMapper<TelemetryConfigurationEvent> {
                override fun map(event: TelemetryConfigurationEvent): TelemetryConfigurationEvent? {
                    return mapTelemetryConfiguration(event)
                }
            }

        )

        attachEventMappers(config, configBuilder)

        Datadog.initialize(
            binding.applicationContext, credentials, configBuilder.build(),
            config.trackingConsent
        )

        if (config.rumConfiguration != null) {
            rumPlugin.setup(config.rumConfiguration!!)
        }
    }

    fun attachToExising(): Map<String, Any> {
        var rumEnabled = false
        if (GlobalRum.isRegistered()) {
            rumEnabled = true
            rumPlugin.attachToExistingSdk()
        }

        return mapOf<String, Any>(
            "rumEnabled" to rumEnabled
        )
    }

    fun updateTelemetryConfiguration(call: MethodCall) {
        var isValid = true

        val option = call.argument<String>("option")
        val value = call.argument<Boolean>(ARG_VALUE)
        if (option != null && value != null) {
            when (option) {
                "trackViewsManually" -> telemetryOverrides.trackViewsManually = value
                "trackInteractions" -> telemetryOverrides.trackInteractions = value
                "trackErrors" -> telemetryOverrides.trackErrors = value
                "trackNetworkRequests" -> telemetryOverrides.trackNetworkRequests = value
                "trackNativeViews" -> telemetryOverrides.trackNativeViews = value
                "trackCrossPlatformLongTasks" ->
                    telemetryOverrides.trackCrossPlatformLongTasks = value
                "trackFlutterPerformance" -> telemetryOverrides.trackFlutterPerformance = value
                else -> isValid = false
            }
        } else {
            isValid = false
        }

        if (!isValid) {
            Datadog._internal._telemetry.debug(
                String.format(MESSAGE_BAD_TELEMETRY_CONFIG, option, value)
            )
        }
    }

    fun mapTelemetryConfiguration(event: TelemetryConfigurationEvent): TelemetryConfigurationEvent {
        event.telemetry.configuration.trackViewsManually = telemetryOverrides.trackViewsManually
        event.telemetry.configuration.trackInteractions = telemetryOverrides.trackInteractions
        event.telemetry.configuration.trackErrors = telemetryOverrides.trackErrors
        event.telemetry.configuration.trackNetworkRequests = telemetryOverrides.trackNetworkRequests
        event.telemetry.configuration.trackNativeViews = telemetryOverrides.trackNativeViews
        event.telemetry.configuration.trackCrossPlatformLongTasks =
            telemetryOverrides.trackCrossPlatformLongTasks
        event.telemetry.configuration.trackFlutterPerformance =
            telemetryOverrides.trackFlutterPerformance

        return event
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

    internal fun stop() {
        simpleInvokeOn("stop", Datadog)

        val rumRegisteredField = GlobalRum::class.java.getDeclaredField("isRegistered")
        rumRegisteredField.isAccessible = true
        val isRegistered: AtomicBoolean = rumRegisteredField.get(null) as AtomicBoolean
        isRegistered.set(false)
    }

    fun attachEventMappers(config: DatadogFlutterConfiguration, configBuilder: Configuration.Builder) {
        if (config.attachLogMapper) {
            configBuilder.setLogEventMapper(
                object : EventMapper<LogEvent> {
                    override fun map(event: LogEvent): LogEvent? {
                        return mapLogEvent(event)
                    }
                }
            )
        }

        config.rumConfiguration?.let {
            if (it.attachViewEventMapper) {
                configBuilder.setRumViewEventMapper(
                    object : ViewEventMapper {
                        override fun map(event: ViewEvent): ViewEvent {
                            return rumPlugin.mapViewEvent(event)
                        }
                    }
                )
            }
            if (it.attachActionEventMapper) {
                configBuilder.setRumActionEventMapper(
                    object : EventMapper<ActionEvent> {
                        override fun map(event: ActionEvent): ActionEvent? {
                            return rumPlugin.mapActionEvent(event)
                        }
                    }
                )
            }
            if(it.attachResourceEventMapper) {
                configBuilder.setRumResourceEventMapper(
                    object: EventMapper<ResourceEvent> {
                        override fun map(event: ResourceEvent): ResourceEvent? {
                            return rumPlugin.mapResourceEvent(event)
                        }
                    }
                )
            }
        }
    }

    @Suppress("TooGenericExceptionCaught")
    internal fun mapLogEvent(event: LogEvent): LogEvent? {
        val jsonEvent = event.toJson().asMap()
        var modifiedJson: Map<String, Any?>? = null

        val latch = CountDownLatch(1)

        val handler = Handler(Looper.getMainLooper())
        handler.post {
            try {
                channel.invokeMethod(
                    "mapLogEvent",
                    mapOf(
                        "event" to jsonEvent
                    ),
                    object : Result {
                        override fun success(result: Any?) {
                            modifiedJson = result as? Map<String, Any?>
                            latch.countDown()
                        }

                        override fun error(
                            errorCode: String,
                            errorMessage: String?,
                            errorDetails: Any?
                        ) {
                            // No telemetry needed, this is likely an issue in user code
                            latch.countDown()
                        }

                        override fun notImplemented() {
                            Datadog._internal._telemetry.error(
                                "mapLogEvent returned notImplemented."
                            )
                            latch.countDown()
                        }
                    }
                )
            } catch (e: Exception) {
                Datadog._internal._telemetry.error("Attempting call mapLogEvent failed.", e)
                latch.countDown()
            }
        }

        try {
            // Stalls until the method channel finishes
            if (!latch.await(1, TimeUnit.SECONDS)) {
                Datadog._internal._telemetry.debug("logMapper timed out")
                return event
            }

            return modifiedJson?.let {
                if (!it.containsKey("_dd.mapper_error")) {
                    val modifiedEvent = LogEvent.fromJsonObject(modifiedJson!!.toJsonObject())

                    event.status = modifiedEvent.status
                    event.message = modifiedEvent.message
                    event.ddtags = modifiedEvent.ddtags
                    event.logger.name = modifiedEvent.logger.name

                    event.additionalProperties.clear()
                    event.additionalProperties.putAll(modifiedEvent.additionalProperties)
                }
                event
            }
        } catch (e: Exception) {
            Datadog._internal._telemetry.error(
                "Attempt to deserialize mapped log event failed, or latch await was interrupted." +
                    " Returning unmodified event.",
                e
            )
            return event
        }
    }

    private fun invokePrivateShutdown(result: Result) {
        executor.submit {
            simpleInvokeOn("flushAndShutdownExecutors", Datadog)
            stop()
        }.get()

        result.success(null)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)

        logsPlugin.detachFromEngine()
        rumPlugin.detachFromEngine()
    }
}

internal const val DATADOG_FLUTTER_TAG = "DatadogFlutter"

internal const val MESSAGE_INVALID_REINITIALIZATION =
    "🔥 Reinitialziing the DatadogSDK with different options, even after a hot restart, is not" +
        " supported. Cold restart your application to change your current configuration."

internal const val MESSAGE_NO_EXISTING_INSTANCE =
    "🔥 attachToExisting was called, but no existing instance of the Datadog SDK exists." +
        " Make sure to initialize the Native Datadog SDK before calling attachToExisting."

internal const val MESSAGE_BAD_TELEMETRY_CONFIG =
    "Attempting to set telemetry configuration option '%s' to '%s', which is invalid."
