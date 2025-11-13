package com.datadoghq.flutter

import com.datadog.android.rum.RumConfiguration
import com.datadog.android.rum.model.ActionEvent
import com.datadog.android.rum.model.ErrorEvent
import com.datadog.android.rum.model.LongTaskEvent
import com.datadog.android.rum.model.ResourceEvent
import com.datadog.android.rum.model.ViewEvent
import com.google.gson.JsonParser

/**
 * This is a helper class that that simplifies event mapping / scrubbing for RUM events.
 *
 * This class is used as a static instance that can be assigned a Dart callback object through
 * a jnigen interface.
 */
@Suppress("StringLiteralDuplication")
class DatadogRumEventMapper {
    // Even though mappers use "jnigen" and could bind / modify the RUM events
    // directly, this would require users use separate iOS / Android callbacks. by sending
    // encoded versions, we can hide some platform specifics.
    interface EventMapper {
        fun mapViewEvent(encodedEvent: String): String?
        fun mapActionEvent(encodedEvent: String): String?
        fun mapResourceEvent(encodedEvent: String): String?
        fun mapErrorEvent(encodedEvent: String): String?
        fun mapLongTaskEvent(encodedEvent: String): String?
    }

    var eventMapper: EventMapper? = null

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

    internal fun mapViewEvent(event: ViewEvent): ViewEvent {
        var result: ViewEvent = event

        eventMapper?.let { mapper ->
            val encodedEvent = event.toJson().toString()

            val encodedResult = mapper.mapViewEvent(encodedEvent)
            if (encodedResult != null) {
                val jsonObject = JsonParser.parseString(encodedResult).asJsonObject
                val jsonView = jsonObject.get("view").asJsonObject
                result.view.name = jsonView.get("name")?.asString
                result.view.referrer = jsonView.get("referrer")?.asString
                result.view.url = jsonView.get("url").asString
            }
            // TODO: Telemetry -- view mappers can't return null
        }

        return result
    }

    @Suppress("NestedBlockDepth")
    internal fun mapActionEvent(event: ActionEvent): ActionEvent? {
        var result: ActionEvent? = event

        eventMapper?.let { mapper ->
            val encodedEvent = event.toJson().toString()

            val encodedResult = mapper.mapActionEvent(encodedEvent)
            if (encodedResult != null) {
                val jsonObject = JsonParser.parseString(encodedResult).asJsonObject
                val jsonView = jsonObject.get("view").asJsonObject
                result!!.view.name = jsonView.get("name")?.asString
                result.view.referrer = jsonView.get("referrer")?.asString
                result.view.url = jsonView.get("url").asString

                result.action.target?.let { resultTarget ->
                    jsonObject.get("action")?.asJsonObject?.get("target")?.asJsonObject?.let {
                        resultTarget.name = it.get("name").asString
                    }
                }
            } else {
                result = null
            }
        }

        return result
    }

    internal fun mapResourceEvent(event: ResourceEvent): ResourceEvent? {
        var result: ResourceEvent? = event

        eventMapper?.let { mapper ->
            val encodedEvent = event.toJson().toString()

            val encodedResult = mapper.mapResourceEvent(encodedEvent)
            if (encodedResult != null) {
                val jsonObject = JsonParser.parseString(encodedResult).asJsonObject
                val jsonView = jsonObject.get("view").asJsonObject
                result!!.view.name = jsonView.get("name")?.asString
                result.view.referrer = jsonView.get("referrer")?.asString
                result.view.url = jsonView.get("url").asString

                result.resource.url = jsonObject.get("resource").asJsonObject.get("url").asString
            } else {
                result = null
            }
        }

        return result
    }

    @Suppress("NestedBlockDepth")
    internal fun mapErrorEvent(event: ErrorEvent): ErrorEvent? {
        var result: ErrorEvent? = event

        eventMapper?.let { mapper ->
            val encodedEvent = event.toJson().toString()

            val encodedResult = mapper.mapErrorEvent(encodedEvent)
            if (encodedResult != null) {
                val jsonObject = JsonParser.parseString(encodedResult).asJsonObject
                val jsonView = jsonObject.get("view").asJsonObject
                result!!.view.name = jsonView.get("name")?.asString
                result.view.referrer = jsonView.get("referrer")?.asString
                result.view.url = jsonView.get("url").asString

                val jsonError = jsonObject.get("error").asJsonObject
                event.error.causes?.let { causes ->
                    val jsonCauses = jsonError.get("causes").asJsonArray
                    if (causes.count() == jsonCauses.count()) {
                        causes.forEachIndexed { i, cause ->
                            val jsonCause = jsonCauses.get(i).asJsonObject
                            cause.message = jsonCause.get("message")?.asString ?: ""
                            cause.stack = jsonCause.get("stack")?.asString ?: ""
                        }
                    }
                }
                result.error.resource?.let { resultResource ->
                    jsonError.get("resource")?.asJsonObject?.let {
                        resultResource.url = it.get("url").asString
                    }
                }

                result.error.stack = jsonError.get("stack")?.asString
                result.error.fingerprint = jsonError.get("fingerprint")?.asString
            } else {
                result = null
            }
        }

        return result
    }

    internal fun mapLongTaskEvent(event: LongTaskEvent): LongTaskEvent? {
        var result: LongTaskEvent? = event

        eventMapper?.let { mapper ->
            val encodedEvent = event.toJson().toString()

            val encodedResult = mapper.mapLongTaskEvent(encodedEvent)
            if (encodedResult != null) {
                val jsonObject = JsonParser.parseString(encodedResult).asJsonObject
                val jsonView = jsonObject.get("view").asJsonObject

                result!!.view.name = jsonView.get("name")?.asString
                result.view.referrer = jsonView.get("referrer")?.asString
                result.view.url = jsonView.get("url").asString
            } else {
                result = null
            }
        }

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
