// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/custom_paint_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'simple_test_capture.dart';

class _FakeCustomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;

  setUp(() {
    recorder = SessionReplayRecorder.withCustomRecorders(
      [CustomPaintRecorder(KeyGenerator())],
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

  testWidgets('returns placeholder for custom paint', (tester) async {
    // Given
    final width = randomDouble(min: 10, max: 50);
    final height = randomDouble(min: 10, max: 50);
    final tree = SimpleTestCapture(
      key: Key('key'),
      recorder: recorder,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            SizedBox(
              width: width,
              height: height,
              child: CustomPaint(painter: _FakeCustomPainter()),
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
    expect(treeCapture, isNotNull);
    expect(treeCapture.nodes.length, 1);
    final containerNode = treeCapture.nodes.first;
    expect(containerNode.attributes.x, 0);
    expect(containerNode.attributes.y, 0);
    expect(containerNode.attributes.width, width.round());
    expect(containerNode.attributes.height, height.round());

    final builtWireframes = containerNode.buildWireframes();
    expect(builtWireframes.length, 1);
    final shapeWireframe = builtWireframes.first as SRPlaceholderWireframe;
    expect(shapeWireframe.x, 0);
    expect(shapeWireframe.y, 0);
    expect(shapeWireframe.width, width.round());
    expect(shapeWireframe.height, height.round());
  });

  testWidgets('returns nothing for custom paint with only foreground painter', (
    tester,
  ) async {
    // Given
    final width = randomDouble(min: 10, max: 50);
    final height = randomDouble(min: 10, max: 50);
    final tree = SimpleTestCapture(
      key: Key('key'),
      recorder: recorder,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            SizedBox(
              width: width,
              height: height,
              child: CustomPaint(foregroundPainter: _FakeCustomPainter()),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = await recorder.performCapture();

    // Then
    expect(capture, isNull);
  });
}
