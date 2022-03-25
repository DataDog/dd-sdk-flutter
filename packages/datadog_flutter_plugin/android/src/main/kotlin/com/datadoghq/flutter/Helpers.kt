package com.datadoghq.flutter

import io.flutter.plugin.common.MethodChannel

fun MethodChannel.Result.missingParameter(methodName: String, details: Object? = null) {
    this.error(
        DatadogSdkPlugin.CONTRACT_VIOLATION,
        "Missing required parameter in call to $methodName",
        details
    )
}

fun MethodChannel.Result.invalidOperation(message: String, details: Object? = null) {
    this.error(
        DatadogSdkPlugin.INVALID_OPERATION,
        message,
        details
    )
}
