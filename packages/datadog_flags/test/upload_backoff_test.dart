// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:math';
import 'package:datadog_flags/src/flags_runtime.dart';
import 'package:test/test.dart';

void main() {
  test('backoff increases, expires monotonically, caps, and resets', () {
    var elapsed = Duration.zero;
    final backoff = UploadBackoff(elapsed: () => elapsed, random: Random(7));
    expect(backoff.remaining, Duration.zero);
    for (var failure = 0; failure < 12; failure++) {
      backoff.failed();
      final base = min(500 * (1 << min(failure, 7)), 60000);
      expect(
        backoff.remaining.inMilliseconds,
        inInclusiveRange((base * .8).floor(), min((base * 1.2).ceil(), 60000)),
      );
      final delay = backoff.remaining;
      elapsed += delay + const Duration(milliseconds: 1);
      expect(backoff.remaining, Duration.zero);
    }
    backoff.reset();
    backoff.failed();
    expect(backoff.remaining.inMilliseconds, inInclusiveRange(400, 600));
    backoff.reset();
    expect(backoff.remaining, Duration.zero);
  });
}
