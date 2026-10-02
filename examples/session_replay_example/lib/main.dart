// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/datadog_flutter_plugin.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  DatadogSdk.instance.sdkVerbosity = CoreLoggerLevel.debug;

  final replaySampleRate = double.parse(
    dotenv.get('DD_SESSION_REPLAY_SAMPLE_RATE', fallback: '50'),
  );

  final configuration = DatadogConfiguration(
    clientToken: dotenv.get('DD_CLIENT_TOKEN', fallback: ''),
    env: dotenv.get('DD_ENV', fallback: ''),
    site: DatadogSite.us1,
    rumConfiguration: DatadogRumConfiguration(
      applicationId: dotenv.get('DD_APPLICATION_ID', fallback: ''),
      // Session Replay can only record sessions that RUM tracks.
      sessionSamplingRate: 50.0,
    ),
  )..enableSessionReplay(
      DatadogSessionReplayConfiguration(
        // Percentage of RUM sessions that get a replay, decided for each RUM
        // session from its ID. It stacks on the RUM sample rate: with RUM at
        // 50% and replay at 50%, about 25% of all sessions have a replay.
        replaySampleRate: replaySampleRate,
        // Don't record until the app calls startRecording(); see
        // RecordedScreen and PrivateScreen.
        startRecordingImmediately: false,
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
        touchPrivacyLevel: TouchPrivacyLevel.show,
      ),
    );

  await DatadogSdk.runApp(configuration, TrackingConsent.granted, () async {
    runApp(ExampleApp(replaySampleRate: replaySampleRate));
  });
}
