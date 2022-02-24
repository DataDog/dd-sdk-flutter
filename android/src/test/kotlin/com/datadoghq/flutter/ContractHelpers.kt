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
import kotlin.reflect.KType

data class Contract(
    val methodName: String,
    val requiredParameters: Map<String, KType>
) {
    fun createContractArguments(forge: Forge,
                                missingParam: String? = null,
                                extraArguments: Map<String, Any?>? = null): Map<String, Any?> {
        var arguments = mutableMapOf<String, Any?>()
        for(param in requiredParameters) {
            if(param.key != missingParam) {
                val value = when (param.value.classifier) {
                    String::class -> {
                        forge.anExtendedAsciiString()
                    }
                    Map::class -> {
                        forge.exhaustiveAttributes()
                    }
                    Int::class -> {
                        forge.anInt()
                    }
                    Long::class -> {
                        forge.aLong()
                    }
                    else -> throw UnsupportedOperationException("Unknown type in contract: ${param.value.toString()}")
                }

                arguments.put(param.key, value)
            }
        }

        if(extraArguments != null) {
            arguments = arguments.toMutableMap()
            arguments.putAll(extraArguments)
        }

        return arguments
    }
}

fun testContracts(contracts: List<Contract>,
                  forge: Forge,
                  plugin: MethodChannel.MethodCallHandler,
                  extraArguments: Map<String, Any?>? = null) {
    fun callContract(contract: Contract,
                     arguments: Map<String, Any?>,
                     plugin: MethodChannel.MethodCallHandler): MethodChannel.Result {
        val call = MethodCall(contract.methodName, arguments)
        val mockResult = mock<MethodChannel.Result>()
        plugin.onMethodCall(call, mockResult)

        return mockResult
    }

    for(contract in contracts) {
        // Test that a proper contract does not throw a contract violation
        val arguments = contract.createContractArguments(forge, extraArguments = extraArguments)
        val result = callContract(contract, arguments, plugin)
        verify(
            result,
            description("${contract.methodName} did not succeed with all required parmeters provided")
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