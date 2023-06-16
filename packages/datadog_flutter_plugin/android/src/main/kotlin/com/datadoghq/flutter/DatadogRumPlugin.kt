/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.os.Handler
import android.os.Looper
import com.datadog.android.Datadog
import com.datadog.android.rum.GlobalRum
import com.datadog.android.rum.RumActionType
import com.datadog.android.rum.RumAttributes
import com.datadog.android.rum.RumErrorSource
import com.datadog.android.rum.RumMonitor
import com.datadog.android.rum.RumPerformanceMetric
import com.datadog.android.rum.RumResourceKind
import com.datadog.android.rum.RumSessionListener
import com.datadog.android.rum.model.ActionEvent
import com.datadog.android.rum.model.ErrorEvent
import com.datadog.android.rum.model.LongTaskEvent
import com.datadog.android.rum.model.ResourceEvent
import com.datadog.android.rum.model.ViewEvent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import java.lang.ClassCastException
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.system.measureNanoTime

@Suppress("StringLiteralDuplication")
class DatadogRumPlugin(
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
    }

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    var rum: RumMonitor? = rumInstance
        private set

    val mapperPerf = PerformanceTracker()
    val mapperPerfMainThread = PerformanceTracker()
    var mapperTimeouts = 0

    fun attachToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter.rum")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding
    }

    fun detachFromEngine() {
        channel.setMethodCallHandler(null)
    }

    fun attachToExistingSdk() {
        rum = GlobalRum.get()
    }

    fun setup(
        configuration: DatadogFlutterConfiguration.RumConfiguration
    ) {
        rum = RumMonitor.Builder()
            .sampleRumSessions(configuration.sampleRate)
            .setSessionListener(object : RumSessionListener {
                override fun onSessionStarted(sessionId: String, isDiscarded: Boolean) {
                    sessionStarted(sessionId, isDiscarded)
                }
            })
            .build()
        GlobalRum.registerIfAbsent(rum!!)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        try {
            when (call.method) {
                "startView" -> startView(call, result)
                "stopView" -> stopView(call, result)
                "addTiming" -> addTiming(call, result)
                "startResourceLoading" -> startResourceLoading(call, result)
                "stopResourceLoading" -> stopResourceLoading(call, result)
                "stopResourceLoadingWithError" -> stopResourceLoadingWithError(call, result)
                "addError" -> addError(call, result)
                "addUserAction" -> addUserAction(call, result)
                "startUserAction" -> startUserAction(call, result)
                "stopUserAction" -> stopUserAction(call, result)
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
                DatadogSdkPlugin.CONTRACT_VIOLATION, e.toString(),
                mapOf(
                    "methodName" to call.method
                )
            )
        }
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

    private fun startResourceLoading(call: MethodCall, result: Result) {
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

    private fun stopResourceLoading(call: MethodCall, result: Result) {
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
    private fun stopResourceLoadingWithError(call: MethodCall, result: Result) {
        val key = call.argument<String>(PARAM_KEY)
        val message = call.argument<String>(PARAM_MESSAGE)
        val errorType = call.argument<String>(PARAM_TYPE)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        if (key != null && message != null && errorType != null && attributes != null) {
            rum?.stopResourceWithError(
                key, null, message, RumErrorSource.NETWORK,
                "", errorType, attributes
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

    private fun addUserAction(call: MethodCall, result: Result) {
        val typeString = call.argument<String>(PARAM_TYPE)
        val name = call.argument<String>(PARAM_NAME)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        if (typeString != null && name != null && attributes != null) {
            val actionType = parseRumActionType(typeString)
            rum?.addUserAction(actionType, name, attributes)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun startUserAction(call: MethodCall, result: Result) {
        val typeString = call.argument<String>(PARAM_TYPE)
        val name = call.argument<String>(PARAM_NAME)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        if (typeString != null && name != null && attributes != null) {
            val actionType = parseRumActionType(typeString)
            rum?.startUserAction(actionType, name, attributes)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun stopUserAction(call: MethodCall, result: Result) {
        val typeString = call.argument<String>(PARAM_TYPE)
        val name = call.argument<String>(PARAM_NAME)
        val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
        if (typeString != null && name != null && attributes != null) {
            val actionType = parseRumActionType(typeString)
            rum?.stopUserAction(actionType, name, attributes)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun addAttribute(call: MethodCall, result: Result) {
        val key = call.argument<String>(PARAM_KEY)
        val value = call.argument<Any>(PARAM_VALUE)
        if (key != null && value != null) {
            GlobalRum.addAttribute(key, value)
            result.success(null)
        } else {
            result.missingParameter(call.method)
        }
    }

    private fun removeAttribute(call: MethodCall, result: Result) {
        val key = call.argument<String>(PARAM_KEY)
        if (key != null) {
            GlobalRum.removeAttribute(key)
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

    private fun sessionStarted(sessionId: String, isDiscarded: Boolean) {
        val handler = Handler(Looper.getMainLooper())
        handler.post {
            channel.invokeMethod(
                "rumSessionStarted",
                mapOf(
                    "sessionId" to sessionId,
                    "sampled" to isDiscarded,
                )
            )
        }
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
                                Datadog._internal._telemetry.error(
                                    "$mapperName returned notImplemented."
                                )
                                latch.countDown()
                            }
                        }
                    )
                } catch (e: Exception) {
                    Datadog._internal._telemetry.error("Attempting call $mapperName failed.", e)
                    latch.countDown()
                }
            }
            mapperPerfMainThread.addSample(perf)
        }

        try {
            // Stalls until the method channel finishes
            if (!latch.await(1, TimeUnit.SECONDS)) {
                Datadog._internal._telemetry.debug("$mapperName timed out")
                return event
            }

            if (modifiedJson?.containsKey("_dd.mapper_error") == true) {
                return event
            }

            return completion(modifiedJson, event)
        } catch (e: InterruptedException) {
            Datadog._internal._telemetry.debug(
                "Latch await was interrupted. Returning unmodified event.",
            )
        } catch (e: Exception) {
            Datadog._internal._telemetry.error(
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
            var jsonEvent = event.toJson().asMap()
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
            var jsonEvent = event.toJson().asMap()
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
            var jsonEvent = event.toJson().asMap()
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
            var jsonEvent = event.toJson().asMap()
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
            var jsonEvent = event.toJson().asMap()
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
        "RumUserActionType.tap" -> RumActionType.TAP
        "RumUserActionType.scroll" -> RumActionType.SCROLL
        "RumUserActionType.swipe" -> RumActionType.SWIPE
        "RumUserActionType.custom" -> RumActionType.CUSTOM
        else -> RumActionType.CUSTOM
    }
}
