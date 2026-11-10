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
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'golden_test_helpers.dart';
import 'mock_platform.dart';
import 'test_fonts.dart' as test_fonts;

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;
  late MockDatadogSessionReplayPlatform platform;

  setUpAll(() async {
    await test_fonts.loadAppFonts();
  });

  setUp(() {
    recorder = SessionReplayRecorder(
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
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

  Widget createFixture(String title) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 16,
            children: [
              // Material icons: sent as text in the player-bundled font.
              const Row(
                spacing: 16,
                children: [
                  Icon(Icons.home),
                  Icon(Icons.star, color: Colors.amber),
                  Icon(Icons.favorite, color: Colors.red, size: 48),
                  IconTheme(
                    data: IconThemeData(color: Colors.blue, opacity: 0.4),
                    child: Icon(Icons.settings, size: 36),
                  ),
                ],
              ),
              // Custom icon fonts: rasterized.
              const Row(
                spacing: 16,
                children: [
                  Icon(CupertinoIcons.heart_fill, color: Colors.pink),
                  Icon(CupertinoIcons.settings, size: 48),
                  Icon(CupertinoIcons.person_crop_circle, color: Colors.teal),
                ],
              ),
              // Material icons the player font can't reproduce: rasterized.
              Row(
                spacing: 16,
                children: [
                  const Icon(
                    Icons.cloud,
                    size: 48,
                    color: Colors.lightBlue,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(2, 2),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: const Icon(Icons.arrow_back, size: 36),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('icons mask none images', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskNone,
    );

    await snapshotTest(tester, recorder, createFixture('Mask None Icons'));
  });

  testWidgets('icons mask non-asset images', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
    );

    await snapshotTest(tester, recorder, createFixture('Mask Non-Asset Icons'));
  });

  testWidgets('icons mask all images', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskAll,
    );

    await snapshotTest(tester, recorder, createFixture('Mask All Icons'));
  });
}
