// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/common_nodes.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/icon_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/image_recorder.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/text_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_platform_interface.dart';
import 'package:datadog_session_replay/src/processor/font_family_transform.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'simple_test_capture.dart';

class MockDatadogSessionReplayPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements DatadogSessionReplayPlatform {}

const _customIcon = IconData(0xe900, fontFamily: 'CustomIcons');
const _otherCustomIcon = IconData(0xe901, fontFamily: 'CustomIcons');
const _packagedIcon = IconData(
  0xe900,
  fontFamily: 'CustomIcons',
  fontPackage: 'custom_icons',
);

/// Like Font Awesome's FaIcon: an [Icon] whose box hugs the glyph instead of
/// being square.
class _NarrowIcon extends Icon {
  const _NarrowIcon(super.icon, {super.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 15, height: 24, child: super.build(context));
  }
}

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
    ImagePrivacyLevel imagePrivacyLevel = ImagePrivacyLevel.maskNone,
    TextAndInputPrivacyLevel textAndInputPrivacyLevel =
        TextAndInputPrivacyLevel.maskAll,
  }) {
    final recorder = SessionReplayRecorder.withCustomRecorders(
      [
        TextElementRecorder(keyGenerator),
        IconRecorder(keyGenerator),
      ],
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: textAndInputPrivacyLevel,
        imagePrivacyLevel: imagePrivacyLevel,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
    );
    recorder.updateContext(context);
    return recorder;
  }

  Widget wrap(
    SessionReplayRecorder recorder,
    Widget child, {
    TextDirection textDirection = TextDirection.ltr,
  }) {
    return MaterialApp(
      home: SimpleTestCapture(
        key: const Key('key'),
        recorder: recorder,
        child: Directionality(
          textDirection: textDirection,
          child: Align(alignment: Alignment.topLeft, child: child),
        ),
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

  group('image privacy', () {
    testWidgets('maskAll records unknown icon glyph without uploading', (
      tester,
    ) async {
      final recorder = createRecorder(
        imagePrivacyLevel: ImagePrivacyLevel.maskAll,
      );
      await tester.pumpWidget(
        wrap(
          recorder,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.home),
              Icon(_customIcon, size: 30, color: Color(0xFF112233)),
            ],
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      expect(nodes.length, 2);
      for (final node in nodes) {
        final glyph = node as TextElementCaptureNode;
        expect(glyph.text, String.fromCharCode(unknownIconCodePoint));
        expect(glyph.family, materialIconsFontFamily);
      }
      final custom = nodes.last as TextElementCaptureNode;
      expect(custom.size, 30);
      expect(custom.color, '#112233ff');
      verifyNever(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      );
    });

    testWidgets('maskAll keeps color of icon with blend mode', (tester) async {
      final recorder = createRecorder(
        imagePrivacyLevel: ImagePrivacyLevel.maskAll,
      );
      await tester.pumpWidget(
        wrap(
          recorder,
          const Icon(
            _customIcon,
            color: Color(0xFF112233),
            blendMode: BlendMode.multiply,
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      final glyph = nodes.single as TextElementCaptureNode;
      expect(glyph.text, String.fromCharCode(unknownIconCodePoint));
      expect(glyph.color, '#112233ff');
    });

    for (final level in [
      ImagePrivacyLevel.maskNone,
      ImagePrivacyLevel.maskNonAssetsOnly,
    ]) {
      testWidgets('$level records Material icon as text', (tester) async {
        final recorder = createRecorder(imagePrivacyLevel: level);
        await tester.pumpWidget(wrap(recorder, const Icon(Icons.home)));

        final nodes = await capture(tester, recorder);

        expect(nodes.length, 1);
        expect(nodes.first, isA<TextElementCaptureNode>());
      });

      testWidgets('$level records custom icon as image', (tester) async {
        final recorder = createRecorder(imagePrivacyLevel: level);
        await tester.pumpWidget(wrap(recorder, const Icon(_customIcon)));

        final nodes = await capture(tester, recorder);

        expect(nodes.length, 1);
        expect(nodes.first, isA<ResourceImageNode>());
        expect(savedResourceKeys().length, 1);
      });
    }
  });

  group('Material icons', () {
    testWidgets('records glyph unmasked in MaterialIcons font', (
      tester,
    ) async {
      final recorder = createRecorder(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
      );
      await tester.pumpWidget(
        wrap(
          recorder,
          const Icon(Icons.home, size: 30, color: Color(0xFF112233)),
        ),
      );

      final nodes = await capture(tester, recorder);

      expect(nodes.length, 1);
      final node = nodes.first as TextElementCaptureNode;
      expect(node.text, String.fromCharCode(Icons.home.codePoint));
      expect(node.family, materialIconsFontFamily);
      expect(node.size, 30);
      expect(node.color, '#112233ff');
      expect(node.alignment, SRHorizontalAlignment.center);
      expect(node.verticalAlignment, SRVerticalAlignment.center);
      expect(node.attributes.width, 30);
      expect(node.attributes.height, 30);
      verifyNever(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      );
    });

    testWidgets('does not record inner RichText as text', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [Icon(Icons.home), Icon(_customIcon)],
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      expect(nodes.length, 2);
      final texts = nodes.whereType<TextElementCaptureNode>().toList();
      expect(texts.length, 1);
      expect(texts.first.family, materialIconsFontFamily);
    });

    testWidgets('applies icon theme opacity to color', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          const IconTheme(
            data: IconThemeData(color: Color(0xFF000000), opacity: 0.5),
            child: Icon(Icons.home),
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      final node = nodes.first as TextElementCaptureNode;
      expect(node.color, '#00000080');
    });

    testWidgets('scales size with transforms', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          Transform.scale(
            scale: 2.0,
            alignment: Alignment.topLeft,
            child: const Icon(Icons.home, size: 20),
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      final node = nodes.first as TextElementCaptureNode;
      expect(node.size, 40);
    });

    testWidgets('rasterizes when drawn with shadows', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          const Icon(
            Icons.home,
            shadows: [Shadow(blurRadius: 2, offset: Offset(1, 1))],
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      expect(nodes.first, isA<ResourceImageNode>());
    });

    testWidgets('ignores font variations, which MaterialIcons lacks', (
      tester,
    ) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(recorder, const Icon(Icons.home, fill: 1.0, weight: 700)),
      );

      final nodes = await capture(tester, recorder);

      expect(nodes.first, isA<TextElementCaptureNode>());
    });

    testWidgets('rasterizes when drawn with a blend mode', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(recorder, const Icon(Icons.home, blendMode: BlendMode.multiply)),
      );

      final nodes = await capture(tester, recorder);

      expect(nodes.first, isA<ResourceImageNode>());
    });

    testWidgets('rasterizes when mirrored for right-to-left', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          const Icon(Icons.arrow_back),
          textDirection: TextDirection.rtl,
        ),
      );

      final nodes = await capture(tester, recorder);

      expect(Icons.arrow_back.matchTextDirection, isTrue);
      expect(nodes.first, isA<ResourceImageNode>());
    });
  });

  group('custom icons', () {
    testWidgets('records image at icon bounds', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(recorder, const Icon(_customIcon, size: 30)),
      );

      final nodes = await capture(tester, recorder);

      final node = nodes.first as ResourceImageNode;
      expect(node.attributes.width, 30);
      expect(node.attributes.height, 30);
      expect(node.resourceKey, savedResourceKeys().single);
    });

    testWidgets('uploads transparent square raster at size times DPR', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          const Icon(_customIcon, size: 20, color: Color(0xFFFF0000)),
        ),
      );

      await capture(tester, recorder);

      final captured = verify(
        () => platform.saveImageForProcessing(
          any(),
          captureAny(),
          captureAny(),
          captureAny(),
        ),
      ).captured;
      // 20dp at 2x.
      expect(captured[0], 40);
      expect(captured[1], 40);
      final bytes = captured[2] as ByteData;
      expect(bytes.lengthInBytes, 40 * 40 * 4);
      // Corners are outside the glyph and stay transparent.
      expect(bytes.getUint8(3), 0);
    });

    testWidgets('rasterizes identical icons once per capture', (
      tester,
    ) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(_customIcon),
              Icon(_customIcon),
              Icon(_customIcon),
            ],
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
      await tester.pumpWidget(wrap(recorder, const Icon(_customIcon)));

      final first = await capture(tester, recorder);
      final second = await capture(tester, recorder);

      final key = savedResourceKeys().single;
      expect((first.single as ResourceImageNode).resourceKey, key);
      expect((second.single as ResourceImageNode).resourceKey, key);
    });

    testWidgets('rasterizes separately per size', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(_customIcon, size: 18),
              Icon(_customIcon, size: 22),
              Icon(_customIcon, size: 22),
            ],
          ),
        ),
      );

      await capture(tester, recorder);

      expect(savedResourceKeys().length, 2);
    });

    testWidgets('rasterizes again when transform scale changes', (
      tester,
    ) async {
      final recorder = createRecorder();
      Widget scaled(double scale) => wrap(
            recorder,
            Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: const Icon(_customIcon, size: 20),
            ),
          );

      await tester.pumpWidget(scaled(1.0));
      await capture(tester, recorder);
      await tester.pumpWidget(scaled(1.5));
      await capture(tester, recorder);

      expect(savedResourceKeys().length, 2);
    });

    testWidgets('rasterizes non-square icon boxes at their own size', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetDevicePixelRatio);
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(recorder, const _NarrowIcon(_customIcon, size: 24)),
      );

      final nodes = await capture(tester, recorder);

      final node = nodes.single as ResourceImageNode;
      expect(node.attributes.width, 15);
      expect(node.attributes.height, 24);
      final captured = verify(
        () => platform.saveImageForProcessing(
          any(),
          captureAny(),
          captureAny(),
          any(),
        ),
      ).captured;
      expect(captured, [30, 48]);
    });

    testWidgets('rasterizes again when device pixel ratio changes', (
      tester,
    ) async {
      addTearDown(tester.view.resetDevicePixelRatio);
      final recorder = createRecorder();

      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(wrap(recorder, const Icon(_customIcon)));
      await capture(tester, recorder);
      tester.view.devicePixelRatio = 3.0;
      await tester.pumpWidget(wrap(recorder, const Icon(_customIcon)));
      await capture(tester, recorder);

      final sizes = verify(
        () =>
            platform.saveImageForProcessing(any(), captureAny(), any(), any()),
      ).captured;
      expect(sizes, [48, 72]);
    });

    testWidgets('rasterizes separately per color', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(_customIcon, color: Color(0xFFFF0000)),
              Icon(_customIcon, color: Color(0xFF00FF00)),
            ],
          ),
        ),
      );

      final nodes = await capture(tester, recorder);

      final keys = savedResourceKeys();
      expect(keys.length, 2);
      expect(
        nodes.map((n) => (n as ResourceImageNode).resourceKey).toSet(),
        keys.toSet(),
      );
    });

    testWidgets('rasterizes packaged font separately', (tester) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [Icon(_customIcon), Icon(_packagedIcon)],
          ),
        ),
      );

      await capture(tester, recorder);

      expect(savedResourceKeys().length, 2);
    });

    testWidgets('rasterizes every distinct icon in one capture', (
      tester,
    ) async {
      final recorder = createRecorder();
      await tester.pumpWidget(
        wrap(
          recorder,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(_customIcon, color: Color(0xFFFF0000)),
              Icon(_customIcon, color: Color(0xFF00FF00)),
              Icon(_customIcon, color: Color(0xFF0000FF)),
              // Same raster as the first icon.
              Icon(_customIcon, color: Color(0xFFFF0000)),
              Icon(_otherCustomIcon),
            ],
          ),
        ),
      );

      final nodes = await capture(tester, recorder);
      expect(nodes.length, 5);
      expect(savedResourceKeys().length, 4);

      await capture(tester, recorder);
      verifyNever(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      );
    });

    testWidgets('records unknown icon glyph when upload fails', (
      tester,
    ) async {
      when(
        () => platform.saveImageForProcessing(any(), any(), any(), any()),
      ).thenThrow(Exception('failed'));
      final recorder = createRecorder();
      await tester.pumpWidget(wrap(recorder, const Icon(_customIcon)));

      final nodes = await capture(tester, recorder);

      final glyph = nodes.single as TextElementCaptureNode;
      expect(glyph.text, String.fromCharCode(unknownIconCodePoint));
      expect(glyph.family, materialIconsFontFamily);
    });
  });

  testWidgets('records nothing for Icon without data', (tester) async {
    final recorder = createRecorder();
    await tester.pumpWidget(wrap(recorder, const Icon(null)));

    final nodes = await capture(tester, recorder);

    expect(nodes, isEmpty);
  });

  testWidgets('resolves the same style Icon draws with', (tester) async {
    const icons = [
      Icon(Icons.home),
      Icon(_packagedIcon, size: 30, color: Color(0xFF123456)),
      Icon(
        Icons.star,
        fill: 1,
        weight: 700,
        grade: 25,
        opticalSize: 48,
        applyTextScaling: true,
        shadows: [Shadow(blurRadius: 2)],
      ),
      Icon(_customIcon, blendMode: BlendMode.multiply),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: IconTheme(
            data: const IconThemeData(color: Color(0xFF00FF00), opacity: 0.5),
            child: Column(children: icons),
          ),
        ),
      ),
    );

    for (final icon in icons) {
      final element = tester.element(find.byWidget(icon));
      final richText = tester.widget<RichText>(
        find.descendant(
          of: find.byWidget(icon),
          matching: find.byType(RichText),
        ),
      );
      final drawn = (richText.text as TextSpan).style!;
      final (style: resolved, :color) = IconRecorder.resolveStyle(
        icon,
        icon.icon!,
        element,
      );

      expect(
        color.toARGB32(),
        (drawn.color ?? drawn.foreground!.color).toARGB32(),
      );
      expect(resolved.foreground?.blendMode, drawn.foreground?.blendMode);
      expect(resolved.fontSize, drawn.fontSize);
      expect(resolved.fontFamily, drawn.fontFamily);
      expect(resolved.fontFamilyFallback, drawn.fontFamilyFallback);
      expect(resolved.fontVariations, drawn.fontVariations);
      expect(resolved.shadows, drawn.shadows);
      expect(resolved.height, drawn.height);
      expect(resolved.leadingDistribution, drawn.leadingDistribution);
    }
  });

  test('unknown icon glyph is the Material outlined square', () {
    expect(unknownIconCodePoint, Icons.square_outlined.codePoint);
    expect(Icons.square_outlined.fontFamily, materialIconsFontFamily);
  });

  group('rasterPixelSize', () {
    test('applies device pixel ratio and rounds up', () {
      expect(IconRecorder.rasterPixelSize(20, 1.0), 20);
      expect(IconRecorder.rasterPixelSize(24, 3.0), 72);
      expect(IconRecorder.rasterPixelSize(20.1, 2.0), 41);
      expect(IconRecorder.rasterPixelSize(0.1, 1.0), 1);
    });

    test('does not cap size for large icons', () {
      expect(IconRecorder.rasterPixelSize(500, 3.0), 1500);
    });
  });

  group('IconRasterKey', () {
    IconRasterKey key({
      TextStyle style = const TextStyle(fontFamily: 'CustomIcons'),
      Color color = const Color(0xFF123456),
      String glyph = 'a',
      bool flipped = false,
      double logicalWidth = 24,
      double logicalHeight = 24,
      double devicePixelRatio = 2,
    }) {
      return IconRasterKey.fromStyle(
        glyph: glyph,
        style: style,
        color: color,
        flipped: flipped,
        logicalWidth: logicalWidth,
        logicalHeight: logicalHeight,
        devicePixelRatio: devicePixelRatio,
      );
    }

    test('equal for equal inputs', () {
      final style = TextStyle(
        fontFamily: 'CustomIcons',
        fontFamilyFallback: const ['Fallback'],
        fontVariations: const [ui.FontVariation('FILL', 1)],
        shadows: const [Shadow(blurRadius: 1)],
      );
      final other = style.copyWith();
      expect(key(style: style), key(style: other));
      expect(key(style: style).hashCode, key(style: other).hashCode);
    });

    test('differs by each input', () {
      final base = key();
      expect(key(glyph: 'b'), isNot(base));
      expect(key(flipped: true), isNot(base));
      expect(key(logicalWidth: 15), isNot(base));
      expect(key(logicalHeight: 36), isNot(base));
      // Same 48px bitmap, but a different size and DPR.
      expect(
        key(logicalWidth: 16, logicalHeight: 16, devicePixelRatio: 3),
        isNot(base),
      );
      expect(
        key(style: const TextStyle(fontFamily: 'packages/p/CustomIcons')),
        isNot(base),
      );
      expect(key(color: const Color(0xFF000000)), isNot(base));
      expect(
        key(
          style: const TextStyle(
            fontFamily: 'CustomIcons',
            fontVariations: [ui.FontVariation('wght', 700)],
          ),
        ),
        isNot(base),
      );
      expect(
        key(
          style: const TextStyle(
            fontFamily: 'CustomIcons',
            shadows: [Shadow(blurRadius: 1)],
          ),
        ),
        isNot(base),
      );
      expect(
        key(
          style: const TextStyle(
            fontFamily: 'CustomIcons',
            fontFamilyFallback: ['Fallback'],
          ),
        ),
        isNot(base),
      );
    });

    test('keys blend mode paint by its blend mode', () {
      Paint paint(BlendMode mode) => Paint()
        ..color = const Color(0xFF123456)
        ..blendMode = mode;
      TextStyle style(BlendMode mode) =>
          TextStyle(fontFamily: 'CustomIcons', foreground: paint(mode));

      expect(
        key(style: style(BlendMode.multiply)),
        key(style: style(BlendMode.multiply)),
      );
      expect(
        key(style: style(BlendMode.multiply)),
        isNot(key(style: style(BlendMode.screen))),
      );
    });
  });
}
