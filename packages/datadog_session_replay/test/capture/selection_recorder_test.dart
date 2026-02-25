// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// Note: to properly test recorders, we need to supply a full widget tree, as
// Element is too difficult to mock effectively.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/selection_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/extensions.dart';
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
      [SelectionControlRecorder(KeyGenerator())],
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
  // Checkbox
  // ---------------------------------------------------------------------------

  group('Checkbox', () {
    testWidgets('checked state produces a single filled node', (tester) async {
      final activeColor = randomColor();
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            Checkbox(
              value: true,
              activeColor: activeColor,
              onChanged: (v) {},
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      expect(nodes.length, 1);

      final wireframe = nodes.first.buildWireframes().first as SRShapeWireframe;
      // Checked → background is the active color.
      expect(wireframe.shapeStyle?.backgroundColor, activeColor.toHexString());
    });

    testWidgets('unchecked state produces a single bordered node', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            Checkbox(value: false, onChanged: (v) {}),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      expect(nodes.length, 1);

      final wireframe = nodes.first.buildWireframes().first as SRShapeWireframe;
      // Unchecked → transparent background with a visible border.
      expect(
        wireframe.shapeStyle?.backgroundColor,
        srTransparentColorString,
      );
      expect(wireframe.border, isNotNull);
    });

    testWidgets('tristate null (indeterminate) produces a filled node', (
      tester,
    ) async {
      final activeColor = randomColor();
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            Checkbox(
              value: null,
              tristate: true,
              activeColor: activeColor,
              onChanged: (v) {},
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      expect(nodes.length, 1);

      final wireframe = nodes.first.buildWireframes().first as SRShapeWireframe;
      // Indeterminate → treated as active → filled with active color.
      expect(wireframe.shapeStyle?.backgroundColor, activeColor.toHexString());
    });
  });

  // ---------------------------------------------------------------------------
  // Radio
  // ---------------------------------------------------------------------------

  group('Radio', () {
    testWidgets('selected Radio produces a single filled circular node', (
      tester,
    ) async {
      final activeColor = randomColor();
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            Radio<int>(
              value: 1,
              groupValue: 1,
              activeColor: activeColor,
              onChanged: (v) {},
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      expect(nodes.length, 1);

      final wireframe = nodes.first.buildWireframes().first as SRShapeWireframe;
      // Selected → filled with active color.
      expect(wireframe.shapeStyle?.backgroundColor, activeColor.toHexString());
      // Radio is always circular → square bounding box.
      expect(wireframe.width, wireframe.height);
      // Non-zero corner radius (circle).
      expect(wireframe.shapeStyle?.cornerRadius, greaterThan(0));
    });

    testWidgets('unselected Radio produces a single bordered circular node', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(
            Radio<int>(
              value: 1,
              groupValue: 2,
              onChanged: (v) {},
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      expect(nodes.length, 1);

      final wireframe = nodes.first.buildWireframes().first as SRShapeWireframe;
      // Unselected → transparent background + border.
      expect(
        wireframe.shapeStyle?.backgroundColor,
        srTransparentColorString,
      );
      expect(wireframe.border, isNotNull);
      expect(wireframe.width, wireframe.height);
    });
  });

  // ---------------------------------------------------------------------------
  // Switch (Material)
  // ---------------------------------------------------------------------------

  group('Switch', () {
    testWidgets('on state produces two nodes with thumb on the right', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(Switch(value: true, onChanged: (v) {})),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      // Track + thumb = 2 nodes.
      expect(nodes.length, 2);

      final track = nodes[0].buildWireframes().first as SRShapeWireframe;
      final thumb = nodes[1].buildWireframes().first as SRShapeWireframe;

      // Track is wider than the thumb.
      expect(track.width, greaterThan(thumb.width));
      // When on, the thumb's centre is in the right half of the track.
      final thumbCentreOn = thumb.x + thumb.width ~/ 2;
      expect(thumbCentreOn, greaterThan(track.x + track.width ~/ 2));
    });

    testWidgets('off state produces two nodes with thumb on the left', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(Switch(value: false, onChanged: (v) {})),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      expect(nodes.length, 2);

      final track = nodes[0].buildWireframes().first as SRShapeWireframe;
      final thumb = nodes[1].buildWireframes().first as SRShapeWireframe;

      // When off, the thumb's centre is in the left half of the track.
      final thumbCentreOff = thumb.x + thumb.width ~/ 2;
      expect(thumbCentreOff, lessThan(track.x + track.width ~/ 2));
    });

    testWidgets('on and off states produce different thumb x positions', (
      tester,
    ) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(Switch(value: true, onChanged: (v) {})),
        ),
      );
      final captureOn = await recorder.performCapture();
      final thumbOnX =
          (captureOn!.viewTreeSnapshot.nodes[1].buildWireframes().first
                  as SRShapeWireframe)
              .x;

      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: _materialStack(Switch(value: false, onChanged: (v) {})),
        ),
      );
      final captureOff = await recorder.performCapture();
      final thumbOffX =
          (captureOff!.viewTreeSnapshot.nodes[1].buildWireframes().first
                  as SRShapeWireframe)
              .x;

      expect(thumbOnX, greaterThan(thumbOffX));
    });
  });

  // ---------------------------------------------------------------------------
  // CupertinoSwitch
  // ---------------------------------------------------------------------------

  group('CupertinoSwitch', () {
    testWidgets('on state produces track and thumb nodes', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [CupertinoSwitch(value: true, onChanged: (v) {})],
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      expect(nodes.length, 2);

      final track = nodes[0].buildWireframes().first as SRShapeWireframe;
      final thumb = nodes[1].buildWireframes().first as SRShapeWireframe;

      expect(track.width, greaterThan(thumb.width));
      // When on, thumb centre is in the right half.
      expect(thumb.x + thumb.width ~/ 2, greaterThan(track.x + track.width ~/ 2));
    });

    testWidgets('off state places thumb on the left', (tester) async {
      await tester.pumpWidget(
        SimpleTestCapture(
          key: const Key('key'),
          recorder: recorder,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(
              children: [CupertinoSwitch(value: false, onChanged: (v) {})],
            ),
          ),
        ),
      );

      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final nodes = capture!.viewTreeSnapshot.nodes;
      expect(nodes.length, 2);

      final track = nodes[0].buildWireframes().first as SRShapeWireframe;
      final thumb = nodes[1].buildWireframes().first as SRShapeWireframe;

      // When off, thumb centre is in the left half.
      expect(thumb.x + thumb.width ~/ 2, lessThan(track.x + track.width ~/ 2));
    });
  });
}
