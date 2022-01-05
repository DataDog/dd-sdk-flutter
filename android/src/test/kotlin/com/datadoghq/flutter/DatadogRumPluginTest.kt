package com.datadoghq.flutter

import com.datadog.android.rum.RumMonitor
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoInteractions

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
}