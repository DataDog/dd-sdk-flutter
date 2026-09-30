/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

class DatadogSessionReplayPlugin private constructor(
    private val manager: FlutterSessionReplayManager
) : FlutterPlugin {
    // The constructor Flutter's plugin registrant calls.
    constructor() : this(FlutterSessionReplayManager.shared)

    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // FFI plugins do not receive engine lifecycle events, so we cannot determine which engine
        // called enable() from within the FFI call itself. Instead, after calling enable() via FFI,
        // Dart fires a non-awaited 'registerEngine' message through this method channel, carrying
        // the token of the bridge it just created. Because method channels route to the plugin
        // instance for their specific engine, this pairs that bridge with this engine's messenger.
        // See: https://github.com/flutter/flutter/issues/184124
        channel = MethodChannel(binding.binaryMessenger, ENGINE_CHANNEL_NAME)
        channel?.setMethodCallHandler { call, result ->
            if (call.method == REGISTER_ENGINE_METHOD) {
                val engineToken = call.arguments as? String
                if (engineToken == null) {
                    result.error(
                        "DatadogSdk:InvalidOperation",
                        "$REGISTER_ENGINE_METHOD requires the engine token as its argument.",
                        null
                    )
                } else {
                    manager.bind(engineToken, binding.binaryMessenger)
                    result.success(null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        // Release this engine's bridge, so context updates don't attempt to invoke a callback into
        // the now-destroyed Dart isolate, which would cause a SIGABRT. Keyed by messenger, so a
        // secondary engine detaching doesn't disturb a still-live one.
        manager.detach(binding.binaryMessenger)
    }

    internal companion object {
        internal const val ENGINE_CHANNEL_NAME = "datadog_session_replay/engine"
        internal const val REGISTER_ENGINE_METHOD = "registerEngine"

        internal fun create(manager: FlutterSessionReplayManager) =
            DatadogSessionReplayPlugin(manager)
    }
}
