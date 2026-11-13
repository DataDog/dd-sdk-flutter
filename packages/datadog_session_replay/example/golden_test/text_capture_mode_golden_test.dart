// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_test_helpers.dart';
import 'mock_platform.dart';
import 'test_fonts.dart' as test_fonts;

void main() {
  late MockDatadogSessionReplayPlatform platform;

  setUpAll(() async {
    await test_fonts.loadAppFonts();
  });

  setUp(() {
    platform = MockDatadogSessionReplayPlatform();
    DatadogSessionReplayPlatform.instance = platform;
  });

  tearDown(() {
    platform.clearImages();
  });

  SessionReplayRecorder createRecorder(
    TextCaptureMode textCaptureMode, {
    TextAndInputPrivacyLevel textAndInputPrivacyLevel =
        TextAndInputPrivacyLevel.maskSensitiveInputs,
  }) {
    final recorder = SessionReplayRecorder(
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: textAndInputPrivacyLevel,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
      textCaptureMode: textCaptureMode,
    );
    recorder.updateContext(
      RUMContext(applicationId: randomString(), sessionId: randomString()),
    );
    return recorder;
  }

  Widget createFixture(String title) {
    return MaterialApp(
      theme: ThemeData(fontFamily: test_fonts.openSans),
      home: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              const Text('Regular body text'),
              const Text(
                'Bold title',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Italic in a custom font',
                style: TextStyle(
                  fontFamily: test_fonts.openSans,
                  fontStyle: FontStyle.italic,
                  fontSize: 18,
                ),
              ),
              const Text(
                'W I D E  spacing',
                style: TextStyle(letterSpacing: 4),
              ),
              const Text.rich(
                TextSpan(
                  text: 'Mixed ',
                  children: [
                    TextSpan(
                      text: 'bold ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: 'and red',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 180,
                child: Text(
                  'A long single line that ends with an ellipsis',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(
                width: 180,
                child: Text(
                  'A paragraph that wraps onto exactly the same lines as '
                  'on the device.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('standard text capture', (tester) async {
    final recorder = createRecorder(TextCaptureMode.standard);
    await snapshotTest(tester, recorder, createFixture('Standard'));
  });

  testWidgets('high fidelity text capture', (tester) async {
    final recorder = createRecorder(TextCaptureMode.highFidelity);
    await snapshotTest(tester, recorder, createFixture('High Fidelity'));
  });

  testWidgets('high fidelity text capture mask all', (tester) async {
    final recorder = createRecorder(
      TextCaptureMode.highFidelity,
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
    );
    await snapshotTest(tester, recorder, createFixture('Masked'));
  });
}
