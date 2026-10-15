/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2026-Present Datadog, Inc.
 */

package com.datadoghq.hybrid_session_replay_example

import android.os.Bundle
import com.datadoghq.flutter.sessionreplay.enableSessionReplay
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The full screen Flutter view pushed on top of [MainActivity]. It runs the `main` entrypoint on
 * the cached [HybridApplication.MAIN_ENGINE_ID] engine.
 */
class HybridFlutterActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Opts this Flutter view in to the native Session Replay. Flutter must also be configured
        // with `isEmbedded: true` on the Dart side.
        enableSessionReplay()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // The Flutter "Back to native" button asks to close this view.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "dismiss") {
                    finish()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    companion object {
        private const val NAVIGATION_CHANNEL = "hybrid_session_replay_example/navigation"
    }
}
