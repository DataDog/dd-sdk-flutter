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
import com.datadog.android.Datadog
import com.datadog.android.DatadogSite
import com.datadog.android.api.context.UserInfo
import com.datadog.android.core.configuration.BatchProcessingLevel
import com.datadog.android.core.configuration.BatchSize
import com.datadog.android.core.configuration.UploadFrequency
import com.datadog.android.privacy.TrackingConsent
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.mockkStatic
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
        Datadog.stopInstance()
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
        Contract("clearAllData", mapOf()),
    )

    @Test
    fun `M report contract violation W missing parameters in contract`(
        @StringForgery clientToken: String,
        @StringForgery environment: String,
        forge: Forge
    ) {
        val config = mapOf(
            "clientToken" to clientToken,
            "env" to environment
        )

        plugin.initialize(config, TrackingConsent.GRANTED)

        testContracts(contracts, forge, plugin)
    }

    @Test
    fun `M parse all batch sizes W parseBatchSize`() {
        // WHEN
        val small = parseBatchSize("BatchSize.small")
        val medium = parseBatchSize("BatchSize.medium")
        val large = parseBatchSize("BatchSize.large")

        // THEN
        assertThat(small).isEqualTo(BatchSize.SMALL)
        assertThat(medium).isEqualTo(BatchSize.MEDIUM)
        assertThat(large).isEqualTo(BatchSize.LARGE)
    }

    @Test
    fun `M parse all batch processing levels W parseBatchProcessingLevel`() {
        // WHEN
        val low = parseBatchProcessingLevel("BatchProcessingLevel.low")
        val medium = parseBatchProcessingLevel("BatchProcessingLevel.medium")
        val high = parseBatchProcessingLevel("BatchProcessingLevel.high")

        // THEN
        assertThat(low).isEqualTo(BatchProcessingLevel.LOW)
        assertThat(medium).isEqualTo(BatchProcessingLevel.MEDIUM)
        assertThat(high).isEqualTo(BatchProcessingLevel.HIGH)
    }

    @Test
    fun `M parse all upload frequency W parseUploadFrequency`() {
        // WHEN
        val frequent = parseUploadFrequency("UploadFrequency.frequent")
        val average = parseUploadFrequency("UploadFrequency.average")
        val rare = parseUploadFrequency("UploadFrequency.rare")

        // THEN
        assertThat(frequent).isEqualTo(UploadFrequency.FREQUENT)
        assertThat(average).isEqualTo(UploadFrequency.AVERAGE)
        assertThat(rare).isEqualTo(UploadFrequency.RARE)
    }

    @Test
    fun `M parse all tracking consent W parseTrackingConsent`() {
        // WHEN
        val granted = parseTrackingConsent("TrackingConsent.granted")
        val notGranted = parseTrackingConsent("TrackingConsent.notGranted")
        val pending = parseTrackingConsent("TrackingConsent.pending")

        // THEN
        assertThat(granted).isEqualTo(TrackingConsent.GRANTED)
        assertThat(notGranted).isEqualTo(TrackingConsent.NOT_GRANTED)
        assertThat(pending).isEqualTo(TrackingConsent.PENDING)
    }

    @Test
    fun `M parse all sites W parseSite`() {
        // WHEN
        val us1 = parseSite("DatadogSite.us1")
        val us3 = parseSite("DatadogSite.us3")
        val us5 = parseSite("DatadogSite.us5")
        val eu1 = parseSite("DatadogSite.eu1")
        val us1Fed = parseSite("DatadogSite.us1Fed")
        val ap1 = parseSite("DatadogSite.ap1")

        // THEN
        assertThat(us1).isEqualTo(DatadogSite.US1)
        assertThat(us3).isEqualTo(DatadogSite.US3)
        assertThat(us5).isEqualTo(DatadogSite.US5)
        assertThat(eu1).isEqualTo(DatadogSite.EU1)
        assertThat(us1Fed).isEqualTo(DatadogSite.US1_FED)
        assertThat(ap1).isEqualTo(DatadogSite.AP1)
    }

    @Test
    fun `M parse all CoreLoggerLevel W parseCoreLoggerLevel`() {
        // WHEN
        val debug = parseCoreLoggerLevel("CoreLoggerLevel.debug")
        val warn = parseCoreLoggerLevel("CoreLoggerLevel.warn")
        val error = parseCoreLoggerLevel("CoreLoggerLevel.error")
        val critical = parseCoreLoggerLevel("CoreLoggerLevel.critical")
        val unknown = parseCoreLoggerLevel("unknown")

        assertThat(debug).isEqualTo(Log.DEBUG)
        assertThat(warn).isEqualTo(Log.WARN)
        assertThat(error).isEqualTo(Log.ERROR)
        assertThat(critical).isEqualTo(Log.ASSERT)
        assertThat(unknown).isEqualTo(Log.INFO)
    }

    @Test
    fun `M decode defaults W fromEncoded`(
        @StringForgery clientToken: String,
        @StringForgery environment: String
    ) {
        // GIVEN
        val encoded = mapOf(
            "clientToken" to clientToken,
            "env" to environment,
            "nativeCrashReportEnabled" to false,
            "site" to null,
            "batchSize" to null,
            "uploadFrequency" to null,
            "batchProcessingLevel" to null,
            "firstPartyHosts" to listOf<String>(),
            "additionalConfig" to mapOf<String, Any?>()
        )

        // WHEN
        val config = plugin.configurationBuilderFromEncoded(encoded)!!.build()

        // THEN
        assertThat(config.getPrivate("clientToken")).isEqualTo(clientToken)
        assertThat(config.getPrivate("env")).isEqualTo(environment)
    }

    @Test
    @Suppress("LongParameterList")
    fun `M decode all properties W fromEncoded`(
        @StringForgery clientToken: String,
        @StringForgery environment: String,
        @StringForgery service: String,
        @StringForgery additionalKey: String,
        @StringForgery additionalValue: String,
    ) {
        // GIVEN
        val encoded = mapOf(
            "clientToken" to clientToken,
            "env" to environment,
            "nativeCrashReportEnabled" to true,
            "service" to service,
            "site" to "DatadogSite.us3",
            "batchSize" to "BatchSize.small",
            "uploadFrequency" to "UploadFrequency.frequent",
            "batchProcessingLevel" to "BatchProcessingLevel.low",
            "additionalConfig" to mapOf<String, Any?>(
                additionalKey to additionalValue
            )
        )

        // WHEN
        val config = plugin.configurationBuilderFromEncoded(encoded)!!.build()

        // THEN
        val coreConfig: Any = config.getFieldValue("coreConfig")
        assertThat(config.getPrivate("crashReportsEnabled")).isEqualTo(true)
        assertThat(coreConfig.getPrivate("site")).isEqualTo(DatadogSite.US3)
        assertThat(coreConfig.getPrivate("batchSize")).isEqualTo(BatchSize.SMALL)
        assertThat(coreConfig.getPrivate("batchProcessingLevel")).isEqualTo(BatchProcessingLevel.LOW)
        assertThat(config.getPrivate("service")).isEqualTo(service)
        assertThat(config.getPrivate("additionalConfig")).isEqualTo(mapOf(
            additionalKey to additionalValue
        ))
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
                "trackingConsent" to "TrackingConsent.granted",
                "configuration" to mapOf(
                    "clientToken" to clientToken,
                    "env" to environment,
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
                "trackingConsent" to "TrackingConsent.granted",
                "configuration" to mapOf(
                    "clientToken" to clientToken,
                    "env" to environment,
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
                "trackingConsent" to "TrackingConsent.granted",
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
                "trackingConsent" to "TrackingConsent.granted",
                "configuration" to mapOf(
                    "clientToken" to forge.anAlphaNumericalString(),
                    "env" to forge.anAlphabeticalString(),
                    "trackingConsent" to "TrackingConsent.granted",
                    "nativeCrashReportEnabled" to true,
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
                "trackingConsent" to "TrackingConsent.granted",
                "configuration" to mapOf(
                    "clientToken" to forge.anAlphaNumericalString(),
                    "env" to forge.anAlphabeticalString(),
                    "trackingConsent" to "TrackingConsent.granted",
                    "nativeCrashReportEnabled" to true,
                )
            )
        )
        val mockResultB = mock<MethodChannel.Result>()
        plugin.onMethodCall(methodCallB, mockResultB)

        // THEN
        io.mockk.verify(exactly = 1) { Log.e(DATADOG_FLUTTER_TAG, MESSAGE_INVALID_REINITIALIZATION) }
    }

//    @Test
//    fun `M issue warning W attachToExisting has no existing instance`() {
//        // GIVEN
//        val methodCall = MethodCall(
//            "attachToExisting",
//            mapOf<String, Any?>()
//        )
//        val mockResult = mock<MethodChannel.Result>()
//        mockkStatic(Log::class)
//
//        // WHEN
//        plugin.onMethodCall(methodCall, mockResult)
//
//        // THEN
//        io.mockk.verify(exactly = 1) { Log.e(DATADOG_FLUTTER_TAG, MESSAGE_NO_EXISTING_INSTANCE) }
//        verify(mockResult).success(null)
//    }

//    @Test
//    fun `M return {rumEnabled false} W attachToExisting with rum not initialized`(
//        forge: Forge
//    ) {
//        // GIVEN
//        Datadog.setVerbosity(Log.INFO)
//        val mockCredentials = Credentials(
//            clientToken = forge.anAlphaNumericalString(),
//            envName = forge.anAlphaNumericalString(),
//            variant = forge.anAlphaNumericalString(),
//            rumApplicationId = forge.anAlphaNumericalString(),
//            serviceName = null
//        )
//        val datadogConfig = Configuration.Builder(
//            logsEnabled = true,
//            tracesEnabled = false,
//            crashReportsEnabled = false,
//            rumEnabled = false,
//        ).build()
//        Datadog.initialize(mockContext, mockCredentials, datadogConfig, TrackingConsent.GRANTED)
//
//        val methodCall = MethodCall(
//            "attachToExisting",
//            mapOf<String, Any?>()
//        )
//        val mockResult = mock<MethodChannel.Result>()
//
//        // WHEN
//        plugin.onMethodCall(methodCall, mockResult)
//
//        // THEN
//        verify(mockResult).success(argThat {
//            var rumEnabled = false
//            val map = this as? Map<*, *>
//            map?.let {
//                rumEnabled = (map["rumEnabled"] as? Boolean) ?: false
//            }
//            !rumEnabled
//        })
//    }
//
//    @Test
//    @Disabled("There's an issue calling Choreographer in RUM vital initialization")
//    fun `M return {rumEnabled true} W attachToExisting with rum initialized`(
//        forge: Forge
//    ) {
//        // GIVEN
//        Datadog.setVerbosity(Log.INFO)
//        val mockCredentials = Credentials(
//            forge.anAlphaNumericalString(),
//            forge.anAlphaNumericalString(),
//            forge.anAlphaNumericalString(),
//            forge.anAlphaNumericalString(),
//            null
//        )
//        val datadogConfig = Configuration.Builder(
//            logsEnabled = true,
//            tracesEnabled = false,
//            crashReportsEnabled = false,
//            rumEnabled = true,
//        ).build()
//        Datadog.initialize(mockContext, mockCredentials, datadogConfig, TrackingConsent.GRANTED)
//
//        val monitor = RumMonitor.Builder().build()
//        GlobalRum.registerIfAbsent(monitor)
//
//        val methodCall = MethodCall(
//            "attachToExisting",
//            mapOf<String, Any?>()
//        )
//        val mockResult = mock<MethodChannel.Result>()
//
//        // WHEN
//        plugin.onMethodCall(methodCall, mockResult)
//
//        // THEN
//        verify(mockResult).success(argThat {
//            var correct = false
//            val map = this as? Map<*, *>
//            map?.let {
//                correct = (map["rumEnabled"] as? Boolean) ?: false
//            }
//            correct
//        })
//    }

    @Test
    fun `M set sdk verbosity W called through MethodChannel`(
        forge: Forge
    ) {
        // GIVEN
        val config = mapOf(
            "clientToken" to forge.aString(),
            "env" to forge.anAlphaNumericalString()
        )
        plugin.initialize(config, TrackingConsent.GRANTED)

        val methodCall = MethodCall(
            "setSdkVerbosity",
            mapOf( "value" to "CoreLoggerLevel.debug" )
        )
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        assertThat(Datadog.getVerbosity()).isEqualTo(Log.DEBUG)
        verify(mockResult).success(null)
    }

    @Test
    fun `M set tracking consent W called through MethodChannel`(
        forge: Forge
    ) {
        // GIVEN
        val config = mapOf(
            "clientToken" to forge.aString(),
            "env" to forge.anAlphaNumericalString()
        )
        plugin.initialize(config, TrackingConsent.PENDING)

        val methodCall = MethodCall(
            "setTrackingConsent",
            mapOf( "value" to "TrackingConsent.notGranted" )
        )
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        val core = Datadog.getInstance()
        val coreFeature: Any = core.getPrivate("coreFeature")!!
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
        val config = mapOf(
            "clientToken" to forge.aString(),
            "env" to forge.anAlphaNumericalString()
        )
        plugin.initialize(config, TrackingConsent.GRANTED)

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
        val core = Datadog.getInstance()
        val coreFeature: Any = core.getPrivate("coreFeature")!!
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
        val config = mapOf(
            "clientToken" to forge.aString(),
            "env" to forge.anAlphaNumericalString()
        )
        plugin.initialize(config, TrackingConsent.GRANTED)

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
        val core = Datadog.getInstance()
        val coreFeature: Any = core.getPrivate("coreFeature")!!
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
        val config = mapOf(
            "clientToken" to forge.aString(),
            "env" to forge.anAlphaNumericalString()
        )
        plugin.initialize(config, TrackingConsent.GRANTED)

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
        val core = Datadog.getInstance()
        val coreFeature: Any = core.getPrivate("coreFeature")!!
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
        val config = mapOf(
            "clientToken" to forge.aString(),
            "env" to forge.anAlphaNumericalString()
        )
        plugin.initialize(config, TrackingConsent.GRANTED)

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

@Suppress("EmptyCatchBlock")
fun Any.getPrivate(varName: String): Any? {
    var value: Any? = null
    try {
        val field = javaClass.getDeclaredField(varName)
        field.isAccessible = true
        value = field.get(this)
    } catch (_: NoSuchFieldException) {

    }

    return value
}