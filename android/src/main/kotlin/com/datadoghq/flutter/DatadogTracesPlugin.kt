/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.datadoghq.flutter

import com.datadog.android.tracing.AndroidTracer
import com.datadog.opentracing.DDTracer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.opentracing.Scope
import io.opentracing.Span
import io.opentracing.Tracer
import io.opentracing.log.Fields
import io.opentracing.util.GlobalTracer
import java.lang.ClassCastException
import java.util.concurrent.TimeUnit

data class SpanInfo(
    val handle: Long,
    val span: Span,
    var scope: Scope?
)

class DatadogTracesPlugin(
    tracerInstance: Tracer? = null
) : MethodChannel.MethodCallHandler {
    companion object TraceParameterNames {
        const val PARAM_SPAN_HANDLE = "spanHandle"
        const val PARAM_PARENT_SPAN = "parentSpan"
        const val PARAM_OPERATION_NAME = "operationName"
        const val PARAM_RESOURCE_NAME = "resourceName"
        const val PARAM_START_TIME = "startTime"
        const val PARAM_TAGS = "tags"
        const val PARAM_MESSAGE = "message"
        const val PARAM_KEY = "key"
        const val PARAM_KIND = "kind"
        const val PARAM_VALUE = "value"
        const val PARAM_FIELDS = "fields"
        const val PARAM_STACK_TRACE = "stackTrace"
    }

    private lateinit var channel: MethodChannel
    private lateinit var binding: FlutterPlugin.FlutterPluginBinding

    private var nextSpanId: Long = 1
    private val spanRegistry = mutableMapOf<Long, SpanInfo>()

    private lateinit var tracer: Tracer

    init {
        if (tracerInstance != null) {
            tracer = tracerInstance
        }
    }

    fun setup(
        flutterPluginBinding: FlutterPlugin.FlutterPluginBinding,
        configuration: DatadogFlutterConfiguration.TracingConfiguration
    ) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter.traces")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding

        tracer = AndroidTracer.Builder()
            .setBundleWithRumEnabled(configuration.bundleWithRum)
            .build()
        GlobalTracer.registerIfAbsent(tracer)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            with(call.method) {
                when {
                    startsWith("span.") -> onSpanMethodCall(call, result)
                    else -> onRootMethodCall(call, result)
                }
            }
        } catch (e: ClassCastException) {
            result.error(
                DatadogSdkPlugin.CONTRACT_VIOLATION, e.toString(),
                mapOf(
                    "methodName" to call.method
                )
            )
        }
    }

    @Suppress("LongMethod", "NestedBlockDepth")
    private fun onRootMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRootSpan" -> {
                val operationName = call.argument<String>(PARAM_OPERATION_NAME)
                if (operationName != null) {
                    val spanBuilder = tracer.buildSpan(operationName)
                        .ignoreActiveSpan()
					call.argument<String>(PARAM_RESOURCE_NAME)?.let {
                  	  val ddBuilder = spanBuilder as DDTracer.DDSpanBuilder
                    	ddBuilder.withResourceName(it)
	                }
                    call.argument<Number>(PARAM_START_TIME)?.let {
                        spanBuilder.withStartTimestamp(TimeUnit.MILLISECONDS.toMicros(it.toLong()))
                    }

                    val span = spanBuilder.start()

                    call.argument<Map<String, Any?>>(PARAM_TAGS)?.let {
                        span.setTags(it)
                    }

                    result.success(storeSpan(span))
                } else {
                    result.error(
                        DatadogSdkPlugin.CONTRACT_VIOLATION,
                        "Missing required parameter in call to startRootSpan",
                        null
                    )
                }
            }
            "startSpan" -> {
                val operationName = call.argument<String>(PARAM_OPERATION_NAME)
                if (operationName != null) {
                    val spanBuilder = tracer.buildSpan(operationName)
					call.argument<String>(PARAM_RESOURCE_NAME)?.let {
                  	  val ddBuilder = spanBuilder as DDTracer.DDSpanBuilder
                    	ddBuilder.withResourceName(it)
	                }
                    call.argument<Number>(PARAM_START_TIME)?.let {
                        spanBuilder.withStartTimestamp(TimeUnit.MILLISECONDS.toMicros(it.toLong()))
                    }
                    call.argument<Number>(PARAM_PARENT_SPAN)?.let {
                        spanRegistry[it.toLong()]?.let { spanInfo ->
                            spanBuilder.asChildOf(spanInfo.span)
                        }
                    }

                    val span = spanBuilder.start()
                    call.argument<Map<String, Any?>>(PARAM_TAGS)?.let {
                        span.setTags(it)
                    }
                    result.success(storeSpan(span))
                } else {
                    result.error(
                        DatadogSdkPlugin.CONTRACT_VIOLATION,
                        "Missing required parameter in call to startRootSpan",
                        null
                    )
                }
            }
            "getTracePropagationHeaders" -> {
                var headers = mapOf<String, String>()
                findCallingSpan(call)?.let { spanInfo ->
                    val context = spanInfo.span.context()
                    headers = mapOf(
                        "x-datadog-trace-id" to context.toTraceId().toString(),
                        "x-datadog-parent-id" to context.toSpanId().toString(),
                        "x-datadog-sampling-priority" to "1",
                        "x-datadog-sampled" to "1",
                    )
                }
                result.success(headers)
            }
            else -> result.notImplemented()
        }
    }

    @Suppress("LongMethod", "ComplexMethod")
    private fun onSpanMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val callingSpanInfo = findCallingSpan(call)
        if (callingSpanInfo == null) {
            result.success(null)
            return
        }

        when (call.method) {
            "span.setActive" -> {
                callingSpanInfo.scope = tracer.activateSpan(callingSpanInfo.span)
                result.success(null)
            }
            "span.setError" -> {
                val kind = call.argument<String>(PARAM_KIND)
                val message = call.argument<String>(PARAM_MESSAGE)
                if (kind != null && message != null) {
                    val fields = mutableMapOf<String, Any>(
                        Fields.EVENT to "error",
                        Fields.ERROR_KIND to kind,
                        Fields.MESSAGE to message,
                    )
                    call.argument<String>(PARAM_STACK_TRACE)?.let {
                        fields[Fields.STACK] = it
                    }

                    callingSpanInfo.span.log(fields)
                    result.success(null)
                } else {
                    result.error(
                        DatadogSdkPlugin.CONTRACT_VIOLATION,
                        "Missing required parameter in call to span.setError",
                        null
                    )
                }
            }
            "span.setTag" -> {
                val key = call.argument<String>(PARAM_KEY)
                if (key != null) {
                    when (val value = call.argument<Any>(PARAM_VALUE)) {
                        is Boolean -> callingSpanInfo.span.setTag(key, value)
                        is Number -> callingSpanInfo.span.setTag(key, value)
                        is String -> callingSpanInfo.span.setTag(key, value)
                        else -> callingSpanInfo.span.setTag(key, value?.toString())
                    }
                    result.success(null)
                } else {
                    result.error(
                        DatadogSdkPlugin.CONTRACT_VIOLATION,
                        "Missing required parameter in call to span.setTag",
                        null
                    )
                }
            }
            "span.setBaggageItem" -> {
                val key = call.argument<String>(PARAM_KEY)
                val value = call.argument<String>(PARAM_VALUE)
                if (key != null && value != null) {
                    callingSpanInfo.span.setBaggageItem(key, value)
                    result.success(null)
                } else {
                    result.error(
                        DatadogSdkPlugin.CONTRACT_VIOLATION,
                        "Missing required parameter in call to span.setBaggageItem",
                        null
                    )
                }
            }
            "span.log" -> {
                val fields = call.argument<Map<String, Any?>>(PARAM_FIELDS)
                if (fields != null) {
                    callingSpanInfo.span.log(fields)
                    result.success(null)
                } else {
                    result.error(
                        DatadogSdkPlugin.CONTRACT_VIOLATION,
                        "Missing required parameter in call to span.log",
                        null
                    )
                }
            }
            "span.finish" -> {
                call.argument<Number>(PARAM_SPAN_HANDLE)?.let {
                    callingSpanInfo.span.finish()
                    callingSpanInfo.scope?.close()
                    spanRegistry.remove(it.toLong())
                }
                result.success(null)
            }
        }
    }

    @Suppress("UNUSED_PARAMETER")
    fun teardown(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    private fun findCallingSpan(call: MethodCall): SpanInfo? {
        call.argument<Number>(PARAM_SPAN_HANDLE)?.let {
            return spanRegistry[it.toLong()]
        }
        return null
    }

    private fun storeSpan(span: Span): Long {
        val spanId = nextSpanId
        nextSpanId += 1
        spanRegistry[spanId] = SpanInfo(spanId, span, null)
        return spanId
    }

    private fun Span.setTags(tags: Map<String, Any?>) {
        tags.forEach { (key, value) ->
            when (value) {
                is Boolean -> setTag(key, value)
                is Number -> setTag(key, value)
                is String -> setTag(key, value)
                else -> setTag(key, value?.toString())
            }
        }
    }

    private inline fun <T : Any> ifLet(vararg elements: T?, closure: (List<T>) -> Unit) {
        if (elements.all { it != null }) {
            closure(elements.filterNotNull())
        }
    }
}
