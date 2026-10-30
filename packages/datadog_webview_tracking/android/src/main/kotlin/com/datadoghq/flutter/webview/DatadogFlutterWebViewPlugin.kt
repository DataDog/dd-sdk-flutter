/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2023-Present Datadog, Inc.
 */
package com.datadoghq.flutter.webview

import android.util.Log
import androidx.annotation.NonNull
import com.datadog.android.Datadog
import com.datadog.android.webview.WebViewTracking
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi

fun MethodChannel.Result.missingParameter(methodName: String, details: Any? = null) {
    this.error(
        "DatadogSdk:ContractViolation",
        "Missing required parameter in call to $methodName",
        details
    )
}

class DatadogFlutterWebViewPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var binding: FlutterPlugin.FlutterPluginBinding? = null

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_webview_tracking")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        if (call.method == "initWebView") {
            val identifier = call.argument<Number>("webViewIdentifier")
            val allowedHosts = call.argument<List<String>>("allowedHosts")
            if (identifier != null && allowedHosts != null) {
                result.success(initWebView(identifier.toLong(), allowedHosts))
            } else {
                result.missingParameter(call.method)
            }
        } else {
            result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        this.binding = null

        channel.setMethodCallHandler(null)
    }

    /*
     * Tracks the WebView and returns its Session Replay slot ID, or `null` if it is not tracked.
     */
    private fun initWebView(webViewIdentifier: Long, allowedHosts: List<String>): String? {
        val binding = binding ?: return null
        val webView = WebViewFlutterAndroidExternalApi.getWebView(binding, webViewIdentifier)
        if (webView == null) {
            Datadog._internalProxy()._telemetry.error(
                "Could not find WebView during initialization when an identifier was provided"
            )
            return null
        }
        if (!webView.settings.javaScriptEnabled) {
            Log.e(DATADOG_FLUTTER_WEBVIEW_TAG, JAVA_SCRIPT_NOT_ENABLED_WARNING_MESSAGE)
            return null
        }
        WebViewTracking.enable(webView, allowedHosts)
        // Matches the slot ID `WebViewTracking.enable` gives the WebView's replay records.
        return System.identityHashCode(webView).toString()
    }
}

internal const val DATADOG_FLUTTER_WEBVIEW_TAG = "DatadogFlutterWebView"

internal const val JAVA_SCRIPT_NOT_ENABLED_WARNING_MESSAGE =
    "You are trying to enable Datadog WebView tracking but the JavaScript capability was not" +
        " enabled for the given WebView. Make sure to call" +
        " .setJavaScriptMode(JavaScriptMode.unrestricted) on your WebViewController"
