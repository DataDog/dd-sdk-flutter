// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:math';

class RateBasedSampler {
  final double sampleRate;
  late final Random random;

  /// [sampleRate] should be between 0 and 1
  RateBasedSampler(this.sampleRate) {
    try {
      random = Random.secure();
    } on UnsupportedError {
      random = Random();
    }
  }

  bool sample() {
    if (sampleRate <= 0.0) return false;
    if (sampleRate >= 1.0) return true;
    return random.nextDouble() <= sampleRate;
  }
}

/// Sampler that makes consistent sampling decisions for a given [seed], using
/// Knuth hashing. Mirrors `DeterministicSampler` in the iOS and Android SDKs,
/// so all of them make the same decision for the same seed and rate.
class DeterministicSampler {
  // Knuth hashing factor (large prime that fits in 64 bits), shared with the
  // iOS and Android SDKs. BigInt keeps the 64-bit math exact on web as well.
  static final _knuthFactor = BigInt.parse('1111111111111111111');
  static final BigInt _maxUint64 = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);

  /// The 64-bit input for Knuth hashing.
  final BigInt seed;

  /// Value between 0 and 100, where 0 means nothing is sampled and 100 means
  /// everything is.
  final double samplingRate;

  /// The sampling decision for [seed] at [samplingRate].
  final bool isSampled;

  DeterministicSampler(this.seed, double samplingRate)
      : samplingRate = samplingRate.clamp(0.0, 100.0),
        isSampled = _computeIsSampled(seed, samplingRate.clamp(0.0, 100.0));

  /// Derives the seed from a UUID string, such as a RUM session ID, using its
  /// last 48 bits (the last 12 hex digits).
  ///
  /// An invalid UUID falls back to seed 0, whose hash is 0, so it is sampled
  /// for any rate above 0 (fail-open), as in the iOS SDK.
  factory DeterministicSampler.fromUuid(String uuid, double samplingRate) {
    final hex = uuid.replaceAll('-', '');
    final seed = hex.length >= 12
        ? int.tryParse(hex.substring(hex.length - 12), radix: 16) ?? 0
        : 0;
    return DeterministicSampler(BigInt.from(seed), samplingRate);
  }

  /// Returns `true` if data should be sampled.
  bool sample() => isSampled;

  /// Returns a sampler that applies both this sampler's rate and [childRate],
  /// keeping the same seed so decisions stay consistent.
  ///
  /// Use this when a feature has its own sample rate on top of the RUM session
  /// sample rate: anything sampled by the result is also sampled by this one.
  DeterministicSampler combined(double childRate) {
    final composedRate = samplingRate * childRate.clamp(0.0, 100.0) / 100.0;
    return DeterministicSampler(seed, composedRate);
  }

  static bool _computeIsSampled(BigInt seed, double samplingRate) {
    if (samplingRate == 100.0) return true;

    final hash = (seed * _knuthFactor) & _maxUint64;
    final threshold = _maxUint64.toDouble() * samplingRate / 100.0;
    return hash.toDouble() < threshold;
  }

  @override
  bool operator ==(Object other) =>
      other is DeterministicSampler &&
      other.seed == seed &&
      other.samplingRate == samplingRate;

  @override
  int get hashCode => Object.hash(seed, samplingRate);
}
