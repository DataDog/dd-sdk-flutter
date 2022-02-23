/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.opentracing.Tracer
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.junit.jupiter.api.extension.Extensions
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.Answers
import org.mockito.Mock
import org.mockito.kotlin.any
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify

@Extensions(
    ExtendWith(ForgeExtension::class),
    ExtendWith(MockitoExtension::class))
class DatadogTracesPluginTest {
    @Mock(answer = Answers.RETURNS_DEEP_STUBS)
    private lateinit var mockTracer: Tracer
    private lateinit var plugin: DatadogTracesPlugin

    @BeforeEach
    fun beforeEach() {
        plugin = DatadogTracesPlugin(mockTracer)
    }

    @Test
    fun `M report a contract violation W startRootSpan is missing parameters`() {
        // GIVEN
        val call = MethodCall("startRootSpan", mapOf<String, Any>())
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W startRootSpan has bad operation name`(
        @IntForgery operationName: Int
    ) {
        // GIVEN
        val call = MethodCall("startRootSpan", mapOf<String, Any>(
            "operationName" to operationName
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W startRootSpan has bad start time`(
        @StringForgery operationName: String,
        @StringForgery startTime: String
    ) {
        // GIVEN
        val call = MethodCall("startRootSpan", mapOf<String, Any>(
            "operationName" to operationName,
            "startTime" to startTime
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W startSpan is missing parameters`() {
        // GIVEN
        val call = MethodCall("startSpan", mapOf<String, Any>())
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W startSpan has bad operation name`(
        @IntForgery operationName: Int
    ) {
        // GIVEN
        val call = MethodCall("startSpan", mapOf<String, Any>(
            "operationName" to operationName
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    private fun createSpan(operationName: String): Long {
        val call = MethodCall("startRootSpan", mapOf<String, Any>(
            "operationName" to operationName
        ))
        val mockResult = mock<MethodChannel.Result>()
        val captor = argumentCaptor<Long>()
        plugin.onMethodCall(call, mockResult)

        verify(mockResult).success(captor.capture())
        return captor.firstValue
    }

    @Test
    fun `M report a contract violation W span setError has missing kind`(
        @StringForgery operationName: String,
        @StringForgery message: String
    ) {
        // GIVEN
        val spanId = createSpan(operationName)
        val call = MethodCall("span.setError", mapOf<String, Any>(
            "spanHandle" to spanId,
            "message" to message
        ))

        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W span setTag has missing key`(
        @StringForgery operationName: String
    ) {
        // GIVEN
        val spanId = createSpan(operationName)
        val call = MethodCall("span.setTag", mapOf<String, Any>(
            "spanHandle" to spanId
        ))

        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W span setBaggageItem has missing key`(
        @StringForgery operationName: String,
        @StringForgery value: String
    ) {
        // GIVEN
        val spanId = createSpan(operationName)
        val call = MethodCall("span.setBaggageItem", mapOf<String, Any>(
            "spanHandle" to spanId,
            "value" to value
        ))

        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }

    @Test
    fun `M report a contract violation W span log has missing fields`(
        @StringForgery operationName: String,
    ) {
        // GIVEN
        val spanId = createSpan(operationName)
        val call = MethodCall("span.log", mapOf<String, Any>(
            "spanHandle" to spanId
        ))

        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
    }
}