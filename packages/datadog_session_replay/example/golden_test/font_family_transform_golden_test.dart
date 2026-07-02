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
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'golden_test_helpers.dart';
import 'test_fonts.dart' as test_fonts;

class MockDatadogSessionReplayPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSessionReplayPlatform {}

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

  testWidgets('font transform smart maps package font to open sans',
      (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Font Transform Test',
            style: TextStyle(fontFamily: 'packages/my_app/CustomFont'),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'This text uses a package font that gets transformed to OpenSans '
            'by the font family transform. If you see readable text in the '
            'golden, the transform is working correctly.',
            style: TextStyle(
              fontFamily: 'packages/my_app/CustomFont',
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
    await snapshotTest(
      tester,
      recorder,
      fixture,
      fontFamilyTransform: FontFamilyTransformConfig(
        strategy: FontFamilyStrategy.smart,
        rules: {
          'CustomFont': test_fonts.openSans,
        },
      ),
    );
  });

  testWidgets('font transform smart drops sentinel and uses fallback rule',
      (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Sentinel Transform',
            style: TextStyle(fontFamily: '.AppleSystemUIFont'),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Text(
            'This text uses .AppleSystemUIFont which the smart strategy '
            'drops as a Flutter sentinel. The empty-key fallback rule then '
            'maps it to OpenSans. Readable text proves sentinel handling works.',
            style: TextStyle(
              fontFamily: '.AppleSystemUIFont',
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
    await snapshotTest(
      tester,
      recorder,
      fixture,
      fontFamilyTransform: FontFamilyTransformConfig(
        strategy: FontFamilyStrategy.smart,
        rules: {
          '': test_fonts.openSans,
        },
      ),
    );
  });

  testWidgets('font transform fallback replaces all families', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Fallback Strategy',
            style: TextStyle(fontFamily: test_fonts.openSans),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OpenSans text stays the same font stack with fallback.',
                style: TextStyle(
                  fontFamily: test_fonts.openSans,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Custom font text also gets the fallback stack.',
                style: TextStyle(
                  fontFamily: 'packages/my_app/CustomFont',
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await snapshotTest(
      tester,
      recorder,
      fixture,
      fontFamilyTransform: const FontFamilyTransformConfig(
        strategy: FontFamilyStrategy.fallback,
      ),
    );
  });
}
