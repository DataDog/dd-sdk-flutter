/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2026-Present Datadog, Inc.
 */

package com.datadoghq.flutter

import android.content.Context
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureSdkCore

/**
 * Stands in for the native tracing feature under [Feature.TRACING_FEATURE_NAME], so that the trace
 * sample rate Flutter traces requests with reaches RUM, which reports it as
 * `_dd.configuration.trace_sample_rate`. RUM only reads it from that feature's context, which only
 * the native OkHttp instrumentation fills, and Flutter traces requests in Dart instead.
 *
 * Only registered when no tracing feature is: registering a feature replaces any other one with the
 * same name, and native tracing publishes its own rate. Enabling native tracing later replaces this
 * feature in turn.
 *
 * While registered, native code takes tracing as enabled: a native Datadog OkHttp interceptor in the
 * same app traces requests whose spans are then dropped, as this feature stores nothing, and the
 * configuration telemetry reports tracing as enabled.
 */
internal class TracingContextFeature : Feature {
    override val name: String = Feature.TRACING_FEATURE_NAME

    override fun onInitialize(appContext: Context) = Unit

    override fun onStop() = Unit

    companion object {
        // Must match TracingInterceptor.OKHTTP_INTERCEPTOR_SAMPLE_RATE in dd-sdk-android-okhttp and
        // RumViewScope.TRACE_SAMPLE_RATE in dd-sdk-android-rum
        internal const val TRACE_SAMPLE_RATE_KEY = "okhttp_interceptor_sample_rate"

        private val registrationLock = Any()

        /**
         * Publishes [sampleRate] in the tracing feature context, registering a
         * [TracingContextFeature] if no tracing feature is registered. Does nothing when native
         * tracing is enabled, as it owns that context.
         */
        fun publishTraceSampleRate(sdkCore: FeatureSdkCore, sampleRate: Float) {
            synchronized(registrationLock) {
                val registered = sdkCore.getFeature(Feature.TRACING_FEATURE_NAME)
                if (registered == null) {
                    sdkCore.registerFeature(TracingContextFeature())
                } else if (registered.unwrap<Feature>() !is TracingContextFeature) {
                    return
                }
            }
            // RUM reads the rate as a Float, and treats any other type as no rate.
            sdkCore.updateFeatureContext(Feature.TRACING_FEATURE_NAME) {
                it[TRACE_SAMPLE_RATE_KEY] = sampleRate
            }
        }
    }
}
