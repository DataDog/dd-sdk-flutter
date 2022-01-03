package com.datadoghq.flutter

import com.datadog.android.rum.RumMonitor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify

class DatadogRumPluginTest {
    private lateinit var plugin: DatadogRumPlugin
    private lateinit var mockRumMonitor: RumMonitor

    @BeforeEach
    fun beforeEach() {
        mockRumMonitor = mock()
        plugin = DatadogRumPlugin(mockRumMonitor)
    }

    @Test
    fun `M call monitor startView W startView is called`() {
        // GIVEN
        val attributes = mapOf<String, Any?>(
            "my_attribute" to "attribute_value"
        )
        val call = MethodCall("startView", mapOf<String, Any?>(
            "key" to "view_key",
            "name" to "view_name",
            "attributes" to attributes
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockRumMonitor).startView("view_key", "view_name", attributes)
        verify(mockResult).success(null)
    }

    @Test
    fun `M call monitor stopView W stopView is called`() {
        // GIVEN
        val attributes = mapOf<String, Any?>(
            "my_attribute" to "attribute_value"
        )
        val call = MethodCall("stopView", mapOf<String, Any?>(
            "key" to "view_key",
            "attributes" to attributes
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockRumMonitor).stopView("view_key", attributes)
        verify(mockResult).success(null)
    }

    @Test
    fun `M call monitor addTiming W addTiming is called`() {
        // GIVEN
        val call = MethodCall("addTiming", mapOf<String, Any?>(
            "name" to "timing_name"
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockRumMonitor).addTiming("timing_name")
        verify(mockResult).success(null)
    }
}