/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import fr.xgouchet.elmyr.junit5.ForgeExtension
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.mock
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.eq
import org.mockito.kotlin.verify

@ExtendWith(ForgeExtension::class)
class DatadogLogsPluginTest {
    private lateinit var plugin: DatadogLogsPlugin

    @BeforeEach
    fun beforeEach() {
        plugin = DatadogLogsPlugin()
    }

    @Test
    fun `M report a contract violation W onMethodCall(log) is missing parameters`(
        forge: Forge,
        @StringForgery message: String
    ) {
        // GIVEN
        val method = forge.anElementFrom( listOf("debug", "info", "warn", "error") )
        val call = MethodCall(method, mapOf(
            "message" to message
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W onMethodCall(log) parameter is of wrong type`(
        forge: Forge,
        @IntForgery message: Int
    ) {
        // GIVEN
        val method = forge.anElementFrom( listOf("debug", "info", "warn", "error") )
        val call = MethodCall(method, mapOf(
            "message" to Int,
            "context" to mapOf<String, Any>()
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W addAttribute is missing parameters`(
        @StringForgery key: String
    ) {
        // GIVEN
        val call = MethodCall("addAttribute", mapOf(
            "key" to key
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W addAttribute is wrong type`(
        @IntForgery key: Int,
        @StringForgery value: String
    ) {
        // GIVEN
        val call = MethodCall("addAttribute", mapOf(
            "key" to key,
            "value" to value
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W addTag is missing parameters`() {
        // GIVEN
        val call = MethodCall("addTag", mapOf<String, Any>())
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W removeAttribute is missing parameters`() {
        // GIVEN
        val call = MethodCall("removeAttribute", mapOf<String, Any>())
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W removeTag is missing parameters`() {
        // GIVEN
        val call = MethodCall("removeTag", mapOf<String, Any>())
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W removeTagWithKey is missing parameters`() {
        // GIVEN
        val call = MethodCall("removeTag", mapOf<String, Any>())
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }
}