/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.content.Context
import android.content.SharedPreferences
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import assertk.assertThat
import assertk.assertions.isFalse
import assertk.assertions.isNotNull
import assertk.assertions.isNull
import assertk.assertions.isTrue
import com.datadog.android.Datadog
import com.datadog.android.privacy.TrackingConsent
import com.datadog.android.rum.GlobalRum
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.opentracing.util.GlobalTracer
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.any
import org.mockito.kotlin.doReturn
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever

@ExtendWith(ForgeExtension::class)
class DatadogSdkPluginTest {
    lateinit var plugin: DatadogSdkPlugin

    @BeforeEach
    fun beforeEach() {
        plugin = DatadogSdkPlugin()
        val mockFlutterPluginBinding = mock<FlutterPlugin.FlutterPluginBinding>()
        whenever(mockFlutterPluginBinding.binaryMessenger).thenReturn(mock())
        // Mock everything to get Datadog to initialize properly
        val mockPackageInfo = mock<PackageInfo> {
            mock.versionName = "version"
            mock.versionCode = 1124
        }
        val mockPackageManager = mock<PackageManager> {
            on { getPackageInfo(any<String>(), any()) } doReturn mockPackageInfo
        }
        val mockPreferences = mock<SharedPreferences>()
        val mockContext = mock<Context>() {
            on { applicationInfo } doReturn mock()
            on { applicationContext } doReturn this.mock
            on { packageName } doReturn "fakePackage"
            on { packageManager } doReturn mockPackageManager
            on { getSharedPreferences(any(), any()) } doReturn mockPreferences
        }
        whenever(mockFlutterPluginBinding.applicationContext).thenReturn(mockContext)
        plugin.onAttachedToEngine(mockFlutterPluginBinding)
    }

    @AfterEach
    fun afterEach() {
        Datadog.invokeMethod("flushAndShutdownExecutors")
    }

    @Test
    fun `M not initialize features W no nested configuration`(
        @StringForgery clientToken: String,
        @StringForgery environment: String
    ) {
        // GIVEN
        val configuration = DatadogFlutterConfiguration(
            clientToken = clientToken,
            env = environment,
            nativeCrashReportEnabled = false,
            trackingConsent = TrackingConsent.GRANTED
        )

        // WHEN
        plugin.initialize(configuration)

        // THEN
        assertThat(Datadog.isInitialized()).isTrue()
        assertThat(plugin.logsPlugin).isNull()
        assertThat(plugin.tracesPlugin).isNull()
        assertThat(plugin.rumPlugin).isNull()

        // Because we have no way to reset these, we can't test
        // that they're registered properly.
        //assertThat(GlobalRum.isRegistered()).isFalse()
        //assertThat(GlobalTracer.isRegistered()).isFalse()
    }

    @Test
    fun `M initialize logger W DatadogFlutterConfiguation { loggingConfiguration }`(
        @StringForgery clientToken: String,
        @StringForgery environment: String
    ) {
        // GIVEN
        val configuration = DatadogFlutterConfiguration(
            clientToken = clientToken,
            env = environment,
            nativeCrashReportEnabled = false,
            trackingConsent = TrackingConsent.GRANTED,
            loggingConfiguration = DatadogFlutterConfiguration.LoggingConfiguration(
                sendNetworkInfo = true,
                printLogsToConsole = true,
                bundleWithRum = false,
                bundleWithTraces = false
            )
        )

        // WHEN
        plugin.initialize(configuration)

        // THEN
        assertThat(plugin.logsPlugin).isNotNull()
        assertThat(plugin.logsPlugin?.log).isNotNull()
    }

    @Test
    fun `M initialize traces W DatadogFlutterConfiguation { tracingConfiguration }`(
        @StringForgery clientToken: String,
        @StringForgery environment: String
    ) {
        // GIVEN
        val configuration = DatadogFlutterConfiguration(
            clientToken = clientToken,
            env = environment,
            nativeCrashReportEnabled = false,
            trackingConsent = TrackingConsent.GRANTED,
            tracingConfiguration = DatadogFlutterConfiguration.TracingConfiguration(
                sendNetworkInfo = true,
                bundleWithRum = true
            )
        )

        // WHEN
        plugin.initialize(configuration)

        // THEN
        assertThat(plugin.tracesPlugin).isNotNull()
        // NOTE: We have no way of knowing if this was set in a previous test
        assertThat(GlobalTracer.isRegistered()).isTrue()
    }

    @Test
    fun `M initialize RUM W DatadogFlutterConfiguration { rumConfiguration }`(
        @StringForgery clientToken: String,
        @StringForgery environment: String,
        @StringForgery applicationId: String
    ) {
        // GIVEN
        val configuration = DatadogFlutterConfiguration(
            clientToken = clientToken,
            env = environment,
            nativeCrashReportEnabled = false,
            trackingConsent = TrackingConsent.GRANTED,
            rumConfiguration = DatadogFlutterConfiguration.RumConfiguration(
                applicationId = applicationId,
                sampleRate = 82.3f
            )
        )

        // WHEN
        plugin.initialize(configuration)

        // THEN
        assertThat(plugin.rumPlugin).isNotNull()
        // NOTE: We have no way of knowing if this was set in a previous test
        assertThat(GlobalRum.isRegistered()).isTrue()
    }

    @Test
    fun `M initialize Datadog W called through MethodChannel`(
        @StringForgery clientToken: String,
        @StringForgery environment: String,
        @StringForgery applicationId: String
    ) {
        // GIVEN
        val methodCall = MethodCall(
            "initialize",
            mapOf(
                "configuration" to mapOf(
                    "clientToken" to clientToken,
                    "env" to environment,
                    "trackingConsent" to "TrackingConsent.granted",
                    "nativeCrashReportEnabled" to true,
                    "loggingConfiguration" to mapOf(
                        "sendNetworkInfo" to true,
                        "printLogsToConsole" to true,
                        "bundleWithRum" to true,
                        "bundleWithTraces" to true,
                    )
                )
            )
        )
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        assertThat(Datadog.isInitialized())
        assertThat(plugin.logsPlugin).isNotNull()
        verify(mockResult).success(null)
    }
}