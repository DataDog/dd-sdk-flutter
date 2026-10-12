// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
// ignore: implementation_imports
import 'package:datadog_session_replay/src/datadog_session_replay_plugin.dart';
import 'package:flutter/material.dart';

import 'embedded_panel.dart';
import 'full_screen_app.dart';

/// Entrypoint for the full screen Flutter view the native host pushes on top
/// of its own screen.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _attachToNativeDatadog();

  runApp(const FullScreenApp());
}

/// Entrypoint for the Flutter panel embedded in the middle of the native
/// screen. It runs in its own engine, so it attaches to Datadog on its own.
@pragma('vm:entry-point')
void embeddedMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _attachToNativeDatadog();

  runApp(const EmbeddedPanelApp());
}

/// The native host has already initialized Datadog, RUM and Session Replay,
/// so Flutter attaches to that instance instead of initializing its own.
Future<void> _attachToNativeDatadog() async {
  final configuration = DatadogAttachConfiguration(
    detectLongTasks: true,
    reportFlutterPerformance: true,
  )..addPlugin(
      DatadogSessionReplayPluginConfiguration(
        configuration: DatadogSessionReplayConfiguration(
          // Ignored when embedded: the native Session Replay sample rate
          // decides which sessions are recorded.
          replaySampleRate: 100,
          // Hand records to the native Session Replay, which composites them
          // into the host's replay where the Flutter view sits on screen.
          isEmbedded: true,
          // Match the privacy levels the native host uses, so Flutter and
          // native content are masked the same way in the replay.
          textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNone,
          touchPrivacyLevel: TouchPrivacyLevel.show,
        ),
      ),
    );

  await DatadogSdk.instance.attachToExisting(configuration);
}
