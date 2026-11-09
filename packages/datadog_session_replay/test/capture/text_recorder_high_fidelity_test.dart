// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/common_nodes.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/container_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/privacy_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/raster_resources.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/text_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'simple_test_capture.dart';

class MockDatadogSessionReplayPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSessionReplayPlatform {}

void main() {
  late MockDatadogSessionReplayPlatform platform;
  late KeyGenerator keyGenerator;
  late RUMContext context;

  setUpAll(() {
    registerFallbackValue(ByteData(1));
  });

  setUp(() {
    keyGenerator = KeyGenerator();
    platform = MockDatadogSessionReplayPlatform();
    DatadogSessionReplayPlatform.instance = platform;
    when(
      () => platform.saveImageForProcessing(any(), any(), any(), any()),
    ).thenAnswer((_) => Future.value());

    context = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
    );
  });

  SessionReplayRecorder createRecorder({
    TextCaptureMode textCaptureMode = TextCaptureMode.highFidelity,
    TextAndInputPrivacyLevel textAndInputPrivacyLevel =
        TextAndInputPrivacyLevel.maskSensitiveInputs,
    int maxImagePixelBudget = defaultMaxImagePixelBudget,
  }) {
    final recorder = SessionReplayRecorder.withCustomRecorders(
      [
        TextElementRecorder(
          keyGenerator,
          textCaptureMode: textCaptureMode,
          maxImagePixelBudget: maxImagePixelBudget,
        ),
        ContainerRecorder(keyGenerator),
      ],
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: textAndInputPrivacyLevel,
        imagePrivacyLevel: ImagePrivacyLevel.maskNone,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
    );
    recorder.updateContext(context);
    return recorder;
  }

  Widget wrap(SessionReplayRecorder recorder, Widget child) {
    return MaterialApp(
      home: SimpleTestCapture(
        key: const Key('key'),
        recorder: recorder,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );
  }

  Future<List<CaptureNode>> capture(
    WidgetTester tester,
    SessionReplayRecorder recorder,
  ) async {
    CaptureResult? result;
    await tester.runAsync(() async {
      result = await recorder.performCapture();
    });
    return result?.viewTreeSnapshot.nodes ?? [];
  }

  List<int> savedResourceKeys() {
    return verify(
      () => platform.saveImageForProcessing(captureAny(), any(), any(), any()),
    ).captured.cast<int>();
  }

  void verifyNothingSaved() {
    verifyNever(
      () => platform.saveImageForProcessing(any(), any(), any(), any()),
    );
  }

  const style = TextStyle(fontSize: 20, color: Color(0xFF000000));

  group('standard mode', () {
    testWidgets('records text as text without uploading', (tester) async {
      final recorder = createRecorder(
        textCaptureMode: TextCaptureMode.standard,
      );
      await tester.pumpWidget(wrap(recorder, const Text('Hello')));

      final nodes = await capture(tester, recorder);

      expect((nodes.single as TextElementCaptureNode).text, 'Hello');
      verifyNothingSaved();
    });
  });

  group('high fidelity mode', () {
    testWidgets('records paragraph as image at its bounds', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          const Padding(
            padding: EdgeInsets.only(left: 10, top: 20),
            child: Text('Hello', style: style),
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      final node = nodes.single as ResourceImageNode;
      final size = tester.getSize(find.byType(RichText));
      expect(node.attributes.paintBounds, const Offset(10, 20) & size);
      expect(node.resourceKey, savedResourceKeys().single);
    });

    testWidgets('uploads drawn pixels at size times DPR', (tester) async {
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      final recorder = createRecorder();
      await tester.pumpWidget(wrap(recorder, const Text('Hi', style: style)));

      await capture(tester, recorder);

      final size = tester.getSize(find.byType(RichText));
      final captured = verify(
        () => platform.saveImageForProcessing(
          any(),
          captureAny(),
          captureAny(),
          captureAny(),
        ),
      ).captured;
      final width = captured[0] as int;
      final height = captured[1] as int;
      expect(width, (size.width * 2).ceil());
      expect(height, (size.height * 2).ceil());
      final bytes = captured[2] as ByteData;
      expect(bytes.lengthInBytes, width * height * 4);

      // The test font draws glyphs as solid boxes, so some pixels are opaque.
      var opaquePixels = 0;
      for (var i = 3; i < bytes.lengthInBytes; i += 4) {
        if (bytes.getUint8(i) == 0xFF) opaquePixels++;
      }
      expect(opaquePixels, greaterThan(0));
    });

    testWidgets('rasterizes paragraphs in any font', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('System', style: TextStyle(fontFamily: 'Roboto')),
              Text('Custom', style: TextStyle(fontFamily: 'MyBrandFont')),
            ],
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      expect(nodes.length, 2);
      expect(nodes, everyElement(isA<ResourceImageNode>()));
      expect(savedResourceKeys().length, 2);
    });

    testWidgets('rasterizes identical paragraphs once per capture', (
      tester,
    ) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [Text('Same'), Text('Same'), Text('Same')],
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      final key = savedResourceKeys().single;
      expect(nodes.length, 3);
      for (final node in nodes) {
        expect((node as ResourceImageNode).resourceKey, key);
      }
    });

    testWidgets('reuses raster in later captures', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(wrap(recorder, const Text('Hello')));

      final first = await capture(tester, recorder);
      final second = await capture(tester, recorder);

      final key = savedResourceKeys().single;
      expect((first.single as ResourceImageNode).resourceKey, key);
      expect((second.single as ResourceImageNode).resourceKey, key);
    });

    testWidgets('rasterizes again when text changes', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(wrap(recorder, const Text('One')));
      await capture(tester, recorder);
      await tester.pumpWidget(wrap(recorder, const Text('Two')));
      await capture(tester, recorder);

      expect(savedResourceKeys().toSet().length, 2);
    });

    testWidgets('rasterizes again when style changes', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(recorder, const Text('Hi', style: TextStyle(color: Colors.red))),
      );
      await capture(tester, recorder);
      await tester.pumpWidget(
        wrap(recorder, const Text('Hi', style: TextStyle(color: Colors.blue))),
      );
      await capture(tester, recorder);

      expect(savedResourceKeys().toSet().length, 2);
    });

    Widget scaled(SessionReplayRecorder recorder, double scale) => wrap(
      recorder,
      Transform.scale(
        scale: scale,
        alignment: Alignment.topLeft,
        child: const Text('Hello', style: style),
      ),
    );

    testWidgets('reuses raster while scaled below layout size', (tester) async {
      final recorder = createRecorder();
      for (final scale in [0.5, 0.8, 1.0]) {
        await tester.pumpWidget(scaled(recorder, scale));
        await capture(tester, recorder);
      }

      expect(savedResourceKeys().length, 1);
    });

    testWidgets('reuses raster for scales within the same step', (
      tester,
    ) async {
      final recorder = createRecorder();
      for (final scale in [1.1, 1.2, 1.25]) {
        await tester.pumpWidget(scaled(recorder, scale));
        await capture(tester, recorder);
      }

      expect(savedResourceKeys().length, 1);
    });

    testWidgets('rasterizes again when scaled up past a step', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(scaled(recorder, 1.0));
      await capture(tester, recorder);
      await tester.pumpWidget(scaled(recorder, 2.0));
      await capture(tester, recorder);

      expect(savedResourceKeys().length, 2);
    });

    testWidgets('downscales oversized paragraphs to the pixel budget', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      final recorder = createRecorder(maxImagePixelBudget: 20000);
      await tester.pumpWidget(
        wrap(recorder, const Text('A long paragraph', style: style)),
      );

      final nodes = await capture(tester, recorder);
      expect(nodes.single, isA<ResourceImageNode>());

      final captured = verify(
        () => platform.saveImageForProcessing(
          any(),
          captureAny(),
          captureAny(),
          any(),
        ),
      ).captured;
      final width = captured[0] as int;
      final height = captured[1] as int;
      expect(width * height, lessThanOrEqualTo(20000));
      final size = tester.getSize(find.byType(RichText));
      // Keeps the paragraph's aspect ratio, within a pixel of rounding.
      expect(width / height, closeTo(size.width / size.height, 0.5));
    });

    for (final downscaling in ImageDownscaling.values) {
      testWidgets('downscales oversized paragraphs with $downscaling', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetDevicePixelRatio);
        final recorder = SessionReplayRecorder(
          defaultCapturePrivacy: TreeCapturePrivacy(
            textAndInputPrivacyLevel:
                TextAndInputPrivacyLevel.maskSensitiveInputs,
            imagePrivacyLevel: ImagePrivacyLevel.maskNone,
          ),
          touchPrivacyLevel: TouchPrivacyLevel.show,
          textCaptureMode: TextCaptureMode.highFidelity,
          imageDownscaling: downscaling,
          maxImagePixelBudget: 20000,
        )..updateContext(context);
        await tester.pumpWidget(
          wrap(recorder, const Text('A long paragraph', style: style)),
        );

        final nodes = await capture(tester, recorder);

        expect(nodes.whereType<ResourceImageNode>().length, 1);
        expect(nodes.whereType<TextElementCaptureNode>(), isEmpty);
      });
    }

    testWidgets('rasterizes again when the selection changes', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          const SelectionArea(child: Text('Selectable text', style: style)),
        ),
      );
      await capture(tester, recorder);

      final textRect = tester.getRect(find.byType(RichText));
      final gesture = await tester.startGesture(
        textRect.centerLeft + const Offset(1, 0),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(textRect.center);
      await gesture.up();
      await tester.pump();
      await capture(tester, recorder);

      expect(savedResourceKeys().toSet().length, 2);
    });

    testWidgets('records WidgetSpan children as their own nodes', (
      tester,
    ) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          const Text.rich(
            TextSpan(
              text: 'Before ',
              children: [
                WidgetSpan(
                  child: ColoredBox(
                    color: Colors.red,
                    child: SizedBox(width: 10, height: 10),
                  ),
                ),
                TextSpan(text: ' after'),
              ],
            ),
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      expect(nodes.whereType<ResourceImageNode>().length, 1);
      expect(
        nodes.whereType<ResourceImageNode>().length,
        lessThan(nodes.length),
      );
    });

    testWidgets('does not rasterize empty text', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(wrap(recorder, const Text('')));

      final nodes = await capture(tester, recorder);

      expect(nodes.whereType<ResourceImageNode>(), isEmpty);
      verifyNothingSaved();
    });

    testWidgets('falls back to text when the upload fails', (tester) async {
      when(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      ).thenThrow(PlatformException(code: 'error'));
      final recorder = createRecorder();
      await tester.pumpWidget(wrap(recorder, const Text('Hello')));

      final nodes = await capture(tester, recorder);

      expect((nodes.single as TextElementCaptureNode).text, 'Hello');
    });
  });

  testWidgets('reads back one paragraph at a time', (tester) async {
    var inFlight = 0;
    var maxInFlight = 0;
    when(
      () => platform.saveImageForProcessing(any(), any(), any(), any()),
    ).thenAnswer((_) async {
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      inFlight--;
    });
    final recorder = createRecorder();
    await tester.pumpWidget(
      wrap(
        recorder,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < 5; i++) Text('Paragraph $i')],
        ),
      ),
    );

    final nodes = await capture(tester, recorder);

    expect(nodes, everyElement(isA<ResourceImageNode>()));
    expect(savedResourceKeys().length, 5);
    expect(maxInFlight, 1);
  });

  testWidgets('records the text shown when the capture started', (
    tester,
  ) async {
    final label = ValueNotifier('Before');
    addTearDown(label.dispose);
    // The changing paragraph comes second, so it's processed after the
    // recorder has already awaited the first one.
    Widget tree(SessionReplayRecorder recorder) => wrap(
      recorder,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Static', style: style),
          SizedBox(
            width: 200,
            height: 20,
            child: ValueListenableBuilder<String>(
              valueListenable: label,
              builder: (context, value, _) => Text(value, style: style),
            ),
          ),
        ],
      ),
    );
    // Uploads happen in tree order, so the last one is the changing paragraph.
    Uint8List savedPixels() {
      final bytes =
          verify(
                () => platform.saveImageForProcessing(
                  any(),
                  any(),
                  any(),
                  captureAny(),
                ),
              ).captured.last
              as ByteData;
      return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    }

    // Pixels of the unchanged text.
    final reference = createRecorder();
    await tester.pumpWidget(tree(reference));
    await capture(tester, reference);
    final expected = savedPixels();
    clearInteractions(platform);

    // A new recorder, so nothing is cached. The text changes after the tree
    // walk but before the pixels are read back.
    final recorder = createRecorder();
    // Unmount first so the capture widget registers with the new recorder.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(tree(recorder));
    await tester.runAsync(() async {
      final pending = recorder.performCapture();
      label.value = 'Changed';
      await tester.pump();
      await pending;
    });

    expect(savedPixels(), expected);
  });

  group('privacy', () {
    testWidgets('maskAll records masked text without uploading', (
      tester,
    ) async {
      final recorder = createRecorder(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      );
      await tester.pumpWidget(wrap(recorder, const Text('Secret')));

      final nodes = await capture(tester, recorder);

      final node = nodes.single as TextElementCaptureNode;
      expect(node.text, isNot(contains('Secret')));
      verifyNothingSaved();
    });

    testWidgets('maskAll subtree records masked text without uploading', (
      tester,
    ) async {
      final recorder = SessionReplayRecorder.withCustomRecorders(
        [
          TextElementRecorder(
            keyGenerator,
            textCaptureMode: TextCaptureMode.highFidelity,
          ),
          PrivacyRecorder(keyGenerator),
        ],
        defaultCapturePrivacy: TreeCapturePrivacy(
          textAndInputPrivacyLevel:
              TextAndInputPrivacyLevel.maskSensitiveInputs,
          imagePrivacyLevel: ImagePrivacyLevel.maskNone,
        ),
        touchPrivacyLevel: TouchPrivacyLevel.show,
      );
      recorder.updateContext(context);
      await tester.pumpWidget(
        wrap(
          recorder,
          const SessionReplayPrivacy(
            textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
            child: Text('Secret'),
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      final node = nodes.single as TextElementCaptureNode;
      expect(node.text, isNot(contains('Secret')));
      verifyNothingSaved();
    });

    for (final level in [
      TextAndInputPrivacyLevel.maskSensitiveInputs,
      TextAndInputPrivacyLevel.maskAllInputs,
    ]) {
      testWidgets('$level rasterizes static text', (tester) async {
        final recorder = createRecorder(textAndInputPrivacyLevel: level);
        await tester.pumpWidget(wrap(recorder, const Text('Visible')));

        final nodes = await capture(tester, recorder);

        expect(nodes.single, isA<ResourceImageNode>());
      });
    }
  });
}
