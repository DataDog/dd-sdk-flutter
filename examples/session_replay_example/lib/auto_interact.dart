// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'dart:io';

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Test-only scripted interaction used by `scripts/run_sampling_test.sh` to
/// check Session Replay sampling end to end. Not needed to use Session Replay.
///
/// It does nothing unless the script wrote a run ID to `Documents/sr_test_run`
/// in the app's data container. When enabled, it taps through the app for
/// about 10 seconds by injecting pointer events into Flutter (no host mouse
/// needed), tags every RUM event with an `sr_test_run` attribute, and logs a
/// report line for the script.
class AutoInteract {
  static String? get _runId {
    // Platform.environment is empty on iOS; systemTemp is <container>/tmp.
    final file = File(
      '${Directory.systemTemp.parent.path}/Documents/sr_test_run',
    );
    if (!file.existsSync()) return null;
    final id = file.readAsStringSync().trim();
    return id.isEmpty ? null : id;
  }

  // Each step taps the widget matching the predicate, then waits.
  static final _script = <(bool Function(Widget), int)>[
    (_icon(Icons.add), 600),
    (_icon(Icons.add), 600),
    (_text('Change Color'), 800),
    (_icon(Icons.remove), 600),
    (_text('Private'), 1200),
    (_text('Toggle setting'), 800),
    (_text('Recorded'), 1200),
    (_icon(Icons.add), 600),
    (_text('Change Color'), 800),
    (_icon(Icons.add), 600),
    (_text('Change Color'), 1200),
  ];

  static bool Function(Widget) _text(String label) =>
      (w) => w is Text && w.data == label;

  static bool Function(Widget) _icon(IconData icon) =>
      (w) => w is Icon && w.icon == icon;

  static void startIfRequested({
    required double rumSampleRate,
    required double replaySampleRate,
  }) {
    final runId = _runId;
    if (runId == null) return;

    DatadogSdk.instance.rum?.addAttribute('sr_test_run', runId);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _run(rumSampleRate, replaySampleRate),
    );
  }

  static Future<void> _run(
      double rumSampleRate, double replaySampleRate) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    for (final (matches, pauseMs) in _script) {
      final position = _centerOf(matches);
      if (position != null) await _tap(position);
      await Future<void>.delayed(Duration(milliseconds: pauseMs));
    }
    await _report(rumSampleRate, replaySampleRate);
  }

  /// Logs this launch's RUM session, the replay decision the SDKs should make
  /// for it, and whether Session Replay captured. The script ends on the
  /// Recorded screen, so a sampled session is capturing.
  static Future<void> _report(
    double rumSampleRate,
    double replaySampleRate,
  ) async {
    final sessionId = await DatadogSdk.instance.rum?.getCurrentSessionId();
    final expected = sessionId != null &&
        DeterministicSampler.fromUuid(sessionId, rumSampleRate)
            .combined(replaySampleRate)
            .sample();
    final capturing = DatadogSessionReplay.instance?.isCapturing ?? false;
    debugPrint(
      'SR_TEST session=$sessionId expectedReplay=$expected capturing=$capturing',
    );
  }

  /// The on-screen center of the first widget matching [matches].
  static Offset? _centerOf(bool Function(Widget) matches) {
    Offset? center;
    void visit(Element element) {
      if (center != null) return;
      final renderObject = element.renderObject;
      if (matches(element.widget) &&
          renderObject is RenderBox &&
          renderObject.attached &&
          renderObject.hasSize) {
        center = renderObject.localToGlobal(
          renderObject.size.center(Offset.zero),
        );
        return;
      }
      element.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return center;
  }

  static Future<void> _tap(Offset position) async {
    final binding = GestureBinding.instance;
    binding.handlePointerEvent(PointerDownEvent(position: position));
    await Future<void>.delayed(const Duration(milliseconds: 80));
    binding.handlePointerEvent(PointerUpEvent(position: position));
  }
}
