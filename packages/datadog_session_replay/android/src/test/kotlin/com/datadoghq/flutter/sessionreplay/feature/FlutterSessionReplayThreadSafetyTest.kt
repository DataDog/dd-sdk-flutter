/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay.feature

import android.os.Handler
import assertk.assertThat
import assertk.assertions.isEqualTo
import assertk.assertions.isTrue
import com.datadog.android.api.feature.Feature
import com.datadog.android.api.feature.FeatureSdkCore
import fr.xgouchet.elmyr.annotation.LongForgery
import fr.xgouchet.elmyr.annotation.StringForgery
import fr.xgouchet.elmyr.junit5.ForgeExtension
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith

/**
 * Reproduction tests for RUMS-5684: Flutter Android crashes after upgrading Datadog SDK.
 *
 * The crash is caused by a Dart VM isolate scheduling violation:
 * "Isolate (null) is already scheduled on mutator thread 0x800, failed to schedule from
 * os thread 0x73c5c0e500"
 *
 * Root cause: DefaultFlutterSessionReplayFeature.onContextUpdate() posts the context
 * change callback to the Android main thread via Handler(Looper.getMainLooper()).
 * When this callback invokes back into Dart via the JNI bridge, it does so from the
 * Android main thread instead of the Dart/Flutter engine mutator thread, causing the
 * Dart VM to abort.
 *
 * The fix should ensure that context change callbacks are NOT dispatched through the
 * Android main thread Handler, but instead invoke Dart via a mechanism that respects
 * the Dart isolate threading model (e.g., using async JNI callbacks or posting to the
 * Flutter engine thread).
 */
@ExtendWith(ForgeExtension::class)
internal class FlutterSessionReplayThreadSafetyTest {

    private val mockCore: FeatureSdkCore = mockk(relaxed = true)
    private val mockHandler: Handler = mockk()

    @BeforeEach
    fun setUp() {
        // Capture the Runnable posted to the Handler instead of immediately executing it.
        // This lets us inspect whether the callback is being dispatched through the
        // main thread Handler (which is the buggy behavior).
        every { mockHandler.post(any()) } returns true
    }

    /**
     * Test that onContextUpdate does NOT dispatch the callback through the main thread
     * Handler. The current implementation posts to mainThreadHandler, which causes the
     * Dart VM crash because JNI calls back into Dart must happen on the Dart mutator
     * thread, not the Android main thread.
     *
     * EXPECTED: onContextChanged callback should NOT be routed through mainThreadHandler.post()
     * ACTUAL (bug): The callback IS posted to mainThreadHandler, causing thread violation.
     */
    @Test
    fun `M not dispatch via main thread handler W onContextUpdate`(
        @StringForgery applicationId: String,
        @StringForgery sessionId: String,
        @StringForgery viewId: String,
        @LongForgery serverTimeOffset: Long
    ) {
        // Given
        val callbackInvoked = AtomicReference(false)
        val onContextChanged: (DefaultFlutterSessionReplayFeature.RumContext) -> Unit = {
            callbackInvoked.set(true)
        }
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            onContextChanged,
            null,
            mockHandler
        )
        val contextValue = mapOf(
            "application_id" to applicationId,
            "session_id" to sessionId,
            "view_id" to viewId,
            "view_timestamp_offset" to serverTimeOffset
        )

        // When
        feature.onContextUpdate(Feature.RUM_FEATURE_NAME, contextValue)

        // Then - The callback should NOT be dispatched through the main thread Handler.
        // If it is dispatched via Handler.post(), that means the callback will execute on the
        // Android main thread, which causes SIGABRT when it calls back into Dart via JNI.
        verify(exactly = 0) { mockHandler.post(any()) }

