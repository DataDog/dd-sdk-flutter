// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'golden_test_helpers.dart';
import 'mock_platform.dart';

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;
  late MockDatadogSessionReplayPlatform platform;

  setUp(() {
    recorder = SessionReplayRecorder(
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
    );
    platform = MockDatadogSessionReplayPlatform();
    DatadogSessionReplayPlatform.instance = platform;

    registerFallbackValue(
      CapturedViewAttributes(paintBounds: Rect.zero, scaleX: 1.0, scaleY: 1.0),
    );

    context = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
    );
    recorder.updateContext(context);
  });

  tearDown(() {
    platform.clearImages();
  });

  Widget createIconFixture() {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: const [
          Icon(Icons.favorite, color: Colors.red, size: 48),
          Icon(Icons.home, color: Colors.blue, size: 48),
          Icon(Icons.settings, size: 48),
        ],
      ),
    );
  }

  testWidgets('global mask all icons', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskAll,
    );

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mask All Icons')),
        body: createIconFixture(),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('global mask none icons', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskNone,
    );

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mask No Icons')),
        body: createIconFixture(),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('global mask non-asset icons', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
    );

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mask Non-Asset Icons')),
        body: createIconFixture(),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('override mask all icons', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Override Mask All Icons')),
        body: SessionReplayPrivacy(
          imagePrivacyLevel: ImagePrivacyLevel.maskAll,
          child: createIconFixture(),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });
}
