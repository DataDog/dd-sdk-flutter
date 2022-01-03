package com.datadoghq.flutter

import com.datadog.android.rum.GlobalRum
import com.datadog.android.rum.RumMonitor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DatadogRumPlugin(
    rumInstance: RumMonitor? = null
) : MethodChannel.MethodCallHandler {
    companion object RumParameterNames {
        const val PARAM_KEY = "key"
        const val PARAM_NAME = "name"
        const val PARAM_ATTRIBUTES = "attributes"
    }

    private val rum: RumMonitor by lazy {
        rumInstance ?: GlobalRum.get()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when(call.method) {
            "startView" -> {
                val key = call.argument<String>(PARAM_KEY)
                val name = call.argument<String>(PARAM_NAME)
                val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
                if (key != null && name != null && attributes != null) {
                    rum.startView(key, name, attributes)
                }
                result.success(null)
            }
            "stopView" -> {
                val key = call.argument<String>(PARAM_KEY)
                val attributes = call.argument<Map<String, Any?>>(PARAM_ATTRIBUTES)
                if (key != null && attributes != null) {
                    rum.stopView(key, attributes)
                }
                result.success(null)
            }
            "addTiming" -> {
                call.argument<String>(PARAM_NAME)?.let {
                    rum.addTiming(it)
                }
                result.success(null)

            }
            else -> {
                result.notImplemented()
            }
        }
    }
}