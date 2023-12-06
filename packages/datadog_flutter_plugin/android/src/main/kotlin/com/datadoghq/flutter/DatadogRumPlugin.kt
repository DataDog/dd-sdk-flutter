/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.datadog.android.Datadog
import com.datadog.android.api.SdkCore
import com.datadog.android.core.configuration.BatchSize
import com.datadog.android.core.configuration.UploadFrequency
import com.datadog.android.event.EventMapper
import com.datadog.android.rum.GlobalRumMonitor
import com.datadog.android.rum.Rum
import com.datadog.android.rum.RumActionType
import com.datadog.android.rum.RumAttributes
import com.datadog.android.rum.RumConfiguration
import com.datadog.android.rum.RumErrorSource
import com.datadog.android.rum.RumMonitor
import com.datadog.android.rum.RumPerformanceMetric
import com.datadog.android.rum.RumResourceKind
import com.datadog.android.rum._RumInternalProxy
import com.datadog.android.rum.configuration.VitalsUpdateFrequency
import com.datadog.android.rum.event.ViewEventMapper
import com.datadog.android.rum.model.ActionEvent
import com.datadog.android.rum.model.ErrorEvent
import com.datadog.android.rum.model.LongTaskEvent
import com.datadog.android.rum.model.ResourceEvent
import com.datadog.android.rum.model.ViewEvent
import com.datadog.android.rum.tracking.ViewTrackingStrategy
import com.datadog.android.telemetry.model.TelemetryConfigurationEvent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import java.lang.ClassCastException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.system.measureNanoTime

