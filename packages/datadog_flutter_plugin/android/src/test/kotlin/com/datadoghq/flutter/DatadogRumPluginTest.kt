/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.util.Log
import assertk.assertThat
import assertk.assertions.isEqualTo
import com.datadog.android.Datadog
import com.datadog.android.log.Logs
import com.datadog.android.log.LogsConfiguration
import com.datadog.android.rum.Rum
import com.datadog.android.rum.RumActionType
import com.datadog.android.rum.RumConfiguration
import com.datadog.android.rum.RumErrorSource
import com.datadog.android.rum.RumMonitor
import com.datadog.android.rum.RumPerformanceMetric
import com.datadog.android.rum.RumResourceKind
import com.datadog.android.rum._RumInternalProxy
import com.datadog.android.rum.configuration.VitalsUpdateFrequency
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.annotation.BoolForgery
import fr.xgouchet.elmyr.annotation.FloatForgery
import fr.xgouchet.elmyr.annotation.Forgery
import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.LongForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.Called
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import io.mockk.verify
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.mock
import java.util.concurrent.TimeUnit

@ExtendWith(ForgeExtension::class)
@Suppress("LargeClass")
class DatadogRumPluginTest {
    private lateinit var plugin: DatadogRumPlugin
    private lateinit var monitorProxy: MockRumMonitor

    @BeforeEach
    fun beforeEach() {
        monitorProxy = MockRumMonitor()
        plugin = DatadogRumPlugin()
        plugin.rum = monitorProxy
    }

    @AfterEach
    fun afterEach() {
        Datadog.stopInstance()
        DatadogRumPlugin.resetConfig();
        unmockkStatic(Log::class)
        unmockkStatic(Rum::class)
    }

    @Test
    fun `M parse all VitalsFrequency W parseVitalsFrequency`() {
        val never = parseVitalsFrequency("VitalsFrequency.never")
        val rare = parseVitalsFrequency("VitalsFrequency.rare")
        val average = parseVitalsFrequency("VitalsFrequency.average")
        val frequent = parseVitalsFrequency("VitalsFrequency.frequent")
        val unknown = parseVitalsFrequency("unknown")

        assertThat(never).isEqualTo(VitalsUpdateFrequency.NEVER)
        assertThat(rare).isEqualTo(VitalsUpdateFrequency.RARE)
        assertThat(average).isEqualTo(VitalsUpdateFrequency.AVERAGE)
        assertThat(frequent).isEqualTo(VitalsUpdateFrequency.FREQUENT)
        assertThat(unknown).isEqualTo(VitalsUpdateFrequency.AVERAGE)
    }

    @Test
    fun `M convert all http methods W parseRumHttpMethod`() {
        val get = parseRumHttpMethod("RumHttpMethod.get")
        val post = parseRumHttpMethod("RumHttpMethod.post")
        val head = parseRumHttpMethod("RumHttpMethod.head")
        val put = parseRumHttpMethod("RumHttpMethod.put")
        val delete = parseRumHttpMethod("RumHttpMethod.delete")
        val patch = parseRumHttpMethod("RumHttpMethod.patch")
        val unknown = parseRumHttpMethod("unknown")

        assertThat(get).isEqualTo("GET")
        assertThat(post).isEqualTo("POST")
        assertThat(head).isEqualTo("HEAD")
        assertThat(put).isEqualTo("PUT")
        assertThat(delete).isEqualTo("DELETE")
        assertThat(patch).isEqualTo("PATCH")
        assertThat(unknown).isEqualTo("GET")
    }

