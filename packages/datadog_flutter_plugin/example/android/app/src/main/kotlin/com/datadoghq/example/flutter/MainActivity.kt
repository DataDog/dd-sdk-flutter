/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.example.flutter

import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import com.datadog.android.rum.GlobalRum
import com.datadog.android.rum.RumErrorSource
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

private const val CRASH_CHANNEL = "datadog_sdk_flutter.example.crash"

class MainActivity : FlutterActivity() {
    lateinit var methodChannel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CRASH_CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            methodCallHandler(call, result)
        }
    }

    private fun methodCallHandler(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "crashNative" -> {
                Handler(Looper.getMainLooper()).postDelayed({
                    @Suppress("TooGenericExceptionThrown")
                    throw RuntimeException("Test crash")
                }, 100)
            }
            "throwException" -> {
                throw NullPointerException("Test exception")
            }
            "performCallback" -> {
                val callbackId = call.argument<Int>("callbackId")

                val result = object : MethodChannel.Result {
                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?
                    ) {
                        // Creating the throwable here isn't a great idea, however the point of this
                        // is to see what the combined stack trace looks like, so that's why it's here.
                        GlobalRum.get().addError(
                            errorMessage ?: "Unknown Dart error",
                            RumErrorSource.SOURCE, Throwable(),
                            mapOf(
                                "errorCode" to errorCode,
                                "errorDetails" to errorDetails
                            )
                        )
                    }

                    override fun success(result: Any?) {}
                    override fun notImplemented() {}
                }

                methodChannel.invokeMethod(
                    "nativeCallback",
                    mapOf(
                        "callbackId" to callbackId,
                        "callbackValue" to "Value String"
                    ),
                    result
                )
            }
        }

        result.success(null)
    }
}
