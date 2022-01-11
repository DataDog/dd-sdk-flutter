/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.example.flutter

import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val CRASH_CHANNEL = "datadog_sdk_flutter.example.crash"

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CRASH_CHANNEL)
            .setMethodCallHandler { _, result ->
                Handler(Looper.getMainLooper()).postDelayed({
                    @Suppress("TooGenericExceptionThrown")
                    throw RuntimeException("Test crash")
                }, 100)

                result.success(null)
            }
    }
}
