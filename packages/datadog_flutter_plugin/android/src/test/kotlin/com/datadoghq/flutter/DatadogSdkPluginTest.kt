/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.util.Log
import assertk.assertThat
import assertk.assertions.isEmpty
import assertk.assertions.isEqualTo
import assertk.assertions.isNotNull
import assertk.assertions.isTrue
import com.datadog.android.Datadog
import com.datadog.android.core.configuration.Configuration
import com.datadog.android.core.configuration.Credentials
import com.datadog.android.privacy.TrackingConsent
import com.datadog.android.rum.GlobalRum
import com.datadog.android.rum.RumMonitor
import com.datadog.android.v2.api.context.UserInfo
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.mockkStatic
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Disabled
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.any
import org.mockito.kotlin.argThat
import org.mockito.kotlin.doReturn
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever

@ExtendWith(ForgeExtension::class)
class DatadogSdkPluginTest {
    lateinit var plugin: DatadogSdkPlugin

    lateinit var mockContext: Context

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
            on { getPackageInfo(any<String>(), any<Int>()) } doReturn mockPackageInfo
        }
        val mockPreferences = mock<SharedPreferences>()
        mockContext = mock<Context>() {
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
        plugin.stop()
    }

    val contracts = listOf(
        Contract("setSdkVerbosity", mapOf(
            "value" to ContractParameter.Type(SupportedContractType.STRING)
        )),
        Contract("setUserInfo", mapOf(
            "extraInfo" to ContractParameter.Type(SupportedContractType.MAP)
        )),
        Contract("addUserExtraInfo", mapOf(
            "extraInfo" to ContractParameter.Type(SupportedContractType.MAP)
        )),
        Contract("setTrackingConsent", mapOf(
            "value" to ContractParameter.Type(SupportedContractType.STRING)
        )),
        Contract("telemetryDebug", mapOf(
            "message" to ContractParameter.Type(SupportedContractType.STRING)
        )),
        Contract("telemetryError", mapOf(
            "message" to ContractParameter.Type(SupportedContractType.STRING)
        )),
    )

    @Test
    fun `M report contract violation W missing parameters in contract`(
        @StringForgery clientToken: String,
        @StringForgery environment: String,
        forge: Forge
    ) {
        // GIVEN
        val configuration = DatadogFlutterConfiguration(
            clientToken = clientToken,
            env = environment,
            nativeCrashReportEnabled = false,
            trackingConsent = TrackingConsent.GRANTED
        )
        plugin.initialize(configuration)

        testContracts(contracts, forge, plugin)
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

        // Because we have no way to reset these, we can't test
        // that they're registered properly.
        //assertThat(plugin.rumPlugin).isNull()
        //assertThat(GlobalRum.isRegistered()).isFalse()
    }


    @Test
    @Disabled("There's an issue calling Choreographer in RUM vital initialization")
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
                sampleRate = 82.3f,
                detectLongTasks = true,
                longTaskThreshold = 0.1f,
                customEndpoint = null
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
                    "nativeCrashReportEnabled" to true
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

    @Test
    fun `M initialize dartVersion telemetry W called through MethodChannel { dartVersion }`(
        @StringForgery clientToken: String,
        @StringForgery environment: String,
        @StringForgery applicationId: String,
        @StringForgery dartVersion: String
    ) {
        // GIVEN
        val methodCall = MethodCall(
            "initialize",
            mapOf(
                "configuration" to mapOf(
                    "clientToken" to clientToken,
                    "env" to environment,
                    "trackingConsent" to "TrackingConsent.granted",
                    "nativeCrashReportEnabled" to true
                ),
                "dartVersion" to dartVersion
            )
        )
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        assertThat(plugin.telemetryOverrides.dartVersion).isEqualTo(dartVersion)
    }


    @Test
    fun `M not issue warning W initialize called with same configuration`(
        forge: Forge
    ) {
        // GIVEN
        mockkStatic(Log::class)
        Datadog.setVerbosity(Log.INFO)

        val config = mapOf(
            "clientToken" to forge.anAlphaNumericalString(),
            "env" to forge.anAlphabeticalString(),
            "trackingConsent" to "TrackingConsent.granted",
            "nativeCrashReportEnabled" to true,
            "loggingConfiguration" to null
        )
        val methodCall = MethodCall(
            "initialize",
            mapOf(
                "configuration" to config
            )
        )
        val mockResult = mock<MethodChannel.Result>()
        plugin.onMethodCall(methodCall, mockResult)

        // WHEN
        val methodCallB = MethodCall(
            "initialize",
            mapOf(
                "configuration" to config
            )
        )
        val mockResultB = mock<MethodChannel.Result>()
        plugin.onMethodCall(methodCallB, mockResultB)

        // THEN
        io.mockk.verify(exactly = 0) {
            Log.println(any(), eq(DATADOG_FLUTTER_TAG), any())
        }
    }

    @Test
    fun `M issue warning W initialize called with different configuration`(
        forge: Forge
    ) {
        // GIVEN
        Datadog.setVerbosity(Log.INFO)

        val methodCall = MethodCall(
            "initialize",
            mapOf(
                "configuration" to mapOf(
                    "clientToken" to forge.anAlphaNumericalString(),
                    "env" to forge.anAlphabeticalString(),
                    "trackingConsent" to "TrackingConsent.granted",
                    "nativeCrashReportEnabled" to true,
                    "loggingConfiguration" to null
                )
            )
        )
        val mockResult = mock<MethodChannel.Result>()
        plugin.onMethodCall(methodCall, mockResult)

        // WHEN
        mockkStatic(Log::class)
        val methodCallB = MethodCall(
            "initialize",
            mapOf(
                "configuration" to mapOf(
                    "clientToken" to forge.anAlphaNumericalString(),
                    "env" to forge.anAlphabeticalString(),
                    "trackingConsent" to "TrackingConsent.granted",
                    "nativeCrashReportEnabled" to true,
                    "loggingConfiguration" to null
                )
            )
        )
        val mockResultB = mock<MethodChannel.Result>()
        plugin.onMethodCall(methodCallB, mockResultB)

        // THEN
        io.mockk.verify(exactly = 1) { Log.e(DATADOG_FLUTTER_TAG, MESSAGE_INVALID_REINITIALIZATION) }
    }

    @Test
    fun `M issue warning W attachToExisting has no existing instance`() {
        // GIVEN
        val methodCall = MethodCall(
            "attachToExisting",
            mapOf<String, Any?>()
        )
        val mockResult = mock<MethodChannel.Result>()
        mockkStatic(Log::class)

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        io.mockk.verify(exactly = 1) { Log.e(DATADOG_FLUTTER_TAG, MESSAGE_NO_EXISTING_INSTANCE) }
        verify(mockResult).success(null)
    }

    @Test
    fun `M return {rumEnabled false} W attachToExisting with rum not initialized`(
        forge: Forge
    ) {
        // GIVEN
        Datadog.setVerbosity(Log.INFO)
        val mockCredentials = Credentials(
            clientToken = forge.anAlphaNumericalString(),
            envName = forge.anAlphaNumericalString(),
            variant = forge.anAlphaNumericalString(),
            rumApplicationId = forge.anAlphaNumericalString(),
            serviceName = null
        )
        val datadogConfig = Configuration.Builder(
            logsEnabled = true,
            tracesEnabled = false,
            crashReportsEnabled = false,
            rumEnabled = false,
        ).build()
        Datadog.initialize(mockContext, mockCredentials, datadogConfig, TrackingConsent.GRANTED)

        val methodCall = MethodCall(
            "attachToExisting",
            mapOf<String, Any?>()
        )
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        verify(mockResult).success(argThat {
            var rumEnabled = false
            val map = this as? Map<*, *>
            map?.let {
                rumEnabled = (map["rumEnabled"] as? Boolean) ?: false
            }
            !rumEnabled
        })
    }

    @Test
    @Disabled("There's an issue calling Choreographer in RUM vital initialization")
    fun `M return {rumEnabled true} W attachToExisting with rum initialized`(
        forge: Forge
    ) {
        // GIVEN
        Datadog.setVerbosity(Log.INFO)
        val mockCredentials = Credentials(
            forge.anAlphaNumericalString(),
            forge.anAlphaNumericalString(),
            forge.anAlphaNumericalString(),
            forge.anAlphaNumericalString(),
            null
        )
        val datadogConfig = Configuration.Builder(
            logsEnabled = true,
            tracesEnabled = false,
            crashReportsEnabled = false,
            rumEnabled = true,
        ).build()
        Datadog.initialize(mockContext, mockCredentials, datadogConfig, TrackingConsent.GRANTED)

        val monitor = RumMonitor.Builder().build()
        GlobalRum.registerIfAbsent(monitor)

        val methodCall = MethodCall(
            "attachToExisting",
            mapOf<String, Any?>()
        )
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        verify(mockResult).success(argThat {
            var correct = false
            val map = this as? Map<*, *>
            map?.let {
                correct = (map["rumEnabled"] as? Boolean) ?: false
            }
            correct
        })
    }

    @Test
    fun `M set sdk verbosity W called through MethodChannel`(
        forge: Forge
    ) {
        // GIVEN
        val configuration = DatadogFlutterConfiguration(
            clientToken = forge.aString(),
            env = "prod",
            nativeCrashReportEnabled = false,
            trackingConsent = TrackingConsent.GRANTED
        )
        plugin.initialize(configuration)

        val methodCall = MethodCall(
            "setSdkVerbosity",
            mapOf( "value" to "Verbosity.info" )
        )
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        val sdkCore: Any = Datadog.getFieldValue<Any, Datadog>("globalSdkCore")
        val setVerbosity: Int = sdkCore.getFieldValue("libraryVerbosity")
        assertThat(setVerbosity).isEqualTo(Log.INFO)
        verify(mockResult).success(null)
    }

    @Test
    fun `M set tracking consent W called through MethodChannel`(
        forge: Forge
    ) {
        // GIVEN
        val configuration = DatadogFlutterConfiguration(
            clientToken = forge.aString(),
            env = forge.anAlphabeticalString(),
            nativeCrashReportEnabled = false,
            trackingConsent = TrackingConsent.GRANTED
        )
        plugin.initialize(configuration)

        val methodCall = MethodCall(
            "setTrackingConsent",
            mapOf( "value" to "TrackingConsent.notGranted" )
        )
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        val coreFeature: Any = Datadog.getFieldValue<Any, Datadog>("globalSdkCore")
            .getFieldValue("coreFeature")
        val trackingConsent: TrackingConsent? = coreFeature
            .getFieldValue<Any, Any>("trackingConsentProvider")
            .getFieldValue("consent")
        assertThat(trackingConsent).isEqualTo(TrackingConsent.NOT_GRANTED)
        verify(mockResult).success(null)
    }

    @Test
    fun `M set user info W called through MethodChannel`(
        @StringForgery id: String,
        @StringForgery name: String,
        @StringForgery email: String,
        forge: Forge
    ) {
        // GIVEN
        val configuration = DatadogFlutterConfiguration(
            clientToken = forge.aString(),
            env = forge.anAlphabeticalString(),
            nativeCrashReportEnabled = false,
            trackingConsent = TrackingConsent.GRANTED
        )
        plugin.initialize(configuration)

        val methodCall = MethodCall(
            "setUserInfo",
            mapOf(
                "id" to id,
                "name" to name,
                "email" to email,
                "extraInfo" to mapOf<String, Any?>()
            )
        )
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        val coreFeature: Any = Datadog.getFieldValue<Any, Datadog>("globalSdkCore")
            .getFieldValue("coreFeature")
        val userInfo: UserInfo? = coreFeature
            .getFieldValue<Any, Any>("userInfoProvider")
            .getFieldValue("internalUserInfo")
        assertThat(userInfo?.id).isEqualTo(id)
        assertThat(userInfo?.name).isEqualTo(name)
        assertThat(userInfo?.email).isEqualTo(email)
        assertThat(userInfo?.additionalProperties).isNotNull().isEmpty()
        verify(mockResult).success(null)
    }

    @Test
    fun `M set user info W called through MethodChannel(null values, exhaustive attributes)`(
        forge: Forge
    ) {
        // GIVEN
        val configuration = DatadogFlutterConfiguration(
            clientToken = forge.aString(),
            env = forge.anAlphabeticalString(),
            nativeCrashReportEnabled = false,
            trackingConsent = TrackingConsent.GRANTED
        )
        plugin.initialize(configuration)

        val id = forge.aNullable { forge.aString() }
        val name = forge.aNullable { forge.aString() }
        val email = forge.aNullable { forge.aString() }
        val extraInfo = forge.exhaustiveAttributes()
        val methodCall = MethodCall(
            "setUserInfo",
            mapOf(
                "id" to id,
                "name" to name,
                "email" to email,
                "extraInfo" to extraInfo
            )
        )
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        val coreFeature: Any = Datadog.getFieldValue<Any, Datadog>("globalSdkCore")
            .getFieldValue("coreFeature")
        val userInfo: UserInfo? = coreFeature
            .getFieldValue<Any, Any>("userInfoProvider")
            .getFieldValue("internalUserInfo")
        assertThat(userInfo?.id).isEqualTo(id)
        assertThat(userInfo?.name).isEqualTo(name)
        assertThat(userInfo?.email).isEqualTo(email)
        assertThat(userInfo?.additionalProperties).isEqualTo(extraInfo)
        verify(mockResult).success(null)
    }

    @Test
    fun `M set user extra info W called through MethodChannel(exhaustive attributes)`(
        forge: Forge
    ) {
        // GIVEN
        val configuration = DatadogFlutterConfiguration(
            clientToken = forge.aString(),
            env = forge.anAlphabeticalString(),
            nativeCrashReportEnabled = false,
            trackingConsent = TrackingConsent.GRANTED
        )
        plugin.initialize(configuration)

        val extraInfo = forge.exhaustiveAttributes()
        val methodCall = MethodCall(
            "addUserExtraInfo",
            mapOf(
                "extraInfo" to extraInfo
            )
        )
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        val coreFeature: Any = Datadog.getFieldValue<Any, Datadog>("globalSdkCore")
            .getFieldValue("coreFeature")
        val userInfo: UserInfo? = coreFeature
            .getFieldValue<Any, Any>("userInfoProvider")
            .getFieldValue("internalUserInfo")
        assertThat(userInfo?.additionalProperties).isEqualTo(extraInfo)
        verify(mockResult).success(null)
    }

    @Test
    fun `M set correct telemetry overrides W updateTelemetryConfiguration`(
        forge: Forge
    ) {
        // GIVEN
        val configuration = DatadogFlutterConfiguration(
            clientToken = forge.aString(),
            env = forge.anAlphabeticalString(),
            nativeCrashReportEnabled = false,
            trackingConsent = TrackingConsent.GRANTED
        )
        plugin.initialize(configuration)

        val trackViewsManually = forge.aBool()
        val trackInteractions = forge.aBool()
        val trackErrors = forge.aBool()
        val trackNetworkRequests = forge.aBool()
        val trackNativeViews = forge.aBool()
        val trackCrossPlatformLongTasks = forge.aBool()
        val trackFlutterPerformance = forge.aBool()

        fun callAndCheck(property: String, value: Boolean, check: () -> Unit) {
            val methodCall = MethodCall(
                "updateTelemetryConfiguration",
                mapOf(
                    "option" to property,
                    "value" to value
                )
            )
            val mockResult = mock<MethodChannel.Result>()
            plugin.onMethodCall(methodCall, mockResult)
            verify(mockResult).success(null)
            check()
        }

        callAndCheck("trackViewsManually", trackViewsManually) {
            assertThat(plugin.telemetryOverrides.trackViewsManually).isEqualTo(trackViewsManually)
        }
        callAndCheck("trackInteractions", trackInteractions) {
            assertThat(plugin.telemetryOverrides.trackInteractions).isEqualTo(trackInteractions)
        }
        callAndCheck("trackErrors", trackErrors) {
            assertThat(plugin.telemetryOverrides.trackErrors).isEqualTo(trackErrors)
        }
        callAndCheck("trackNetworkRequests", trackNetworkRequests) {
            assertThat(plugin.telemetryOverrides.trackNetworkRequests).isEqualTo(trackNetworkRequests)
        }
        callAndCheck("trackNativeViews", trackNativeViews) {
            assertThat(plugin.telemetryOverrides.trackNativeViews).isEqualTo(trackNativeViews)
        }
        callAndCheck("trackCrossPlatformLongTasks", trackCrossPlatformLongTasks) {
            assertThat(plugin.telemetryOverrides.trackCrossPlatformLongTasks).isEqualTo(trackCrossPlatformLongTasks)
        }
        callAndCheck("trackFlutterPerformance", trackFlutterPerformance) {
            assertThat(plugin.telemetryOverrides.trackFlutterPerformance).isEqualTo(trackFlutterPerformance)
        }
    }
}