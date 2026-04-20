// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart'
    show CapturedViewAttributes;
import 'package:datadog_session_replay/src/capture/element_recorders/common_nodes.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/icon_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/image_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/text_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'simple_test_capture.dart';

class MockDatadogSessionReplayPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSessionReplayPlatform {}

void main() {
  late MockDatadogSessionReplayPlatform platform;
  late SessionReplayRecorder recorder;
  late RUMContext context;

  setUp(() {
    final keyGenerator = KeyGenerator();
    platform = MockDatadogSessionReplayPlatform();
    DatadogSessionReplayPlatform.instance = platform;
    recorder = SessionReplayRecorder.withCustomRecorders(
      [
        IconRecorder(keyGenerator),
        TextElementRecorder(keyGenerator),
      ],
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
    );

    registerFallbackValue(
      CapturedViewAttributes(paintBounds: Rect.zero, scaleX: 1.0, scaleY: 1.0),
    );
    registerFallbackValue(ByteData(1));

    context = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
    );
    recorder.updateContext(context);

    when(() => platform.saveImageForProcessing(any(), any(), any(), any()))
        .thenAnswer((_) => Future.value());
    when(() => platform.resourceIdForKey(any())).thenReturn('rid');
  });

  testWidgets('captures Icon as ResourceImageNode and saves bytes once for two identical icons',
      (tester) async {
    const iconSize = 32.0;
    final x1 = randomDouble(min: 10, max: 40);
    final y1 = randomDouble(min: 10, max: 40);
    final x2 = x1 + 60;
    final y2 = y1;

    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: const Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: y1,
              left: x1,
              width: iconSize,
              height: iconSize,
              child: const Icon(Icons.favorite, color: Colors.red, size: iconSize),
            ),
            Positioned(
              top: y2,
              left: x2,
              width: iconSize,
              height: iconSize,
              child: const Icon(Icons.favorite, color: Colors.red, size: iconSize),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    CaptureResult? capture1;
    await tester.runAsync(() async {
      capture1 = await recorder.performCapture();
    });
    expect(capture1, isNotNull);
    expect(capture1!.viewTreeSnapshot.nodes.length, 2);
    expect(capture1!.viewTreeSnapshot.nodes.every((n) => n is ResourceImageNode), isTrue);
    final key1 = (capture1!.viewTreeSnapshot.nodes[0] as ResourceImageNode).resourceKey;
    final key2 = (capture1!.viewTreeSnapshot.nodes[1] as ResourceImageNode).resourceKey;
    expect(key1, key2);

    final expectedPx = math.max(1, (iconSize * tester.view.devicePixelRatio).ceil());

    CaptureResult? capture2;
    await tester.runAsync(() async {
      capture2 = await recorder.performCapture();
    });
    expect(capture2, isNotNull);
    expect(capture2!.viewTreeSnapshot.nodes.length, 2);
    expect((capture2!.viewTreeSnapshot.nodes[0] as ResourceImageNode).resourceKey, key1);
    expect((capture2!.viewTreeSnapshot.nodes[1] as ResourceImageNode).resourceKey, key1);

    // One rasterization for two identical icons; second capture is cache-only.
    verify(
      () => platform.saveImageForProcessing(
        key1,
        expectedPx,
        expectedPx,
        any(),
      ),
    ).called(1);
  });

  testWidgets('different icon color triggers second saveImageForProcessing', (tester) async {
    const iconSize = 28.0;
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: const Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: 10,
              left: 10,
              width: iconSize,
              height: iconSize,
              child: const Icon(Icons.star, color: Colors.amber, size: iconSize),
            ),
            Positioned(
              top: 10,
              left: 60,
              width: iconSize,
              height: iconSize,
              child: const Icon(Icons.star, color: Colors.green, size: iconSize),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    await tester.runAsync(() async {
      await recorder.performCapture();
    });

    verify(
      () => platform.saveImageForProcessing(any(), any(), any(), any()),
    ).called(2);
  });

  testWidgets('maskAll shows Icon placeholder and does not save image', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
      imagePrivacyLevel: ImagePrivacyLevel.maskAll,
    );

    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: const Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: 20,
              left: 20,
              width: 40,
              height: 40,
              child: const Icon(Icons.info, size: 40),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    expect(capture, isNotNull);
    final wf = capture!.viewTreeSnapshot.nodes.single.buildWireframes().single;
    expect(wf, isA<SRPlaceholderWireframe>());
    // Caption only when width >= PlaceholderNode minWidth (125); 40px is intentionally narrow.
    expect((wf as SRPlaceholderWireframe).label, isNull);
    verifyNever(() => platform.saveImageForProcessing(any(), any(), any(), any()));
  });

  testWidgets('maskNonAssetsOnly still captures Material Icon', (tester) async {
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
    );

    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: const Key('key'),
        recorder: recorder,
        child: const Stack(
          children: [
            Positioned(
              top: 12,
              left: 12,
              width: 24,
              height: 24,
              child: Icon(Icons.check_circle, size: 24),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    expect(capture!.viewTreeSnapshot.nodes.single, isA<ResourceImageNode>());
    verify(() => platform.saveImageForProcessing(any(), any(), any(), any())).called(1);
  });

  testWidgets('Icon subtree is ignored so inner RichText is not captured as text',
      (tester) async {
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: const Key('key'),
        recorder: recorder,
        child: const Stack(
          children: [
            Positioned(
              top: 8,
              left: 8,
              width: 48,
              height: 48,
              child: Icon(Icons.ac_unit, size: 48),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    expect(capture, isNotNull);
    expect(capture!.viewTreeSnapshot.nodes.length, 1);
    expect(capture!.viewTreeSnapshot.nodes.single, isA<ResourceImageNode>());
    expect(
      capture!.viewTreeSnapshot.nodes.whereType<TextElementCaptureNode>(),
      isEmpty,
    );
  });
}
