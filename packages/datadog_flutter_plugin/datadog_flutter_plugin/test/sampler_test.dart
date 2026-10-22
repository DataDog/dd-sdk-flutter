// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2026-Present Datadog, Inc.

import 'package:datadog_flutter_plugin/src/sampler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final maxSeed = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);

  group('DeterministicSampler', () {
    test('sampling decisions are deterministic for a seed', () {
      // Generated using the dd-trace-go implementation with the following
      // program: https://go.dev/play/p/CUrDJtze8E_e. The iOS SDK's
      // DeterministicSamplerTests use the same vectors.
      final inputs = <(BigInt, double, bool)>[
        (BigInt.parse('5577006791947779410'), 94.0509, true),
        (BigInt.parse('15352856648520921629'), 43.7714, true),
        (BigInt.parse('3916589616287113937'), 68.6823, true),
        (BigInt.parse('894385949183117216'), 30.0912, true),
        (BigInt.parse('12156940908066221323'), 46.889, true),
        (BigInt.parse('9828766684487745566'), 15.6519, false),
        (BigInt.parse('4751997750760398084'), 81.364, false),
        (BigInt.parse('11199607447739267382'), 38.0657, false),
        (BigInt.parse('6263450610539110790'), 21.8553, false),
        (BigInt.parse('1874068156324778273'), 36.0871, false),
      ];

      for (final (seed, sampleRate, expected) in inputs) {
        expect(
          DeterministicSampler(sampleRate).sample(seed),
          expected,
          reason: 'seed $seed at $sampleRate%',
        );
      }
    });

    test('sampling decisions are deterministic for a session UUID', () {
      // The seeds above truncated to 48 bits, as the last group of a UUID,
      // which sometimes results in a different decision. Created using this
      // program: https://go.dev/play/p/lUl2SiOHxfZ
      final inputs = <(String, double, bool)>[
        ('11111111-2222-3333-4444-822107fcfd52', 94.050909, true),
        ('11111111-2222-3333-4444-4dc76695721d', 43.771419, true),
        ('11111111-2222-3333-4444-858149c6e2d1', 68.682307, true),
        ('11111111-2222-3333-4444-cb397916001e', 15.651925, false),
        ('11111111-2222-3333-4444-7f48392907a0', 30.091186, true),
        ('11111111-2222-3333-4444-7cc6f3875d04', 81.363996, true),
        ('11111111-2222-3333-4444-ffa2ba517936', 38.065719, true),
        ('11111111-2222-3333-4444-21587cb3ad0b', 46.888984, false),
        ('11111111-2222-3333-4444-768b7c4e0b68', 29.310186, false),
        ('11111111-2222-3333-4444-3f2525632186', 21.855305, false),
      ];

      for (final (uuid, sampleRate, expected) in inputs) {
        expect(
          DeterministicSampler(sampleRate).sampleUuid(uuid),
          expected,
          reason: '$uuid at $sampleRate%',
        );
      }
    });

    test('100% samples every seed', () {
      final sampler = DeterministicSampler(100);

      expect(sampler.sample(BigInt.zero), isTrue);
      expect(sampler.sample(maxSeed), isTrue);
    });

    test('0% never samples a seed', () {
      final sampler = DeterministicSampler(0);

      expect(sampler.sample(BigInt.zero), isFalse);
      expect(sampler.sample(maxSeed), isFalse);
    });

    test('sampling rate is clamped to 0..100', () {
      expect(DeterministicSampler(-10).samplingRate, 0);
      expect(DeterministicSampler(150).samplingRate, 100);
      expect(DeterministicSampler(150).sample(maxSeed), isTrue);
    });

    test('seedFromUuid uses the last 48 bits of the UUID', () {
      expect(
        DeterministicSampler.seedFromUuid(
          'aaaaaaaa-bbbb-cccc-dddd-0123456789ab',
        ),
        BigInt.parse('0123456789ab', radix: 16),
      );
    });

    test('seedFromUuid falls back to 0 for an invalid UUID', () {
      expect(DeterministicSampler.seedFromUuid(''), BigInt.zero);
      expect(DeterministicSampler.seedFromUuid('not-a-uuid'), BigInt.zero);
    });

    test('combined multiplies the rates', () {
      expect(DeterministicSampler(50).combined(50).samplingRate, 25);
      expect(DeterministicSampler(10).combined(100).samplingRate, 10);
      expect(DeterministicSampler(100).combined(0).samplingRate, 0);
    });

    test('a combined sampler only samples what its parent samples', () {
      final parent = DeterministicSampler(50);
      final child = parent.combined(50);

      var parentSampled = 0;
      var childSampled = 0;
      for (var i = 0; i < 10000; i++) {
        final seed = BigInt.from(i) * BigInt.parse('9E3779B97F4A', radix: 16);
        final inParent = parent.sample(seed);
        final inChild = child.sample(seed);
        if (inParent) parentSampled++;
        if (inChild) childSampled++;
        if (inChild) expect(inParent, isTrue, reason: 'seed $seed');
      }
      expect(childSampled, lessThan(parentSampled));
      expect(childSampled, greaterThan(0));
    });

    test('samplers with the same rate are equal', () {
      expect(DeterministicSampler(20), DeterministicSampler(20));
      expect(DeterministicSampler(20), isNot(DeterministicSampler(30)));
    });
  });
}