        // The callback should have been invoked directly (or via a Dart-safe mechanism)
        assertThat(callbackInvoked.get()).isTrue()
    }

    /**
     * Test that verifies the current buggy behavior: the callback IS posted to the main
     * thread Handler. This test documents the bug and should be removed once fixed.
     *
     * The Handler.post() call dispatches to the Android main Looper, but the Dart JNI
     * bridge requires callbacks on the Dart mutator thread. This mismatch causes:
     * "Isolate (null) is already scheduled on mutator thread, failed to schedule from os thread"
     */
    @Test
    fun `M post callback to main thread handler W onContextUpdate { current buggy behavior }`(
        @StringForgery applicationId: String,
        @StringForgery sessionId: String,
        @StringForgery viewId: String,
        @LongForgery serverTimeOffset: Long
    ) {
        // Given
        val onContextChanged = mockk<(DefaultFlutterSessionReplayFeature.RumContext) -> Unit>(
            relaxed = true
        )
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            onContextChanged,
            null,
            mockHandler
        )
        val contextValue = mapOf(
            "application_id" to applicationId,
            "session_id" to sessionId,
            "view_id" to viewId,
            "view_timestamp_offset" to serverTimeOffset
        )

        // When
        feature.onContextUpdate(Feature.RUM_FEATURE_NAME, contextValue)

        // Then - This verifies the BUG: the callback is dispatched through the main thread
        // Handler, which will cause a SIGABRT when Dart JNI bridge is invoked from the
        // Android main thread instead of the Dart mutator thread.
        verify(exactly = 1) { mockHandler.post(any()) }
    }

    /**
     * Test that the context callback runs on a thread compatible with Dart's isolate
     * threading model. When onContextUpdate is called from a background thread (as the
     * SDK core does), the callback to Dart should not be dispatched to the Android main
     * thread.
     *
     * This simulates the real crash scenario: SDK core calls onContextUpdate from an
     * internal thread, the feature dispatches to main thread, and the Dart callback
     * executes on the wrong thread.
     */
    @Test
    fun `M invoke callback without thread switch W onContextUpdate from background thread`(
        @StringForgery applicationId: String,
        @StringForgery sessionId: String,
        @StringForgery viewId: String,
        @LongForgery serverTimeOffset: Long
    ) {
        // Given - Set up handler to capture the runnable for thread analysis
        val capturedRunnable = slot<Runnable>()
        every { mockHandler.post(capture(capturedRunnable)) } returns true

        val callbackThread = AtomicReference<Thread?>(null)
        val onContextChanged: (DefaultFlutterSessionReplayFeature.RumContext) -> Unit = {
            callbackThread.set(Thread.currentThread())
        }
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            onContextChanged,
            null,
            mockHandler
        )
        val contextValue = mapOf(
            "application_id" to applicationId,
            "session_id" to sessionId,
            "view_id" to viewId,
            "view_timestamp_offset" to serverTimeOffset
        )

        // When - Simulate SDK core calling from a background thread
        val latch = CountDownLatch(1)
        val bgThread = Thread({
            feature.onContextUpdate(Feature.RUM_FEATURE_NAME, contextValue)
            latch.countDown()
        }, "sdk-core-thread")
        bgThread.start()
        latch.await(5, TimeUnit.SECONDS)

        // Then - The callback should NOT have been posted to the main thread handler.
        // Instead, it should execute on a thread compatible with Dart's isolate model.
        // The current implementation incorrectly posts to mainThreadHandler.
        verify(exactly = 0) { mockHandler.post(any()) }
    }

    /**
     * Test that context updates for non-RUM features are correctly ignored
     * (this is existing behavior that should be preserved).
     */
    @Test
    fun `M not invoke callback W onContextUpdate with non-RUM feature`(
        @StringForgery featureName: String,
        @StringForgery applicationId: String
    ) {
        // Given
        val callbackInvoked = AtomicReference(false)
        val onContextChanged: (DefaultFlutterSessionReplayFeature.RumContext) -> Unit = {
            callbackInvoked.set(true)
        }
        val feature = DefaultFlutterSessionReplayFeature(
            mockCore,
            onContextChanged,
            null,
            mockHandler
        )
        val contextValue = mapOf("application_id" to applicationId)

        // When - Use a non-RUM feature name
        feature.onContextUpdate(featureName, contextValue)

        // Then
        verify(exactly = 0) { mockHandler.post(any()) }
        assertThat(callbackInvoked.get()).isEqualTo(false)
    }
}
