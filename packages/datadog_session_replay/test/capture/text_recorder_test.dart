// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// Note: to properly test recorders, we need to supply a full widget tree, as Element
// is too difficult to mock effectively.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/container_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/text_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/capture/text_masking.dart';
import 'package:datadog_session_replay/src/extensions.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';
import 'simple_test_capture.dart';

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;

  setUp(() {
    recorder = SessionReplayRecorder.withCustomRecorders(
      [TextElementRecorder(KeyGenerator())],
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
    );

    registerFallbackValue(
      CapturedViewAttributes(paintBounds: Rect.zero, scaleX: 1.0, scaleY: 1.0),
    );

    context = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
    );
    recorder.updateContext(context);
  });

  group('simple text', () {
    testWidgets('text returns captured node semantics', (tester) async {
      // Given
      final textData = randomString();
      final tree = SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(children: [Text(textData)]),
        ),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      expect(treeCapture.nodes.length, 1);
      final textNode = treeCapture.nodes.first;
      expect(textNode.attributes.x, 0);
      expect(textNode.attributes.y, 0);
      // Don't check width / height here as that would require measuring
      // the string.

      final builtWireframes = textNode.buildWireframes();
      expect(builtWireframes.length, 1);
      final shapeWireframe = builtWireframes.first as SRTextWireframe;
      expect(shapeWireframe.x, 0);
      expect(shapeWireframe.y, 0);
      expect(shapeWireframe.text, textData);
      expect(shapeWireframe.textStyle.color, '#000000ff');
      expect(shapeWireframe.textPosition?.alignment, isNotNull);
      expect(
        shapeWireframe.textPosition?.alignment?.horizontal,
        SRHorizontalAlignment.left,
      );
    });

    testWidgets('text returns text style (font and color)', (tester) async {
      // Given
      final textData = randomString();
      final style = TextStyle(
        color: randomColor(),
        fontSize: randomDouble(min: 12, max: 40),
      );
      final tree = SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(children: [Text(textData, style: style)]),
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
      final shapeWireframe = builtWireframes.first as SRTextWireframe;
      expect(shapeWireframe.text, textData);
      expect(shapeWireframe.textStyle.color, style.color!.toHexString());
      expect(shapeWireframe.textStyle.size, style.fontSize!.round());
    });

    testWidgets('text returns proper positioning', (tester) async {
      // Given
      final textData = randomString();
      final x = randomDouble(min: 0, max: 200);
      final y = randomDouble(min: 0, max: 200);

      final tree = SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [Positioned(left: x, top: y, child: Text(textData))],
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
      expect(textNode.attributes.x, x.round());
      expect(textNode.attributes.y, y.round());
    });

    testWidgets('text is masked with maskAll', (tester) async {
      // Given
      recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
        imagePrivacyLevel: ImagePrivacyLevel.maskAll,
      );
      final textData = randomString();
      final x = randomDouble(min: 0, max: 200);
      final y = randomDouble(min: 0, max: 200);

      final tree = SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [Positioned(left: x, top: y, child: Text(textData))],
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
      final wireframes = textNode.buildWireframes();
      final textWireframe = wireframes.first as SRTextWireframe;
      expect(textWireframe.text, maskTextPreservingSpaces(textData));
    });
  });

  testWidgets('text scale is modified transform', (tester) async {
    // Given
    final textData = randomString();

    final tree = SimpleTestCapture(
      key: Key('key'),
      recorder: recorder,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Text(textData),
            Transform(
              transform: Matrix4.identity()..scaleByDouble(0.5, 0.5, 0.5, 1.0),
              child: Text(textData),
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
    final firstTextNode = treeCapture.nodes[0];
    final secondTextNode = treeCapture.nodes[1];

    final firstWireframe =
        firstTextNode.buildWireframes().first as SRTextWireframe;
    final secondWireframe =
        secondTextNode.buildWireframes().first as SRTextWireframe;
    expect(secondWireframe.width, (firstWireframe.width ~/ 2));
    expect(secondWireframe.height, (firstWireframe.height ~/ 2));
    expect(
      secondWireframe.textStyle.size,
      (firstWireframe.textStyle.size ~/ 2),
    );
  });

  group('rich text', () {
    testWidgets('text span tree is concatenated to single record', (
      tester,
    ) async {
      // Given
      final textData = randomString();
      final innerStrings = [randomString(), randomString()];
      final tree = SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Text.rich(
                TextSpan(
                  text: textData,
                  children: innerStrings.map((e) => TextSpan(text: e)).toList(),
                ),
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
      final shapeWireframe = builtWireframes.first as SRTextWireframe;
      expect(shapeWireframe.text, textData + innerStrings.join());
    });

    testWidgets('text span tree ignores widget spans in text', (tester) async {
      // Given
      final textData = randomString();
      final innerStrings = [randomString(), randomString()];
      final tree = SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Text.rich(
                TextSpan(
                  text: textData,
                  children: [
                    TextSpan(text: innerStrings[0]),
                    WidgetSpan(child: SizedBox(width: 10, height: 10)),
                    TextSpan(text: innerStrings[1]),
                  ],
                ),
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
      final shapeWireframe = builtWireframes.first as SRTextWireframe;
      expect(shapeWireframe.text, textData + innerStrings.join());
    });

    testWidgets('text span tree captures inline widgets', (tester) async {
      // Given
      // Use a different recorder that is capable of capturing containers.
      final keyGenerator = KeyGenerator();
      recorder = SessionReplayRecorder.withCustomRecorders(
        [TextElementRecorder(keyGenerator), ContainerRecorder(keyGenerator)],
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
        ),
        touchPrivacyLevel: TouchPrivacyLevel.show,
      );
      recorder.updateContext(context);

      final textData = randomString();
      final innerStrings = [randomString(), randomString()];
      final containerColor = randomColor();
      final tree = SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Text.rich(
                TextSpan(
                  text: textData,
                  children: [
                    TextSpan(text: innerStrings[0]),
                    WidgetSpan(
                      child: Container(
                        width: 10,
                        height: 10,
                        color: containerColor,
                      ),
                    ),
                    TextSpan(text: innerStrings[1]),
                  ],
                ),
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
      expect(treeCapture.nodes.length, 2);
      final containerNode = treeCapture.nodes.last;
      final containerWireframe =
          containerNode.buildWireframes().first as SRShapeWireframe;

      expect(containerWireframe.width, 10);
      expect(containerWireframe.height, 10);
      expect(
        containerWireframe.shapeStyle!.backgroundColor,
        containerColor.toHexString(),
      );
    });

    testWidgets('text span tree is masked with maskAll', (tester) async {
      // Given
      // Use a different recorder that is capable of capturing containers.
      final keyGenerator = KeyGenerator();
      recorder = SessionReplayRecorder.withCustomRecorders(
        [TextElementRecorder(keyGenerator), ContainerRecorder(keyGenerator)],
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
          imagePrivacyLevel: ImagePrivacyLevel.maskAll,
        ),
        touchPrivacyLevel: TouchPrivacyLevel.show,
      );
      recorder.updateContext(context);

      final textData = randomString();
      final innerStrings = [randomString(), randomString()];
      final containerColor = randomColor();
      final tree = SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              Text.rich(
                TextSpan(
                  text: textData,
                  children: [
                    TextSpan(text: innerStrings[0]),
                    WidgetSpan(
                      child: Container(
                        width: 10,
                        height: 10,
                        color: containerColor,
                      ),
                    ),
                    TextSpan(text: innerStrings[1]),
                  ],
                ),
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
      expect(treeCapture.nodes.length, 2);
      final textNode = treeCapture.nodes.first;

      final testString = textData + innerStrings.join();
      final textWireframeA =
          textNode.buildWireframes().first as SRTextWireframe;
      expect(textWireframeA.text, maskTextPreservingSpaces(testString));
    });
  });
}