    @Test
    fun `M convert all resource kinds W parseRumResourceKind`() {
        val document = parseRumResourceKind("RumResourceType.document")
        val image = parseRumResourceKind("RumResourceType.image")
        val xhr = parseRumResourceKind("RumResourceType.xhr")
        val beacon = parseRumResourceKind("RumResourceType.beacon")
        val css = parseRumResourceKind("RumResourceType.css")
        val fetch = parseRumResourceKind("RumResourceType.fetch")
        val font = parseRumResourceKind("RumResourceType.font")
        val js = parseRumResourceKind("RumResourceType.js")
        val media = parseRumResourceKind("RumResourceType.media")
        val other = parseRumResourceKind("RumResourceType.other")
        val native = parseRumResourceKind("RumResourceType.native")
        val unknown = parseRumResourceKind("unknownType")

        assertThat(document).isEqualTo(RumResourceKind.DOCUMENT)
        assertThat(image).isEqualTo(RumResourceKind.IMAGE)
        assertThat(xhr).isEqualTo(RumResourceKind.XHR)
        assertThat(beacon).isEqualTo(RumResourceKind.BEACON)
        assertThat(css).isEqualTo(RumResourceKind.CSS)
        assertThat(fetch).isEqualTo(RumResourceKind.FETCH)
        assertThat(font).isEqualTo(RumResourceKind.FONT)
        assertThat(js).isEqualTo(RumResourceKind.JS)
        assertThat(media).isEqualTo(RumResourceKind.MEDIA)
        assertThat(other).isEqualTo(RumResourceKind.OTHER)
        assertThat(native).isEqualTo(RumResourceKind.NATIVE)
        assertThat(unknown).isEqualTo(RumResourceKind.OTHER)
    }

    @Test
    fun `M convert all error sources W parseRumErrorSource`() {
        val source = parseRumErrorSource("RumErrorSource.source")
        val network = parseRumErrorSource("RumErrorSource.network")
        val webview = parseRumErrorSource("RumErrorSource.webview")
        val console = parseRumErrorSource("RumErrorSource.console")
        val custom = parseRumErrorSource("RumErrorSource.custom")
        val unknown = parseRumErrorSource("unknown")

        assertThat(source).isEqualTo(RumErrorSource.SOURCE)
        assertThat(network).isEqualTo(RumErrorSource.NETWORK)
        assertThat(webview).isEqualTo(RumErrorSource.WEBVIEW)
        assertThat(console).isEqualTo(RumErrorSource.CONSOLE)
        assertThat(custom).isEqualTo(RumErrorSource.SOURCE)
        assertThat(unknown).isEqualTo(RumErrorSource.SOURCE)
    }

    @Test
    fun `M convert all action types W parseRumActionType`() {
        val tap = parseRumActionType(("RumActionType.tap"))
        val scroll = parseRumActionType("RumActionType.scroll")
        val swipe = parseRumActionType("RumActionType.swipe")
        val custom = parseRumActionType("RumActionType.custom")
        val unknown = parseRumActionType("unknown")

        assertThat(tap).isEqualTo(RumActionType.TAP)
        assertThat(scroll).isEqualTo(RumActionType.SCROLL)
        assertThat(swipe).isEqualTo(RumActionType.SWIPE)
        assertThat(custom).isEqualTo(RumActionType.CUSTOM)
        assertThat(unknown).isEqualTo(RumActionType.CUSTOM)
    }

    @Suppress("LongParameterList")
    @Test
    fun `M decode configuration W withEncoded is called`(
        @FloatForgery(min = 0.0f, max = 100.0f) sessionSampleRate: Float,
        @FloatForgery(min = 0.1f, max = 5.0f) longTaskThreshold: Float,
        @BoolForgery trackFrustration: Boolean,
        @StringForgery endpoint: String,
        @FloatForgery(min = 0.0f, max = 100.0f) telemetrySampleRate: Float,
        forge: Forge
    ) {
        // GIVEN
        val trackNonFatalAnrs = forge.aNullable { forge.aBool() }
        val attributes = forge.exhaustiveAttributes()
        val configArg = mapOf(
            "sessionSampleRate" to sessionSampleRate,
            "longTaskThreshold" to longTaskThreshold,
            "trackFrustrations" to trackFrustration,
            "trackNonFatalAnrs" to trackNonFatalAnrs,
            "customEndpoint" to endpoint,
            "vitalsUpdateFrequency" to "VitalsFrequency.frequent",
            "telemetrySampleRate" to telemetrySampleRate,
            "additionalConfig" to attributes
        )

        // WHEN
        val config = RumConfiguration.Builder(forge.aString())
            .withEncoded(configArg)
            .build()

        // THEN
        val featureConfiguration: Any = config.getFieldValue("featureConfiguration")
        assertThat(featureConfiguration.getPrivate("sampleRate")).isEqualTo(sessionSampleRate)
        assertThat(featureConfiguration.getPrivate("trackFrustrations")).isEqualTo(trackFrustration)
        if (trackNonFatalAnrs != null) {
            assertThat(featureConfiguration.getPrivate("trackNonFatalAnrs")).isEqualTo(trackNonFatalAnrs)
        } else {
            // If null, default shouldn't be changed. Tests are run on a version that enables ANR tracking by default
            assertThat(featureConfiguration.getPrivate("trackNonFatalAnrs")).isEqualTo(true)
        }
        assertThat(featureConfiguration.getPrivate("customEndpointUrl")).isEqualTo(endpoint)
        assertThat(featureConfiguration.getPrivate("vitalsMonitorUpdateFrequency"))
            .isEqualTo(VitalsUpdateFrequency.FREQUENT)
        assertThat(featureConfiguration.getPrivate("additionalConfig")).isEqualTo(attributes)
    }

