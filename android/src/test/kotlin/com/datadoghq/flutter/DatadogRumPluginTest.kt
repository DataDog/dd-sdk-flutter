package com.datadoghq.flutter

import assertk.assertThat
import assertk.assertions.isEqualTo
import com.datadog.android.rum.RumErrorSource
import com.datadog.android.rum.RumMonitor
import com.datadog.android.rum.RumResourceKind
import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.LongForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.*

@ExtendWith(ForgeExtension::class)
class DatadogRumPluginTest {
    private lateinit var plugin: DatadogRumPlugin
    private lateinit var mockRumMonitor: RumMonitor

    @BeforeEach
    fun beforeEach() {
        mockRumMonitor = mock()
        plugin = DatadogRumPlugin(mockRumMonitor)
    }

    @Test
    fun `M convert all http methods W parseRumHttpMethod`() {
        var get = parseRumHttpMethod("RumHttpMethod.get")
        var post = parseRumHttpMethod("RumHttpMethod.post")
        var head = parseRumHttpMethod("RumHttpMethod.head")
        var put = parseRumHttpMethod("RumHttpMethod.put")
        var delete = parseRumHttpMethod("RumHttpMethod.delete")
        var patch = parseRumHttpMethod("RumHttpMethod.patch")
        var unknown = parseRumHttpMethod("unknown")

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
        var document = parseRumResourceKind("RumResourceType.document")
        var image = parseRumResourceKind("RumResourceType.image")
        var xhr = parseRumResourceKind("RumResourceType.xhr")
        var beacon = parseRumResourceKind("RumResourceType.beacon")
        var css = parseRumResourceKind("RumResourceType.css")
        var fetch = parseRumResourceKind("RumResourceType.fetch")
        var font = parseRumResourceKind("RumResourceType.font")
        var js = parseRumResourceKind("RumResourceType.js")
        var media = parseRumResourceKind("RumResourceType.media")
        var other = parseRumResourceKind("RumResourceType.other")
        var native = parseRumResourceKind("RumResourceType.native")
        var unknown = parseRumResourceKind("uknowntype")

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
        var source = parseRumErrorSource("RumErrorSource.source")
        var network = parseRumErrorSource("RumErrorSource.network")
        var webview = parseRumErrorSource("RumErrorSource.webview")
        var console = parseRumErrorSource("RumErrorSource.console")
        var custom = parseRumErrorSource("RumErrorSource.custom")
        var unknown = parseRumErrorSource("unknown")

        assertThat(source).isEqualTo(RumErrorSource.SOURCE)
        assertThat(network).isEqualTo(RumErrorSource.NETWORK)
        assertThat(webview).isEqualTo(RumErrorSource.WEBVIEW)
        assertThat(console).isEqualTo(RumErrorSource.CONSOLE)
        assertThat(custom).isEqualTo(RumErrorSource.SOURCE)
        assertThat(unknown).isEqualTo(RumErrorSource.SOURCE)
    }

    @Test
    fun `M call notImplemented W unknown method is called`(
        @StringForgery methodName: String,
        @StringForgery argName: String,
        @StringForgery argValue: String
    ) {
        // GIVEN
        val call = MethodCall(methodName, mapOf(argName to argValue))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verifyNoInteractions(mockRumMonitor)
        verify(mockResult).notImplemented()
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
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockRumMonitor).startView(viewKey, viewName, attributes)
        verify(mockResult).success(null)
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
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockRumMonitor).stopView(viewKey, attributes)
        verify(mockResult).success(null)
    }

    @Test
    fun `M call monitor addTiming W addTiming is called`(
        @StringForgery timingName: String,
    ) {
        // GIVEN
        val call = MethodCall("addTiming", mapOf(
            "name" to timingName
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockRumMonitor).addTiming(timingName)
        verify(mockResult).success(null)
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
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockRumMonitor).startResource(resourceKey, "GET",  url,
            mapOf(attributeKey to attributeValue)
        )
        verify(mockResult).success(null)
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
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockRumMonitor).stopResource(resourceKey, statusCode, size, RumResourceKind.IMAGE,
            mapOf(attributeKey to attributeValue))
        verify(mockResult).success(null)
    }

    @Test
    fun `M call monitor stopResourceWithError W stopResourceLoadingWithError is called`(
        @StringForgery resourceKey: String,
        @StringForgery message: String,
        @StringForgery attributeKey: String,
        @StringForgery attributeValue: String
    ) {
        // GIVEN
        val call = MethodCall("stopResourceLoadingWithError", mapOf(
            "key" to resourceKey,
            "message" to message,
            "attributes" to mapOf(
                attributeKey to attributeValue
            )
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockRumMonitor).stopResourceWithError(eq(resourceKey), isNull(), eq(message),
            eq(RumErrorSource.NETWORK), any(), eq(mapOf(attributeKey to attributeValue)))
        verify(mockResult).success(null)
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
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockRumMonitor).addErrorWithStacktrace(message, RumErrorSource.NETWORK,
            stackTrace, mapOf(attributeKey to attributeValue))
        verify(mockResult).success(null)
    }
}