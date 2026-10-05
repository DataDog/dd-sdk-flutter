/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadog.android.sessionreplay

import android.view.View
import com.datadog.android.api.SdkCore

/**
 * A test double for the real, `compileOnly` `_SessionReplayInternalProxy` — same package, same
 * class name, same method signatures.
 *
 * `dd-sdk-android-session-replay` is never on this module's test classpath, so without this,
 * `DefaultEmbeddedSessionReplay`'s own `Class.forName(PROXY_CLASS_NAME)` always throws
 * `ClassNotFoundException`, `isProxyClassAvailable` is always `false`, and `guarded()` always
 * returns before ever reaching the code that catches a real `LinkageError` — none of that class's
 * actual guarding logic has ever run in a test. Placing a class with this exact fully-qualified
 * name here makes it the one `DefaultEmbeddedSessionReplay`'s compiled calls resolve to instead,
 * so a test can drive its real behavior: flip [throwOnSetSlotId]/[throwOnAddRecords]/
 * [throwOnAddResource] to make the corresponding call throw a genuine [NoSuchMethodError] — a real
 * [LinkageError] subtype, the same shape a version-skewed native SDK would produce by actually
 * missing that member.
 */
internal class _SessionReplayInternalProxy {
    companion object {
        var setSlotIdCallCount = 0
        var addRecordsCallCount = 0
        var addResourceCallCount = 0

        var throwOnSetSlotId = false
        var throwOnAddRecords = false
        var throwOnAddResource = false

        /** Resets every counter and throw switch — call between tests, this state is global. */
        fun reset() {
            setSlotIdCallCount = 0
            addRecordsCallCount = 0
            addResourceCallCount = 0
            throwOnSetSlotId = false
            throwOnAddRecords = false
            throwOnAddResource = false
        }

        fun setEmbeddedContentSlotId(view: View, slotId: String?) {
            if (throwOnSetSlotId) {
                throw NoSuchMethodError("test-forced: setEmbeddedContentSlotId is missing")
            }
            setSlotIdCallCount++
        }

        fun addEmbeddedContentRecords(
            records: List<Map<String, Any?>>,
            slotId: String,
            viewId: String,
            sdkCore: SdkCore
        ) {
            if (throwOnAddRecords) {
                throw NoSuchMethodError("test-forced: addEmbeddedContentRecords is missing")
            }
            addRecordsCallCount++
        }

        fun addEmbeddedContentResource(
            identifier: String,
            resourceData: ByteArray,
            mimeType: String,
            sdkCore: SdkCore
        ) {
            if (throwOnAddResource) {
                throw NoSuchMethodError("test-forced: addEmbeddedContentResource is missing")
            }
            addResourceCallCount++
        }
    }
}
