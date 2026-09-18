// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/cupertino_widgets/cupertino_switch_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/material_widgets/switch_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/extensions.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../simple_test_capture.dart';

SimpleTestCapture captureSwitch(
  SessionReplayRecorder recorder,
  Widget switchWidget,
) {
  return SimpleTestCapture(
    key: Key('key'),
    recorder: recorder,
    child: MaterialApp(
      home: Scaffold(
        body: Center(child: switchWidget),
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
        SwitchRecorder(KeyGenerator()),
        CupertinoSwitchRecorder(KeyGenerator()),
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

  SRShapeWireframe trackOf(CaptureResult? capture) =>
      wireframesOf(capture)[0] as SRShapeWireframe;

  SRTextWireframe thumbOf(CaptureResult? capture) =>
      wireframesOf(capture)[1] as SRTextWireframe;

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
      'switch always produces 2 wireframes (track + thumb)',
      [
        () => captureSwitch(recorder, Switch(value: true, onChanged: (_) {})),
        () => captureSwitch(recorder, Switch(value: false, onChanged: (_) {})),
        () => captureSwitch(
            recorder, CupertinoSwitch(value: true, onChanged: (_) {})),
        () => captureSwitch(
            recorder, CupertinoSwitch(value: false, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframesOf(capture).length, 2);
      },
    );

    metaTestWidgets(
      'disabled switch still produces 2 wireframes',
      [
        () => captureSwitch(recorder, Switch(value: true, onChanged: null)),
        () => captureSwitch(
            recorder, CupertinoSwitch(value: true, onChanged: null)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframesOf(capture).length, 2);
      },
    );

    metaTestWidgets(
      'switch produces a single capture node',
      [
        () => captureSwitch(recorder, Switch(value: true, onChanged: (_) {})),
        () => captureSwitch(
            recorder, CupertinoSwitch(value: true, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(capture!.viewTreeSnapshot.nodes.length, 1);
      },
    );
  });

  group('layout and size', () {
    testWidgets(
        'material M3 switch track is 54x34 (52x32 logical + 2px outline at center stroke align)',
        (tester) async {
      // M3 default outline width is 2.0 with strokeAlignCenter — adds 2px to each dimension.
      final tree = captureSwitch(
        recorder,
        Theme(
          data: ThemeData(useMaterial3: true),
          child: Switch(value: false, onChanged: (_) {}),
        ),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      expect(trackOf(capture).width, 54);
      expect(trackOf(capture).height, 34);
    });

    testWidgets('material M2 switch track is 33x14 (no outline by default)',
        (tester) async {
      final tree = captureSwitch(
        recorder,
        Theme(
          data: ThemeData(useMaterial3: false),
          child: Switch(value: false, onChanged: (_) {}),
        ),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      expect(trackOf(capture).width, 33);
      expect(trackOf(capture).height, 14);
    });

    metaTestWidgets(
      'Cupertino-style switch and CupertinoSwitch track is 51x31',
      [
        () => captureSwitch(
            recorder, CupertinoSwitch(value: false, onChanged: (_) {})),
        () => captureSwitch(
            recorder, Switch.adaptive(value: false, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(trackOf(capture).width, 51);
        expect(trackOf(capture).height, 31);
      },
      beforeEach: () => debugDefaultTargetPlatformOverride = TargetPlatform.iOS,
      afterEach: () => debugDefaultTargetPlatformOverride = null,
    );
  });

  group('track color', () {
    metaTestWidgets(
      'selected track uses activeTrackColor',
      [
        () => captureSwitch(
            recorder,
            Switch(
                value: true, onChanged: (_) {}, activeTrackColor: Colors.red)),
        () => captureSwitch(
            recorder,
            CupertinoSwitch(
                value: true, onChanged: (_) {}, activeTrackColor: Colors.red)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(trackOf(capture).shapeStyle!.backgroundColor,
            Colors.red.toHexString());
      },
    );

    metaTestWidgets(
      'unselected track uses inactiveTrackColor',
      [
        () => captureSwitch(
            recorder,
            Switch(
                value: false,
                onChanged: (_) {},
                inactiveTrackColor: Colors.blue)),
        () => captureSwitch(
            recorder,
            CupertinoSwitch(
                value: false,
                onChanged: (_) {},
                inactiveTrackColor: Colors.blue)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(trackOf(capture).shapeStyle!.backgroundColor,
            Colors.blue.toHexString());
      },
    );

    testWidgets(
        'material switch trackColor WidgetStateProperty is resolved per state',
        (tester) async {
      final trackColor = WidgetStateProperty.resolveWith<Color?>((states) {
        return states.contains(WidgetState.selected)
            ? Colors.green
            : Colors.yellow;
      });
      final tree = captureSwitch(
        recorder,
        Switch(value: true, onChanged: (_) {}, trackColor: trackColor),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      expect(trackOf(capture).shapeStyle!.backgroundColor,
          Colors.green.toHexString());
    });
  });

  group('thumb color', () {
    metaTestWidgets(
      'selected thumb uses the active thumb color',
      [
        () => captureSwitch(
            recorder,
            Switch(
                value: true, onChanged: (_) {}, activeThumbColor: Colors.red)),
        () => captureSwitch(
            recorder,
            CupertinoSwitch(
                value: true, onChanged: (_) {}, thumbColor: Colors.red)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(thumbOf(capture).shapeStyle!.backgroundColor,
            Colors.red.toHexString());
      },
    );

    metaTestWidgets(
      'unselected thumb uses the inactive thumb color',
      [
        () => captureSwitch(
            recorder,
            Switch(
                value: false,
                onChanged: (_) {},
                inactiveThumbColor: Colors.blue)),
        () => captureSwitch(
            recorder,
            CupertinoSwitch(
                value: false,
                onChanged: (_) {},
                inactiveThumbColor: Colors.blue)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(thumbOf(capture).shapeStyle!.backgroundColor,
            Colors.blue.toHexString());
      },
    );

    testWidgets(
        'CupertinoSwitch unselected thumb falls back to thumbColor when inactiveThumbColor is null',
        (tester) async {
      // Flutter's effectiveInactiveThumbColor = inactiveThumbColor ?? effectiveActiveThumbColor.
      final tree = captureSwitch(
        recorder,
        CupertinoSwitch(
            value: false, onChanged: (_) {}, thumbColor: Colors.blue),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      expect(thumbOf(capture).shapeStyle!.backgroundColor,
          Colors.blue.toHexString());
    });
  });

  group('thumb position', () {
    metaTestWidgets(
      'selected thumb is on the right side of the track',
      [
        () => captureSwitch(recorder, Switch(value: true, onChanged: (_) {})),
        () => captureSwitch(
            recorder, CupertinoSwitch(value: true, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        final track = trackOf(capture);
        final thumb = thumbOf(capture);
        expect(
            thumb.x + thumb.width / 2, greaterThan(track.x + track.width / 2));
      },
    );

    metaTestWidgets(
      'unselected thumb is on the left side of the track',
      [
        () => captureSwitch(recorder, Switch(value: false, onChanged: (_) {})),
        () => captureSwitch(
            recorder, CupertinoSwitch(value: false, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        final track = trackOf(capture);
        final thumb = thumbOf(capture);
        expect(thumb.x + thumb.width / 2, lessThan(track.x + track.width / 2));
      },
    );
  });

  group('border', () {
    metaTestWidgets(
      'trackOutlineColor is applied with default width 2.0',
      [
        () => captureSwitch(
            recorder,
            Switch(
                value: false,
                onChanged: (_) {},
                trackOutlineColor: WidgetStateProperty.all(Colors.red))),
        () => captureSwitch(
            recorder,
            CupertinoSwitch(
                value: false,
                onChanged: (_) {},
                trackOutlineColor: WidgetStateProperty.all(Colors.red))),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(trackOf(capture).border!.color, Colors.red.toHexString());
        expect(trackOf(capture).border!.width, 2);
      },
    );

    metaTestWidgets(
      'custom trackOutlineWidth is applied',
      [
        () => captureSwitch(
            recorder,
            Switch(
                value: false,
                onChanged: (_) {},
                trackOutlineColor: WidgetStateProperty.all(Colors.green),
                trackOutlineWidth: WidgetStateProperty.all(4.0))),
        () => captureSwitch(
            recorder,
            CupertinoSwitch(
                value: false,
                onChanged: (_) {},
                trackOutlineColor: WidgetStateProperty.all(Colors.green),
                trackOutlineWidth: WidgetStateProperty.all(4.0))),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(trackOf(capture).border!.color, Colors.green.toHexString());
        expect(trackOf(capture).border!.width, 4);
      },
    );

    testWidgets('material M3 unselected switch has outline border by default',
        (tester) async {
      const outlineColor = Color(0xFF112233);
      final tree = captureSwitch(
        recorder,
        Theme(
          data: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.light(outline: outlineColor),
          ),
          child: Switch(value: false, onChanged: (_) {}),
        ),
      );
      await tester.pumpWidget(tree);
      final capture = await recorder.performCapture();
      expect(capture, isNotNull);
      expect(trackOf(capture).border!.color, outlineColor.toHexString());
      expect(trackOf(capture).border!.width, 2);
    });

    metaTestWidgets(
      'selected switch has transparent border by default',
      [
        () => captureSwitch(
            recorder,
            Theme(
              data: ThemeData(useMaterial3: true),
              child: Switch(value: true, onChanged: (_) {}),
            )),
        () => captureSwitch(
            recorder, CupertinoSwitch(value: true, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(
            trackOf(capture).border!.color, Colors.transparent.toHexString());
      },
    );
  });

  group('disabled opacity', () {
    metaTestWidgets(
      'Cupertino-style disabled switch applies 50% opacity to track color regardless of state',
      [
        () => captureSwitch(
            recorder,
            CupertinoSwitch(
                value: true, onChanged: null, activeTrackColor: Colors.red)),
        () => captureSwitch(
            recorder,
            CupertinoSwitch(
                value: false, onChanged: null, inactiveTrackColor: Colors.red)),
        () => captureSwitch(
            recorder,
            Switch.adaptive(
                value: true, onChanged: null, activeTrackColor: Colors.red)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(
          trackOf(capture).shapeStyle!.backgroundColor,
          Colors.red.withValues(alpha: 0.5).toHexString(),
        );
      },
      beforeEach: () => debugDefaultTargetPlatformOverride = TargetPlatform.iOS,
      afterEach: () => debugDefaultTargetPlatformOverride = null,
    );

    metaTestWidgets(
      'Cupertino-style disabled switch applies 50% opacity to thumb color',
      [
        () => captureSwitch(
            recorder,
            CupertinoSwitch(
                value: true, onChanged: null, thumbColor: Colors.white)),
        () => captureSwitch(
            recorder,
            Switch.adaptive(
                value: true, onChanged: null, activeThumbColor: Colors.white)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(
          thumbOf(capture).shapeStyle!.backgroundColor,
          Colors.white.withValues(alpha: 0.5).toHexString(),
        );
      },
      beforeEach: () => debugDefaultTargetPlatformOverride = TargetPlatform.iOS,
      afterEach: () => debugDefaultTargetPlatformOverride = null,
    );
  });

  group('privacy', () {
    metaTestWidgets(
      'maskAllInputs treats selected switch as unselected (inactive track color)',
      [
        () => captureSwitch(
            recorder,
            Switch(
                value: true,
                onChanged: (_) {},
                activeTrackColor: Colors.red,
                inactiveTrackColor: Colors.blue)),
        () => captureSwitch(
            recorder,
            CupertinoSwitch(
                value: true,
                onChanged: (_) {},
                activeTrackColor: Colors.red,
                inactiveTrackColor: Colors.blue)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(trackOf(capture).shapeStyle!.backgroundColor,
            Colors.blue.toHexString());
      },
      beforeEach: () {
        recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
          textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
        );
      },
    );

    metaTestWidgets(
      'maskSensitiveInputs does not mask switch state',
      [
        () => captureSwitch(
            recorder,
            Switch(
                value: true,
                onChanged: (_) {},
                activeTrackColor: Colors.red,
                inactiveTrackColor: Colors.blue)),
        () => captureSwitch(
            recorder,
            CupertinoSwitch(
                value: true,
                onChanged: (_) {},
                activeTrackColor: Colors.red,
                inactiveTrackColor: Colors.blue)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(trackOf(capture).shapeStyle!.backgroundColor,
            Colors.red.toHexString());
      },
      beforeEach: () {
        recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
        );
      },
    );
  });
}
