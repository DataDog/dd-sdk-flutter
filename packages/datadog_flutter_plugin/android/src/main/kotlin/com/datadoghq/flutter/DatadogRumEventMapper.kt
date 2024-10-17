package com.datadoghq.flutter

import android.os.Handler
import android.os.Looper
import com.datadog.android.Datadog
import com.datadog.android.rum.RumConfiguration
import com.datadog.android.rum.model.ActionEvent
import com.datadog.android.rum.model.ErrorEvent
import com.datadog.android.rum.model.LongTaskEvent
import com.datadog.android.rum.model.ResourceEvent
import com.datadog.android.rum.model.ViewEvent
import io.flutter.plugin.common.MethodChannel
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import kotlin.system.measureNanoTime

/**
 * This is a helper class that that simplifies event mapping / scrubbing for RUM events.
 *
 * Since it is possible for Flutter engines to shut down and be recreated, it is possible that the
 * object used as the event mapper to be lost. This class is used as a static instance that will
 * perform mapping and call the Flutter mapping methods using the last provided MethodChannel.
 */
@Suppress("StringLiteralDuplication")
internal class DatadogRumEventMapper {
    private val channels: MutableSet<MethodChannel> = Collections.newSetFromMap(ConcurrentHashMap())

    val mapperPerf = PerformanceTracker()
    val mapperPerfMainThread = PerformanceTracker()
    var mapperTimeouts = 0
    var lastKnownGoodChannel: MethodChannel? = null

    fun addChannel(channel: MethodChannel) {
        channels.add(channel)
        if (lastKnownGoodChannel == null) {
            lastKnownGoodChannel = channel
        }
    }

    fun removeChannel(channel: MethodChannel) {
        channels.remove(channel)
        if (channel == lastKnownGoodChannel) {
            lastKnownGoodChannel = channels.firstOrNull()
        }
    }

    fun attachMappers(
        config: Map<String, Any?>,
        configBuilder: RumConfiguration.Builder
    ): RumConfiguration.Builder {
        fun optionIsSet(key: String): Boolean {
            return config[key] as? Boolean ?: false
        }

        if (optionIsSet("attachViewEventMapper")) {
            configBuilder.setViewEventMapper { event -> mapViewEvent(event) }
        }
        if (optionIsSet("attachActionEventMapper")) {
            configBuilder.setActionEventMapper { event -> mapActionEvent(event) }
        }
        if (optionIsSet("attachResourceEventMapper")) {
            configBuilder.setResourceEventMapper { event -> mapResourceEvent(event) }
        }
        if (optionIsSet("attachErrorEventMapper")) {
            configBuilder.setErrorEventMapper { event -> mapErrorEvent(event) }
        }
        if (optionIsSet("attachLongTaskEventMapper")) {
            configBuilder.setLongTaskEventMapper { event -> mapLongTaskEvent(event) }
        }

        return configBuilder
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
                        event.error.fingerprint = encodedError["fingerprint"] as? String
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

    @Suppress("TooGenericExceptionCaught")
    private fun callWithChannel(
        channel: MethodChannel,
        mapperName: String,
        encodedEvent: Map<String, Any?>
    ): MapperCallResult<Map<String, Any?>?, String> {
        val latch = CountDownLatch(1)
        var modifiedJson: Map<String, Any?>? = encodedEvent
        var didFailNotImplemented = false
        val handler = Handler(Looper.getMainLooper())
        handler.post {
            try {
                channel.invokeMethod(
                    mapperName,
                    mapOf(
                        "event" to encodedEvent
                    ),
                    object : MethodChannel.Result {
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
                            didFailNotImplemented = true
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

        try {
            // Stalls until the method channel finishes
            if (!latch.await(5, TimeUnit.SECONDS)) {
                Datadog._internalProxy()._telemetry.debug("$mapperName timed out")
                return MapperCallResult.Error("Timeout")
            }

            if (modifiedJson?.containsKey("_dd.mapper_error") == true) {
                return MapperCallResult.Error("Error in Mapper")
            }

            if (didFailNotImplemented) {
                return MapperCallResult.ReturnedNotImplemented("Not Implemented")
            }

            return MapperCallResult.Ok(modifiedJson)
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

        return MapperCallResult.Error("unknown")
    }

    internal fun <T> callEventMapper(
        mapperName: String,
        event: T,
        encodedEvent: Map<String, Any?>,
        completion: (Map<String, Any?>?, T) -> T?
    ): T? {
        var currentChannel = lastKnownGoodChannel
        // No last known good channel?
        if (currentChannel == null) {
            Datadog._internalProxy()._telemetry.debug(
                "No last known good channel. Returning unmodified event."
            )
            return event
        }

        while (currentChannel != null) {
            val result = callWithChannel(currentChannel, mapperName, encodedEvent)
            when (result) {
                is MapperCallResult.Ok -> {
                    return completion(result.value, event)
                }

                is MapperCallResult.Error -> {
                    // These errors are fine and occasionally expected, don't try a different channel
                    return event
                }

                is MapperCallResult.ReturnedNotImplemented -> {
                    Datadog._internalProxy()._telemetry.debug(
                        "$mapperName returned notImplemented. Trying next channel."
                    )
                    channels.remove(currentChannel)
                    lastKnownGoodChannel = channels.firstOrNull()
                    currentChannel = lastKnownGoodChannel
                }
            }
        }

        Datadog._internalProxy()._telemetry.error(
            "Never found good channel for mapping. Returning unmodified event."
        )

        return event
    }

    sealed class MapperCallResult<out S, out F> {
        data class Ok<out S>(val value: S) : MapperCallResult<S, Nothing>()
        data class Error<out F>(val reason: F) : MapperCallResult<Nothing, F>()
        data class ReturnedNotImplemented<out F>(val reason: F) : MapperCallResult<Nothing, F>()
    }
}
