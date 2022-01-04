package com.datadoghq.flutter

import com.datadog.android.rum.GlobalRum
import com.datadog.android.rum.RumMonitor
import io.flutter.embedding.engine.plugins.FlutterPlugin
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

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    private val rum: RumMonitor by lazy {
        rumInstance ?: GlobalRum.get()
    }

    fun setup(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter.rum")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding
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

    fun teardown(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}