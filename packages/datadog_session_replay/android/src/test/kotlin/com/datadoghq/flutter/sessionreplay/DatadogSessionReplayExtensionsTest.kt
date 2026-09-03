/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

package com.datadoghq.flutter.sessionreplay

import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleObserver
import androidx.lifecycle.LifecycleOwner
import assertk.assertThat
import assertk.assertions.hasSize
import assertk.assertions.isNotNull
import assertk.assertions.isNull
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.mockk.Runs
import io.mockk.every
import io.mockk.just
import io.mockk.mockk
import kotlin.test.Test

internal class DatadogSessionReplayExtensionsTest {
    @Test
    fun `M stop routing to detached cached engine W lifecycle host restarts`() {
        // Given - a lifecycle host whose view already has a cached engine
        val lifecycle = mockk<Lifecycle>()
        val lifecycleOwner = mockk<LifecycleOwner>()
        val view = mockk<FlutterView>()
        val engine = mockk<FlutterEngine>()
        val messenger = mockk<DartExecutor>()
        val lifecycleObservers = mutableListOf<LifecycleObserver>()
        val attachmentListeners = mutableListOf<FlutterView.FlutterEngineAttachmentListener>()
        every { lifecycle.addObserver(capture(lifecycleObservers)) } just Runs
        every { view.attachedFlutterEngine } returns engine
        every { view.addFlutterEngineAttachmentListener(capture(attachmentListeners)) } just Runs
        every { engine.dartExecutor } returns messenger

        try {
            observeHost(lifecycle) { view }
            assertThat(FlutterSessionReplayManager.shared.slotId(messenger)).isNotNull()

            // When - restarting the same host and then detaching its view from the cached engine
            (lifecycleObservers.single() as LifecycleEventObserver).onStateChanged(
                lifecycleOwner,
                Lifecycle.Event.ON_START
            )
            assertThat(attachmentListeners).hasSize(1)
            attachmentListeners.single().onFlutterEngineDetachedFromFlutterView()

            // Then - records can no longer target the stale slot
            assertThat(FlutterSessionReplayManager.shared.slotId(messenger)).isNull()
        } finally {
            FlutterSessionReplayManager.shared.detach(messenger)
        }
    }
}