    @Test
    fun `M return invalidOperation W method called { !enabled }`() {
        //GIVEN
        val plugin = DatadogRumPlugin()
        val call = MethodCall(
            "startView",
            mapOf(
                "key" to "fake_key",
                "name" to "FakeName",
                "attributes" to mapOf<String, Any?>()
            )
        )
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.invalidOperation(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { mockResult.invalidOperation(any()) }
    }

    @Test
    fun `M call Rum enable with correct config W method channel sends enable`(
        forge: Forge
    ) {
        // GIVEN
        mockkStatic(Rum::class)
        val applicationId = forge.aString()
        val config = mapOf(
            "applicationId" to applicationId,
            "trackFrustrations" to true,
            "vitalsUpdateFrequency" to "VitalsFrequency.frequent",
            "telemetrySampleRate" to 100.0f,
        )
        val methodCall = MethodCall(
            "enable",
            mapOf(
                "configuration" to config
            )
        )

        // WHEN
        val mockResult = mock<MethodChannel.Result>()
        plugin.onMethodCall(methodCall, mockResult)

        // THEN
        io.mockk.verify {
            // Would like to check the specific configuration, but there are too many
            // internal variables
            Rum.enable(any())
        }
    }

    @Test
    fun `M not issue warning W enable called with same configuration`(
        forge: Forge
    ) {
        // GIVEN
        mockkStatic(Log::class)
        Datadog.setVerbosity(Log.INFO)

        val applicationId = forge.aString()
        val config = mapOf(
            "applicationId" to applicationId,
            "trackFrustrations" to true,
            "vitalsUpdateFrequency" to "VitalsFrequency.frequent",
            "telemetrySampleRate" to 100.0f,
        )
        val methodCall = MethodCall(
            "enable",
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
    fun `M issue warning W enable called with different configuration`(
        forge: Forge
    ) {
        // GIVEN
        mockkStatic(Log::class)
        Datadog.setVerbosity(Log.INFO)

        val applicationId = forge.aString()
        val config = mapOf(
            "applicationId" to applicationId,
            "trackFrustrations" to true,
            "vitalsUpdateFrequency" to "VitalsFrequency.frequent",
            "telemetrySampleRate" to 100.0f,
        )
        val methodCall = MethodCall(
            "enable",
            mapOf(
                "configuration" to config
            )
        )
        val mockResult = mock<MethodChannel.Result>()
        plugin.onMethodCall(methodCall, mockResult)

        // WHEN
        val methodCallB = MethodCall(
            "enable",
            mapOf(
                "configuration" to mapOf(
                    "applicationId" to applicationId,
                    "trackFrustrations" to true,
                    "vitalsUpdateFrequency" to "VitalsFrequency.rare",
                    "telemetrySampleRate" to 25.0f,
                )
            )
        )
        val mockResultB = mock<MethodChannel.Result>()
        plugin.onMethodCall(methodCallB, mockResultB)

        // THEN
        io.mockk.verify(exactly = 1) {
            Log.e(DATADOG_FLUTTER_TAG, MESSAGE_INVALID_RUM_REINITIALIZATION)
        }
    }

    @Test
    fun `M call notImplemented W unknown method is called`(
        @StringForgery methodName: String,
        @StringForgery argName: String,
        @StringForgery argValue: String
    ) {
        // GIVEN
        val call = MethodCall(methodName, mapOf(argName to argValue))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.notImplemented() } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor wasNot Called }
        verify { mockResult.notImplemented() }
    }

    @Test
    fun `M call monitor startView W startView is called`(
        @StringForgery viewKey: String,
        @StringForgery viewName: String,
        @StringForgery viewAttribute: String,
        @StringForgery attributeValue: String,
    ) {
        // GIVEN
        val attributes = mapOf<String, Any?>(
            viewAttribute to attributeValue
        )
        val call = MethodCall("startView", mapOf(
            "key" to viewKey,
            "name" to viewName,
            "attributes" to attributes
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor.startView(viewKey, viewName, attributes) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M report contract violation W bad parameter`(
        @StringForgery key: String,
        @IntForgery name: Int
    ) {
        // GIVEN
        val call = MethodCall("startView", mapOf(
            "key" to key,
            "name" to name,
            "attributes" to mapOf<String, Any?>()
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.error(any(), any(), any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { mockResult.error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), any()) }
    }

    @Test
    fun `M call monitor stopView W stopView is called`(
        @StringForgery viewKey: String,
        @StringForgery viewAttribute: String,
        @StringForgery attributeValue: String,
    ) {
        // GIVEN
        val attributes = mapOf<String, Any?>(
            viewAttribute to attributeValue
        )
        val call = MethodCall("stopView", mapOf(
            "key" to viewKey,
            "attributes" to attributes
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor.stopView(viewKey, attributes) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor addTiming W addTiming is called`(
        @StringForgery timingName: String,
    ) {
        // GIVEN
        val call = MethodCall("addTiming", mapOf(
            "name" to timingName
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor.addTiming(timingName) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor addViewLoadingTime W addViewLoadingTime is called`(
        @BoolForgery overwrite: Boolean
    ) {
        // GIVEN
        val call = MethodCall("addViewLoadingTime", mapOf(
            "overwrite" to overwrite
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor.addViewLoadingTime(overwrite) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor startResource W startResource is called`(
        @StringForgery resourceKey: String,
        @StringForgery url: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("startResource", mapOf(
            "key" to resourceKey,
            "url" to url,
            "httpMethod" to "RumHttpMethod.get",
            "attributes" to mapOf(
                attributeKey to attributeValue
            )
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor.startResource(resourceKey, "GET",  url,
            mapOf(attributeKey to attributeValue)
        ) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor stopResource W stopResource is called`(
        @StringForgery resourceKey: String,
        @IntForgery statusCode: Int,
        @LongForgery size: Long,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("stopResource", mapOf(
            "key" to resourceKey,
            "kind" to "RumResourceType.image",
            "statusCode" to statusCode,
            "size" to size,
            "attributes" to mapOf(
                attributeKey to attributeValue
            )
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor.stopResource(resourceKey, statusCode, size, RumResourceKind.IMAGE,
            mapOf(attributeKey to attributeValue)) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor stopResourceWithError W stopResourceWithError is called`(
        @StringForgery resourceKey: String,
        @StringForgery message: String,
        @StringForgery errorType: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("stopResourceWithError", mapOf(
            "key" to resourceKey,
            "message" to message,
            "type" to errorType,
            "attributes" to mapOf(
                attributeKey to attributeValue
            )
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor.stopResourceWithError(eq(resourceKey), isNull(), eq(message),
            eq(RumErrorSource.NETWORK), eq(""), eq(errorType),
            eq(mapOf(attributeKey to attributeValue))) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor addError W addError is called`(
        @StringForgery message: String,
        @StringForgery stackTrace: String,
        @StringForgery errorType: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("addError", mapOf(
            "message" to message,
            "source" to "RumErrorSource.network",
            "stackTrace" to stackTrace,
            "errorType" to errorType,
            "attributes" to mapOf(
                attributeKey to attributeValue
            )
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor.addErrorWithStacktrace(message, RumErrorSource.NETWORK,
            stackTrace, mapOf(
                attributeKey to attributeValue,
                "_dd.error_type" to errorType
            )) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor addAction W addAction is called`(
        @StringForgery name: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("addAction", mapOf(
            "type" to "RumActionType.tap",
            "name" to name,
            "attributes" to mapOf(
                attributeKey to attributeValue
            )
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor.addAction(RumActionType.TAP, name, mapOf(
            attributeKey to attributeValue
        )) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor startAction W startAction is called`(
        @StringForgery name: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("startAction", mapOf(
            "type" to "RumActionType.scroll",
            "name" to name,
            "attributes" to mapOf(
                attributeKey to attributeValue
            )
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor.startAction(RumActionType.SCROLL, name, mapOf(
            attributeKey to attributeValue
        )) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor stopAction W stopAction is called`(
        @StringForgery name: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("stopAction", mapOf(
            "type" to "RumActionType.swipe",
            "name" to name,
            "attributes" to mapOf(
                attributeKey to attributeValue
            )
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { monitorProxy.mockMonitor.stopAction(RumActionType.SWIPE, name, mapOf(
            attributeKey to attributeValue
        )) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call internal addLongTask W reportLongTask is called`(
        @LongForgery at: Long,
        @IntForgery duration: Int
    ) {
        // GIVEN
        val call = MethodCall("reportLongTask", mapOf(
            "at" to at,
            "duration" to duration
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        val durationNs = TimeUnit.MILLISECONDS.toNanos(duration.toLong())
        verify { monitorProxy.mockInternalProxy.addLongTask(durationNs, "") }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call internal updatePerformanceMetrics W updatePerformanceMetrics is called`(
        forge: Forge,
    ) {
        // GIVEN
        val buildTimes = forge.aList { forge.aDouble() }
        val rasterTimes = forge.aList { forge.aDouble() }
        val call = MethodCall( "updatePerformanceMetrics", mapOf(
            "buildTimes" to buildTimes,
            "rasterTimes" to rasterTimes,
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        for (raster in rasterTimes) {
            verify { monitorProxy.mockInternalProxy.updatePerformanceMetric(RumPerformanceMetric.FLUTTER_RASTER_TIME, raster) }
        }
        for (build in buildTimes) {
            verify { monitorProxy.mockInternalProxy.updatePerformanceMetric(RumPerformanceMetric.FLUTTER_BUILD_TIME, build) }
        }
        verify { mockResult.success(null) }
    }

    private val contracts = listOf(
        Contract("startView", mapOf(
            "key" to ContractParameter.Type(SupportedContractType.STRING),
            "name" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("stopView", mapOf(
            "key" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("addTiming", mapOf(
            "name" to ContractParameter.Type(SupportedContractType.STRING),
        )),
        Contract("addViewLoadingTime", mapOf(
            "overwrite" to ContractParameter.Type(SupportedContractType.BOOL),
        )),
        Contract("startResource", mapOf(
            "key" to ContractParameter.Type(SupportedContractType.STRING),
            "url" to ContractParameter.Type(SupportedContractType.STRING),
            "httpMethod" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("stopResource", mapOf(
            "key" to ContractParameter.Type(SupportedContractType.STRING),
            "kind" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("stopResourceWithError", mapOf(
            "key" to ContractParameter.Type(SupportedContractType.STRING),
            "message" to ContractParameter.Type(SupportedContractType.STRING),
            "type" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("addError", mapOf(
            "message" to ContractParameter.Type(SupportedContractType.STRING),
            "source" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("addAction", mapOf(
            "type" to ContractParameter.Type(SupportedContractType.STRING),
            "name" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("startAction", mapOf(
            "type" to ContractParameter.Type(SupportedContractType.STRING),
            "name" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("stopAction", mapOf(
            "type" to ContractParameter.Type(SupportedContractType.STRING),
            "name" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("addAttribute", mapOf(
            "key" to ContractParameter.Type(SupportedContractType.STRING),
            "value" to ContractParameter.Type(SupportedContractType.STRING),
        )),
        Contract("removeAttribute", mapOf(
            "key" to ContractParameter.Type(SupportedContractType.STRING)
        )),
        Contract("reportLongTask", mapOf(
            "at" to ContractParameter.Type(SupportedContractType.LONG),
            "duration" to ContractParameter.Type(SupportedContractType.INT)
        )),
        Contract("updatePerformanceMetrics", mapOf(
            "buildTimes" to ContractParameter.Type(SupportedContractType.LIST),
            "rasterTimes" to ContractParameter.Type(SupportedContractType.LIST),
        )),
        Contract("addFeatureFlagEvaluation", mapOf(
            "name" to ContractParameter.Type(SupportedContractType.STRING),
            "value" to ContractParameter.Type(SupportedContractType.ANY),
        )),
        Contract("stopSession", mapOf())
    )

    @Test
    fun `M report contract violation W missing parameters in contract`(
        forge: Forge
    ) {
        testContracts(contracts, forge, plugin)
    }
}