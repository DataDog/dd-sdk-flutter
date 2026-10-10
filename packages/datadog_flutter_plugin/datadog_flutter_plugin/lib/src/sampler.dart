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
