package com.datadoghq.flutter

import com.datadog.android.log.LogsConfiguration
import com.datadog.android.log.model.LogEvent
import com.google.gson.JsonParser

/**
 * This is a helper class that that simplifies event mapping / scrubbing for Log events.
 *
 * Since it is possible for Flutter engines to shut down and be recreated, it is possible that the
 * object used as the event mapper to be lost. This class is used as a static instance that will
 * perform mapping and call the Flutter mapping methods using the last provided MethodChannel.
 */
class DatadogLogEventMapper {
    // Even though mappers use "jnigen" and could bind / modify the Log events
    // directly, this would require users use separate iOS / Android callbacks. by sending
    // encoded versions, we can hide some platform specifics.
    interface EventMapper {
        fun mapLogEvent(encodedEvent: String): String?
    }

    var eventMapper: EventMapper? = null

    fun attachMapper(config: LogsConfiguration.Builder): LogsConfiguration.Builder {
        config.setEventMapper { event -> mapLogEvent(event) }

        return config
    }

    @Suppress("TooGenericExceptionCaught")
    internal fun mapLogEvent(event: LogEvent): LogEvent? {
        var result: LogEvent? = event

        eventMapper?.let { mapper ->
            val encodedEvent = event.toJson().toString()

            val encodedResult = mapper.mapLogEvent(encodedEvent)
            if (encodedResult != null) {
                val jsonObject = JsonParser.parseString(encodedResult).asJsonObject
                val modifiedEvent = LogEvent.fromJsonObject(jsonObject)

                event.status = modifiedEvent.status
                event.message = modifiedEvent.message
                event.ddtags = modifiedEvent.ddtags
                event.logger.name = modifiedEvent.logger.name
                event.error?.fingerprint = modifiedEvent.error?.fingerprint

                event.additionalProperties.clear()
                event.additionalProperties.putAll(modifiedEvent.additionalProperties)
            } else {
                result = null
            }
        }

        return result
    }
}
