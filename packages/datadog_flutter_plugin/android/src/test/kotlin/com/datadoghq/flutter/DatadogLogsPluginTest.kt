/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import android.util.Log
import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isNotNull
import com.datadog.android.log.Logger
import fr.xgouchet.elmyr.junit5.ForgeExtension
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.extension.ExtendWith
import fr.xgouchet.elmyr.Forge
import fr.xgouchet.elmyr.annotation.IntForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.mockk.mockk
import io.mockk.verify
import org.junit.jupiter.api.Test

@ExtendWith(ForgeExtension::class)
@OptIn(kotlin.ExperimentalStdlibApi::class)
class DatadogLogsPluginTest {
    private lateinit var plugin: DatadogLogsPlugin
    private lateinit var mockLogger: Logger

    @BeforeEach
    fun beforeEach() {
        plugin = DatadogLogsPlugin()
        mockLogger = mockk(relaxed = true)

        plugin.addLogger("mock-logger", mockLogger)
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
            "logLevel" to "LogLevel.info",
            "context" to mapOf<String, Any>()
        ))
        val mockResult = mockk<MethodChannel.Result>(relaxed = true)

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { mockResult.error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), any()) }
    }

    private val contracts = listOf(
        Contract("log", mapOf(
            "loggerHandle" to ContractParameter.Value("mock-logger"),
            "logLevel" to ContractParameter.Type(SupportedContractType.STRING),
            "message" to ContractParameter.Type(SupportedContractType.STRING),
            "context" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("addAttribute", mapOf(
            "loggerHandle" to ContractParameter.Value("mock-logger"),
            "key" to ContractParameter.Type(SupportedContractType.STRING),
            "value" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("addTag", mapOf(
            "loggerHandle" to ContractParameter.Value("mock-logger"),
            "tag" to ContractParameter.Type(SupportedContractType.STRING)
        )),
        Contract("removeAttribute", mapOf(
            "loggerHandle" to ContractParameter.Value("mock-logger"),
            "key" to ContractParameter.Type(SupportedContractType.STRING)
        )),
        Contract("removeTag", mapOf(
            "loggerHandle" to ContractParameter.Value("mock-logger"),
            "tag" to ContractParameter.Type(SupportedContractType.STRING)
        )),
        Contract("removeTagWithKey", mapOf(
            "loggerHandle" to ContractParameter.Value("mock-logger"),
            "key" to ContractParameter.Type(SupportedContractType.STRING)
        )),
    )

    @Test
    fun `M report contract violation W missing parameters in contract`(
        forge: Forge
    ) {
        testContracts(contracts, forge, plugin)
    }

    fun defaultLoggingConfig(): Map<String, Any?> {
        return mapOf(
            "sendNetworkInfo" to true,
            "printLogsToConsole" to true,
            "sendLogsToDatadog" to true,
            "bundleWithRum" to true,
            "bundleWithTraces" to true,
            "loggerName" to "my_logger"
        )
    }

    @Test
    fun `M parse correct level W parseLogLevel`() {
        // WHEN
        var debug = parseLogLevel("LogLevel.debug")
        var info = parseLogLevel("LogLevel.info")
        var notice = parseLogLevel("LogLevel.notice")
        var warning = parseLogLevel("LogLevel.warning")
        var error = parseLogLevel("LogLevel.error")
        var critical = parseLogLevel("LogLevel.critical")
        var alert = parseLogLevel("LogLevel.alert")
        var emergency = parseLogLevel("LogLevel.emergency")
        var unknown = parseLogLevel("LogLevel.unknown")

        // THEN
        assertThat(debug).isEqualTo(Log.DEBUG)
        assertThat(info).isEqualTo(Log.INFO)
        // No matching level in Log
        assertThat(notice).isEqualTo(Log.WARN)
        assertThat(warning).isEqualTo(Log.WARN)
        assertThat(error).isEqualTo(Log.ERROR)
        // No matching level in Log
        assertThat(critical).isEqualTo(Log.ASSERT)
        // No matching level in Log
        assertThat(alert).isEqualTo(Log.ASSERT)
        // No matching level in Log
        assertThat(emergency).isEqualTo(Log.ASSERT)
        assertThat(unknown).isEqualTo(Log.INFO)
    }

    @Test
    fun `M create logger W createLogger`(
        @StringForgery loggerHandle: String
    ) {
        // GIVEN
        val call = MethodCall("createLogger", mapOf(
            "loggerHandle" to loggerHandle,
            "configuration" to defaultLoggingConfig()
        ))
        val mockResult = mockk<MethodChannel.Result>(relaxed = true)

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { mockResult.success(null) }

        val logger = plugin.getLogger(loggerHandle)
        assertThat(logger).isNotNull()
    }

    @Test
    fun `M call logger W log called through channel`(
        forge: Forge
    ) {
        // GIVEN
        val message = forge.aString()
        val context = forge.exhaustiveAttributes()
        val call = MethodCall("log", mapOf(
            "loggerHandle" to "mock-logger",
            "logLevel" to "LogLevel.info",
            "message" to message,
            "errorMessage" to null,
            "errorKind" to null,
            "stackTrace" to null,
            "context" to context
        ))
        val mockResult = mockk<MethodChannel.Result>(relaxed = true)

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { mockResult.success(null) }

        verify { mockLogger.log(Log.INFO, message, null, null, null, context) }
    }

    @Test
    fun `M call logger W log called through channel { error info }`(
        forge: Forge
    ) {
        // GIVEN
        val message = forge.aString()
        val context = forge.exhaustiveAttributes()
        val errorMessage = forge.aString()
        val errorKind = forge.anAlphaNumericalString()
        val stackTrace = forge.anAlphaNumericalString()
        val call = MethodCall("log", mapOf(
            "loggerHandle" to "mock-logger",
            "logLevel" to "LogLevel.verbose",
            "message" to message,
            "errorMessage" to errorMessage,
            "errorKind" to errorKind,
            "stackTrace" to stackTrace,
            "context" to context
        ))
        val mockResult = mockk<MethodChannel.Result>(relaxed = true)

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify { mockResult.success(null) }

        verify { mockLogger.log(Log.INFO, message, errorKind, errorMessage, stackTrace, context) }
    }
}