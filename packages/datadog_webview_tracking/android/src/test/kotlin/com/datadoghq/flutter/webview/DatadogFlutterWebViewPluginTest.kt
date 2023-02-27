/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2023-Present Datadog, Inc.
 */
package com.datadoghq.flutter.webview

import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

@ExtendWith(ForgeExtension::class)
class DatadogFlutterWebViewPluginTest {

    @Test
    fun `M report contract violation W missing parameter for initWebView { no hosts }`(
        forge: Forge
    ) {
        // GIVEN
        val plugin = DatadogFlutterWebViewPlugin()
        val call = MethodCall("initWebView", mapOf(
            "webViewIdentifier" to forge.anInt()
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.error(any(), any(), any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify {
            mockResult.error("DatadogSdk:ContractViolation", any(), any())
        }
    }

    @Test
    fun `M report contract violation W missing parameter for initWebView { no identifier }`(
        forge: Forge
    ) {
        // GIVEN
        val plugin = DatadogFlutterWebViewPlugin()
        val call = MethodCall("initWebView", mapOf(
            "allowedHosts" to listOf(forge.anAlphabeticalString())
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.error(any(), any(), any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify {
            mockResult.error("DatadogSdk:ContractViolation", any(), any())
        }
    }

    @Test
    fun `M report success W initWebView `(
        forge: Forge
    ) {
        // GIVEN
        val plugin = DatadogFlutterWebViewPlugin()
        val call = MethodCall("initWebView", mapOf(
            "webViewIdentifier" to forge.anInt(),
            "allowedHosts" to listOf(forge.anAlphabeticalString())
        ))
        val mockResult = mockk<MethodChannel.Result>()
        every { mockResult.success(any()) } returns Unit

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify {
            mockResult.success(null)
        }
    }
}