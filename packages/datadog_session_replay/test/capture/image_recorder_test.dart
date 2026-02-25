// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/image_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../test_utils.dart';
import 'simple_test_capture.dart';

class MockDatadogSessionReplayPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSessionReplayPlatform {}

void main() {
  late MockDatadogSessionReplayPlatform platform;
  late SessionReplayRecorder recorder;
  late RUMContext context;

  late final ui.Image testImage;

  setUpAll(() async {
    final width = randomInt(min: 10, max: 50);
    final height = randomInt(min: 10, max: 50);
    testImage = await createTestImage(
      width: width.toInt(),
      height: height.toInt(),
    );
  });

  tearDownAll(() {
    testImage.dispose();
  });

  setUp(() {
    final KeyGenerator keyGenerator = KeyGenerator();
    platform = MockDatadogSessionReplayPlatform();
    DatadogSessionReplayPlatform.instance = platform;
    recorder = SessionReplayRecorder.withCustomRecorders(
      [ImageRecorder(keyGenerator)],
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
        touchPrivacyLevel: TouchPrivacyLevel.show,
      )
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
  });

  testWidgets('returns no node when image is not loaded', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);

    final imageProvider = TestImageProvider(testImage);
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: y,
              left: x,
              width: testImage.width.toDouble(),
              height: testImage.height.toDouble(),
              child: Image(image: imageProvider),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    // Then
    expect(capture, isNull);
  });

  testWidgets('returns node for loaded Image', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);

    final imageProvider = TestImageProvider(testImage);
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: y,
              left: x,
              width: testImage.width.toDouble(),
              height: testImage.height.toDouble(),
              child: Image(image: imageProvider),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);
    imageProvider.complete();
    await tester.pump();

    // When
    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    // Then
    expect(capture!.viewTreeSnapshot.nodes.length, 1);

    final capturedImageNode = capture!.viewTreeSnapshot.nodes.last;
    expect(capturedImageNode.attributes.x, x.round());
    expect(capturedImageNode.attributes.y, y.round());
    expect(capturedImageNode.attributes.width, testImage.width);
    expect(capturedImageNode.attributes.height, testImage.height);
  });

  testWidgets('captured image saves image to platform for processing', (
    tester,
  ) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);

    when(
      () => platform.saveImageForProcessing(any(), any(), any(), any()),
    ).thenAnswer((_) {
      Future.value();
    });

    final imageProvider = TestImageProvider(testImage);
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: y,
              left: x,
              width: testImage.width.toDouble(),
              height: testImage.height.toDouble(),
              child: Image(image: imageProvider),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);
    imageProvider.complete();
    await tester.pump();

    // When
    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    // Then
    expect(capture!.viewTreeSnapshot.nodes.length, 1);

    final capturedImageNode =
        capture!.viewTreeSnapshot.nodes.last as ResourceImageNode;
    final resourceKey =
        verify(
              () => platform.saveImageForProcessing(
                captureAny(),
                testImage.width,
                testImage.height,
                any(),
              ),
            ).captured.first
            as int;
    expect(capturedImageNode.resourceKey, resourceKey);
  });

  testWidgets('captured image uses identifier from platform', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);

    when(
      () => platform.saveImageForProcessing(any(), any(), any(), any()),
    ).thenAnswer((_) {
      Future.value();
    });
    final randomId = randomString();
    when(() => platform.resourceIdForKey(any())).thenReturn(randomId);

    final imageProvider = TestImageProvider(testImage);
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: y,
              left: x,
              width: testImage.width.toDouble(),
              height: testImage.height.toDouble(),
              child: Image(image: imageProvider),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);
    imageProvider.complete();
    await tester.pump();

    // When
    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    // Then
    expect(capture!.viewTreeSnapshot.nodes.length, 1);

    final capturedImageNode =
        capture!.viewTreeSnapshot.nodes.last as ResourceImageNode;
    final resourceKey =
        verify(
              () => platform.saveImageForProcessing(
                captureAny(),
                testImage.width,
                testImage.height,
                any(),
              ),
            ).captured.first
            as int;

    final builtWireframes = capturedImageNode.buildWireframes();
    expect(builtWireframes.length, 1);
    final wireframe = builtWireframes.first as SRImageWireframe;
    verify(() => platform.resourceIdForKey(resourceKey));
    expect(wireframe.resourceId, randomId);
  });

  testWidgets('large images build placeholder wireframe', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);
    final width = 900;
    final height = 900;

    ui.Image? testImage = await tester.runAsync(() {
      return createTestImage(width: width.round(), height: height.round());
    });

    final imageProvider = TestImageProvider(testImage!);
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: y,
              left: x,
              width: width.toDouble(),
              height: height.toDouble(),
              child: Image(image: imageProvider),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);
    imageProvider.complete();
    await tester.pump();

    // When
    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    // Then
    expect(capture!.viewTreeSnapshot.nodes.length, 1);

    final capturedImageNode = capture!.viewTreeSnapshot.nodes.last;
    final builtWireframes = capturedImageNode.buildWireframes();
    expect(builtWireframes.length, 1);
    final wireframe = builtWireframes.first as SRPlaceholderWireframe;

    expect(wireframe.x, x.round());
    expect(wireframe.y, y.round());
    expect(wireframe.width, width.round());
    expect(wireframe.height, height.round());
    expect(wireframe.label, 'Large Image');

    testImage.dispose();
  });

  testWidgets('captured image below width has no label', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);
    final width = 900;
    final height = 900;

    ui.Image? testImage = await tester.runAsync(() {
      return createTestImage(width: width.round(), height: height.round());
    });

    final imageProvider = TestImageProvider(testImage!);
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: y,
              left: x,
              width: 100.0,
              height: 40.0,
              child: Image(image: imageProvider),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);
    imageProvider.complete();
    await tester.pump();

    // When
    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    // Then
    expect(capture!.viewTreeSnapshot.nodes.length, 1);

    final capturedImageNode = capture!.viewTreeSnapshot.nodes.last;
    final builtWireframes = capturedImageNode.buildWireframes();
    expect(builtWireframes.length, 1);
    final wireframe = builtWireframes.first as SRPlaceholderWireframe;

    expect(wireframe.label, isNull);
  });

  group('Caching tests', () {
    testWidgets(
      'same-content images skip duplicate saveImageForProcessing',
      (tester) async {
        // Given - two different ui.Image instances with identical pixel content
        ui.Image? image1 = await tester.runAsync(() {
          return createTestImage(width: 20, height: 20);
        });
        ui.Image? image2 = await tester.runAsync(() {
          return createTestImage(width: 20, height: 20);
        });
        when(
          () => platform.saveImageForProcessing(any(), any(), any(), any()),
        ).thenAnswer((_) async {});

        final provider1 = TestImageProvider(image1!);
        final provider2 = TestImageProvider(image2!);

        final tree = MaterialApp(
          home: SimpleTestCapture(
            key: Key('key'),
            recorder: recorder,
            child: Stack(
              children: [
                Positioned(
                  top: 10.0,
                  left: 10.0,
                  width: 20.0,
                  height: 20.0,
                  child: Image(image: provider1),
                ),
                Positioned(
                  top: 40.0,
                  left: 10.0,
                  width: 20.0,
                  height: 20.0,
                  child: Image(image: provider2),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(tree);

        // Load image1 first and capture — saveImageForProcessing called once
        provider1.complete();
        await tester.pump();
        await tester.runAsync(() async {
          await recorder.performCapture();
        });

        // Load image2 (same content, different instance) and capture again
        provider2.complete();
        await tester.pump();
        await tester.runAsync(() async {
          await recorder.performCapture();
        });

        // Then saveImageForProcessing was only called once total
        verify(
          () => platform.saveImageForProcessing(any(), any(), any(), any()),
        ).called(1);

        image1.dispose();
        image2.dispose();
      },
    );

    testWidgets(
      'resourceId native call is cached after first resolution',
      (tester) async {
        // Given
        when(
          () => platform.saveImageForProcessing(any(), any(), any(), any()),
        ).thenAnswer((_) async {});
        final resourceIdValue = randomString();
        when(() => platform.resourceIdForKey(any())).thenReturn(resourceIdValue);

        final provider = TestImageProvider(testImage);
        final tree = MaterialApp(
          home: SimpleTestCapture(
            key: Key('key'),
            recorder: recorder,
            child: Stack(
              children: [
                Positioned(
                  top: 10.0,
                  left: 10.0,
                  width: testImage.width.toDouble(),
                  height: testImage.height.toDouble(),
                  child: Image(image: provider),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(tree);
        provider.complete();
        await tester.pump();

        CaptureResult? capture;
        await tester.runAsync(() async {
          capture = await recorder.performCapture();
        });

        // When - call buildWireframes multiple times
        final node = capture!.viewTreeSnapshot.nodes.last as ResourceImageNode;
        node.buildWireframes(); // First call — queries native and caches
        node.buildWireframes(); // Second call — should use Dart cache
        node.buildWireframes(); // Third call — should still use Dart cache

        // Then resourceIdForKey was only called once despite three invocations
        verify(() => platform.resourceIdForKey(any())).called(1);
      },
    );
  });

  /// Masking tests can avoid using the full recorder because we don't
  /// need to test widget positioning
  group('Masking tests', () {
    testWidgets('maskAll does not process images', (tester) async {
      // Given
      recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
        imagePrivacyLevel: ImagePrivacyLevel.maskAll,
      );
      final x = randomDouble(min: 10, max: 50);
      final y = randomDouble(min: 10, max: 50);

      final imageProvider = TestImageProvider(testImage);
      final tree = MaterialApp(
        home: SimpleTestCapture(
          key: Key('key'),
          recorder: recorder,
          child: Stack(
            children: [
              Positioned(
                top: y,
                left: x,
                width: 250.0,
                height: 40.0,
                child: Image(image: imageProvider),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree);
      imageProvider.complete();
      await tester.pump();

      // When
      CaptureResult? capture;
      await tester.runAsync(() async {
        capture = await recorder.performCapture();
      });

      // Then
      expect(capture!.viewTreeSnapshot.nodes.length, 1);

      final capturedImageNode = capture!.viewTreeSnapshot.nodes.last;
      final builtWireframes = capturedImageNode.buildWireframes();
      expect(builtWireframes.length, 1);
      final wireframe = builtWireframes.first as SRPlaceholderWireframe;

      expect(wireframe.label, 'Image');
      verifyZeroInteractions(platform);
    });

    // Missing Test - ImagePrivacyLevel.maskNonAssetsOnly checks for Assets.
    // This requires being able to load an asset, so it is checked as part of the
    // golden tests, not here.

    testWidgets('maskNonAssetsOnly does not process non-asset', (tester) async {
      // Given
      recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      );
      final x = randomDouble(min: 10, max: 50);
      final y = randomDouble(min: 10, max: 50);

      final imageProvider = TestImageProvider(testImage);
      final tree = MaterialApp(
        home: SimpleTestCapture(
          key: Key('key'),
          recorder: recorder,
          child: Stack(
            children: [
              Positioned(
                top: y,
                left: x,
                width: 250.0,
                height: 40.0,
                child: Image(image: imageProvider),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree);
      imageProvider.complete();
      await tester.pump();

      // When
      CaptureResult? capture;
      await tester.runAsync(() async {
        capture = await recorder.performCapture();
      });

      // Then
      expect(capture!.viewTreeSnapshot.nodes.length, 1);

      final capturedImageNode = capture!.viewTreeSnapshot.nodes.last;
      final builtWireframes = capturedImageNode.buildWireframes();
      expect(builtWireframes.length, 1);
      final wireframe = builtWireframes.first as SRPlaceholderWireframe;

      expect(wireframe.label, 'Image');
      verifyZeroInteractions(platform);
    });
  });
}
