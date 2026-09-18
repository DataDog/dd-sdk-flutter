// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/cupertino_widgets/cupertino_checkbox_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/material_widgets/checkbox_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/extensions.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../simple_test_capture.dart';

SimpleTestCapture captureCheckbox(
  SessionReplayRecorder recorder,
  Widget checkbox,
) {
  return SimpleTestCapture(
    key: Key('key'),
    recorder: recorder,
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: checkbox,
        ),
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
        CheckboxRecorder(KeyGenerator()),
        CupertinoCheckboxRecorder(KeyGenerator()),
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

  SRTextWireframe wireframeOf(CaptureResult? capture) {
    return capture!.viewTreeSnapshot.nodes.first.buildWireframes().first
        as SRTextWireframe;
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

  group('symbol output', () {
    metaTestWidgets(
      'checked checkbox shows checkmark symbol',
      [
        () =>
            captureCheckbox(recorder, Checkbox(value: true, onChanged: (_) {})),
        () => captureCheckbox(
            recorder, CupertinoCheckbox(value: true, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(capture!.viewTreeSnapshot.nodes.length, 1);
        expect(wireframeOf(capture).text,
            String.fromCharCode(Icons.check.codePoint));
      },
    );

    metaTestWidgets(
      'unchecked checkbox shows empty text',
      [
        () => captureCheckbox(
            recorder, Checkbox(value: false, onChanged: (_) {})),
        () => captureCheckbox(
            recorder, CupertinoCheckbox(value: false, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(capture!.viewTreeSnapshot.nodes.length, 1);
        expect(wireframeOf(capture).text, '');
      },
    );

    metaTestWidgets(
      'tristate checkbox shows dash symbol',
      [
        () => captureCheckbox(
            recorder, Checkbox(value: null, tristate: true, onChanged: (_) {})),
        () => captureCheckbox(recorder,
            CupertinoCheckbox(value: null, tristate: true, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(capture!.viewTreeSnapshot.nodes.length, 1);
        expect(wireframeOf(capture).text,
            String.fromCharCode(Icons.remove.codePoint));
      },
    );
  });

  group('fill color', () {
    final statefulFill = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.selected)) {
        return states.contains(WidgetState.disabled)
            ? Colors.grey
            : Colors.blue;
      }
      return Colors.transparent;
    });

    metaTestWidgets(
      'enabled selected checkbox has active fill color',
      [
        () => captureCheckbox(recorder,
            Checkbox(value: true, onChanged: (_) {}, fillColor: statefulFill)),
        () => captureCheckbox(
            recorder,
            CupertinoCheckbox(
                value: true, onChanged: (_) {}, fillColor: statefulFill)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframeOf(capture).shapeStyle!.backgroundColor,
            Colors.blue.toHexString());
      },
    );

    metaTestWidgets(
      'enabled unselected checkbox has transparent fill',
      [
        () => captureCheckbox(recorder,
            Checkbox(value: false, onChanged: (_) {}, fillColor: statefulFill)),
        () => captureCheckbox(
            recorder,
            CupertinoCheckbox(
                value: false, onChanged: (_) {}, fillColor: statefulFill)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframeOf(capture).shapeStyle!.backgroundColor,
            Colors.transparent.toHexString());
      },
    );

    metaTestWidgets(
      'enabled tristate checkbox has active fill color',
      [
        () => captureCheckbox(
            recorder,
            Checkbox(
                value: null,
                tristate: true,
                onChanged: (_) {},
                fillColor: statefulFill)),
        () => captureCheckbox(
            recorder,
            CupertinoCheckbox(
                value: null,
                tristate: true,
                onChanged: (_) {},
                fillColor: statefulFill)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframeOf(capture).shapeStyle!.backgroundColor,
            Colors.blue.toHexString());
      },
    );

    metaTestWidgets(
      'disabled selected checkbox has disabled fill color',
      [
        () => captureCheckbox(recorder,
            Checkbox(value: true, onChanged: null, fillColor: statefulFill)),
        () => captureCheckbox(
            recorder,
            CupertinoCheckbox(
                value: true, onChanged: null, fillColor: statefulFill)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframeOf(capture).shapeStyle!.backgroundColor,
            Colors.grey.toHexString());
      },
    );

    metaTestWidgets(
      'disabled unselected checkbox has transparent fill',
      [
        () => captureCheckbox(recorder,
            Checkbox(value: false, onChanged: null, fillColor: statefulFill)),
        () => captureCheckbox(
            recorder,
            CupertinoCheckbox(
                value: false, onChanged: null, fillColor: statefulFill)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframeOf(capture).shapeStyle!.backgroundColor,
            Colors.transparent.toHexString());
      },
    );
  });

  group('symbol color', () {
    metaTestWidgets(
      'enabled selected checkbox symbol uses checkColor',
      [
        () => captureCheckbox(recorder,
            Checkbox(value: true, onChanged: (_) {}, checkColor: Colors.red)),
        () => captureCheckbox(
            recorder,
            CupertinoCheckbox(
                value: true, onChanged: (_) {}, checkColor: Colors.red)),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframeOf(capture).textStyle.color, Colors.red.toHexString());
      },
    );

    testWidgets(
        'disabled material selected checkbox default symbol color comes from theme surface',
        (tester) async {
      // Given — M3 default: disabled+selected uses theme.colorScheme.surface
      const surface = Color(0xFF112233);
      final tree = captureCheckbox(
        recorder,
        Theme(
          data: ThemeData(colorScheme: ColorScheme.light(surface: surface)),
          child: Checkbox(value: true, onChanged: null),
        ),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(wireframeOf(capture).textStyle.color, surface.toHexString());
    });

    testWidgets(
        'disabled cupertino selected checkbox default symbol color is grey-black',
        (tester) async {
      // Given — CupertinoCheckbox default: white when enabled, grey-black when disabled
      final tree = captureCheckbox(
        recorder,
        CupertinoCheckbox(value: true, onChanged: null),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then — Color.fromARGB(64, 0, 0, 0) light-mode variant of _kDisabledCheckColor
      expect(capture, isNotNull);
      expect(wireframeOf(capture).textStyle.color,
          Color.fromARGB(64, 0, 0, 0).toHexString());
    });
  });

  group('border', () {
    // resolveSide returns null for selected states, falling through to _defaultSide (transparent).
    // For unselected states it returns the BorderSide as-is. This works uniformly for both widget types.

    metaTestWidgets(
      'enabled selected checkbox has transparent border',
      [
        () => captureCheckbox(
            recorder,
            Checkbox(
              value: true,
              onChanged: (_) {},
              side: BorderSide(color: Colors.green, width: 2),
            )),
        () => captureCheckbox(
            recorder,
            CupertinoCheckbox(
              value: true,
              onChanged: (_) {},
              side: BorderSide(color: Colors.green, width: 2),
            )),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframeOf(capture).border!.color,
            Colors.transparent.toHexString());
      },
    );

    metaTestWidgets(
      'enabled tristate checkbox has transparent border',
      [
        () => captureCheckbox(
            recorder,
            Checkbox(
              value: null,
              tristate: true,
              onChanged: (_) {},
              side: BorderSide(color: Colors.green, width: 2),
            )),
        () => captureCheckbox(
            recorder,
            CupertinoCheckbox(
              value: null,
              tristate: true,
              onChanged: (_) {},
              side: BorderSide(color: Colors.green, width: 2),
            )),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframeOf(capture).border!.color,
            Colors.transparent.toHexString());
      },
    );

    metaTestWidgets(
      'enabled unselected checkbox has visible border',
      [
        () => captureCheckbox(
            recorder,
            Checkbox(
              value: false,
              onChanged: (_) {},
              side: BorderSide(color: Colors.green, width: 2),
            )),
        () => captureCheckbox(
            recorder,
            CupertinoCheckbox(
              value: false,
              onChanged: (_) {},
              side: BorderSide(color: Colors.green, width: 2),
            )),
      ],
      (capture) {
        expect(capture, isNotNull);
        final wire = wireframeOf(capture);
        expect(wire.border!.color, Colors.green.toHexString());
        expect(wire.border!.width, 2);
      },
    );

    metaTestWidgets(
      'custom side color and width are applied',
      [
        () => captureCheckbox(
            recorder,
            Checkbox(
              value: false,
              onChanged: (_) {},
              side: BorderSide(color: Colors.red, width: 3),
            )),
        () => captureCheckbox(
            recorder,
            CupertinoCheckbox(
              value: false,
              onChanged: (_) {},
              side: BorderSide(color: Colors.red, width: 3),
            )),
      ],
      (capture) {
        expect(capture, isNotNull);
        final wire = wireframeOf(capture);
        expect(wire.border!.color, Colors.red.toHexString());
        expect(wire.border!.width, 3);
      },
    );
  });

  group('layout and size', () {
    metaTestWidgets(
      'checkbox produces a single wireframe node',
      [
        () => captureCheckbox(
            recorder,
            Checkbox(
                value: true,
                onChanged: (_) {},
                side: BorderSide(strokeAlign: BorderSide.strokeAlignInside))),
        () => captureCheckbox(
            recorder,
            CupertinoCheckbox(
                value: true,
                onChanged: (_) {},
                side: BorderSide(strokeAlign: BorderSide.strokeAlignInside))),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(capture!.viewTreeSnapshot.nodes.length, 1);
      },
    );

    testWidgets('material checkbox has default size of 18x18', (tester) async {
      // Given
      final tree = captureCheckbox(
          recorder,
          Checkbox(
              value: true,
              onChanged: (_) {},
              side: BorderSide(strokeAlign: BorderSide.strokeAlignInside)));
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final wire = wireframeOf(capture);
      expect(wire.width, 18);
      expect(wire.height, 18);
    });

    testWidgets('cupertino checkbox has default size of 14x14', (tester) async {
      // Given
      final tree = captureCheckbox(
          recorder,
          CupertinoCheckbox(
              value: true,
              onChanged: (_) {},
              side: BorderSide(strokeAlign: BorderSide.strokeAlignInside)));
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final wire = wireframeOf(capture);
      expect(wire.width, 14);
      expect(wire.height, 14);
    });

    testWidgets('scaled checkbox has scaled size', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Transform.scale(
            scale: 0.5,
            child: Checkbox(
                value: true,
                onChanged: (_) {},
                side: BorderSide(strokeAlign: BorderSide.strokeAlignInside))),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      // 18 * 0.5 = 9
      expect(capture, isNotNull);
      final wire = wireframeOf(capture);
      expect(wire.width, 9);
      expect(wire.height, 9);
    });
  });

  group('text style', () {
    metaTestWidgets(
      'symbol size is 90% of the checkbox height',
      [
        () =>
            captureCheckbox(recorder, Checkbox(value: true, onChanged: (_) {})),
        () => captureCheckbox(
            recorder, CupertinoCheckbox(value: true, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        final wire = wireframeOf(capture);
        expect(wire.textStyle.size, (wire.height * 0.9).round());
      },
    );

    metaTestWidgets(
      'symbol is center aligned horizontally and vertically',
      [
        () =>
            captureCheckbox(recorder, Checkbox(value: true, onChanged: (_) {})),
        () => captureCheckbox(
            recorder, CupertinoCheckbox(value: true, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        final wire = wireframeOf(capture);
        expect(wire.textPosition?.alignment?.horizontal,
            SRHorizontalAlignment.center);
        expect(
            wire.textPosition?.alignment?.vertical, SRVerticalAlignment.center);
      },
    );
  });

  group('privacy', () {
    metaTestWidgets(
      'maskAllInputs masks checked checkbox with x symbol',
      [
        () =>
            captureCheckbox(recorder, Checkbox(value: true, onChanged: (_) {})),
        () => captureCheckbox(
            recorder, CupertinoCheckbox(value: true, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        final wire = wireframeOf(capture);
        expect(wire.text, String.fromCharCode(Icons.close.codePoint));
        expect(
            wire.shapeStyle!.backgroundColor,
            anyOf(Colors.transparent.toHexString(),
                CupertinoColors.white.toHexString()));
        expect(wire.border, isNotNull);
      },
      beforeEach: () => recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
    );

    metaTestWidgets(
      'maskAll masks checked checkbox with x symbol',
      [
        () =>
            captureCheckbox(recorder, Checkbox(value: true, onChanged: (_) {})),
        () => captureCheckbox(
            recorder, CupertinoCheckbox(value: true, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        final wire = wireframeOf(capture);
        expect(wire.text, String.fromCharCode(Icons.close.codePoint));
        expect(
            wire.shapeStyle!.backgroundColor,
            anyOf(Colors.transparent.toHexString(),
                CupertinoColors.white.toHexString()));
        expect(wire.border, isNotNull);
      },
      beforeEach: () => recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
    );

    metaTestWidgets(
      'maskAllInputs masks unchecked checkbox with x symbol',
      [
        () => captureCheckbox(
            recorder, Checkbox(value: false, onChanged: (_) {})),
        () => captureCheckbox(
            recorder, CupertinoCheckbox(value: false, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframeOf(capture).text,
            String.fromCharCode(Icons.close.codePoint));
      },
      beforeEach: () => recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
    );

    metaTestWidgets(
      'maskSensitiveInputs does not mask checkbox',
      [
        () =>
            captureCheckbox(recorder, Checkbox(value: true, onChanged: (_) {})),
        () => captureCheckbox(
            recorder, CupertinoCheckbox(value: true, onChanged: (_) {})),
      ],
      (capture) {
        expect(capture, isNotNull);
        expect(wireframeOf(capture).text,
            String.fromCharCode(Icons.check.codePoint));
      },
      beforeEach: () => recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
    );
  });
}
