package com.datadoghq.flutter

import android.os.Handler
import android.os.Looper
import com.datadog.android.Datadog
import com.datadog.android.log.LogsConfiguration
import com.datadog.android.log.model.LogEvent
import io.flutter.plugin.common.MethodChannel
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * This is a helper class that that simplifies event mapping / scrubbing for Log events.
 *
 * Since it is possible for Flutter engines to shut down and be recreated, it is possible that the
 * object used as the event mapper to be lost. This class is used as a static instance that will
 * perform mapping and call the Flutter mapping methods using the last provided MethodChannel.
 */
internal class DatadogLogEventMapper {
    private val channels: MutableSet<MethodChannel> = Collections.newSetFromMap(ConcurrentHashMap())

    fun addChannel(channel: MethodChannel) {
        channels.add(channel)
    }

    fun removeChannel(channel: MethodChannel) {
        channels.remove(channel)
    }

    fun attachMapper(config: LogsConfiguration.Builder): LogsConfiguration.Builder {
        config.setEventMapper { event -> mapLogEvent(event) }

        return config
    }

    @Suppress("TooGenericExceptionCaught")
    internal fun mapLogEvent(event: LogEvent): LogEvent? {
        val jsonEvent = event.toJson().asFlutterMap()
        var modifiedJson: Map<String, Any?>? = null

        val latch = CountDownLatch(1)

        val handler = Handler(Looper.getMainLooper())
        val channel = channels.firstOrNull() ?: return event

        handler.post {
            try {
                channel.invokeMethod(
                    "mapLogEvent",
                    mapOf(
                        "event" to jsonEvent
                    ),
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            @Suppress("UNCHECKED_CAST")
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
                            Datadog._internalProxy()._telemetry.error(
                                "mapLogEvent returned notImplemented."
                            )
                            latch.countDown()
                        }
                    }
                )
            } catch (e: Exception) {
                Datadog._internalProxy()._telemetry.error("Attempting call mapLogEvent failed.", e)
                latch.countDown()
            }
        }

        try {
            // Stalls until the method channel finishes
            if (!latch.await(1, TimeUnit.SECONDS)) {
                Datadog._internalProxy()._telemetry.debug("logMapper timed out")
                return event
            }

            return modifiedJson?.let {
                if (!it.containsKey("_dd.mapper_error")) {
                    val modifiedEvent = LogEvent.fromJsonObject(modifiedJson!!.toJsonObject())

                    event.status = modifiedEvent.status
                    event.message = modifiedEvent.message
                    event.ddtags = modifiedEvent.ddtags
                    event.logger.name = modifiedEvent.logger.name
                    event.error?.fingerprint = modifiedEvent.error?.fingerprint

                    event.additionalProperties.clear()
                    event.additionalProperties.putAll(modifiedEvent.additionalProperties)
                }
                event
            }
        } catch (e: Exception) {
            Datadog._internalProxy()._telemetry.error(
                "Attempt to deserialize mapped log event failed, or latch await was interrupted." +
                    " Returning unmodified event.",
                e
            )
            return event
        }
    }
}
