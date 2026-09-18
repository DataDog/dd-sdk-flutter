/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class DatadogSessionReplayPlugin : FlutterPlugin {
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // FFI plugins do not receive engine lifecycle events, so we cannot determine
        // which engine called enable() from within the FFI call itself. Instead, after
        // calling enable() via FFI, Dart fires a non-awaited 'claimOwnership' message
        // through this method channel. Because method channels route to the plugin
        // instance for their specific engine, we can reliably associate the enable()
        // call with this engine's messenger and set listenerOwner correctly.
        // See: https://github.com/flutter/flutter/issues/184124
        channel = MethodChannel(binding.binaryMessenger, "datadog_session_replay/engine")
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "claimOwnership") {
                FlutterSessionReplayBridge.claimOwnership(binding.binaryMessenger)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        // Null out the context listener so context updates don't attempt to invoke a
        // callback into the now-destroyed Dart isolate, which would cause a SIGABRT.
        // The ownership check ensures a secondary engine detaching doesn't clear the
        // listener registered by a still-live engine.
        FlutterSessionReplayBridge.detachFromEngine(binding.binaryMessenger)
    }
}