@Suppress("StringLiteralDuplication")
class DatadogRumPlugin internal constructor(
    rumInstance: RumMonitor? = null
) : MethodChannel.MethodCallHandler {
    companion object RumParameterNames {
        const val PARAM_AT = "at"
        const val PARAM_DURATION = "duration"
        const val PARAM_KEY = "key"
        const val PARAM_VALUE = "value"
        const val PARAM_NAME = "name"
        const val PARAM_ATTRIBUTES = "attributes"
        const val PARAM_URL = "url"
        const val PARAM_HTTP_METHOD = "httpMethod"
        const val PARAM_KIND = "kind"
        const val PARAM_STATUS_CODE = "statusCode"
        const val PARAM_SIZE = "size"
        const val PARAM_MESSAGE = "message"
        const val PARAM_SOURCE = "source"
        const val PARAM_STACK_TRACE = "stackTrace"
        const val PARAM_ERROR_TYPE = "errorType"
        const val PARAM_TYPE = "type"
        const val PARAM_BUILD_TIMES = "buildTimes"
        const val PARAM_RASTER_TIMES = "rasterTimes"

        // See DatadogSdkPlugin's description of this same member
        private var previousConfiguration: Map<String, Any?>? = null

        val instance: DatadogRumPlugin by lazy {
            DatadogRumPlugin()
        }

        // For testing purposes only
        internal fun resetConfig() {
            previousConfiguration = null
        }
    }

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    var rum: RumMonitor? = rumInstance
        private set

    val mapperPerf = PerformanceTracker()
    val mapperPerfMainThread = PerformanceTracker()
    var mapperTimeouts = 0

    // Might need a better way to deal with this. There's weird shared responsibility for
    // telemetry between the core and RUM.
    var telemetryOverrides: DatadogSdkPlugin.ConfigurationTelemetryOverrides? = null

    fun attachToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter.rum")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding
    }

    fun detachFromEngine() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method != "enable" && rum == null) {
            result.invalidOperation(
                "Attempting to call ${call.method} on RUM when it has not been enabled"
            )
            return
        }

        try {
            when (call.method) {
                "enable" -> enable(call, result)
                "startView" -> startView(call, result)
                "stopView" -> stopView(call, result)
                "addTiming" -> addTiming(call, result)
                "startResource" -> startResource(call, result)
                "stopResource" -> stopResource(call, result)
                "stopResourceWithError" -> stopResourceWithError(call, result)
                "addError" -> addError(call, result)
                "addAction" -> addAction(call, result)
                "startAction" -> startAction(call, result)
                "stopAction" -> stopAction(call, result)
                "addAttribute" -> addAttribute(call, result)
                "removeAttribute" -> removeAttribute(call, result)
                "reportLongTask" -> reportLongTask(call, result)
                "updatePerformanceMetrics" -> updatePerformanceMetrics(call, result)
                "addFeatureFlagEvaluation" -> addFeatureFlagEvaluation(call, result)
                "stopSession" -> stopSession(call, result)
                else -> {
                    result.notImplemented()
                }
            }
        } catch (e: ClassCastException) {
            result.error(
                DatadogSdkPlugin.CONTRACT_VIOLATION,
                e.toString(),
                mapOf(
                    "methodName" to call.method
                )
            )
        }
    }

    fun enable(call: MethodCall, result: Result) {
        val encodedConfig = call.argument<Map<String, Any?>>("configuration")
        val applicationId = encodedConfig?.get("applicationId") as? String
        if (previousConfiguration == null) {
            if (encodedConfig != null && applicationId != null) {
                var configBuilder = RumConfiguration.Builder(applicationId)
                    .withEncoded(encodedConfig)

                configBuilder = _RumInternalProxy.setTelemetryConfigurationEventMapper(
                    configBuilder,
                    object : EventMapper<TelemetryConfigurationEvent> {
                        override fun map(
                            event: TelemetryConfigurationEvent
                        ): TelemetryConfigurationEvent {
                            return mapTelemetryConfiguration(event)
                        }
                    }
                )
                // Common initialization
                configBuilder = configBuilder
                    .disableUserInteractionTracking()
                    .useViewTrackingStrategy(NoOpViewTrackingStrategy)

                // Mapper initialization
                configBuilder = attachEventMappers(encodedConfig, configBuilder)

                Rum.enable(configBuilder.build())
                rum = GlobalRumMonitor.get()
                previousConfiguration = encodedConfig
            }
        } else if (previousConfiguration != encodedConfig) {
            // Maybe use DevLogger instead?
            Log.e(DATADOG_FLUTTER_TAG, MESSAGE_INVALID_RUM_REINITIALIZATION)
        }
    }

    fun attachToExistingSdk(monitor: RumMonitor) {
        rum = monitor
    }

    private fun mapTelemetryConfiguration(
        event: TelemetryConfigurationEvent
    ): TelemetryConfigurationEvent {
        telemetryOverrides?.let {
            event.telemetry.configuration.trackViewsManually = it.trackViewsManually
            event.telemetry.configuration.trackInteractions = it.trackInteractions
            event.telemetry.configuration.trackErrors = it.trackErrors
            event.telemetry.configuration.trackNetworkRequests = it.trackNetworkRequests
            event.telemetry.configuration.trackNativeViews = it.trackNativeViews
            event.telemetry.configuration.trackCrossPlatformLongTasks =
                it.trackCrossPlatformLongTasks
            event.telemetry.configuration.trackFlutterPerformance =
                it.trackFlutterPerformance
            event.telemetry.configuration.dartVersion = it.dartVersion
        }

        return event
    }

    private fun attachEventMappers(
        config: Map<String, Any?>,
        configBuilder: RumConfiguration.Builder
    ): RumConfiguration.Builder {
        fun optionIsSet(key: String): Boolean {
            return config[key] as? Boolean ?: false
        }

        if (optionIsSet("attachViewEventMapper")) {
            configBuilder.setViewEventMapper(
                object : ViewEventMapper {
                    override fun map(event: ViewEvent): ViewEvent {
                        return mapViewEvent(event)
                    }
                }
            )
        }
        if (optionIsSet("attachActionEventMapper")) {
            configBuilder.setActionEventMapper(
                object : EventMapper<ActionEvent> {
                    override fun map(event: ActionEvent): ActionEvent? {
                        return mapActionEvent(event)
                    }
                }
            )
        }
        if (optionIsSet("attachResourceEventMapper")) {
            configBuilder.setResourceEventMapper(
                object : EventMapper<ResourceEvent> {
                    override fun map(event: ResourceEvent): ResourceEvent? {
                        return mapResourceEvent(event)
                    }
                }
            )
        }
        if (optionIsSet("attachErrorEventMapper")) {
            configBuilder.setErrorEventMapper(
                object : EventMapper<ErrorEvent> {
                    override fun map(event: ErrorEvent): ErrorEvent? {
                        return mapErrorEvent(event)
                    }
                }
            )
        }
        if (optionIsSet("attachLongTaskEventMapper")) {
            configBuilder.setLongTaskEventMapper(
                object : EventMapper<LongTaskEvent> {
                    override fun map(event: LongTaskEvent): LongTaskEvent? {
                        return mapLongTaskEvent(event)
                    }
                }
            )
        }

        return configBuilder
    }

    private fun startView(call: MethodCall, result: Result) {
        val key = call.argument<String>(PARAM_KEY)
        val name = call.argument<String>(PARAM_NAME)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        if (key != null && name != null && attributes != null) {
            rum?.startView(key, name, attributes)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun stopView(call: MethodCall, result: Result) {
        val key = call.argument<String>(PARAM_KEY)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        if (key != null && attributes != null) {
            rum?.stopView(key, attributes)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun addTiming(call: MethodCall, result: Result) {
        val name = call.argument<String>(PARAM_NAME)
        if (name != null) {
            rum?.addTiming(name)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun startResource(call: MethodCall, result: Result) {
        val key = call.argument<String>(PARAM_KEY)
        val url = call.argument<String>(PARAM_URL)
        val method = call.argument<String>(PARAM_HTTP_METHOD)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)

        @Suppress("ComplexCondition")
        if (key != null && url != null && method != null && attributes != null) {
            val httpMethod = parseRumHttpMethod(method)
            rum?.startResource(key, httpMethod, url, attributes)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun stopResource(call: MethodCall, result: Result) {
        val key = call.argument<String>(PARAM_KEY)
        val kindString = call.argument<String>(PARAM_KIND)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        val statusCode = call.argument<Number>(PARAM_STATUS_CODE)
        val size = call.argument<Number>(PARAM_SIZE)
        if (key != null && kindString != null && attributes != null) {
            val kind = parseRumResourceKind(kindString)
            rum?.stopResource(
                key,
                statusCode?.toInt(),
                size?.toLong(),
                kind,
                attributes
            )
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    @Suppress("ComplexCondition")
    private fun stopResourceWithError(call: MethodCall, result: Result) {
        val key = call.argument<String>(PARAM_KEY)
        val message = call.argument<String>(PARAM_MESSAGE)
        val errorType = call.argument<String>(PARAM_TYPE)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        if (key != null && message != null && errorType != null && attributes != null) {
            rum?.stopResourceWithError(
                key,
                null,
                message,
                RumErrorSource.NETWORK,
                "",
                errorType,
                attributes
            )
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun addError(call: MethodCall, result: Result) {
        val message = call.argument<String>(PARAM_MESSAGE)
        val sourceString = call.argument<String>(PARAM_SOURCE)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        val stackTrace = call.argument<String>(PARAM_STACK_TRACE)
        val errorType = call.argument<String>(PARAM_ERROR_TYPE)
        if (message != null && sourceString != null && attributes != null) {
            var fullAttributes = attributes
            if (errorType != null) {
                fullAttributes = attributes + Pair(
                    RumAttributes.INTERNAL_ERROR_TYPE,
                    errorType
                )
            }
            val source = parseRumErrorSource(sourceString)
            rum?.addErrorWithStacktrace(message, source, stackTrace, fullAttributes)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun addAction(call: MethodCall, result: Result) {
        val typeString = call.argument<String>(PARAM_TYPE)
        val name = call.argument<String>(PARAM_NAME)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        if (typeString != null && name != null && attributes != null) {
            val actionType = parseRumActionType(typeString)
            rum?.addAction(actionType, name, attributes)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun startAction(call: MethodCall, result: Result) {
        val typeString = call.argument<String>(PARAM_TYPE)
        val name = call.argument<String>(PARAM_NAME)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        if (typeString != null && name != null && attributes != null) {
            val actionType = parseRumActionType(typeString)
            rum?.startAction(actionType, name, attributes)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun stopAction(call: MethodCall, result: Result) {
        val typeString = call.argument<String>(PARAM_TYPE)
        val name = call.argument<String>(PARAM_NAME)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        if (typeString != null && name != null && attributes != null) {
            val actionType = parseRumActionType(typeString)
            rum?.stopAction(actionType, name, attributes)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun addAttribute(call: MethodCall, result: Result) {
        val key = call.argument<String>(PARAM_KEY)
        val value = call.argument<Any>(PARAM_VALUE)
        if (key != null && value != null) {
            rum?.addAttribute(key, value)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun removeAttribute(call: MethodCall, result: Result) {
        val key = call.argument<String>(PARAM_KEY)
        if (key != null) {
            rum?.removeAttribute(key)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun reportLongTask(call: MethodCall, result: Result) {
        val at = call.argument<Long>(PARAM_AT)
        val duration = call.argument<Int>(PARAM_DURATION)
        if (at != null && duration != null) {
            // Duration is in ms, convert to ns
            val durationNs = TimeUnit.MILLISECONDS.toNanos(duration.toLong())
            rum?._getInternal()?.addLongTask(durationNs, "")
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun updatePerformanceMetrics(call: MethodCall, result: Result) {
        val buildTimes = call.argument<List<Double>>(PARAM_BUILD_TIMES)
        val rasterTimes = call.argument<List<Double>>(PARAM_RASTER_TIMES)
        if (buildTimes != null && rasterTimes != null) {
            buildTimes.forEach {
                rum?._getInternal()?.updatePerformanceMetric(
                    RumPerformanceMetric.FLUTTER_BUILD_TIME,
                    it
                )
            }
            rasterTimes.forEach {
                rum?._getInternal()?.updatePerformanceMetric(
                    RumPerformanceMetric.FLUTTER_RASTER_TIME,
                    it
                )
            }
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun addFeatureFlagEvaluation(call: MethodCall, result: Result) {
        val name = call.argument<String>(PARAM_NAME)
        val value = call.argument<Any>(PARAM_VALUE)
        if (name != null && value != null) {
            rum?.addFeatureFlagEvaluation(name, value)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun stopSession(call: MethodCall, result: Result) {
        rum?.stopSession()
        result.success(null)
    }

    @Suppress("TooGenericExceptionCaught")
    internal fun <T> callEventMapper(
        mapperName: String,
        event: T,
        encodedEvent: Map<String, Any?>,
        completion: (Map<String, Any?>?, T) -> T?
    ): T? {
        var modifiedJson: Map<String, Any?>? = encodedEvent
        val latch = CountDownLatch(1)

        val handler = Handler(Looper.getMainLooper())
        handler.post {
            val perf = measureNanoTime {
                try {
                    channel.invokeMethod(
                        mapperName,
                        mapOf(
                            "event" to encodedEvent
                        ),
                        object : Result {
                            @Suppress("UNCHECKED_CAST")
                            override fun success(result: Any?) {
                                modifiedJson = (result as? Map<String, Any?>)
                                latch.countDown()
                            }

                            override fun error(
                                errorCode: String,
                                errorMessage: String?,
                                errorDetails: Any?
                            ) {
                                latch.countDown()
                            }

                            override fun notImplemented() {
                                Datadog._internalProxy()._telemetry.error(
                                    "$mapperName returned notImplemented."
                                )
                                latch.countDown()
                            }
                        }
                    )
                } catch (e: Exception) {
                    Datadog._internalProxy()._telemetry.error(
                        "Attempting call $mapperName failed.",
                        e
                    )
                    latch.countDown()
                }
            }
            mapperPerfMainThread.addSample(perf)
        }

        try {
            // Stalls until the method channel finishes
            if (!latch.await(1, TimeUnit.SECONDS)) {
                Datadog._internalProxy()._telemetry.debug("$mapperName timed out")
                return event
            }

            if (modifiedJson?.containsKey("_dd.mapper_error") == true) {
                return event
            }

            return completion(modifiedJson, event)
        } catch (e: InterruptedException) {
            Datadog._internalProxy()._telemetry.debug(
                "Latch await was interrupted. Returning unmodified event."
            )
        } catch (e: Exception) {
            Datadog._internalProxy()._telemetry.error(
                "Unknown exception attempting to deserialize mapped log event." +
                    " Returning unmodified event.",
                e
            )
        }

        return event
    }

    @Suppress("UNCHECKED_CAST")
    internal fun mapViewEvent(event: ViewEvent): ViewEvent {
        var result: ViewEvent
        val perf = measureNanoTime {
            var jsonEvent = event.toJson().asFlutterMap()
            jsonEvent = normalizeExtraUserInfo(jsonEvent)

            result = callEventMapper("mapViewEvent", event, jsonEvent) { encodedResult, event ->
                (encodedResult?.get("view") as? Map<String, Any?>)?.let {
                    event.view.name = it["name"] as? String
                    event.view.referrer = it["referrer"] as? String
                    event.view.url = it["url"] as String
                }

                event
            } ?: event
        }
        mapperPerf.addSample(perf)

        return result
    }

    @Suppress("UNCHECKED_CAST")
    internal fun mapActionEvent(event: ActionEvent): ActionEvent? {
        val result: ActionEvent?
        val perf = measureNanoTime {
            var jsonEvent = event.toJson().asFlutterMap()
            jsonEvent = normalizeExtraUserInfo(jsonEvent)

            result = callEventMapper("mapActionEvent", event, jsonEvent) { encodedResult, event ->
                if (encodedResult == null) {
                    null
                } else {
                    (encodedResult["action"] as? Map<String, Any?>)?.let {
                        val encodedTarget = it["target"] as? Map<String, Any?>
                        if (encodedTarget != null) {
                            event.action.target?.name = encodedTarget["name"] as String
                        }
                    }

                    (encodedResult["view"] as? Map<String, Any?>)?.let {
                        event.view.name = it["name"] as? String
                        event.view.referrer = it["referrer"] as? String
                        event.view.url = it["url"] as String
                    }

                    event
                }
            }
        }
        mapperPerf.addSample(perf)

        return result
    }

    @Suppress("UNCHECKED_CAST")
    internal fun mapResourceEvent(event: ResourceEvent): ResourceEvent? {
        var result: ResourceEvent?
        val perf = measureNanoTime {
            var jsonEvent = event.toJson().asFlutterMap()
            jsonEvent = normalizeExtraUserInfo(jsonEvent)

            result = callEventMapper("mapResourceEvent", event, jsonEvent) { encodedResult, event ->
                if (encodedResult == null) {
                    null
                } else {
                    (encodedResult["resource"] as? Map<String, Any?>)?.let {
                        event.resource.url = it["url"] as String
                    }

                    (encodedResult["view"] as? Map<String, Any?>)?.let {
                        event.view.name = it["name"] as? String
                        event.view.referrer = it["referrer"] as? String
                        event.view.url = it["url"] as String
                    }

                    event
                }
            }
        }
        mapperPerf.addSample(perf)

        return result
    }

    @Suppress("ComplexMethod", "UNCHECKED_CAST")
    internal fun mapErrorEvent(event: ErrorEvent): ErrorEvent? {
        var result: ErrorEvent?
        val perf = measureNanoTime {
            var jsonEvent = event.toJson().asFlutterMap()
            jsonEvent = normalizeExtraUserInfo(jsonEvent)

            result = callEventMapper("mapErrorEvent", event, jsonEvent) { encodedResult, event ->
                if (encodedResult == null) {
                    null
                } else {
                    (encodedResult["error"] as? Map<String, Any?>)?.let { encodedError ->
                        val encodedCauses = encodedError["causes"] as? List<Map<String, Any?>>
                        if (encodedCauses != null) {
                            event.error.causes?.let { causes ->
                                if (causes.count() == encodedCauses.count()) {
                                    causes.forEachIndexed { i, cause ->
                                        cause.message = encodedCauses[i]["message"] as? String ?: ""
                                        cause.stack = encodedCauses[i]["stack"] as? String
                                    }
                                }
                            }
                        } else {
                            event.error.causes = null
                        }

                        val encodedResource = encodedError["resource"] as? Map<String, Any?>
                        if (encodedResource != null) {
                            event.error.resource?.url = encodedResource["url"] as? String ?: ""
                        }

                        event.error.stack = encodedError["stack"] as? String
                    }

                    (encodedResult["view"] as? Map<String, Any?>)?.let {
                        event.view.name = it["name"] as? String
                        event.view.referrer = it["referrer"] as? String
                        event.view.url = it["url"] as String
                    }

                    event
                }
            }
        }
        mapperPerf.addSample(perf)

        return result
    }

    @Suppress("UNCHECKED_CAST")
    internal fun mapLongTaskEvent(event: LongTaskEvent): LongTaskEvent? {
        var result: LongTaskEvent?
        val perf = measureNanoTime {
            var jsonEvent = event.toJson().asFlutterMap()
            jsonEvent = normalizeExtraUserInfo(jsonEvent)

            result = callEventMapper("mapLongTaskEvent", event, jsonEvent) { encodedResult, event ->
                if (encodedResult == null) {
                    null
                } else {
                    (encodedResult["view"] as? Map<String, Any?>)?.let {
                        event.view.name = it["name"] as? String
                        event.view.referrer = it["referrer"] as? String
                        event.view.url = it["url"] as String
                    }

                    event
                }
            }
        }
        mapperPerf.addSample(perf)

        return result
    }

    @Suppress("UNCHECKED_CAST")
    private fun normalizeExtraUserInfo(encodedEvent: Map<String, Any?>): Map<String, Any?> {
        val reservedKeys = setOf("email", "id", "name")
        // Pull out user information
        val mutableEvent = encodedEvent.toMutableMap()
        (mutableEvent["usr"] as? Map<String, Any?>)?.let { usr ->
            val mutableUsr = usr.toMutableMap()
            val extraUserInfo = mutableMapOf<String, Any?>()
            usr.filter { !reservedKeys.contains(it.key) }.forEach {
                extraUserInfo[it.key] = it.value
                mutableUsr.remove(it.key)
            }
            mutableUsr["usr_info"] = extraUserInfo
            mutableEvent["usr"] = mutableUsr
        }

        return mutableEvent
    }
}

object NoOpViewTrackingStrategy : ViewTrackingStrategy {
    override fun register(sdkCore: SdkCore, context: Context) {
        // Nop
    }

    override fun unregister(context: Context?) {
        // Nop
    }
}

fun RumConfiguration.Builder.withEncoded(encoded: Map<String, Any?>): RumConfiguration.Builder {
    var builder = this

    (encoded["sessionSampleRate"] as? Number)?.let {
        builder = builder.setSessionSampleRate(it.toFloat())
    }
    (encoded["longTaskThreshold"] as? Number)?.let {
        builder = builder.trackLongTasks((it.toFloat() * 1000).toLong())
    }
    (encoded["trackFrustrations"] as? Boolean)?.let {
        builder = builder.trackFrustrations(it)
    }
    (encoded["customEndpoint"] as? String)?.let {
        builder = builder.useCustomEndpoint(it)
    }
    (encoded["vitalsUpdateFrequency"] as? String)?.let {
        val frequency = parseVitalsFrequency(it)
        builder = builder.setVitalsUpdateFrequency(frequency)
    }
    (encoded["telemetrySampleRate"] as? Number)?.let {
        builder = builder.setTelemetrySampleRate(it.toFloat())
    }
    (encoded["additionalConfig"] as? Map<String, Any>)?.let {
        builder = _RumInternalProxy.setAdditionalConfiguration(builder, it)
    }

    return builder
}

fun parseRumHttpMethod(value: String): String {
    return when (value) {
        "RumHttpMethod.get" -> "GET"
        "RumHttpMethod.post" -> "POST"
        "RumHttpMethod.head" -> "HEAD"
        "RumHttpMethod.put" -> "PUT"
        "RumHttpMethod.delete" -> "DELETE"
        "RumHttpMethod.patch" -> "PATCH"
        else -> "GET"
    }
}

fun parseRumResourceKind(value: String): RumResourceKind {
    return when (value) {
        "RumResourceType.document" -> RumResourceKind.DOCUMENT
        "RumResourceType.image" -> RumResourceKind.IMAGE
        "RumResourceType.xhr" -> RumResourceKind.XHR
        "RumResourceType.beacon" -> RumResourceKind.BEACON
        "RumResourceType.css" -> RumResourceKind.CSS
        "RumResourceType.fetch" -> RumResourceKind.FETCH
        "RumResourceType.font" -> RumResourceKind.FONT
        "RumResourceType.js" -> RumResourceKind.JS
        "RumResourceType.media" -> RumResourceKind.MEDIA
        "RumResourceType.native" -> RumResourceKind.NATIVE
        else -> RumResourceKind.OTHER
    }
}

fun parseRumErrorSource(value: String): RumErrorSource {
    return when (value) {
        "RumErrorSource.source" -> RumErrorSource.SOURCE
        "RumErrorSource.network" -> RumErrorSource.NETWORK
        "RumErrorSource.webview" -> RumErrorSource.WEBVIEW
        "RumErrorSource.console" -> RumErrorSource.CONSOLE
        "RumErrorSource.custom" -> RumErrorSource.SOURCE
        else -> RumErrorSource.SOURCE
    }
}

fun parseRumActionType(value: String): RumActionType {
    return when (value) {
        "RumActionType.tap" -> RumActionType.TAP
        "RumActionType.scroll" -> RumActionType.SCROLL
        "RumActionType.swipe" -> RumActionType.SWIPE
        "RumActionType.custom" -> RumActionType.CUSTOM
        else -> RumActionType.CUSTOM
    }
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

internal fun parseVitalsFrequency(vitalsFrequency: String): VitalsUpdateFrequency {
    return when (vitalsFrequency) {
        "VitalsFrequency.frequent" -> VitalsUpdateFrequency.FREQUENT
        "VitalsFrequency.average" -> VitalsUpdateFrequency.AVERAGE
        "VitalsFrequency.rare" -> VitalsUpdateFrequency.RARE
        "VitalsFrequency.never" -> VitalsUpdateFrequency.NEVER
        else -> VitalsUpdateFrequency.AVERAGE
    }
}

internal const val MESSAGE_INVALID_RUM_REINITIALIZATION =
    "🔥 Re-enabling the Datadog RUM with different options is not supported, even after a" +
        " hot restart. Cold restart your application to change your current configuration."
