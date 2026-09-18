// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/cupertino_widgets/cupertino_radio_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/material_widgets/radio_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/extensions.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../simple_test_capture.dart';

SimpleTestCapture captureRadio(
  SessionReplayRecorder recorder,
  Widget radio, {
  int? groupValue,
}) {
  Widget content = radio;
  if (groupValue != null) {
    content = RadioGroup<int>(
      groupValue: groupValue,
      onChanged: (_) {},
      child: radio,
    );
  }
  return SimpleTestCapture(
    key: Key('key'),
    recorder: recorder,
    child: MaterialApp(
      home: Scaffold(
        body: Center(child: content),
      ),
    ),
  );
}

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;

  setUp(() {
    recorder = SessionReplayRecorder.withCustomRecorders(
      [
        RadioRecorder(KeyGenerator()),
        CupertinoRadioRecorder(KeyGenerator()),
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

  List<SRWireframe> wireframesOf(CaptureResult? capture) {
    return capture!.viewTreeSnapshot.nodes.first.buildWireframes();
  }

  SRShapeWireframe outerRingOf(CaptureResult? capture) {
    return wireframesOf(capture).first as SRShapeWireframe;
  }

  SRShapeWireframe innerDotOf(CaptureResult? capture) {
    return wireframesOf(capture)[1] as SRShapeWireframe;
  }

  void metaTestWidgets(
    String testDescription,
    List<Widget Function()> setups,
    void Function(CaptureResult?) checks, {
    VoidCallback? beforeEach,
  }) {
    for (final setup in setups) {
      testWidgets(testDescription, (tester) async {
        // Given
        beforeEach?.call();
        final tree = setup();
        await tester.pumpWidget(tree);

        // When
        final capture = await recorder.performCapture();

        // Then
        checks(capture);
      });
    }
  }

  group('wireframe count', () {
    metaTestWidgets(
      'selected radio produces 2 wireframes',
      [
        () => captureRadio(recorder, Radio<int>(value: 1), groupValue: 1),
        () => captureRadio(recorder, CupertinoRadio<int>(value: 1),
            groupValue: 1),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframesOf(capture).length, 2);
      },
    );

    metaTestWidgets(
      'unselected radio produces 1 wireframe',
      [
        () => captureRadio(recorder, Radio<int>(value: 1), groupValue: 2),
        () => captureRadio(recorder, CupertinoRadio<int>(value: 1),
            groupValue: 2),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframesOf(capture).length, 1);
      },
    );

    metaTestWidgets(
      'disabled radio produces 1 wireframe',
      [
        () => captureRadio(recorder, Radio<int>(value: 1)),
        () => captureRadio(recorder, CupertinoRadio<int>(value: 1)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframesOf(capture).length, 1);
      },
    );
  });

  group('fill color', () {
    testWidgets('material radio selected inner dot uses fill color',
        (tester) async {
      // Given
      final fill = WidgetStateProperty.all<Color?>(Colors.red);
      final tree = captureRadio(
        recorder,
        Radio<int>(value: 1, fillColor: fill),
        groupValue: 1,
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(innerDotOf(capture).shapeStyle!.backgroundColor,
          Colors.red.toHexString());
    });

    testWidgets('cupertino radio selected inner dot uses fill color',
        (tester) async {
      // Given
      final tree = captureRadio(
        recorder,
        CupertinoRadio<int>(value: 1, fillColor: Colors.red),
        groupValue: 1,
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(innerDotOf(capture).shapeStyle!.backgroundColor,
          Colors.red.toHexString());
    });
  });

  group('background color', () {
    testWidgets('material radio background is transparent by default',
        (tester) async {
      // Given
      final tree = captureRadio(
        recorder,
        Radio<int>(value: 1),
        groupValue: 2,
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(outerRingOf(capture).shapeStyle!.backgroundColor,
          Colors.transparent.toHexString());
    });

    testWidgets('material radio background uses backgroundColor',
        (tester) async {
      // Given
      final bgColor = WidgetStateProperty.all<Color?>(Colors.yellow);
      final tree = captureRadio(
        recorder,
        Radio<int>(value: 1, backgroundColor: bgColor),
        groupValue: 1,
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(outerRingOf(capture).shapeStyle!.backgroundColor,
          Colors.yellow.toHexString());
    });

    testWidgets('cupertino radio selected background uses activeColor',
        (tester) async {
      // Given
      final tree = captureRadio(
        recorder,
        CupertinoRadio<int>(value: 1, activeColor: Colors.purple),
        groupValue: 1,
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(outerRingOf(capture).shapeStyle!.backgroundColor,
          Colors.purple.toHexString());
    });

    testWidgets('cupertino radio unselected background uses inactiveColor',
        (tester) async {
      // Given
      final tree = captureRadio(
        recorder,
        CupertinoRadio<int>(value: 1, inactiveColor: Colors.orange),
        groupValue: 2,
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(outerRingOf(capture).shapeStyle!.backgroundColor,
          Colors.orange.toHexString());
    });
  });

  group('border', () {
    testWidgets('radio unselected outer ring uses custom side', (tester) async {
      // Given
      final tree = captureRadio(
        recorder,
        Radio<int>(
          value: 1,
          side: BorderSide(color: Colors.green, width: 3),
        ),
        groupValue: 2,
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then — resolveSide returns the BorderSide for unselected state
      expect(capture, isNotNull);
      final ring = outerRingOf(capture);
      expect(ring.border!.color, Colors.green.toHexString());
      expect(ring.border!.width, 3);
    });

    testWidgets('radio selected outer ring border defaults to fill color',
        (tester) async {
      // Given — resolveSide returns null for selected state, falling back to fillColor as border
      final fill = WidgetStateProperty.all<Color?>(Colors.blue);
      final tree = captureRadio(
        recorder,
        Radio<int>(
          value: 1,
          fillColor: fill,
          side: BorderSide(color: Colors.green, width: 3),
        ),
        groupValue: 1,
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(outerRingOf(capture).border!.color, Colors.blue.toHexString());
    });
  });

  group('layout and size', () {
    metaTestWidgets(
      'radio produces a single capture node',
      [
        () => captureRadio(recorder, Radio<int>(value: 1), groupValue: 1),
        () => captureRadio(recorder, CupertinoRadio<int>(value: 1),
            groupValue: 1),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(capture!.viewTreeSnapshot.nodes.length, 1);
      },
    );

    testWidgets('material radio default size is 18x18', (tester) async {
      // Given — outer radius 8.0 + strokeAlignCenter border (width 2.0) → visual radius 9.0 → diameter 18
      final tree = captureRadio(recorder, Radio<int>(value: 1));
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final ring = outerRingOf(capture);
      expect(ring.width, 18);
      expect(ring.height, 18);
    });

    testWidgets('cupertino radio default size is 14x14', (tester) async {
      // Given — outer radius 7.0 → diameter 14
      final tree = captureRadio(recorder, CupertinoRadio<int>(value: 1));
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final ring = outerRingOf(capture);
      expect(ring.width, 14);
      expect(ring.height, 14);
    });
  });

  group('privacy', () {
    metaTestWidgets(
      'maskAllInputs shows selected radio as unselected',
      [
        () => captureRadio(recorder, Radio<int>(value: 1), groupValue: 1),
        () => captureRadio(recorder, CupertinoRadio<int>(value: 1),
            groupValue: 1),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframesOf(capture).length, 1);
      },
      beforeEach: () => recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
    );

    metaTestWidgets(
      'maskAll shows selected radio as unselected',
      [
        () => captureRadio(recorder, Radio<int>(value: 1), groupValue: 1),
        () => captureRadio(recorder, CupertinoRadio<int>(value: 1),
            groupValue: 1),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframesOf(capture).length, 1);
      },
      beforeEach: () => recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
    );

    metaTestWidgets(
      'maskSensitiveInputs does not mask selected radio',
      [
        () => captureRadio(recorder, Radio<int>(value: 1), groupValue: 1),
        () => captureRadio(recorder, CupertinoRadio<int>(value: 1),
            groupValue: 1),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframesOf(capture).length, 2);
      },
      beforeEach: () => recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
    );
  });
}
