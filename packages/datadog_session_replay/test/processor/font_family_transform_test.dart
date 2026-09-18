// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/processor/font_family_transform.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('stripPackageFontPrefix', () {
    test('strips packages/<pkg>/ prefix', () {
      expect(
        stripPackageFontPrefix('packages/google_fonts/Roboto'),
        'Roboto',
      );
      expect(stripPackageFontPrefix('Roboto'), 'Roboto');
      expect(stripPackageFontPrefix('packages/foo/bar/Baz'), 'bar/Baz');
    });
  });

  group('FontFamilyTransform', () {
    const iosStack = defaultReplayFontStack;
    const smartConfig = FontFamilyTransformConfig(
      strategy: FontFamilyStrategy.smart,
    );

    test('none returns input unchanged', () {
      final t = FontFamilyTransform(
        const FontFamilyTransformConfig(strategy: FontFamilyStrategy.none),
      );
      const raw = 'packages/google_fonts/Roboto';
      expect(t.transformFamily(raw), raw);
    });

    test('fallback always returns iOS-parity stack', () {
      final t = FontFamilyTransform(
        const FontFamilyTransformConfig(strategy: FontFamilyStrategy.fallback),
      );
      expect(t.transformFamily(''), iosStack);
      expect(t.transformFamily('Anything'), iosStack);
    });

    test('smart: empty becomes iOS-parity stack', () {
      final t = FontFamilyTransform(smartConfig);
      expect(t.transformFamily(''), iosStack);
      expect(t.transformFamily('   '), iosStack);
    });

    test('smart: rules empty key overrides fallback for empty captured', () {
      final t = FontFamilyTransform(
        FontFamilyTransformConfig(
          strategy: FontFamilyStrategy.smart,
          rules: {'': 'Georgia, serif'},
        ),
      );
      expect(t.transformFamily(''), 'Georgia, serif');
      expect(t.transformFamily('   '), 'Georgia, serif');
    });

    test('smart: rules empty key applies when only sentinels remain', () {
      final t = FontFamilyTransform(
        FontFamilyTransformConfig(
          strategy: FontFamilyStrategy.smart,
          rules: {'': 'Verdana, sans-serif'},
        ),
      );
      expect(t.transformFamily('CupertinoSystemText'), 'Verdana, sans-serif');
    });

    test('smart: rules empty key whitespace-only value uses default stack', () {
      final t = FontFamilyTransform(
        FontFamilyTransformConfig(
          strategy: FontFamilyStrategy.smart,
          rules: {'': '   '},
        ),
      );
      expect(t.transformFamily(''), iosStack);
    });

    test('smart: only sentinels become iOS-parity stack', () {
      final t = FontFamilyTransform(smartConfig);
      expect(t.transformFamily('CupertinoSystemText'), iosStack);
      expect(t.transformFamily('.SF UI Text'), iosStack);
    });

    test('smart: packages prefix stripped and sans-serif appended', () {
      final t = FontFamilyTransform(smartConfig);
      expect(
        t.transformFamily('packages/google_fonts/Roboto'),
        'Roboto, sans-serif',
      );
    });

    test('smart: comma-separated list preserves order and drops sentinel', () {
      final t = FontFamilyTransform(smartConfig);
      expect(
        t.transformFamily('Roboto, CupertinoSystemText'),
        'Roboto, sans-serif',
      );
    });

    test('smart: quotes spaces in family names', () {
      final t = FontFamilyTransform(smartConfig);
      expect(
        t.transformFamily('Open Sans'),
        "'Open Sans', sans-serif",
      );
    });

    test('smart: rules override before sentinel strip', () {
      final t = FontFamilyTransform(
        FontFamilyTransformConfig(
          strategy: FontFamilyStrategy.smart,
          rules: {
            'CupertinoSystemText': 'Inter, sans-serif',
          },
        ),
      );
      expect(t.transformFamily('CupertinoSystemText'), 'Inter, sans-serif');
    });

    test('smart: rules match stripped packages key', () {
      final t = FontFamilyTransform(
        FontFamilyTransformConfig(
          strategy: FontFamilyStrategy.smart,
          rules: {
            'Roboto': 'Lato, sans-serif',
          },
        ),
      );
      expect(
        t.transformFamily('packages/google_fonts/Roboto'),
        'Lato, sans-serif',
      );
    });

    test('smart: rules prefer peeled key over stripped when both exist', () {
      final t = FontFamilyTransform(
        FontFamilyTransformConfig(
          strategy: FontFamilyStrategy.smart,
          rules: {
            'packages/foo/Roboto': 'FromPeeled',
            'Roboto': 'FromStripped',
          },
        ),
      );
      expect(
          t.transformFamily('packages/foo/Roboto'), 'FromPeeled, sans-serif');
    });

    test('smart: does not append sans-serif when already generic', () {
      final t = FontFamilyTransform(smartConfig);
      expect(t.transformFamily('serif'), 'serif');
      expect(t.transformFamily('monospace'), 'monospace');
      expect(t.transformFamily('Roboto, sans-serif'), 'Roboto, sans-serif');
    });

    test('smart: idempotent on iOS-parity stack', () {
      final t = FontFamilyTransform(smartConfig);
      final once = t.transformFamily('');
      expect(once, iosStack);
      final twice = t.transformFamily(once);
      expect(twice, once);
    });

    test('smart: idempotent on typical transformed output', () {
      final t = FontFamilyTransform(smartConfig);
      final once = t.transformFamily('Roboto');
      final twice = t.transformFamily(once);
      expect(once, 'Roboto, sans-serif');
      expect(twice, once);
    });

    test('apply updates SRTextWireframe textStyle.family', () {
      final t = FontFamilyTransform(smartConfig);
      final w = SRTextWireframe(
        id: 1,
        x: 0,
        y: 0,
        width: 10,
        height: 10,
        text: 'hi',
        textStyle: SRTextStyle(
          color: '#FF0000FF',
          family: '',
          size: 12,
        ),
      );
      final out = t.apply(w);
      expect(out.textStyle.family, iosStack);
      expect(identical(out, w), isFalse);
    });

    test('apply returns same instance when none strategy', () {
      final t = FontFamilyTransform(
        const FontFamilyTransformConfig(strategy: FontFamilyStrategy.none),
      );
      final w = SRTextWireframe(
        id: 1,
        x: 0,
        y: 0,
        width: 10,
        height: 10,
        text: 'hi',
        textStyle: SRTextStyle(
          color: '#FF0000FF',
          family: 'packages/x/Y',
          size: 12,
        ),
      );
      final out = t.apply(w);
      expect(identical(out, w), isTrue);
    });

    test('smart: re-applying iOS-parity stack is idempotent string', () {
      final t = FontFamilyTransform(smartConfig);
      expect(t.transformFamily(defaultReplayFontStack), defaultReplayFontStack);
    });
  });
}
