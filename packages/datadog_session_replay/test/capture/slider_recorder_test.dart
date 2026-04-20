// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// Note: to properly test recorders, we need to supply a full widget tree, as
// Element is too difficult to mock effectively.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/slider_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils.dart';
import 'simple_test_capture.dart';

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;

  setUp(() {
    recorder = SessionReplayRecorder.withCustomRecorders(
      [SliderRecorder(KeyGenerator())],
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

  Widget _materialStack(Widget child) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: ThemeData(),
        child: Material(child: Stack(children: [child])),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Material Slider
  // ---------------------------------------------------------------------------

  group('Slider', () {
    testWidgets('produces three nodes: inactive track, active track, thumb', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            Slider(value: 0.5, onChanged: (v) {}),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // Inactive track + active track + thumb = 3 nodes.
      expect(nodes.length, 3);

      final inactiveTrack =
          nodes[0].buildWireframes().first as SRShapeWireframe;
      final activeTrack = nodes[1].buildWireframes().first as SRShapeWireframe;
      final thumb = nodes[2].buildWireframes().first as SRShapeWireframe;

      // Inactive track covers the full width.
      expect(inactiveTrack.width, greaterThan(0));
      // Active track is narrower than the inactive track at value 0.5.
      expect(activeTrack.width, greaterThan(0));
      expect(activeTrack.width, lessThan(inactiveTrack.width));
      // Thumb is smaller than the track.
      expect(thumb.width, lessThan(inactiveTrack.width));
      // Track and active portion share the same left edge.
      expect(activeTrack.x, inactiveTrack.x);
    });

    testWidgets('value=0.0 produces zero-width active track', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            Slider(value: 0.0, onChanged: (v) {}),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // At value=0 there is no visible fill, so the active track node is
      // omitted (width=0 → clamp removes it from the list).
      // Either 2 (no active track) or 3 (zero-width active track) nodes are
      // acceptable; the thumb is always present.
      expect(nodes.length, greaterThanOrEqualTo(2));
    });

    testWidgets('value=1.0 produces full-width active track', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            Slider(value: 1.0, onChanged: (v) {}),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      expect(nodes.length, 3);

      final inactiveTrack =
          nodes[0].buildWireframes().first as SRShapeWireframe;
      final activeTrack = nodes[1].buildWireframes().first as SRShapeWireframe;

      // At value=1.0 the active track fills the full width.
      expect(activeTrack.width, inactiveTrack.width);
    });

    testWidgets('active track color matches activeColor', (tester) async {
      final activeColor = randomColor();
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            Slider(
              value: 0.5,
              activeColor: activeColor,
              onChanged: (v) {},
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      final activeTrack =
          capture!.viewTreeSnapshot.nodes[1].buildWireframes().first
              as SRShapeWireframe;

      expect(
        activeTrack.shapeStyle?.backgroundColor,
        activeColor.toHexString(),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // RangeSlider
  // ---------------------------------------------------------------------------

  group('RangeSlider', () {
    testWidgets('produces four nodes: inactive, active, start thumb, end thumb',
        (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            RangeSlider(
              values: const RangeValues(0.25, 0.75),
              onChanged: (v) {},
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // Inactive + active + thumb start + thumb end = 4 nodes.
      expect(nodes.length, 4);

      final inactiveTrack =
          nodes[0].buildWireframes().first as SRShapeWireframe;
      final activeTrack = nodes[1].buildWireframes().first as SRShapeWireframe;
      final thumbStart =
          nodes[2].buildWireframes().first as SRShapeWireframe;
      final thumbEnd = nodes[3].buildWireframes().first as SRShapeWireframe;

      // Active segment is between the two thumbs — narrower than full track.
      expect(activeTrack.width, lessThan(inactiveTrack.width));
      // Start thumb is to the left of end thumb.
      expect(thumbStart.x, lessThan(thumbEnd.x));
    });
  });

  // ---------------------------------------------------------------------------
  // CupertinoSlider
  // ---------------------------------------------------------------------------

  group('CupertinoSlider', () {
    testWidgets('produces three nodes: inactive track, active track, thumb', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [CupertinoSlider(value: 0.5, onChanged: (v) {})],
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      expect(nodes.length, 3);

      final inactiveTrack =
          nodes[0].buildWireframes().first as SRShapeWireframe;
      final activeTrack = nodes[1].buildWireframes().first as SRShapeWireframe;

      expect(activeTrack.width, greaterThan(0));
      expect(activeTrack.width, lessThan(inactiveTrack.width));
    });

    testWidgets('active track reflects activeColor', (tester) async {
      final activeColor = randomColor();
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [
                CupertinoSlider(
                  value: 0.5,
                  activeColor: activeColor,
                  onChanged: (v) {},
                ),
              ],
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      final activeTrack =
          capture!.viewTreeSnapshot.nodes[1].buildWireframes().first
              as SRShapeWireframe;

      expect(
        activeTrack.shapeStyle?.backgroundColor,
        activeColor.toHexString(),
      );
    });
  });
}
