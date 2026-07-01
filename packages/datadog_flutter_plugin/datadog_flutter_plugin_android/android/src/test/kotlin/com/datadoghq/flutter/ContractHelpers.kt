@file:Suppress("MatchingDeclarationName")

package com.datadoghq.flutter

import fr.xgouchet.elmyr.Forge
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.kotlin.any
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.description
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify

enum class SupportedContractType {
    STRING,
    MAP,
    LIST,
    INT,
    LONG,
    BOOL,
    ANY,
}

sealed class ContractParameter {
    class Type(val type: SupportedContractType): ContractParameter()
    class Value(val value: Any): ContractParameter()
}

@Suppress("NestedBlockDepth")
data class Contract(
    val methodName: String,
    val requiredParameters: Map<String, ContractParameter>
) {
    fun createContractArguments(forge: Forge,
                                missingParam: String? = null,
                                extraArguments: Map<String, Any?>? = null): Map<String, Any?> {
        var arguments = mutableMapOf<String, Any?>()
        for(param in requiredParameters) {
            if(param.key != missingParam) {
                val value = when (val contractParameter = param.value) {
                    is ContractParameter.Value -> contractParameter.value
                    is ContractParameter.Type -> forgeValue(forge, contractParameter.type)
                }

                arguments[param.key] = value
            }
        }

        if(extraArguments != null) {
            arguments = arguments.toMutableMap()
            arguments.putAll(extraArguments)
        }

        return arguments
    }

    private fun forgeValue(forge: Forge, type: SupportedContractType): Any {
        return when(type) {
            SupportedContractType.STRING -> forge.anExtendedAsciiString()
            SupportedContractType.MAP -> forge.exhaustiveAttributes()
            SupportedContractType.LIST -> emptyList<Any>()
            SupportedContractType.INT -> forge.anInt()
            SupportedContractType.LONG -> forge.aLong()
            SupportedContractType.BOOL -> forge.aBool()
            SupportedContractType.ANY -> forge.aValueFrom(
                listOf(
                    forge.aBool(),
                    forge.anInt(),
                    forge.aLong(),
                    forge.aFloat(),
                    forge.aDouble(),
                    forge.anAsciiString(),
                    forge.aList { anAlphabeticalString() },
                ).associateBy { forge.anAlphabeticalString() }
            )
        }
    }
}

fun testContracts(
    contracts: List<Contract>,
    forge: Forge,
    plugin: MethodChannel.MethodCallHandler,
    extraArguments: Map<String, Any?>? = null
) {
    fun callContract(
        contract: Contract,
        arguments: Map<String, Any?>,
        plugin: MethodChannel.MethodCallHandler
    ): MethodChannel.Result {
        val call = MethodCall(contract.methodName, arguments)
        val mockResult = mock<MethodChannel.Result>()
        plugin.onMethodCall(call, mockResult)

        return mockResult
    }

    for(contract in contracts) {
        // Test that a proper contract does not throw a contract violation
        val allArguments = contract.createContractArguments(forge, extraArguments = extraArguments)
        val successResult = callContract(contract, allArguments, plugin)
        verify(
            successResult,
            description("${contract.methodName} did not succeed with all required parameters provided")
        ).success(anyOrNull())

        for (param in contract.requiredParameters) {
            // GIVEN
            val arguments = contract.createContractArguments(forge, param.key, extraArguments)

            // WHEN
            val result = callContract(contract, arguments, plugin)

            // THEN
            verify(
                result,
                description("${contract.methodName} did not throw a contract violation when missing ${param.key}")
            ).error(eq(DatadogSdkPlugin.CONTRACT_VIOLATION), any(), anyOrNull())
        }
    }
}