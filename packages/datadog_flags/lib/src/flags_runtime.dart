// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:math';

import 'package:http/http.dart' as http;

import 'datadog_flags_config.dart';
import 'flags_configuration.dart';

class FlagsRuntime {
  final DatadogFlagsConfiguration configuration;
  final DatadogFlagsConfig datadogConfig;
  final http.Client httpClient;

  const FlagsRuntime({
    required this.configuration,
    required this.datadogConfig,
    required this.httpClient,
  });
}

bool shouldRetryFlagsUpload(int statusCode) {
  return statusCode == 408 || statusCode == 429 || statusCode >= 500;
}

/// Exponential upload backoff shared across telemetry runtime handoffs.
///
/// Delays start at 500 ms with 20 percent jitter and are capped at 60 seconds.
/// Handoffs preserve the failure count and remaining monotonic delay. Periodic
/// flushes and batch-size triggers respect this delay. Successful uploads and
/// non-retryable responses reset it. Shutdown makes one bounded drain attempt.
final class UploadBackoff {
  static const maxDelay = Duration(seconds: 60);
  final Stopwatch _clock = Stopwatch()..start();
  final Duration Function()? elapsed;
  final Random _random;
  var _failures = 0;
  var _due = Duration.zero;

  UploadBackoff({this.elapsed, Random? random}) : _random = random ?? Random();

  Duration get _now => elapsed?.call() ?? _clock.elapsed;

  Duration get remaining {
    final delay = _due - _now;
    return delay.isNegative ? Duration.zero : delay;
  }

  void failed() {
    final base = min(500 * (1 << min(_failures, 7)), maxDelay.inMilliseconds);
    final milliseconds = min(
      (base * (0.8 + _random.nextDouble() * 0.4)).round(),
      maxDelay.inMilliseconds,
    );
    _failures = min(_failures + 1, 8);
    _due = _now + Duration(milliseconds: milliseconds);
  }

  void reset() {
    _failures = 0;
    _due = Duration.zero;
  }
}
