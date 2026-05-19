// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/cupertino_widgets/cupertino_slider_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/material_widgets/slider_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/extensions.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../simple_test_capture.dart';

SimpleTestCapture captureSlider(
  SessionReplayRecorder recorder,
  Widget slider, {
  ThemeData? theme,
}) {
  return SimpleTestCapture(
    key: Key('key'),
    recorder: recorder,
    child: MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(child: slider),
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
        SliderRecorder(KeyGenerator()),
        CupertinoSliderRecorder(KeyGenerator()),
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

  // Both recorders emit the inactive track first and the thumb last. Anything
  // in between (secondary, ticks, gap, stop indicator) varies by configuration.
  SRShapeWireframe inactiveTrackOf(CaptureResult? capture) =>
      wireframesOf(capture).first as SRShapeWireframe;

  SRShapeWireframe thumbOf(CaptureResult? capture) =>
      wireframesOf(capture).last as SRShapeWireframe;

  void metaTestWidgets(
    String testDescription,
    List<Widget Function()> setups,
    void Function(CaptureResult?) checks, {
    VoidCallback? beforeEach,
    VoidCallback? afterEach,
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
        afterEach?.call();
      });
    }
  }

  group('wireframe count', () {
    metaTestWidgets(
      'slider produces 3 wireframes (inactive + active + thumb)',
      [
        () => captureSlider(recorder, Slider(value: 0.5, onChanged: (_) {})),
        () => captureSlider(
            recorder, CupertinoSlider(value: 0.5, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframesOf(capture).length, 3);
      },
    );

    metaTestWidgets(
      'slider produces a single capture node',
      [
        () => captureSlider(recorder, Slider(value: 0.5, onChanged: (_) {})),
        () => captureSlider(
            recorder, CupertinoSlider(value: 0.5, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(capture!.viewTreeSnapshot.nodes.length, 1);
      },
    );

    metaTestWidgets(
      'disabled slider (onChanged: null) still produces 3 wireframes',
      [
        () => captureSlider(recorder, Slider(value: 0.5, onChanged: null)),
        () => captureSlider(
            recorder, CupertinoSlider(value: 0.5, onChanged: null)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframesOf(capture).length, 3);
      },
    );

    testWidgets(
        'material slider with secondaryTrackValue adds a secondary track wireframe',
        (tester) async {
      final tree = captureSlider(
        recorder,
        Slider(value: 0.3, secondaryTrackValue: 0.7, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      expect(wireframesOf(capture).length, 4);
    });

    testWidgets(
        'material slider with divisions=N adds N+1 tick mark wireframes',
        (tester) async {
      final tree = captureSlider(
        recorder,
        Slider(value: 0.5, divisions: 4, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      // 3 (inactive + active + thumb) + 5 ticks = 8
      expect(wireframesOf(capture).length, 8);
    });

    testWidgets('CupertinoSlider with divisions still produces 3 wireframes',
        (tester) async {
      // CupertinoSlider snaps the value to divisions but doesn't render
      // visual tick marks (unlike Material).
      final tree = captureSlider(
        recorder,
        CupertinoSlider(value: 0.5, divisions: 4, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      expect(wireframesOf(capture).length, 3);
    });

    testWidgets(
        'M3-2024 material slider (year2023: false) adds gap + stop indicator wireframes',
        (tester) async {
      final tree = captureSlider(
        recorder,
        Slider(
          // ignore: deprecated_member_use
          year2023: false,
          value: 0.5,
          onChanged: (_) {},
        ),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      // 3 (inactive + active + thumb) + 2 (gap + stop indicator) = 5
      expect(wireframesOf(capture).length, 5);
    });
  });

  group('colors', () {
    metaTestWidgets(
      'thumb uses widget.thumbColor when set',
      [
        () => captureSlider(recorder,
            Slider(value: 0.5, onChanged: (_) {}, thumbColor: Colors.red)),
        () => captureSlider(
            recorder,
            CupertinoSlider(
                value: 0.5, onChanged: (_) {}, thumbColor: Colors.red)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(thumbOf(capture).shapeStyle!.backgroundColor,
            Colors.red.toHexString());
      },
    );

    metaTestWidgets(
      'active track uses widget.activeColor when set',
      [
        () => captureSlider(recorder,
            Slider(value: 0.5, onChanged: (_) {}, activeColor: Colors.green)),
        () => captureSlider(
            recorder,
            CupertinoSlider(
                value: 0.5, onChanged: (_) {}, activeColor: Colors.green)),
      ],
      (capture) {
        expect(capture, isNotNull);
        // For both recorders, with no secondary/ticks/gap, the active track
        // lives at index 1 (between [0] inactive and [last] thumb).
        final active = wireframesOf(capture)[1] as SRShapeWireframe;
        expect(active.shapeStyle!.backgroundColor, Colors.green.toHexString());
      },
    );

    testWidgets('material inactive track uses widget.inactiveColor when set',
        (tester) async {
      final tree = captureSlider(
        recorder,
        Slider(value: 0.5, onChanged: (_) {}, inactiveColor: Colors.yellow),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      expect(inactiveTrackOf(capture).shapeStyle!.backgroundColor,
          Colors.yellow.toHexString());
    });

    testWidgets(
        'material secondary track uses widget.secondaryActiveColor when set',
        (tester) async {
      final tree = captureSlider(
        recorder,
        Slider(
          value: 0.3,
          secondaryTrackValue: 0.7,
          onChanged: (_) {},
          secondaryActiveColor: Colors.purple,
        ),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      // Order: [0] inactive, [1] secondary, [2] active, [3] thumb.
      final secondary = wireframesOf(capture)[1] as SRShapeWireframe;
      expect(
          secondary.shapeStyle!.backgroundColor, Colors.purple.toHexString());
    });
  });

  group('thumb position', () {
    metaTestWidgets(
      'thumb at value=min sits on the left side of the track',
      [
        () => captureSlider(recorder, Slider(value: 0.0, onChanged: (_) {})),
        () => captureSlider(
            recorder, CupertinoSlider(value: 0.0, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        final track = inactiveTrackOf(capture);
        final thumb = thumbOf(capture);
        expect(thumb.x + thumb.width / 2, lessThan(track.x + track.width / 2));
      },
    );

    metaTestWidgets(
      'thumb at value=max sits on the right side of the track',
      [
        () => captureSlider(recorder, Slider(value: 1.0, onChanged: (_) {})),
        () => captureSlider(
            recorder, CupertinoSlider(value: 1.0, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        final track = inactiveTrackOf(capture);
        final thumb = thumbOf(capture);
        expect(
            thumb.x + thumb.width / 2, greaterThan(track.x + track.width / 2));
      },
    );

    metaTestWidgets(
      'thumb at value=0.5 sits near the middle of the track',
      [
        () => captureSlider(recorder, Slider(value: 0.5, onChanged: (_) {})),
        () => captureSlider(
            recorder, CupertinoSlider(value: 0.5, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        final track = inactiveTrackOf(capture);
        final thumb = thumbOf(capture);
        final trackMid = track.x + track.width / 2;
        final thumbMid = thumb.x + thumb.width / 2;
        expect((thumbMid - trackMid).abs(), lessThan(2));
      },
    );

    testWidgets(
        'material thumb position scales linearly with custom min/max range',
        (tester) async {
      final tree = captureSlider(
        recorder,
        Slider(value: 50.0, min: 0.0, max: 100.0, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final track = inactiveTrackOf(capture);
      final thumb = thumbOf(capture);
      final trackMid = track.x + track.width / 2;
      final thumbMid = thumb.x + thumb.width / 2;
      expect((thumbMid - trackMid).abs(), lessThan(2));
    });
  });

  group('material year2023', () {
    testWidgets(
        'year2023: false produces a handle-style thumb (taller than wide)',
        (tester) async {
      final tree = captureSlider(
        recorder,
        Slider(
          // ignore: deprecated_member_use
          year2023: false,
          value: 0.5,
          onChanged: (_) {},
        ),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final thumb = thumbOf(capture);
      expect(thumb.height, 44);
      expect(thumb.width, greaterThanOrEqualTo(2.0));
      expect(thumb.width, lessThanOrEqualTo(4.0));
    });

    testWidgets('year2023: true produces a round thumb (square)',
        (tester) async {
      final tree =
          captureSlider(recorder, Slider(value: 0.5, onChanged: (_) {}));
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final thumb = thumbOf(capture);
      expect(thumb.width, thumb.height);
    });
  });

  group('cupertino specifics', () {
    testWidgets('CupertinoSlider thumb is a circle (square wireframe)',
        (tester) async {
      final tree = captureSlider(
          recorder, CupertinoSlider(value: 0.5, onChanged: (_) {}));
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      final thumb = thumbOf(capture);
      expect(thumb.width, thumb.height);
    });

    testWidgets(
        'CupertinoSlider default thumb color is white when no thumbColor is set',
        (tester) async {
      final tree = captureSlider(
          recorder, CupertinoSlider(value: 0.5, onChanged: (_) {}));
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      expect(thumbOf(capture).shapeStyle!.backgroundColor,
          CupertinoColors.white.toHexString());
    });
  });

  group('privacy', () {
    metaTestWidgets(
      'maskAllInputs anchors the thumb at midpoint regardless of value',
      [
        () => captureSlider(recorder, Slider(value: 0.95, onChanged: (_) {})),
        () => captureSlider(
            recorder, CupertinoSlider(value: 0.95, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        final track = inactiveTrackOf(capture);
        final thumb = thumbOf(capture);
        final trackMid = track.x + track.width / 2;
        final thumbMid = thumb.x + thumb.width / 2;
        expect((thumbMid - trackMid).abs(), lessThan(2));
      },
      beforeEach: () {
        recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
          textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
        );
      },
    );

    metaTestWidgets(
      'maskSensitiveInputs does not anchor the thumb (default)',
      [
        () => captureSlider(recorder, Slider(value: 1.0, onChanged: (_) {})),
        () => captureSlider(
            recorder, CupertinoSlider(value: 1.0, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        final track = inactiveTrackOf(capture);
        final thumb = thumbOf(capture);
        expect(
            thumb.x + thumb.width / 2, greaterThan(track.x + track.width / 2));
      },
    );
  });
}
