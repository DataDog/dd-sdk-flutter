// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/container_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/editable_text_recorder.dart';
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
    final KeyGenerator keyGenerator = KeyGenerator();
    recorder = SessionReplayRecorder.withCustomRecorders(
      [
        TextElementRecorder(keyGenerator),
        ContainerRecorder(keyGenerator),
        EditableTextRecorder(keyGenerator),
        InputDecoratorRecorder(keyGenerator),
      ],
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

  testWidgets('returns elements of EditableText', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);
    final width = randomDouble(min: 10, max: 50);
    final height = randomDouble(min: 20, max: 50);

    final controller = TextEditingController();
    final focusNode = FocusNode();
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: y,
                left: x,
                width: width,
                height: height,
                child: EditableText(
                  controller: controller,
                  focusNode: focusNode,
                  style: TextStyle(),
                  cursorColor: Colors.blue,
                  backgroundCursorColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = await recorder.performCapture();

    // Then
    expect(capture!.viewTreeSnapshot.nodes.length, 2);

    final capturedTextNode = capture.viewTreeSnapshot.nodes.last;
    expect(capturedTextNode.attributes.x, x.round());
    expect(capturedTextNode.attributes.y, y.round());
    expect(capturedTextNode.attributes.width, width.round());
    expect(capturedTextNode.attributes.height, height.round());
  });

  testWidgets('returns decorator elements of TextField', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);
    final width = randomDouble(min: 10, max: 50);
    final height = randomDouble(min: 20, max: 50);
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Scaffold(
          body: Stack(
            children: [
              Positioned(
                top: y,
                left: x,
                width: width,
                height: height,
                child: TextField(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = await recorder.performCapture();

    // Then
    // Here, we get a top level material, the TextField border, and the Editable text
    expect(capture!.viewTreeSnapshot.nodes.length, 3);

    // Input decoration should be captured before editable text
    final capturedTextNode = capture.viewTreeSnapshot.nodes[1];
    expect(capturedTextNode.attributes.x, x.round());
    expect(capturedTextNode.attributes.y, y.round());
    expect(capturedTextNode.attributes.width, width.round());
    expect(capturedTextNode.attributes.height, height.round());
  });

  testWidgets('build wireframes captures text style', (tester) async {
    // Given
    final style = TextStyle(
      color: randomColor(),
      fontFamily: 'Fake Font',
      fontFamilyFallback: ['Fake Fallback A', 'Fake Fallback B'],
      fontSize: randomDouble(min: 12, max: 80),
    );
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Scaffold(body: Stack(children: [TextField(style: style)])),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = await recorder.performCapture();

    // Then
    expect(capture!.viewTreeSnapshot.nodes.length, 3);

    final capturedTextNode = capture.viewTreeSnapshot.nodes.last;
    final wireframes = capturedTextNode.buildWireframes();
    expect(wireframes.length, 1);
    final textWireframe = wireframes.first as SRTextWireframe;
    expect(textWireframe.text, isEmpty);
    expect(textWireframe.textStyle.color, style.color?.toHexString());
    expect(
      textWireframe.textStyle.family,
      'Fake Font,Fake Fallback A,Fake Fallback B',
    );
    expect(textWireframe.textStyle.size, style.fontSize?.round());
  });

  testWidgets('build wireframes captures current text state', (tester) async {
    // Given
    final text = randomString();
    final controller = TextEditingController(text: text);
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Scaffold(
          body: Stack(children: [TextField(controller: controller)]),
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = await recorder.performCapture();

    // Then
    final capturedTextNode = capture!.viewTreeSnapshot.nodes.last;
    final wireframes = capturedTextNode.buildWireframes();
    expect(wireframes.length, 1);
    final textWireframe = wireframes.first as SRTextWireframe;
    expect(textWireframe.text, text);
  });

  testWidgets('captured text is obscured when privacy set to maskAllInputs', (
    tester,
  ) async {
    // Given
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
      imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
    );
    final text = randomString();
    final controller = TextEditingController(text: text);
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Scaffold(
          body: Stack(children: [TextField(controller: controller)]),
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = await recorder.performCapture();

    // Then
    final capturedTextNode = capture!.viewTreeSnapshot.nodes.last;
    final wireframes = capturedTextNode.buildWireframes();
    expect(wireframes.length, 1);
    final textWireframe = wireframes.first as SRTextWireframe;
    expect(textWireframe.text, maskTextFixedLength(text));
  });

  testWidgets('captured text is obscured when privacy set to maskAll', (
    tester,
  ) async {
    // Given
    recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
      textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
    );
    final text = randomString();
    final controller = TextEditingController(text: text);
    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Scaffold(
          body: Stack(children: [TextField(controller: controller)]),
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = await recorder.performCapture();

    // Then
    final capturedTextNode = capture!.viewTreeSnapshot.nodes.last;
    final wireframes = capturedTextNode.buildWireframes();
    expect(wireframes.length, 1);
    final textWireframe = wireframes.first as SRTextWireframe;
    expect(textWireframe.text, maskTextFixedLength(text));
  });

  final maskedTextInputTypes = [
    TextInputType.name,
    TextInputType.phone,
    TextInputType.emailAddress,
    TextInputType.streetAddress,
    TextInputType.visiblePassword,
  ];
  for (final inputType in maskedTextInputTypes) {
    testWidgets('captured text is obscured for $inputType', (tester) async {
      // Given
      final text = randomString();
      final controller = TextEditingController(text: text);
      final tree = MaterialApp(
        home: SimpleTestCapture(
          key: Key('key'),
          recorder: recorder,
          child: Scaffold(
            body: Stack(
              children: [
                TextField(controller: controller, keyboardType: inputType),
              ],
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      final capturedTextNode = capture!.viewTreeSnapshot.nodes.last;
      final wireframes = capturedTextNode.buildWireframes();
      expect(wireframes.length, 1);
      final textWireframe = wireframes.first as SRTextWireframe;
      expect(textWireframe.text, maskTextFixedLength(text));
    });
  }
}
