// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';
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
      [
        ImageRecorder(
          keyGenerator,
          imageDownscaling: ImageDownscaling.enabled,
        ),
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
    ).thenAnswer((_) => Future.value());

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
    final resourceKey = verify(
      () => platform.saveImageForProcessing(
        captureAny(),
        testImage.width,
        testImage.height,
        any(),
      ),
    ).captured.first as int;
    expect(capturedImageNode.resourceKey, resourceKey);
  });

  testWidgets('captured image uses identifier from platform', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);

    when(
      () => platform.saveImageForProcessing(any(), any(), any(), any()),
    ).thenAnswer((_) => Future.value());
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
    final resourceKey = verify(
      () => platform.saveImageForProcessing(
        captureAny(),
        testImage.width,
        testImage.height,
        any(),
      ),
    ).captured.first as int;

    final builtWireframes = capturedImageNode.buildWireframes();
    expect(builtWireframes.length, 1);
    final wireframe = builtWireframes.first as SRImageWireframe;
    verify(() => platform.resourceIdForKey(resourceKey));
    expect(wireframe.resourceId, randomId);
  });

  testWidgets('large images are downscaled when enabled', (tester) async {
    int? savedW;
    int? savedH;
    when(
      () => platform.saveImageForProcessing(any(), any(), any(), any()),
    ).thenAnswer((invocation) {
      savedW = invocation.positionalArguments[1] as int;
      savedH = invocation.positionalArguments[2] as int;
      return Future.value();
    });

    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);
    const width = 900;
    const height = 900;

    ui.Image? bigImage = await tester.runAsync(() {
      return createTestImage(width: width, height: height);
    });

    final imageProvider = TestImageProvider(bigImage!);
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

    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    expect(capture!.viewTreeSnapshot.nodes.length, 1);
    final capturedImageNode =
        capture!.viewTreeSnapshot.nodes.last as ResourceImageNode;
    expect(capturedImageNode, isA<ResourceImageNode>());

    verify(
      () => platform.saveImageForProcessing(
        capturedImageNode.resourceKey,
        any(),
        any(),
        any(),
      ),
    );
    expect(savedW! * savedH!, lessThanOrEqualTo(defaultMaxImagePixelBudget));
    expect(savedW! / savedH!, closeTo(width / height, 0.02));

    bigImage.dispose();
  });

  testWidgets(
      'images larger than paint bounds are downscaled to DPR-scaled bounds',
      (tester) async {
    when(
      () => platform.saveImageForProcessing(any(), any(), any(), any()),
    ).thenAnswer((_) => Future.value());

    ui.Image? bigImage = await tester.runAsync(() {
      return createTestImage(width: 1000, height: 1000);
    });

    final imageProvider = TestImageProvider(bigImage!);
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              width: 200,
              height: 200,
              child: Image(image: imageProvider),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);
    imageProvider.complete();
    await tester.pump();

    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    expect(capture!.viewTreeSnapshot.nodes.length, 1);
    final node = capture!.viewTreeSnapshot.nodes.last as ResourceImageNode;
    final a = node.attributes;
    final expected = ImageRecorder.downscaleSizeTarget(
      1000,
      1000,
      CapturedViewAttributes(
        paintBounds: a.paintBounds,
        scaleX: a.scaleX,
        scaleY: a.scaleY,
      ),
      tester.view.devicePixelRatio,
      defaultMaxImagePixelBudget,
    );
    final expectedW = expected.$2;
    final expectedH = expected.$3;

    verify(
      () => platform.saveImageForProcessing(
        node.resourceKey,
        expectedW,
        expectedH,
        any(),
      ),
    );

    bigImage.dispose();
  });

  testWidgets('normal-sized image is not downscaled', (tester) async {
    when(
      () => platform.saveImageForProcessing(any(), any(), any(), any()),
    ).thenAnswer((_) => Future.value());

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

    CaptureResult? capture;
    await tester.runAsync(() async {
      capture = await recorder.performCapture();
    });

    expect(capture, isNotNull);
    verify(
      () => platform.saveImageForProcessing(
        any(),
        testImage.width,
        testImage.height,
        any(),
      ),
    );
  });

  group('downscaleSizeTarget', () {
    test(
        'returns none with source dimensions when native fits painted bounds and budget',
        () {
      final attrs = CapturedViewAttributes(
        paintBounds: Rect.fromLTWH(0, 0, 200, 200),
        scaleX: 1,
        scaleY: 1,
      );
      final result = ImageRecorder.downscaleSizeTarget(
        50,
        50,
        attrs,
        1.0,
        defaultMaxImagePixelBudget,
      );
      expect(result.$1, DownscalingNeed.none);
      expect(result.$2, 50);
      expect(result.$3, 50);
    });

    test(
        'scales down to painted size when under pixel budget (no budget clamp)',
        () {
      final attrs = CapturedViewAttributes(
        paintBounds: Rect.fromLTWH(0, 0, 400, 400),
        scaleX: 1,
        scaleY: 1,
      );
      final (_, w, h) = ImageRecorder.downscaleSizeTarget(
        800,
        800,
        attrs,
        1.0,
        defaultMaxImagePixelBudget,
      );
      expect(w, 400);
      expect(h, 400);
    });

    test('clamps to pixel budget preserving aspect ratio', () {
      final attrs = CapturedViewAttributes(
        paintBounds: Rect.fromLTWH(0, 0, 900, 900),
        scaleX: 1,
        scaleY: 1,
      );
      final (_, w, h) = ImageRecorder.downscaleSizeTarget(
        900,
        900,
        attrs,
        1.0,
        defaultMaxImagePixelBudget,
      );
      expect(w * h, lessThanOrEqualTo(defaultMaxImagePixelBudget));
      expect(w, 800);
      expect(h, 800);
    });

    test('fits to render bounds times DPR without exceeding source size', () {
      final attrs = CapturedViewAttributes(
        paintBounds: Rect.fromLTWH(0, 0, 200, 200),
        scaleX: 1,
        scaleY: 1,
      );
      final (_, w, h) = ImageRecorder.downscaleSizeTarget(
        1000,
        1000,
        attrs,
        3.0,
        defaultMaxImagePixelBudget,
      );
      expect(w, 600);
      expect(h, 600);
    });

    test('applies budget clamp after fitting to painted bounds', () {
      final attrs = CapturedViewAttributes(
        paintBounds: Rect.fromLTWH(0, 0, 900, 900),
        scaleX: 1,
        scaleY: 1,
      );
      const tightBudget = 10000;
      final (_, w, h) = ImageRecorder.downscaleSizeTarget(
        900,
        900,
        attrs,
        1.0,
        tightBudget,
      );
      expect(w * h, lessThanOrEqualTo(tightBudget));
    });
  });

  group('ImageDownscaling.disabled: decoded pixel budget vs on-screen bounds',
      () {
    const fixtureMaxPixelBudget = defaultMaxImagePixelBudget;

    void useDisabledRecorder() {
      final keyGenerator = KeyGenerator();
      recorder = SessionReplayRecorder.withCustomRecorders(
        [
          ImageRecorder(
            keyGenerator,
            imageDownscaling: ImageDownscaling.disabled,
            maxImagePixelBudget: fixtureMaxPixelBudget,
          ),
        ],
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNone,
        ),
        touchPrivacyLevel: TouchPrivacyLevel.show,
      );
      recorder.updateContext(context);
    }

    testWidgets(
      'below budget decoded, painted smaller: uploads native pixel dimensions',
      (WidgetTester tester) async {
        when(() => platform.saveImageForProcessing(any(), any(), any(), any()))
            .thenAnswer((_) => Future.value());
        final randomId = randomString();
        when(() => platform.resourceIdForKey(any())).thenReturn(randomId);
        useDisabledRecorder();

        const nativeSide = 200;
        final dpr = tester.view.devicePixelRatio;
        final logicalPaint = (nativeSide - 2) / dpr;
        expect((logicalPaint * dpr).ceil(), lessThan(nativeSide));

        final x = randomDouble(min: 10, max: 50);
        final y = randomDouble(min: 10, max: 50);
        ui.Image? img = await tester.runAsync(() {
          return createTestImage(width: nativeSide, height: nativeSide);
        });

        final imageProvider = TestImageProvider(img!);
        final tree = MaterialApp(
          home: SimpleTestCapture(
            key: Key('key'),
            recorder: recorder,
            child: Stack(
              children: [
                Positioned(
                  top: y,
                  left: x,
                  width: logicalPaint,
                  height: logicalPaint,
                  child: Image(image: imageProvider),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(tree);
        imageProvider.complete();
        await tester.pump();

        CaptureResult? capture;
        await tester.runAsync(() async {
          capture = await recorder.performCapture();
        });

        expect(capture!.viewTreeSnapshot.nodes.length, 1);
        final node = capture!.viewTreeSnapshot.nodes.last as ResourceImageNode;
        final resourceKey = verify(
          () => platform.saveImageForProcessing(
            captureAny(),
            nativeSide,
            nativeSide,
            any(),
          ),
        ).captured.first as int;
        expect(node.resourceKey, resourceKey);
        final wireframe = node.buildWireframes().first as SRImageWireframe;
        verify(() => platform.resourceIdForKey(resourceKey));
        expect(wireframe.resourceId, randomId);

        img.dispose();
      },
    );

    testWidgets(
      'below budget decoded, painted larger: uploads native pixel dimensions',
      (WidgetTester tester) async {
        when(() => platform.saveImageForProcessing(any(), any(), any(), any()))
            .thenAnswer((_) => Future.value());
        final randomId = randomString();
        when(() => platform.resourceIdForKey(any())).thenReturn(randomId);
        useDisabledRecorder();

        const nativeSide = 100;
        final x = randomDouble(min: 10, max: 50);
        final y = randomDouble(min: 10, max: 50);
        ui.Image? img = await tester.runAsync(() {
          return createTestImage(width: nativeSide, height: nativeSide);
        });

        const layoutSide = 400.0;

        final imageProvider = TestImageProvider(img!);
        final tree = MaterialApp(
          home: SimpleTestCapture(
            key: Key('key'),
            recorder: recorder,
            child: Stack(
              children: [
                Positioned(
                  top: y,
                  left: x,
                  width: layoutSide,
                  height: layoutSide,
                  child: Image(image: imageProvider),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(tree);
        imageProvider.complete();
        await tester.pump();

        CaptureResult? capture;
        await tester.runAsync(() async {
          capture = await recorder.performCapture();
        });

        expect(capture!.viewTreeSnapshot.nodes.length, 1);
        final node = capture!.viewTreeSnapshot.nodes.last as ResourceImageNode;
        verify(
          () => platform.saveImageForProcessing(
            captureAny(),
            nativeSide,
            nativeSide,
            any(),
          ),
        );
        final wireframe = node.buildWireframes().first as SRImageWireframe;
        verify(() => platform.resourceIdForKey(node.resourceKey));
        expect(wireframe.resourceId, randomId);

        img.dispose();
      },
    );

    testWidgets(
      'over budget decoded, painted smaller: '
      'Large Image placeholder, no upload',
      (WidgetTester tester) async {
        useDisabledRecorder();

        const side = 900;

        final x = randomDouble(min: 10, max: 50);
        final y = randomDouble(min: 10, max: 50);
        ui.Image? img = await tester.runAsync(() {
          return createTestImage(width: side, height: side);
        });

        final imageProvider = TestImageProvider(img!);
        final tree = MaterialApp(
          home: SimpleTestCapture(
            key: Key('key'),
            recorder: recorder,
            child: Stack(
              children: [
                Positioned(
                  top: y,
                  left: x,
                  width: 100,
                  height: 40,
                  child: Image(image: imageProvider),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(tree);
        imageProvider.complete();
        await tester.pump();

        CaptureResult? capture;
        await tester.runAsync(() async {
          capture = await recorder.performCapture();
        });

        expect(capture!.viewTreeSnapshot.nodes.length, 1);
        final wireframe = capture!.viewTreeSnapshot.nodes.last
            .buildWireframes()
            .first as SRPlaceholderWireframe;
        expect(wireframe.label, isNull);
        verifyNever(
          () => platform.saveImageForProcessing(any(), any(), any(), any()),
        );

        img.dispose();
      },
    );

    testWidgets(
      'over budget decoded, painted at native logical size: '
      'Large Image placeholder, no upload',
      (WidgetTester tester) async {
        useDisabledRecorder();

        final x = randomDouble(min: 10, max: 50);
        final y = randomDouble(min: 10, max: 50);
        const width = 900;
        const height = 900;

        ui.Image? big = await tester.runAsync(() {
          return createTestImage(width: width, height: height);
        });

        final imageProvider = TestImageProvider(big!);
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

        CaptureResult? capture;
        await tester.runAsync(() async {
          capture = await recorder.performCapture();
        });

        expect(capture!.viewTreeSnapshot.nodes.length, 1);
        final wireframe = capture!.viewTreeSnapshot.nodes.last
            .buildWireframes()
            .first as SRPlaceholderWireframe;

        expect(wireframe.x, x.round());
        expect(wireframe.y, y.round());
        expect(wireframe.width, width);
        expect(wireframe.height, height);
        expect(wireframe.label, 'Large Image');
        verifyNever(
          () => platform.saveImageForProcessing(any(), any(), any(), any()),
        );

        big.dispose();
      },
    );
  });

  testWidgets(
    'downscale throws non-timeout shows Failed Downscale placeholder',
    (tester) async {
      when(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      ).thenAnswer((_) => Future.value());

      final kg = KeyGenerator();
      recorder = SessionReplayRecorder.withCustomRecorders(
        [
          ImageRecorder(
            kg,
            imageDownscaling: ImageDownscaling.enabled,
            downscaleOverride: (_, __, ___) async =>
                throw StateError('simulated raster failure'),
          ),
        ],
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNone,
        ),
        touchPrivacyLevel: TouchPrivacyLevel.show,
      );
      recorder.updateContext(context);

      const imageSize = 900;
      ui.Image? big = await tester.runAsync(() {
        return createTestImage(width: imageSize, height: imageSize);
      });

      final imageProvider = TestImageProvider(big!);
      final tree = MaterialApp(
        home: SimpleTestCapture(
          key: Key('key'),
          recorder: recorder,
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 10,
                width: imageSize.toDouble(),
                height: imageSize.toDouble(),
                child: Image(image: imageProvider),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree);
      imageProvider.complete();
      await tester.pump();

      CaptureResult? capture;
      await tester.runAsync(() async {
        capture = await recorder.performCapture();
      });

      expect(capture!.viewTreeSnapshot.nodes.length, 1);
      final wf = capture!.viewTreeSnapshot.nodes.last.buildWireframes().first
          as SRPlaceholderWireframe;
      expect(wf.label, 'Failed Downscale');
      verifyNever(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      );

      big.dispose();
    },
  );

  testWidgets(
    'saveImageForProcessing failure shows Error Image placeholder',
    (tester) async {
      when(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      ).thenAnswer((_) => Future<void>.error(StateError('upload failed')));

      final x = randomDouble(min: 10, max: 50);
      final y = randomDouble(min: 10, max: 50);

      final imageProvider = TestImageProvider(testImage);
      const layoutSide = 200.0;
      final tree = MaterialApp(
        home: SimpleTestCapture(
          key: Key('key'),
          recorder: recorder,
          child: Stack(
            children: [
              Positioned(
                top: y,
                left: x,
                width: layoutSide,
                height: layoutSide,
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.fill,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree);
      imageProvider.complete();
      await tester.pump();

      CaptureResult? capture;
      await tester.runAsync(() async {
        capture = await recorder.performCapture();
      });

      expect(capture!.viewTreeSnapshot.nodes.length, 1);
      final wf = capture!.viewTreeSnapshot.nodes.last.buildWireframes().first
          as SRPlaceholderWireframe;
      expect(wf.label, 'Error Image');

      verify(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      ).called(1);
    },
  );

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

    testWidgets('maskNonAssetsOnly processes ExactAssetImage as asset',
        (tester) async {
      // Given
      recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      );

      when(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      ).thenAnswer((_) => Future.value());
      when(() => platform.resourceIdForKey(any())).thenReturn(randomString());

      final imageProvider = TestExactAssetImage(testImage);
      final tree = MaterialApp(
        home: SimpleTestCapture(
          key: Key('key'),
          recorder: recorder,
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 10,
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
      final allWireframes = capture!.viewTreeSnapshot.nodes
          .expand((node) => node.buildWireframes())
          .toList();

      expect(
        allWireframes.whereType<SRPlaceholderWireframe>(),
        isEmpty,
        reason: 'ExactAssetImage should not be masked under maskNonAssetsOnly',
      );
      expect(
        allWireframes.whereType<SRImageWireframe>(),
        isNotEmpty,
        reason: 'ExactAssetImage should produce SRImageWireframe',
      );
    });

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

  group('DownscaleCircuitBreaker', () {
    test('starts not tripped', () {
      final breaker = DownscaleCircuitBreaker();
      expect(breaker.isTripped, isFalse);
    });

    test('stays not tripped below failure threshold', () {
      final breaker = DownscaleCircuitBreaker();
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.isTripped, isFalse);
    });

    test('trips after maxConsecutiveFailures', () {
      final breaker = DownscaleCircuitBreaker();
      for (var i = 0; i < DownscaleCircuitBreaker.maxConsecutiveFailures; i++) {
        breaker.recordFailure();
      }
      expect(breaker.isTripped, isTrue);
    });

    test('success resets failure counter', () {
      final breaker = DownscaleCircuitBreaker();
      breaker.recordFailure();
      breaker.recordFailure();
      breaker.recordSuccess();
      breaker.recordFailure();
      breaker.recordFailure();
      expect(breaker.isTripped, isFalse);
    });

    test('stays tripped after additional failures', () {
      final breaker = DownscaleCircuitBreaker();
      for (var i = 0; i < DownscaleCircuitBreaker.maxConsecutiveFailures; i++) {
        breaker.recordFailure();
      }
      breaker.recordFailure();
      expect(breaker.isTripped, isTrue);
    });
  });

  group('Timeout and circuit breaker integration', () {
    testWidgets(
      'full timeout, recovery, and trip sequence',
      (tester) async {
        var slow = true;
        final circuitBreaker = DownscaleCircuitBreaker();

        ui.Image? smallImage = await tester.runAsync(() {
          return createTestImage(width: 800, height: 800);
        });

        DownscaleFunction makeDownscale() {
          return (ui.Image source, int destW, int destH) async {
            if (slow) {
              throw TimeoutException('simulated slow downscale');
            }
            return smallImage!;
          };
        }

        when(
          () => platform.saveImageForProcessing(any(), any(), any(), any()),
        ).thenAnswer((_) => Future.value());

        const imageSize = 900;
        ui.Image? bigImage = await tester.runAsync(() {
          return createTestImage(width: imageSize, height: imageSize);
        });

        final imageProvider = TestImageProvider(bigImage!);
        var imageCompleted = false;

        int stepKey = 0;
        Future<CaptureResult?> captureStep() async {
          stepKey++;
          final kg = KeyGenerator();
          recorder = SessionReplayRecorder.withCustomRecorders(
            [
              ImageRecorder(
                kg,
                imageDownscaling: ImageDownscaling.enabled,
                circuitBreaker: circuitBreaker,
                downscaleOverride: makeDownscale(),
                downscaleTimeout: const Duration(milliseconds: 50),
              ),
            ],
            defaultCapturePrivacy: TreeCapturePrivacy(
              textAndInputPrivacyLevel:
                  TextAndInputPrivacyLevel.maskSensitiveInputs,
              imagePrivacyLevel: ImagePrivacyLevel.maskNone,
            ),
            touchPrivacyLevel: TouchPrivacyLevel.show,
          );
          recorder.updateContext(context);

          final tree = MaterialApp(
            home: SimpleTestCapture(
              key: Key('step$stepKey'),
              recorder: recorder,
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    width: imageSize.toDouble(),
                    height: imageSize.toDouble(),
                    child: Image(image: imageProvider),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpWidget(tree);
          if (!imageCompleted) {
            imageProvider.complete();
            imageCompleted = true;
          }
          await tester.pump();

          CaptureResult? result;
          await tester.runAsync(() async {
            result = await recorder.performCapture();
          });
          return result;
        }

        SRPlaceholderWireframe expectPlaceholder(CaptureResult? result) {
          expect(result, isNotNull);
          expect(result!.viewTreeSnapshot.nodes.length, 1);
          final node = result.viewTreeSnapshot.nodes.last;
          final wfs = node.buildWireframes();
          expect(wfs.length, 1);
          return wfs.first as SRPlaceholderWireframe;
        }

        void expectResource(CaptureResult? result) {
          expect(result, isNotNull);
          expect(result!.viewTreeSnapshot.nodes.length, 1);
          expect(
            result.viewTreeSnapshot.nodes.last,
            isA<ResourceImageNode>(),
          );
        }

        // Step 1: slow -> timeout -> "Slow Device" (failures: 1)
        slow = true;
        var wf = expectPlaceholder(await captureStep());
        expect(wf.label, 'Slow Device');
        expect(circuitBreaker.isTripped, isFalse);

        // Step 2: fast -> success -> ResourceImageNode (failures: 0)
        slow = false;
        expectResource(await captureStep());
        expect(circuitBreaker.isTripped, isFalse);

        // Step 3: slow -> timeout -> "Slow Device" (failures: 1)
        slow = true;
        wf = expectPlaceholder(await captureStep());
        expect(wf.label, 'Slow Device');
        expect(circuitBreaker.isTripped, isFalse);

        // Step 4: slow -> timeout -> "Slow Device" (failures: 2)
        wf = expectPlaceholder(await captureStep());
        expect(wf.label, 'Slow Device');
        expect(circuitBreaker.isTripped, isFalse);

        // Step 5: slow -> timeout -> "Slow Device" (failures: 3, trips!)
        wf = expectPlaceholder(await captureStep());
        expect(wf.label, 'Slow Device');
        expect(circuitBreaker.isTripped, isTrue);

        // Step 6: circuit broken -> "Slow Device" (stays tripped, mock not called)
        var downscaleCalled = false;
        final kg6 = KeyGenerator();
        recorder = SessionReplayRecorder.withCustomRecorders(
          [
            ImageRecorder(
              kg6,
              imageDownscaling: ImageDownscaling.enabled,
              circuitBreaker: circuitBreaker,
              downscaleOverride: (_, __, ___) async {
                downscaleCalled = true;
                return smallImage!;
              },
              downscaleTimeout: const Duration(milliseconds: 50),
            ),
          ],
          defaultCapturePrivacy: TreeCapturePrivacy(
            textAndInputPrivacyLevel:
                TextAndInputPrivacyLevel.maskSensitiveInputs,
            imagePrivacyLevel: ImagePrivacyLevel.maskNone,
          ),
          touchPrivacyLevel: TouchPrivacyLevel.show,
        );
        recorder.updateContext(context);
        final tree6 = MaterialApp(
          home: SimpleTestCapture(
            key: Key('step6'),
            recorder: recorder,
            child: Stack(
              children: [
                Positioned(
                  top: 10,
                  left: 10,
                  width: imageSize.toDouble(),
                  height: imageSize.toDouble(),
                  child: Image(image: imageProvider),
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(tree6);
        await tester.pump();

        CaptureResult? step6Result;
        await tester.runAsync(() async {
          step6Result = await recorder.performCapture();
        });
        wf = expectPlaceholder(step6Result);
        expect(wf.label, 'Slow Device');
        expect(downscaleCalled, isFalse);
        expect(circuitBreaker.isTripped, isTrue);

        bigImage.dispose();
      },
    );
  });
}
