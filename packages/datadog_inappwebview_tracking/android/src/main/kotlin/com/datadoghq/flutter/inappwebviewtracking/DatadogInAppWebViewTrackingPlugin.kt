package com.datadoghq.flutter.inappwebviewtracking

import com.datadog.android.Datadog
import com.datadog.android.webview.WebViewTracking
import com.datadoghq.flutter.DatadogSdkPlugin
import com.datadoghq.flutter.invalidOperation
import com.google.gson.JsonParser
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.security.SecureRandom
import java.util.Locale.US

class DatadogInAppWebViewTrackingPlugin : FlutterPlugin, MethodCallHandler {
    private val random = SecureRandom()
    private lateinit var channel: MethodChannel
    private var internalWebViewProxy: WebViewTracking._InternalWebViewProxy? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "datadog_inappwebview_tracking"
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "webViewMessage") {
            handleWebViewMessage(call, result)
        } else {
            result.notImplemented()
        }
    }

    private fun handleWebViewMessage(call: MethodCall, result: Result) {
        val message = call.argument<String>("message")
        val logSampleRate = call.argument<Double>("logSampleRate")
        if (message == null || logSampleRate == null) {
            result.missingParameter(call.method)
            return
        }

        val datadogSdk = Datadog.getInstance()
        if (internalWebViewProxy == null) {
            internalWebViewProxy = WebViewTracking._InternalWebViewProxy(datadogSdk)
        }

        // The proxy doesn't do any sampling, so we need to parse the message, see if it's a log,
        // then sample as needed.
        val webEvent = JsonParser.parseString(message).asJsonObject
        if (!webEvent.has(EVENT_TYPE_KEY)) {
            result.invalidOperation(WEB_EVENT_MISSING_TYPE_ERROR_MESSAGE.format(US, message))
            return
        }

        val eventType = webEvent.get(EVENT_TYPE_KEY).asString
        if (eventType == LOG_EVENT_TYPE) {
            if (logSampleRate < 100.0 && (random.nextFloat() * 100) > logSampleRate) {
                // Log was sampled out.
                result.success(null)
                return
            }
        }

        internalWebViewProxy?.consumeWebviewEvent(message)
        result.success(null)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val EVENT_TYPE_KEY = "eventType"
        const val LOG_EVENT_TYPE = "log"
        const val WEB_EVENT_MISSING_TYPE_ERROR_MESSAGE = "The web event: %s is missing" +
            " the event type."
    }
}

fun MethodChannel.Result.missingParameter(methodName: String, details: Any? = null) {
    this.error(
        DatadogSdkPlugin.CONTRACT_VIOLATION,
        "Missing required parameter in call to $methodName",
        details
    )
}
