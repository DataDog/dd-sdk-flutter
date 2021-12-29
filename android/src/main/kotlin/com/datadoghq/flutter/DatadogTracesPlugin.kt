package com.datadoghq.flutter

import com.datadog.android.tracing.AndroidTracer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.opentracing.Span
import io.opentracing.Tracer
import io.opentracing.log.Fields
import java.util.concurrent.TimeUnit

internal class DatadogTracesPlugin : MethodChannel.MethodCallHandler {
    companion object TraceParameterNames {
        const val PARAM_SPAN_HANDLE = "spanHandle"
        const val PARAM_PARENT_SPAN = "parentSpan"
        const val PARAM_OPERATION_NAME = "operationName"
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
    private val spanRegistry = mutableMapOf<Long, Span>()

    private val tracer: Tracer by lazy {
        AndroidTracer.Builder().build()
    }

    fun setup(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "datadog_sdk_flutter.traces")
        channel.setMethodCallHandler(this)

        binding = flutterPluginBinding
    }

    @Suppress("LongMethod", "ComplexMethod", "NestedBlockDepth")
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        with(call.method) {
            when {
                equals("startRootSpan") -> {
                    val operationName = call.argument<String>(PARAM_OPERATION_NAME)

                    val spanBuilder = tracer.buildSpan(operationName)
                        .ignoreActiveSpan()
                    call.argument<Number>(PARAM_START_TIME)?.let {
                        spanBuilder.withStartTimestamp(TimeUnit.MILLISECONDS.toMicros(it.toLong()))
                    }

                    val span = spanBuilder.start()

                    call.argument<Map<String, Any?>>(PARAM_TAGS)?.let {
                        span.setTags(it)
                    }

                    result.success(storeSpan(span))
                }
                equals("startSpan") -> {
                    val operationName = call.argument<String>(PARAM_OPERATION_NAME)

                    val spanBuilder = tracer.buildSpan(operationName)
                    call.argument<Number>(PARAM_START_TIME)?.let {
                        spanBuilder.withStartTimestamp(TimeUnit.MILLISECONDS.toMicros(it.toLong()))
                    }
                    call.argument<Number>(PARAM_PARENT_SPAN)?.let {
                        spanRegistry[it.toLong()]?.let { span ->
                            spanBuilder.asChildOf(span)
                        }
                    }

                    val span = spanBuilder.start()
                    call.argument<Map<String, Any?>>(PARAM_TAGS)?.let {
                        span.setTags(it)
                    }

                    result.success(storeSpan(span))
                }
                startsWith("span.") -> onSpanMethodCall(call, result)
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("LongMethod", "ComplexMethod")
    private fun onSpanMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val callingSpan = findCallingSpan(call)
        if (callingSpan == null) {
            result.success(null)
            return
        }

        when (call.method) {
            "span.setActive" -> {
                tracer.activateSpan(callingSpan)
                result.success(null)
            }
            "span.setError" -> {
                ifLet(
                    call.argument<String>(PARAM_KIND),
                    call.argument<String>(PARAM_MESSAGE)
                ) { (kind, message) ->
                    val fields = mutableMapOf<String, Any>(
                        Fields.EVENT to "error",
                        Fields.ERROR_KIND to kind,
                        Fields.MESSAGE to message,
                    )
                    call.argument<String>(PARAM_STACK_TRACE)?.let {
                        fields[Fields.STACK] = it
                    }

                    callingSpan.log(fields)
                }
                result.success(null)
            }
            "span.setTag" -> {
                call.argument<String>(PARAM_KEY)?.let { key ->
                    when (val value = call.argument<Any>(PARAM_VALUE)) {
                        is Boolean -> callingSpan.setTag(key, value)
                        is Number -> callingSpan.setTag(key, value)
                        is String -> callingSpan.setTag(key, value)
                        else -> callingSpan.setTag(key, value?.toString())
                    }
                }
                result.success(null)
            }
            "span.setBaggageItem" -> {
                ifLet(
                    call.argument<String>(PARAM_KEY),
                    call.argument<String>(PARAM_VALUE)
                ) { (key, value) ->
                    callingSpan.setBaggageItem(key, value)
                }
                result.success(null)
            }
            "span.log" -> {
                call.argument<Map<String, Any?>>(PARAM_FIELDS)?.let {
                    callingSpan.log(it)
                }
                result.success(null)
            }
            "span.finish" -> {
                call.argument<Number>(PARAM_SPAN_HANDLE)?.let {
                    callingSpan.finish()
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

    private fun findCallingSpan(call: MethodCall): Span? {
        call.argument<Number>(PARAM_SPAN_HANDLE)?.let {
            return spanRegistry[it.toLong()]
        }
        return null
    }

    private fun storeSpan(span: Span): Long {
        val spanId = nextSpanId
        nextSpanId += 1
        spanRegistry[spanId] = span
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
