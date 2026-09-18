// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ui' as ui;

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_flutter_plugin/datadog_internal.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/image_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/privacy_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/text_recorder.dart';
import 'package:datadog_session_replay/src/capture/pointer_capture.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/capture/text_masking.dart';
import 'package:datadog_session_replay/src/capture/view_tree_snapshot.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:datadog_session_replay/src/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';
import 'simple_test_capture.dart';

class MockElement extends Mock implements Element {
  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return super.toString();
  }
}

void main() {
  group('SessionReplayPrivacy override behaviors', () {
    test('does not change privacy options with no parameters', () {
      // Given
      final testWidget = SessionReplayPrivacy(child: Placeholder());
      final mockElement = MockElement();
      when(() => mockElement.widget).thenReturn(testWidget);
      final recorder = PrivacyRecorder(KeyGenerator());

      // When
      final capturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      );
      final semantics = recorder.captureSemantics(
        mockElement,
        CapturedViewAttributes(
          paintBounds: Rect.zero,
          scaleX: 1.0,
          scaleY: 1.0,
        ),
        capturePrivacy,
      );

      // Then
      expect(semantics, isNotNull);
      expect(semantics!.subtreePrivacy, capturePrivacy);
      expect(semantics.subtreeStrategy, CaptureNodeSubtreeStrategy.record);
    });

    test('overrides text and input privacy', () {
      // Given
      final testWidget = SessionReplayPrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
        child: Placeholder(),
      );
      final mockElement = MockElement();
      when(() => mockElement.widget).thenReturn(testWidget);
      final recorder = PrivacyRecorder(KeyGenerator());

      // When
      final capturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      );
      final semantics = recorder.captureSemantics(
        mockElement,
        CapturedViewAttributes(
          paintBounds: Rect.zero,
          scaleX: 1.0,
          scaleY: 1.0,
        ),
        capturePrivacy,
      );

      // Then
      expect(semantics, isNotNull);
      expect(
        semantics!.subtreePrivacy!.textAndInputPrivacyLevel,
        TextAndInputPrivacyLevel.maskAll,
      );
      expect(
        semantics.subtreePrivacy!.imagePrivacyLevel,
        ImagePrivacyLevel.maskNone,
      );
      expect(semantics.subtreeStrategy, CaptureNodeSubtreeStrategy.record);
    });

    test('overrides image privacy', () {
      // Given
      final testWidget = SessionReplayPrivacy(
        imagePrivacyLevel: ImagePrivacyLevel.maskAll,
        child: Placeholder(),
      );
      final mockElement = MockElement();
      when(() => mockElement.widget).thenReturn(testWidget);
      final recorder = PrivacyRecorder(KeyGenerator());

      // When
      final capturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      );
      final semantics = recorder.captureSemantics(
        mockElement,
        CapturedViewAttributes(
          paintBounds: Rect.zero,
          scaleX: 1.0,
          scaleY: 1.0,
        ),
        capturePrivacy,
      );

      // Then
      expect(semantics, isNotNull);
      expect(
        semantics!.subtreePrivacy!.textAndInputPrivacyLevel,
        TextAndInputPrivacyLevel.maskSensitiveInputs,
      );
      expect(
        semantics.subtreePrivacy!.imagePrivacyLevel,
        ImagePrivacyLevel.maskAll,
      );
      expect(semantics.subtreeStrategy, CaptureNodeSubtreeStrategy.record);
    });

    test('returns ignore subtree strategy on hide', () {
      final testWidget = SessionReplayPrivacy(hide: true, child: Placeholder());
      final mockElement = MockElement();
      when(() => mockElement.widget).thenReturn(testWidget);
      final recorder = PrivacyRecorder(KeyGenerator());

      // When
      final capturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      );
      final semantics = recorder.captureSemantics(
        mockElement,
        CapturedViewAttributes(
          paintBounds: Rect.zero,
          scaleX: 1.0,
          scaleY: 1.0,
        ),
        capturePrivacy,
      );

      // Then
      expect(semantics, isNotNull);
      expect(semantics!.subtreeStrategy, CaptureNodeSubtreeStrategy.ignore);
    });

    test('returns hidden placeholder on hide of captured size', () {
      final testWidget = SessionReplayPrivacy(hide: true, child: Placeholder());
      final mockElement = MockElement();
      when(() => mockElement.widget).thenReturn(testWidget);
      final recorder = PrivacyRecorder(KeyGenerator());

      // When
      final capturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      );
      final bounds = Rect.fromCenter(
        center: Offset(randomDouble(), randomDouble()),
        width: randomDouble(min: 1),
        height: randomDouble(min: 1),
      );
      final semantics = recorder.captureSemantics(
        mockElement,
        CapturedViewAttributes(paintBounds: bounds, scaleX: 1.0, scaleY: 1.0),
        capturePrivacy,
      );

      // Then
      expect(semantics, isNotNull);
      expect(semantics!.nodes.length, 1);
      final node = semantics.nodes.first as PlaceholderNode;
      expect(node.caption, 'Hidden');
      expect(node.minWidth, greaterThan(0));
      expect(node.attributes.paintBounds, bounds);
    });
  });

  group('SessionReplayPrivacy real widget tests', () {
    late SessionReplayRecorder recorder;
    late RUMContext context;

    late final ui.Image testImage;

    setUpAll(() async {
      final width = randomInt(min: 200, max: 350);
      final height = randomInt(min: 200, max: 350);
      testImage = await createTestImage(
        width: width.toInt(),
        height: height.toInt(),
      );
    });

    tearDownAll(() {
      testImage.dispose();
    });

    setUp(() {
      final keyGenerator = KeyGenerator();
      recorder = SessionReplayRecorder.withCustomRecorders(
        [
          PrivacyRecorder(keyGenerator),
          ImageRecorder(keyGenerator),
          TextElementRecorder(keyGenerator),
        ],
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
        ),
        touchPrivacyLevel: TouchPrivacyLevel.show,
      );

      registerFallbackValue(
        CapturedViewAttributes(
          paintBounds: Rect.zero,
          scaleX: 1.0,
          scaleY: 1.0,
        ),
      );

      context = RUMContext(
        applicationId: randomString(),
        sessionId: randomString(),
      );
      recorder.updateContext(context);
    });

    testWidgets('overriding text privacy affects text elements', (
      tester,
    ) async {
      // Given
      final tree = SimpleTestCapture(
        recorder: recorder,
        key: Key('key'),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              SessionReplayPrivacy(
                textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
                child: Text('Simple Text'),
              ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final textNode = treeCapture.nodes.first;

      final builtWireframes = textNode.buildWireframes();
      expect(builtWireframes.length, 1);
      final textWirefame = builtWireframes.first as SRTextWireframe;
      expect(textWirefame.text, maskTextPreservingSpaces('Simple Text'));
    });

    testWidgets('overriding image privacy affects image elements', (
      tester,
    ) async {
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
                child: SessionReplayPrivacy(
                  imagePrivacyLevel: ImagePrivacyLevel.maskAll,
                  child: Image(image: imageProvider),
                ),
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
    });

    testWidgets('overriding touch privacy prevents touch recording', (
      tester,
    ) async {
      // Given
      final x = randomDouble(min: 10, max: 50);
      final y = randomDouble(min: 10, max: 50);
      final pointerRecorder = PointerSnapshotRecorder(DefaultTimeProvider());

      bool wasTapped = false;
      final tree = MaterialApp(
        home: SimpleTestCapture(
          key: Key('key'),
          recorder: recorder,
          child: PointerSnapshotRecorderProvider(
            recorder: pointerRecorder,
            child: PointerRecorder(
              pointerRecorder: pointerRecorder,
              child: Stack(
                children: [
                  Positioned(
                    top: y,
                    left: x,
                    width: 50.0,
                    height: 50.0,
                    child: SessionReplayPrivacy(
                      touchPrivacyLevel: TouchPrivacyLevel.hide,
                      child: MaterialButton(
                        onPressed: () {
                          wasTapped = true;
                        },
                        child: Text('Test Button'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree);
      await tester.tap(find.byType(MaterialButton));
      await tester.pumpAndSettle();

      // When
      CaptureResult? capture;
      await tester.runAsync(() async {
        capture = await recorder.performCapture();
      });

      // Then
      expect(wasTapped, isTrue);
      expect(capture!.pointerSnapshot, isNull);
    });
  });
}
