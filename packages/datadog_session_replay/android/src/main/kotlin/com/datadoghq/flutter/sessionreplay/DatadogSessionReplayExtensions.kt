/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2025-Present Datadog, Inc.
 */

@file:JvmName("DatadogSessionReplay")

package com.datadoghq.flutter.sessionreplay

import androidx.annotation.UiThread
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterFragment
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine

/**
 * Records this Flutter content as part of the native app's Session Replay.
 *
 * Call this from a native host that embeds Flutter, on the object that hosts it, and configure
 * Session Replay on the Dart side with `isEmbedded: true`. Nothing else is needed — the Flutter
 * records are composited into this host's replay wherever this view sits on screen.
 *
 * Call it as early as you like: if the Flutter view or its engine does not exist yet, recording
 * starts as soon as they do. Calling it more than once for the same host is harmless, and the host
 * keeps the same slot across configuration changes, so the replay is continuous.
 *
 * Each host gets its own slot, so an app embedding several engines records each one in the right
 * place.
 *
 * This does nothing unless the native Session Replay is enabled in the host app — in a pure-Flutter
 * app, configure Session Replay from Dart instead and leave `isEmbedded` at its default.
 */
@UiThread
fun FlutterFragment.enableSessionReplay() {
    // The fragment's own lifecycle, not the view's: the view lifecycle owner is replaced every time
    // the view is recreated, so observing it would stop at the first configuration change.
    observeHost(lifecycle) { findFlutterView() }
}

/** See [FlutterFragment.enableSessionReplay]. */
@UiThread
fun FlutterActivity.enableSessionReplay() {
    observeHost(lifecycle) { findFlutterView() }
}

/**
 * See [FlutterFragment.enableSessionReplay].
 *
 * Use this overload when the host manages the [FlutterView] itself rather than through
 * [FlutterFragment] or [FlutterActivity]. There is no lifecycle to follow here, so this tracks the
 * view's engine for as long as the view lives; a host that replaces the view must call this again on
 * the new one.
 */
@UiThread
fun FlutterView.enableSessionReplay() {
    registerSlot()
    // Registration needs an engine, which a view is not required to have yet. Following attachment
    // is also what keeps a cached engine moving between views — a common add-to-app pattern —
    // pointing at the view currently showing it.
    addFlutterEngineAttachmentListener(
        object : FlutterView.FlutterEngineAttachmentListener {
            override fun onFlutterEngineAttachedToFlutterView(engine: FlutterEngine) {
                FlutterSessionReplayManager.shared.registerSlot(this@enableSessionReplay, engine.messenger)
            }

            override fun onFlutterEngineDetachedFromFlutterView() {
                // The engine is already gone by the time this fires, so the slot cannot be
                // unregistered by messenger here. It is dropped when the plugin detaches, and until
                // then the weakly held view lets a re-attach reuse the same slot.
            }
        }
    )
}

/** Registers this view as its engine's slot, if it currently has an engine. */
@UiThread
private fun FlutterView.registerSlot() {
    val engine = attachedFlutterEngine ?: return
    FlutterSessionReplayManager.shared.registerSlot(this, engine.messenger)
}

/**
 * The messenger identifying an engine across this plugin.
 *
 * A plugin binding's `binaryMessenger` is this same object, which is what lets the host side and the
 * plugin side agree on which engine they are talking about.
 */
private val FlutterEngine.messenger get() = dartExecutor

/**
 * Registers the host's Flutter view as a slot, now if [findView] can find one and every time the
 * host starts thereafter.
 *
 * Re-resolving on each start is what makes a single call at any point in the host's setup enough:
 * the view may not exist yet when the host calls, and — for a fragment or an activity recreated on a
 * configuration change — the view it eventually gets is not the one it would have had. Registration
 * is idempotent and preserves the slot ID, so repeating it costs nothing and keeps the replay
 * unbroken.
 */
@UiThread
private fun observeHost(lifecycle: Lifecycle, findView: () -> FlutterView?) {
    findView()?.registerSlot()

    // Observed even when that succeeded: a fragment's view is torn down and rebuilt around a stop,
    // so the view registered just now is not necessarily the one the host ends up displaying.
    lifecycle.addObserver(
        object : LifecycleEventObserver {
            override fun onStateChanged(source: LifecycleOwner, event: Lifecycle.Event) {
                when (event) {
                    // ON_START rather than ON_CREATE: for both hosts the Flutter view exists and has
                    // its engine by the time the host is started.
                    Lifecycle.Event.ON_START -> findView()?.registerSlot()
                    Lifecycle.Event.ON_DESTROY -> source.lifecycle.removeObserver(this)
                    else -> Unit
                }
            }
        }
    )
}

/**
 * Finds the [FlutterView] a [FlutterFragment] or [FlutterActivity] hosts.
 *
 * Both give their Flutter view the same well-known ID, and neither exposes it directly —
 * `getFlutterEngine()` is protected on the activity, and would not give us the view in any case.
 */
private fun FlutterFragment.findFlutterView(): FlutterView? =
    view?.findViewById(FlutterFragment.FLUTTER_VIEW_ID)

private fun FlutterActivity.findFlutterView(): FlutterView? =
    findViewById(FlutterActivity.FLUTTER_VIEW_ID)
