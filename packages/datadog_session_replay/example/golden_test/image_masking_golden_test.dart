// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

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

const String assetImage = 'assets/dd_logo_v_rgb.png';
const String networkImageUrl =
    'https://docs.dd-static.net/img/dd_logo_n_70x75.png';

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;
  late MockDatadogSessionReplayPlatform platform;

  setUp(() {
    // Needed to fetch network images
    final httpOverride = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = httpOverride);

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

  Future<void> precacheImageCommonImages(WidgetTester tester,
      {double? scale}) async {
    await tester.runAsync(() async {
      final ImageProvider assetProvider = scale != null
          ? ExactAssetImage(assetImage, scale: scale)
          : AssetImage(assetImage);
      await precacheImage(assetProvider, tester.binding.rootElement!);
      await precacheImage(
        FileImage(File(assetImage)),
        tester.binding.rootElement!,
      );
      await precacheImage(
        NetworkImage(networkImageUrl),
        tester.binding.rootElement!,
      );
    });
  }

  Widget createFixtureBody({double? scale}) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        spacing: 12,
        children: [
          SizedBox(
              width: 130,
              height: 130,
              child: Image.asset(assetImage, scale: scale)),
          SizedBox(
            width: 130,
            height: 130,
            child: Image.file(File(assetImage)),
          ),
          SizedBox(
            width: 130,
            height: 130,
            child: Image.network(networkImageUrl),
          ),
        ],
      ),
    );
  }

  testWidgets('global mask all images', (tester) async {
    await precacheImageCommonImages(tester);

    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskAll,
    );

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mask All Images')),
        body: createFixtureBody(),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('global mask non-asset images', (tester) async {
    await precacheImageCommonImages(tester);

    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
    );

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mask Non-Asset Images')),
        body: createFixtureBody(),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('global mask non-asset images with scaled asset', (tester) async {
    await precacheImageCommonImages(tester, scale: 2.0);

    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
    );

    final fixture = MaterialApp(
      home: Scaffold(
        appBar:
            AppBar(title: const Text('Mask Non-Asset Images (Scaled Asset)')),
        body: createFixtureBody(scale: 2.0),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('global mask none images', (tester) async {
    await precacheImageCommonImages(tester);

    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskNone,
    );

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Mask No Images')),
        body: createFixtureBody(),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  // For Override tests, the default is `maskNone`
  testWidgets('override mask all images', (tester) async {
    await precacheImageCommonImages(tester);

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Override Mask All')),
        body: SessionReplayPrivacy(
          imagePrivacyLevel: ImagePrivacyLevel.maskAll,
          child: createFixtureBody(),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });

  testWidgets('override mask non-asset images', (tester) async {
    await precacheImageCommonImages(tester);

    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Override Mask Non-Assets')),
        body: SessionReplayPrivacy(
          imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
          child: createFixtureBody(),
        ),
      ),
    );
    await snapshotTest(tester, recorder, fixture);
  });
}
