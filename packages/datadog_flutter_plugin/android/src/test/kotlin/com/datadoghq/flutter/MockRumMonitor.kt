package com.datadoghq.flutter

import com.datadog.android.rum.ExperimentalRumApi
import com.datadog.android.rum.RumActionType
import com.datadog.android.rum.RumErrorSource
import com.datadog.android.rum.RumMonitor
import com.datadog.android.rum.RumResourceKind
import com.datadog.android.rum.RumResourceMethod
import com.datadog.android.rum._RumInternalProxy
import io.mockk.mockk

class MockRumMonitor : RumMonitor {
    val mockMonitor: RumMonitor = mockk(relaxed = true)
    val mockInternalProxy : _RumInternalProxy = mockk(relaxed = true)

    override var debug: Boolean
        get() = mockMonitor.debug
        set(value) { mockMonitor.debug = value }

    override fun _getInternal(): _RumInternalProxy? {
        return mockInternalProxy
    }

    override fun getCurrentSessionId(callback: (String?) -> Unit) {
        callback(null)
    }

    override fun addAction(type: RumActionType, name: String, attributes: Map<String, Any?>) {
        mockMonitor.addAction(type, name, attributes)
    }

    override fun addAttribute(key: String, value: Any?) {
        mockMonitor.addAttribute(key, value)
    }

    override fun addError(
        message: String,
        source: RumErrorSource,
        throwable: Throwable?,
        attributes: Map<String, Any?>
    ) {
        mockMonitor.addError(message, source, throwable, attributes)
    }

    override fun addErrorWithStacktrace(
        message: String,
        source: RumErrorSource,
        stacktrace: String?,
        attributes: Map<String, Any?>
    ) {
        mockMonitor.addErrorWithStacktrace(message, source, stacktrace, attributes)
    }

    override fun addFeatureFlagEvaluation(name: String, value: Any) {
        mockMonitor.addFeatureFlagEvaluation(name, value)
    }

    override fun addFeatureFlagEvaluations(featureFlags: Map<String, Any>) {
        mockMonitor.addFeatureFlagEvaluations(featureFlags)
    }

    override fun addTiming(name: String) {
        mockMonitor.addTiming(name)
    }

    @ExperimentalRumApi
    override fun addViewLoadingTime(overwrite: Boolean) {
        mockMonitor.addViewLoadingTime(overwrite)
    }

    override fun clearAttributes() {
        mockMonitor.clearAttributes()
    }

    override fun getAttributes(): Map<String, Any?> {
        return mockMonitor.getAttributes()
    }

    override fun removeAttribute(key: String) {
        mockMonitor.removeAttribute(key)
    }

    override fun startAction(type: RumActionType, name: String, attributes: Map<String, Any?>) {
        mockMonitor.startAction(type, name, attributes)
    }

    override fun startResource(
        key: String,
        method: RumResourceMethod,
        url: String,
        attributes: Map<String, Any?>
    ) {
        mockMonitor.startResource(key, method, url, attributes)
    }

    @Deprecated("Deprecated")
    override fun startResource(
        key: String,
        method: String,
        url: String,
        attributes: Map<String, Any?>
    ) {
        mockMonitor.startResource(key, method, url, attributes)
    }

    override fun startView(key: Any, name: String, attributes: Map<String, Any?>) {
        mockMonitor.startView(key, name, attributes)
    }

    override fun stopAction(type: RumActionType, name: String, attributes: Map<String, Any?>) {
        mockMonitor.stopAction(type, name, attributes)
    }

    override fun stopResource(
        key: String,
        statusCode: Int?,
        size: Long?,
        kind: RumResourceKind,
        attributes: Map<String, Any?>
    ) {
        mockMonitor.stopResource(key, statusCode, size, kind, attributes)
    }

    override fun stopResourceWithError(
        key: String,
        statusCode: Int?,
        message: String,
        source: RumErrorSource,
        stackTrace: String,
        errorType: String?,
        attributes: Map<String, Any?>
    ) {
        mockMonitor.stopResourceWithError(key, statusCode, message, source, stackTrace, errorType, attributes)
    }

    override fun stopResourceWithError(
        key: String,
        statusCode: Int?,
        message: String,
        source: RumErrorSource,
        throwable: Throwable,
        attributes: Map<String, Any?>
    ) {
        mockMonitor.stopResourceWithError(key, statusCode, message, source, throwable, attributes)
    }

    override fun stopSession() {
        mockMonitor.stopSession()
    }

    override fun stopView(key: Any, attributes: Map<String, Any?>) {
        mockMonitor.stopView(key, attributes)
    }
}