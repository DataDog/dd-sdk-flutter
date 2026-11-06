// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:async';

import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/raster_resources.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rasterScale', () {
    for (final (scale, expected) in [
      (0.0, 1.0),
      (0.5, 1.0),
      (1.0, 1.0),
      (1.01, 1.25),
      (1.25, 1.25),
      (1.3, 1.5),
      (2.0, 2.0),
    ]) {
      test('rasterizes scale $scale at $expected', () {
        expect(rasterScale(scale), expected);
      });
    }
  });

  group('rasterBitmapSize', () {
    for (final (logical, ratio, expected) in [
      (const Size(20, 20), 1.0, (width: 20, height: 20)),
      (const Size(24, 24), 3.0, (width: 72, height: 72)),
      (const Size(20.1, 10), 2.0, (width: 41, height: 20)),
      (const Size(0.1, 0.1), 1.0, (width: 1, height: 1)),
    ]) {
      test('sizes $logical at ${ratio}x as $expected', () {
        expect(
          rasterBitmapSize(
            logical,
            ratio,
            maxPixels: defaultMaxImagePixelBudget,
            downscaling: ImageDownscaling.disabled,
          ),
          expected,
        );
      });
    }

    test('returns null over budget when downscaling is disabled', () {
      expect(
        rasterBitmapSize(
          const Size(100, 20),
          3.0,
          maxPixels: 2000,
          downscaling: ImageDownscaling.disabled,
        ),
        isNull,
      );
    });

    test('fits budget when downscaling is enabled', () {
      expect(
        rasterBitmapSize(
          const Size(100, 20),
          3.0,
          maxPixels: 2000,
          downscaling: ImageDownscaling.enabled,
        ),
        (width: 100, height: 20),
      );
    });
  });

  group('fitPixelBudget', () {
    test('keeps size within budget', () {
      expect(fitPixelBudget(300, 60, 18000), (width: 300, height: 60));
    });

    test('shrinks to budget keeping aspect ratio', () {
      expect(fitPixelBudget(600, 600, 10000), (width: 100, height: 100));
    });

    test('never shrinks a side below one pixel', () {
      expect(fitPixelBudget(10000, 1, 100), (width: 1000, height: 1));
    });
  });

  group('RasterResourceCache', () {
    test('rasterizes concurrent requests for a key once', () async {
      final cache = RasterResourceCache<String>();
      final completer = Completer<int?>();
      var calls = 0;
      Future<int?> rasterize() {
        calls++;
        return completer.future;
      }

      final first = cache.rasterizeOnce('a', rasterize);
      final second = cache.rasterizeOnce('a', rasterize);
      completer.complete(7);

      expect(await first, 7);
      expect(await second, 7);
      expect(calls, 1);
      expect(cache.hasResourceKey('a'), isTrue);
      expect(cache.lookup('a'), 7);
    });

    test('does not remember failures', () async {
      final cache = RasterResourceCache<String>();

      expect(await cache.rasterizeOnce('a', () async => null), isNull);
      await expectLater(
        cache.rasterizeOnce('a', () async => throw StateError('failed')),
        throwsStateError,
      );
      expect(cache.hasResourceKey('a'), isFalse);
      expect(cache.lookup('a'), isNull);
      expect(await cache.rasterizeOnce('a', () async => 3), 3);
    });

    test('checking for a key does not mark it as recently used', () async {
      final cache = RasterResourceCache<String>(maxEntries: 2);
      await cache.rasterizeOnce('a', () async => 1);
      await cache.rasterizeOnce('b', () async => 2);
      expect(cache.hasResourceKey('a'), isTrue);
      await cache.rasterizeOnce('c', () async => 3);

      expect(cache.hasResourceKey('a'), isFalse);
      expect(cache.hasResourceKey('b'), isTrue);
    });

    test('evicts least recently used keys', () async {
      final cache = RasterResourceCache<String>(maxEntries: 2);
      await cache.rasterizeOnce('a', () async => 1);
      await cache.rasterizeOnce('b', () async => 2);
      cache.lookup('a');
      await cache.rasterizeOnce('c', () async => 3);

      expect(cache.lookup('a'), 1);
      expect(cache.lookup('b'), isNull);
      expect(cache.lookup('c'), 3);
    });
  });
}
