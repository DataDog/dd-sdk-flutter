/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import assertk.assertThat
import assertk.assertions.isNotNull
import com.datadog.android.log.Logger
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
import kotlin.reflect.typeOf

@ExtendWith(ForgeExtension::class)
@OptIn(kotlin.ExperimentalStdlibApi::class)
class DatadogLogsPluginTest {
    private lateinit var plugin: DatadogLogsPlugin

    @BeforeEach
    fun beforeEach() {
        plugin = DatadogLogsPlugin()

        plugin.addLogger("mock-logger", Logger.Builder().build())
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

    private val contracts = listOf(
        Contract("debug", mapOf(
            "loggerHandle" to ContractParameter.Value("mock-logger"),
            "message" to ContractParameter.Type(SupportedContractType.STRING),
            "context" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("info", mapOf(
            "loggerHandle" to ContractParameter.Value("mock-logger"),
            "message" to ContractParameter.Type(SupportedContractType.STRING),
            "context" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("warn", mapOf(
            "loggerHandle" to ContractParameter.Value("mock-logger"),
            "message" to ContractParameter.Type(SupportedContractType.STRING),
            "context" to ContractParameter.Type(SupportedContractType.MAP),
        )),
        Contract("error", mapOf(
            "loggerHandle" to ContractParameter.Value("mock-logger"),
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
    fun `M create logger W createLogger`(
        @StringForgery loggerHandle: String
    ) {
        // GIVEN
        val call = MethodCall("createLogger", mapOf(
            "loggerHandle" to loggerHandle,
            "configuration" to defaultLoggingConfig()
        ))
        val mockResult = mock<MethodChannel.Result>()

        // WHEN
        plugin.onMethodCall(call, mockResult)

        // THEN
        verify(mockResult).success(null)

        val logger = plugin.getLogger(loggerHandle)
        assertThat(logger).isNotNull()
    }
}