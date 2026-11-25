/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2026-Present Datadog, Inc.
 */

package com.datadoghq.hybrid_session_replay_example

import android.app.Application
import android.util.Log
import com.datadog.android.Datadog
import com.datadog.android.DatadogSite
import com.datadog.android.core.configuration.BatchSize
import com.datadog.android.core.configuration.Configuration
import com.datadog.android.core.configuration.UploadFrequency
import com.datadog.android.log.Logs
import com.datadog.android.log.LogsConfiguration
import com.datadog.android.privacy.TrackingConsent
import com.datadog.android.rum.Rum
import com.datadog.android.rum.RumConfiguration
import com.datadog.android.sessionreplay.ImagePrivacy
import com.datadog.android.sessionreplay.SessionReplay
import com.datadog.android.sessionreplay.SessionReplayConfiguration
import com.datadog.android.sessionreplay.TextAndInputPrivacy
import com.datadog.android.sessionreplay.TouchPrivacy
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import org.json.JSONObject

class HybridApplication : Application() {
    private val TAG = "HybridApplication"

    override fun onCreate() {
        super.onCreate()

        var clientToken = ""
        var applicationId = ""
        try {
            val jsonText = resources.openRawResource(R.raw.dd_config).bufferedReader().use {
                it.readText()
            }
            val config = JSONObject(jsonText)
            clientToken = config.get("client_token") as String
            applicationId = config.get("application_id") as String
        } catch (e: Exception) {
            Log.e(
                TAG,
                "Failed to find client token and application id in raw/dd_config.json." +
                    " Did you run './generate_env.sh'?",
                e
            )
        }

        Datadog.setVerbosity(Log.VERBOSE)

        // Datadog must be fully initialized on the Android side, including Session Replay, before
        // any Flutter engine runs `main` and calls `DatadogSdk.attachToExisting`.
        val datadogConfig = Configuration.Builder(clientToken, "prod")
            .setBatchSize(BatchSize.SMALL)
            .setUploadFrequency(UploadFrequency.FREQUENT)
            .useSite(DatadogSite.US1)
            .build()
        Datadog.initialize(this, datadogConfig, TrackingConsent.GRANTED)

        Logs.enable(LogsConfiguration.Builder().build())

        // Each FlutterActivity is tracked as its own RUM view, so the full screen Flutter view gets
        // its own view in the replay.
        Rum.enable(RumConfiguration.Builder(applicationId).build())

        // The native Session Replay records the whole app, Flutter included. Its sample rate decides
        // which sessions get a replay; the Flutter side's `replaySampleRate` is ignored. The privacy
        // levels are not shared, so the Dart side sets the same ones.
        val sessionReplayConfiguration = SessionReplayConfiguration.Builder(100f)
            .setTextAndInputPrivacy(TextAndInputPrivacy.MASK_SENSITIVE_INPUTS)
            .setImagePrivacy(ImagePrivacy.MASK_NONE)
            .setTouchPrivacy(TouchPrivacy.SHOW)
            .build()
        SessionReplay.enable(sessionReplayConfiguration)

        // One engine for the full screen Flutter view (`main`)...
        val flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        FlutterEngineCache.getInstance().put(MAIN_ENGINE_ID, flutterEngine)

        // ... and one for the panel embedded in the native screen (`embeddedMain`).
        val embeddedFlutterEngine = FlutterEngine(this)
        val appBundlePath = FlutterInjector.instance().flutterLoader().findAppBundlePath()
        embeddedFlutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(appBundlePath, "embeddedMain")
        )
        FlutterEngineCache.getInstance().put(EMBEDDED_ENGINE_ID, embeddedFlutterEngine)
    }

    companion object {
        const val MAIN_ENGINE_ID = "main_flutter_engine"
        const val EMBEDDED_ENGINE_ID = "embedded_flutter_engine"
    }
}
