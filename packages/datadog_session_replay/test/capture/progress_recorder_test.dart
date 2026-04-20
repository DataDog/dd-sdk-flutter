// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// Note: to properly test recorders, we need to supply a full widget tree, as
// Element is too difficult to mock effectively.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/progress_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';
import 'simple_test_capture.dart';

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;

  setUp(() {
    recorder = SessionReplayRecorder.withCustomRecorders(
      [ProgressRecorder(KeyGenerator())],
      defaultCapturePrivacy: const TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
    );
    context = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
    );
    recorder.updateContext(context);
  });

  Widget _stack(Widget child) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [SizedBox(width: 200, child: child)]),
    );
  }

  // ---------------------------------------------------------------------------
  // LinearProgressIndicator
  // ---------------------------------------------------------------------------

  group('LinearProgressIndicator', () {
    testWidgets('determinate: produces track and fill nodes', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _stack(LinearProgressIndicator(value: 0.5)),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // Track + fill = 2 nodes.
      expect(nodes.length, 2);

      final track = nodes[0].buildWireframes().first as SRShapeWireframe;
      final fill = nodes[1].buildWireframes().first as SRShapeWireframe;

      // Track covers the full width.
      expect(track.width, greaterThan(0));
      // Fill is narrower than the track at value 0.5.
      expect(fill.width, greaterThan(0));
      expect(fill.width, lessThan(track.width));
      // Fill starts at the same left edge as the track.
      expect(fill.x, track.x);
    });

    testWidgets('fill width is proportional to value', (tester) async {
      // Build with value=0.25.
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _stack(LinearProgressIndicator(value: 0.25)),
        ),
      );
      final capture25 = await recorder.performCapture();
      final track25 =
          capture25!.viewTreeSnapshot.nodes[0].buildWireframes().first
              as SRShapeWireframe;
      final fill25 =
          capture25.viewTreeSnapshot.nodes[1].buildWireframes().first
              as SRShapeWireframe;

      // Build with value=0.75.
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _stack(LinearProgressIndicator(value: 0.75)),
        ),
      );
      final capture75 = await recorder.performCapture();
      final fill75 =
          capture75!.viewTreeSnapshot.nodes[1].buildWireframes().first
              as SRShapeWireframe;

      // At 0.75 the fill is wider than at 0.25 and both are less than full width.
      expect(fill75.width, greaterThan(fill25.width));
      expect(fill25.width, lessThan(track25.width));
    });

    testWidgets('value=0.0 produces only the track node', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _stack(LinearProgressIndicator(value: 0.0)),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      // fillWidth == 0 → fill node not added.
      expect(capture!.viewTreeSnapshot.nodes.length, 1);
    });

    testWidgets('indeterminate (value==null) produces track and partial fill', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          // ignore: avoid_redundant_argument_values
          child: _stack(const LinearProgressIndicator()),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // Indeterminate → 40 % fill, so fill is non-zero → 2 nodes.
      expect(nodes.length, 2);

      final track = nodes[0].buildWireframes().first as SRShapeWireframe;
      final fill = nodes[1].buildWireframes().first as SRShapeWireframe;

      // Fill is less than full width (40 %).
      expect(fill.width, greaterThan(0));
      expect(fill.width, lessThan(track.width));
    });

    testWidgets('indicator color appears on fill node', (tester) async {
      final indicatorColor = randomColor();
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _stack(
            LinearProgressIndicator(
              value: 0.5,
              color: AlwaysStoppedAnimation<Color>(indicatorColor),
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      final fill =
          capture!.viewTreeSnapshot.nodes[1].buildWireframes().first
              as SRShapeWireframe;

      expect(
        fill.shapeStyle?.backgroundColor,
        indicatorColor.toHexString(),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // CircularProgressIndicator
  // ---------------------------------------------------------------------------

  group('CircularProgressIndicator', () {
    testWidgets('indeterminate produces a single ring node', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _stack(const CircularProgressIndicator()),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // Indeterminate → ring only = 1 node.
      expect(nodes.length, 1);

      final ring = nodes[0].buildWireframes().first as SRShapeWireframe;
      // Ring has a border (stroke around the circle).
      expect(ring.border, isNotNull);
      // Corner radius equals half the shortest side → circular.
      expect(ring.shapeStyle?.cornerRadius, greaterThan(0));
      // Square bounding box.
      expect(ring.width, ring.height);
    });

    testWidgets('determinate produces ring and inner fill nodes', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _stack(const CircularProgressIndicator(value: 0.5)),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // Ring + inner fill = 2 nodes.
      expect(nodes.length, 2);

      final ring = nodes[0].buildWireframes().first as SRShapeWireframe;
      final fill = nodes[1].buildWireframes().first as SRShapeWireframe;

      // Inner fill circle is smaller than the outer ring.
      expect(fill.width, lessThan(ring.width));
      expect(fill.height, lessThan(ring.height));
      // Both are square (circular).
      expect(ring.width, ring.height);
      expect(fill.width, fill.height);
    });

    testWidgets('value=0.0 produces only the ring node', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _stack(const CircularProgressIndicator(value: 0.0)),
        ),
      );

      final capture = await recorder.performCapture();
      // value=0 → fillRadius == 0 → inner fill node not added.
      expect(capture!.viewTreeSnapshot.nodes.length, 1);
    });

    testWidgets('indicator color appears as ring border color', (
      tester,
    ) async {
      final indicatorColor = randomColor();
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _stack(
            CircularProgressIndicator(
              color: AlwaysStoppedAnimation<Color>(indicatorColor),
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      final ring =
          capture!.viewTreeSnapshot.nodes[0].buildWireframes().first
              as SRShapeWireframe;

      expect(ring.border?.color, indicatorColor.toHexString());
    });
  });
}
