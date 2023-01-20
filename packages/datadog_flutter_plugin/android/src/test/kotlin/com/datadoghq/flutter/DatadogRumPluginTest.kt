/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import assertk.assertThat
import assertk.assertions.isEqualTo
import com.datadog.android.rum.RumActionType
import com.datadog.android.rum.RumErrorSource
import com.datadog.android.rum.RumMonitor
import com.datadog.android.rum.RumPerformanceMetric
import com.datadog.android.rum.RumResourceKind
import com.datadog.android.rum._RumInternalProxy
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.LongForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.Called
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import java.util.concurrent.TimeUnit

@ExtendWith(ForgeExtension::class)
@OptIn(kotlin.ExperimentalStdlibApi::class)
class DatadogRumPluginTest {
    private lateinit var plugin: DatadogRumPlugin
    private lateinit var mockRumMonitor: RumMonitor
    private lateinit var mockRumProxy: _RumInternalProxy

    @BeforeEach
    fun beforeEach() {
        mockRumMonitor = mockk(relaxed = true)
        mockRumProxy = mockk(relaxed = true)
        every { mockRumMonitor._getInternal() } returns mockRumProxy
        plugin = DatadogRumPlugin(mockRumMonitor)
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
        val unknown = parseRumResourceKind("uknowntype")

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
        val tap = parseRumActionType(("RumUserActionType.tap"))
        val scroll = parseRumActionType("RumUserActionType.scroll")
        val swipe = parseRumActionType("RumUserActionType.swipe")
        val custom = parseRumActionType("RumUserActionType.custom")
        val unknown = parseRumActionType("unknown")

        assertThat(tap).isEqualTo(RumActionType.TAP)
        assertThat(scroll).isEqualTo(RumActionType.SCROLL)
        assertThat(swipe).isEqualTo(RumActionType.SWIPE)
        assertThat(custom).isEqualTo(RumActionType.CUSTOM)
        assertThat(unknown).isEqualTo(RumActionType.CUSTOM)
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
        verify { mockRumMonitor wasNot Called }
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
        verify { mockRumMonitor.startView(viewKey, viewName, attributes) }
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
        verify { mockRumMonitor.stopView(viewKey, attributes) }
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
        verify { mockRumMonitor.addTiming(timingName) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor startResource W startResourceLoading is called`(
        @StringForgery resourceKey: String,
        @StringForgery url: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("startResourceLoading", mapOf(
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
        verify { mockRumMonitor.startResource(resourceKey, "GET",  url,
            mapOf(attributeKey to attributeValue)
        ) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor stopResource W stopResourceLoading is called`(
        @StringForgery resourceKey: String,
        @IntForgery statusCode: Int,
        @LongForgery size: Long,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("stopResourceLoading", mapOf(
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
        verify { mockRumMonitor.stopResource(resourceKey, statusCode, size, RumResourceKind.IMAGE,
            mapOf(attributeKey to attributeValue)) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor stopResourceWithError W stopResourceLoadingWithError is called`(
        @StringForgery resourceKey: String,
        @StringForgery message: String,
        @StringForgery errorType: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("stopResourceLoadingWithError", mapOf(
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
        verify { mockRumMonitor.stopResourceWithError(eq(resourceKey), isNull(), eq(message),
            eq(RumErrorSource.NETWORK), eq(""), eq(errorType),
            eq(mapOf(attributeKey to attributeValue))) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor addError W addError is called`(
        @StringForgery message: String,
        @StringForgery stackTrace: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("addError", mapOf(
            "message" to message,
            "source" to "RumErrorSource.network",
            "stackTrace" to stackTrace,
            "attributes" to mapOf(
                attributeKey to attributeValue
            )
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { mockRumMonitor.addErrorWithStacktrace(message, RumErrorSource.NETWORK,
            stackTrace, mapOf(attributeKey to attributeValue)) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor addUserAction W addUserAction is called`(
        @StringForgery name: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("addUserAction", mapOf(
            "type" to "RumUserActionType.tap",
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
        verify { mockRumMonitor.addUserAction(RumActionType.TAP, name, mapOf(
            attributeKey to attributeValue
        )) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor startUserAction W startUserAction is called`(
        @StringForgery name: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("startUserAction", mapOf(
            "type" to "RumUserActionType.scroll",
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
        verify { mockRumMonitor.startUserAction(RumActionType.SCROLL, name, mapOf(
            attributeKey to attributeValue
        )) }
        verify { mockResult.success(null) }
    }

    @Test
    fun `M call monitor stopUserAction W stopUserAction is called`(
        @StringForgery name: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("stopUserAction", mapOf(
            "type" to "RumUserActionType.swipe",
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
        verify { mockRumMonitor.stopUserAction(RumActionType.SWIPE, name, mapOf(
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
        verify { mockRumProxy.addLongTask(durationNs, "") }
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
            verify { mockRumProxy.updatePerformanceMetric(RumPerformanceMetric.FLUTTER_RASTER_TIME, raster) }
        }
        for (build in buildTimes) {
            verify { mockRumProxy.updatePerformanceMetric(RumPerformanceMetric.FLUTTER_BUILD_TIME, build) }
        }
        verify { mockResult.success(null) }
    }

    val contracts = listOf(
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
        Contract("startResourceLoading", mapOf(
            "key" to ContractParameter.Type(SupportedContractType.STRING),
            "url" to ContractParameter.Type(SupportedContractType.STRING),
            "httpMethod" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("stopResourceLoading", mapOf(
            "key" to ContractParameter.Type(SupportedContractType.STRING),
            "kind" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("stopResourceLoadingWithError", mapOf(
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
        Contract("addUserAction", mapOf(
            "type" to ContractParameter.Type(SupportedContractType.STRING),
            "name" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("startUserAction", mapOf(
            "type" to ContractParameter.Type(SupportedContractType.STRING),
            "name" to ContractParameter.Type(SupportedContractType.STRING),
            "attributes" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("stopUserAction", mapOf(
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
        ))
    )

    @Test
    fun `M report contract violation W missing parameters in contract`(
        forge: Forge
    ) {
        testContracts(contracts, forge, plugin)
    }
}