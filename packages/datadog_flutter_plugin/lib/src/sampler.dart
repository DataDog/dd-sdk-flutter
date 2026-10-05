// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:math';

import '../datadog_internal.dart';

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

/// Sampler that makes consistent sampling decisions for a seed, using Knuth
/// hashing: the same seed always gets the same decision at a given rate.
class DeterministicSampler {
  // Knuth hashing factor (large prime that fits in 64 bits), shared with all
  // Datadog SDKs and the backend. BigInt keeps the 64-bit math exact on web as
  // well.
  static final _knuthFactor = BigInt.parse('1111111111111111111');
  static final BigInt _maxUint64 = BigInt.parse('FFFFFFFFFFFFFFFF', radix: 16);

  /// Value between 0 and 100, where 0 means nothing is sampled and 100 means
  /// everything is.
  final double samplingRate;

  DeterministicSampler(double samplingRate)
      : samplingRate = samplingRate.clamp(0.0, 100.0);

  /// Whether [seed], a 64-bit value, is sampled at [samplingRate].
  bool sample(BigInt seed) {
    if (samplingRate == 100.0) return true;

    final hash = (seed * _knuthFactor) & _maxUint64;
    final threshold =
        BigInt.from(_maxUint64.toDouble() * (samplingRate / 100.0));
    return hash < threshold;
  }

  /// Whether the UUID [uuid], such as a RUM session ID, is sampled at
  /// [samplingRate]. See [seedFromUuid].
  bool sampleUuid(String uuid) => sample(seedFromUuid(uuid));

  /// Whether a trace should be sampled based on its Trace Id.
  bool sampleTrace(TracingId traceId) {
    final lowBits = traceId.value & _maxUint64;
    return sample(lowBits);
  }

  /// The seed for a UUID string: its last 48 bits (the last 12 hex digits), as
  /// the native SDKs use.
  ///
  /// An invalid UUID falls back to seed 0, whose hash is 0, so it is sampled
  /// for any rate above 0 (fail-open).
  static BigInt seedFromUuid(String uuid) {
    final hex = uuid.replaceAll('-', '');
    final seed = hex.length >= 12
        ? int.tryParse(hex.substring(hex.length - 12), radix: 16) ?? 0
        : 0;
    return BigInt.from(seed);
  }

  /// Returns a sampler that applies both this sampler's rate and [childRate].
  ///
  /// Use this when a feature has its own sample rate on top of the RUM session
  /// sample rate: for the same seed, anything sampled by the result is also
  /// sampled by this one.
  DeterministicSampler combined(double childRate) {
    return DeterministicSampler(
      samplingRate * (childRate.clamp(0.0, 100.0) / 100.0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DeterministicSampler && other.samplingRate == samplingRate;

  @override
  int get hashCode => samplingRate.hashCode;
}
